local mixtures = require("__science-handle-with-care__/shared/mixtures")
local wear = require("__science-handle-with-care__/shared/wear")
local checkpoint_tick = 120
local finish_tick = 2400

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

-- Observe the actual production worker; fixture code never admits science.
local function worker(shell)
  return assert(
    shell.surface.find_entities_filtered({
      name = "shwc-lab-worker",
      position = shell.position,
      radius = 0.1,
    })[1],
    "native worker missing"
  )
end
local function salvage_lab(shell, inventory)
  local surface, position = shell.surface, shell.position
  shell.destroy({ raise_destroy = true })
  for _, dropped in
    pairs(surface.find_entities_filtered({ type = "item-entity", position = position, radius = 3 }))
  do
    assert(inventory.insert(dropped.stack) == dropped.stack.count, "salvage inventory full")
    dropped.destroy()
  end
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

script.on_init(function()
  for name in pairs(script.active_mods) do
    assert(
      name == "base" or name == "science-handle-with-care" or name == "science-validation-fixture",
      "unexpected enabled mod: " .. name
    )
  end
  assert(not prototypes.entity["shwc-lab"], "separate beaker lab still exists")
  assert(
    not prototypes.item["shwc-beaker-red"] and not prototypes.item["shwc-beaker-green"],
    "single-science fragile prototypes still exist"
  )
  local lab_recipe = game.forces.player.recipes.lab
  local ingredients = {}
  for _, ingredient in pairs(lab_recipe.ingredients) do
    ingredients[ingredient.name] = ingredient.amount
  end
  assert(
    ingredients["electronic-circuit"] == 10
      and ingredients["iron-gear-wheel"] == 10
      and ingredients["transport-belt"] == 4,
    "ordinary lab recipe changed"
  )
  assert(prototypes.item.lab.place_result.name == "lab", "ordinary lab item changed")
  for _, technology in pairs(game.forces.player.technologies) do
    for _, effect in pairs(technology.prototype.effects) do
      assert(effect.recipe ~= "shwc-lab", "extra lab unlock remains")
    end
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
  state.conventional_force = game.create_force("conventional-science-validation")
  state.conventional_force.research_queue = { "science-validation-conventional" }
  state.conventional_lab = assert(surface.create_entity({
    name = "lab",
    position = { -50, 25 },
    force = state.conventional_force,
    raise_built = true,
  }))
  assert(#state.conventional_lab.get_inventory(defines.inventory.chest) == 1)
  local conventional_pole = spawn("small-electric-pole", -50, 27)
  conventional_pole.force = state.conventional_force
  local conventional_power = spawn("electric-energy-interface", -50, 30)
  conventional_power.force = state.conventional_force
  conventional_power.energy = 1000000000
  assert(state.conventional_lab.insert({ name = "automation-science-pack", count = 1 }) == 1)
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
  assert(
    game.forces.player.recipes["shwc-mixer"].enabled,
    "existing green research did not unlock new machines"
  )
  state.character = spawn("character", 50, 30)
  state.red = mixer(-30, 0, 2)
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
  state.boundary = arm_case("inserter", 46, 8)
  state.failure = arm_case("fast-inserter", -50, 8)
  state.raw_arm = arm_case("fast-inserter", -26, 0, mixtures.packs[1])
  state.waste = arm_case("inserter", -42, 0, "shwc-denatured-science")
  state.lab = spawn("lab", 0, 25)
  state.lab_pole = spawn("small-electric-pole", -1, 27)
  state.lab_power = spawn("electric-energy-interface", 0, 30)
  state.lab_power.energy = 1000000000
  local lab_input = state.lab.get_inventory(defines.inventory.chest)
  assert(lab_input and #lab_input == 1, "lab needs one physical generic input slot")
  assert(lab_input.insert({ name = mixtures.packs[2], count = 1 }) == 1)
  for _, name in ipairs({ mixtures.packs[1], mixtures.beaker }) do
    assert(lab_input.insert({ name = name, count = 1 }) == 0, "occupied Lab accepted " .. name)
    assert(
      lab_input[1].name == mixtures.packs[2] and lab_input[1].count == 1,
      "competing insertion changed wrong science"
    )
  end
  local blocked_force = game.create_force("blocked-lab-validation")
  blocked_force.research_queue = { "science-validation-research" }
  state.blocked_lab = { force = blocked_force, blocked_ticks = 0 }
  local blocked_lab = state.blocked_lab
  blocked_lab.shell = spawn("lab", -35, -32)
  blocked_lab.source = spawn("wooden-chest", -38, -32)
  blocked_lab.arm = spawn("inserter", -37, -32, defines.direction.west)
  local blocked_pole = spawn("small-electric-pole", -36, -30)
  local blocked_power = spawn("electric-energy-interface", -35, -27)
  for _, entity in ipairs({
    blocked_lab.shell,
    blocked_lab.source,
    blocked_lab.arm,
    blocked_pole,
    blocked_power,
  }) do
    entity.force = blocked_force
  end
  blocked_power.energy = 1000000000
  assert(blocked_lab.source.insert({ name = mixtures.beaker, count = 1 }) == 1)
  state.lab_source = spawn("wooden-chest", -3, 25)
  spawn("inserter", -2, 25, defines.direction.west)
  assert(state.lab_source.insert({ name = mixtures.beaker, count = 4 }) == 4)
  local technology = game.forces.player.technologies["science-validation-research"]
  assert(#technology.research_unit_ingredients == 1, "equal red/green technology not converted")
  assert(technology.research_unit_ingredients[1].name == mixtures.beaker)
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
  belt_item.set_stack({ name = mixtures.beaker, count = 1 })
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

local function check_blocked_lab(case, tick)
  if case.done then
    return
  end
  local input = case.shell.get_inventory(defines.inventory.chest)
  local native = worker(case.shell)
  local hand = case.arm.held_stack
  local credit = native.get_stored_durability(mixtures.beaker).durability
  assert(
    native.get_inventory(defines.inventory.lab_input).is_empty(),
    "blocked Lab worker buffered"
  )
  if not case.released then
    -- An already-full destination can prevent pickup; obstruct the observed real pickup.
    if not case.obstructed and hand.valid_for_read then
      assert(input.insert({ name = mixtures.packs[2], count = 1 }) == 1)
      case.obstructed = true
    end
    if case.obstructed then
      assert(input[1].name == mixtures.packs[2] and input[1].count == 1, "wrong science escaped")
    else
      assert(input.is_empty(), "Lab received beaker before observed pickup")
    end
    assert(credit == 0 and case.force.research_progress == 0, "blocked Lab admitted science")
    assert(
      case.source.get_item_count(mixtures.beaker) + (hand.valid_for_read and hand.count or 0) == 1,
      "blocked Lab transport lost or duplicated beaker"
    )
    if hand.valid_for_read then
      assert(
        hand.name == mixtures.beaker and wear.from_health(hand.health) == 1,
        "blocked Lab pickup wear changed"
      )
    end
    if case.arm.status == defines.entity_status.waiting_for_space_in_destination then
      assert(
        hand.valid_for_read and case.arm.energy > 0,
        "blocked Lab arm did not attempt delivery"
      )
      case.blocked_ticks = case.blocked_ticks + 1
    else
      case.blocked_ticks = 0
    end
    if case.blocked_ticks == 100 then
      input.clear()
      case.released = true
      log("SCIENCE_LAB_BLOCKED PASS held=100")
    end
    assert(tick < 300 or case.released, "Lab arm never held blocked delivery for 100 ticks")
  elseif credit > 0 and case.force.research_progress > 0 then
    assert(
      input.is_empty() and not hand.valid_for_read,
      "released Lab did not admit delivered beaker"
    )
    assert(case.source.get_item_count(mixtures.beaker) == 0, "released Lab left source beaker")
    case.done = true
    log("SCIENCE_LAB_RELEASED PASS")
  end
  assert(tick < 400 or case.done, "removing wrong science did not permit delivery and research")
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
  if tick == 10 then
    assert(
      state.lab.get_inventory(defines.inventory.chest)[1].name == mixtures.packs[2],
      "wrong mixture did not block single physical slot"
    )
    assert(
      worker(state.lab).get_inventory(defines.inventory.lab_input).is_empty(),
      "worker has physical science buffer"
    )
    state.lab.get_inventory(defines.inventory.chest).clear()
    assert(state.lab.insert({ name = mixtures.beaker, count = 1 }) == 1)
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
      inventory(state.failed_mine).get_item_count(mixtures.beaker) == 1,
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
  elseif tick == 431 then
    assert(
      math.abs(state.timing.crafting_progress - 0.5) < 0.000001,
      "native progress bar not halfway after thirty powered ticks"
    )
  elseif tick == 460 then
    assert(inventory(state.timing).is_empty(), "craft completed before sixty powered ticks")
  elseif tick == 461 then
    assert(
      inventory(state.timing).get_item_count(mixtures.packs[1]) == 1,
      "craft did not complete after exactly sixty powered ticks"
    )
    assert(state.timing.crafting_progress == 0, "native progress did not reset on delivery")
  elseif tick == 490 then
    local existing_output = state.bootstrap_destination.get_inventory(defines.inventory.chest)[1]
    assert(
      existing_output.valid_for_read
        and existing_output.name == mixtures.beaker
        and wear.from_health(existing_output.health) == 4,
      "existing-world inserter was not registered or charged"
    )
    assert(
      inventory(state.circuit).get_item_count(mixtures.packs[1]) == 1,
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
      if stack.valid_for_read and stack.name == mixtures.beaker then
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
      state.lab.get_inventory(defines.inventory.chest).get_item_count(mixtures.beaker) == 0,
      "five-unit research left physical beakers"
    )
    assert(
      worker(state.lab).get_stored_durability(mixtures.beaker).durability < 0.000001,
      "five-unit research left unexpected credit"
    )
    state.lab.insert({ name = mixtures.beaker, count = 1 })
    force.research_queue = { "science-validation-credit" }
    state.other_lab = spawn("lab", 12, 25)
    power(12, 27)
    worker(state.other_lab).disabled_by_script = true
    state.other_lab.insert({ name = mixtures.beaker, count = 1 })
    state.health_lab = spawn("lab", 42, 25)
    power(42, 27)
    local committed = state.health_lab.get_inventory(defines.inventory.chest)
    assert(committed.insert({ name = mixtures.beaker, count = 1, health = wear.to_health(9) }) == 1)
  elseif tick == 930 then
    local credit = worker(state.health_lab).get_stored_durability(mixtures.beaker).durability
    assert(credit > 0 and credit < 1, "worn beaker did not become native credit")
    assert(
      worker(state.health_lab).get_module_inventory().insert({ name = "speed-module", count = 1 })
        == 1
    )
    local mined = game.create_inventory(8)
    local native = worker(state.health_lab)
    salvage_lab(state.health_lab, mined)
    assert(not native.valid, "script removal orphaned worker")
    assert(mined.get_item_count("speed-module") == 1, "removal lost worker module")
    local tagged = assert(mined.find_item_stack("lab"), "removal lost credit item")
    assert(#tagged.tags.sciencecredits == 1, "removal lost tagged credit")
    assert(
      math.abs(tagged.tags.sciencecredits[1].durability - credit) < 0.000001,
      "removal changed fractional mixed credit"
    )
    mined.destroy()
  elseif tick == 960 then
    state.independent_credit = worker(state.lab).get_stored_durability(mixtures.beaker).durability
    assert(
      state.independent_credit > 0 and state.independent_credit < 1,
      "primary lab not consuming credit"
    )
    state.lab_pole.destroy()
    worker(state.lab).energy = 0
    state.progress_before_other = game.forces.player.research_progress
    worker(state.other_lab).disabled_by_script = false
  elseif tick == 1020 then
    assert(
      worker(state.lab).get_stored_durability(mixtures.beaker).durability
        == state.independent_credit,
      "other lab spent paused primary credit"
    )
    assert(
      game.forces.player.research_progress > state.progress_before_other,
      "second lab did not advance shared research"
    )
    state.other_credit = worker(state.other_lab).get_stored_durability(mixtures.beaker).durability
    assert(
      state.other_credit > 0 and state.other_credit < 1,
      "second lab has no independent credit"
    )
    force.research_queue = { "science-validation-raw" }
    state.other_lab.insert({ name = mixtures.packs[1], count = 1 })
    state.lab.insert({ name = mixtures.packs[1], count = 1 })
    state.lab_pole = spawn("small-electric-pole", -1, 27)
    state.tagged_input_shell = spawn("lab", 24, 25)
    power(24, 27)
    assert(state.tagged_input_shell.insert({ name = mixtures.packs[1], count = 1 }) == 1)
  elseif tick == 1050 then
    state.tagged_input_worker = worker(state.tagged_input_shell)
    state.tagged_input_worker.disabled_by_script = true
    state.tagged_shell_credit =
      state.tagged_input_worker.get_stored_durability(mixtures.packs[1]).durability
    assert(state.tagged_shell_credit > 0 and state.tagged_shell_credit < 1)
    assert(
      worker(state.lab).get_stored_durability(mixtures.beaker).durability
        == state.independent_credit,
      "research switch erased primary credit"
    )
    assert(
      worker(state.other_lab).get_stored_durability(mixtures.beaker).durability
        == state.other_credit,
      "research switch erased second credit"
    )
    assert(
      game.forces.player.research_progress > 0,
      "single-science research did not use raw science"
    )
    local raw = worker(state.other_lab).get_stored_durability(mixtures.packs[1]).durability
    assert(raw > 0 and raw < 1, "raw science did not retain fractional native credit")
    force.research_queue = { "science-validation-credit" }
  elseif tick == 1100 then
    worker(state.other_lab).disabled_by_script = true
    state.robot_credit = {}
    for _, name in ipairs(worker(state.other_lab).prototype.lab_inputs) do
      state.robot_credit[name] = worker(state.other_lab).get_stored_durability(name).durability
    end
    assert(
      worker(state.other_lab)
        .get_module_inventory()
        .insert({ name = "productivity-module", count = 1 }) == 1
    )
    state.robot_worker = worker(state.other_lab)
    state.robot_shell = state.other_lab
    local port = spawn("roboport", 18, 33)
    port.energy = 100000000
    spawn("small-electric-pole", 20, 31)
    local source = spawn("electric-energy-interface", 23, 31)
    source.energy = 1000000000
    state.robot_chest = spawn("storage-chest", 18, 29)
    assert(port.insert({ name = "construction-robot", count = 10 }) == 10)
    assert(state.robot_shell.insert({ name = "lab", count = 2 }) == 2)
    assert(state.robot_shell.order_deconstruction(game.forces.player))
    local incoming = state.tagged_input_shell.get_inventory(defines.inventory.chest)[1]
    incoming.set_stack({ name = "lab", count = 1 })
    incoming.tags = {
      sciencecredits = { { name = mixtures.packs[2], durability = 0.375, quality = "normal" } },
      fixture_marker = "already-credited-input",
      fixture_metadata = { value = 17 },
    }
    assert(state.tagged_input_shell.order_deconstruction(game.forces.player))
    local primary_credit = worker(state.lab).get_stored_durability(mixtures.beaker).durability
    assert(
      primary_credit < state.independent_credit,
      "matching research did not resume primary credit"
    )
    local other_credit = worker(state.other_lab).get_stored_durability(mixtures.beaker).durability
    assert(other_credit < state.other_credit, "matching research did not resume second credit")
  end
end

local function robot_tick(state)
  if not state.robot_shell then
    return
  end
  local delivered = state.robot_chest.get_inventory(defines.inventory.chest)
  if
    not state.robot_mined
    and not state.robot_shell.valid
    and not state.tagged_input_shell.valid
    and delivered.get_item_count("lab") == 5
    and delivered.get_item_count("productivity-module") == 1
  then
    assert(
      not state.robot_shell.valid and not state.robot_worker.valid,
      "robot mining left shell or worker"
    )
    local input = state.robot_chest.get_inventory(defines.inventory.chest)
    assert(not state.tagged_input_worker.valid, "tagged-input mining orphaned worker")
    state.extra_labs = game.create_inventory(8)
    local incoming_count, shell_count = 0, 0
    for i = 1, #input do
      local stack = input[i]
      if stack.valid_for_read and stack.name == "lab" and stack.tags.sciencecredits then
        local tags = stack.tags
        if tags.fixture_marker then
          assert(tags.fixture_marker == "already-credited-input", "input marker overwritten")
          assert(tags.fixture_metadata.value == 17, "input metadata overwritten")
          assert(#tags.sciencecredits == 1, "input gained credit")
          local credit = tags.sciencecredits[1]
          assert(
            credit.name == mixtures.packs[2]
              and credit.durability == 0.375
              and credit.quality == "normal",
            "tagged input credit overwritten"
          )
          incoming_count = incoming_count + stack.count
          assert(state.extra_labs.insert(stack) == stack.count)
          stack.clear()
        elseif #tags.sciencecredits == 1 and tags.sciencecredits[1].name == mixtures.packs[1] then
          assert(
            math.abs(tags.sciencecredits[1].durability - state.tagged_shell_credit) < 0.000001,
            "tagged-input shell credit changed"
          )
          shell_count = shell_count + stack.count
          assert(state.extra_labs.insert(stack) == stack.count)
          stack.clear()
        end
      end
    end
    assert(incoming_count == 1, "tagged Lab input lost or duplicated")
    assert(shell_count == 1, "tagged-input shell credit lost or duplicated")
    local lab
    for i = 1, #input do
      local stack = input[i]
      if stack.valid_for_read and stack.name == "lab" and stack.tags.sciencecredits then
        lab = stack
        break
      end
    end
    assert(lab, "robot did not deliver credited mined lab")
    assert(lab.tags and lab.tags.sciencecredits, "robot mined lab lost credit tags")
    assert(lab.count == 1, "robot mining tagged multiple Lab items with the same credit")
    local untagged = 0
    for i = 1, #input do
      local stack = input[i]
      if stack.valid_for_read and stack.name == "lab" and not stack.tags.sciencecredits then
        untagged = untagged + stack.count
        assert(state.extra_labs.insert(stack) == stack.count)
        stack.clear()
      end
    end
    assert(untagged == 2, "robot mining changed untagged Lab input items")
    assert(input.get_item_count("lab") == 1, "robot mining returned extra credit carriers")
    log("SCIENCE_TAGGED_INPUT_ROBOT PASS incoming=1 shell=1 original=1 untagged=2")

    assert(input.get_item_count("productivity-module") == 1, "robot mining lost native module")
    local tags = lab.tags
    local restored = {}
    for _, credit in ipairs(tags.sciencecredits) do
      restored[credit.name] = credit.durability
    end
    for name, amount in pairs(state.robot_credit) do
      assert(
        math.abs((restored[name] or 0) - amount) < 0.000001,
        "robot mining changed " .. name .. " credit"
      )
    end
    state.robot_ghost = state.surface.create_entity({
      name = "entity-ghost",
      inner_name = "lab",
      position = { 12, 25 },
      force = game.forces.player,
    })
    -- Actual robot placement consumes the tagged item delivered by construction robots.
    state.robot_mined = true
  elseif state.robot_mined and not state.robot_rebuilt and not state.robot_ghost.valid then
    local shell = assert(
      state.surface.find_entities_filtered({ name = "lab", position = { 12, 25 }, radius = 1 })[1],
      "robot rebuilt shell absent"
    )
    state.restored_robot_lab = shell
    local native = worker(shell)
    local raw = native.get_stored_durability(mixtures.packs[1]).durability
    assert(
      math.abs(raw - state.robot_credit[mixtures.packs[1]]) < 0.000001,
      "robot build lost fractional raw credit"
    )
    local mixed = native.get_stored_durability(mixtures.beaker).durability
    if mixed > 0 and mixed < state.robot_credit[mixtures.beaker] then
      state.robot_rebuilt = true
    end
  end
end

script.on_event(defines.events.on_tick, function(event)
  local state = storage.fixture
  local tick = event.tick
  if state.done then
    return
  end
  for _, entity in pairs(state.surface.find_entities_filtered({ name = "shwc-lab-worker" })) do
    assert(
      entity.get_inventory(defines.inventory.lab_input).is_empty(),
      "hidden physical science buffer"
    )
  end
  if tick == 10 or tick == 20 then
    assert(
      state.conventional_lab.get_inventory(defines.inventory.chest).is_empty(),
      "conventional three-science research blocked required raw ingredient"
    )
    local next_pack = tick == 10 and "logistic-science-pack" or "chemical-science-pack"
    assert(state.conventional_lab.insert({ name = next_pack, count = 1 }) == 1)
  elseif tick == 110 then
    assert(
      state.conventional_force.technologies["science-validation-conventional"].researched,
      "conventional three-science research did not complete"
    )
    assert(
      state.conventional_lab.get_inventory(defines.inventory.chest).is_empty(),
      "conventional research left physical input"
    )
    local native = worker(state.conventional_lab)
    for _, name in ipairs({
      "automation-science-pack",
      "logistic-science-pack",
      "chemical-science-pack",
    }) do
      assert(
        native.get_stored_durability(name).durability < 0.000001,
        "conventional research did not consume exactly one " .. name
      )
    end
  end
  extended_tick(state, tick)
  check_blocked_lab(state.blocked_lab, tick)
  robot_tick(state)
  for _, case in ipairs(state.arms) do
    if case.arm.valid then
      check_arm(case, mixtures.beaker, costs[case.name])
    end
  end
  check_arm(state.boundary, mixtures.beaker, 9)
  check_arm(state.failure, "shwc-denatured-science", 0)
  check_arm(state.raw_arm, mixtures.packs[1], 0)
  check_arm(state.waste, "shwc-denatured-science", 0)
  if tick == 10 then
    state.sample.insert({ name = mixtures.packs[2], count = 1 })
    -- Block after the craft has already consumed its input.
    local output = inventory(state.blocked)
    for index = 1, #output do
      assert(output[index].set_stack({ name = mixtures.outputs[index], count = 1 }))
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
    -- This inventory is reused for the independent lab mining regression.
    state.character.get_main_inventory().clear()
  elseif tick == 90 then
    assert(inventory(state.red).get_item_count(mixtures.packs[1]) == 1, "red passthrough count")
    local red = inventory(state.red).find_item_stack(mixtures.packs[1])
    assert(
      red.name == mixtures.packs[1] and red.health == 1,
      "passthrough changed ordinary science identity or health"
    )
    assert(inventory(state.green).get_item_count(mixtures.packs[2]) == 1, "green recipe-free craft")
    assert(inventory(state.combined).get_item_count(mixtures.beaker) == 1, "combined craft")
    assert(inventory(state.blocked).get_item_count() == 3, "blocked output overwrote items")
    assert(inventory(state.unpowered).is_empty(), "unpowered mixer crafted")
    assert(
      state.unpowered
        .get_inventory(defines.inventory.crafter_input)
        .get_item_count(mixtures.packs[1]) == 1
    )
    state.credit_before_pause = worker(state.lab).get_stored_durability(mixtures.beaker).durability
    assert(
      state.credit_before_pause > 0 and state.credit_before_pause < 1,
      "native lab has no fractional credit: "
        .. state.credit_before_pause
        .. " energy="
        .. worker(state.lab).energy
        .. " status="
        .. worker(state.lab).status
    )
    state.lab_pole.destroy()
    worker(state.lab).energy = 0
  elseif tick == 100 then
    state.reload.insert({ name = mixtures.packs[1], count = 1 })
    state.reload.insert({ name = mixtures.packs[2], count = 1 })
  elseif tick == checkpoint_tick then
    state.credit_checkpoint = worker(state.lab).get_stored_durability(mixtures.beaker).durability
    assert(state.credit_checkpoint == state.credit_before_pause, "power interruption spent credit")
    assert(inventory(state.reload).is_empty(), "midcraft checkpoint too late")
    state.native_progress_checkpoint = state.reload.crafting_progress
    assert(
      state.native_progress_checkpoint > 0 and state.native_progress_checkpoint < 1,
      "midcraft native progress bar missing"
    )
    assert(state.boundary.arm.held_stack.valid_for_read, "midhand checkpoint missing")
    state.checkpoint = true
    game.auto_save("science-validation-checkpoint", true)
    log("SCIENCE_VALIDATION_CHECKPOINT PASS")
  elseif tick == checkpoint_tick + 1 then
    assert(state.checkpoint, "checkpoint state missing after reload")
    local credit = worker(state.lab).get_stored_durability(mixtures.beaker).durability
    assert(credit == state.credit_checkpoint, "reload lost credit")
    assert(
      state.reload.crafting_progress > state.native_progress_checkpoint,
      "native progress did not resume from serialized midpoint"
    )
    log("SCIENCE_VALIDATION_RESUMED PASS")
  elseif tick == 180 then
    assert(
      inventory(state.reload).get_item_count(mixtures.beaker) == 1,
      "reload lost midcraft output"
    )
    assert(
      inventory(state.sample).get_item_count(mixtures.packs[1]) == 1,
      "later ingredient changed active craft"
    )
    assert(
      inventory(state.sample).get_item_count(mixtures.packs[2]) == 1,
      "later ingredient not next craft"
    )
    inventory(state.blocked).clear()
    state.lab_pole = spawn("small-electric-pole", -1, 27)
  elseif tick == 250 then
    assert(
      inventory(state.blocked).get_item_count(mixtures.beaker) == 1,
      "blocked craft lost or duplicated output"
    )
    assert(
      state.blocked.get_inventory(defines.inventory.crafter_input).is_empty(),
      "blocked craft did not consume exactly once"
    )
  elseif tick == 2000 then
    assert(
      state.robot_mined,
      "robot mining/delivery deadline exceeded: original="
        .. tostring(state.robot_shell.valid)
        .. " tagged="
        .. tostring(state.tagged_input_shell.valid)
        .. " Labs="
        .. state.robot_chest.get_item_count("lab")
        .. " modules="
        .. state.robot_chest.get_item_count("productivity-module")
    )
  elseif tick == 2300 then
    assert(state.robot_rebuilt, "robot rebuild/research deadline exceeded")
  elseif tick == 2350 then
    local shell = state.restored_robot_lab
    local native = worker(shell)
    native.disabled_by_script = true
    assert(native.get_module_inventory().insert({ name = "speed-module", count = 1 }) == 1)
    state.lifecycle_credit = {}
    for _, name in ipairs(native.prototype.lab_inputs) do
      state.lifecycle_credit[name] = native.get_stored_durability(name).durability
    end
    script.raise_script_built({ entity = shell })
    assert(worker(shell) == native, "duplicate build replaced worker")
    assert(#shell.surface.find_entities_filtered({
      name = "shwc-lab-worker",
      position = shell.position,
      radius = 0.1,
    }) == 1, "duplicate build orphaned worker")
    local clone = assert(shell.clone({ position = { 52, 25 } }), "native shell clone failed")
    local clone_worker = worker(clone)
    local duplicate = native.clone({ position = clone.position })
    assert(not duplicate or not duplicate.valid, "native worker clone orphaned paid science")
    assert(clone_worker.get_module_inventory().is_empty(), "clone duplicated modules")
    for _, name in ipairs(clone_worker.prototype.lab_inputs) do
      assert(clone_worker.get_stored_durability(name).durability == 0, "clone duplicated credit")
    end
    clone.destroy({ raise_destroy = true })
    assert(not clone_worker.valid, "cloned shell removal orphaned worker")
    assert(shell.teleport({ 14, 25 }), "same-surface shell teleport failed")
    state.lifecycle_worker = native
  elseif tick == 2351 then
    local shell = state.restored_robot_lab
    local native = worker(shell)
    assert(
      not state.lifecycle_worker.valid or native == state.lifecycle_worker,
      "teleport orphaned old worker"
    )
    assert(
      native.get_module_inventory().get_item_count("speed-module") == 1,
      "teleport lost module"
    )
    for name, amount in pairs(state.lifecycle_credit) do
      assert(
        math.abs(native.get_stored_durability(name).durability - amount) < 0.000001,
        "duplicate build or teleport changed " .. name .. " credit"
      )
    end
    native.destroy({ raise_destroy = true })
    assert(not shell.valid, "worker removal left unpaired shell")
  elseif tick == finish_tick then
    for _, case in ipairs(state.arms) do
      assert(case.saw, "inserter never picked up: " .. case.name)
    end
    assert(
      state.boundary.saw and state.failure.saw and state.waste.saw and state.raw_arm.saw,
      "wear boundary logistics missing"
    )
    local input = state.lab.get_inventory(defines.inventory.chest)
    assert(#input == 1, "lab physical input size changed")
    assert(
      game.forces.player.technologies["science-validation-research"].researched,
      "native five-beaker research did not complete"
    )

    assert(
      inventory(state.red).get_item_count(mixtures.packs[1]) == 2,
      "raw passthrough lost second stacked pack"
    )
    state.done = true
    log("SCIENCE_VALIDATION_FINAL PASS")
  end
end)
