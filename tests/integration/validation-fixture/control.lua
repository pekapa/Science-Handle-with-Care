-- luacheck: read globals script defines
local suite = require("suite")

script.on_init(suite.initialize)
script.on_event(defines.events.on_tick, suite.tick)
