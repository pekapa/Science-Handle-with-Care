local wear = require("__science-handle-with-care__/shared/wear")
local composition = require("__science-handle-with-care__/shared/composition")
local item = "science-validation-tool"
local expected_wear = 4
local expected_durability = 731
local finish_tick = 600

local function spawn(surface, name, x, y, direction)
  local entity = surface.create_entity({
    name = name,
    position = { x, y },
    direction = direction or defines.direction.east,
    force = game.forces.player,
    create_build_effect_smoke = false,
  })
  assert(entity, "fixture could not create " .. name)
  return entity
end

local function check_stack(stack)
  assert(stack.valid_for_read and stack.name == item, "unexpected fixture item")
  assert(stack.count == 1, "fixture count changed")
  assert(wear.from_health(stack.health) == expected_wear, "encoded health changed")
  assert(stack.durability == expected_durability, "science durability changed")
end

script.on_init(function()
  assert(composition.key({ red = 1, green = 1 }) == composition.key({ green = 1, red = 1 }))
  local surface = game.create_surface("science-validation", {
    seed = 12345,
    width = 64,
    height = 64,
    autoplace_controls = {},
    default_enable_all_autoplace_controls = false,
  })
  surface.request_to_generate_chunks({ 0, 0 }, 1)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -8, 8 do
    for y = -8, 8 do
      tiles[#tiles + 1] = { name = "grass-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  local source = spawn(surface, "wooden-chest", 0, 0)
  local arm = spawn(surface, "inserter", 1, 0, defines.direction.west)
  local belts = {}
  for x = 2, 5 do
    belts[#belts + 1] = spawn(surface, "transport-belt", x, 0)
  end
  spawn(surface, "small-electric-pole", 1, 1)
  local power = spawn(surface, "electric-energy-interface", 1, 4)
  power.energy = 1000000000
  local inventory = source.get_inventory(defines.inventory.chest)
  assert(inventory[1].set_stack({ name = item, count = 1 }))
  inventory[1].health = wear.to_health(expected_wear)
  inventory[1].durability = expected_durability
  check_stack(inventory[1])
  storage.fixture =
    { source = source, arm = arm, belts = belts, saw_hand = false, saw_belt = false }
end)

script.on_event(defines.events.on_tick, function(event)
  local state = storage.fixture
  if state.done then
    return
  end
  local total = 0
  local inventory = state.source.get_inventory(defines.inventory.chest)
  for index = 1, #inventory do
    if inventory[index].valid_for_read then
      check_stack(inventory[index])
      total = total + inventory[index].count
    end
  end
  local hand = state.arm.held_stack
  if hand.valid_for_read then
    check_stack(hand)
    total = total + hand.count
    state.saw_hand = true
  end
  for _, belt in ipairs(state.belts) do
    for index = 1, 2 do
      for _, detail in pairs(belt.get_transport_line(index).get_detailed_contents()) do
        check_stack(detail.stack)
        total = total + detail.stack.count
        state.saw_belt = true
      end
    end
  end
  assert(total == 1, "fixture lost or duplicated a Tool")
  if event.tick == finish_tick then
    assert(state.saw_hand, "powered inserter never picked up the Tool")
    assert(state.saw_belt, "Tool never reached the belt")
    assert(inventory.get_item_count(item) == 0, "Tool remained in chest")
    assert(not hand.valid_for_read, "Tool remained in inserter")
    state.done = true
    log("SCIENCE_VALIDATION_FINAL PASS")
  end
end)
