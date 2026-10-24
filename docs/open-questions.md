# Open questions

Current requirements live in [decisions.md](decisions.md). This file describes
unresolved problems and when they must be answered. Move resolved requirements to
the current design rather than retaining a decision chronology here.

## Q01 — Megabase throughput and batch handling

Deferred until the basic research loop works. Nonstacking usable beakers constrain
inserter throughput, while stacking can average individual wear. Evaluate batching,
racks, hand capacity and belt-stack height without losing the handling challenge.
Denatured science stacking is already allowed.

## Q02 — Lab admission and buffering

Resolve during the research slice. A player places one visible lab; it may buffer
beakers after valid admission, and continuous research is desirable. What capacity
and admission mechanism meet that goal? There is no selected gated-shell design.

Test research changes, wrong mixtures, simultaneous and manual insertion, modules,
power, circuits, mining and reload. Health may round downward inside the lab once
committed to consumption. Native worker credit must survive; an empty inventory or
force-wide research progress cannot establish whether that worker has credit left.
The buffering direction still needs production implementation and engine evidence.

## Q03 — Every-subset prototype scale

Benchmark before expanding the supported set. N science types require 2^N - 1
mixture types, including unused mixtures. Measure loading, memory, filters and icon
usability. Compatibility changes must preserve every supported subset.

## Q04 — Wear tuning and tracking edge cases

Resolve during handling playtests and before release. Starting costs are ordinary,
burner and long-handed 1, fast 2, bulk and stack 4. The proposed safe budget is ten.
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

## Q09 — Mixer start, timing and blocked states

Define before mixer implementation. Crafting-start input sampling and consumption
of one pack per present type are settled; same-tick delivery is not required.
Choose the start trigger, processing time, energy and output-blocking behavior.

Prefer at most one input pack per type if feasible; raw-pack buffering is an allowed
fallback. Determine capacity, duplicate handling and intake during output blockage.
Preserve items and every nonempty subset. Boundary and blockage tests must prove
that deliveries after crafting starts cannot change its mixture.

## Q10 — Circuits, compatibility and performance

Implement after the basic loop and verify before broader release. Expose original
science requirements after technology conversion. Define supported labs, surfaces,
quality, overhauls, multiplayer and save migration. Stable and experimental builds
are intended validation targets, not untested compatibility claims. Benchmark
entity tracking and lifecycle registration as scale increases.
