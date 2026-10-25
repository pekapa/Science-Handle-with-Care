-- luacheck: globals storage
-- luacheck: read globals game log
local setup = require("setup")
local mixer = require("mixer_cases")
local handling = require("handling_cases")
local lab = require("lab_cases")
local M = {}
local checkpoint_tick = 120
local finish_tick = 2400

function M.initialize()
  setup.initialize()
end

-- These substeps preserve the original extended_tick's interleaved side effects.
local function extended_tick(state, tick)
  handling.observe_belt_route(state)
  lab.extended_tick(state, tick)
  handling.existing_world_tick(state, tick)
  mixer.extended_tick(state, tick)
  handling.extended_tick(state, tick)
end

function M.tick(event)
  local state = storage.fixture
  local tick = event.tick
  if state.done then
    return
  end
  lab.assert_empty_workers(state)
  lab.conventional_tick(state, tick)
  extended_tick(state, tick)
  lab.blocked_delivery_tick(state, tick)
  lab.robot_tick(state)
  handling.observe_arms(state)
  mixer.tick(state, tick)
  lab.tick(state, tick)
  if tick == checkpoint_tick then
    lab.checkpoint(state)
    mixer.checkpoint(state)
    handling.checkpoint(state)
    state.checkpoint = true
    game.auto_save("science-validation-checkpoint", true)
    log("SCIENCE_VALIDATION_CHECKPOINT PASS")
  elseif tick == checkpoint_tick + 1 then
    assert(state.checkpoint, "checkpoint state missing after reload")
    lab.resumed(state)
    mixer.resumed(state)
    log("SCIENCE_VALIDATION_RESUMED PASS")
  elseif tick == finish_tick then
    handling.finish(state)
    lab.finish(state)
    mixer.finish(state)
    -- Stop fixture work; Python owns disposal of the isolated profile/world.
    state.done = true
    log("SCIENCE_VALIDATION_FINAL PASS")
  end
end

return M
