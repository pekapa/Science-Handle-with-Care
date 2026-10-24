local constants = require("shared.constants")
local wear = {}

local function nonnegative_integer(value)
  return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
end

function wear.is_failed(value)
  assert(nonnegative_integer(value), "wear must be a nonnegative integer")
  return value > constants.wear_budget
end

-- Failed packs share a terminal state; later pickups cannot restore them.
function wear.after_pickup(value, cost)
  assert(nonnegative_integer(value), "wear must be a nonnegative integer")
  assert(nonnegative_integer(cost) and cost > 0, "pickup cost must be a positive integer")
  return math.min(value + cost, constants.failed_wear)
end

-- Proposed item-health encoding, not tool durability. No stack is modified here.
-- Eleven is the terminal failure sentinel; health stays positive at failure.
function wear.to_health(value)
  assert(nonnegative_integer(value), "wear must be a nonnegative integer")
  return 1 - math.min(value, constants.failed_wear) / constants.health_steps
end

function wear.from_health(health)
  assert(
    type(health) == "number"
      and health <= 1
      and health >= 1 - constants.failed_wear / constants.health_steps,
    "health is outside the proposed wear encoding"
  )
  local steps = (1 - health) * constants.health_steps
  local rounded = math.floor(steps + 0.5)
  assert(math.abs(steps - rounded) < 0.000001, "health is not an encoded wear step")
  return rounded
end

return wear
