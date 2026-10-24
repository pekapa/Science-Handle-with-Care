"""Distribution contracts, exercised through the standalone package builder."""

import json
import unittest
import zipfile

from package import MOD, ROOT, build, validate_manifest


class DistributionTests(unittest.TestCase):
    def test_archive_contains_exact_mod_sources_and_license(self):
        manifest = validate_manifest()
        folder = f"{manifest['name']}_{manifest['version']}"
        expected = {
            f"{folder}/{path.relative_to(MOD).as_posix()}"
            for path in MOD.rglob("*")
            if path.is_file()
        }
        expected.add(f"{folder}/LICENSE")
        with zipfile.ZipFile(build()) as archive:
            self.assertEqual(
                set(archive.namelist()), expected, "Unexpected or missing shipped files"
            )
            self.assertIsNone(archive.testzip(), "Corrupt ZIP member")
            self.assertEqual(json.loads(archive.read(f"{folder}/info.json")), manifest)
            self.assertEqual(archive.read(f"{folder}/LICENSE"), (ROOT / "LICENSE").read_bytes())
