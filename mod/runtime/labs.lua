local labs = {}

---@class LabState Tracked Lab in `storage.labs`, keyed by the visible shell's unit number.
---@field entity LuaEntity Visible one-slot container.
---@field worker LuaEntity? Hidden native lab holding power, modules and credit.
---@field paused_for_move boolean? Worker disabled until it can follow the shell.
---@field worker_disabled boolean? Worker's own disabled state to restore after the move.

---@class ScienceCredit Native lab credit for one science type, also saved in Lab item tags.
---@field name string
---@field durability number
---@field quality string?

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

---Lists the worker's nonzero stored research credit.
---@param worker LuaEntity
---@return ScienceCredit[]
local function credits(worker)
  local result = {}
  for _, name in ipairs(worker.prototype.lab_inputs) do
    local credit = worker.get_stored_durability(name)
    if credit.durability > 0 then
      result[#result + 1] = {
        name = name,
        durability = credit.durability,
        quality = type(credit.quality) == "string" and credit.quality
          or credit.quality and credit.quality.name,
      }
    end
  end
  return result
end

---Creates the hidden worker under a Lab shell.
---@param entity LuaEntity Lab shell.
---@return LuaEntity? worker nil when the engine refuses creation.
local function create_worker(entity)
  local worker = entity.surface.create_entity({
    name = "shwc-lab-worker",
    position = entity.position,
    force = entity.force,
    quality = entity.quality,
  })
  if worker then
    worker.operable, worker.destructible = false, false
  end
  return worker
end

---Toggles the disabled flag to make an idle native lab notice newly stored credit.
---@param worker LuaEntity
local function wake(worker)
  local disabled = worker.disabled_by_script
  worker.disabled_by_script = true
  worker.disabled_by_script = disabled
end

---Pairs a newly built Lab with a worker and restores credit from its item tags.
---@param event BuiltEvent
function labs.built(event)
  local entity = event.entity or event.created_entity or event.destination
  if not (entity and entity.valid) then
    return
  end
  -- The shell creates its own worker. Area cloning may also clone the invisible
  -- worker; discard that independent copy rather than orphaning paid credit.
  if event.destination and entity.name == "shwc-lab-worker" then
    entity.destroy()
    return
  end
  if entity.name ~= "lab" or storage.labs[entity.unit_number] then
    return
  end
  local worker = create_worker(entity)
  if not worker then
    return
  end
  storage.labs[entity.unit_number] = { entity = entity, worker = worker }
  -- Cloning must not duplicate paid science credit. Only an actual consumed
  -- tagged item restores credit; script-raised builds have no item tags.
  if event.destination then
    return
  end
  local tags = event.tags
  if not tags and event.stack and event.stack.valid_for_read and event.stack.is_item_with_tags then
    tags = event.stack.tags
  end
  if not tags and event.consumed_items then
    for i = 1, #event.consumed_items do
      local item = event.consumed_items[i]
      if item.valid_for_read and item.name == "lab" and item.is_item_with_tags then
        tags = item.tags
        break
      end
    end
  end
  if tags and tags.sciencecredits then
    for _, credit in ipairs(tags.sciencecredits) do
      worker.set_stored_durability(credit.name, credit)
    end
    wake(worker)
  end
end

---Returns a Lab's credit (as Lab item tags), modules and input, then destroys its worker.
---@param state LabState
---@param event RemovedEvent|{} Empty when the shell vanished without an event.
local function recover(state, event)
  local shell, worker = state.entity, state.worker
  local anchor = shell.valid and shell or worker
  if not (anchor and anchor.valid) then
    return
  end
  local function deliver(stack)
    if event.buffer then
      local remaining = stack.count - event.buffer.insert(stack)
      if remaining > 0 then
        -- Keep the original stack so overflow retains Tool health/durability
        -- and item tags. The caller clears the source after delivery.
        stack.count = remaining
        spill(anchor, stack)
      end
    else
      spill(anchor, stack)
    end
  end
  if worker and worker.valid then
    local remaining = credits(worker)
    if #remaining > 0 then
      local tagged
      if event.buffer then
        for i = 1, #event.buffer do
          local stack = event.buffer[i]
          if stack.valid_for_read and stack.name == "lab" then
            tagged = stack
            break
          end
        end
      end
      if tagged then
        tagged.tags = { sciencecredits = remaining }
      else
        deliver({
          name = "lab",
          count = 1,
          quality = anchor.quality,
          tags = { sciencecredits = remaining },
        })
      end
    end
    local modules = worker.get_module_inventory()
    for i = 1, #modules do
      if modules[i].valid_for_read then
        deliver(modules[i])
        modules[i].clear()
      end
    end
    worker.destroy()
  end
  if shell.valid and not event.buffer then
    local input = shell.get_inventory(defines.inventory.chest)
    if input[1].valid_for_read then
      deliver(input[1])
      input[1].clear()
    end
  end
end

---Recovers a removed Lab, whether the event names its shell or its worker.
---@param event RemovedEvent
function labs.removed(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  local state = storage.labs[entity.unit_number]
  if state then
    recover(state, event)
    storage.labs[entity.unit_number] = nil
    return
  end
  if entity.name == "shwc-lab-worker" then
    for id, candidate in pairs(storage.labs) do
      if candidate.worker == entity then
        recover(candidate, event)
        if candidate.entity.valid then
          candidate.entity.destroy()
        end
        storage.labs[id] = nil
        return
      end
    end
  end
end

---Moves the worker to its shell, replacing it when the shell changed surface.
---@param state LabState
---@return boolean moved false leaves the original worker and its balances intact.
local function move_worker(state)
  local shell, worker = state.entity, state.worker
  if worker.surface == shell.surface then
    return worker.teleport(shell.position)
  end
  -- Native labs cannot teleport across surfaces. Move their independent local
  -- balances before destroying the old worker.
  local replacement = create_worker(shell)
  if not replacement then
    return false
  end
  local source, target = worker.get_module_inventory(), replacement.get_module_inventory()
  for i = 1, #source do
    if not target[i].swap_stack(source[i]) then
      for j = 1, i - 1 do
        target[j].swap_stack(source[j])
      end
      replacement.destroy()
      return false
    end
  end
  for _, credit in ipairs(credits(worker)) do
    replacement.set_stored_durability(credit.name, credit)
  end
  replacement.energy = worker.energy
  replacement.disabled_by_script = worker.disabled_by_script
  wake(replacement)
  state.worker = replacement
  worker.destroy()
  return true
end

---Shows a custom status on the Lab shell.
---@param shell LuaEntity
---@param key string Suffix of the `entity-status.shwc-lab-*` locale key.
---@param diode string Name in `defines.entity_status_diode`.
local function status(shell, key, diode)
  shell.custom_status =
    { diode = defines.entity_status_diode[diode], label = { "entity-status.shwc-lab-" .. key } }
end

---Keeps each worker beside its shell and admits one matching pack from the
---physical slot into native credit when that science type's credit runs out.
function labs.tick()
  for id, state in pairs(storage.labs) do
    local shell, worker = state.entity, state.worker
    if shell.valid and not (worker and worker.valid) then
      -- Direct unraised destruction makes native credit inaccessible. Keep the
      -- visible item and intake intact rather than destroying another balance.
      local replacement = create_worker(shell)
      if replacement then
        state.worker = replacement
      else
        status(shell, "unavailable", "red")
      end
    elseif not shell.valid then
      recover(state, {})
      storage.labs[id] = nil
    else
      if
        worker.surface ~= shell.surface
        or worker.position.x ~= shell.position.x
        or worker.position.y ~= shell.position.y
      then
        if not move_worker(state) then
          if not state.paused_for_move then
            state.worker_disabled = worker.disabled_by_script
            state.paused_for_move = true
          end
          worker.disabled_by_script = true
          status(shell, "unavailable", "red")
          goto continue
        end
        worker = state.worker
      end
      if state.paused_for_move then
        worker.disabled_by_script = state.worker_disabled
        state.paused_for_move, state.worker_disabled = nil, nil
      end
      if worker.force ~= shell.force then
        worker.force = shell.force
      end
      local input = shell.get_inventory(defines.inventory.chest)[1]
      local research = shell.force.current_research
      local ingredients = research and research.research_unit_ingredients
      local matching = false
      if ingredients and input.valid_for_read then
        for _, ingredient in ipairs(ingredients) do
          if ingredient.name == input.name then
            matching = true
            break
          end
        end
      end
      if matching then
        if worker.get_stored_durability(input.name).durability <= 0 then
          worker.set_stored_durability(
            input.name,
            { durability = input.is_tool and input.durability or 1, quality = input.quality.name }
          )
          wake(worker)
          input.count = input.count - 1
        end
        status(shell, "working", "green")
      elseif input.valid_for_read then
        status(shell, "wrong-mixture", "yellow")
      else
        status(shell, "waiting", "yellow")
      end
    end
    ::continue::
  end
end

return labs
