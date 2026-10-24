# Engine validation fixture

Run `FACTORIO_BIN=/absolute/path/to/factorio make test-engine` or
`python3 scripts/engine_runner.py --factorio /absolute/path/to/factorio`.
The supported engine series and channels live in `scripts/engine-targets.json`.
CI runs the latest official stable and experimental headless channels. Local runs
use `FACTORIO_BIN` without downloads. Set `FACTORIO_TARGET=2.1.23` (or pass
`--target 2.1.23` to the engine runner) to require an exact build; channel
selectors locally verify the supported series, not whether an installed binary is
the latest release. Each command has a 120-second timeout (`--timeout SECONDS`
with the engine runner). Missing tools and unavailable downloads fail.
Use `python3 scripts/test.py --suite engine --list` to discover the named case.

The runner discovers `data/core` and `data/base` in standard macOS app-bundle and
Linux/Windows archive layouts relative to the resolved executable. For a custom
installation, pass `--data-dir /absolute/path/to/data` to the Python runner.

The runner builds the production ZIP, copies it and this companion mod into an
isolated temporary mod directory, creates an isolated save with `--create`, then
runs 660 benchmark ticks. It uses a temporary config and write-data directory,
never the player's configuration, mods or saves. Temporary files are deleted;
`build/test-results/{version,create,benchmark}.log` and `runtime.json` remain
available for diagnosis; CI also records the downloaded archive SHA-256.
`runtime.json` records target, actual engine version/build output, mod version and
fixture seed. A recorded digest identifies the archive; it is not an independent
upstream digest verification.
Nonzero exits, logged errors, timeouts, a mismatched engine version, and a missing
or duplicate exact final `SCIENCE_VALIDATION_FINAL PASS` marker all fail.

The companion imports production `shared/wear` and `shared/composition`. Its own
Tool prototype is test-only. A real powered ordinary inserter transfers one Tool
from a real chest to real belts on a surface with fixed map seed 12345. Every tick checks conservation of one item,
encoded health and independent durability, and the final assertion requires both
hand and belt observations. It runs production data/control loading but does not
implement or prove production pickup wear: production has no pickup events yet.
It does not prove blocked delivery, reload continuity, lab credit, mixture output,
other inserters, multiplayer behavior or compatibility. Historical probes remain
separate feasibility evidence. Only `mod/` and root `LICENSE` ship to players.
