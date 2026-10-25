"""Shared graphical fixture preparation and evidence helpers."""

import hashlib
import json
import struct
import subprocess
import zipfile
import zlib

from graphical_preflight import validate_seed
from package import ROOT

GUI_SCREENSHOTS = ("lab-gui.png", "mixer-gui.png")


def png_dimensions(path):
    """Reject missing/truncated PNGs and corrupt chunks; return observed dimensions."""
    with path.open("rb") as stream:
        if stream.read(8) != b"\x89PNG\r\n\x1a\n":
            raise ValueError(f"Invalid PNG signature: {path.name}")
        dimensions, image_data = None, False
        while True:
            header = stream.read(8)
            if len(header) != 8:
                raise ValueError(f"Truncated PNG: {path.name}")
            length, kind = struct.unpack(">I4s", header)
            payload, checksum = stream.read(length), stream.read(4)
            if len(payload) != length or len(checksum) != 4:
                raise ValueError(f"Truncated PNG chunk: {path.name}")
            if zlib.crc32(kind + payload) != struct.unpack(">I", checksum)[0]:
                raise ValueError(f"Corrupt PNG chunk: {path.name}")
            if dimensions is None:
                if kind != b"IHDR" or length != 13:
                    raise ValueError(f"Missing PNG header: {path.name}")
                dimensions = list(struct.unpack(">II", payload[:8]))
                if not all(dimensions):
                    raise ValueError(f"Empty PNG dimensions: {path.name}")
            image_data |= kind == b"IDAT" and length > 0
            if kind == b"IEND":
                if length or not image_data or stream.read(1):
                    raise ValueError(f"Invalid PNG ending: {path.name}")
                return dimensions


def source_state():
    revision = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=False
    )
    status = subprocess.run(
        ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True, check=False
    )
    return {
        "revision": revision.stdout.strip() if revision.returncode == 0 else "unknown",
        "dirty": bool(status.stdout) if status.returncode == 0 else "unknown",
    }


def copy_player_save(source, destination, fixture=None):
    """Replace only the copy's scenario script; never modify the supplied save."""
    fixture_path = fixture or ROOT / "tests/integration/gui-validation-fixture/control.lua"
    fixture_bytes = fixture_path.read_bytes()
    control = validate_seed(source)
    bundle = {"control.lua": fixture_bytes}
    if fixture is None or fixture_path.parent.name == "gui-validation-fixture":
        bundle.update(
            {path.name: path.read_bytes() for path in sorted(fixture_path.parent.glob("*.lua"))}
        )
        bundle["control.lua"] = fixture_bytes
    prefix = control.rsplit("/", 1)[0] + "/"
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(destination, "w") as copied:
        for entry in original.infolist():
            if entry.filename not in {prefix + name for name in bundle}:
                copied.writestr(entry, original.read(entry))
        for name, content in bundle.items():
            copied.writestr(prefix + name, content)
    if len(bundle) == 1:
        return hashlib.sha256(fixture_bytes).hexdigest()
    hashes = {name: hashlib.sha256(content).hexdigest() for name, content in bundle.items()}
    return hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()
