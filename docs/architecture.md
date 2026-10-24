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
must exist, including unused mixtures. Keep subset generation separate from the
combinations research can consume, and identifiers stable across load ordering.

The mixer is a fixed-recipe assembling-machine shell with native separate input
and output inventories. The internal recipe supplies inventory filters only;
native crafting is disabled, and runtime owns sampling and processing. Never set
native `crafting_progress`: the engine would refund the intake recipe on mining,
duplicating script-owned materials. Two input slots allow up to 400 raw packs total,
with either type able to occupy both, as the practical buffering fallback. Output has one filtered slot per mixture.
One additional craft may wait for its mixture's blocked slot; no further inputs
are consumed until that output fits. Processing costs 60 powered ticks, 90 kW plus
3 kW drain, and circuit disable pauses it. These are initial prototype defaults.

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

Expose one persistent native lab. Its input allowlist includes ordinary science
and all three beakers. Wrong mixtures can wait removable and unconsumed; native
technology ingredients decide which item is consumed. No intake gate or hidden
worker is used. The prototype retains native lab slots, power and modules.

The final data stage converts only technologies using equal quantities of exactly
red and green science to combined beakers. Unit count and time are retained.
Single-science and later combinations remain conventional. Mixer and lab recipes
unlock with the existing green-science technology.

Beakers committed to consumption inside the lab may round downward in health.
Outside the lab, individual wear must survive transport and cannot be averaged
away. An empty input inventory does not prove a worker has no science credit;
force-wide research progress cannot substitute for its own stored credit. Preserve
items and credit on research changes, power interruption, removal and reload.

On removal, recover stored native credit as a partially used Tool, independently
of physical input inventory. Keep its fractional durability. Native stored credit
does not retain health, so recovered beaker credit receives the conservative
maximum surviving wear of ten, rather than refreshing its handling allowance; force-wide progress
cannot represent that local balance. Any future technical entities need a defined
shared lifecycle, with no orphaning, duplication or silent loss.

## First playable slices

1. **Mixtures:** red, green and red+green items; crafting-start sampling, one pack
   per present type, explicit start and buffering policy, and blocked-output behavior.
2. **Handling:** once-per-pickup wear through real transport and reload; stackable
   waste without further wear. Starting costs and budget are tuning, not proof of balance.
3. **Research:** valid admission and buffering through one visible lab; native
   research and stored credit preserved through pauses, changes and reloads.
4. **Playable scenario:** readable status/tooltips, starter layout, removal and
   rebuilding, and a manual playtest alongside automated regressions.

Start each gameplay slice with a failing behavior test when feasible, implement the
smallest change, then refactor. Keep racks, recovery, Space Age, quality and overhaul
support outside this milestone. See [testing](testing.md) for required evidence.
