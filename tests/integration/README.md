# Production engine validation

Run `FACTORIO_BIN=/absolute/path/to/factorio make test-engine`, or
`python3 scripts/engine_runner.py --factorio /absolute/path/to/factorio`.
Use `FACTORIO_TARGET=2.1.23` for an exact-build regression. Channel selectors
`stable` and `experimental` verify the installed series locally without checking
network freshness. CI downloads the current official channels. Shared targets
live in `scripts/engine-targets.json`.

The runner builds the production ZIP and uses isolated temporary mods, config,
write-data and save directories. First, a bootstrap companion creates a world
with existing inserters and green science researched, without the production mod.
It then disables that companion and installs the packaged production mod plus
the gameplay validation companion into the existing save. Bundled optional mods, including recycler,
are explicitly disabled for the normal-quality red/green scope. It never installs
into the player's normal directories. Each engine command has a 120-second timeout
(`--timeout SECONDS`). Missing tools, timeouts, nonzero exits, engine errors and
missing completion markers fail.

The runner discovers `data/core` and `data/base` relative to standard macOS app and
Linux/Windows archive executable layouts. Supply `--data-dir PATH` for a custom
installation. The fixture uses fixed seed 12345.

The companion creates actual production mixers, inserters and a native beaker lab.
It checks all three recipe-free mixtures, immediate start and exact 60-tick
processing, late-arrival sampling, blocked output, connected circuit pause/resume,
unpowered behavior, pickup costs and ten/eleven wear boundaries. Real belts preserve
wear between two distinct pickups. Other checks cover persistent blocked holding,
wrong mixtures, native research timing, research switches and independent credit
in two same-force labs. Mining checks cover unfinished materials, held beakers,
failed full-inventory scripted mining and fractional stored credit recovery/rebuilding.
Destruction checks conserve pending and buffered materials. Bootstrap assertions
check existing inserters take wear and already-researched green science unlocks
the new recipes.
It creates test-only research prototypes to keep assertions bounded; it does not
reimplement mixing, wear or research progress.

The first owned process runs to tick 121 and serializes a checkpoint at tick 120,
with a mixer midcraft, an inserter holding a worn beaker and a paused lab holding
fractional native credit. A second process loads that saved state and runs 1,100 benchmark ticks, requiring
the final assertion at tick 1,200. The fixture
requires checkpoint/resume assertions and exactly one final
`SCIENCE_VALIDATION_FINAL PASS` engine marker. Calling `on_load` directly is not
used as a substitute for reload.

Temporary state is deleted. Logs remain in `build/test-results/`:
`version.log`, `create.log`, `checkpoint.log`, `benchmark.log` and `runtime.json`.
Runtime metadata records actual engine/build output, target, mod version and seed.
CI also preserves the downloaded archive SHA-256; this identifies the archive,
not independently verified upstream authenticity.

These checks establish bounded production behavior on the actual recorded engine.
They do not drive player or robot mining events through a graphical client; those
post-success event subscriptions are verified by code review. They also do not
establish graphical usability, multiplayer performance, Space Age,
quality or overhaul compatibility. The manual installed-ZIP starter-layout
playtest remains outstanding. Development showcase sources and generated saves
are excluded from the production ZIP.
