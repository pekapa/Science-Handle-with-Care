-- Create ordinary logistics before the production mod is installed.
script.on_init(function()
  local surface = game.surfaces.nauvis
  local tiles = {}
  for x = -4, 8 do
    for y = -4, 8 do
      tiles[#tiles + 1] = { name = "grass-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  local function create(name, x, y, direction)
    assert(surface.create_entity({
      name = name,
      position = { x, y },
      direction = direction or defines.direction.east,
      force = game.forces.player,
    }))
  end
  create("wooden-chest", 0, 0)
  create("inserter", 1, 0, defines.direction.west)
  create("wooden-chest", 2, 0)
  create("small-electric-pole", 1, 1)
  create("electric-energy-interface", 1, 4)
  local force = game.forces.player
  force.technologies["logistic-science-pack"].researched = true
end)
