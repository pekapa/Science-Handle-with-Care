# Project architecture

The first milestone is a playable red/green logistics experiment. The repository
currently provides a foundation, not the production gameplay loop. Stable and
experimental Factorio builds are intended validation targets; exact builds belong
in configurable test targets. Keep dependencies small: Lua for the mod and Python's
standard library for test orchestration and packaging.

## Boundaries

| Location | Responsibility |
| --- | --- |
| `mod/data.lua` | Register prototypes; delegate to `mod/prototypes/` when needed |
| `mod/control.lua` | Register events and route them to runtime features |
| `mod/shared/` | Pure rules shared by stages; no Factorio globals or mutable global state |
| `mod/runtime/` | Future mixer, pickup, lab and lifecycle behavior |
| `mod/prototypes/` | Future generated items, machines, recipes and technologies |
| `mod/locale/en/` | Future player-facing names, descriptions and status messages |
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

Prefer one input pack per type if feasible; raw-input buffering is an allowed
fallback. Start trigger, capacities and blocked-output behavior need validation
before implementation is considered complete. This is a design requirement, not a
claim that buffering or the mixer has been demonstrated.

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

Expose one visible placed lab. Preserve native research, quantities, timing and
per-worker stored credit. Admit beakers valid for research, with buffering allowed
after admission; do not impose a global single-beaker limit. Continuous research
is a design goal. The admission mechanism and buffer capacity remain unproven.
There is no selected gated-shell or hidden-worker architecture.

Beakers committed to consumption inside the lab may round downward in health.
Outside the lab, individual wear must survive transport and cannot be averaged
away. An empty input inventory does not prove a worker has no science credit;
force-wide research progress cannot substitute for its own stored credit. Preserve
items and credit on research changes, power interruption, removal and reload.

Validate the simplest lab implementation against these requirements before adding
technical entities. Any additional entities must have a defined shared lifecycle,
GUI, circuit, module and energy policy, with no orphaning, duplication or silent loss.

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
