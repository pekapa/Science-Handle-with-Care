-- luacheck: globals storage game defines prototypes log
local M = {}
function M.tick(state, player, expect, actions, gui, setup)
  local phase, opened = state.phase, state.opened
  local mixer, lab, worker = state.mixer, state.lab, state.worker
  if phase == 1 then
    player.opened = nil
    local position = player.position
    mixer = setup.mixer(state, player, position)
    player.teleport({ mixer.position.x, mixer.position.y + 3 })
    player.opened = mixer
  elseif phase == 2 then
    local frame = expect.panel(player, mixer)
    assert(opened == 1, "native mixer open event missing")
    assert(
      frame.anchor.gui == defines.relative_gui_type.assembling_machine_gui,
      "mixer panel has wrong native anchor"
    )
    assert(#mixer.get_inventory(defines.inventory.crafter_input) == 2, "mixer input size changed")
    assert(#mixer.get_inventory(defines.inventory.crafter_output) == 3, "mixer output size changed")
    player.opened = nil
    assert(not player.gui.relative["shwc-machine-info"], "native close retained panel")
    lab, worker = setup.lab(state, player, mixer)
    player.teleport({ lab.position.x, lab.position.y + 3 })
    player.opened = lab
  elseif phase == 3 then
    local frame = expect.panel(player, lab)
    assert(opened == 2, "native lab open event missing")
    assert(frame.anchor.gui == defines.relative_gui_type.container_gui, "wrong Lab anchor")
    local intake = lab.get_inventory(defines.inventory.chest)
    assert(#intake == 1, "Lab must have one physical input slot")
    assert(
      not intake.supports_bar() and not intake.supports_filters(),
      "Lab exposes chest bar or filter controls"
    )
    local widget = frame.modules
    assert(widget and widget.type == "inventory", "worker module inventory widget missing")
    assert(widget.inventory == worker.get_module_inventory(), "wrong worker module binding")
    assert(
      widget.handle_cursor_transfer and widget.handle_cursor_split,
      "native cursor handlers disabled"
    )
    assert(#widget.inventory == 2, "Lab must expose two worker module slots")
    assert(widget.inventory.index == defines.inventory.lab_modules, "widget is not lab_modules")
    assert(widget.inventory.entity_owner == worker, "module inventory belongs to wrong entity")
    assert(
      widget.inventory.insert({ name = "automation-science-pack", count = 1 }) == 0,
      "module inventory accepted science"
    )
    assert(
      widget.inventory.insert({ name = "speed-module", count = 1 }) == 1,
      "module inventory rejected module"
    )
    widget.inventory.clear()
    assert(widget.empty_slot_info.sprite == "utility/empty_module_slot", "module slot hint missing")
    expect.credit_display(player, frame, lab, worker, gui)
    actions.module_actions(player, widget, lab, worker, gui)
    intake[1].set_stack({ name = "lab", count = 1 })
    intake[1].tags = { gui_regression = "preserve" }
    worker.get_module_inventory()[1].set_stack({ name = "speed-module", count = 1 })
    local mixed = mixer.get_inventory(defines.inventory.crafter_output)[3]
    mixed.set_stack({ name = "shwc-beaker-red-green", count = 1 })
    mixed.health = 0.6
    mixed.durability = mixed.durability / 2
  elseif phase == 19 then
    game.take_screenshot({
      player = player,
      show_gui = true,
      path = "lab-gui.png",
      resolution = player.display_resolution,
      force_render = true,
    })
  elseif phase == 20 then
    local frame = expect.panel(player, lab)
    assert(frame.modules.inventory[1].name == "speed-module", "module widget lost actual inventory")
    assert(
      lab.get_inventory(defines.inventory.chest)[1].tags.gui_regression == "preserve",
      "native intake lost tags while panel refreshed"
    )
    player.opened = nil
    player.teleport({ mixer.position.x, mixer.position.y + 3 })
    mixer
      .get_inventory(defines.inventory.crafter_input)
      .insert({ name = "automation-science-pack", count = 1 })
    player.opened = mixer
    frame = expect.panel(player, mixer)
    assert(frame.health.caption[1] == "shwc-gui.beaker-state", "mixed output health absent")
    local mixed = mixer.get_inventory(defines.inventory.crafter_output)[3]
    assert(
      mixed.name == "shwc-beaker-red-green" and math.abs(mixed.health - 0.6) < 0.00001,
      "mixed output changed before health display check"
    )
    -- Factorio normalizes numeric LocalisedString parameters to strings on readback.
    assert(
      frame.health.caption[2] == tostring(math.floor(mixed.health * 100 + 0.5)),
      "mixed output health differs from real stack"
    )
    assert(
      frame.health.caption[3] == tostring(mixed.durability),
      "mixed output durability differs from real stack"
    )
  elseif phase > 20 and phase < 45 then
    mixer.energy = mixer.electric_buffer_size
    expect.panel(player, mixer)
  elseif phase == 45 then
    expect.panel(player, mixer)
    assert(mixer.crafting_progress > 0, "native powered craft never progressed")
    game.take_screenshot({
      player = player,
      show_gui = true,
      path = "mixer-gui.png",
      resolution = player.display_resolution,
      force_render = true,
    })
  elseif phase == 46 then
    -- Screenshots render after the tick; keep the window open for that frame.
    player.teleport({ mixer.position.x + 100, mixer.position.y })
  elseif phase == 55 then
    assert(not player.gui.relative["shwc-machine-info"], "out-of-reach panel retained")
    assert(opened == 3, "switch/reopen native events missing")
    player.teleport({ lab.position.x, lab.position.y + 3 })
    player.opened = lab
    expect.panel(player, lab)
    lab.destroy({ raise_destroy = true })
  elseif phase == 70 then
    assert(not player.gui.relative["shwc-machine-info"], "removed Lab retained relative panel")
    log("SCIENCE_GUI_FINAL PASS")
    state.complete = true
  end
  state.mixer, state.lab, state.worker = mixer, lab, worker
end
return M
