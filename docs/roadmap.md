# Roadmap

## Red/green prototype

The mod contains an automatic mixer, ordinary red/green pass-through, fragile
red+green beakers, pickup wear and stackable waste. Only the mixer unlocks with
green science. The ordinary Lab retains early availability and gains one physical
science slot. Wrong science blocks that slot; matching science becomes native
credit, and mining stores remaining credit on the Lab item.

The revised Lab and native machine windows are under validation. Basic setup
and the transport line have received manual inspection; the revised interface
still needs a graphical playtest of the installed ZIP.

The maintained isolated engine suite exercises shipped production code, including
actual save/reload during crafting, holding and native stored credit. See
[testing](testing.md) for scope and exact commands. Development showcase material
stays outside the distributed mod.

Before closing the playable milestone, complete the production scenario matrix,
run stable and experimental CI targets, and perform a graphical manual playtest
of the installed ZIP and starter layout. Automated checks alone do not establish
usability or balance.

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
