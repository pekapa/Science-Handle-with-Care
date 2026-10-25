# Design decisions

This document describes current requirements and separates them from unresolved
implementation choices and tuning. It is not a development history.

## Accepted rules

- **Title:** Science, Handle With Care. Package ID: `science-handle-with-care`.
- **Every nonempty supported science subset is producible.** A single type passes
  through as the same ordinary pack. Combined types produce a fragile layered
  beaker, including mixtures no technology uses. Useless mixtures are never
  automatically corrected, rejected or denatured.
- **No player-selected mixer recipe.** At crafting start, consume one ordinary pack
  of each type present. Later deliveries do not change that craft. An idle enabled
  mixer starts immediately; players coordinate delivery timing. Every craft,
  including single-science pass-through, takes 60 powered ticks.
- **Input buffering is allowed.** The native assembler has two input slots, up to
  400 raw packs total, with either type able to occupy both. Its API does not
  provide a per-type one-pack cap. Red, green and combined outputs each have one
  slot; at most one completed craft waits for output space.
- **Wear values:** ordinary and burner cost 1; long-handed and fast cost 2; bulk and
  stack cost 4. Fresh health is 100%, each point removes 10 percentage points,
  nine points survive at 10%, and ten denatures. Ordinary science has no scripted wear.
- **Wear happens once at pickup.** Blocked holding and save/reload never charge the
  same pickup again. Denatured science stacks and receives no further wear.
- **One visible Lab, one physical science input slot.** Wrong science occupies and
  blocks the slot until removed. Matching science becomes native research credit;
  the persistent native worker's physical science input remains empty. Its stored
  credit can support continuous research while another item occupies the intake.
- **Native research remains authoritative.** Preserve per-worker credit through
  research changes, power pauses and reload. Mine all remaining credit into the
  Lab item's tags and restore it on rebuilding. Physical input and modules are
  separate balances. Do not manufacture fresh raw packs from fractional credit.
- **Progression:** the ordinary Lab retains its base item/entity name, recipe and
  early availability. Only the mixer unlocks with green science. Single-science
  research keeps ordinary packs; equal-quantity red+green research uses beakers.
- **Lab health rounding is acceptable after admission.** Transport must preserve
  individual wear; admitted beakers are committed to research consumption.
- **Preserve native machine windows and inventory operations.** The mixer keeps
  its assembler window and the Lab keeps its one-slot container window. Fixed
  internal recipe and filter details may remain visible; players still cannot
  select a mixer recipe. A relative panel exposes the hidden worker's status,
  power, research and real module inventory. Native windows own science transfers
  and mixer progress; supplemental labels show mixed-beaker health and durability.
- **Installable first playable:** limited normal-quality base-game red/green
  functionality belongs in the mod. Development scenarios do not ship.
- **Megabase batching and racks are deferred** until the basic gameplay loop works.

## Unresolved choices and tuning

Mixer power is initially 90 kW plus 3 kW drain. Handling costs and the nine-point
surviving budget need balance playtests. Denatured stack size is initially 1,000;
recovery is unimplemented. One pack per 1,000 waste and an unlock after 5,000
processed beakers remain proposals. Broader circuits, alternative transport,
unequal science quantities, quality, spoilage and compatibility remain open; see
[open questions](open-questions.md).

## Technical constraints

Different-health stacks can average their health, so usable mixed beakers are
nonstacking. Health records handling; Tool durability records research value.
Ordinary packs are Items and cannot represent fractional native credit as Tools.

Native lab allowlists cannot provide one shared untyped science slot. A visible
container intake and persistent hidden native lab worker satisfy that concrete
requirement. Preserve the worker's local credit rather than inferring it from
force-wide progress or an empty inventory.

The native mixer shell uses `return_ingredients_on_change = false` so exposing
`crafting_progress` does not refund its internal intake recipe on mining.
Runtime alone owns ingredient consumption and pending craft returns.

Follow [architecture](architecture.md) and [testing](testing.md). The revised lab
and interfaces need engine regression and graphical manual evidence; previous
checks do not establish their correctness. Stable and experimental compatibility
are validation targets, not assertions about untested builds.

Project-owned source and documentation use the MIT license with notices retained.
Factorio assets and binaries are not relicensed or redistributed by that license.
