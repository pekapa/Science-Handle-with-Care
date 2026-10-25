"""Exercise production GUI with a copied, explicitly supplied real-player test save."""

import argparse
import hashlib
import json
import os
import re
import shutil
import tempfile
import zipfile
from pathlib import Path

from engine_config import validate_version
from engine_runner import run
from package import ROOT, build, validate_manifest

MARKER = "SCIENCE_GUI_FINAL PASS"


def copy_player_save(source, destination):
    """Replace only the copy's scenario script; never modify the supplied save."""
    fixture = ROOT / "tests/integration/gui-validation-fixture/control.lua"
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(destination, "w") as copied:
        controls = [
            name
            for name in original.namelist()
            if name.count("/") == 1 and name.endswith("/control.lua")
        ]
        if len(controls) != 1:
            raise ValueError("Player save must contain exactly one scenario control.lua")
        for entry in original.infolist():
            copied.writestr(
                entry,
                fixture.read_bytes() if entry.filename == controls[0] else original.read(entry),
            )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--player-save", type=Path, required=True)
    parser.add_argument("--factorio", default=os.environ.get("FACTORIO_BIN"))
    parser.add_argument("--target", default=os.environ.get("FACTORIO_TARGET", "2.1.23"))
    parser.add_argument("--data-dir", type=Path)
    parser.add_argument("--timeout", type=int, default=120)
    args = parser.parse_args()
    binary = shutil.which(args.factorio or "")
    if not binary or args.timeout <= 0:
        parser.error("supply an installed --factorio/FACTORIO_BIN and positive --timeout")
    source = args.player_save.resolve()
    if not source.is_file() or not zipfile.is_zipfile(source):
        parser.error("--player-save must be an existing isolated Factorio test save ZIP")
    executable = Path(binary).resolve()
    candidates = (
        [args.data_dir]
        if args.data_dir
        else [executable.parent / "../data", executable.parent / "../../data"]
    )
    data = next(
        (p.resolve() for p in candidates if (p / "core").is_dir() and (p / "base").is_dir()), None
    )
    if data is None:
        parser.error("cannot find core/base data; supply --data-dir")
    results = ROOT / "build/gui-test-results"
    results.mkdir(parents=True, exist_ok=True)
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="gui-", dir=results) as temporary:
        isolated = Path(temporary).resolve()
        mods, output = isolated / "mods", isolated / "write-data"
        mods.mkdir()
        output.mkdir()
        config = isolated / "config.ini"
        config.write_text(f"[path]\nread-data={data}\nwrite-data={output}\n", encoding="utf-8")
        archive = build()
        shutil.copy2(archive, mods / archive.name)
        manifest = validate_manifest()
        (mods / "mod-list.json").write_text(
            json.dumps(
                {
                    "mods": [
                        {"name": name, "enabled": name in {"base", manifest["name"]}}
                        for name in (
                            "base",
                            manifest["name"],
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
        save = isolated / "gui-validation.zip"
        copy_player_save(source, save)
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
                    "player_save_sha256": digest,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        text = run(
            common + ["--benchmark", str(save), "--benchmark-ticks", "60", "--benchmark-runs", "1"],
            results / "benchmark.log",
            args.timeout,
        )
        markers = re.findall(r"Script @[^\n]*: (SCIENCE_GUI_FINAL PASS)\s*$", text, re.M)
        if markers != [MARKER]:
            raise RuntimeError("Missing or duplicate GUI completion assertion; see benchmark.log")
        screenshots = []
        for name in ("lab-gui.png", "mixer-gui.png"):
            screenshot = output / "script-output" / name
            (results / name).unlink(missing_ok=True)
            if screenshot.is_file():
                shutil.copy2(screenshot, results / name)
                screenshots.append(name)
        (results / "screenshots.json").write_text(json.dumps(screenshots) + "\n", encoding="utf-8")
    if hashlib.sha256(source.read_bytes()).hexdigest() != digest:
        raise RuntimeError("Supplied save changed while validation ran")
    print(f"Production GUI assertions passed; logs: {results}")
    print(f"Rendered screenshots: {len(screenshots)} (benchmark may skip rendering)")


if __name__ == "__main__":
    main()
