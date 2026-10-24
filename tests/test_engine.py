"""Real Factorio case; explicitly requested and never skipped for missing tools."""

import subprocess
import sys
import unittest

from package import ROOT


class RealEngineTests(unittest.TestCase):
    def test_packaged_helpers_preserve_tool_through_inserter_and_belt(self):
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/engine_runner.py")], check=False
        )
        self.assertEqual(
            result.returncode, 0, "Engine fixture failed; inspect build/test-results logs"
        )
