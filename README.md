# Science, Handle With Care

Mix your science. Mind the handling.

Turn ordinary Factorio science packs into fragile, layered beakers. Coordinate
inserters to make the mixture you want, then deliver it to research before too
much handling ruins it.

- **Ingredients choose the mixture.** The mixer takes one of each science type
  present when crafting starts, with no player-selected recipe.
- **Every mixture is possible.** Even a combination no technology needs is a
  valid beaker. Getting the ingredients right is your factory's job.
- **Every pickup counts.** Faster handling wears beakers more quickly. Belts and
  splitters let you move them without spending another transfer.
- **Mistakes leave waste.** Exhausted beakers become stackable denatured science.

The mod is an early red/green prototype. It implements mixing, pickup wear and
native research, with isolated engine regressions including actual save/reload.
It has not completed a graphical manual playtest and is not a published release.
Space Age, quality and overhaul compatibility are outside this demonstration.

Development is deliberately unstable: gameplay, code, identifiers and saved state
will change and may break. **Backward compatibility is not maintained during
development.** Expect to start fresh when changes invalidate existing saves or setups.

## Try the prototype

Run `make package` to build `build/science-handle-with-care_0.1.0.zip`.
Install that ZIP using your Factorio test profile's mods directory and enable
**Science, Handle With Care**. Use a fresh test save; development saves may break.
The configured engine series is Factorio 2.1; consult the
[testing guide](docs/testing.md) for evidence and limitations.

Research green science to unlock the **Science mixer** and **Beaker lab** recipes.
Each machine is crafted from its base-game counterpart and five electronic circuits.
Single-science research still uses ordinary packs. Technologies requiring equal
amounts of only red and green science instead consume red+green beakers, keeping
their original research count and time. Use the Beaker lab for these technologies;
ordinary labs cannot consume mixed beakers. Later science combinations remain conventional.

An idle powered mixer starts immediately when any supported pack is present. It
consumes one of each type present and takes one second of powered processing.
To make red+green, coordinate delivery before the mixer starts, or disable it with
a circuit condition while loading. Later arrivals belong to the next craft.
Red-only and green-only beakers are valid outputs even when no research uses them.
Raw packs may buffer in two native input slots (up to 400 packs total; either
type can occupy both slots). Each mixture has one output
slot; a blocked completed craft waits without consuming more inputs.

Usable beakers do not stack. Ordinary/burner pickups cost 1 handling point,
long-handed/fast cost 2, and bulk/stack cost 4. Ten points survive; the next point
turns the beaker into stackable denatured science. Belts and splitters add no wear;
blocked holding adds no repeated charge. Health drops 6.25 percentage points per
handling point; 37.5% is the last safe level. Manual moves
and bots currently add no scripted charge; broader transport rules remain open.
Wrong mixtures can wait unused in a Beaker lab until matching research uses them,
or you remove them. Mining returns unfinished mixer ingredients and recovers
fractional stored lab credit as a partially used science item. Recovered committed
beaker credit has its handling allowance rounded down to zero, so another inserter
pickup denatures it; move it manually if you want to reuse it.

For a supplied development layout, generate a separate showcase save:

```sh
FACTORIO_BIN=/absolute/path/to/factorio python3 scripts/create_showcase.py
```

Load `build/showcase/science-showcase.zip` with the production mod enabled and
bundled optional mods disabled. It provides synchronized red/green input arms,
power, mixed-science research and supplies when you join. The scenario and save
are development material, excluded from the distributed ZIP. Generator logs and
independent reload assertions remain under `build/showcase/`.

## Contribute

Start with [CONTRIBUTING.md](CONTRIBUTING.md). The
[design](DESIGN.md) explains the intended experience,
[decisions](docs/decisions.md) distinguish settled rules from tuning, and the
[roadmap](docs/roadmap.md) identifies the next playable milestone.

Code lives in `mod/`, automated tests in `tests/`. See the
[architecture](docs/architecture.md) for boundaries and the
[testing guide](docs/testing.md) for setup and commands. Compatibility targets are
the latest stable and experimental Factorio branches; test results identify the
actual builds checked. This is a support goal, not a claim of complete compatibility.

## License and inspiration

Project-owned code and documentation are [MIT licensed](LICENSE). Factorio and its
assets are separate; see [third-party notices](THIRD_PARTY_NOTICES.md).

Inspired by Wiwiweb's [Big Bottle concept](https://www.reddit.com/r/Factoriohno/comments/1xa4w60/comment/phqx5wc/).
This project is an independent implementation.
