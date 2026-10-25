"""Local preflight contracts; these checks never launch Factorio."""

import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import Mock, patch

import gui_runner
import input_runner
from graphical_preflight import cached_output, headless_preflight, select_mods, validate_seed


class GraphicalPreflightTests(unittest.TestCase):
    def test_ambiguous_seed_fails_before_copy(self):
        with tempfile.TemporaryDirectory() as temporary:
            seed = Path(temporary) / "seed.zip"
            with zipfile.ZipFile(seed, "w") as archive:
                archive.writestr("one/control.lua", "")
                archive.writestr("two/control.lua", "")
            with self.assertRaisesRegex(ValueError, "exactly one"):
                validate_seed(seed)

    def test_missing_dependency_does_not_write_mod_list(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            data, mods = root / "data", root / "mods"
            (data / "base").mkdir(parents=True)
            mods.mkdir()
            (data / "base/info.json").write_text(json.dumps({"name": "base", "version": "2.1.23"}))
            manifest = {"name": "fixture", "version": "0.1.0", "dependencies": ["absent"]}
            with self.assertRaisesRegex(ValueError, "absent"):
                select_mods(data, mods, [manifest])
            self.assertFalse((mods / "mod-list.json").exists())

    def test_headless_preflight_requires_created_save(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            engine = Mock(return_value="No engine error")
            with self.assertRaisesRegex(RuntimeError, "save"):
                headless_preflight(["factorio", "--config", "isolated"], root, root, 1, engine)
            command = engine.call_args.args[0]
            self.assertIn("--create", command)
            self.assertNotIn("--load-game", command)

    def test_cache_lock_and_stale_capture_cleanup(self):
        with tempfile.TemporaryDirectory() as temporary:
            cache = Path(temporary) / "cache"
            with cached_output(cache) as output:
                (output / "script-output/old.png").write_bytes(b"stale")
                (output / "atlas-cache.dat").write_bytes(b"cached")
                with self.assertRaisesRegex(RuntimeError, "locked"):
                    with cached_output(cache):
                        self.fail("Lock admitted concurrent runner")
            with cached_output(cache) as output:
                self.assertFalse((output / "script-output/old.png").exists())
                self.assertEqual((output / "atlas-cache.dat").read_bytes(), b"cached")

    def test_rejected_overlapping_run_preserves_active_results(self):
        for runner, profile, result_dir in (
            (gui_runner, "gui-sprite-cache", "gui-test-results"),
            (input_runner, "input-sprite-cache", "input-test-results"),
        ):
            with self.subTest(runner=runner.__name__), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                data = root / "data"
                (data / "core").mkdir(parents=True)
                (data / "base").mkdir()
                seed = root / "seed.zip"
                with zipfile.ZipFile(seed, "w") as archive:
                    archive.writestr("seed/control.lua", "-- disposable seed")
                results = root / "build" / result_dir
                results.mkdir(parents=True)
                evidence = results / "runtime.json"
                evidence.write_text("active owner evidence")
                with cached_output(root / "build" / profile):
                    with (
                        patch.object(runner, "ROOT", root),
                        patch(
                            "sys.argv",
                            [
                                "runner",
                                "--player-save",
                                str(seed),
                                "--factorio",
                                sys.executable,
                                "--data-dir",
                                str(data),
                            ],
                        ),
                    ):
                        with self.assertRaisesRegex(RuntimeError, "locked"):
                            runner.main()
                self.assertEqual(evidence.read_text(), "active owner evidence")
