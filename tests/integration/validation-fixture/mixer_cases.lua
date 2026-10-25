-- luacheck: read globals game defines log
local mixtures = require("__science-handle-with-care__/shared/mixtures")
local support = require("fixture_support")
local mixer, spawn, inventory = support.mixer, support.spawn, support.inventory
local M = {}

function M.setup_initial(state)
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
end

function M.setup_timing(state)
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
end

function M.extended_tick(state, tick)
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
    assert(
      inventory(state.circuit).get_item_count(mixtures.packs[1]) == 1,
      "resumed circuit craft lost output"
    )
  end
end

function M.tick(state, tick)
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
  elseif tick == 100 then
    state.reload.insert({ name = mixtures.packs[1], count = 1 })
    state.reload.insert({ name = mixtures.packs[2], count = 1 })
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
  elseif tick == 250 then
    assert(
      inventory(state.blocked).get_item_count(mixtures.beaker) == 1,
      "blocked craft lost or duplicated output"
    )
    assert(
      state.blocked.get_inventory(defines.inventory.crafter_input).is_empty(),
      "blocked craft did not consume exactly once"
    )
  end
end

function M.checkpoint(state)
  assert(inventory(state.reload).is_empty(), "midcraft checkpoint too late")
  state.native_progress_checkpoint = state.reload.crafting_progress
  assert(
    state.native_progress_checkpoint > 0 and state.native_progress_checkpoint < 1,
    "midcraft native progress bar missing"
  )
end

function M.resumed(state)
  assert(
    state.reload.crafting_progress > state.native_progress_checkpoint,
    "native progress did not resume from serialized midpoint"
  )
end

function M.finish(state)
  assert(
    inventory(state.red).get_item_count(mixtures.packs[1]) == 2,
    "raw passthrough lost second stacked pack"
  )
end

return M
