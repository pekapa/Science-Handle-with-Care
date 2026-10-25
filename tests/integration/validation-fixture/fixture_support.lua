-- luacheck: globals storage
-- luacheck: read globals game defines
local mixtures = require("__science-handle-with-care__/shared/mixtures")

local function spawn(name, x, y, direction)
  local entity = storage.fixture.surface.create_entity({
    name = name,
    position = { x, y },
    direction = direction or defines.direction.east,
    force = game.forces.player,
    raise_built = true,
  })
  assert(entity, "fixture could not create " .. name)
  return entity
end

-- Observe the actual production worker; fixture code never admits science.
local function worker(shell)
  return assert(
    shell.surface.find_entities_filtered({
      name = "shwc-lab-worker",
      position = shell.position,
      radius = 0.1,
    })[1],
    "native worker missing"
  )
end
local function salvage_lab(shell, inventory)
  local surface, position = shell.surface, shell.position
  shell.destroy({ raise_destroy = true })
  for _, dropped in
    pairs(surface.find_entities_filtered({ type = "item-entity", position = position, radius = 3 }))
  do
    assert(inventory.insert(dropped.stack) == dropped.stack.count, "salvage inventory full")
    dropped.destroy()
  end
end

local function power(x, y)
  spawn("small-electric-pole", x, y)
  local source = spawn("electric-energy-interface", x, y + 3)
  source.energy = 1000000000
  return source
end

local function mixer(x, y, red, green)
  local entity = spawn("shwc-mixer", x, y)
  power(x, y + 2)
  local input = entity.get_inventory(defines.inventory.crafter_input)
  if red then
    assert(input.insert({ name = mixtures.packs[1], count = red }) == red)
  end
  if green then
    assert(input.insert({ name = mixtures.packs[2], count = green }) == green)
  end
  return entity
end

local function inventory(entity)
  return entity.get_inventory(defines.inventory.crafter_output)
end

return {
  spawn = spawn,
  worker = worker,
  salvage_lab = salvage_lab,
  power = power,
  mixer = mixer,
  inventory = inventory,
}
