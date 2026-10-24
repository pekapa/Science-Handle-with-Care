local constants = require("shared.constants")
local wear = {}

local function nonnegative_integer(value)
  return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

function wear.is_failed(value)
  assert(nonnegative_integer(value), "wear must be a nonnegative integer")
  return value >= constants.wear_budget
end

-- Failed packs share a terminal state; later pickups cannot restore them.
function wear.after_pickup(value, cost)
  assert(nonnegative_integer(value), "wear must be a nonnegative integer")
  assert(nonnegative_integer(cost) and cost > 0, "pickup cost must be a positive integer")
  return math.min(value + cost, constants.failed_wear)
end

-- Linear item health, independent of tool durability. Convert failed beakers
-- before assigning health: the terminal wear state would have zero health.
function wear.to_health(value)
  assert(nonnegative_integer(value), "wear must be a nonnegative integer")
  assert(not wear.is_failed(value), "failed wear must be converted to denatured science")
  return 1 - value / constants.health_steps
end

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
