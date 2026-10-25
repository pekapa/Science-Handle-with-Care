local mixtures = require("shared.mixtures")

local gui = {}
local frame_name = "shwc-machine-info"

---Removes the player's information panel and stops tracking their open machine.
---@param player LuaPlayer
local function close(player)
  local frame = player.gui.relative[frame_name]
  if storage.machine_guis then
    storage.machine_guis[player.index] = nil
  end
  if frame then
    frame.destroy()
  end
end

---@param entity LuaEntity Lab shell.
---@return LuaEntity? worker
local function worker_for(entity)
  local state = storage.labs and storage.labs[entity.unit_number]
  return state and state.worker
end

---Shows one credit bar per ingredient of the current research, rebuilding rows
---only when the ingredient list changes.
---@param worker LuaEntity
---@param research LuaTechnology?
---@param container LuaGuiElement
local function refresh_credit(worker, research, container)
  local ingredients = research and research.research_unit_ingredients or {}
  local rows = container.children
  local changed = #rows ~= #ingredients
  for index, ingredient in ipairs(ingredients) do
    if not rows[index] or rows[index].pack.sprite ~= "item/" .. ingredient.name then
      changed = true
    end
  end
  if changed then
    container.clear()
    for _, ingredient in ipairs(ingredients) do
      local row = container.add({ type = "flow", direction = "horizontal" })
      row.add({
        type = "sprite",
        name = "pack",
        sprite = "item/" .. ingredient.name,
        tooltip = { "item-name." .. ingredient.name },
      })
      local remaining = row.add({
        type = "progressbar",
        name = "remaining",
        style = "production_progressbar",
      })
      remaining.style.horizontally_stretchable = true
    end
    rows = container.children
  end
  for index, ingredient in ipairs(ingredients) do
    local amount = worker.get_stored_durability(ingredient.name).durability
    rows[index].remaining.value = math.min(1, math.max(0, amount))
    rows[index].remaining.tooltip = { "shwc-gui.science-credit-value", amount }
  end
end

---Updates the panel from the machine's current state.
---@param entity LuaEntity Mixer or Lab shell.
---@param frame LuaGuiElement
---@return boolean ok false when the Lab has no worker and the panel should close.
local function refresh(entity, frame)
  local inventory
  if entity.name == "lab" then
    local worker = worker_for(entity)
    if not (worker and worker.valid) then
      return false
    end
    local status = entity.custom_status or worker.custom_status
    if status then
      frame.status.caption = status.label
    else
      for name, value in pairs(defines.entity_status) do
        if value == worker.status then
          frame.status.caption = { "entity-status." .. name:gsub("_", "-") }
          break
        end
      end
    end
    local capacity = worker.electric_buffer_size or 0
    frame.power.value = capacity > 0 and math.min(worker.energy / capacity, 1) or 0
    local research = entity.force.current_research
    frame.research.caption = research and research.localised_name or { "shwc-gui.no-research" }
    frame.progress.value = research and entity.force.research_progress or 0
    refresh_credit(worker, research, frame.credit)
    -- Rebind if lifecycle handling replaces a worker while the intake stays open.
    frame.modules.inventory = worker.get_module_inventory()
    inventory = entity.get_inventory(defines.inventory.chest)
  else
    inventory = entity.get_inventory(defines.inventory.crafter_output)
  end
  frame.health.visible = false
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack.valid_for_read and mixtures.is_beaker(stack.name) then
      frame.health.caption = {
        "shwc-gui.beaker-state",
        math.floor(stack.health * 100 + 0.5),
        stack.durability,
      }
      frame.health.visible = true
      break
    end
  end
  return true
end

---Attaches the information panel beside the native mixer or Lab window.
---@param event EventData.on_gui_opened
function gui.opened(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end
  close(player)
  local entity = event.entity
  if
    not (
      entity
      and entity.valid
      and (entity.name == "shwc-mixer" or entity.name == "lab")
      and player.opened == entity
      and player.can_reach_entity(entity)
    )
  then
    return
  end
  local worker = entity.name == "lab" and worker_for(entity)
  if entity.name == "lab" and not (worker and worker.valid) then
    return
  end
  local frame = player.gui.relative.add({
    type = "frame",
    name = frame_name,
    direction = "vertical",
    caption = { "shwc-gui.information" },
    anchor = {
      gui = entity.name == "lab" and defines.relative_gui_type.container_gui
        or defines.relative_gui_type.assembling_machine_gui,
      position = defines.relative_gui_position.right,
      name = entity.name,
    },
  })
  frame.style.width = 280
  if worker then
    frame.add({ type = "label", name = "status" })
    local research = frame.add({ type = "label", name = "research" })
    research.style.single_line = false
    research.style.maximal_width = 252
    local progress =
      frame.add({ type = "progressbar", name = "progress", style = "production_progressbar" })
    progress.caption = { "shwc-gui.research-progress" }
    progress.style.horizontally_stretchable = true
    frame.add({ type = "label", caption = { "shwc-gui.science-credit" } })
    frame.add({ type = "flow", name = "credit", direction = "vertical" })
    frame.add({ type = "label", caption = { "shwc-gui.electricity" } })
    local power = frame.add({
      type = "progressbar",
      name = "power",
      style = "electric_satisfaction_progressbar",
    })
    power.style.horizontally_stretchable = true
    frame.add({ type = "label", caption = { "shwc-gui.modules" } })
    local modules = frame.add({
      type = "inventory",
      name = "modules",
      slots_per_row = 2,
      handle_cursor_transfer = true,
      handle_cursor_split = true,
    })
    modules.inventory = worker.get_module_inventory()
    modules.empty_slot_info = {
      sprite = "utility/empty_module_slot",
      caption = { "shwc-gui.modules" },
      text = { "shwc-gui.module-slot" },
    }
  end
  local health = frame.add({ type = "label", name = "health" })
  health.style.single_line = false
  health.style.maximal_width = 252
  storage.machine_guis = storage.machine_guis or {}
  storage.machine_guis[player.index] = entity
  refresh(entity, frame)
end

---Closes the panel when its machine window closes.
---@param event EventData.on_gui_closed
function gui.closed(event)
  local player = game.get_player(event.player_index)
  local entity = storage.machine_guis and storage.machine_guis[event.player_index]
  if player and entity and (event.entity == entity or player.opened ~= entity) then
    close(player)
  end
end

---Handles modifier clicks on the worker module slots with native stack transfers.
---@param event EventData.on_gui_inventory_action
function gui.inventory_action(event)
  local player = game.get_player(event.player_index)
  local entity = storage.machine_guis and storage.machine_guis[event.player_index]
  local frame = player and player.gui.relative[frame_name]
  if not (entity and entity.valid and entity.name == "lab" and frame) then
    return
  end
  if player.opened ~= entity or not player.can_reach_entity(entity) then
    close(player)
    return
  end
  local worker = worker_for(entity)
  if not (worker and worker.valid) then
    close(player)
    return
  end
  local element = event.element
  if not (element and element.valid and element == frame.modules) then
    return
  end
  local action = event.action
  if
    action == defines.inventory_actions.stack_transfer
    or action == defines.inventory_actions.stack_split
    or action == defines.inventory_actions.inventory_transfer
    or action == defines.inventory_actions.inventory_split
  then
    player.stack_transfers({
      source_inventory = worker.get_module_inventory(),
      index = event.slot,
      target = player.get_main_inventory(),
      transfer_type = action,
    })
  end
end

---Refreshes open panels every 10 ticks, closing any whose machine became unreachable.
function gui.tick()
  for index, entity in pairs(storage.machine_guis or {}) do
    local player = game.get_player(index)
    if player then
      local frame = player.gui.relative[frame_name]
      if
        not player.connected
        or not entity.valid
        or not frame
        or player.opened ~= entity
        or not player.can_reach_entity(entity)
        or not refresh(entity, frame)
      then
        close(player)
      end
    else
      storage.machine_guis[index] = nil
    end
  end
end

return gui
