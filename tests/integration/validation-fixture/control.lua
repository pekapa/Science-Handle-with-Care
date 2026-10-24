local mixtures = require("__science-handle-with-care__/shared/mixtures")
local wear = require("__science-handle-with-care__/shared/wear")
local checkpoint_tick = 120
local finish_tick = 1200

local function spawn(name, x, y, direction)
  local entity = storage.fixture.surface.create_entity({
    name = name,
    position = { x, y },
    direction = direction or defines.direction.east,
    force = game.forces.player,
    raise_built = true,
  })
  assert(entity, "fixture could not create " .. name)
  return entity
end

local function power(x, y)
  spawn("small-electric-pole", x, y)
  local source = spawn("electric-energy-interface", x, y + 3)
  source.energy = 1000000000
  return source
end

local function mixer(x, y, red, green)
  local entity = spawn("shwc-mixer", x, y)
  power(x, y + 2)
  local input = entity.get_inventory(defines.inventory.crafter_input)
  if red then
    assert(input.insert({ name = mixtures.packs[1], count = red }) == red)
  end
  if green then
    assert(input.insert({ name = mixtures.packs[2], count = green }) == green)
  end
  return entity
end

local function inventory(entity)
  return entity.get_inventory(defines.inventory.crafter_output)
end

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
  stack.set_stack({ name = item or mixtures.items[3], count = 1 })
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

script.on_init(function()
  for name in pairs(script.active_mods) do
    assert(
      name == "base" or name == "science-handle-with-care" or name == "science-validation-fixture",
      "unexpected enabled mod: " .. name
    )
  end
  local surface = game.create_surface("science-validation", {
    seed = 12345,
    width = 256,
    height = 256,
    autoplace_controls = {},
    default_enable_all_autoplace_controls = false,
  })
  surface.request_to_generate_chunks({ 0, 0 }, 4)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -60, 60 do
    for y = -40, 40 do
      tiles[#tiles + 1] = { name = "grass-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  storage.fixture = { surface = surface, arms = {} }
  local state = storage.fixture
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
  existing_input.set_stack({ name = mixtures.items[1], count = 1, health = wear.to_health(3) })
  assert(
    game.forces.player.recipes["shwc-mixer"].enabled
      and game.forces.player.recipes["shwc-lab"].enabled,
    "existing green research did not unlock new machines"
  )
  state.character = spawn("character", 50, 30)
  state.red = mixer(-30, 0, 1)
  state.green = mixer(-20, 0, nil, 1)
  state.combined = mixer(-10, 0, 1, 1)
  state.sample = mixer(0, 0, 1)
  state.blocked = mixer(10, 0, 1, 1)
  state.removal = mixer(20, 0, 1, 1)
  state.failed_mine = mixer(-45, 0, 2, 2)
  state.reload = mixer(30, 0)
  state.unpowered = spawn("shwc-mixer", 45, 0)
  state.unpowered.insert({ name = mixtures.packs[1], count = 1 })
  for index, name in ipairs({
    "inserter",
    "burner-inserter",
    "long-handed-inserter",
    "fast-inserter",
    "bulk-inserter",
  }) do
    state.arms[#state.arms + 1] = arm_case(name, -50 + index * 16, 0)
  end
  state.boundary = arm_case("inserter", 46, 9)
  state.failure = arm_case("fast-inserter", -50, 9)
  state.waste = arm_case("inserter", -42, 0, "shwc-denatured-science")
  state.lab = spawn("shwc-lab", 0, 25)
  state.lab_pole = spawn("small-electric-pole", -1, 27)
  state.lab_power = spawn("electric-energy-interface", 0, 30)
  state.lab_power.energy = 1000000000
  local lab_input = state.lab.get_inventory(defines.inventory.lab_input)
  for _, name in ipairs(mixtures.items) do
    assert(lab_input.insert({ name = name, count = 1 }) > 0)
  end
  state.lab_source = spawn("wooden-chest", -3, 25)
  spawn("inserter", -2, 25, defines.direction.west)
  assert(state.lab_source.insert({ name = mixtures.items[3], count = 4 }) == 4)
  local technology = game.forces.player.technologies["science-validation-research"]
  assert(#technology.research_unit_ingredients == 1, "equal red/green technology not converted")
  assert(technology.research_unit_ingredients[1].name == mixtures.items[3])
  assert(technology.research_unit_count == 5 and technology.research_unit_energy == 120)
  game.forces.player.add_research(technology)
  state.timing = mixer(-35, 15)
  log(
    "SCIENCE_INPUT_CAPACITY "
      .. state.timing
        .get_inventory(defines.inventory.crafter_input)
        .get_insertable_count(mixtures.packs[1])
  )
  state.circuit = mixer(-25, 15, 1)
  local circuit_pole = state.surface.find_entities_filtered({
    name = "small-electric-pole",
    position = { -25, 17 },
    radius = 2,
  })[1]
  assert(
    state.circuit
      .get_wire_connector(defines.wire_connector_id.circuit_red, true)
      .connect_to(circuit_pole.get_wire_connector(defines.wire_connector_id.circuit_red, true))
  )
  local behavior = state.circuit.get_or_create_control_behavior()
  behavior.circuit_enable_disable = true
  behavior.circuit_condition = {
    first_signal = { type = "item", name = "iron-plate" },
    comparator = ">",
    constant = 0,
  }
  state.dying = mixer(-15, 15, 2, 2)
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
  belt_item.set_stack({ name = mixtures.items[3], count = 1 })
  belt_item.health = wear.to_health(3)
end)

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

local function extended_tick(state, tick)
  local force = game.forces.player
  if state.recovered_arm then
    local hand = state.recovered_arm.held_stack
    if hand.valid_for_read then
      assert(
        hand.name == "shwc-denatured-science" and hand.count == 1,
        "recovered credit regained handling allowance"
      )
      state.recovered_waste = true
    end
  end
  local total = 0
  local function count_stack(stack, expected)
    if stack.valid_for_read and stack.name == mixtures.items[3] then
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
  if tick == 10 then
    local irrelevant = spawn("big-rock", 55, 0)
    irrelevant.destroy({ raise_destroy = true })
    local full = game.create_inventory(1)
    full[1].set_stack({ name = "iron-plate", count = 100 })
    assert(
      not state.failed_mine.mine({ inventory = full, force = false, raise_destroyed = true }),
      "full inventory unexpectedly mined machine"
    )
    assert(state.failed_mine.valid, "failed mining removed machine")
    full.destroy()
    assert(state.dying.die(), "mixer death failed")
    local counts = {}
    for _, dropped in
      pairs(state.surface.find_entities_filtered({
        type = "item-entity",
        area = { { -19, 11 }, { -11, 19 } },
      }))
    do
      counts[dropped.stack.name] = (counts[dropped.stack.name] or 0) + dropped.stack.count
    end
    assert(
      counts[mixtures.packs[1]] == 2 and counts[mixtures.packs[2]] == 2,
      "death lost pending or buffered ingredients"
    )
  elseif tick == 90 then
    assert(
      inventory(state.failed_mine).get_item_count(mixtures.items[3]) == 1,
      "failed mining lost live craft registration or contents"
    )
    assert(state.circuit.disabled_by_control_behavior, "circuit condition did not disable shell")
    assert(
      state.circuit.get_inventory(defines.inventory.crafter_input).get_item_count(mixtures.packs[1])
        == 1,
      "circuit-disabled mixer sampled input"
    )
    assert(
      state.circuit.custom_status.label[1] == "entity-status.shwc-paused",
      "mixer status does not explain pause"
    )
  elseif tick == 400 then
    state.timing.insert({ name = mixtures.packs[1], count = 1 })
    state.circuit.get_control_behavior().circuit_enable_disable = false
  elseif tick == 401 then
    assert(
      state.timing.get_inventory(defines.inventory.crafter_input).is_empty(),
      "idle powered mixer did not sample immediately"
    )
    assert(
      inventory(state.timing).is_empty(),
      "craft produced at sampling instead of after processing"
    )
  elseif tick == 410 then
    assert(
      state.circuit.get_inventory(defines.inventory.crafter_input).is_empty(),
      "circuit resume did not sample input"
    )
    state.circuit.get_control_behavior().circuit_enable_disable = true
  elseif tick == 430 then
    assert(
      state.circuit.disabled_by_control_behavior and inventory(state.circuit).is_empty(),
      "circuit pause did not preserve active craft"
    )
    state.circuit.get_control_behavior().circuit_enable_disable = false
  elseif tick == 460 then
    assert(inventory(state.timing).is_empty(), "craft completed before sixty powered ticks")
  elseif tick == 461 then
    assert(
      inventory(state.timing).get_item_count(mixtures.items[1]) == 1,
      "craft did not complete after exactly sixty powered ticks"
    )
  elseif tick == 490 then
    local existing_output = state.bootstrap_destination.get_inventory(defines.inventory.chest)[1]
    assert(
      existing_output.valid_for_read
        and existing_output.name == mixtures.items[1]
        and wear.from_health(existing_output.health) == 4,
      "existing-world inserter was not registered or charged"
    )
    assert(
      inventory(state.circuit).get_item_count(mixtures.items[1]) == 1,
      "resumed circuit craft lost output"
    )
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
      if stack.valid_for_read and stack.name == mixtures.items[3] then
        assert(wear.from_health(stack.health) == 1, "mining changed held wear")
        total_beakers = total_beakers + stack.count
      end
    end
    assert(total_beakers == 1, "mining lost or duplicated held beaker")
  elseif tick == 900 then
    assert(
      game.forces.player.technologies["science-validation-research"].researched,
      "initial native research did not complete"
    )
    assert(
      state.lab_source.get_inventory(defines.inventory.chest).is_empty(),
      "five-unit research left source beakers"
    )
    assert(
      state.lab.get_inventory(defines.inventory.lab_input).get_item_count(mixtures.items[3]) == 0,
      "five-unit research left physical beakers"
    )
    assert(
      state.lab.get_stored_durability(mixtures.items[3]).durability < 0.000001,
      "five-unit research left unexpected credit"
    )
    state.lab.insert({ name = mixtures.items[3], count = 1 })
    force.research_queue = { "science-validation-credit" }
    state.other_lab = spawn("shwc-lab", 12, 25)
    power(12, 28)
    state.other_lab.disabled_by_script = true
    state.other_lab.insert({ name = mixtures.items[3], count = 1 })
    state.health_lab = spawn("shwc-lab", 42, 25)
    power(42, 28)
    local committed = state.health_lab.get_inventory(defines.inventory.lab_input)
    assert(
      committed.insert({ name = mixtures.items[3], count = 1, health = wear.to_health(10) }) == 1
    )
  elseif tick == 930 then
    local credit = state.health_lab.get_stored_durability(mixtures.items[3]).durability
    assert(credit > 0 and credit < 1, "worn beaker did not become native credit")
    local mined = game.create_inventory(8)
    assert(
      state.health_lab.mine({ inventory = mined, raise_destroyed = true }),
      "worn lab mining failed"
    )
    local source = spawn("wooden-chest", 42, 25)
    local recovered = 0
    for _, dropped in
      pairs(state.surface.find_entities_filtered({
        type = "item-entity",
        area = { { 38, 21 }, { 46, 29 } },
      }))
    do
      if dropped.stack.name == mixtures.items[3] then
        assert(dropped.stack.health <= wear.to_health(10), "mining renewed committed beaker health")
        assert(
          math.abs(dropped.stack.durability - credit) < 0.000001,
          "worn credit durability changed"
        )
        recovered = recovered + dropped.stack.count
        assert(source.get_inventory(defines.inventory.chest)[1].transfer_stack(dropped.stack))
        if dropped.valid then
          dropped.destroy()
        end
      end
    end
    assert(recovered == 1, "worn credit recovery count")
    mined.destroy()
    state.recovered_arm = spawn("inserter", 43, 25, defines.direction.west)
    state.recovered_destination = spawn("wooden-chest", 44, 25)
    spawn("small-electric-pole", 43, 27)
  elseif tick == 960 then
    state.independent_credit = state.lab.get_stored_durability(mixtures.items[3]).durability
    assert(
      state.independent_credit > 0 and state.independent_credit < 1,
      "primary lab not consuming credit"
    )
    state.lab_pole.destroy()
    state.lab.energy = 0
    state.progress_before_other = game.forces.player.research_progress
    state.other_lab.disabled_by_script = false
  elseif tick == 1020 then
    assert(
      state.lab.get_stored_durability(mixtures.items[3]).durability == state.independent_credit,
      "other lab spent paused primary credit"
    )
    assert(
      game.forces.player.research_progress > state.progress_before_other,
      "second lab did not advance shared research"
    )
    state.other_credit = state.other_lab.get_stored_durability(mixtures.items[3]).durability
    assert(
      state.other_credit > 0 and state.other_credit < 1,
      "second lab has no independent credit"
    )
    force.research_queue = { "science-validation-raw" }
    state.other_lab.insert({ name = mixtures.packs[1], count = 1 })
    state.lab.insert({ name = mixtures.packs[1], count = 1 })
    state.lab_pole = spawn("small-electric-pole", -1, 27)
  elseif tick == 1050 then
    assert(
      state.lab.get_stored_durability(mixtures.items[3]).durability == state.independent_credit,
      "research switch erased primary credit"
    )
    assert(
      state.other_lab.get_stored_durability(mixtures.items[3]).durability == state.other_credit,
      "research switch erased second credit"
    )
    assert(
      game.forces.player.research_progress > 0,
      "single-science research did not use raw science"
    )
    assert(
      state.lab.get_inventory(defines.inventory.lab_input).get_item_count(mixtures.items[1]) == 1,
      "raw research consumed singleton beaker"
    )
    force.research_queue = { "science-validation-credit" }
  elseif tick == 1100 then
    assert(
      state.recovered_waste,
      "recovered committed credit did not denature on next actual pickup"
    )
    assert(
      state.recovered_destination
        .get_inventory(defines.inventory.chest)
        .get_item_count("shwc-denatured-science") == 1,
      "recovered waste count changed"
    )
    assert(
      state.lab.get_stored_durability(mixtures.items[3]).durability < state.independent_credit,
      "matching research did not resume primary credit"
    )
    assert(
      state.other_lab.get_stored_durability(mixtures.items[3]).durability < state.other_credit,
      "matching research did not resume second credit"
    )
  end
end

script.on_event(defines.events.on_tick, function(event)
  local state = storage.fixture
  local tick = event.tick
  if state.done then
    return
  end
  extended_tick(state, tick)
  for _, case in ipairs(state.arms) do
    if case.arm.valid then
      check_arm(case, mixtures.items[3], costs[case.name])
    end
  end
  check_arm(state.boundary, mixtures.items[3], 10)
  check_arm(state.failure, "shwc-denatured-science", 0)
  check_arm(state.waste, "shwc-denatured-science", 0)
  if tick == 10 then
    state.sample.insert({ name = mixtures.packs[2], count = 1 })
    -- Block after the craft has already consumed its input.
    local output = inventory(state.blocked)
    for index = 1, #output do
      assert(output[index].set_stack({ name = mixtures.items[index], count = 1 }))
    end
    assert(
      state.removal.mine({
        inventory = state.character.get_main_inventory(),
        raise_destroyed = true,
      }),
      "midcraft mining failed"
    )
    local red, green = 0, 0
    for _, dropped in
      pairs(state.surface.find_entities_filtered({
        type = "item-entity",
        area = { { 18, -2 }, { 22, 2 } },
      }))
    do
      if dropped.stack.name == mixtures.packs[1] then
        red = red + dropped.stack.count
      end
      if dropped.stack.name == mixtures.packs[2] then
        green = green + dropped.stack.count
      end
    end
    assert(
      red + state.character.get_main_inventory().get_item_count(mixtures.packs[1]) == 1
        and green + state.character.get_main_inventory().get_item_count(mixtures.packs[2]) == 1,
      "midcraft mining ingredients dropped "
        .. red
        .. "/"
        .. green
        .. " inventory "
        .. state.character.get_main_inventory().get_item_count(mixtures.packs[1])
        .. "/"
        .. state.character.get_main_inventory().get_item_count(mixtures.packs[2])
    )
  elseif tick == 90 then
    assert(inventory(state.red).get_item_count(mixtures.items[1]) == 1, "red recipe-free craft")
    assert(inventory(state.green).get_item_count(mixtures.items[2]) == 1, "green recipe-free craft")
    assert(inventory(state.combined).get_item_count(mixtures.items[3]) == 1, "combined craft")
    assert(inventory(state.blocked).get_item_count() == 3, "blocked output overwrote items")
    assert(inventory(state.unpowered).is_empty(), "unpowered mixer crafted")
    assert(
      state.unpowered
        .get_inventory(defines.inventory.crafter_input)
        .get_item_count(mixtures.packs[1]) == 1
    )
    state.credit_before_pause = state.lab.get_stored_durability(mixtures.items[3]).durability
    assert(
      state.credit_before_pause > 0 and state.credit_before_pause < 1,
      "native lab has no fractional credit"
    )
    state.lab_pole.destroy()
    state.lab.energy = 0
  elseif tick == 100 then
    state.reload.insert({ name = mixtures.packs[1], count = 1 })
    state.reload.insert({ name = mixtures.packs[2], count = 1 })
  elseif tick == checkpoint_tick then
    state.credit_checkpoint = state.lab.get_stored_durability(mixtures.items[3]).durability
    assert(state.credit_checkpoint == state.credit_before_pause, "power interruption spent credit")
    assert(inventory(state.reload).is_empty(), "midcraft checkpoint too late")
    assert(state.boundary.arm.held_stack.valid_for_read, "midhand checkpoint missing")
    state.checkpoint = true
    game.auto_save("science-validation-checkpoint", true)
    log("SCIENCE_VALIDATION_CHECKPOINT PASS")
  elseif tick == checkpoint_tick + 1 then
    assert(state.checkpoint, "checkpoint state missing after reload")
    assert(
      state.lab.get_stored_durability(mixtures.items[3]).durability == state.credit_checkpoint,
      "reload lost credit"
    )
    log("SCIENCE_VALIDATION_RESUMED PASS")
  elseif tick == 180 then
    assert(
      inventory(state.reload).get_item_count(mixtures.items[3]) == 1,
      "reload lost midcraft output"
    )
    assert(
      inventory(state.sample).get_item_count(mixtures.items[1]) == 1,
      "later ingredient changed active craft"
    )
    assert(
      inventory(state.sample).get_item_count(mixtures.items[2]) == 1,
      "later ingredient not next craft"
    )
    inventory(state.blocked).clear()
    state.lab_pole = spawn("small-electric-pole", -1, 27)
  elseif tick == 250 then
    assert(
      inventory(state.blocked).get_item_count(mixtures.items[3]) == 1,
      "blocked craft lost or duplicated output"
    )
    assert(
      state.blocked.get_inventory(defines.inventory.crafter_input).is_empty(),
      "blocked craft did not consume exactly once"
    )
    state.lab.disabled_by_script = true
    local credit = state.lab.get_stored_durability(mixtures.items[3]).durability
    assert(
      credit > 0 and credit < 1,
      "lab credit missing before mining "
        .. credit
        .. " progress "
        .. game.forces.player.research_progress
        .. " energy "
        .. state.lab.energy
    )
    local physical =
      state.lab.get_inventory(defines.inventory.lab_input).get_item_count(mixtures.items[3])
    assert(
      state.lab.mine({ inventory = state.character.get_main_inventory(), raise_destroyed = true }),
      "lab mining failed"
    )
    local returned = 0
    for _, dropped in
      pairs(state.surface.find_entities_filtered({
        type = "item-entity",
        area = { { -2, 23 }, { 2, 27 } },
      }))
    do
      if dropped.stack.name == mixtures.items[3] then
        returned = returned + dropped.stack.durability
      end
    end
    local recovered = state.character.get_main_inventory()
    for index = 1, #recovered do
      local stack = recovered[index]
      if stack.valid_for_read and stack.name == mixtures.items[3] then
        returned = returned + stack.durability * stack.count
      end
    end
    assert(
      math.abs(returned - credit - physical) < 0.000001,
      "mining lost fractional native science credit"
    )
    state.lab = spawn("shwc-lab", 0, 25)
    local lab_input = state.lab.get_inventory(defines.inventory.lab_input)
    for index = 1, #recovered do
      local stack = recovered[index]
      if stack.valid_for_read and mixtures.is_beaker(stack.name) then
        local target = lab_input
        if stack.name == mixtures.items[3] and stack.durability == 1 then
          target = state.lab_source.get_inventory(defines.inventory.chest)
        end
        assert(target.insert(stack) == stack.count, "mined stack not recoverable")
        stack.clear()
      end
    end
    for _, dropped in
      pairs(state.surface.find_entities_filtered({
        type = "item-entity",
        area = { { -2, 23 }, { 2, 27 } },
      }))
    do
      if dropped.stack.name == mixtures.items[3] then
        assert(lab_input.insert(dropped.stack) == 1, "recovered fractional Tool not insertable")
        dropped.destroy()
      end
    end
  elseif tick == finish_tick then
    for _, case in ipairs(state.arms) do
      assert(case.saw, "inserter never picked up: " .. case.name)
    end
    assert(
      state.boundary.saw and state.failure.saw and state.waste.saw,
      "wear boundary logistics missing"
    )
    local input = state.lab.get_inventory(defines.inventory.lab_input)
    assert(
      input.get_item_count(mixtures.items[1]) == 1 and input.get_item_count(mixtures.items[2]) == 1,
      "wrong mixes consumed"
    )
    assert(
      game.forces.player.technologies["science-validation-research"].researched,
      "native five-beaker research did not complete"
    )

    state.done = true
    log("SCIENCE_VALIDATION_FINAL PASS")
  end
end)
