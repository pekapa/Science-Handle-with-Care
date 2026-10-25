"""Engine runner contracts without launching Factorio."""

import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

from engine_config import download_url, validate_version
from engine_runner import run_checkpoint, validate_completion


class EngineHarnessTests(unittest.TestCase):
    def test_checkpoint_server_waits_for_completed_archive(self):
        script = """
import pathlib, sys, time, zipfile
args = sys.argv[1:]
assert args[0] == '--start-server'
assert args[2] == '--server-settings'
assert args[4:] == ['--bind', '127.0.0.1', '--port', '0']
checkpoint = pathlib.Path(args[1]).with_name('checkpoint.zip')
print('SCIENCE_VALIDATION_CHECKPOINT PASS', flush=True)
checkpoint.write_text('unfinished archive')
time.sleep(0.2)
with zipfile.ZipFile(checkpoint, 'w') as saved:
    saved.writestr('checkpoint', 'serialized state')
time.sleep(30)
"""
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            checkpoint = root / "checkpoint.zip"
            run_checkpoint(
                [sys.executable, "-c", script],
                root / "save.zip",
                checkpoint,
                root / "settings.json",
                root / "checkpoint.log",
                5,
            )
            with zipfile.ZipFile(checkpoint) as saved:
                self.assertEqual(saved.read("checkpoint"), b"serialized state")

    def test_checkpoint_marker_without_save_times_out(self):
        script = (
            "import time; print('SCIENCE_VALIDATION_CHECKPOINT PASS', flush=True); time.sleep(30)"
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(RuntimeError, "Checkpoint save timed out"):
                run_checkpoint(
                    [sys.executable, "-c", script],
                    root / "save.zip",
                    root / "missing.zip",
                    root / "settings.json",
                    root / "checkpoint.log",
                    0.5,
                )

    def test_official_channel_and_exact_version_urls(self):
        for target in ("stable", "experimental", "2.1.23"):
            self.assertEqual(
                download_url(target), f"https://factorio.com/get-download/{target}/headless/linux64"
            )
        with self.assertRaises(ValueError):
            download_url("arbitrary/path")

    def test_actual_build_and_explicit_version_match(self):
        self.assertEqual(validate_version("Version: 2.1.23 (build 123)", "stable"), "2.1.23")
        with self.assertRaises(ValueError):
            validate_version("Version: 2.1.24", "2.1.23")
        with self.assertRaises(ValueError):
            validate_version("Version: 3.0.0", "experimental")
        with self.assertRaises(ValueError):
            validate_version("no version", "stable")

    def test_completion_requires_exact_single_engine_marker(self):
        marker = "0.1 Script @fixture/control.lua:90: SCIENCE_VALIDATION_FINAL PASS\n"
        validate_completion(marker)
        for output in (
            "",
            "SCIENCE_VALIDATION_FINAL PASS\n",
            marker + marker,
            marker.replace("PASS", "PASS extra"),
        ):
            with self.subTest(output=output), self.assertRaises(RuntimeError):
                validate_completion(output)
