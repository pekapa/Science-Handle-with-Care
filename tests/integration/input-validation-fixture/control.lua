-- luacheck: globals storage game defines remote script log
-- The companion owns simulation callbacks and the connected-player host.
local case = require("input_case")
local host = require("input_host")
local gui_suite = require("batch") and require("__science-input-validation-fixture__/gui_suite")

local function run(action, label)
  local ok, failure = pcall(action)
  if not ok then
    case.teardown()
    log("LAB_INPUT FAIL " .. label .. ": " .. tostring(failure))
  end
end

remote.add_interface("science-input-validation", {
  start = function()
    run(case.start, "start")
  end,
  step = function()
    if storage.input_validation and storage.input_validation.active then
      run(case.step, "input")
    end
  end,
})

script.on_event(defines.events.on_gui_opened, function(event)
  if not game.simulation and gui_suite then
    gui_suite.opened(event)
  end
end)
script.on_event(defines.events.on_tick, function()
  if not game.simulation then
    host.tick(gui_suite)
  end
end)
