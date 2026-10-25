"""Test-runner discovery contracts without invoking any discovered test bodies."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from package import ROOT


class DiscoveryTests(unittest.TestCase):
    def list_cases(self, *arguments):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            tests = root / "tests"
            tests.mkdir()
            for name in ("new_contract", "engine"):
                (tests / f"test_{name}.py").write_text(
                    "import unittest\n"
                    "class ExampleTests(unittest.TestCase):\n"
                    "    def test_example(self):\n"
                    "        raise AssertionError('Listing must not execute tests')\n"
                )
            result = subprocess.run(
                [
                    sys.executable,
                    "-c",
                    "import sys; from pathlib import Path; "
                    "sys.path.insert(0, sys.argv.pop(1)); "
                    "import test; test.ROOT = Path(sys.argv.pop(1)); test.main()",
                    str(ROOT / "scripts"),
                    str(root),
                    "--list",
                    *arguments,
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return result.stdout.splitlines()

    def test_new_module_is_discovered_locally_and_engine_is_excluded(self):
        self.assertEqual(self.list_cases(), ["test_new_contract.ExampleTests.test_example"])

    def test_discovered_module_and_engine_are_individually_selectable(self):
        for name in ("new_contract", "engine"):
            with self.subTest(name=name):
                self.assertEqual(
                    self.list_cases("--suite", name), [f"test_{name}.ExampleTests.test_example"]
                )

    def test_all_includes_new_module_and_engine(self):
        self.assertEqual(
            self.list_cases("--suite", "all"),
            [
                "test_new_contract.ExampleTests.test_example",
                "test_engine.ExampleTests.test_example",
            ],
        )
