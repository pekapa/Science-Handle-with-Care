"""Prepare isolated graphical runs and reject cheap failures before opening a client."""

import contextlib
import json
import re
import shutil
import zipfile
from pathlib import PurePosixPath


def validate_seed(path):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or any(
            PurePosixPath(name).is_absolute() or ".." in PurePosixPath(name).parts for name in names
        ):
            raise ValueError("Save ZIP contains duplicate or unsafe member names")
        if archive.testzip() is not None:
            raise ValueError("Save ZIP contains a corrupt member")
        controls = [
            name for name in names if name.count("/") == 1 and name.endswith("/control.lua")
        ]
        if len(controls) != 1:
            raise ValueError("Player save must contain exactly one scenario control.lua")
        return controls[0]


def validate_package(path, manifest):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise ValueError("Production ZIP contains a corrupt member")
        prefix = f"{manifest['name']}_{manifest['version']}/"
        names = archive.namelist()
        if len(names) != len(set(names)) or any(
            not name.startswith(prefix) or ".." in PurePosixPath(name).parts for name in names
        ):
            raise ValueError("Production ZIP has unexpected or duplicate members")
        for required in ("control.lua", "data.lua", "LICENSE"):
            if prefix + required not in names:
                raise ValueError(f"Production ZIP missing {required}")
        if json.loads(archive.read(prefix + "info.json")) != manifest:
            raise ValueError("Production ZIP manifest does not match current source")


def select_mods(data, mods, manifests):
    bundled = {}
    for path in sorted(data.iterdir()):
        if path.name != "core" and (path / "info.json").is_file():
            manifest = json.loads((path / "info.json").read_text())
            if manifest.get("name") != path.name:
                raise ValueError(f"Bundled mod manifest name mismatch: {path.name}")
            bundled[path.name] = manifest
    available = dict(bundled)
    for manifest in manifests:
        if not all(
            isinstance(manifest.get(key), str) and manifest[key] for key in ("name", "version")
        ):
            raise ValueError("Mod manifest requires name and version")
        if manifest["name"] in available:
            raise ValueError(f"Duplicate mod manifest: {manifest['name']}")
        available[manifest["name"]] = manifest
    enabled = {"base", *(manifest["name"] for manifest in manifests)}
    if "base" not in available:
        raise ValueError("Missing bundled base manifest")
    for name in sorted(enabled):
        dependencies = available[name].get("dependencies", [])
        if not isinstance(dependencies, list):
            raise ValueError(f"Invalid dependencies for {name}")
        for dependency in dependencies:
            match = re.fullmatch(
                r"([a-zA-Z0-9_-]+)(?:\s*(>=|=|>|<=|<)\s*(\d+(?:\.\d+){1,2}))?", dependency
            )
            if not match:
                raise ValueError(f"Unsupported dependency in isolated fixture: {dependency}")
            required, operator, version = match.groups()
            if required not in enabled:
                raise ValueError(f"Missing enabled dependency for {name}: {required}")
            if operator:
                actual = tuple(int(part) for part in available[required]["version"].split("."))
                minimum = tuple(int(part) for part in version.split("."))
                actual, minimum = (
                    actual + (0,) * (3 - len(actual)),
                    minimum + (0,) * (3 - len(minimum)),
                )
                valid = {
                    ">=": actual >= minimum,
                    "=": actual == minimum,
                    ">": actual > minimum,
                    "<=": actual <= minimum,
                    "<": actual < minimum,
                }[operator]
                if not valid:
                    raise ValueError(f"Unsatisfied dependency for {name}: {dependency}")
    (mods / "mod-list.json").write_text(
        json.dumps(
            {"mods": [{"name": name, "enabled": name in enabled} for name in sorted(available)]}
        ),
        encoding="utf-8",
    )


def write_config(config, data, output):
    config.write_text(
        f"[path]\nread-data={data}\nwrite-data={output}\n"
        "[graphics]\ncache-sprite-atlas=true\ncache-sprite-atlas-count=1\nfull-screen=false\n"
        "[other]\nshow-tips-and-tricks=false\n",
        encoding="utf-8",
    )


@contextlib.contextmanager
def cached_output(cache):
    """Keep engine-managed atlas files in a dedicated, exclusively owned test profile."""
    cache.mkdir(parents=True, exist_ok=True)
    lock = cache / ".runner-lock"
    try:
        lock.mkdir()
    except FileExistsError as error:
        raise RuntimeError(f"Test sprite cache is locked: {lock}") from error
    try:
        output = cache / "write-data"
        output.mkdir(exist_ok=True)
        for name in ("script-output", "saves"):
            shutil.rmtree(output / name, ignore_errors=True)
            (output / name).mkdir()
        (output / "factorio-current.log").unlink(missing_ok=True)
        yield output
    except RuntimeError as error:
        # Steam may still own this profile after its launcher exits or times out.
        if "may still be running" in str(error):
            raise
        lock.rmdir()
        raise
    except BaseException:
        lock.rmdir()
        raise
    else:
        lock.rmdir()


def headless_preflight(common, isolated, results, timeout, run):
    save = isolated / "preflight.zip"
    run(
        common + ["--create", str(save), "--map-gen-seed", "12345"],
        results / "preflight.log",
        timeout,
    )
    if not save.is_file():
        raise RuntimeError("Headless preflight did not produce its required save")
    with zipfile.ZipFile(save) as archive:
        if archive.testzip() is not None or not archive.namelist():
            raise ValueError("Headless preflight produced an invalid save ZIP")
