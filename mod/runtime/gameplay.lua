local mixtures = require("shared.mixtures")
local constants = require("shared.constants")
local wear = require("shared.wear")
local labs = require("runtime.labs")
local gameplay = {}

---@class MixerState Tracked mixer in `storage.mixers`, keyed by unit number.
---@field entity LuaEntity
---@field output string? Item the active craft produces; nil while idle.
---@field ingredients LuaInventory? Packs consumed by the active craft.
---@field progress integer? Powered ticks of the active craft, up to 60.
---@field status string? Last custom status key shown on the entity.
---@field status_value number?

---@class ArmState Tracked inserter in `storage.arms`, keyed by unit number.
---@field entity LuaEntity
---@field holding boolean Whether the hand held an item on the previous tick.

---@alias BuiltEvent
---| EventData.on_built_entity
---| EventData.on_robot_built_entity
---| EventData.script_raised_built
---| EventData.script_raised_revive
---| EventData.on_entity_cloned

---@alias RemovedEvent
---| EventData.on_player_mined_entity
---| EventData.on_robot_mined_entity
---| EventData.on_entity_died
---| EventData.script_raised_destroy

---Creates persistent tables and adopts mixers, Labs and inserters already in the save.
function gameplay.init()
  storage.labs = {}
  storage.mixers = {}
  storage.arms = {}
  for _, force in pairs(game.forces) do
    if force.technologies["logistic-science-pack"].researched then
      force.recipes["shwc-mixer"].enabled = true
    end
  end
  -- Installation into an existing save needs one bootstrap scan, never a tick scan.
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({ type = "inserter" })) do
      gameplay.built({ entity = entity })
    end
    for _, entity in pairs(surface.find_entities_filtered({ name = { "shwc-mixer", "lab" } })) do
      gameplay.built({ entity = entity })
    end
  end
end

---Starts tracking a newly built, revived or cloned mixer, Lab or inserter.
---@param event BuiltEvent
function gameplay.built(event)
  local entity = event.entity or event.created_entity or event.destination
  if not (entity and entity.valid) then
    return
  end
  labs.built(event)
  if not entity.valid then
    return
  end
  if entity.name == "shwc-mixer" then
    entity.disabled_by_script = true
    storage.mixers[entity.unit_number] = { entity = entity }
  elseif entity.type == "inserter" then
    storage.arms[entity.unit_number] = { entity = entity, holding = false }
  end
end

---Drops a stack on the ground at the entity, marked for pickup by robots.
---@param entity LuaEntity
---@param stack LuaItemStack|ItemStackDefinition
local function spill(entity, stack)
  entity.surface.spill_item_stack({
    position = entity.position,
    stack = stack,
    enable_looted = true,
    force = entity.force,
    allow_belts = false,
  })
end

---Stops tracking a mined or destroyed entity and returns the items it held,
---including the ingredients of an unfinished mixer craft.
---@param event RemovedEvent
function gameplay.removed(event)
  labs.removed(event)
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
      recover(
        mixtures.is_beaker(state.output) and { name = state.output, count = 1 }
          or state.ingredients[1]
      )
    else
      for index = 1, #state.ingredients do
        local stack = state.ingredients[index]
        if stack.valid_for_read then
          recover(stack)
        end
      end
    end
    state.ingredients.destroy()
    state.output = nil
  end
  storage.mixers[entity.unit_number] = nil
  storage.arms[entity.unit_number] = nil
end

---Charges wear once when an inserter's hand picks up a beaker.
---@param state ArmState
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

---Shows a custom status on the mixer, writing only when it changes.
---@param state MixerState
---@param key string Suffix of the `entity-status.shwc-*` locale key.
---@param diode string Name in `defines.entity_status_diode`.
---@param value number? Locale parameter, such as progress percent.
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

---Advances one mixer by a tick: samples inputs when idle, spends power while
---mixing and delivers the output once 60 powered ticks have passed.
---@param state MixerState
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
      entity.crafting_progress = state.progress / 60
      status(state, "mixing", "green", math.floor(state.progress * 100 / 60))
    end
    if
      state.progress >= 60
      and output.get_item_count() < 3
      and output.insert(
          mixtures.is_beaker(state.output) and { name = state.output, count = 1 }
            or state.ingredients[1]
        )
        == 1
    then
      state.ingredients.destroy()
      state.ingredients = nil
      state.output = nil
      entity.crafting_progress = 0
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
  -- A native inventory preserves the consumed stacks and their item metadata.
  state.ingredients = game.create_inventory(2)
  for index, present in ipairs({ red, green }) do
    if present then
      local name = mixtures.packs[index]
      for slot = 1, #input do
        if input[slot].valid_for_read and input[slot].name == name then
          local target = state.ingredients[red and green and index or 1]
          assert(target.transfer_stack(input[slot], 1))
          break
        end
      end
    end
  end
  state.progress = 0
  status(state, "mixing", "green", 0)
end

---Runs every tick over tracked entities only: inserter pickups, Labs, then mixers.
function gameplay.tick()
  for id, state in pairs(storage.arms) do
    if state.entity.valid then
      pickup(state)
    else
      storage.arms[id] = nil
    end
  end
  labs.tick()
  for id, state in pairs(storage.mixers) do
    if state.entity.valid then
      mix(state)
    else
      storage.mixers[id] = nil
    end
  end
end

return gameplay
