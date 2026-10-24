# Science, Handle With Care

This is the gameplay design for a Factorio mod in development. The repository
contains a mod foundation and isolated validation tools; the mixer, wear tracking
and lab gameplay loop are not implemented or validated as a playable mod.

## Core experience

Mix ordinary science packs into fragile layered beakers, then transport them
carefully to research. Players coordinate deliveries with inserters and circuits.
The mixer has no player-selected recipe: the science types present when crafting
starts determine the mixture. Research does not fill in missing ingredients or
correct a player's mixture.

Every nonempty subset of supported science types has a distinct beaker, including
mixtures no technology uses. A useless mixture remains that mixture; it is not
rejected or automatically denatured. A beaker retains its composition when research
changes. Red+green does not substitute for red+green+blue.

## Mixing

At crafting start, sample the input types and consume one ordinary science pack of
each present type to define one beaker. Inputs need not arrive on the same tick;
only their presence at the start matters. Later arrivals cannot change an active
craft. The start trigger, processing time and blocked-output behavior still need
an explicit implementation policy and engine tests.

A small intake accepting at most one pack per type is the preferred logistics
challenge if feasible. Raw-pack buffering is an acceptable fallback; any buffered
extras remain inputs for later crafts. Neither approach has been demonstrated in
production gameplay. Conserve inputs and output when blocked, and expose enough
status for players to understand when crafting will begin.

## Handling

Charge wear once when an inserter picks up a usable beaker. Holding a beaker during
a blocked delivery adds no further wear, including across save/reload. Belts and
splitters add no pickup charge. Each inserter pickup, including final lab loading,
counts; internal crafting does not itself imply a transport charge.

The working balance proposal gives ordinary, burner and long-handed inserters a
cost of 1, fast inserters 2, and bulk and stack inserters 4. Stack cost 4 is the
current starting tuning value.
A proposed budget allows ten agitation points and denatures a beaker above ten.
These values need playtesting; tooltip wording should show composition and the
remaining handling budget once gameplay exists.

Item health is a candidate wear representation, independent of research durability.
Different-health stacks can merge with averaged health, so usable beakers must
preserve individual wear during transport. Nonstacking items are the initial
representation to evaluate. Bots, loaders, manual moves and modded inserters need
a declared policy before release.

## Labs and research

Players place one visible lab. Native research and each worker's stored science
credit remain authoritative. A beaker must match the research composition when
admitted. Once validly admitted, the lab may buffer beakers; there is no global
one-physical-beaker limit across intake and research machinery. Continuous research
is desirable, and buffer size and admission behavior need engine validation.

Inside the lab, beakers are committed to consumption, so health may round downward
there. This permission does not relax wear preservation during transport. Preserve
native research timing, quantities, power behavior and credited science through
research changes, removal and reload. An empty input inventory does not imply
stored research credit is exhausted, and force-wide progress cannot identify a
particular worker's credit. No intake shell or hidden-worker architecture is
selected; implementation must first validate the simpler buffering direction.

Circuit support should expose mixer contents and state, and original science
requirements after technologies consume combined beakers. Wrong or unused mixes
must remain removable rather than disappearing on a research change.

## Progression and waste

Early conventional science and a mixing unlock before mixed-science research are
bootstrap proposals. No extra empty-glass production chain is currently planned.

Denatured science stacks and receives no further wear. Give it a distinct name and
appearance from military science. Disposal should be available before recovery so
mistakes cannot block progression. Stack size, recovery ratio, unlock trigger and
output selection are unresolved tuning. Candidate values are a stack size of
1,000, recovery of one unlocked ordinary pack per 1,000 waste, and an unlock after
5,000 processed beakers. None is settled balance.

## Scope and technical constraints

The first playable target is a normal-quality red/green demonstration with all
three nonempty subsets. Stable and experimental Factorio compatibility are intended
test targets, not promises; exact configured builds and validation live in
[the testing guide](docs/testing.md). Space Age, quality, spoilage, overhauls and
megabase batching require separate design and evidence.

Generate mixture identifiers from stable sorted science names. The number of
mixture prototypes grows as 2^N - 1; expanding supported science needs a scale and
usability check. Technologies with unequal ingredient quantities need an explicit
mapping before conversion; subset identity alone does not settle their value.

Keep runtime state in `storage`, track relevant entities without per-tick world
scans, and verify Factorio behavior with isolated engine scenarios exercising
production code. See [decisions](docs/decisions.md), [architecture](docs/architecture.md)
and [open questions](docs/open-questions.md) for requirements and remaining work.

## Inspiration

Wiwiweb's [Big Bottle comment](https://www.reddit.com/r/Factoriohno/comments/1xa4w60/comment/phqx5wc/)
inspired the mixing concept. This is an independent implementation.
