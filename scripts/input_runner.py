"""Run the native Lab input regression in an isolated standalone graphical client."""

import argparse
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
import time
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

MARKER = "LAB_INPUT_FINAL PASS"
SCREENSHOTS = ("lab-input-before.png", "lab-input-after.png")
FIXTURE = ROOT / "tests/integration/input-validation-fixture"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def completion(text, with_gui=False):
    markers = re.findall(r"Script @[^\n]*: (LAB_INPUT_FINAL PASS)\s*$", text, re.M)
    if len(markers) > 1:
        raise RuntimeError("Duplicate Lab input final assertion")
    host = re.findall(r"Script @[^\n]*: (LAB_INPUT_HOST_FINAL PASS)\s*$", text, re.M)
    if len(host) > 1:
        raise RuntimeError("Duplicate host cleanup assertion")
    if with_gui:
        gui = re.findall(r"Script @[^\n]*: (SCIENCE_GUI_FINAL PASS)\s*$", text, re.M)
        if len(gui) > 1:
            raise RuntimeError("Duplicate GUI final assertion")
        return (
            markers == [MARKER]
            and host == ["LAB_INPUT_HOST_FINAL PASS"]
            and gui == ["SCIENCE_GUI_FINAL PASS"]
        )
    return markers == [MARKER] and host == ["LAB_INPUT_HOST_FINAL PASS"]


def reject_errors(text):
    if re.search(r"\b(?:Error|ERROR)\b|LAB_INPUT FAIL|SCIENCE_GUI FAIL", text):
        raise RuntimeError("Engine or named fixture failure; see client.log")


def run_client(command, log_path, screenshots, timeout, with_gui=False):
    """Require exact completion and rendered captures, then stop/reap only our child."""
    if not math.isfinite(timeout) or not 0 < timeout <= 120:
        raise ValueError("Timeout must be positive and at most 120 seconds")
    with log_path.open("w", encoding="utf-8") as output:
        child = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
        deadline, ready_since = time.monotonic() + timeout, None
        capture_error = None
        try:
            while time.monotonic() < deadline:
                text = log_path.read_text(errors="replace")
                reject_errors(text)
                if child.poll() is not None:
                    raise RuntimeError(
                        f"Graphical client exited {child.returncode} before shutdown"
                    )
                ready = completion(text, with_gui) and all(path.is_file() for path in screenshots)
                if ready:
                    try:
                        for path in screenshots:
                            graphical_support.png_dimensions(path)
                    except ValueError as error:
                        # The graphical client can expose the file before its last chunk.
                        # Keep checking errors/exit/completion while the write finishes.
                        capture_error, ready_since = error, None
                    else:
                        capture_error = None
                        ready_since = ready_since or time.monotonic()
                        # Retain the live host until queued captures and logs have flushed.
                        if time.monotonic() - ready_since >= 2:
                            return text
                time.sleep(0.1)
            if capture_error is not None:
                raise ValueError(
                    f"PNG capture invalid at deadline: {capture_error}"
                ) from capture_error
            raise RuntimeError(
                "Lab input timeout: connected player, final assertion or PNGs missing"
            )
        finally:
            if child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=10)
            else:
                child.wait(timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio", default=os.environ.get("FACTORIO_BIN"))
    parser.add_argument(
        "--target", default=os.environ.get("FACTORIO_TARGET", CONFIG["default_target"])
    )
    parser.add_argument("--player-save", type=Path, required=True)
    parser.add_argument("--data-dir", type=Path)
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument(
        "--with-gui", action="store_true", help="also run full-window GUI suite in the same client"
    )
    parser.add_argument(
        "--preflight-only", action="store_true", help="validate without opening a graphical client"
    )
    args = parser.parse_args()
    with cached_output(ROOT / "build/input-sprite-cache") as output:
        _run(args, output)


def _run(args, output):
    screenshots = SCREENSHOTS + graphical_support.GUI_SCREENSHOTS if args.with_gui else SCREENSHOTS
    results = ROOT / "build/input-test-results"
    results.mkdir(parents=True, exist_ok=True)
    for name in (
        *SCREENSHOTS,
        *graphical_support.GUI_SCREENSHOTS,
        "client.log",
        "version.log",
        "runtime.json",
        "preflight.log",
    ):
        (results / name).unlink(missing_ok=True)
    source, digest = args.player_save.resolve(), None
    evidence = {
        "outcome": "failed",
        "target": args.target,
        "with_gui": args.with_gui,
        "preflight_only": args.preflight_only,
        "source": graphical_support.source_state(),
        "actual_version": "unknown",
        "version_output": "unknown",
        "gui_scale": "unknown",
        "screenshots": {},
        "limits": "Native Lab input left-click only. Opening is assigned. Module routing, "
        "modifier keys and full-window visual usability remain unverified. Outer captures "
        "show a potentially clipped Factoriopedia simulation host, not the full visual suite.",
    }
    try:
        binary = shutil.which(args.factorio or "")
        if not binary or not math.isfinite(args.timeout) or not 0 < args.timeout <= 120:
            raise ValueError("Supply standalone --factorio and 0 < --timeout <= 120")
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
            raise ValueError("Cannot find core/base data; supply --data-dir")
        validate_seed(source)
        digest = sha256(source)
        evidence["player_save_sha256"] = digest
        files = {
            str(p.relative_to(FIXTURE)): sha256(p)
            for p in sorted(FIXTURE.rglob("*"))
            if p.is_file()
        }
        evidence["fixture_files_sha256"] = files
        evidence["fixture_bundle_sha256"] = hashlib.sha256(
            json.dumps(files, sort_keys=True).encode()
        ).hexdigest()
        with tempfile.TemporaryDirectory(prefix="input-", dir=results) as temporary:
            isolated = Path(temporary).resolve()
            mods = isolated / "mods"
            mods.mkdir()
            config = isolated / "config.ini"
            write_config(config, data, output)
            evidence["sprite_cache"] = str(output)
            archive, manifest = build(), validate_manifest()
            shutil.copy2(archive, mods / archive.name)
            evidence.update(package_sha256=sha256(archive), mod_version=manifest["version"])
            companion = json.loads((FIXTURE / "info.json").read_text())["name"]
            shutil.copytree(FIXTURE, mods / companion)
            gui_fixture = ROOT / "tests/integration/gui-validation-fixture"
            if args.with_gui:
                for path in gui_fixture.glob("*.lua"):
                    if path.name != "control.lua":
                        shutil.copy2(path, mods / companion / path.name)
            (mods / companion / "batch.lua").write_text(
                "return " + ("true" if args.with_gui else "false") + "\n", encoding="utf-8"
            )
            bundled_files = {
                path.name: sha256(path)
                for path in sorted((mods / companion).iterdir())
                if path.is_file()
            }
            evidence["prepared_fixture_files_sha256"] = bundled_files
            evidence["prepared_fixture_bundle_sha256"] = hashlib.sha256(
                json.dumps(bundled_files, sort_keys=True).encode()
            ).hexdigest()
            validate_package(archive, manifest)
            select_mods(data, mods, [manifest, json.loads((FIXTURE / "info.json").read_text())])
            save = isolated / "input-validation.zip"
            evidence["scenario_sha256"] = graphical_support.copy_player_save(
                source, save, FIXTURE / "scenario.lua"
            )
            evidence["copied_save_sha256"] = sha256(save)
            common = [binary, "--config", str(config), "--mod-directory", str(mods)]
            evidence["version_command"] = common + ["--version"]
            version = run(evidence["version_command"], results / "version.log", args.timeout)
            evidence.update(
                version_output=version, actual_version=validate_version(version, args.target)
            )
            headless_preflight(common, isolated, results, args.timeout, run)
            evidence["preflight"] = "passed"
            if not args.preflight_only:
                command = common + ["--disable-audio", "--load-game", str(save)]
                evidence["command"] = command
                captures = [output / "script-output" / name for name in screenshots]
                try:
                    run_client(
                        command, results / "client.log", captures, args.timeout, args.with_gui
                    )
                finally:
                    for path in captures:
                        if path.is_file():
                            shutil.copy2(path, results / path.name)
                            evidence["screenshots"][path.name] = graphical_support.png_dimensions(
                                path
                            )
                # Recheck after shutdown: late fixture errors/duplicates cannot become a pass.
                text = (results / "client.log").read_text(errors="replace")
                reject_errors(text)
                if not completion(text, args.with_gui):
                    raise RuntimeError("Missing exact Lab input final assertion")
        if sha256(source) != digest:
            raise RuntimeError("Supplied save changed during validation")
        evidence["outcome"] = "passed"
    except Exception as error:
        evidence["error"] = str(error)
        raise
    finally:
        log = results / "client.log"
        if log.is_file():
            scales = re.findall(r"\[UIScale: ([^\]\r\n]+)\]", log.read_text(errors="replace"))
            if scales:
                evidence["gui_scale"] = scales[-1]
        if digest and (not source.is_file() or sha256(source) != digest):
            evidence.update(outcome="failed", error="Supplied save changed during validation")
        (results / "runtime.json").write_text(
            json.dumps(evidence, indent=2) + "\n", encoding="utf-8"
        )
    label = (
        "Preflight"
        if args.preflight_only
        else "Combined GUI and Lab input"
        if args.with_gui
        else "Native Lab input"
    )
    print(f"{label} passed; evidence: {results}")
    print(evidence["limits"])


if __name__ == "__main__":
    main()
