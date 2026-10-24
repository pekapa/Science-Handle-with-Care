"""Validate and package the local mod; never install it into Factorio."""

import json
import os
import re
import tempfile
import zipfile
from pathlib import Path

from engine_config import CONFIG

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "mod"


def validate_manifest():
    manifest = json.loads((MOD / "info.json").read_text(encoding="utf-8"))
    for field in ("name", "version", "title", "author", "factorio_version"):
        if not isinstance(manifest.get(field), str) or not manifest[field].strip():
            raise ValueError(f"Manifest requires a nonempty {field}")
    if not re.fullmatch(r"[a-z][a-z0-9-]*", manifest["name"]):
        raise ValueError("Invalid mod name")
    if not re.fullmatch(r"\d+\.\d+\.\d+", manifest["version"]):
        raise ValueError("Version must have three numeric components")
    if manifest["factorio_version"] != CONFIG["factorio_version"]:
        raise ValueError(f"Manifest must target Factorio {CONFIG['factorio_version']}")
    if manifest.get("dependencies") != [f"base >= {CONFIG['minimum_base_version']}"]:
        raise ValueError("Base dependency must match scripts/engine-targets.json")
    for entrypoint in ("data.lua", "control.lua"):
        if not (MOD / entrypoint).is_file():
            raise ValueError(f"Missing {entrypoint}")
    return manifest


def build():
    manifest = validate_manifest()
    folder = f"{manifest['name']}_{manifest['version']}"
    paths = sorted(MOD.rglob("*"))
    if any(path.is_symlink() for path in paths):
        raise ValueError("Mod source must not contain symbolic links")
    output = ROOT / "build"
    output.mkdir(exist_ok=True)
    target = output / f"{folder}.zip"
    descriptor, temporary = tempfile.mkstemp(prefix=f".{folder}-", suffix=".zip", dir=output)
    os.close(descriptor)
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in paths:
                if path.is_file():
                    archive.write(path, f"{folder}/{path.relative_to(MOD).as_posix()}")
            archive.write(ROOT / "LICENSE", f"{folder}/LICENSE")
        os.replace(temporary, target)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return target


if __name__ == "__main__":
    print(build())
