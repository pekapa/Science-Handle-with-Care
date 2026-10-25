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

`make lint` also runs `scripts/lua_docs.py`, which needs
[LuaLS](https://luals.github.io/) (`lua-language-server`, 3.19.2 in CI) and Node.js 22.7+.
It fails when a top-level function under `mod/` lacks a `---` doc comment, then runs
`lua-language-server --check` with `.luarc.json`. That check reports unknown parameter
names, incomplete signatures and type names missing from the Factorio API. On first
run, the script generates the API definitions into `build/luals/` from the online
`latest` documentation, using the pinned Factorio Modding Tool Kit CLI. Delete
`build/luals/` to regenerate them after a Factorio release. Only documentation
diagnostics gate the build; LuaLS type-flow checks are disabled.

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
`--suite unit` or `--suite package` for pure-rule or distribution checks,
`--suite engine_runner`, `--suite gui_runner`, `--suite input_runner` or
`--suite graphical_preflight` for runner contracts, and `--suite all` to include
the real engine. New Python modules named `tests/test_<suite>.py` are discovered
automatically; local execution excludes the explicit `engine` suite. Pure Lua
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

## Test organization and lifecycle

Pure-rule specifications live in `tests/unit/` and `test_unit.py`. Distribution
checks live in `test_package.py`; process and evidence contracts live in their
runner-specific Python suites. The engine suite orchestrates the production ZIP
and test-only companions. The [architecture guide](architecture.md#test-architecture)
defines these boundaries.

The [gameplay fixture](../tests/integration/validation-fixture/README.md) separates
world setup, real-entity helpers, domain scenarios and suite orchestration. Its
small control file only registers events. Case actions and expectations stay
adjacent; shared persistent state lives in `storage.fixture`. Tick-dependent
Lab/robot/research cases form one ordered workflow, so they are verified together
rather than presented as independent tests.

The Python engine runner owns profile setup and teardown. It creates a bootstrap
world, loads production and the gameplay companion, saves at tick 120, stops that
owned process, and resumes at tick 121 in another process. Domain completion
assertions run before the final marker at tick 2400. Only then does the fixture
stop its tick work and the runner discard the isolated world. Changes to these boundaries require the existing engine outcome checks and
actual reload; mocks of Factorio entities or assertions about file size do not
establish correctness.

## Development showcase

`FACTORIO_BIN=/absolute/path/to/factorio python3 scripts/create_showcase.py`
generates `build/showcase/science-showcase.zip` using a fresh isolated profile,
mods, write-data and server settings. For a graphical binary it also writes
`build/showcase/launch.sh`; run that launcher to use the new profile. Its isolated
configuration enables sprite atlas caching for subsequent launches. Existing
profiles are left untouched. It only terminates its own server process. The
scenario asserts actual mixed-beaker transport, pickup wear, power and native
research progress, saves, then independently reloads and asserts further research.
It verifies that only base and the production mod are active. The generated save,
logs and scenario sources are excluded from the production package.

This automated showcase validation is not a graphical manual playtest. Basic
setup and the transport line have been manually inspected; the revised single-slot
Lab and native windows with relative information panels still need graphical verification. Follow the reproducible
[manual playtest checklist](manual-playtest.md) with the installed ZIP. Keep
personal saves separate. The revised local Factorio 2.1.23 suite exercises genuine
robot mining/reconstruction, credit tags, unchanged three-science research and
stacked or already-tagged Labs in the intake. GUI appearance and player transfers
are not established by those headless assertions. Check the current PR results
for stable and experimental CI evidence.

## Layers and their limits

| Layer                             | Evidence                                                                                                           | Does not establish                                                       |
| --------------------------------- | ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| Pure Lua                          | Composition identity, invalid input rejection, wear boundaries and encoding                                        | Entity events, hand behavior or native research                          |
| Package checks                    | Manifest, source contents, license and archive integrity                                                           | A playable mod or engine load success                                    |
| Production engine scenarios       | Packaged mixing, pickup wear, native research and real save/reload with actual machines                            | Manual usability or untested compatibility                               |
| Real-player GUI scenario          | Production window construction, contents, refresh and lifecycle; production transfer actions with real inventories | Physical mouse events, rendered appearance or visual usability           |
| Graphical capture runner          | Production windows rendered by a graphical client; current PNGs and exact fixture/package identity                 | Visual usability without image inspection, or mouse/keyboard routing     |
| Optional native Lab input runner  | Simulated mouse removal of wrong science from the production Lab; count, health, quality and cursor assertions     | Module-widget events, physical OS input, or complete interface usability |
| Client input checks (outstanding) | Actual mouse/keyboard routing and resulting inventory/cursor outcomes                                              | Untested builds, resolutions or input combinations                       |

### Quiet GUI validation workflow

Run `make test lint package` before requesting a graphical validation. The GUI
runners then validate the seed archive and staged mod configuration and run an
isolated non-graphical engine preflight before opening a client. Use
`--preflight-only` to stop at that boundary. This catches packaging, dependency
and prototype-load errors early; it cannot prove rendering or input behavior.
A failed stage stops the command; there is no automatic graphical retry.

Prefer a single final session for both full-window captures and native input:

```sh
python3 scripts/input_runner.py --factorio /absolute/path/to/factorio \
  --target 2.1.23 --player-save /absolute/path/to/isolated-player-save.zip \
  --with-gui
```

This runs the mixer/Lab construction, action and capture cases before opening the
Factoriopedia input host in the same graphical process. Both suites must complete,
and all four PNGs must be valid. The separate runners remain useful for focused
failures. Graphical validation uses a windowed profile with audio disabled and may still
open/focus a window;
background or minimized rendering has not been established as equivalent.

Test profiles explicitly enable the sprite atlas cache and retain dedicated
write-data under ignored `build/` output. They never inherit the player's profile.
Only one run may own a cache profile at a time. The first launch builds the cache;
later launches can reuse it when Factorio considers it valid. Cache configuration
is not a measured loading-time improvement.

Fixture responsibilities and execution flow are documented beside the
[GUI fixtures](../tests/integration/gui-validation-fixture/README.md).
Factorio's asynchronous tick and simulation APIs need a small state machine, but
setup, actions, expectations and cleanup should remain named and separate.
Python owns subprocess/profile lifecycle and evidence; Lua owns real engine
setup and assertions. Never substitute mocks for actual inventories in engine
cases. Runner unit tests may mock subprocesses to verify that bad preflight
results prevent a graphical launch.

### GUI evidence and completion

Use the optional [real-player GUI runner](../tests/integration/README.md#optional-real-player-gui-regression)
when changing machine windows or transfer actions. It is separate from `make test`
and the normal headless gameplay suite. Run the relevant GUI assertions against
the packaged production code; invoking only native inventory methods does not
test production action logic. A direct production action call tests that action,
not the GUI event that would normally invoke it.

For layout changes, inspect a rendered capture at a recorded resolution and GUI
scale alongside the corresponding default Factorio window. For interaction
changes, exercise real client input and observe both the GUI event path and the
resulting cursor/inventory state. Include left/right, shift/control, occupied or
full destinations, module restrictions and item metadata when those paths change.
Screenshots alone cannot establish transfer correctness; helper tests alone
cannot establish event routing or appearance.

Report construction, action, client-input and visual results separately with the
engine build and package revision. A graphical client or screenshot unavailable
to the runner leaves that check unverified. Do not report an interface as fully
verified or the graphical milestone complete until the required layers pass.

Factorio exposes [simulation input controls](https://lua-api.factorio.com/latest/classes/LuaSimulation.html)
for test players, mouse actions and control presses. These apply inside a
simulation; a [simulation's `mods` list](https://lua-api.factorio.com/latest/types/SimulationDefinition.html#mods)
loads the production runtime scripts. The maintained input fixture uses the Lab's
Factoriopedia preview as that host. It assigns the native Lab window, resolves the
live input slot, sends a simulated mouse click and checks the resulting cursor,
count, health, quality and empty intake. It does not call the production transfer
helper. Window opening, module modifier events and physical OS input remain
outside that case's evidence.

The full-window GUI suite uses the connected outer player, checks production
construction and direct module actions, and captures the native Lab and mixer.
The input suite's outer before/after captures are diagnostic: the embedded
Factoriopedia preview can clip its window, and successful teardown may leave the
preview closed. Those images do not replace full-window captures or visual
inspection. The `--with-gui` mode runs both layers in one process and requires
both exact completion markers; it does not expand either layer's coverage.

Agents changing the GUI must open and inspect the current run's captures, not
infer appearance from logs. Record the package hash, actual engine build, capture
dimensions and GUI scale (or explicitly unknown scale), and describe any clipping,
overlap or unreadable text. Compare against the corresponding native machine
window. Keep generated captures and logs in ignored build output; include their
paths with the result so another agent or contributor can inspect the same run.
Never reuse a previous run's screenshots as evidence for changed code.

Standalone Factorio 2.1.23 build 87750 has completed the maintained graphical
fixture unattended. Its inspected 3024×1842 captures at 100% GUI scale show both
full native windows and relative panels. The Lab status text is ellipsized, and
module-slot backgrounds extend beyond the relative panel; retain these as visual
findings rather than declaring the layout finished. This evidence covers that
recorded build/package/display only; the runner's per-run metadata identifies the
tested package and fixture. Other display settings and genuine input remain
unverified.

Direct execution of the local Steam build can exit with a Steam restart request
before running the fixture. Launching the isolated benchmark through Steam's
`-applaunch 427520` route has produced both PNGs and the final assertion on 2.1.23.
Steam launcher exit alone is not game completion: require the isolated game log's
final assertion and automatic quit, plus the captures. A standalone build is not
required for graphical rendering, but is preferred for unattended local tests:
the observed Steam launch needed a user to accept a Steam prompt, so that run
does not establish unattended execution. Use the direct graphical runner with an
independent standalone installation when available. Never change a normal Steam
profile or terminate an existing player session to obtain test access.

Screenshot resolution must match the test player's display dimensions; requesting
a smaller image can clip the native window instead of scaling it. Keep the window
open until the frame has rendered: closing it or teleporting out of reach in the
same tick as a screenshot request can produce an image with no window. Inspect
the resulting images even when file integrity and scenario assertions pass.

Earlier engine experiments are engineering evidence, not the maintained regression
suite. Port the smallest relevant case into `tests/integration/` when implementing
its production behavior. Test fixtures may create entities and initialize state;
they must not reimplement the behavior under test and claim production coverage.

## Required scenarios for the playable milestone

| Scenario                     | Observable assertions                                                                                                                                                                                                                                                                                                                                                   |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Recipe-free mixing           | Red/green return the same ordinary pack after 60 powered ticks; red+green produces a fragile beaker; start-time ingredients determine output                                                                                                                                                                                                                            |
| Immediate start and blockage | Correct boundary ticks; blocked output neither loses ingredients nor duplicates output; bounded buffering                                                                                                                                                                                                                                                               |
| Pickup and stalled delivery  | One wear charge per pickup; hundreds of held ticks add no charges; next pickup charges again                                                                                                                                                                                                                                                                            |
| Wear failure                 | Nine survives at 10% health, ten converts; count conserved; waste stacks and has no further wear                                                                                                                                                                                                                                                                        |
| Single-slot lab admission    | Exactly one physical input slot; wrong science blocks until removed; matching science becomes credit; worker physical science input stays empty                                                                                                                                                                                                                         |
| Machine interface            | Real player opening preserves the native mixer/Lab entity window and constructs relative panels; the Lab module widget binds the real worker inventory; production modifier actions preserve module metadata and counts, including full destinations; mixer native progress follows the powered craft; graphical checks cover appearance and genuine mouse interactions |
| Native research              | Expected count/time; local cached credit consumed once; another same-force lab cannot corrupt this lab's stored credit                                                                                                                                                                                                                                                  |
| Persistence and power        | Actual save/reload mid-hand and mid-credit; no double charge/lost credit; unpowered worker retains credit                                                                                                                                                                                                                                                               |
| Lifecycle                    | Mining/rebuild preserves raw and mixed fractional credit in Lab item tags, input and modules; research changes/removal do not orphan workers or duplicate credit                                                                                                                                                                                                        |

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
