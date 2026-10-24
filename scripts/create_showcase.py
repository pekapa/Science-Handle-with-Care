"""Build and independently validate a development-only Factorio showcase save."""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile
from pathlib import Path

from engine_config import CONFIG
from package import ROOT, build, validate_manifest

SCENARIO = ROOT / "tests/showcase/scenario"
PASS = "SCIENCE_SHOWCASE_SETUP PASS"


def run(command, log_path, timeout):
    with log_path.open("w", encoding="utf-8") as output:
        result = subprocess.run(
            command, stdout=output, stderr=subprocess.STDOUT, timeout=timeout, check=False
        )
    if result.returncode:
        raise RuntimeError(f"Command exited {result.returncode}; see {log_path}")
    return log_path.read_text(encoding="utf-8", errors="replace")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio", default=os.environ.get("FACTORIO_BIN"))
    parser.add_argument("--data-dir", type=Path)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if not args.factorio:
        parser.error("supply --factorio PATH or FACTORIO_BIN")
    executable = Path(shutil.which(args.factorio) or args.factorio).resolve()
    if not executable.is_file():
        parser.error(f"Factorio executable not found: {executable}")
    candidates = [args.data_dir] if args.data_dir else [executable.parent / "../data"]
    data_dir = next(
        (
            path.resolve()
            for path in candidates
            if path and (path / "core").is_dir() and (path / "base").is_dir()
        ),
        None,
    )
    if data_dir is None:
        parser.error("cannot locate Factorio core/base data; supply --data-dir")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")

    output_dir = ROOT / "build/showcase"
    work = output_dir / "work"
    if work.exists():
        shutil.rmtree(work)
    mods = work / "mods"
    write_data = work / "write-data"
    scenarios = write_data / "scenarios"
    mods.mkdir(parents=True)
    scenarios.mkdir(parents=True)
    shutil.copytree(SCENARIO, scenarios / "science-showcase")
    archive = build()
    shutil.copy2(archive, mods / archive.name)
    manifest = validate_manifest()
    enabled_mods = ["base", manifest["name"]]
    mod_list = [{"name": name, "enabled": True} for name in enabled_mods] + [
        {"name": name, "enabled": False}
        for name in sorted(
            path.name
            for path in data_dir.iterdir()
            if path.is_dir()
            and (path / "info.json").is_file()
            and path.name not in {"base", "core"}
        )
    ]
    (mods / "mod-list.json").write_text(json.dumps({"mods": mod_list}), encoding="utf-8")
    config = work / "config.ini"
    config.write_text(f"[path]\nread-data={data_dir}\nwrite-data={write_data}\n", encoding="utf-8")
    common = [str(executable), "--config", str(config), "--mod-directory", str(mods)]
    version = run(common + ["--version"], output_dir / "version.log", args.timeout)
    if CONFIG["factorio_version"] not in version:
        raise RuntimeError(
            f"Engine version does not match {CONFIG['factorio_version']}; see version.log"
        )

    settings = work / "server-settings.json"
    server_settings = json.loads(
        (data_dir / "server-settings.example.json").read_text(encoding="utf-8")
    )
    server_settings.update(
        {
            "name": "Isolated science showcase generator",
            "visibility": {"public": False, "lan": False},
            "require_user_verification": False,
            "auto_pause": False,
        }
    )
    settings.write_text(json.dumps(server_settings), encoding="utf-8")
    server_log = output_dir / "scenario.log"
    with server_log.open("w", encoding="utf-8") as log:
        server = subprocess.Popen(
            common
            + [
                "--start-server-load-scenario",
                "science-showcase",
                "--server-settings",
                str(settings),
                "--port",
                "0",
                "--console-log",
                str(output_dir / "server-console.log"),
            ],
            stdout=log,
            stderr=subprocess.STDOUT,
        )
        deadline = time.monotonic() + args.timeout
        saves = write_data / "saves"
        save = None
        try:
            while time.monotonic() < deadline:
                if server.poll() is not None:
                    raise RuntimeError(
                        f"Scenario server exited {server.returncode}; see {server_log}"
                    )
                candidates = sorted(saves.glob("_autosave-science-showcase.zip"))
                if candidates and candidates[0].stat().st_size:
                    save = candidates[0]
                    break
                time.sleep(1)
            if save is None:
                raise RuntimeError(f"Scenario autosave timed out; see {server_log}")
        finally:
            server.terminate()
            try:
                server.wait(timeout=20)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait(timeout=20)
    scenario_output = server_log.read_text(encoding="utf-8", errors="replace")
    if PASS not in scenario_output:
        raise RuntimeError(
            "Missing scenario setup completion marker; see scenario.log and server-console.log"
        )

    built_save = output_dir / "science-showcase.zip"
    shutil.copy2(save, built_save)
    with zipfile.ZipFile(built_save) as saved:
        if not any(name.endswith("/control.lua") for name in saved.namelist()):
            raise RuntimeError("Showcase save does not embed its scenario script")
    verify = run(
        common
        + ["--benchmark", str(built_save), "--benchmark-ticks", "120", "--benchmark-runs", "1"],
        output_dir / "load-validation.log",
        args.timeout,
    )
    if (
        "Performed 120 updates" not in verify
        or "SCIENCE_SHOWCASE_RELOAD PASS" not in verify
        or "SCIENCE_SHOWCASE_MODS PASS" not in verify
    ):
        raise RuntimeError(
            "Independent save load did not reach benchmark completion; see load-validation.log"
        )
    print(f"Showcase save generated and independently load-validated: {built_save}")
    print(f"Logs: {output_dir}")


if __name__ == "__main__":
    try:
        main()
    except (
        OSError,
        RuntimeError,
        subprocess.TimeoutExpired,
        zipfile.BadZipFile,
        KeyError,
    ) as error:
        print(f"showcase generation failed: {error}", file=sys.stderr)
        raise SystemExit(1)
