# Gameplay validation fixture

This companion mod exercises the packaged production runtime in the real engine.
The Python engine runner owns its isolated profile, bootstrap save, checkpoint
process stop, reload and final disposal. Run it as described in the
[integration harness](../README.md); loading modules or linting them does not
establish engine behavior.

| Module | Responsibility |
| --- | --- |
| `control.lua` | Register init and tick handlers only |
| `suite.lua` | Initialize, dispatch ordered substeps, checkpoint/resume and finish |
| `setup.lua` | Enabled-mod/prototype expectations, world and initial Lab setup; ordered feature setup calls |
| `fixture_support.lua` | Create actual entities/power, find the production worker, collect salvage and access mixer output |
| `mixer_cases.lua` | Sampling, powered timing/circuits, blocked delivery, removal and reload expectations |
| `handling_cases.lua` | Existing-world registration, actual inserters, belt conservation, wear and held-stack mining |
| `lab_cases.lua` | Single-slot admission, conventional/native research, pause/reload credit, robot mining/rebuild and lifecycle |

All persistent references and observations live in `storage.fixture`. Modules
capture no save state at require time, and no `on_load` handler mutates the world.
Support functions find the production worker; they never implement admission,
research, pickup wear or credit restoration themselves.

Setup preserves entity creation order, coordinates, forces and research setup.
Each tick first checks empty physical worker inventories and conventional
research. The extended substeps then observe the belt route, run Lab research
steps, check the existing-world inserter, run mixer timing, and check the route
and held-inserter mining. This explicit interleaving preserves the existing-world
assertion before the circuit-output assertion at tick 490. Blocked Lab delivery,
robot polling and arm observations follow, then the main mixer/Lab timeline.
In particular research preparation at 1100 precedes robot polling, and arm
observation at 600 follows the held-inserter mining step, skipping its invalid arm.

At tick 120, Lab credit, partial mixer progress and a held inserter are checked
before setting the checkpoint flag, saving and emitting the checkpoint marker.
Tick 121 checks that flag, serialized credit and resumed progress, then emits the
resume marker. Tick 2400 checks handling, Lab and mixer completion in that order,
sets `done` and emits the final marker. Further ticks do no fixture work. The
checkpoint world remains intact for the runner's real process reload; fixture
completion does not destroy it.

The Lab credit, research switch, robot delivery, rebuild and subsequent lifecycle
checks deliberately share one workflow and remain together in `lab_cases.lua`.
Assertions stay beside their actions and absolute tick conditions. These are
interdependent engine cases, not independently scheduled scenarios.

