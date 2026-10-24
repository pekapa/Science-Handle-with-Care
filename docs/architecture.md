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

The custom machine interface binds directly to real native inventory slots and
reads native progress. Internal recipe controls and typed filter ghosts are hidden
from that interface. Inventory movement must keep Factorio's native semantics;
GUI code must not simulate transfers with copied stacks.

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
