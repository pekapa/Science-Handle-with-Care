local gameplay = require("runtime.gameplay")
local gui = require("runtime.gui")
script.on_init(gameplay.init)
script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
  defines.events.on_entity_cloned,
}, gameplay.built)
script.on_event({
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy,
}, gameplay.removed)
script.on_event(defines.events.on_tick, gameplay.tick)
script.on_event(defines.events.on_gui_opened, gui.opened)
script.on_event(defines.events.on_gui_closed, gui.closed)
script.on_event(defines.events.on_gui_click, gui.clicked)
script.on_event(defines.events.on_gui_inventory_action, gui.inventory_action)
script.on_nth_tick(10, gui.tick)
