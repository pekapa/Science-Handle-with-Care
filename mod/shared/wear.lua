local constants = require("shared.constants")
local wear = {}

---@param value any
---@return boolean
local function nonnegative_integer(value)
  return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

---@param value integer Wear points.
---@return boolean failed Whether the wear budget is exhausted.
function wear.is_failed(value)
  assert(nonnegative_integer(value), "wear must be a nonnegative integer")
  return value >= constants.wear_budget
end

---Adds one pickup's wear. Failed packs share a terminal state; later pickups
---cannot restore them.
---@param value integer Wear points before the pickup.
---@param cost integer Wear points charged by this pickup.
---@return integer
function wear.after_pickup(value, cost)
  assert(nonnegative_integer(value), "wear must be a nonnegative integer")
  assert(nonnegative_integer(cost) and cost > 0, "pickup cost must be a positive integer")
  return math.min(value + cost, constants.failed_wear)
end

---Linear item health, independent of tool durability. Convert failed beakers
---before assigning health: the terminal wear state would have zero health.
---@param value integer Wear points below the failure budget.
---@return number health In (0, 1].
function wear.to_health(value)
  assert(nonnegative_integer(value), "wear must be a nonnegative integer")
  assert(not wear.is_failed(value), "failed wear must be converted to denatured science")
  return 1 - value / constants.health_steps
end

---Decodes wear points from an item health written by `wear.to_health`.
---@param health number
---@return integer
function wear.from_health(health)
  assert(
    type(health) == "number" and health <= 1 and health > 0,
    "health is outside the wear encoding"
  )
  local steps = (1 - health) * constants.health_steps
  local rounded = math.floor(steps + 0.5)
  assert(math.abs(steps - rounded) < 0.000001, "health is not an encoded wear step")
  assert(not wear.is_failed(rounded), "health encodes failed wear")
  return rounded
end

return wear
