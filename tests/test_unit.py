"""Pure Lua rule tests."""

import shutil
import subprocess
import unittest

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
