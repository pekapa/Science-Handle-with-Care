# GUI fixture boundaries

The standalone copied save loads `control.lua`, a thin event adapter for
`gui_suite.lua`. The input runner can copy the suite and its sibling `gui_*.lua`
modules into `science-input-validation-fixture`, set its generated `batch.lua`
to `return true`, and invoke the same suite before the input host opens.
The checked-in `batch.lua` returns false for input-only runs. Sibling imports
use the input companion's explicit mod prefix there and scenario-local imports
in the standalone copied save.

| Module | Responsibility |
| --- | --- |
| `gui_suite.lua` | Tick/open-event entry points, bounded case sequence and teardown on completion or failure |
| `gui_setup.lua` | Create owned mixer/Lab and locate its production worker; close windows and destroy owned entities |
| `gui_cases.lua` | Run the existing timed construction, refresh, capture and lifecycle cases |
| `gui_expectations.lua` | Assert native window/panel identity and research-credit refresh |
| `gui_actions.lua` | Exercise the production module action with real inventories, metadata and full destinations |
| `../input-validation-fixture/control.lua` | Register simulation remote callbacks and outer events |
| `../input-validation-fixture/input_host.lua` | Run optional GUI suite for the first 90 connected-player ticks; capture diagnostics, open Factoriopedia at age 240 and close its preview at age 420 |
| `../input-validation-fixture/input_case.lua` | Set up wrong science, locate native slot, move/click simulation cursor, assert, then deactivate the case |
| `../input-validation-fixture/input_expectations.lua` | Assert blocking before the click and cursor/count/health/quality/intake/widget state afterward |

The GUI suite retains captures at phases 19 and 45 and its final marker at phase
70. Cases use `storage.gui_validation`; the outer input host uses
`storage.input_host`; the input simulation uses `storage.input_validation` in its
separate simulation script state. GUI production-helper calls intentionally seed
this fixture environment's `storage.machine_guis` and `storage.labs` with actual
production entities. The production mod maintains its independent state and owns
window lifecycle. The simulation never runs the outer GUI suite or forwards its
open events to that suite.

Successful input assertions precede case deactivation and `LAB_INPUT_FINAL PASS`.
Failure paths retain the named start/input log and the existing 600-tick deadline.
The simulation owns its test player, GUI, cursor and entities. Simulation update
callbacks only deactivate the case: they must not close its window, clear its
cursor or destroy its entities. Synchronous cleanup at that boundary reproduced
an engine GUI-logic SIGSEGV after both pass markers and all four PNGs were written;
those assertions and captures did not establish a successful graphical run.

The normal outer `on_tick` handler closes Factoriopedia at connected age 420,
after the age-360 diagnostic capture and expected input assertions. Closing that
owner releases the simulation. If the runner finishes earlier or fails, disposal
of its isolated process releases the remaining resources. The outer GUI suite
continues to close its own windows and remove its entities directly. Its captures
precede teardown by multiple ticks so requested frames can render with the window
open. A successful engine run must include the host cleanup marker and remain
free of late engine errors; static checks or input assertion markers alone do
not validate cleanup.

These are separate evidence layers: the GUI cases check production construction,
refresh and direct action calls; inspected graphical captures check appearance;
the simulation case checks one native wrong-science pickup through simulated
mouse input. Combined execution does not expand those claims to module modifier
event routing, physical OS input or complete usability. Runner completion still
requires each requested suite's final assertion and required captures.

The runner requires exactly one `LAB_INPUT_HOST_FINAL PASS` after the outer
preview closes, as well as the input assertions and requested GUI suite marker.
Input assertions alone cannot turn a cleanup failure into a passing run.
