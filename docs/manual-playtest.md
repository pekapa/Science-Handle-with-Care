# Manual playtest

Use a fresh isolated Factorio 2.1 test profile with the built production ZIP and
base game at normal quality. Keep personal saves and mods separate. Generate the
starter layout with the command in [testing](testing.md), then run
`sh build/showcase/launch.sh` from the repository root. This launcher selects the
fresh isolated profile and its matching mod ZIP.
Do not reuse a command pointing to `build/showcase/work/mods`: older isolated
profiles keep their old ZIP even when `science-showcase.zip` has been regenerated.
Close any currently running Factorio instance before using the launcher. Restart
after replacing the ZIP so the loaded code matches the package being checked.

The isolated profile has its own controls settings. To enter the editor, open
**Settings → Controls → Toggle chat (and Lua console)** and check or rebind the
key, then open the console and enter `/editor`. The default grave/backtick key
can be awkward on regional keyboard layouts. See the official
[console documentation](https://wiki.factorio.com/Console).

Basic setup and the transport line have received manual inspection. This checklist
covers the revised Lab and machine interfaces; completing automated tests does not
mark these graphical checks complete. Record the exact engine and mod versions,
package revision, case result and failure evidence when reporting a run.

| Case | Action and expected result |
| --- | --- |
| Early Lab | In a fresh game, craft the ordinary Lab using its normal recipe before green science. It has one science input slot and usable module controls. Only the mixer requires green science. |
| Pass-through | Supply only red, then only green to a powered mixer. Each returns the same ordinary pack after one second. No fragile single-science item or scripted wear appears. |
| Start timing | Supply red+green together to get a mixed beaker. Deliver the second type after crafting starts; it belongs to the next craft. Circuit disable allows loading before start. |
| Mixer interface | Open the mixer. See two real input slots, three real output slots and progress; no recipe selector or typed recipe ghosts. Progress pauses without power or when disabled; blocked output preserves one pending result. |
| Inventory interactions | Use cursor clicks and shift transfers in both machine windows, including worn beakers and tagged Lab items. Counts, health, durability and tags survive; reopen and verify actual inventories agree. |
| Linear wear | Follow a fresh mixed beaker through ordinary inserter pickups. First pickup shows 90%, ninth 10%, tenth becomes denatured science. Holding during a blocked delivery does not charge again. |
| One-slot blockage | Put wrong science in the Lab. The slot remains occupied and blocks the right science until manually emptied. Wrong science is removable and unchanged. |
| Native research | Supply matching science and power. Research advances at native speed; stored credit remains through power pauses and research switches. Check power, modules and research display are understandable. |
| Mining credit | Partially consume ordinary science, then mine the Lab. Rebuild that exact tagged item and finish using the remaining fractional credit. Repeat with a combined beaker; inputs and modules are returned without duplication. |
| Reload | Save and reload while an inserter holds a worn beaker and a lab has credit. No repeated wear charge or credit loss occurs. |
| Window lifecycle | Walk away, remove the open machine, reconnect, and open another machine. Windows close or update cleanly; normal inventory interaction remains usable. |

Headless tests prove inventories, wear, credit and persistence with actual engine
entities. Manual checks establish appearance, legibility and interaction. Neither
establishes Space Age, quality, overhaul or untested-build compatibility.
