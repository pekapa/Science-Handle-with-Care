"""GUI runner evidence contracts without launching Factorio."""

import json
import unittest
import zipfile

import graphical_support
from package import validate_manifest


class GuiEvidenceTests(unittest.TestCase):
    """Runner contracts; fake engine output does not establish Factorio GUI behavior."""

    def test_graphics_requires_both_rendered_images_and_completion(self):
        for images, completion in ((1, True), (2, False), (2, True)):
            with self.subTest(images=images, completion=completion):
                self.run_gui(graphics=True, images=images, completion=completion)

    def test_ordinary_mode_accepts_assertions_without_rendered_images(self):
        self.run_gui(graphics=False, images=0, completion=True)

    def test_graphics_rejects_invalid_png_despite_completion(self):
        self.run_gui(graphics=True, images=2, completion=True, corrupt=True)

    def test_steam_route_preserves_isolation_and_records_game_build(self):
        self.run_gui(graphics=True, images=2, completion=True, steam=True)

    def test_preflight_only_never_starts_graphical_benchmark(self):
        self.run_gui(graphics=True, images=0, completion=True, preflight_only=True)

    def test_failed_headless_preflight_prevents_graphical_benchmark(self):
        self.run_gui(graphics=True, images=0, completion=True, preflight_failure=True)

    def run_gui(
        self,
        *,
        graphics,
        images,
        completion,
        corrupt=False,
        steam=False,
        preflight_only=False,
        preflight_failure=False,
    ):
        import configparser
        import hashlib
        import sys
        import tempfile
        from pathlib import Path
        from unittest.mock import patch

        import gui_runner

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            fixture = root / "tests/integration/gui-validation-fixture"
            fixture.mkdir(parents=True)
            fixture_bytes = b"-- test runner boundary\n"
            (fixture / "control.lua").write_bytes(fixture_bytes)
            copied_save_digest = None
            data = root / "data"
            for name in ("core", "base"):
                (data / name).mkdir(parents=True)
            (data / "base/info.json").write_text(json.dumps({"name": "base", "version": "2.1.23"}))
            seed = root / "seed.zip"
            with zipfile.ZipFile(seed, "w") as archive:
                archive.writestr("seed/control.lua", "-- untouched seed\n")
            seed_bytes = seed.read_bytes()
            package = root / "production.zip"
            manifest = validate_manifest()
            prefix = f"{manifest['name']}_{manifest['version']}/"
            with zipfile.ZipFile(package, "w") as archive:
                archive.writestr(prefix + "info.json", json.dumps(manifest))
                for name in ("control.lua", "data.lua", "LICENSE"):
                    archive.writestr(prefix + name, "test runner boundary")
            results = root / "build/gui-test-results"
            results.mkdir(parents=True)
            for name in (
                *graphical_support.GUI_SCREENSHOTS,
                "runtime.json",
                "screenshots.json",
                "version.log",
                "benchmark.log",
                "visual-review.json",
            ):
                (results / name).write_text("stale pass evidence")

            png = valid_png()

            def engine(command, log, timeout):
                nonlocal copied_save_digest
                if "--version" in command:
                    text = "Version: 2.1.23 (build 12345, test)"
                elif "--create" in command:
                    if preflight_failure:
                        raise RuntimeError("Preflight rejected prototype")
                    save = Path(command[command.index("--create") + 1])
                    with zipfile.ZipFile(save, "w") as archive:
                        archive.writestr("preflight/level.dat", "created")
                    text = "Created isolated preflight save"
                else:
                    self.assertFalse(
                        preflight_only or preflight_failure, "Graphical launch before preflight"
                    )
                    self.assertIn("--benchmark-graphics" if graphics else "--benchmark", command)
                    self.assertGreaterEqual(
                        int(command[command.index("--benchmark-ticks") + 1]), 70
                    )
                    save_flag = "--benchmark-graphics" if graphics else "--benchmark"
                    save = Path(command[command.index(save_flag) + 1])
                    copied_save_digest = hashlib.sha256(save.read_bytes()).hexdigest()
                    with zipfile.ZipFile(save) as copied:
                        self.assertEqual(copied.read("seed/control.lua"), fixture_bytes)
                    # A concurrent source edit must not change identity of inserted bytes.
                    (fixture / "control.lua").write_text("-- edited after snapshot\n")
                    config = configparser.ConfigParser()
                    config.read(command[command.index("--config") + 1])
                    output = Path(config["path"]["write-data"]) / "script-output"
                    output.mkdir(exist_ok=True)
                    for name in graphical_support.GUI_SCREENSHOTS[:images]:
                        (output / name).write_bytes(b"not PNG" if corrupt else png)
                    text = (
                        "Script @fixture: SCIENCE_GUI_FINAL PASS\n" if completion else "unfinished"
                    )
                    if graphics:
                        text += "\n[UIScale: automatic (100.0%)]\n"
                log.write_text(text)
                return text

            args = [
                "gui_runner.py",
                "--factorio",
                sys.executable,
                "--data-dir",
                str(data),
                "--player-save",
                str(seed),
            ] + (["--graphics"] if graphics else [])
            if preflight_only:
                args += ["--preflight-only"]
            if steam:
                args += ["--steam-launcher", sys.executable]

            def steam_launch(command, **kwargs):
                from unittest.mock import Mock

                text = engine(command, results / "benchmark.log", 120)
                config = configparser.ConfigParser()
                config.read(command[command.index("--config") + 1])
                output = Path(config["path"]["write-data"])
                (output / "factorio-current.log").write_text(
                    "Factorio 2.1.23 (build 54321, steam)\n"
                    + text
                    + "Quitting: automatic-quit.\nGoodbye\n"
                )
                return Mock()

            success = not preflight_failure and (
                preflight_only or (completion and not corrupt and (not graphics or images == 2))
            )
            with (
                patch.object(gui_runner, "ROOT", root),
                patch.object(graphical_support, "ROOT", root),
                patch.object(gui_runner, "build", return_value=package),
                patch.object(gui_runner, "run", side_effect=engine),
                patch.object(gui_runner, "require_no_factorio"),
                patch.object(gui_runner.subprocess, "Popen", side_effect=steam_launch),
                patch.object(
                    graphical_support,
                    "source_state",
                    return_value={"revision": "test", "dirty": True},
                ),
                patch("sys.argv", args),
            ):
                if success:
                    gui_runner.main()
                else:
                    with self.assertRaises((RuntimeError, ValueError)):
                        gui_runner.main()
            evidence = json.loads((results / "runtime.json").read_text())
            self.assertEqual(evidence["outcome"], "passed" if success else "failed")
            self.assertEqual(
                evidence["mode"],
                "preflight"
                if preflight_only
                else "graphics"
                if graphics
                else "construction-actions",
            )
            self.assertEqual(evidence["actual_version"], "2.1.23")
            if preflight_only or preflight_failure:
                self.assertEqual(evidence["screenshots"], {})
                self.assertFalse((results / "benchmark.log").exists())
                return
            self.assertEqual(
                evidence["package_sha256"], hashlib.sha256(package.read_bytes()).hexdigest()
            )
            self.assertEqual(seed.read_bytes(), seed_bytes)
            self.assertEqual(evidence["fixture_sha256"], hashlib.sha256(fixture_bytes).hexdigest())
            self.assertEqual(evidence["copied_save_sha256"], copied_save_digest)
            self.assertEqual(evidence["gui_scale"], "automatic (100.0%)" if graphics else "unknown")
            self.assertEqual(evidence["visual_inspection"], "unverified")
            self.assertFalse((results / "visual-review.json").exists())
            if steam:
                self.assertEqual(evidence["launch_route"], "steam")
                self.assertIn("build 54321", evidence["version_output"])
                self.assertTrue(Path(evidence["isolated_directory"]).is_dir())
            self.assertNotIn("stale", (results / "benchmark.log").read_text())
            if images == 0:
                self.assertEqual(json.loads((results / "screenshots.json").read_text()), [])
                self.assertFalse((results / "lab-gui.png").exists())


def valid_png():
    import struct
    import zlib

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
        + chunk(b"IDAT", zlib.compress(b"\0\0\0\0"))
        + chunk(b"IEND", b"")
    )


class SteamGuiRunnerTests(unittest.TestCase):
    """Steam launcher exit must never substitute for isolated game evidence."""

    def test_steam_observes_game_completion_after_launcher_exits(self):
        self.monitor("Script @fixture: SCIENCE_GUI_FINAL PASS\n", quit=True, images=True)

    def test_steam_rejects_missing_final_assertion_after_game_quits(self):
        self.monitor("", quit=True, images=True, error="completion assertion")

    def test_successful_launcher_without_game_completion_times_out(self):
        self.monitor("", quit=False, images=False, error="may still be running")

    def test_steam_rejects_engine_errors(self):
        self.monitor("Error loading scenario\n", quit=False, images=False, error="logged an error")

    def test_steam_requires_both_images_after_game_quits(self):
        self.monitor(
            "Script @fixture: SCIENCE_GUI_FINAL PASS\n",
            quit=True,
            images=False,
            error="lab-gui.png",
        )

    def monitor(self, text, *, quit, images, error=None):
        import tempfile
        from pathlib import Path
        from unittest.mock import Mock, patch

        import gui_runner

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / "write-data"
            output.mkdir()
            if quit:
                text += "Quitting: automatic-quit.\nGoodbye\n"
            (output / "factorio-current.log").write_text(text)
            if images:
                screenshots = output / "script-output"
                screenshots.mkdir()
                for name in graphical_support.GUI_SCREENSHOTS:
                    (screenshots / name).write_bytes(valid_png())
            process = Mock()
            process.poll.return_value = 0
            with (
                patch.object(gui_runner, "require_no_factorio"),
                patch.object(gui_runner.subprocess, "Popen", return_value=process) as launch,
                patch.object(gui_runner.time, "monotonic", side_effect=[0, 0, 2]),
                patch.object(gui_runner.time, "sleep"),
            ):
                if error:
                    with self.assertRaisesRegex((RuntimeError, FileNotFoundError), error):
                        gui_runner.run_steam("steam", ["--config", "isolated.ini"], output, root, 1)
                else:
                    self.assertEqual(
                        gui_runner.run_steam(
                            "steam", ["--config", "isolated.ini"], output, root, 1
                        ),
                        text,
                    )
                self.assertEqual(launch.call_args.args[0][:3], ["steam", "-applaunch", "427520"])
                process.terminate.assert_not_called()
                process.kill.assert_not_called()
            self.assertEqual((root / "benchmark.log").read_text(), text)
            self.assertTrue(output.is_dir())

    def test_steam_refuses_existing_game_or_unavailable_process_inventory(self):
        import subprocess
        from unittest.mock import Mock, patch

        import gui_runner

        for inventory in (
            Mock(stdout="123 /Applications/Factorio.app/Contents/MacOS/factorio\n"),
            Mock(stdout=""),
            subprocess.CalledProcessError(1, "ps"),
        ):
            with self.subTest(inventory=inventory):
                kwargs = (
                    {"side_effect": inventory}
                    if isinstance(inventory, Exception)
                    else {"return_value": inventory}
                )
                with patch.object(gui_runner.subprocess, "run", **kwargs):
                    with self.assertRaisesRegex(RuntimeError, "Steam launch refused"):
                        gui_runner.require_no_factorio()
