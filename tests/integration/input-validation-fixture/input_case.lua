-- luacheck: globals storage game defines prototypes log
local expect = require("input_expectations")
local M = {}
local function mark(message)
  log("LAB_INPUT " .. message)
end
local function modules()
  return storage.input_validation.worker.get_module_inventory()
end

function M.start()
  local state = {}
  storage.input_validation = state
  assert(game.simulation, "simulation host missing")
  state.active, state.age, state.phase = true, 0, "open"
  local player = game.simulation.create_test_player({ name = "Lab input validation" })
  state.player = player
  player.teleport({ 0, 2 })
  player.get_main_inventory().clear()
  player.clear_cursor()
  game.simulation.camera_player = player
  game.simulation.camera_position = { 0, 0 }
  game.simulation.camera_zoom = 1
  local lab = assert(
    player.surface.create_entity({
      name = "lab",
      position = { 0, 0 },
      force = player.force,
      raise_built = true,
    }),
    "production Lab creation failed"
  )
  state.lab = lab
  local workers = player.surface.find_entities_filtered({ name = "shwc-lab-worker" })
  assert(#workers == 1, "production build must create exactly one worker")
  state.worker = workers[1]
  modules()[1].set_stack({ name = "speed-module", count = 1 })
  modules()[1].health = 0.4
  player.force.enable_research()
  player.force.research_queue = {}
  player.force.technologies["automation-science-pack"].researched = true
  player.force.technologies.automation.enabled = true
  player.force.technologies.automation.researched = false
  assert(player.force.add_research("automation"), "could not queue automation research")
  assert(
    player.force.current_research and player.force.current_research.name == "automation",
    "automation research not active"
  )
  local intake = lab.get_inventory(defines.inventory.chest)
  assert(#intake == 1, "Lab must have exactly one physical input slot")
  intake[1].set_stack({ name = "logistic-science-pack", count = 1 })
  intake[1].health = 0.6
  player.opened = lab
  mark("START assigned native window; opening click is outside this test")
end

function M.step()
  local state = storage.input_validation
  state.age = state.age + 1
  assert(state.age <= 600, "600-tick Lab input deadline exceeded")
  local player = state.player
  if state.phase == "open" and state.age >= 30 then
    expect.blocked(state, player)
    -- Resolve only after this actual native window opens. No fallback coordinates.
    state.target = game.simulation.get_slot_position({
      inventory = "entity",
      inventory_index = defines.inventory.chest,
      slot_index = 0,
    })
    assert(state.target, "native Lab input slot lookup returned nil")
    state.phase = "move"
  elseif state.phase == "move" then
    if game.simulation.move_cursor({ position = state.target }) then
      game.simulation.mouse_click()
      state.target = nil
      state.phase, state.wait_until = "assert", state.age + 15
    end
  elseif state.phase == "assert" and state.age >= state.wait_until then
    expect.removed(state, player)
    mark("WRONG_SCIENCE_CLICK PASS count1 health0.6 qualitynormal cursor; intakeempty; widgetbound")
    M.teardown()
    log("LAB_INPUT_FINAL PASS")
  end
end

function M.teardown()
  local state = storage.input_validation
  if not state then
    return
  end
  state.active = false
  -- Simulation callbacks only stop the case. The outer host closes the preview
  -- after rendering; destroying its GUI/entities here can crash engine GUI logic.
end
return M
