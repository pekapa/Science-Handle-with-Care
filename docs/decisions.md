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
  occur on the same tick; later arrivals do not change the active craft.
- **Input buffering is allowed.** At most one pack per type is the preferred
  challenge if feasible; raw-pack buffering is an acceptable fallback. Its
  implementation and capacity remain unproven.
- **Wear happens once at pickup.** Blocked holding and save/reload must not charge
  the same pickup again. Denatured science stacks and receives no further wear.
- **One visible placed lab; native research remains authoritative.** A lab may
  buffer beakers after valid admission. There is no shared one-physical-beaker cap.
  Continuous research is desirable; buffer capacity is unresolved.
- **Lab health rounding is acceptable after admission.** A beaker committed to lab
  consumption may round downward in health. Transport must preserve individual wear.
- **Preserve research credit.** Native worker credit, rather than force-wide
  progress or an empty input inventory, determines that worker's remaining science.
- **Megabase batching and racks are deferred** until the basic gameplay loop works.

## Unresolved choices and tuning

- Mixer start trigger, duration, input capacity, and output-blocking policy.
  A first-arrival window is a candidate, not a required sampling rule.
- Wear budget of ten, with denaturing above ten; ordinary/burner/long-handed cost 1,
  fast cost 2, and bulk and stack cost 4 are the starting tuning values.
- Integer wear encoded in item health, using binary-exact steps, is the current
  helper model; production transport still needs validation with that representation.
- Lab admission mechanism, buffer size, GUI/circuits, power and lifecycle behavior.
  A gated shell and hidden worker are not an architectural commitment.
- Conventional early red research and a mixing unlock before mixed-science research.
- Denatured stack size 1,000, recovery of one pack per 1,000 waste, and an unlock
  after 5,000 processed beakers are candidate balance values only.
- Policies for alternative transport, unequal science quantities, quality,
  spoilage and wider compatibility. See [open questions](open-questions.md).

## Technical constraints

- Different-health items can average their health when merged. Usable beakers need
  individual wear preserved outside the lab; nonstacking items are the initial
  representation to evaluate. Stack size, hand capacity and belt height differ.
- Native lab allowlists do not impose one total item across all accepted types.
  That limitation does not require a strict intake gate under the current design.
- Native labs can retain science credit after their input inventory becomes empty.
  Replacing a worker without preserving that credit loses science value.
- Existing isolated checks establish bounded engine behavior, not production mixer,
  buffering, wear or lab correctness. The foundation is not a playable release.

## Engineering and delivery

Follow [architecture](architecture.md) and [testing](testing.md): separate pure
rules, prototypes and runtime behavior; use isolated real-engine regressions for
Factorio claims. Public PR checks run without secrets. Stable and experimental
compatibility are intended validation targets; untested builds are not supported
by assertion. The initial gameplay scope is a small red/green demonstration.

Project-owned source and documentation use the MIT license with notices retained.
Factorio assets and binaries are not relicensed or redistributed by that license.
