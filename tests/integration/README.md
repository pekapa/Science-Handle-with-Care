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
- The Lab has one physical intake slot. Competing raw and mixed science insertions
  accept zero items while wrong science occupies it. A separate powered inserter
  must hold a beaker at blocked delivery for 100 consecutive ticks, preserving its
  count and pickup wear with no research admission. Removing the wrong science
  must allow real delivery and native research by tick 400. The worker's physical
  science inventory remains empty. Native stored credit, research timing, power
  pauses, research switches and independent labs are observed.
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

## Optional real-player GUI regression

Use a disposable test save that already contains a connected character/player:

```sh
python3 scripts/gui_runner.py --factorio /absolute/path/to/factorio \
  --target 2.1.23 --player-save /absolute/path/to/isolated-player-save.zip
```

`FACTORIO_BIN`, `FACTORIO_TARGET`, `--data-dir` and `--timeout` work as in the
engine runner. This optional test does not run in the default headless suite:
creating a player with the script API does not supply the real player needed by
native GUI events. Make the seed in a separate test profile, with room beside
the character for a mixer and Lab. Never supply a personal save or normal profile.
No save or proprietary binary is committed or distributed.

The runner builds the current production ZIP and copies the seed into temporary
isolated configuration/mod/write-data directories. Only the copy's scenario
`control.lua` is replaced by `gui-validation-fixture/control.lua`; production code
is unmodified. It enables base and the production mod, disables bundled optional
mods, and runs 60 updates. The supplied save is read only; its SHA-256 is checked
again afterward. The fixture intentionally changes the copied player's inventory.

Assigning the actual mixer/Lab to `player.opened` generates genuine native open
events. Assertions inspect the actual production window: horizontal character and
machine panels, native player-inventory binding, preview, separate electricity and
craft bars, two/three mixer slots, one Lab input, two real worker module slots,
generic empty slots, displayed worn-beaker health, timed crafting refresh, close,
switch/reopen and out-of-reach cleanup. Slot identity is checked with actual item
contents; the fixture does not reproduce the GUI implementation.

The same fixture calls the production transfer helper used by GUI handlers with
real player, cursor and machine inventories. It checks left/right take/place,
merge/swap, worn nonstacking beakers and tagged items, module restrictions,
extraction-only outputs, shift/control transfer counts and conservation when the
player inventory is full. These are production action/API checks; they do not
claim physical mouse clicks, GUI event routing or visual usability. Those still
need the [manual checklist](../../docs/manual-playtest.md).

`build/gui-test-results/` retains `version.log`, `runtime.json` (including the seed
save hash), `benchmark.log`, and `screenshots.json`. Exact engine target matching,
nonzero exits, errors, timeouts and a missing/duplicate `SCIENCE_GUI_FINAL PASS`
all fail. The scenario requests genuine GUI screenshots, but benchmark mode may
skip rendering; only files actually produced are retained. An empty screenshot
list establishes no visual evidence.
