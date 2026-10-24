# Reading the mod code

This guide is a suggested route through the code for someone new to Factorio
modding. Open the linked files beside this document in your editor. Start with one
behavior and follow its calls before trying to understand every edge case.

## 1. Understand the two stages

Factorio first loads definitions: what items, machines, recipes and technologies
exist. This is the **data or prototype stage**. A prototype is a template, not an
individual machine placed on the map.

When a save starts running, Factorio loads event handlers that interact with real
machines, inventories and players. This is the **runtime or control stage**.

A useful distinction:

- `data.raw` holds prototype definitions during startup.
- `game` gives runtime access to forces, surfaces and entities inside event handlers.
- `storage` holds this mod's persistent runtime state, saved with the world.
- A Lua `local` variable alone does not become persistent save state.

Official reference: [Data lifecycle](https://lua-api.factorio.com/latest/auxiliary/data-lifecycle.html).
Use the documentation bundled with the tested Factorio build when checking exact APIs;
the online `latest` reference can move ahead of the installed game.

## 2. Start with the entry points

| File | Purpose | First thing to inspect |
| --- | --- | --- |
| [info.json](../mod/info.json) | Package identity, version and dependencies | The internal package name and required base version |
| [data.lua](../mod/data.lua) | Prototype-stage entry point | Its `require` call delegates prototype creation |
| [prototypes/gameplay.lua](../mod/prototypes/gameplay.lua) | Item, machine and recipe definitions | `table.deepcopy`, then `data:extend` |
| [data-final-fixes.lua](../mod/data-final-fixes.lua) | Adjusts technologies after definitions load | Research ingredient conversion and unlock effects |
| [control.lua](../mod/control.lua) | Runtime entry point | Event registrations and their handler functions |
| [runtime/gameplay.lua](../mod/runtime/gameplay.lua) | Running simulation | `init`, `built`, `tick`, `mix`, `pickup`, `removed` |
| [runtime/labs.lua](../mod/runtime/labs.lua) | Single-slot Lab and native credit | Intake, persistent worker, tagged mining returns |
| [runtime/gui.lua](../mod/runtime/gui.lua) | Machine windows | Native inventory bindings and progress display |
| [shared/](../mod/shared/) | Rules without Factorio globals | Constants, mixture identity and wear calculations |
| [locale/en/science.cfg](../mod/locale/en/science.cfg) | Player-facing text | Keys referenced by prototypes and runtime status |

`require("runtime.gameplay")` loads a module and receives its returned Lua table.
The module exposes functions as fields on that table. `script.on_event(...)` tells
Factorio which function to call when an event occurs; it does not run the function
immediately.

## 3. Follow one machine being built

Start in `control.lua`, at the build-event registrations. Follow the call to
`gameplay.built` in `runtime/gameplay.lua`.

Find where the entity is validated, where its type/name is checked, and where its
reference is recorded under its `unit_number`. That number identifies this placed
entity. Another machine made from the same prototype has a different number.

Then read `gameplay.init`. It prepares persistent tables and registers relevant
entities already present when the mod is first added to an existing save. This is
a one-time scan; the tick handler uses the tracked tables instead of searching the
whole world every tick.

## 4. Follow one craft

Read `gameplay.tick`, then the `mix` function it calls for tracked mixers.

Trace these questions in order:

1. Can this machine run now, considering power, circuits and deconstruction?
2. Is a craft already active, or should inputs be sampled?
3. Where are the consumed ingredients and selected output remembered?
4. How does elapsed processing advance?
5. What happens if the output cannot fit?
6. When is the active craft cleared?

The distinction between an idle machine and an active craft is essential. Inputs
arriving later must not silently change a craft that has already consumed packs.

The machine prototype supplies native Factorio inventories and graphics. Runtime
code controls the sampling behavior. Keep the prototype definition and runtime
logic open together when following that boundary.

## 5. Follow one inserter pickup

Read `pickup` in the runtime module, then [shared/wear.lua](../mod/shared/wear.lua)
and [shared/constants.lua](../mod/shared/constants.lua).

The runtime observes tracked inserter hands. A change from empty to occupied is a
pickup; continuing to hold the same item is not another pickup. The pure helper
calculates wear, while the runtime changes the actual held stack or converts it
to waste. Fresh mixed beakers start at 100%; one wear point leaves 90%, nine leave
10%, and ten denatures. Ordinary science passes through unchanged and receives no
scripted wear. Check the constants and boundary tests for the calculation.

**Health and durability are separate:** health represents handling wear on mixed
beakers; Tool durability represents remaining science value for native research.
Reducing handling health must not silently consume research durability.

## 6. Follow removal and research credit

Read `removed` and its event registrations in `control.lua`, then the lifecycle
functions in [runtime/labs.lua](../mod/runtime/labs.lua).

The visible Lab is a one-slot container. Its partner is an invisible native lab
that owns power, modules, research timing and stored credit. Native lab inventories
cannot provide one shared untyped slot, which is why this partner exists.

Follow the intake check: wrong science remains in the physical slot and blocks
other items. Matching science is consumed into the worker's native credit; the
worker's physical science input stays empty. A raw pack contributes one unit;
a mixed Tool contributes its remaining durability. Already admitted credit can
survive a research switch and be used later.

Physical inventory, committed mixer ingredients and stored lab credit are separate
balances. Empty physical science input does not mean empty credit. Search for
`get_stored_durability` and `set_stored_durability` to follow that native balance.
Factorio advances research; the mod does not add force-wide progress each tick.

On mining, the Lab item keeps remaining credit in its tags. Rebuilding restores
it. Ordinary science is an Item, not a Tool, so fractional ordinary credit cannot
be returned as a partially used pack. Input and modules must also be conserved.

### Follow the machine window

Read [runtime/gui.lua](../mod/runtime/gui.lua). Its inventory widgets bind to the
real mixer input/output, Lab intake, worker modules and player inventory. Native
cursor interaction and stack transfers preserve the actual stack metadata.
The window hides internal recipes and typed filter ghosts; it does not invent a
second inventory or copy counts to imitate a transfer.

Mixer progress reads the entity's `crafting_progress`, which the mixing runtime
updates for the 60-powered-tick cycle. Look at the mixer prototype's
`return_ingredients_on_change = false` too: it prevents the native shell from
refunding its internal recipe on mining. Runtime alone returns committed inputs.
Window refreshes only inspect players with open machine windows. Graphical layout,
ghost suppression and click/shift interactions need the manual checks described
in [manual-playtest.md](manual-playtest.md).

## 7. Read the tests as worked examples

| Location | What it demonstrates |
| --- | --- |
| [tests/unit/](../tests/unit/) | Pure rule inputs and expected results, without Factorio |
| [validation fixture](../tests/integration/validation-fixture/control.lua) | Real production machines, inventories, transport, research and lifecycle assertions |
| [bootstrap fixture](../tests/integration/bootstrap-fixture/control.lua) | A world created before the production mod is installed |
| [engine runner](../scripts/engine_runner.py) | Packaging, isolated engine processes, checkpoint saving and independent reload |
| [showcase scenario](../tests/showcase/scenario/control.lua) | Starter layout and supplies for manual experimentation |

Pure tests can use small Lua inputs because they exercise pure calculations. They
cannot prove Factorio behavior with empty inventory/entity mocks. The engine
fixtures set up real situations and inspect outcomes. They must call or exercise
production behavior, rather than duplicate the implementation under test.

The showcase is development material, not a runtime module shipped to players.
Only `mod/` and the root license enter the distributed archive.

## 8. Make a small change

For a first exercise, change a player-facing description in the locale file.
Find the prototype or runtime expression that references its key, then rebuild
and inspect the result in the isolated test profile.

From the repository root:

```sh
make test
make lint
make package
```

Copy the newly built ZIP into the isolated test profile's mods directory and
restart Factorio. Editing source under `mod/` does not update an already copied
ZIP automatically. Use a fresh development save when a change invalidates old
state; development versions do not maintain backward compatibility.

For behavior changes, use the real-engine commands in [testing.md](testing.md).
A passing pure test cannot establish actual inserter, inventory or lab behavior.

Next references: [architecture](architecture.md), [current rules](decisions.md),
[testing](testing.md), and the [official API](https://lua-api.factorio.com/latest/).
