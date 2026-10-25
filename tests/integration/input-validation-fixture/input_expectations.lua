-- luacheck: globals storage game defines prototypes log
local M = {}
function M.blocked(state, player)
  assert(player.opened == state.lab, "production native Lab window not open")
  local frame = assert(player.gui.relative["shwc-machine-info"], "production panel missing")
  assert(
    frame.modules.inventory == state.worker.get_module_inventory(),
    "production module binding missing"
  )
  local input = state.lab.get_inventory(defines.inventory.chest)[1]
  assert(
    input.valid_for_read and input.name == "logistic-science-pack" and input.count == 1,
    "wrong science must remain blocking before click"
  )
  assert(math.abs(input.health - 0.6) < 0.00001, "blocked input health changed")
  assert(input.quality.name == "normal", "blocked input quality changed")
end
function M.removed(state, player)
  local cursor = player.cursor_stack
  assert(
    cursor.valid_for_read and cursor.name == "logistic-science-pack" and cursor.count == 1,
    "native Lab left-click cursor count/item mismatch"
  )
  assert(math.abs(cursor.health - 0.6) < 0.00001, "native Lab click changed health")
  assert(cursor.quality.name == "normal", "native Lab click changed quality")
  assert(state.lab.get_inventory(defines.inventory.chest).is_empty(), "click retained input")
  assert(
    player.gui.relative["shwc-machine-info"].modules.inventory
      == state.worker.get_module_inventory(),
    "production module binding lost after native input click"
  )
end
return M
