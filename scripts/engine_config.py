"""Shared supported engine series and official download channel configuration."""

import json
import re
from pathlib import Path

CONFIG = json.loads(Path(__file__).with_name("engine-targets.json").read_text(encoding="utf-8"))


def download_url(target):
    if target not in CONFIG["targets"] and not re.fullmatch(r"\d+\.\d+\.\d+", target):
        raise ValueError("Engine target must be stable, experimental, or an exact X.Y.Z version")
    return f"https://factorio.com/get-download/{target}/headless/linux64"


def validate_version(output, target):
    download_url(target)
    match = re.search(r"\bVersion: (\d+\.\d+\.\d+)\b", output)
    if not match:
        raise ValueError("Cannot identify actual Factorio build in version.log")
    actual = match[1]
    if not actual.startswith(CONFIG["factorio_version"] + "."):
        raise ValueError(f"Unsupported engine {actual}; expected {CONFIG['factorio_version']}.x")
    if target not in CONFIG["targets"] and actual != target:
        raise ValueError(f"Engine target {target} does not match actual build {actual}")
    return actual


if __name__ == "__main__":
    import argparse
    import os

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--target", default=os.environ.get("FACTORIO_TARGET", CONFIG["default_target"])
    )
    args = parser.parse_args()
    print(download_url(args.target))
