# Production engine validation

Run `FACTORIO_BIN=/absolute/path/to/factorio make test-engine`, or
`python3 scripts/engine_runner.py --factorio /absolute/path/to/factorio`.
Use `FACTORIO_TARGET=2.1.23` for an exact-build regression. Local channel selectors
verify the installed series; CI downloads current official stable/experimental
channels. Shared targets live in `scripts/engine-targets.json`.

The runner packages the production mod and uses isolated temporary configuration,
mods, write-data and saves. A bootstrap companion creates a world with existing
inserters and green science researched, without the production mod. It then disables
that companion and installs the ZIP plus the gameplay validation companion into
the existing save. Bundled optional mods, including recycler, are disabled.
Nothing is installed into normal player directories.

Each command has a 120-second timeout (`--timeout SECONDS`). Missing tools, timeouts,
nonzero exits, engine errors and missing completion markers fail. The runner finds
`data/core` and `data/base` in standard macOS app and Linux/Windows archive layouts;
pass `--data-dir PATH` for a custom installation. Seed is fixed at 12345.

## Production scenarios

The fixture creates real mixers, inserters, ordinary Lab intakes and native workers.
It observes production behavior rather than implementing mixing or research itself.
Test-only technologies keep research assertions bounded.

- Ordinary red/green pass through unchanged after 60 powered ticks; combined inputs
  produce a fragile mixed beaker. Native crafting progress, start boundaries,
  later arrivals, circuits, power and blocked output are checked.
- Real transport checks pickup costs, linear wear with nine surviving and ten
  denaturing, belt transport between distinct pickups, blocked holding and waste.
- The Lab has one physical intake slot. Wrong science blocks it; the worker's
  physical science inventory remains empty. Native stored credit, research timing,
  power pauses, research switches and independent labs are observed.
- Genuine construction robots mine and rebuild a credited Lab using the actual
  returned tagged item. No synthetic player events or manually copied ghost tags
  substitute for that roundtrip. Raw/mixed fractional credit and modules are checked.
- Other lifecycle cases cover unfinished mixer mining, held beakers, failed
  full-inventory mixer mining, destruction, duplicate builds, native clones,
  same-surface movement and raised worker removal.
- Bootstrap checks existing inserters take wear and existing green-science research
  unlocks the mixer.

## Actual save and reload

A private loopback server runs with public/LAN visibility and user verification
disabled, and automatic pause off. At tick 120 the fixture serializes a named
autosave with a mixer midcraft, an inserter holding a worn beaker and paused native
credit. The runner waits for the assertion and a complete ZIP, stops only its own
server, then loads that autosave in a separate process.

The resumed process runs 2,300 benchmark updates and requires the final assertion
at tick 2,400. Robot phases poll actual delivery/build/research conditions, with
bounded failure deadlines. Checkpoint/resume markers and exactly one
`SCIENCE_VALIDATION_FINAL PASS` are required. Calling `on_load` directly is not a
persistence test.

## Evidence and limits

Temporary engine state is deleted. `build/test-results/` retains `version.log`,
`create.log`, `checkpoint.log`, `benchmark.log` and `runtime.json`. Metadata records
actual engine/build output, target, mod version and seed. CI also records the
downloaded archive SHA-256, which identifies the archive rather than independently
verifying upstream authenticity.

Real robot events are exercised; genuine player placement/mining and custom GUI
interaction still need client checks. Generic empty-slot appearance, cursor and
bulk transfers, readability and reach/window behavior are manual tests. Cross-surface
movement and arbitrary other-mod entity manipulation are not supported by assertion.
See [architecture](../../docs/architecture.md) for scripted-removal limits and
[the manual checklist](../../docs/manual-playtest.md) for client verification.
Space Age, quality, overhauls and multiplayer performance remain outside this scope.
Fixtures, showcase sources and generated saves are excluded from the production ZIP.
