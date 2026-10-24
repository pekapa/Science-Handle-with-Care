# Open questions

Current requirements live in [decisions.md](decisions.md). This file describes
unresolved problems and when they must be answered. Move resolved requirements to
the current design rather than retaining a decision chronology here.

## Q01 — Megabase throughput and batch handling

Deferred until the basic research loop works. Nonstacking usable beakers constrain
inserter throughput, while stacking can average individual wear. Evaluate batching,
racks, hand capacity and belt-stack height without losing the handling challenge.
Denatured science stacking is already allowed.

## Q02 — Lab buffering and usability

The prototype uses one persistent native lab, with native input slots and stored
credit. Wrong mixtures may wait unused until matching research consumes them, or
the player removes them. No gate or hidden worker is required. Native inventory
filters cannot enforce current-research admission, which is unnecessary under the
accepted buffering rule.

Playtest whether the native buffer and status are understandable. Broader circuit,
module and quality policies remain open; preserve per-lab credit when extending
these behaviors.

## Q03 — Every-subset prototype scale

Benchmark before expanding the supported set. N science types require 2^N - 1
mixture types, including unused mixtures. Measure loading, memory, filters and icon
usability. Compatibility changes must preserve every supported subset.

## Q04 — Wear tuning and tracking edge cases

Resolve during handling playtests and before release. Initial costs are ordinary and burner 1, long-handed and fast 2, bulk and stack 4.
The initial safe budget is ten.
Are these costs legible and challenging? Define modded-inserter costs and verify
partial hand additions, filter changes, mining/rotation, quality speeds and
simultaneous pickups. Blocked holding must never repeat the pickup charge.

## Q05 — Alternative transport

Decide during prototype playtesting. Define bots, loaders, manual moves, dropped
items, trains and modded transport without making the handling rules obscure.

## Q06 — Unused mixtures and disposal

Resolve during prototype playtesting. Unused subsets remain valid beakers. Define
how players remove, store or dispose of them, and whether recovery accepts them.
Never automatically correct or denature a mixture because research cannot use it.

## Q07 — Mixture quantities, spoilage and quality

Resolve before expanding beyond the normal-quality red/green demonstration. Each
craft consumes one ordinary pack of each present type. How do technologies with
unequal science quantities map to beakers without duplication or lost value? Define
batch ratios, mixed qualities and agricultural science freshness separately.

## Q08 — Recovery progression and balance

Revisit after waste is playable. Candidate values are 5,000 processed beakers to
unlock recovery, 1,000 waste per returned science and a waste stack size of 1,000.
Confirm eligibility, randomness and costs through playtesting. Disposal must be
available before recovery to avoid progression deadlocks.

## Q09 — Mixer tuning

The prototype starts immediately when an idle enabled mixer has any supported
ingredient. There is no collection window. It consumes one pack of each type
present; later arrivals belong to later crafts. Players synchronize delivery or
use circuit disable while loading.

Initial technical defaults are 60 powered ticks, 90 kW plus 3 kW drain, two native
raw-pack input slots (up to 400 packs total, either type in either slot) and one
output slot per mixture. A completed craft waits when
its output slot is blocked; at most one craft is pending. Native input stacks are
the practical buffering fallback rather than a one-pack-per-type limit.

Playtest whether these capacities, timing and status produce a useful logistics
challenge. A tighter intake would need a concrete engine-supported implementation.

## Q10 — Circuits, compatibility and performance

Implement after the basic loop and verify before broader release. Expose original
science requirements after technology conversion. Define supported labs, surfaces,
quality, overhauls, multiplayer and save migration. Stable and experimental builds
are intended validation targets, not untested compatibility claims. Benchmark
entity tracking and lifecycle registration as scale increases.
