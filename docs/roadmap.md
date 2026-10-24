# Roadmap

## Foundation

The repository contains pure composition and wear helpers, package tooling and an
isolated real-engine harness. These establish a development foundation; production
mixer, pickup tracking and lab buffering gameplay are not implemented or proven.

Known constraints inform the design: item health can represent wear separately
from research durability, differently worn stacks can average health on merging,
and native workers can retain credit after input items disappear. Translate these
constraints into maintained production regressions as each feature is implemented.

## First playable demonstration

- One recipe-free mixer accepting red and green science. At crafting start,
  consume one ordinary pack of each present type; deliveries need not be simultaneous.
- All three nonempty subsets, including unused mixtures; explicit start timing,
  input capacity and blocked-output behavior. Prefer one pack per type if feasible,
  with raw-pack buffering available as a fallback.
- Once-per-pickup wear, stackable denatured science and understandable tooltips.
- One visible lab with valid admission, buffering and native authoritative research.
  Validate capacity and continuous feeding without committing to a gated shell.
- A starter layout, status presentation and safe removal/rebuilding behavior.

Exit condition: production code completes the isolated red/green research loop,
preserves inputs, wear and credit across actual reloads, and passes a short manual
playtest. Follow [architecture](architecture.md) and [testing](testing.md). Settle
mixer timing, capacities and admission behavior before calling the loop playable.

## Tune the challenge

Playtest start timing, processing time, handling budget and inserter costs. Stack
inserters start at cost 4, the same as bulk; this remains tunable balance. Define
alternative transport and disposal. Add layered graphics, circuit status and an
original-science research signal interface.

## Expand and harden

Generate every nonempty supported subset at larger scale, resolve unequal science
quantities, and add progression and recovery. Test research changes, forces,
surfaces, multiplayer and larger factories. Validate intended stable and
experimental engine targets using configured builds, and report their actual scope.

Megabase batching and racks remain deferred until the basic loop works. Space Age,
quality, spoilage and overhaul support require separate evidence. Preserve unused
mixtures throughout expansion; see [open questions](open-questions.md).
