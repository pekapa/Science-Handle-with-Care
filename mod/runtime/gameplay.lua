local mixtures = require("shared.mixtures")
local constants = require("shared.constants")
local wear = require("shared.wear")
local gameplay = {}

function gameplay.init()
  storage.mixers = {}
  storage.arms = {}
  for _, force in pairs(game.forces) do
    if force.technologies["logistic-science-pack"].researched then
      force.recipes["shwc-mixer"].enabled = true
      force.recipes["shwc-lab"].enabled = true
    end
  end
  -- Installation into an existing save needs one bootstrap scan, never a tick scan.
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ type = "inserter" })) do
      gameplay.built({ entity = entity })
    end
    for _, entity in pairs(surface.find_entities_filtered({ name = "shwc-mixer" })) do
      gameplay.built({ entity = entity })
    end
  end
end

function gameplay.built(event)
  local entity = event.entity or event.created_entity or event.destination
  if not (entity and entity.valid) then
    return
  end
  if entity.name == "shwc-mixer" then
    entity.disabled_by_script = true
    storage.mixers[entity.unit_number] = { entity = entity }
  elseif entity.type == "inserter" then
    storage.arms[entity.unit_number] = { entity = entity, holding = false }
  end
end

local function spill(entity, stack)
  entity.surface.spill_item_stack({
    position = entity.position,
    stack = stack,
    enable_looted = true,
    force = entity.force,
    allow_belts = false,
  })
end

function gameplay.removed(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  if not entity.unit_number then
    return
  end
  local function recover(stack)
    if event.buffer then
      assert(event.buffer.insert(stack) == stack.count)
    else
      spill(entity, stack)
    end
  end
  -- Success events run while the entity is valid, after native mining results
  -- have been collected. A failed pre-mining event must never change state.
  if
    event.name == defines.events.on_entity_died
    or event.name == defines.events.script_raised_destroy
  then
    local inventories = {}
    if entity.name == "shwc-mixer" then
      inventories = { defines.inventory.crafter_input, defines.inventory.crafter_output }
    elseif entity.name == "shwc-lab" then
      inventories = { defines.inventory.lab_input }
    end
    for _, id in ipairs(inventories) do
      local inventory = entity.get_inventory(id)
      for index = 1, #inventory do
        if inventory[index].valid_for_read then
          recover(inventory[index])
          inventory[index].clear()
        end
      end
    end
    if entity.type == "inserter" and entity.held_stack.valid_for_read then
      recover(entity.held_stack)
      entity.held_stack.clear()
    end
  end
  local state = storage.mixers[entity.unit_number]
  if state and state.output then
    -- Return the ingredients of an unfinished craft, or its completed beaker.
    if state.progress >= 60 then
      recover({ name = state.output, count = 1 })
    else
      for _, name in ipairs(state.ingredients) do
        recover({ name = name, count = 1 })
      end
    end
    state.output = nil
  end
  if entity.name == "shwc-lab" then
    for _, name in ipairs(entity.prototype.lab_inputs) do
      local credit = entity.get_stored_durability(name)
      if credit.durability > 0 then
        recover({
          name = name,
          count = 1,
          durability = credit.durability,
          health = mixtures.is_beaker(name) and wear.to_health(constants.wear_budget) or 1,
          quality = credit.quality and credit.quality.name,
        })
        entity.set_stored_durability(name, { durability = 0, quality = "normal" })
      end
    end
  end
  storage.mixers[entity.unit_number] = nil
  storage.arms[entity.unit_number] = nil
end

local function pickup(state)
  local entity = state.entity
  local hand = entity.held_stack
  local holding = hand.valid_for_read
  if holding and not state.holding and mixtures.is_beaker(hand.name) then
    local cost = constants.pickup_cost[entity.name] or 4
    local steps = wear.after_pickup(wear.from_health(hand.health), cost)
    if wear.is_failed(steps) then
      hand.set_stack({
        name = "shwc-denatured-science",
        count = hand.count,
        quality = hand.quality,
      })
    else
      hand.health = wear.to_health(steps)
    end
  end
  state.holding = holding
end

local function status(state, key, diode, value)
  if state.status == key and state.status_value == value then
    return
  end
  state.status, state.status_value = key, value
  state.entity.custom_status = {
    diode = defines.entity_status_diode[diode],
    label = { "entity-status.shwc-" .. key, value },
  }
end

local function mix(state)
  local entity = state.entity
  if entity.disabled_by_control_behavior or entity.to_be_deconstructed() then
    status(state, "paused", "yellow")
    return
  end
  if entity.energy < 1500 then
    status(state, "no-power", "red")
    return
  end
  local output = entity.get_inventory(defines.inventory.crafter_output)
  if state.output then
    if state.progress < 60 then
      entity.energy = entity.energy - 1500
      state.progress = state.progress + 1
      status(state, "mixing", "green", math.floor(state.progress * 100 / 60))
    end
    if
      state.progress >= 60
      and output.get_item_count() < 3
      and output.insert({ name = state.output, count = 1 }) == 1
    then
      state.output = nil
      status(state, "ready", "green")
    elseif state.progress >= 60 then
      status(state, "output-full", "yellow")
    end
    return
  end
  if output.get_item_count() >= 3 then
    status(state, "output-full", "yellow")
    return
  end
  local input = entity.get_inventory(defines.inventory.crafter_input)
  local red = input.get_item_count(mixtures.packs[1]) > 0
  local green = input.get_item_count(mixtures.packs[2]) > 0
  if not (red or green) then
    status(state, "waiting", "yellow")
    return
  end
  state.output = mixtures.output(red, green)
  state.ingredients = {}
  for index, present in ipairs({ red, green }) do
    if present then
      local name = mixtures.packs[index]
      assert(input.remove({ name = name, count = 1 }) == 1)
      state.ingredients[#state.ingredients + 1] = name
    end
  end
  state.progress = 0
  status(state, "mixing", "green", 0)
end

function gameplay.tick()
  for id, state in pairs(storage.arms) do
    if state.entity.valid then
      pickup(state)
    else
      storage.arms[id] = nil
    end
  end
  for id, state in pairs(storage.mixers) do
    if state.entity.valid then
      mix(state)
    else
      storage.mixers[id] = nil
    end
  end
end

return gameplay
