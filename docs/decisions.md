# Design decisions

This document describes current requirements and separates them from unresolved
implementation choices and tuning. It is not a development history.

## Accepted rules

- **Title:** Science, Handle With Care. Package ID: `science-handle-with-care`.
- **Every nonempty supported science subset is producible.** Each has its own
  layered beaker, including mixtures no technology uses. Useless mixtures are not
  automatically corrected, rejected or denatured.
- **No player-selected mixer recipe.** At crafting start, the types present define
  the mixture. Consume one ordinary pack of each present type. Deliveries need not
  occur on the same tick; later arrivals do not change the active craft. An idle,
  enabled mixer starts immediately when any supported ingredient is available.
  There is no collection window; players coordinate delivery timing.
- **Input buffering is allowed.** At most one pack per type is the preferred
  challenge if feasible; raw-pack buffering is an acceptable fallback. The
  prototype uses the native assembler's two input slots, up to 400 raw packs total
  with either type able to occupy both, because it does not provide a per-type
  one-pack limit.
- **Initial wear values:** ordinary and burner cost 1; long-handed and fast cost 2;
  bulk and stack cost 4. Ten points survive; above ten denatures.
- **Installable first playable:** limited red/green functionality belongs in the
  mod; development showcase saves/scenarios do not ship in the package.
- **Wear happens once at pickup.** Blocked holding and save/reload must not charge
  the same pickup again. Denatured science stacks and receives no further wear.
- **One visible placed lab; native research remains authoritative.** Wrong mixtures
  may enter and wait unused until matching research consumes them, or the player
  removes them. Buffering is allowed; there is no shared one-physical-beaker cap.
- **Progression:** single-science research keeps its ordinary science pack. Unlock
  the mixer and beaker lab alongside green science, without an extra technology.
  Equal-quantity red+green research consumes combined beakers.
- **Lab health rounding is acceptable after admission.** A beaker committed to lab
  consumption may round downward in health. Transport must preserve individual wear.
- **Preserve research credit.** Native worker credit, rather than force-wide
  progress or an empty input inventory, determines that worker's remaining science.
- **Megabase batching and racks are deferred** until the basic gameplay loop works.

## Unresolved choices and tuning

- Mixer values are initial technical defaults: 60 powered ticks, 90 kW plus 3 kW
  drain; two native input slots; one output slot per mixture and at most one pending
  craft. A completed blocked craft waits without consuming additional inputs.
- Wear is encoded in item health with binary-exact steps, independently of native
  science durability. Broader transport and scale remain to be validated.
- Broader lab GUI/circuit policy and balance. The prototype uses one persistent
  native lab, with native slots, modules, power and credit.
- Denatured stack size is initially 1,000. Recovery is not implemented; one pack
  per 1,000 waste and an unlock after 5,000 processed beakers remain proposals.
- Policies for alternative transport, unequal science quantities, quality,
  spoilage and wider compatibility. See [open questions](open-questions.md).

## Technical constraints

- Different-health items can average their health when merged. Usable beakers need
  individual wear preserved outside the lab; usable prototype beakers are
  nonstacking. Stack size, hand capacity and belt height differ.
- Native lab allowlists do not impose one total item across all accepted types.
  That limitation does not require a strict intake gate under the current design.
- Native labs can retain science credit after their input inventory becomes empty.
  Replacing a worker without preserving that credit loses science value.
- Maintained isolated scenarios exercise production mixing, pickup wear, research
  and real reload. Exact scope belongs in the testing guide; a graphical manual
  playtest is still outstanding.

## Engineering and delivery

Follow [architecture](architecture.md) and [testing](testing.md): separate pure
rules, prototypes and runtime behavior; use isolated real-engine regressions for
Factorio claims. Public PR checks run without secrets. Stable and experimental
compatibility are intended validation targets; untested builds are not supported
by assertion. The initial gameplay scope is a small red/green demonstration.

Project-owned source and documentation use the MIT license with notices retained.
Factorio assets and binaries are not relicensed or redistributed by that license.
