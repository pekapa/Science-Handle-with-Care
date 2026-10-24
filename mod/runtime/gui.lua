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

local function inventory_widget(parent, name, inventory, columns, caption)
  local flow = parent.add({ type = "flow", direction = "vertical" })
  flow.add({ type = "label", caption = { "shwc-gui." .. caption } })
  local widget = flow.add({
    type = "inventory",
    name = name,
    slots_per_row = columns,
    empty_slot_info = { caption = { "shwc-gui.empty-slot" } },
    handle_cursor_transfer = true,
    handle_cursor_split = true,
  })
  widget.inventory = inventory
end

local function refresh(player, entity, frame)
  local worker = worker_for(entity)
  if not (worker and worker.valid) then
    close(player)
    return
  end
  local body = frame.body
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
  body.power.caption = { "shwc-gui.electricity" }
  if entity.name == "shwc-mixer" then
    body.progress.value = entity.crafting_progress
    body.progress.caption = {
      "shwc-gui.mixing-progress",
      math.floor(entity.crafting_progress * 100),
    }
  else
    local research = entity.force.current_research
    body.research.caption = research and research.localised_name or { "shwc-gui.no-research" }
    body.progress.value = research and entity.force.research_progress or 0
    body.progress.caption = { "shwc-gui.research-progress" }
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
  local body = frame.add({
    type = "frame",
    name = "body",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
  })
  body.add({ type = "label", name = "status" })
  local slots = body.add({ type = "flow" })
  if entity.name == "shwc-mixer" then
    inventory_widget(
      slots,
      "input",
      entity.get_inventory(defines.inventory.crafter_input),
      2,
      "input"
    )
    inventory_widget(
      slots,
      "output",
      entity.get_inventory(defines.inventory.crafter_output),
      3,
      "output"
    )
  else
    inventory_widget(slots, "input", entity.get_inventory(defines.inventory.chest), 1, "input")
    local modules = worker.get_module_inventory()
    if modules then
      inventory_widget(slots, "modules", modules, 2, "modules")
    end
    body.add({ type = "label", name = "research" })
  end
  local progress = body.add({
    type = "progressbar",
    name = "progress",
    style = "production_progressbar",
  })
  progress.style.horizontally_stretchable = true
  local power = body.add({
    type = "progressbar",
    name = "power",
    style = "electric_satisfaction_progressbar",
  })
  power.style.horizontally_stretchable = true
  inventory_widget(body, "player-inventory", player.get_main_inventory(), 10, "inventory")
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

function gui.clicked(event)
  local element = event.element
  if element and element.valid and element.name == "shwc-machine-close" then
    close(game.get_player(event.player_index))
  end
end

function gui.inventory_action(event)
  local element = event.element
  if not (element and element.valid and element.type == "inventory") then
    return
  end
  local root = element
  while root and root.name ~= frame_name do
    root = root.parent
  end
  if not root then
    return
  end
  local player = game.get_player(event.player_index)
  local entity = storage.machine_guis and storage.machine_guis[event.player_index]
  if not (player and entity and entity.valid and player.can_reach_entity(entity)) then
    if player then
      close(player)
    end
    return
  end
  local action = event.action
  if
    action == defines.inventory_actions.stack_transfer
    or action == defines.inventory_actions.stack_split
    or action == defines.inventory_actions.inventory_transfer
    or action == defines.inventory_actions.inventory_split
  then
    local target = player
    if element.name == "player-inventory" then
      target = entity
      if entity.name == "lab" and event.item and event.item.type == "module" then
        local worker = worker_for(entity)
        if not (worker and worker.valid) then
          close(player)
          return
        end
        target = worker.get_module_inventory()
      end
    end
    player.stack_transfers({
      source_inventory = element.inventory,
      index = event.slot,
      target = target,
      transfer_type = action,
    })
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
