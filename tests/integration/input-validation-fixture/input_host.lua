-- luacheck: globals storage game defines prototypes log
local M = {}
local function mark(message)
  log("LAB_INPUT " .. message)
end
function M.tick(gui_suite)
  storage.input_host = storage.input_host or {}
  local player = game.connected_players[1]
  if not player then
    return -- Runner's wall-clock deadline names missing connected-player failures.
  end
  storage.input_host.connected_tick = storage.input_host.connected_tick or game.tick
  local age = game.tick - storage.input_host.connected_tick
  if gui_suite and age < 90 then
    gui_suite.tick()
  end
  local function capture(name)
    game.take_screenshot({
      player = player,
      path = name,
      resolution = player.display_resolution,
      show_gui = true,
      force_render = true,
    })
    mark("OUTER_CAPTURE " .. name)
  end
  if age == 180 then
    capture("lab-input-before.png")
  elseif age == 240 then
    player.open_factoriopedia_gui(prototypes.entity.lab)
    mark("OUTER_OPEN age240")
  elseif age == 360 then
    capture("lab-input-after.png")
  elseif age == 420 then
    -- Release the simulation through its owner, outside its update callback.
    player.close_factoriopedia_gui()
    assert(
      player.opened_gui_type == defines.gui_type.none,
      "input host preview retained after cleanup"
    )
    mark("OUTER_CLOSE age420")
    log("LAB_INPUT_HOST_FINAL PASS")
  end
end
return M
