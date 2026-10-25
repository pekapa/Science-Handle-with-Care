-- luacheck: globals storage game defines prototypes log script
-- Usable from a copied save scenario or the input companion mod.
local prefix = script.mod_name == "science-input-validation-fixture"
    and "__science-input-validation-fixture__/"
  or ""
local cases = require(prefix .. "gui_cases")
local setup = require(prefix .. "gui_setup")
local expect = require(prefix .. "gui_expectations")
local actions = require(prefix .. "gui_actions")
local gui = require("__science-handle-with-care__/runtime/gui")
local M = {}

local function state()
  storage.gui_validation = storage.gui_validation or { phase = 0, opened = 0 }
  return storage.gui_validation
end

function M.opened(event)
  if event.entity then
    local current = state()
    current.opened = current.opened + 1
  end
end

function M.tick()
  local current = state()
  if current.complete then
    return
  end
  current.phase = current.phase + 1
  local player = game.players[1]
  current.player = player
  local ok, failure = pcall(function()
    assert(player and player.character and player.connected, "save needs a real connected player")
    cases.tick(current, player, expect, actions, gui, setup)
  end)
  if not ok or current.complete then
    setup.teardown(current)
  end
  if not ok then
    error(failure)
  end
end
return M
