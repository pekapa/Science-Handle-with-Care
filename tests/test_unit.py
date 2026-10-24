"""Pure Lua rules and regression tests for the engine harness."""

import shutil
import subprocess
import unittest

from engine_config import download_url, validate_version
from engine_runner import validate_completion
from package import MOD, ROOT


class PureRulesTests(unittest.TestCase):
    pass


def lua_case(path):
    def run(self):
        runtime = next(
            (shutil.which(name) for name in ("lua5.2", "lua", "luajit") if shutil.which(name)), None
        )
        self.assertIsNotNone(
            runtime, "Lua 5.2-compatible runtime required; install it before testing"
        )
        result = subprocess.run(
            [runtime, str(path)], cwd=MOD, capture_output=True, text=True, timeout=30
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    return run


for path in sorted((ROOT / "tests/unit").glob("*.lua")):
    setattr(PureRulesTests, f"test_{path.stem}", lua_case(path))


class EngineHarnessTests(unittest.TestCase):
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
