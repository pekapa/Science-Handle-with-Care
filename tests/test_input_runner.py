"""Local contracts for isolated graphical input execution; no Factorio required."""

import hashlib
import itertools
import struct
import sys
import tempfile
import unittest
import zipfile
import zlib
from pathlib import Path
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import input_runner
from graphical_support import copy_player_save

INPUT_FINAL = "Script @fixture:1: LAB_INPUT_FINAL PASS\n"
HOST_FINAL = "Script @fixture:2: LAB_INPUT_HOST_FINAL PASS\n"
COMPLETE = INPUT_FINAL + HOST_FINAL


def png():
    def chunk(kind, payload):
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload))
        )

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00"))
        + chunk(b"IEND", b"")
    )


class InputRunnerContracts(unittest.TestCase):
    def run_fixture(self, text, images=2, exited=False, timeout=10, corrupt=False, partial=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            screenshots = [root / name for name in input_runner.SCREENSHOTS]
            for path in screenshots[:images]:
                path.write_bytes(b"broken" if corrupt else png()[:33] if partial else png())
            process = Mock()
            process.poll.return_value = 0 if exited else None
            process.returncode = 0
            clock = itertools.count(step=0.25)

            def launch(*args, **kwargs):
                kwargs["stdout"].write(text)
                kwargs["stdout"].flush()
                return process

            sleeps = 0

            def flush_captures(_delay):
                nonlocal sleeps
                sleeps += 1
                if partial and sleeps == 3:
                    for path in screenshots:
                        path.write_bytes(png())

            with (
                patch.object(input_runner.subprocess, "Popen", side_effect=launch),
                patch.object(input_runner.time, "monotonic", side_effect=lambda: next(clock)),
                patch.object(input_runner.time, "sleep", side_effect=flush_captures),
            ):
                try:
                    return input_runner.run_client(
                        ["owned-test-child"], root / "log", screenshots, timeout
                    )
                finally:
                    process.wait.assert_called_once_with(timeout=10)
                    if not exited:
                        process.terminate.assert_called_once_with()
                    else:
                        process.terminate.assert_not_called()

    def test_exact_final_and_both_pngs_pass_and_owned_child_is_reaped(self):
        text = COMPLETE
        self.assertEqual(self.run_fixture(text), text)

    def test_partial_pngs_finish_during_live_host_flush(self):
        text = COMPLETE
        self.assertEqual(self.run_fixture(text, partial=True), text)

    def test_missing_marker_and_missing_png_each_timeout(self):
        for text, images in [("no assertion", 2), (COMPLETE, 1)]:
            with self.subTest(images=images), self.assertRaisesRegex(RuntimeError, "timeout"):
                self.run_fixture(text, images=images, timeout=1)

    def test_failure_and_engine_errors_reject_even_with_final(self):
        for failure in ("Error engine failure", "LAB_INPUT FAIL native slot missing"):
            with self.subTest(failure=failure), self.assertRaisesRegex(RuntimeError, "failure"):
                self.run_fixture(COMPLETE + failure)

    def test_exit_zero_does_not_substitute_for_completed_live_host(self):
        with self.assertRaisesRegex(RuntimeError, "exited 0"):
            self.run_fixture(COMPLETE, exited=True)

    def test_corrupt_png_rejects_completion(self):
        with self.assertRaisesRegex(ValueError, "PNG"):
            self.run_fixture(COMPLETE, corrupt=True)

    def test_only_exact_single_marker_counts(self):
        valid = COMPLETE
        for text in ("LAB_INPUT_FINAL PASS\n", valid.rstrip() + " extra\n"):
            self.assertFalse(input_runner.completion(text))
        with self.assertRaisesRegex(RuntimeError, "Duplicate"):
            input_runner.completion(valid * 2)

    def test_combined_completion_requires_each_exact_marker_once(self):
        input_final = COMPLETE
        gui_final = "Script @fixture:2: SCIENCE_GUI_FINAL PASS\n"
        self.assertFalse(input_runner.completion(input_final, with_gui=True))
        self.assertFalse(input_runner.completion(gui_final, with_gui=True))
        self.assertTrue(input_runner.completion(input_final + gui_final, with_gui=True))
        with self.assertRaisesRegex(RuntimeError, "Duplicate GUI"):
            input_runner.completion(input_final + gui_final * 2, with_gui=True)

    def test_input_assertions_without_host_cleanup_cannot_pass(self):
        self.assertFalse(input_runner.completion(INPUT_FINAL))
        with self.assertRaisesRegex(RuntimeError, "timeout"):
            self.run_fixture(INPUT_FINAL, timeout=1)
        with self.assertRaisesRegex(RuntimeError, "Duplicate host"):
            input_runner.completion(COMPLETE + HOST_FINAL)

    def test_timeout_bounds_prevent_launch(self):
        with patch.object(input_runner.subprocess, "Popen") as launch:
            for timeout in (0, -1, 121, float("nan"), float("inf")):
                with self.assertRaisesRegex(ValueError, "Timeout"):
                    input_runner.run_client([], Path("unused"), [], timeout)
            launch.assert_not_called()

    def test_seed_copy_replaces_only_scenario_with_exact_fixture_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, destination, fixture = (
                root / "source.zip",
                root / "copy.zip",
                root / "control.lua",
            )
            fixture.write_bytes(b"-- inert scenario\n")
            with zipfile.ZipFile(source, "w") as archive:
                archive.writestr("seed/control.lua", b"old scenario")
                archive.writestr("seed/level.dat", b"actual seed bytes")
            original = source.read_bytes()
            digest = copy_player_save(source, destination, fixture)
            self.assertEqual(digest, hashlib.sha256(fixture.read_bytes()).hexdigest())
            self.assertEqual(source.read_bytes(), original)
            with zipfile.ZipFile(destination) as copied:
                self.assertEqual(copied.read("seed/control.lua"), fixture.read_bytes())
                self.assertEqual(copied.read("seed/level.dat"), b"actual seed bytes")

    def test_gui_seed_copy_injects_sibling_modules_and_hashes_bundle(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fixture = root / "gui-validation-fixture"
            fixture.mkdir()
            (fixture / "control.lua").write_bytes(b"require('gui_suite')")
            (fixture / "gui_suite.lua").write_bytes(b"return {}")
            seed = root / "seed.zip"
            with zipfile.ZipFile(seed, "w") as archive:
                archive.writestr("seed/control.lua", b"old")
                archive.writestr("seed/gui_suite.lua", b"outdated")
            first = copy_player_save(seed, root / "first.zip", fixture / "control.lua")
            with zipfile.ZipFile(root / "first.zip") as copied:
                self.assertEqual(copied.read("seed/gui_suite.lua"), b"return {}")
                self.assertEqual(copied.namelist().count("seed/gui_suite.lua"), 1)
            (fixture / "gui_suite.lua").write_bytes(b"return {changed=true}")
            second = copy_player_save(seed, root / "second.zip", fixture / "control.lua")
            self.assertNotEqual(first, second)

    def test_seed_without_unique_scenario_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source.zip"
            for names in ([], ["one/control.lua", "two/control.lua"]):
                with zipfile.ZipFile(source, "w") as archive:
                    for name in names:
                        archive.writestr(name, b"scenario")
                with self.assertRaisesRegex(ValueError, "exactly one"):
                    copy_player_save(
                        source, root / "copy.zip", input_runner.FIXTURE / "scenario.lua"
                    )
