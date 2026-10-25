local mixtures = require("shared.mixtures")
local transfer = require("runtime.inventory_transfer")

local gui = {}
local frame_name = "shwc-machine"

local function close(player)
  local frame = player.gui.screen[frame_name]
  if storage.machine_guis then
    storage.machine_guis[player.index] = nil
  end
  if frame then
    if player.opened == frame then
      player.opened = nil
    end
    if frame.valid then
      frame.destroy()
    end
  end
end

local function worker_for(entity)
  if entity.name == "shwc-mixer" then
    return entity
  end
  local state = storage.labs and storage.labs[entity.unit_number]
  return state and state.worker
end

local function machine_inventory(entity, role)
  if role == "modules" then
    return worker_for(entity).get_module_inventory()
  end
  local index = entity.name == "shwc-mixer"
      and (role == "output" and defines.inventory.crafter_output or defines.inventory.crafter_input)
    or defines.inventory.chest
  return entity.get_inventory(index)
end

local function slot_group(parent, entity, role)
  local group = parent.add({ type = "flow", name = role, direction = "vertical" })
  group.add({ type = "label", caption = { "shwc-gui." .. role } })
  local slots = group.add({ type = "flow", name = "slots" })
  slots.style.horizontal_spacing = 0
  for index = 1, #machine_inventory(entity, role) do
    local cell = slots.add({ type = "flow", name = "slot-" .. index, direction = "vertical" })
    cell.style.width = 40
    cell.style.height = 44
    cell.style.vertical_spacing = 0
    cell.add({
      type = "sprite-button",
      name = "shwc-" .. role .. "-" .. index,
      style = "slot_button",
      tags = { role = role, slot = index },
    })
    local health = cell.add({ type = "progressbar", name = "health" })
    health.style.width = 40
    health.style.height = 4
    health.visible = false
  end
end

local function refresh_slots(group, inventory)
  for index = 1, #inventory do
    local cell = group.slots.children[index]
    local button = cell.children[1]
    local stack = inventory[index]
    cell.health.visible = stack.valid_for_read and mixtures.is_beaker(stack.name)
    if cell.health.visible then
      cell.health.value = stack.health
      cell.health.tooltip = { "shwc-gui.health", math.floor(stack.health * 100 + 0.5) }
    end
    if stack.valid_for_read then
      button.sprite = "item/" .. stack.name
      button.number = stack.count
      button.quality = stack.quality
      button.elem_tooltip = { type = "item", name = stack.name, quality = stack.quality.name }
      if mixtures.is_beaker(stack.name) then
        button.tooltip = {
          "shwc-gui.beaker-state",
          math.floor(stack.health * 100 + 0.5),
          stack.durability,
        }
      else
        button.tooltip = ""
      end
    else
      button.sprite = ""
      button.number = nil
      button.quality = nil
      button.elem_tooltip = nil
      button.tooltip = { "shwc-gui.empty-slot" }
    end
  end
end

local function refresh(player, entity, frame)
  local worker = worker_for(entity)
  if not (worker and worker.valid) then
    close(player)
    return
  end
  local body = frame.body.machine
  local status = entity.custom_status or worker.custom_status
  if status then
    body.status.caption = status.label
  else
    for name, value in pairs(defines.entity_status) do
      if value == worker.status then
        body.status.caption = { "entity-status." .. name:gsub("_", "-") }
        break
      end
    end
  end
  local capacity = worker.electric_buffer_size or 0
  body.power.value = capacity > 0 and math.min(worker.energy / capacity, 1) or 0
  if entity.name == "shwc-mixer" then
    body.crafting.progress.value = entity.crafting_progress
    body.crafting.progress.tooltip = {
      "shwc-gui.mixing-progress",
      math.floor(entity.crafting_progress * 100),
    }
  else
    local research = entity.force.current_research
    body.research.caption = research and research.localised_name or { "shwc-gui.no-research" }
    body.progress.value = research and entity.force.research_progress or 0
    body.progress.caption = { "shwc-gui.research-progress" }
  end
  local slots = entity.name == "shwc-mixer" and body.crafting or body
  refresh_slots(slots.input, machine_inventory(entity, "input"))
  if entity.name == "shwc-mixer" then
    refresh_slots(slots.output, machine_inventory(entity, "output"))
  elseif body.modules then
    refresh_slots(body.modules, machine_inventory(entity, "modules"))
  end
end

function gui.opened(event)
  local entity = event.entity
  if not (entity and entity.valid and (entity.name == "shwc-mixer" or entity.name == "lab")) then
    return
  end
  local player = game.get_player(event.player_index)
  local worker = worker_for(entity)
  if not (player and worker and worker.valid and player.can_reach_entity(entity)) then
    return
  end
  close(player)
  local frame = player.gui.screen.add({ type = "frame", name = frame_name, direction = "vertical" })
  local title = frame.add({ type = "flow" })
  title.add({ type = "label", style = "frame_title", caption = entity.localised_name })
  local drag = title.add({ type = "empty-widget", style = "draggable_space_header" })
  drag.style.horizontally_stretchable = true
  drag.drag_target = frame
  title.add({
    type = "sprite-button",
    name = "shwc-machine-close",
    sprite = "utility/close",
    style = "frame_action_button",
    tooltip = { "gui.close-instruction" },
  })
  local body = frame.add({ type = "flow", name = "body", direction = "horizontal" })
  body.style.horizontal_spacing = 12
  body.style.vertical_align = "top"
  local character = body.add({
    type = "frame",
    name = "character",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
  })
  character.add({ type = "label", style = "heading_2_label", caption = { "shwc-gui.inventory" } })
  local inventory = character.add({
    type = "inventory",
    name = "player-inventory",
    slots_per_row = 10,
    handle_cursor_transfer = true,
    handle_cursor_split = true,
  })
  inventory.inventory = player.get_main_inventory()
  local machine = body.add({
    type = "frame",
    name = "machine",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
  })
  machine.style.width = 400
  machine.add({ type = "label", name = "status" })
  local preview = machine.add({ type = "entity-preview", name = "preview" })
  preview.entity = entity
  preview.style.width = 368
  preview.style.height = 120
  if entity.name == "shwc-mixer" then
    local crafting = machine.add({ type = "flow", name = "crafting" })
    crafting.style.vertical_align = "center"
    crafting.style.horizontal_spacing = 12
    slot_group(crafting, entity, "input")
    local progress = crafting.add({
      type = "progressbar",
      name = "progress",
      style = "production_progressbar",
    })
    progress.style.width = 120
    slot_group(crafting, entity, "output")
  else
    local research = machine.add({ type = "label", name = "research" })
    research.style.single_line = false
    research.style.maximal_width = 368
    local progress = machine.add({
      type = "progressbar",
      name = "progress",
      style = "production_progressbar",
    })
    progress.style.horizontally_stretchable = true
    slot_group(machine, entity, "input")
    if worker.get_module_inventory() then
      slot_group(machine, entity, "modules")
    end
  end
  machine.add({ type = "line" })
  machine.add({ type = "label", caption = { "shwc-gui.electricity" } })
  local power = machine.add({
    type = "progressbar",
    name = "power",
    style = "electric_satisfaction_progressbar",
  })
  power.style.horizontally_stretchable = true
  power.style.height = 12
  storage.machine_guis = storage.machine_guis or {}
  storage.machine_guis[player.index] = entity
  frame.auto_center = true
  -- Replacing the native window raises its close event; only our frame's close
  -- event may remove this window.
  player.opened = frame
  refresh(player, entity, frame)
end

function gui.closed(event)
  if event.element and event.element.valid and event.element.name == frame_name then
    if storage.machine_guis then
      storage.machine_guis[event.player_index] = nil
    end
    event.element.destroy()
  end
end

local function active_window(event)
  local player = game.get_player(event.player_index)
  local entity = storage.machine_guis and storage.machine_guis[event.player_index]
  local frame = player and player.gui.screen[frame_name]
  local root = event.element
  while root and root.name ~= frame_name do
    root = root.parent
  end
  if
    not (
      root
      and player
      and entity
      and entity.valid
      and player.opened == frame
      and player.can_reach_entity(entity)
    )
  then
    if player and root then
      close(player)
    end
    return
  end
  local worker = worker_for(entity)
  if not (worker and worker.valid) then
    close(player)
    return
  end
  return player, entity, frame
end

function gui.clicked(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end
  if element.name == "shwc-machine-close" then
    close(game.get_player(event.player_index))
    return
  end
  local role, index = element.tags.role, element.tags.slot
  if not (index and (role == "input" or role == "output" or role == "modules")) then
    return
  end
  local player, entity, frame = active_window(event)
  if not player then
    return
  end
  local inventory = machine_inventory(entity, role)
  transfer.click(player, inventory, index, event, role == "output")
  refresh(player, entity, frame)
end

function gui.inventory_action(event)
  local element = event.element
  if not (element and element.valid and element.type == "inventory") then
    return
  end
  local player, entity, frame = active_window(event)
  if not player then
    return
  end
  local action = event.action
  if
    action == defines.inventory_actions.stack_transfer
    or action == defines.inventory_actions.stack_split
    or action == defines.inventory_actions.inventory_transfer
    or action == defines.inventory_actions.inventory_split
  then
    local role = event.item and event.item.type == "module" and "modules" or "input"
    local target = role == "modules" and worker_for(entity).get_module_inventory()
      or machine_inventory(entity, "input")
    if not target then
      return
    end
    transfer.bulk(player, element.inventory, event.slot, target, action)
    refresh(player, entity, frame)
  end
end

function gui.tick(event)
  if event.tick % 10 ~= 0 then
    return
  end
  for index, entity in pairs(storage.machine_guis or {}) do
    local player = game.get_player(index)
    if player then
      local frame = player.gui.screen[frame_name]
      if
        not player.connected
        or not entity.valid
        or not frame
        or player.opened ~= frame
        or not player.can_reach_entity(entity)
      then
        close(player)
      else
        refresh(player, entity, frame)
      end
    else
      storage.machine_guis[index] = nil
    end
  end
end

return gui
