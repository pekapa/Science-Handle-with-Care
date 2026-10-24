local function place(surface, name, position, force)
  local entity = surface.create_entity({
    name = name,
    position = position,
    force = force,
    direction = defines.direction.west,
    raise_built = true,
  })
  assert(entity and entity.valid, "showcase could not place " .. name)
  return entity
end

local function setup_player(event)
  storage.showcase.player_joined = true
  local player = game.players[event.player_index]
  player.teleport({ 0, 4 }, game.surfaces[1])
  player.insert({ name = "pistol", count = 1 })
  player.insert({ name = "firearm-magazine", count = 32 })
  player.insert({ name = "iron-plate", count = 100 })
  player.insert({ name = "copper-plate", count = 100 })
  player.insert({ name = "copper-cable", count = 100 })
  player.insert({ name = "automation-science-pack", count = 100 })
  player.insert({ name = "logistic-science-pack", count = 100 })
  player.print({ "scenario.welcome" })
  for _, starter in ipairs({
    { "shwc-beaker-red", 6 },
    { "shwc-beaker-green", 6 },
    { "shwc-beaker-red-green", 12 },
    { "inserter", 20 },
    { "fast-inserter", 10 },
    { "transport-belt", 100 },
    { "splitter", 10 },
    { "steel-chest", 10 },
    { "small-electric-pole", 30 },
    { "solar-panel", 20 },
    { "shwc-mixer", 4 },
    { "shwc-lab", 4 },
  }) do
    player.insert({ name = starter[1], count = starter[2] })
  end
end

local function check_dependencies()
  local count = 0
  for name in pairs(script.active_mods) do
    assert(
      name == "base" or name == "core" or name == "science-handle-with-care",
      "unexpected showcase mod: " .. name
    )
    count = count + 1
  end
  assert(
    script.active_mods.base and script.active_mods["science-handle-with-care"],
    "showcase production dependency missing"
  )
  log("SCIENCE_SHOWCASE_MODS PASS count=" .. count)
end

local function setup()
  check_dependencies()
  local force = game.forces.player
  local surface = game.surfaces[1]
  surface.request_to_generate_chunks({ 0, 0 }, 2)
  surface.force_generate_chunk_requests()
  for _, entity in pairs(surface.find_entities_filtered({ area = { { -12, -10 }, { 12, 10 } } })) do
    if entity.type ~= "character" then
      entity.destroy()
    end
  end
  local tiles = {}
  for x = -12, 12 do
    for y = -10, 10 do
      tiles[#tiles + 1] = { name = "grass-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  surface.daytime = 0
  surface.freeze_daytime = true
  force.technologies["logistic-science-pack"].researched = true
  force.technologies["logistics"].researched = true
  force.research_queue = { "logistics-2" }
  assert(
    force.current_research and force.current_research.name == "logistics-2",
    "showcase research not queued"
  )
  assert(
    force.current_research.research_unit_ingredients[1].name == "shwc-beaker-red-green",
    "showcase research does not use mixed beakers"
  )

  local mixer = place(surface, "shwc-mixer", { 0, 0 }, force)
  local lab = place(surface, "shwc-lab", { 4, 0 }, force)
  local red = place(surface, "steel-chest", { -3, -1 }, force)
  local green = place(surface, "steel-chest", { -3, 1 }, force)
  place(surface, "inserter", { -2, -1 }, force)
  place(surface, "inserter", { -2, 1 }, force)
  local output = place(surface, "inserter", { 2, 0 }, force)
  for _, position in ipairs({ { -2, -2 }, { -2, 2 }, { 2, -2 }, { 5, -2 } }) do
    place(surface, "small-electric-pole", position, force)
  end
  for _, position in ipairs({ { -4, -5 }, { 0, -5 }, { 4, -5 } }) do
    place(surface, "solar-panel", position, force)
  end
  assert(red.insert({ name = "automation-science-pack", count = 80 }) == 80)
  assert(green.insert({ name = "logistic-science-pack", count = 80 }) == 80)
  storage.showcase = { mixer = mixer, lab = lab, output = output, saw_delivery = false }
end

script.on_init(setup)
script.on_event(defines.events.on_player_created, setup_player)
script.on_nth_tick(30, function(event)
  local state = storage.showcase
  if state.player_joined then
    return
  end
  if state.saved_tick then
    if event.tick == state.saved_tick + 120 then
      assert(
        game.forces.player.research_progress > state.saved_progress,
        "showcase research stalled after reload"
      )
      check_dependencies()
      log("SCIENCE_SHOWCASE_RELOAD PASS")
    end
    return
  end
  local held = state.output.held_stack
  if held.valid_for_read and held.name == "shwc-beaker-red-green" then
    assert(held.health < 1, "showcase output pickup has no wear")
    state.saw_delivery = true
  end
  if event.tick == 1200 then
    assert(state.saw_delivery, "showcase mixer-to-lab inserter did not transport mixed beaker")
    assert(state.mixer.energy > 0 and state.lab.energy > 0, "showcase machines lack power")
    assert(game.forces.player.research_progress > 0, "showcase native research did not advance")
    state.saved_tick = event.tick
    state.saved_progress = game.forces.player.research_progress
    log("SCIENCE_SHOWCASE_SETUP PASS research_progress=" .. state.saved_progress)
    game.auto_save("science-showcase")
  end
end)
