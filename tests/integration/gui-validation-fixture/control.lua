-- Runs as the copied save's scenario, alongside the packaged production mod.
local phase, opened = 0, 0
local mixer, lab, worker
local transfer = require("__science-handle-with-care__/runtime/inventory_transfer")

local function transfer_checks(player)
  local input = lab.get_inventory(defines.inventory.chest)
  local output = mixer.get_inventory(defines.inventory.crafter_output)
  local modules = worker.get_module_inventory()
  local cursor = player.cursor_stack
  local main = player.get_main_inventory()
  local left, right = defines.mouse_button_type.left, defines.mouse_button_type.right
  local function click(inventory, button, output_only, shift, control)
    transfer.click(player, inventory, 1, {
      button = button,
      shift = shift or false,
      control = control or false,
    }, output_only or false)
  end
  input.clear()
  cursor.clear()
  input[1].set_stack({ name = "automation-science-pack", count = 5 })
  click(input, right)
  assert(cursor.count == 3 and input[1].count == 2, "right click did not take rounded half")
  click(input, right)
  assert(cursor.count == 2 and input[1].count == 3, "right click did not place one")
  click(input, left)
  assert(not cursor.valid_for_read and input[1].count == 5, "left click failed merge")
  cursor.set_stack({ name = "logistic-science-pack", count = 2 })
  click(input, left)
  assert(
    cursor.name == "automation-science-pack" and cursor.count == 5,
    "left swap lost original stack"
  )
  assert(
    input[1].name == "logistic-science-pack" and input[1].count == 2,
    "left swap lost cursor stack"
  )
  input.clear()
  cursor.clear()
  cursor.set_stack({ name = "lab", count = 1 })
  cursor.tags = { action_regression = "tagged" }
  click(input, left)
  click(input, left)
  assert(cursor.tags.action_regression == "tagged", "production click lost tags")
  input[1].set_stack({ name = "lab", count = 1 })
  input[1].tags = { action_regression = "other" }
  click(input, left)
  assert(
    cursor.tags.action_regression == "other" and input[1].tags.action_regression == "tagged",
    "same-name tagged Lab swap lost tags"
  )
  input[1].set_stack({ name = "automation-science-pack", count = 200 })
  cursor.set_stack({ name = "automation-science-pack", count = 2 })
  click(input, left)
  assert(input[1].count == 200 and cursor.count == 2, "full compatible stack must not swap")
  cursor.clear()
  input[1].set_stack({ name = "shwc-beaker-red-green", count = 1 })
  input[1].health = 0.4
  input[1].durability = input[1].durability / 2
  local worn_durability = input[1].durability
  cursor.set_stack({ name = "shwc-beaker-red-green", count = 1 })
  local fresh_durability = cursor.durability
  click(input, left)
  assert(
    math.abs(cursor.health - 0.4) < 0.00001 and cursor.durability == worn_durability,
    "same-name beaker left click must swap worn stack into cursor"
  )
  assert(
    input[1].health == 1 and input[1].durability == fresh_durability,
    "same-name beaker left click must preserve fresh stack in input"
  )
  input.clear()
  cursor.clear()
  modules.clear()
  cursor.set_stack({ name = "automation-science-pack", count = 2 })
  click(modules, left)
  assert(modules.is_empty() and cursor.count == 2, "module click accepted invalid science")
  cursor.set_stack({ name = "speed-module", count = 1 })
  click(modules, left)
  assert(
    not cursor.valid_for_read and modules[1].name == "speed-module",
    "module click rejected valid module"
  )
  cursor.set_stack({ name = "automation-science-pack", count = 2 })
  click(modules, left)
  assert(
    modules[1].name == "speed-module" and cursor.name == "automation-science-pack",
    "module swap accepted invalid science"
  )
  output.clear()
  click(output, left, true)
  click(output, right, true)
  assert(output.is_empty() and cursor.count == 2, "output accepted cursor deposit")
  cursor.clear()
  output[3].set_stack({ name = "shwc-beaker-red-green", count = 1 })
  output[3].health = 0.4
  output[3].durability = output[3].durability / 2
  local durability = output[3].durability
  transfer.click(player, output, 3, { button = left }, true)
  assert(
    math.abs(cursor.health - 0.4) < 0.00001 and cursor.durability == durability,
    "production output extraction lost wear/durability"
  )
  cursor.clear()
  main.clear()
  input[1].set_stack({ name = "automation-science-pack", count = 8 })
  click(input, right, false, true)
  assert(
    main.get_item_count("automation-science-pack") == 4 and input[1].count == 4,
    "shift right did not split stack"
  )
  click(input, left, false, true)
  assert(
    main.get_item_count("automation-science-pack") == 8 and input.is_empty(),
    "shift left did not transfer stack"
  )
  input[1].set_stack({ name = "automation-science-pack", count = 6 })
  click(input, right, false, false, true)
  assert(
    main.get_item_count("automation-science-pack") == 11 and input[1].count == 3,
    "control right did not split inventory"
  )
  click(input, left, false, false, true)
  assert(
    main.get_item_count("automation-science-pack") == 14 and input.is_empty(),
    "control left did not transfer inventory"
  )
  main.clear()
  for index = 1, #main do
    main[index].set_stack({ name = "iron-plate", count = 100 })
  end
  input[1].set_stack({ name = "automation-science-pack", count = 7 })
  click(input, left, false, true)
  assert(
    input[1].count == 7 and main.get_item_count("automation-science-pack") == 0,
    "blocked bulk transfer lost science"
  )
  main.clear()
  input.clear()
  modules.clear()
  log("SCIENCE_GUI_ACTIONS PASS production helper with real inventories")
end

script.on_event(defines.events.on_gui_opened, function(event)
  if event.entity then
    opened = opened + 1
  end
end)

local function find(root, name)
  if root.name == name then
    return root
  end
  for _, child in pairs(root.children) do
    local result = find(child, name)
    if result then
      return result
    end
  end
end

local function window(player)
  local frame = player.gui.screen["shwc-machine"]
  assert(frame and frame.valid and player.opened == frame, "production window absent")
  local body = frame.body
  assert(body.direction == "horizontal", "expected horizontal left/right panels")
  assert(body.character and body.machine, "character and machine panels missing")
  local inventory = find(body.character, "player-inventory")
  assert(inventory and inventory.type == "inventory", "native player inventory missing")
  assert(inventory.inventory == player.get_main_inventory(), "wrong player inventory binding")
  assert(body.machine.power.type == "progressbar", "separate electricity bar missing")
  assert(body.machine.preview.type == "entity-preview", "machine preview missing")
  assert(body.machine.preview.entity.valid, "preview has no actual entity")
  return frame, body.machine
end

local function slots(root, role, count)
  local group = find(root, role)
  assert(group, role .. " slot group missing")
  for index = 1, count do
    local button = find(group, "shwc-" .. role .. "-" .. index)
    assert(button and button.type == "sprite-button", role .. " physical slot missing")
    assert(button.tags.role == role and button.tags.slot == index, "wrong slot identity")
    assert(not button.sprite or button.sprite == "", role .. " empty slot shows filter sprite")
    assert(
      button.parent.style.minimal_width >= 32 and button.parent.style.minimal_height >= 32,
      "unusable slot dimensions"
    )
  end
  assert(not find(group, "shwc-" .. role .. "-" .. (count + 1)), "extra physical slot")
end

script.on_event(defines.events.on_tick, function(event)
  phase = phase + 1
  local player = game.players[1]
  assert(player and player.character and player.connected, "save needs a real connected player")
  if phase == 1 then
    player.opened = nil
    local position = player.position
    mixer = player.surface.create_entity({
      name = "shwc-mixer",
      position = { position.x + 4, position.y },
      force = player.force,
      raise_built = true,
    })
    assert(mixer, "could not create test mixer beside player")
    player.teleport({ mixer.position.x, mixer.position.y + 3 })
    player.opened = mixer
  elseif phase == 2 then
    local _, machine = window(player)
    assert(opened == 1, "native mixer open event missing")
    local input = mixer.get_inventory(defines.inventory.crafter_input)
    local output = mixer.get_inventory(defines.inventory.crafter_output)
    assert(#input == 2 and #output == 3, "mixer native slot counts changed")
    slots(machine, "input", 2)
    slots(machine, "output", 3)
    assert(machine.crafting.progress.value == mixer.crafting_progress, "wrong native progress")
    assert(machine.power ~= machine.crafting.progress, "power and craft bars overlap logically")
    player.opened = nil
    assert(not player.gui.screen["shwc-machine"], "native close retained window")
    lab = player.surface.create_entity({
      name = "lab",
      position = { mixer.position.x + 5, mixer.position.y },
      force = player.force,
      raise_built = true,
    })
    assert(lab, "could not create test lab")
    worker = player.surface.find_entities_filtered({
      name = "shwc-lab-worker",
      position = lab.position,
      limit = 1,
    })[1]
    assert(worker, "production lab worker missing")
    player.teleport({ lab.position.x, lab.position.y + 3 })
    player.opened = lab
  elseif phase == 3 then
    local _, machine = window(player)
    assert(opened == 2, "native lab open event missing")
    assert(#lab.get_inventory(defines.inventory.chest) == 1, "lab input must be one slot")
    assert(#worker.get_module_inventory() == 2, "lab must expose two worker module slots")
    slots(machine, "input", 1)
    slots(machine, "modules", 2)
    transfer_checks(player)
    -- These genuine engine transfers check metadata, not GUI click/shift routing.
    local input = lab.get_inventory(defines.inventory.chest)
    local cursor = player.cursor_stack
    cursor.clear()
    input[1].set_stack({ name = "lab", count = 1 })
    input[1].tags = { gui_regression = "preserve" }
    assert(cursor.transfer_stack(input[1]), "native cursor transfer failed")
    assert(cursor.tags.gui_regression == "preserve", "cursor lost item tags")
    assert(input[1].transfer_stack(cursor), "native return transfer failed")
    assert(input[1].tags.gui_regression == "preserve", "return lost item tags")
    worker.get_module_inventory()[1].set_stack({ name = "speed-module", count = 1 })
    local mixed = mixer.get_inventory(defines.inventory.crafter_output)[3]
    mixed.set_stack({ name = "shwc-beaker-red-green", count = 1 })
    mixed.health = 0.6
    mixed.durability = mixed.durability / 2
    local durability = mixed.durability
    assert(cursor.transfer_stack(mixed), "mixed cursor transfer failed")
    assert(math.abs(cursor.health - 0.6) < 0.00001, "native transfer lost health")
    assert(cursor.durability == durability, "native transfer lost durability")
    assert(mixed.transfer_stack(cursor), "mixed return failed")
  elseif phase == 19 then
    game.take_screenshot({
      player = player,
      show_gui = true,
      path = "lab-gui.png",
      resolution = { 1280, 900 },
      force_render = true,
    })
  elseif phase == 20 then
    local _, machine = window(player)
    assert(find(machine, "shwc-input-1").sprite == "item/lab", "wrong lab input binding")
    assert(
      find(machine, "shwc-modules-1").sprite == "item/speed-module",
      "module slots do not read actual worker modules"
    )
    player.opened = nil
    player.teleport({ mixer.position.x, mixer.position.y + 3 })
    mixer.get_inventory(defines.inventory.crafter_input).insert({
      name = "automation-science-pack",
      count = 1,
    })
    player.opened = mixer
    local _, mixer_machine = window(player)
    local output = find(mixer_machine, "shwc-output-3")
    assert(output.sprite == "item/shwc-beaker-red-green", "output slot reads wrong stack")
    assert(output.parent.health.visible, "mixed health bar missing")
    assert(math.abs(output.parent.health.value - 0.6) < 0.00001, "wrong mixed health shown")
  elseif phase > 20 and phase < 45 then
    mixer.energy = mixer.electric_buffer_size
    if event.tick % 10 == 1 then
      local _, machine = window(player)
      assert(
        math.abs(machine.crafting.progress.value - mixer.crafting_progress) < 0.00001,
        "GUI refresh differs from powered native crafting progress"
      )
    end
  elseif phase == 45 then
    window(player)
    assert(mixer.crafting_progress > 0, "powered craft never progressed")
    game.take_screenshot({
      player = player,
      show_gui = true,
      path = "mixer-gui.png",
      resolution = { 1280, 900 },
      force_render = true,
    })
    player.teleport({ mixer.position.x + 100, mixer.position.y })
  elseif phase == 60 then
    assert(not player.gui.screen["shwc-machine"], "out-of-reach window retained")
    assert(opened == 3, "switch/reopen native events missing")
    log("SCIENCE_GUI_FINAL PASS")
  end
end)
