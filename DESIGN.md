# Science, Handle With Care

This is the gameplay design for a Factorio mod in development. The repository
contains an installable red/green prototype and isolated production regressions.
A graphical manual playtest remains required before declaring the milestone complete.

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
craft. An idle, enabled mixer starts as soon as any supported science ingredient is
available. There is no automatic collection window: players coordinate deliveries
with inserters and circuits. The prototype processes for 60 powered ticks at
90 kW plus 3 kW drain. A completed blocked craft waits without consuming more
ingredients.

A small intake accepting at most one pack per type is the preferred logistics
challenge if feasible. Raw-pack buffering is an acceptable fallback; any buffered
extras remain inputs for later crafts. The prototype uses two native raw-pack
slots, allowing up to 400 raw packs total; either type can occupy both slots.
The native assembler intake does not provide a per-type one-pack cap. Conserve inputs and output when blocked, and expose enough
status for players to understand when crafting will begin.

## Handling

Charge wear once when an inserter picks up a usable beaker. Holding a beaker during
a blocked delivery adds no further wear, including across save/reload. Belts and
splitters add no pickup charge. Each inserter pickup, including final lab loading,
counts; internal crafting does not itself imply a transport charge.

Ordinary and burner inserters cost 1 per pickup, long-handed and fast inserters
cost 2, and bulk and stack inserters cost 4. A beaker survives ten agitation
points and denatures above ten. These are the initial playable values. Tooltips
explain costs; native item health indicates remaining handling allowance.

The prototype encodes wear in item health, independent of research durability.
Different-health stacks can merge with averaged health, so usable beakers must
preserve individual wear during transport. Usable beakers are nonstacking in the prototype. Bots, loaders, manual moves and modded inserters need
a declared policy before release.

## Labs and research

Players place one visible lab. Native research and each worker's stored science
credit remain authoritative. A beaker must match the research composition to be
consumed. Wrong mixtures may wait unused inside the lab until matching research
uses them, or the player removes them. The lab may buffer beakers; there is no
global one-physical-beaker limit across intake and research machinery. Continuous research
is desirable, and the prototype uses native lab input slots and stored credit.

Inside the lab, beakers are committed to consumption, so health may round downward
there. This permission does not relax wear preservation during transport. Preserve
native research timing, quantities, power behavior and credited science through
research changes, removal and reload. An empty input inventory does not imply
stored research credit is exhausted, and force-wide progress cannot identify a
particular worker's credit. The prototype uses a persistent native lab, without
a hidden worker.

Circuit support should expose mixer contents and state, and original science
requirements after technologies consume combined beakers. Wrong or unused mixes
must remain removable rather than disappearing on a research change.

## Progression and waste

Single-science research uses its ordinary science pack directly. The mixer and
beaker lab unlock alongside green science, with no additional technology.
Equal-quantity red+green research uses combined beakers. No extra empty-glass
production chain is currently planned.

Denatured science stacks and receives no further wear. Give it a distinct name and
appearance from military science. Disposal should be available before recovery so
mistakes cannot block progression. Stack size, recovery ratio, unlock trigger and
output selection are unresolved tuning. The prototype stacks 1,000 waste and
provides no recovery recipe. Candidate recovery values are one unlocked ordinary
pack per 1,000 waste, with an unlock after 5,000 processed beakers.

## Scope and technical constraints

The first playable target is an installable normal-quality red/green mod with all
three nonempty subsets. Development showcase saves or sandbox scenarios stay
outside the distributed mod. Stable and experimental Factorio compatibility are
intended test targets, not promises; exact configured builds and validation live in
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
