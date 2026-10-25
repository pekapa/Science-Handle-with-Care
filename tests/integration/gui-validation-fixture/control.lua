-- The copied save scenario owns event registration; cases live in sibling modules.
local suite = require("gui_suite")
script.on_event(defines.events.on_gui_opened, suite.opened)
script.on_event(defines.events.on_tick, suite.tick)
