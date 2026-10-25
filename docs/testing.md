# Testing and CI

Tests establish observable behavior, not implementation shape. Use a few focused
cases with explicit invariants instead of coverage quotas, empty mocks or large
end-to-end suites that cannot identify the failure.

For engine invocation, consult the official [command-line parameters](https://wiki.factorio.com/Command_line_parameters).
For API behavior, use the documentation shipped with the exact tested engine;
the online [runtime API](https://lua-api.factorio.com/latest/) can move ahead of our
baseline. Tool configuration follows [StyLua](https://github.com/JohnnyMorganz/StyLua),
[Luacheck](https://github.com/lunarmodules/luacheck) and
[Ruff](https://docs.astral.sh/ruff/configuration/).

## Local checks

From the repository root, install Python 3.11+, a Lua 5.2-compatible interpreter
(LuaJIT works for the current pure helpers), Luacheck and StyLua. Python lint tools
are pinned in `requirements-dev.txt`; install them in a virtual environment.
CI configuration records the formatter and Lua linter versions.

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/pre-commit install
make test
make lint
make package
```

Activate the environment or put `.venv/bin` on PATH before `make lint`.
`make format` applies formatting; check its diff before submitting. Missing tools
must fail rather than silently reducing validation.

The pre-commit hook runs `make test lint` before every commit, checking the staged
snapshot (pre-commit temporarily stashes unstaged changes). It uses `.venv/bin`
when present, so the installed hook does not require an activated environment.
Lua, Luacheck and StyLua must still be on PATH. Install the hook once per clone;
Git does not install repository hooks automatically. To run it manually:

```sh
.venv/bin/pre-commit run --all-files
```

These checks cover pure rules, package/runner contracts and lint without starting
Factorio or downloading tools. Real-engine validation remains a separate check
and runs in CI for both configured channels. Hooks can be bypassed, so CI remains
the merge gate.

`make test` discovers named standard-library
`unittest` cases: pure Lua rules, engine-runner contracts, and manifest/archive checks.
Use `python3 scripts/test.py --list` to list cases without running them,
`--suite unit` or `--suite package` for a focused run, and `--suite all` to include
the real engine. New Python cases belong in `tests/test_<suite>.py`; pure Lua
cases in `tests/unit/*.lua` are discovered automatically. No Python test framework
dependency is needed. Standalone `python3 scripts/package.py` remains supported.
The local suite does not prove Factorio API behavior. `make package` builds a local ZIP, without installing it.

Use your own matching Factorio binary for isolated engine checks:

```sh
FACTORIO_BIN=/absolute/path/to/factorio make test-engine
FACTORIO_TARGET=2.1.23 FACTORIO_BIN=/absolute/path/to/factorio make test-engine
```

See [the integration harness](../tests/integration/README.md) for runner options,
current assertions and output locations. It runs only its own process with
temporary configuration, mods and saves. Never use the player's normal mod folder,
write-data path or save. A timeout, engine error, missing binary or missing final
assertion is a failure. Preserve logs for diagnosis.

## Development showcase

`FACTORIO_BIN=/absolute/path/to/factorio python3 scripts/create_showcase.py`
generates `build/showcase/science-showcase.zip` using a fresh isolated profile,
mods, write-data and server settings. For a graphical binary it also writes
`build/showcase/launch.sh`; run that launcher to use the new profile. Existing
profiles are left untouched. It only terminates its own server process. The
scenario asserts actual mixed-beaker transport, pickup wear, power and native
research progress, saves, then independently reloads and asserts further research.
It verifies that only base and the production mod are active. The generated save,
logs and scenario sources are excluded from the production package.

This automated showcase validation is not a graphical manual playtest. Basic
setup and the transport line have been manually inspected; the revised single-slot
Lab and custom interfaces still need graphical verification. Follow the reproducible
[manual playtest checklist](manual-playtest.md) with the installed ZIP. Keep
personal saves separate. The revised local Factorio 2.1.23 suite exercises genuine
robot mining/reconstruction, credit tags, unchanged three-science research and
stacked or already-tagged Labs in the intake. GUI appearance and player transfers
are not established by those headless assertions. Check the current PR results
for stable and experimental CI evidence.

## Layers and their limits

| Layer | Evidence | Does not establish |
| --- | --- | --- |
| Pure Lua | Composition identity, invalid input rejection, wear boundaries and encoding | Entity events, hand behavior or native research |
| Package checks | Manifest, source contents, license and archive integrity | A playable mod or engine load success |
| Production engine scenarios | Packaged mixing, pickup wear, native research and real save/reload with actual machines | Manual usability or untested compatibility |
| Manual revised interfaces (outstanding) | Readable status, setup, interactions and understandable failures | Automated regression coverage |

Earlier engine experiments are engineering evidence, not the maintained regression
suite. Port the smallest relevant case into `tests/integration/` when implementing
its production behavior. Test fixtures may create entities and initialize state;
they must not reimplement the behavior under test and claim production coverage.

## Required scenarios for the playable milestone

| Scenario | Observable assertions |
| --- | --- |
| Recipe-free mixing | Red/green return the same ordinary pack after 60 powered ticks; red+green produces a fragile beaker; start-time ingredients determine output |
| Immediate start and blockage | Correct boundary ticks; blocked output neither loses ingredients nor duplicates output; bounded buffering |
| Pickup and stalled delivery | One wear charge per pickup; hundreds of held ticks add no charges; next pickup charges again |
| Wear failure | Nine survives at 10% health, ten converts; count conserved; waste stacks and has no further wear |
| Single-slot lab admission | Exactly one physical input slot; wrong science blocks until removed; matching science becomes credit; worker physical science input stays empty |
| Machine interface | Real player opening builds character/machine panels and generic slots; production transfer actions preserve stack metadata and respect input, output and module restrictions; mixer progress follows the actual powered craft; graphical checks cover appearance and genuine mouse interactions |
| Native research | Expected count/time; local cached credit consumed once; another same-force lab cannot corrupt this lab's stored credit |
| Persistence and power | Actual save/reload mid-hand and mid-credit; no double charge/lost credit; unpowered worker retains credit |
| Lifecycle | Mining/rebuild preserves raw and mixed fractional credit in Lab item tags, input and modules; research changes/removal do not orphan workers or duplicate credit |

Reload means serialize a real save, stop that owned test process, and launch a
second process from the save. Calling `on_load` manually or keeping a Lua table
alive is not a persistence test. Each scenario needs a bounded tick budget, a
named assertion failure and a completion marker. Attach seed, engine/mod versions,
commands and logs to a failure.

Start each gameplay slice with a red test. Confirm it fails for the intended
missing behavior, implement until green, then refactor. When engine setup makes
TDD impractical, explain the exception and add the regression in the same change.

## CI policy

Public pull requests run static, pure Lua and packaging checks, plus stable and
experimental headless engine jobs on disposable hosted runners without secrets.
`scripts/engine-targets.json` defines the shared supported series, base dependency,
default channel and CI channel matrix. Set `FACTORIO_TARGET` to `stable`,
`experimental`, or an exact `X.Y.Z` build; `FACTORIO_BIN` always selects the local
executable and never downloads anything. Local channel selectors accept an installed
build in the configured series; they do not contact the network to check freshness.
Exact targets require the actual build to match. CI downloads the current channel
from the official HTTPS endpoint, records the downloaded archive SHA-256 as
evidence (not independent authenticity verification), and preserves logs plus
actual runtime version/build output and mod version in `runtime.json`. Keep CI tools
versioned and workflow permissions read-only. Never use `pull_request_target` to execute contributor code, and never
send public PR code to a persistent self-hosted machine.

When the repository is published on GitHub, require `check` and both `engine` matrix
statuses before merging to `main`. The workflow is defined here; repository branch
protection still needs to be enabled on GitHub.

Real-engine results are a separate gate for gameplay changes. Extend the engine
suite with production behavior scenarios as each gameplay feature is implemented;
the initial smoke test alone does not meet the playable milestone matrix. An
unavailable download or a channel moving outside the configured supported series
fails explicitly; update the supported series only as a deliberate
compatibility change. Exact-version local runs provide reproducible regressions.

Before a playable release, require the gameplay scenario matrix, a real reload
test, installation from the built ZIP and a manual starter-layout playtest. No
release or mod-portal upload is automatic.
