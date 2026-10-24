"""Run the production ZIP and test companion using isolated Factorio directories."""

import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

from engine_config import CONFIG, download_url, validate_version
from package import ROOT, build, validate_manifest

MARKER = "SCIENCE_VALIDATION_FINAL PASS"


def run(command, log_path, timeout):
    with log_path.open("w", encoding="utf-8") as output:
        try:
            result = subprocess.run(
                command, stdout=output, stderr=subprocess.STDOUT, timeout=timeout, check=False
            )
        except subprocess.TimeoutExpired as error:
            raise RuntimeError(f"Engine timeout; see {log_path}") from error
    text = log_path.read_text(encoding="utf-8", errors="replace")
    if result.returncode != 0:
        raise RuntimeError(f"Engine exited {result.returncode}; see {log_path}")
    if re.search(r"\b(?:Error|ERROR)\b", text):
        raise RuntimeError(f"Engine logged an error; see {log_path}")
    return text


def validate_completion(output):
    markers = re.findall(r"Script @[^\n]*: (SCIENCE_VALIDATION_FINAL PASS)\s*$", output, re.M)
    if markers != [MARKER]:
        raise RuntimeError("Missing or duplicate exact final PASS marker; see benchmark.log")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio", default=os.environ.get("FACTORIO_BIN"))
    parser.add_argument(
        "--target", default=os.environ.get("FACTORIO_TARGET", CONFIG["default_target"])
    )
    parser.add_argument(
        "--data-dir", type=Path, help="Factorio data directory containing core and base"
    )
    parser.add_argument("--timeout", type=int, default=120, help="seconds per engine command")
    args = parser.parse_args()
    download_url(args.target)  # Validate selectors without making a network request.
    if not args.factorio:
        parser.error("supply --factorio PATH or FACTORIO_BIN; engine checks are required")
    binary = shutil.which(args.factorio)
    if binary is None:
        parser.error(f"Factorio executable not found: {args.factorio}")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    executable = Path(binary).resolve()
    candidates = (
        [args.data_dir]
        if args.data_dir
        else [executable.parent / "../data", executable.parent / "../../data"]
    )
    data_dir = next(
        (
            path.resolve()
            for path in candidates
            if (path / "core").is_dir() and (path / "base").is_dir()
        ),
        None,
    )
    if data_dir is None:
        parser.error("cannot locate Factorio core/base data; supply --data-dir PATH")
    results = ROOT / "build/test-results"
    results.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="engine-", dir=results) as temporary:
        isolated = Path(temporary).resolve()
        mods = isolated / "mods"
        mods.mkdir()
        write_data = isolated / "write-data"
        write_data.mkdir()
        save = isolated / "saves/validation.zip"
        save.parent.mkdir()
        config = isolated / "config.ini"
        config.write_text(
            f"[path]\nread-data={data_dir}\nwrite-data={write_data}\n",
            encoding="utf-8",
        )
        archive = build()
        shutil.copy2(archive, mods / archive.name)
        shutil.copytree(
            ROOT / "tests/integration/validation-fixture",
            mods / "science-validation-fixture_0.1.0",
        )
        manifest = validate_manifest()
        shutil.copytree(
            ROOT / "tests/integration/bootstrap-fixture",
            mods / "science-bootstrap-fixture_0.1.0",
        )

        def select_mods(gameplay):
            enabled = (
                {"base", manifest["name"], "science-validation-fixture"}
                if gameplay
                else {"base", "science-bootstrap-fixture"}
            )
            (mods / "mod-list.json").write_text(
                json.dumps(
                    {
                        "mods": [
                            {"name": name, "enabled": name in enabled}
                            for name in (
                                "base",
                                manifest["name"],
                                "science-validation-fixture",
                                "science-bootstrap-fixture",
                                "space-age",
                                "quality",
                                "elevated-rails",
                                "recycler",
                            )
                        ]
                    }
                ),
                encoding="utf-8",
            )

        select_mods(False)
        common = [binary, "--config", str(config), "--mod-directory", str(mods)]
        version = run(common + ["--version"], results / "version.log", args.timeout)
        actual = validate_version(version, args.target)
        (results / "runtime.json").write_text(
            json.dumps(
                {
                    "target": args.target,
                    "actual_version": actual,
                    "version_output": version,
                    "mod_version": manifest["version"],
                    "seed": 12345,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        run(
            common + ["--create", str(save), "--map-gen-seed", "12345"],
            results / "create.log",
            args.timeout,
        )
        select_mods(True)
        checkpoint = run(
            common + ["--load-game", str(save), "--until-tick", "121"],
            results / "checkpoint.log",
            args.timeout,
        )
        if "SCIENCE_VALIDATION_CHECKPOINT PASS" not in checkpoint:
            raise RuntimeError("Missing checkpoint assertion; see checkpoint.log")
        output = run(
            common
            + [
                "--benchmark",
                str(save),
                "--benchmark-ticks",
                "1100",
                "--benchmark-runs",
                "1",
            ],
            results / "benchmark.log",
            args.timeout,
        )
        if "SCIENCE_VALIDATION_RESUMED PASS" not in output:
            raise RuntimeError("Missing reload assertion; see benchmark.log")
        validate_completion(output)
    print(f"Engine fixture passed; logs: {results}")


if __name__ == "__main__":
    main()
