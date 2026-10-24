# Contributing

Science, Handle With Care is a Factorio mod foundation, not a playable release.
Contributions, forks and adaptations are welcome under the [MIT license](LICENSE).
Contributions are supplied under that same license; no CLA is required.

Read [the architecture](docs/architecture.md), [accepted decisions](docs/decisions.md)
and [testing guide](docs/testing.md) first. Humans and AI assistants follow the
same behavior and evidence standards; [AGENTS.md](AGENTS.md) summarizes them.
Keep design documents focused on current rules and open choices, without dated
experiment narratives or verbatim user quotes. Separate implemented behavior,
engine constraints and unvalidated gameplay intent. Stable and experimental builds
are intended validation targets; record exact tested builds with results.

## Development workflow

Backward compatibility is not maintained during development. Change or remove
existing interfaces, identifiers, data formats and gameplay when the current design
needs it, even if saves or setups break. Update callers, tests and current docs in
the same change; remove superseded code instead of adding compatibility layers,
legacy aliases or save migrations solely to preserve earlier development versions.

1. Choose one small observable behavior or bug. Discuss changes to accepted
   mechanics in an issue or pull request and record the resulting decision.
2. Write a focused failing test when feasible. Use pure Lua for rules and the real
   Factorio engine for inventories, logistics, research and persistence.
3. Implement the smallest change that passes, then refactor. Keep test fixtures
   deterministic and separate from the shipped mod.
4. Run the relevant checks in [docs/testing.md](docs/testing.md), document engine
   version and results, and explain any checks you could not run.
5. Open a focused pull request explaining the player-visible result and evidence.

Install the local pre-commit hook with `.venv/bin/pre-commit install` after setting
up the development tools. It runs the foundation tests and lint before commits;
see [the testing guide](docs/testing.md) for setup and manual execution.

Use two spaces in Lua, four in Python, UTF-8 and LF endings. StyLua and Ruff
define formatting; Luacheck and Ruff catch static issues. Keep names descriptive,
entrypoints small, and comments about intent or engine constraints. Avoid broad
lint suppressions; justify narrow exceptions near the relevant code.

For engine API claims, include a matching official documentation link or an
isolated executable regression test. A mock of an entity cannot establish its
actual inventory, hand, lab or save/load semantics.

## Assets and attribution

Submit only work you can license. Reference base-game graphics by Factorio paths;
do not redistribute Factorio binaries or copied proprietary assets. Record any
third-party asset's source, author and license in `THIRD_PARTY_NOTICES.md` before
adding it. Do not assume inspiration grants permission to copy text or artwork.

Do not include personal configurations, saves, credentials, engine downloads,
logs or generated archives in a contribution. Test in isolation from normal play.
