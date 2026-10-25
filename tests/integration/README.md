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

Real robot events are exercised; genuine player placement/mining and GUI
interaction still need client checks. Native window appearance, cursor and
bulk transfers, readability and reach/window behavior need manual evidence. Cross-surface
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
mods, and runs 80 updates. The supplied save is read only; its SHA-256 is checked
again afterward. The fixture intentionally changes the copied player's inventory.

Assigning the actual mixer/Lab to `player.opened` generates genuine native open
events. Assertions verify production keeps that entity open, attaches a relative
panel to the matching native window, and retains two/three mixer slots and one
normal Lab input slot without bar/filter controls. The Lab widget binds the real
worker's two module slots with native cursor handlers enabled. The fixture checks
supplemental mixed-beaker health, powered native crafting progress, close,
switch/reopen, reach cleanup and entity-removal cleanup.

The fixture directly calls the production module inventory action handler with
real inventories. All four stack/inventory transfer/split actions must conserve
modules and health, full destinations retain the source stack, and unrelated
widgets cannot trigger module transfers. These are production action/API checks;
they do not establish native science cursor/keyboard handling, genuine modifier
GUI event routing or rendered usability. Those still need the
[manual checklist](../../docs/manual-playtest.md). No helper-only transfer tests
claim native window input correctness.

Add `--graphics` to require rendered evidence using the installed graphical
binary's `--benchmark-graphics` mode. Both `lab-gui.png` and `mixer-gui.png` must
have a valid PNG signature, header dimensions and complete checksummed chunks,
and the final assertion must pass. Ordinary benchmark mode establishes only
construction/action assertions; it can pass without screenshots. Neither mode
exercises genuine mouse or keyboard input.

Prefer a standalone graphical installation for unattended tests. It uses the
direct command above with `--graphics`; no Steam launcher is needed. On macOS,
a restricted process without desktop access can fail during Cocoa startup before
the fixture loads. Report that as a failed run and use an execution context with
graphical-session access. Keep the isolated configuration and save arguments.

For the macOS Steam installation, add the explicit launcher path while retaining
`--factorio` for version/data discovery:

```sh
python3 scripts/gui_runner.py --factorio /absolute/path/to/factorio \
  --target 2.1.23 --player-save /absolute/path/to/isolated-player-save.zip \
  --graphics --steam-launcher /Applications/Steam.app/Contents/MacOS/steam_osx
```

This launches Factorio app 427520 through Steam with the isolated config, mods and
copied save. Steam can require a confirmation prompt; a run requiring that prompt
is not evidence of unattended execution. The runner first checks `ps -axo pid=,comm=` and refuses if Factorio
already runs or that inventory cannot establish its absence. Steam's launcher
exit does not establish completion: the runner monitors only the isolated
`write-data/factorio-current.log` for exactly one final assertion, automatic quit
and `Goodbye`, rejects engine errors, and requires both valid PNGs. It validates
the actual Steam-launched build from that log against the requested target.
The timeout bounds monitoring. On timeout the game may still be running; the
runner signals neither Steam nor Factorio. Its isolated directory remains on disk
and is recorded in `runtime.json`, including on failure; after confirming the
owned test game has exited, that directory can be removed. Normal player
configuration and the source seed remain untouched.

`build/gui-test-results/` retains `version.log`, `runtime.json`, `benchmark.log`
and `screenshots.json`, plus any produced PNGs. Steam runs also retain
`launcher.log` and their isolated directory. The runner removes previous run
evidence first. `runtime.json` records the current outcome/mode, errors, actual
engine/build output, package SHA-256, source revision/dirty status, source/copy
save hashes and the hash of the exact fixture bundle inserted into the copy
(`fixture_sha256`; a lone control script uses its byte hash).
Screenshot dimensions come from PNG headers; GUI scale comes from the engine
log’s `UIScale` entry, or is explicitly unknown when absent. Captures use the test
player's actual display resolution and keep each window open through its render
frame. A failed run records failure
instead of retaining an earlier pass. Exact engine target matching, nonzero exits,
errors, timeouts and missing/duplicate `SCIENCE_GUI_FINAL PASS` all fail.

Inspect both retained PNGs with an image viewer before reporting appearance as
verified. Compare the native mixer and Lab window layouts, relative panel
placement, clipping and readability at the recorded dimensions and an observed
GUI scale. Record that inspection separately; a graphics runner pass confirms
artifact production, not visual usability. A separate `visual-review.json` may
record inspection findings and screenshot/package hashes; the runner removes
that review on each new run and keeps its own visual inspection unverified.
Genuine client input still requires
the [manual checklist](../../docs/manual-playtest.md).

## Preflight, batching and sprite cache

Before graphical validation, run `make test lint package`. Both graphical runners
perform archive/configuration checks and a non-graphical engine load before
opening a window. `--preflight-only` stops there and leaves preflight evidence;
this is not a GUI pass. The runner stops on failure without retrying the client.

For one final graphical session instead of two separate launches:

```sh
python3 scripts/input_runner.py --factorio /absolute/path/to/factorio \
  --target 2.1.23 --player-save /absolute/path/to/isolated-player-save.zip \
  --with-gui
```

The outer player runs the production window/capture cases, then the Factoriopedia
host runs the native input case. Completion requires both suites and four PNGs.
The client uses a windowed test profile with audio disabled. This is one visible
client, not a claim of invisible/minimized GUI execution.

Dedicated test write-data retains the enabled sprite atlas cache under ignored
`build/` output. A profile lock prevents concurrent reuse. Normal player settings
and saves are never used; temporary mods/config/save staging remains isolated.
The first run must build the cache and engine invalidation can rebuild it. No
loading-time improvement is claimed until measured. Do not delete a retained
profile lock without establishing that its test process has exited.

Read [the fixture guide](gui-validation-fixture/README.md) for setup, execution,
expectations, teardown and the distinction between production action calls and
simulated client input.

## Optional native Lab input regression

Use a **standalone graphical binary** and an ordinary disposable connected-player
save made in an isolated profile:

```sh
python3 scripts/input_runner.py --factorio /absolute/path/to/factorio \
  --target 2.1.23 --player-save /absolute/path/to/isolated-player-save.zip
```

`--data-dir`, `FACTORIO_BIN`, `FACTORIO_TARGET` and `--timeout` are supported;
the positive timeout is capped at 120 seconds. Add `--with-gui` to run the full-window
capture cases and native input case in one graphical session. This optional suite
is separate from the headless gameplay suite. Its Python runner contracts run
in the normal local suite without a game. No Steam launch or network access is
performed. The runner starts, stops and reaps only its own direct subprocess.
A startup error, premature exit (including exit zero), named fixture failure,
missing/duplicate exact `LAB_INPUT_FINAL PASS`, missing/corrupt PNG or timeout fails.

The runner packages production as a ZIP, installs that ZIP and the test companion
in temporary isolated mod/config/write-data directories, and copies the seed.
Only the copy's scenario script is replaced with an inert script. With `--with-gui`,
the GUI case modules are staged in the test companion. The original
seed bytes are hashed before and checked after execution. Never provide personal
saves; no proprietary save or binary is distributed with these tests.

After a connected outer player has existed for 240 ticks, the companion opens the
Lab's Factoriopedia simulation. That simulation loads production and the companion,
creates a test player, builds a production Lab using the raised build event, and
finds the real hidden native worker. It activates red-only Automation research
through `force.add_research` after its prerequisite. One wrong green science pack
(count 1, health 0.6, normal quality) must block the one physical input slot.
The fixture assigns the native Lab window, waits for production panel construction,
resolves the documented live native input-slot position, moves the simulation
cursor, and sends an actual left mouse click. The pack must reach the cursor with
unchanged metadata, the intake must empty, and the production module widget must
remain bound to the actual worker module inventory. No production helper is called
and no transfer logic is copied into the fixture. Missing targets fail; no guessed
or stale coordinates are used.

`build/input-test-results/` retains `client.log`, `version.log`, `runtime.json`,
`lab-input-before.png` and `lab-input-after.png` when produced. Each run clears its
previous evidence. Metadata records exact engine/build version output, production
package hash and version, source revision/dirty state, companion file hashes and
bundle hash, inserted scenario hash, source/copied seed hashes, launch commands,
outcome, capture dimensions and observed GUI scale (or unknown). PNGs are required
along with the exact input and host-cleanup final assertions; the runner allows a final capture/log flush
before terminating its own still-live host.

This proves the native Lab **input pickup** boundary at the recorded build and
settings. Window opening is assigned, and module clicks, modifier actions, split,
placement, full destinations and other input combinations remain unverified.
The before/after images show the outer Factoriopedia host: its embedded simulation
may clip the machine GUI. They do not replace the full-window captures or visual
inspection required by the graphical suite. Inspect and report captures separately;
a file-integrity check does not establish readability or complete visual usability.

## Fixture responsibilities

The [gameplay fixture guide](validation-fixture/README.md) maps setup, support,
domain cases, ordered dispatch and checkpoint ownership. The
[GUI fixture guide](gui-validation-fixture/README.md) describes window, action,
simulation-input and cleanup boundaries. Python runners own isolated filesystem
profiles and processes; Lua fixtures own scenario actions and outcome assertions.
The bootstrap fixture prepares the pre-install world only. The showcase remains
a separate development layout and does not replace either regression suite.
