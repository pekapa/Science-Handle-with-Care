-- luacheck: globals storage game defines prototypes log
local M = {}
function M.module_actions(player, widget, lab, worker, gui)
  -- Required production module executes in the scenario's Lua environment.
  -- Seed its storage references to the actual production entities/window; the
  -- packaged mod's storage remains independent and owns window lifecycle.
  storage.machine_guis = { [player.index] = lab }
  storage.labs = { [lab.unit_number] = { worker = worker } }
  local modules = worker.get_module_inventory()
  local main = player.get_main_inventory()
  local function action(kind, element)
    gui.inventory_action({
      player_index = player.index,
      element = element or widget,
      slot = 1,
      action = kind,
      item = prototypes.item["speed-module"],
    })
  end
  for _, kind in pairs({
    defines.inventory_actions.stack_transfer,
    defines.inventory_actions.stack_split,
    defines.inventory_actions.inventory_transfer,
    defines.inventory_actions.inventory_split,
  }) do
    modules.clear()
    main.clear()
    modules[1].set_stack({ name = "speed-module", count = 1 })
    modules[1].health = 0.4
    action(kind)
    assert(
      modules.get_item_count("speed-module") + main.get_item_count("speed-module") == 1,
      "module modifier action did not conserve count"
    )
    assert(main.get_item_count("speed-module") == 1, "module modifier action did not move module")
    local moved = main.find_item_stack("speed-module")
    assert(math.abs(moved.health - 0.4) < 0.00001, "module modifier lost stack health")
  end
  main.clear()
  for index = 1, #main do
    main[index].set_stack({ name = "iron-plate", count = 100 })
  end
  modules[1].set_stack({ name = "speed-module", count = 1 })
  modules[1].health = 0.6
  action(defines.inventory_actions.stack_transfer)
  assert(
    modules[1].count == 1 and math.abs(modules[1].health - 0.6) < 0.00001,
    "full player inventory lost module or metadata"
  )
  main.clear()
  -- An unrelated inventory widget must never acquire this panel's transfer behavior.
  local foreign = player.gui.screen.add({ type = "inventory", name = "foreign" })
  foreign.inventory = modules
  action(defines.inventory_actions.stack_transfer, foreign)
  assert(modules[1].valid_for_read and main.is_empty(), "foreign inventory triggered module action")
  foreign.destroy()
  modules.clear()
  log("SCIENCE_GUI_ACTIONS PASS production module handler with real inventories")
end

return M
