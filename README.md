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

The mod is in development. The repository contains the design, shared rules and
a testable package foundation; **there is no playable release yet**. The first
playable milestone is a small red/green mixing and research loop.

Development is deliberately unstable: gameplay, code, identifiers and saved state
will change and may break. **Backward compatibility is not maintained during
development.** Expect to start fresh when changes invalidate existing saves or setups.

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
