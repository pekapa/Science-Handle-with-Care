# Project architecture

The first milestone is an installable red/green logistics experiment. Production
mixing, handling and native research are implemented; a graphical manual playtest
remains outstanding. Stable and
experimental Factorio builds are intended validation targets; exact builds belong
in configurable test targets. Keep dependencies small: Lua for the mod and Python's
standard library for test orchestration and packaging.

## Boundaries

| Location | Responsibility |
| --- | --- |
| `mod/data.lua` | Register prototypes; delegate to `mod/prototypes/` when needed |
| `mod/control.lua` | Register events and route them to runtime features |
| `mod/shared/` | Pure rules shared by stages; no Factorio globals or mutable global state |
| `mod/runtime/` | Mixer, pickup and lifecycle behavior |
| `mod/prototypes/` | Items, machines and recipes |
| `mod/locale/en/` | Player-facing names, descriptions and status messages |
| `tests/unit/` | Executable specifications of pure rules |
| `tests/integration/` | Test-only Factorio fixtures and engine assertions |
| `scripts/` | Validation, isolated engine runner and distribution tooling |
| `docs/` | Current design, testing and milestone acceptance criteria |
| `.github/` | Pull request guidance and CI |

Create feature directories with their first implementation. Avoid empty modules,
speculative abstractions and placeholder tests. Only `mod/` and the root license
belong in the distributable; test mods never ship to players.

Development versions do not maintain backward compatibility. Replace obsolete
interfaces and saved-state formats directly, updating callers, tests and docs
together. Do not retain legacy structures or add migrations solely to support
earlier development versions. Persistence and save/reload within the current
version must still preserve items and research credit.

## Test architecture

Tests have three execution boundaries. Pure Lua specifications exercise rules
without Factorio. Python contracts exercise packaging and runner behavior, using
owned subprocesses or process mocks where appropriate. Engine fixtures exercise
the packaged production mod with actual entities and inventories. Importing a
Python test or listing suites must not launch the game; the `engine` suite is
explicitly selected.

| Component | Responsibility |
| --- | --- |
| `scripts/test.py` | Discover Python suites, select local or explicit engine execution, report results |
| Python runners in `scripts/` | Stage isolated profiles/packages, own child-process lifetimes, validate completion and retain evidence |
| `graphical_preflight.py` | Validate graphical test inputs and mod configuration; own reusable test-cache locking |
| `graphical_support.py` | Shared save-copy, PNG integrity and source-identity utilities; no CLI or process lifecycle |
| Fixture `control.lua` | Register engine events and delegate to the fixture lifecycle |
| Gameplay `suite.lua` | Order scenario steps and own checkpoint, resume and final completion |
| Gameplay `setup.lua` and `fixture_support.lua` | Initialize the test world and provide real entity/inventory operations |
| Domain case modules | Perform named gameplay actions and assert their observable outcomes |

The gameplay fixture's mixer, handling and Lab cases are cooperating workflows,
not independently isolated unit cases. Keep their tick order explicit in the
suite. Store references and observations in `storage.fixture`; requiring a module
must not capture saved state or mutate the world. The Python runner serializes a
checkpoint, stops its process, and reloads it in another process. Completion stops
fixture tick work; disposal of the isolated Python profile owns final world
teardown. Do not remove entities before persistence assertions finish.

Keep expectations near the actions whose results they check. Extract shared
helpers only for repeated mechanics; never reproduce production mixing, wear,
admission or credit logic in a fixture. Small bootstrap and showcase scenarios
can remain cohesive files. File length alone is not a reason to introduce a
module. See the [gameplay fixture guide](../tests/integration/validation-fixture/README.md)
and [GUI fixture guide](../tests/integration/gui-validation-fixture/README.md)
for their concrete execution order and resource ownership.

## Prototype and runtime rules

Generate mixture prototypes in the data stage. At crafting start, runtime samples
present input types and consumes one ordinary pack of each type to determine the
output. Later deliveries do not alter that craft. Every nonempty supported subset
must be producible, including unused mixtures. Single-type outputs keep the
ordinary science item; only combined outputs are fragile beakers. Keep subset generation separate from the
combinations research can consume, and identifiers stable across load ordering.

The mixer is a fixed-recipe assembling-machine shell with native separate input
and output inventories. The internal recipe supplies inventory filters only;
native crafting is disabled, and runtime owns sampling and processing. Runtime
sets native `crafting_progress` to expose the actual 60-powered-tick craft cycle.
The prototype sets `return_ingredients_on_change = false`: without it, the engine
would refund the internal intake recipe when mining a progressing shell and
duplicate script-owned ingredients. Runtime returns committed inputs itself.
Two input slots allow up to 400 raw packs total, with either type able to occupy
both. Three output slots accept ordinary red, ordinary green and combined beakers.
A completed blocked craft waits without consuming additional ingredients.
Processing costs 90 kW plus 3 kW drain; circuit disable pauses it.

Machine windows remain engine-owned: GUI code never replaces `player.opened`.
The mixer uses its native assembler inventory, progress and power controls; the
Lab uses a native container with one normal inventory slot, without chest bars or
filters. Fixed internal mixer recipe/filter details may be visible; the prototype
still prevents recipe selection. Science and player-inventory transfers use the
native window without scripted slot buttons or a duplicate character inventory.

`runtime/gui.lua` attaches a relative information panel to the open machine.
The Lab panel reads actual worker status, power and force research, and binds an
inventory widget directly to the worker module inventory, with an explicit empty
module-slot sprite and localized hint. A separate row for each current research
ingredient reads the worker's native stored durability as remaining standard-pack
credit (all current packs have a full value of one). Its bar shows that balance,
not a percentage of the originally admitted damaged beaker; its tooltip gives the
actual remaining value. Research changes rebuild the ingredient rows, and no
research clears them. Force research progress remains a separate display. The widget enables
native cursor transfer/split; its modifier actions call `player.stack_transfers`
with the real worker source and player main inventory destination. No stack copies
are constructed. The supplemental health/durability label reads the Lab intake or
mixed mixer output. Refreshes inspect only tracked open panels, removing them on
close, invalid entity/worker, disconnection or loss of reach.

Use `storage` for serializable persistent state; local tables are caches only.
Rebuild local references in `on_load` without mutating game state. Handle entity
creation, removal, cloning, force/surface changes and invalid references explicitly.
Centralize event registration so features cannot overwrite each other's handlers.
Use stable ordering when iteration affects simulation. Avoid wall-clock time,
filesystem access, unseeded randomness and player-local state in simulation logic.

Track relevant entities on build and removal, using bounded active sets and event
filters. Do not scan the world each tick. Optimize after reproducible measurements.
Pickup tracking must charge once even when delivery is blocked or a save is reloaded.

## Lab boundary

The ordinary `lab` item and placed entity retain their base identifiers, recipe
and availability. The visible entity is a one-slot container intake, paired with a
persistent invisible, collision-free native lab worker. This worker is necessary
because native lab inventories cannot enforce one shared untyped physical slot.
The worker supplies native power, modules, research timing and stored credit.
Its physical science input remains empty.

Admission checks the selected technology against the actual intake stack. Wrong
science remains removable and blocks that one slot. Matching ordinary science adds
one unit of native credit; matching combined science adds the Tool's remaining
durability. No script increments force research progress. Previously admitted
credit remains on the worker through research changes, power pauses and reload.

The final data stage converts only technologies using equal quantities of exactly
red and green science. Unit count and time remain unchanged. Single-science and
later combinations remain conventional. Only the mixer recipe unlocks with green
science. Superseded separate beaker-lab and singleton-beaker identifiers are removed;
development versions do not need aliases or migrations.

Health records handling wear; durability records research value. Admitted beakers
may round downward in health, but transport cannot average individual wear away.
An empty science inventory does not prove a worker has no credit, and force-wide
research progress cannot identify its local balance.

On mining, retain all native credit in the mined `lab` item's tags and restore it
on placement. Raw science packs are Items, so fractional raw credit cannot be
returned as partially used packs. Preserve physical input and modules separately
using native inventory returns. The visible intake and worker share lifecycle
handling: removal must not orphan a worker, duplicate credit or silently discard
items. Persist references and balances in `storage`, including across real reload.

## Removal integration limits

Normal player and robot mining supplies the actual mining-result buffer, allowing
credit to travel with one returned Lab item. Raised death and destruction paths
recover available physical items and native credit before deleting the worker.

External scripts calling `LuaEntity.mine` with `raise_destroyed=true` expose a
destruction event without the mining-result buffer. That route cannot be reliably
distinguished from destruction and is outside the current integration contract
for credited Labs. Other mods must not assume this programmatic mining path is
compatible. Direct deletion of the hidden worker without raising events also makes
its native credit inaccessible; the visible intake is retained as unavailable,
not reported as a successful recovery. No general other-mod lifecycle compatibility
is claimed.

## First playable slices

1. **Mixtures:** ordinary red/green pass-through and fragile red+green; crafting-start sampling, one pack
   per present type, explicit start and buffering policy, and blocked-output behavior.
2. **Handling:** once-per-pickup wear through real transport and reload; stackable
   waste without further wear. Starting costs and budget are tuning, not proof of balance.
3. **Research:** matching admission through one physical input slot; native
   research and stored credit preserved through pauses, changes and reloads.
4. **Playable scenario:** readable status/tooltips, starter layout, removal and
   rebuilding, and a manual playtest alongside automated regressions.

Start each gameplay slice with a failing behavior test when feasible, implement the
smallest change, then refactor. Keep racks, recovery, Space Age, quality and overhaul
support outside this milestone. See [testing](testing.md) for required evidence.
