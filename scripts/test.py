"""Discover named regression cases: python3 scripts/test.py [--suite SUITE]."""

import argparse
import sys
import unittest

from package import ROOT


def main():
    available = tuple(
        path.stem.removeprefix("test_") for path in sorted((ROOT / "tests").glob("test_*.py"))
    )
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=("local", "all", *available), default="local")
    parser.add_argument("--list", action="store_true", help="list case IDs without running tests")
    args = parser.parse_args()
    suites = (args.suite,)
    if args.suite in ("local", "all"):
        suites = tuple(name for name in available if name != "engine")
        if args.suite == "all" and "engine" in available:
            suites += ("engine",)
    suite = unittest.TestSuite(
        unittest.defaultTestLoader.discover(str(ROOT / "tests"), pattern=f"test_{name}.py")
        for name in suites
    )
    if args.list:

        def cases(group):
            for case in group:
                if isinstance(case, unittest.TestSuite):
                    yield from cases(case)
                else:
                    yield case.id()

        print("\n".join(cases(suite)))
        return
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(not result.wasSuccessful())


if __name__ == "__main__":
    main()
