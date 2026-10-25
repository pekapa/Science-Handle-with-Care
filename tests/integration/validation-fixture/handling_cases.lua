-- luacheck: read globals game defines
local mixtures = require("__science-handle-with-care__/shared/mixtures")
local wear = require("__science-handle-with-care__/shared/wear")
local support = require("fixture_support")
local spawn, power = support.spawn, support.power
local M = {}

local function arm_case(name, x, initial, item)
  local source = spawn("wooden-chest", x, -20)
  local arm = spawn(name, x + 1, -20, defines.direction.west)
  if name == "long-handed-inserter" then
    source.destroy()
    source = spawn("wooden-chest", x - 1, -20)
  end
  local destination = spawn("wooden-chest", x + (name == "long-handed-inserter" and 3 or 2), -20)
  power(x + 1, -19)
  if name == "burner-inserter" then
    arm.insert({ name = "coal", count = 10 })
  end
  local stack = source.get_inventory(defines.inventory.chest)[1]
  stack.set_stack({ name = item or mixtures.beaker, count = 1 })
  stack.health = wear.to_health(initial)
  return {
    source = source,
    destination = destination,
    arm = arm,
    initial = initial,
    name = name,
    saw = false,
  }
end

local costs = {
  inserter = 1,
  ["burner-inserter"] = 1,
  ["long-handed-inserter"] = 2,
  ["fast-inserter"] = 2,
  ["bulk-inserter"] = 4,
}

local function check_arm(case, expected_item, expected_wear)
  local hand = case.arm.held_stack
  if hand.valid_for_read then
    assert(
      hand.name == expected_item,
      "pickup changed composition or failed to denature: " .. case.name
    )
    assert(hand.count == 1, "pickup count changed")
    assert(wear.from_health(hand.health) == expected_wear, "pickup wear/reload: " .. case.name)
    case.saw = true
    if not case.blocked then
      local output = case.destination.get_inventory(defines.inventory.chest)
      for index = 1, #output do
        output[index].set_stack({ name = "iron-plate", count = 100 })
      end
      case.blocked = true
    end
  end
end

function M.setup_existing_world(state)
  local bootstrap_area = { { -1, -1 }, { 4, 2 } }
  state.bootstrap_arm =
    game.surfaces.nauvis.find_entities_filtered({ type = "inserter", area = bootstrap_area })[1]
  assert(state.bootstrap_arm, "existing-world inserter missing")
  local bootstrap_chests =
    game.surfaces.nauvis.find_entities_filtered({ name = "wooden-chest", area = bootstrap_area })
  table.sort(bootstrap_chests, function(a, b)
    return a.position.x < b.position.x
  end)
  state.bootstrap_destination = bootstrap_chests[2]
  local existing_input = bootstrap_chests[1].get_inventory(defines.inventory.chest)[1]
  existing_input.set_stack({ name = mixtures.beaker, count = 1, health = wear.to_health(3) })
end

function M.setup_arms(state)
  for index, name in ipairs({
    "inserter",
    "burner-inserter",
    "long-handed-inserter",
    "fast-inserter",
    "bulk-inserter",
  }) do
    state.arms[#state.arms + 1] = arm_case(name, -50 + index * 16, 0)
  end
  state.boundary = arm_case("inserter", 46, 8)
  state.failure = arm_case("fast-inserter", -50, 8)
  state.raw_arm = arm_case("fast-inserter", -26, 0, mixtures.packs[1])
  state.waste = arm_case("inserter", -42, 0, "shwc-denatured-science")
end

function M.setup_belt_route(state)
  state.belt_source = spawn("wooden-chest", 20, 35)
  state.belt_first = spawn("inserter", 21, 35, defines.direction.west)
  state.belts = {}
  for x = 22, 27 do
    state.belts[#state.belts + 1] = spawn("transport-belt", x, 35)
  end
  state.belt_second = spawn("inserter", 28, 35, defines.direction.west)
  state.belt_destination = spawn("wooden-chest", 29, 35)
  power(23, 37)
  spawn("small-electric-pole", 27, 37)
  local belt_item = state.belt_source.get_inventory(defines.inventory.chest)[1]
  belt_item.set_stack({ name = mixtures.beaker, count = 1 })
  belt_item.health = wear.to_health(3)
end

function M.observe_belt_route(state)
  local total = 0
  local function count_stack(stack, expected)
    if stack.valid_for_read and stack.name == mixtures.beaker then
      assert(
        stack.count == 1 and wear.from_health(stack.health) == expected,
        "belt route wear changed"
      )
      total = total + 1
    end
  end
  count_stack(state.belt_source.get_inventory(defines.inventory.chest)[1], 3)
  count_stack(state.belt_first.held_stack, 4)
  if state.belt_first.held_stack.valid_for_read then
    state.first_pickup = true
  end
  for _, belt in ipairs(state.belts) do
    for line = 1, 2 do
      for _, detail in pairs(belt.get_transport_line(line).get_detailed_contents()) do
        count_stack(detail.stack, 4)
        state.saw_belt = true
      end
    end
  end
  count_stack(state.belt_second.held_stack, 5)
  if state.belt_second.held_stack.valid_for_read then
    state.second_pickup = true
  end
  count_stack(state.belt_destination.get_inventory(defines.inventory.chest)[1], 5)
  assert(total == 1, "belt route lost or duplicated beaker")
end

function M.existing_world_tick(state, tick)
  if tick == 490 then
    local existing_output = state.bootstrap_destination.get_inventory(defines.inventory.chest)[1]
    assert(
      existing_output.valid_for_read
        and existing_output.name == mixtures.beaker
        and wear.from_health(existing_output.health) == 4,
      "existing-world inserter was not registered or charged"
    )
  end
end

function M.extended_tick(state, tick)
  if tick == 490 then
    assert(
      state.first_pickup and state.second_pickup and state.saw_belt,
      "route did not exercise two real pickups and belts"
    )
  elseif tick == 600 then
    local arm = state.arms[1].arm
    assert(arm.held_stack.valid_for_read, "mining regression has no held beaker")
    state.arm_mining = game.create_inventory(8)
    assert(
      arm.mine({ inventory = state.arm_mining, raise_destroyed = true }),
      "held inserter mining failed"
    )
    local total_beakers = 0
    for index = 1, #state.arm_mining do
      local stack = state.arm_mining[index]
      if stack.valid_for_read and stack.name == mixtures.beaker then
        assert(wear.from_health(stack.health) == 1, "mining changed held wear")
        total_beakers = total_beakers + stack.count
      end
    end
    assert(total_beakers == 1, "mining lost or duplicated held beaker")
  end
end

function M.observe_arms(state)
  for _, case in ipairs(state.arms) do
    if case.arm.valid then
      check_arm(case, mixtures.beaker, costs[case.name])
    end
  end
  check_arm(state.boundary, mixtures.beaker, 9)
  check_arm(state.failure, "shwc-denatured-science", 0)
  check_arm(state.raw_arm, mixtures.packs[1], 0)
  check_arm(state.waste, "shwc-denatured-science", 0)
end

function M.checkpoint(state)
  assert(state.boundary.arm.held_stack.valid_for_read, "midhand checkpoint missing")
end

function M.finish(state)
  for _, case in ipairs(state.arms) do
    assert(case.saw, "inserter never picked up: " .. case.name)
  end
  assert(
    state.boundary.saw and state.failure.saw and state.waste.saw and state.raw_arm.saw,
    "wear boundary logistics missing"
  )
end

return M
