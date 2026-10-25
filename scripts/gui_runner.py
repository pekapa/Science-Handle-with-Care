"""Exercise production GUI with a copied, explicitly supplied real-player test save."""

import argparse
import contextlib
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
import zipfile
from pathlib import Path

import graphical_support
from engine_config import CONFIG, validate_version
from engine_runner import run
from graphical_preflight import (
    cached_output,
    headless_preflight,
    select_mods,
    validate_package,
    validate_seed,
    write_config,
)
from package import ROOT, build, validate_manifest

MARKER = "SCIENCE_GUI_FINAL PASS"


def require_no_factorio():
    """Refuse Steam forwarding when an existing game might receive our arguments."""
    try:
        processes = subprocess.run(
            ["ps", "-axo", "pid=,comm="], capture_output=True, text=True, timeout=10, check=True
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise RuntimeError(
            "Cannot establish that no Factorio game is running; Steam launch refused"
        ) from error
    for line in processes.stdout.splitlines():
        fields = line.strip().split(maxsplit=1)
        if len(fields) != 2 or not fields[0].isdigit():
            raise RuntimeError("Cannot interpret process inventory; Steam launch refused")
        if Path(fields[1]).name.lower() == "factorio":
            raise RuntimeError("An existing Factorio game is running; Steam launch refused")
    if not processes.stdout.strip():
        raise RuntimeError("Empty process inventory; Steam launch refused")


def run_steam(launcher, arguments, output, results, timeout):
    """Observe the isolated game, independently of Steam's short-lived launcher."""
    require_no_factorio()
    with (results / "launcher.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(
            [launcher, "-applaunch", "427520", *arguments], stdout=log, stderr=subprocess.STDOUT
        )
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            game_log = output / "factorio-current.log"
            text = game_log.read_text(errors="replace") if game_log.is_file() else ""
            (results / "benchmark.log").write_text(text, encoding="utf-8")
            if re.search(r"\b(?:Error|ERROR)\b", text):
                raise RuntimeError(
                    "Steam-launched engine logged an error; see benchmark.log. "
                    "The launched game may still be running; no process was signalled."
                )
            if "Quitting: automatic-quit." in text and re.search(r"\bGoodbye\s*$", text, re.M):
                markers = re.findall(r"Script @[^\n]*: (SCIENCE_GUI_FINAL PASS)\s*$", text, re.M)
                if markers != [MARKER]:
                    raise RuntimeError(
                        "Missing or duplicate GUI completion assertion; see benchmark.log"
                    )
                for name in graphical_support.GUI_SCREENSHOTS:
                    graphical_support.png_dimensions(output / "script-output" / name)
                return text
            # Launcher exit (including success) is not game completion.
            process.poll()
            time.sleep(0.25)
    raise RuntimeError(
        "Steam game completion timed out; see benchmark.log and launcher.log. "
        "The launched game may still be running; its isolated directory is retained. "
        "No process was signalled."
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--player-save", type=Path, required=True)
    parser.add_argument("--factorio", default=os.environ.get("FACTORIO_BIN"))
    parser.add_argument(
        "--target", default=os.environ.get("FACTORIO_TARGET", CONFIG["default_target"])
    )
    parser.add_argument("--data-dir", type=Path)
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument(
        "--graphics", action="store_true", help="require rendered PNGs using --benchmark-graphics"
    )
    parser.add_argument("--steam-launcher", help="Steam executable; requires --graphics")
    parser.add_argument(
        "--preflight-only", action="store_true", help="validate without opening a graphical client"
    )
    args = parser.parse_args()
    with cached_output(ROOT / "build/gui-sprite-cache") as output:
        _run(args, output)


def _run(args, output):
    results = ROOT / "build/gui-test-results"
    results.mkdir(parents=True, exist_ok=True)
    for name in (
        *graphical_support.GUI_SCREENSHOTS,
        "runtime.json",
        "screenshots.json",
        "version.log",
        "benchmark.log",
        "launcher.log",
        "visual-review.json",
        "preflight.log",
    ):
        (results / name).unlink(missing_ok=True)
    source, digest = args.player_save.resolve(), None
    evidence = {
        "outcome": "failed",
        "mode": "preflight"
        if args.preflight_only
        else "graphics"
        if args.graphics
        else "construction-actions",
        "launch_route": "steam" if args.steam_launcher else "direct",
        "target": args.target,
        "actual_version": "unknown",
        "version_output": "unknown",
        "package_sha256": "unknown",
        "source": graphical_support.source_state(),
        "player_save_sha256": "unknown",
        "fixture_sha256": "unknown",
        "copied_save_sha256": "unknown",
        "gui_scale": "unknown",
        "screenshots": {},
        "client_input": "unverified",
        "visual_inspection": "unverified",
    }
    try:
        launcher = shutil.which(args.steam_launcher) if args.steam_launcher else None
        if args.steam_launcher and (not args.graphics or not launcher):
            raise ValueError(
                "--steam-launcher requires --graphics and an installed Steam executable"
            )
        binary = shutil.which(args.factorio or "")
        if not binary or args.timeout <= 0:
            raise ValueError("supply an installed --factorio/FACTORIO_BIN and positive --timeout")
        source = args.player_save.resolve()
        if not source.is_file() or not zipfile.is_zipfile(source):
            raise ValueError("--player-save must be an existing isolated Factorio test save ZIP")
        executable = Path(binary).resolve()
        candidates = (
            [args.data_dir]
            if args.data_dir
            else [executable.parent / "../data", executable.parent / "../../data"]
        )
        data = next(
            (p.resolve() for p in candidates if (p / "core").is_dir() and (p / "base").is_dir()),
            None,
        )
        if data is None:
            raise ValueError("cannot find core/base data; supply --data-dir")
        validate_seed(source)
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        evidence["player_save_sha256"] = digest
        if launcher:
            temporary_directory = tempfile.mkdtemp(prefix="steam-gui-", dir=results)
            evidence["isolated_directory"] = str(Path(temporary_directory).resolve())
            directory = contextlib.nullcontext(temporary_directory)
        else:
            directory = tempfile.TemporaryDirectory(prefix="gui-", dir=results)
        with directory as temporary:
            isolated = Path(temporary).resolve()
            mods = isolated / "mods"
            mods.mkdir()
            config = isolated / "config.ini"
            write_config(config, data, output)
            evidence["sprite_cache"] = str(output)
            archive = build()
            shutil.copy2(archive, mods / archive.name)
            evidence["package_sha256"] = hashlib.sha256(archive.read_bytes()).hexdigest()
            manifest = validate_manifest()
            validate_package(archive, manifest)
            select_mods(data, mods, [manifest])
            save = isolated / "gui-validation.zip"
            evidence["fixture_sha256"] = graphical_support.copy_player_save(source, save)
            evidence["copied_save_sha256"] = hashlib.sha256(save.read_bytes()).hexdigest()
            common = [binary, "--config", str(config), "--mod-directory", str(mods)]
            version = run(common + ["--version"], results / "version.log", args.timeout)
            evidence["version_output"] = version
            actual = validate_version(version, args.target)
            evidence.update(
                actual_version=actual,
                version_output=version,
                mod_version=manifest["version"],
            )
            headless_preflight(common, isolated, results, args.timeout, run)
            evidence["preflight"] = "passed"
            if not args.preflight_only:
                arguments = common[1:] + [
                    "--disable-audio",
                    "--benchmark-graphics" if args.graphics else "--benchmark",
                    str(save),
                    "--benchmark-ticks",
                    "90",
                    "--benchmark-runs",
                    "1",
                ]
                if launcher:
                    evidence.update(actual_version="unknown", version_output="unknown")
                    try:
                        text = run_steam(launcher, arguments, output, results, args.timeout)
                    finally:
                        # Steam may launch a different installation than --factorio;
                        # retain its actual build even when assertions or rendering fail.
                        game_log = output / "factorio-current.log"
                        observed = (
                            game_log.read_text(errors="replace") if game_log.is_file() else ""
                        )
                        build_line = re.search(r"Factorio (\d+\.\d+\.\d+[^\n]*)", observed)
                        if build_line:
                            evidence.update(
                                version_output="Version: " + build_line[1],
                                actual_version=build_line[1].split()[0],
                            )
                    validate_version(evidence["version_output"], args.target)
                else:
                    text = run([binary, *arguments], results / "benchmark.log", args.timeout)
                for name in graphical_support.GUI_SCREENSHOTS:
                    screenshot = output / "script-output" / name
                    if screenshot.is_file():
                        shutil.copy2(screenshot, results / name)
                        evidence["screenshots"][name] = graphical_support.png_dimensions(
                            results / name
                        )
                markers = re.findall(r"Script @[^\n]*: (SCIENCE_GUI_FINAL PASS)\s*$", text, re.M)
                if markers != [MARKER]:
                    raise RuntimeError(
                        "Missing or duplicate GUI completion assertion; see benchmark.log"
                    )
                if args.graphics and set(evidence["screenshots"]) != set(
                    graphical_support.GUI_SCREENSHOTS
                ):
                    raise RuntimeError("Graphics mode requires both lab-gui.png and mixer-gui.png")
        if hashlib.sha256(source.read_bytes()).hexdigest() != digest:
            raise RuntimeError("Supplied save changed while validation ran")
        evidence["outcome"] = "passed"
    except (Exception, SystemExit) as error:
        evidence["error"] = str(error)
        raise
    finally:
        benchmark = results / "benchmark.log"
        if benchmark.is_file():
            scales = re.findall(r"\[UIScale: ([^\]\r\n]+)\]", benchmark.read_text(errors="replace"))
            if scales:
                evidence["gui_scale"] = scales[-1]
        if digest and (
            not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != digest
        ):
            evidence.update(outcome="failed", error="Supplied save changed while validation ran")
        (results / "runtime.json").write_text(
            json.dumps(evidence, indent=2) + "\n", encoding="utf-8"
        )
        (results / "screenshots.json").write_text(
            json.dumps(list(evidence["screenshots"])) + "\n", encoding="utf-8"
        )
    print(f"Production GUI {evidence['mode']} passed; logs: {results}")
    print("Client input and visual inspection remain unverified by this runner")


if __name__ == "__main__":
    main()
