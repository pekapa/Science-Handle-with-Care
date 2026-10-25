local util = require("__core__/lualib/util")
local transfer = {}

local function same_contents(stack, cursor)
  if
    not stack.valid_for_read
    or stack.name ~= cursor.name
    or stack.quality.name ~= cursor.quality.name
    or stack.health ~= cursor.health
  then
    return false
  end
  if stack.prototype.type == "tool" and stack.durability ~= cursor.durability then
    return false
  end
  if stack.prototype.type == "item-with-tags" then
    return util.table.compare(stack.tags or {}, cursor.tags or {})
  end
  return true
end

function transfer.bulk(player, source, index, target, action)
  return player.stack_transfers({
    source_inventory = source,
    index = index,
    target = target,
    transfer_type = action,
  })
end

function transfer.click(player, inventory, index, event, output_only)
  local right = event.button == defines.mouse_button_type.right
  if not (right or event.button == defines.mouse_button_type.left) then
    return
  end
  local stack = inventory[index]
  if event.shift or event.control then
    local actions = defines.inventory_actions
    return transfer.bulk(
      player,
      inventory,
      index,
      player,
      event.control and (right and actions.inventory_split or actions.inventory_transfer)
        or (right and actions.stack_split or actions.stack_transfer)
    )
  end
  local cursor = player.cursor_stack
  if not cursor then
    return
  end
  if not cursor.valid_for_read then
    if stack.valid_for_read then
      if right then
        cursor.transfer_stack(stack, math.ceil(stack.count / 2))
      else
        cursor.swap_stack(stack)
      end
    end
  elseif output_only then
    if not right and stack.valid_for_read then
      cursor.transfer_stack(stack)
    end
  elseif right then
    stack.transfer_stack(cursor, 1)
  else
    local count = cursor.count
    local same = same_contents(stack, cursor)
    stack.transfer_stack(cursor)
    if cursor.valid_for_read and cursor.count == count and not same then
      stack.swap_stack(cursor)
    end
  end
end

return transfer
