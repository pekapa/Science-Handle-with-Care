-- luacheck: globals storage
-- luacheck: read globals script game defines prototypes
local mixtures = require("__science-handle-with-care__/shared/mixtures")
local support = require("fixture_support")
local spawn = support.spawn
local mixer_cases = require("mixer_cases")
local handling_cases = require("handling_cases")
local M = {}

function M.initialize()
  for name in pairs(script.active_mods) do
    assert(
      name == "base" or name == "science-handle-with-care" or name == "science-validation-fixture",
      "unexpected enabled mod: " .. name
    )
  end
  assert(not prototypes.entity["shwc-lab"], "separate beaker lab still exists")
  assert(
    not prototypes.item["shwc-beaker-red"] and not prototypes.item["shwc-beaker-green"],
    "single-science fragile prototypes still exist"
  )
  local lab_recipe = game.forces.player.recipes.lab
  local ingredients = {}
  for _, ingredient in pairs(lab_recipe.ingredients) do
    ingredients[ingredient.name] = ingredient.amount
  end
  assert(
    ingredients["electronic-circuit"] == 10
      and ingredients["iron-gear-wheel"] == 10
      and ingredients["transport-belt"] == 4,
    "ordinary lab recipe changed"
  )
  assert(prototypes.item.lab.place_result.name == "lab", "ordinary lab item changed")
  for _, technology in pairs(game.forces.player.technologies) do
    for _, effect in pairs(technology.prototype.effects) do
      assert(effect.recipe ~= "shwc-lab", "extra lab unlock remains")
    end
  end
  local surface = game.create_surface("science-validation", {
    seed = 12345,
    width = 256,
    height = 256,
    autoplace_controls = {},
    default_enable_all_autoplace_controls = false,
  })
  surface.request_to_generate_chunks({ 0, 0 }, 4)
  surface.force_generate_chunk_requests()
  local tiles = {}
  for x = -60, 60 do
    for y = -40, 40 do
      tiles[#tiles + 1] = { name = "grass-1", position = { x, y } }
    end
  end
  surface.set_tiles(tiles)
  storage.fixture = { surface = surface, arms = {} }
  local state = storage.fixture
  state.conventional_force = game.create_force("conventional-science-validation")
  state.conventional_force.research_queue = { "science-validation-conventional" }
  state.conventional_lab = assert(surface.create_entity({
    name = "lab",
    position = { -50, 25 },
    force = state.conventional_force,
    raise_built = true,
  }))
  assert(#state.conventional_lab.get_inventory(defines.inventory.chest) == 1)
  local conventional_pole = spawn("small-electric-pole", -50, 27)
  conventional_pole.force = state.conventional_force
  local conventional_power = spawn("electric-energy-interface", -50, 30)
  conventional_power.force = state.conventional_force
  conventional_power.energy = 1000000000
  assert(state.conventional_lab.insert({ name = "automation-science-pack", count = 1 }) == 1)
  handling_cases.setup_existing_world(state)
  assert(
    game.forces.player.recipes["shwc-mixer"].enabled,
    "existing green research did not unlock new machines"
  )
  state.character = spawn("character", 50, 30)
  mixer_cases.setup_initial(state)
  handling_cases.setup_arms(state)
  state.lab = spawn("lab", 0, 25)
  state.lab_pole = spawn("small-electric-pole", -1, 27)
  state.lab_power = spawn("electric-energy-interface", 0, 30)
  state.lab_power.energy = 1000000000
  local lab_input = state.lab.get_inventory(defines.inventory.chest)
  assert(lab_input and #lab_input == 1, "lab needs one physical generic input slot")
  assert(lab_input.insert({ name = mixtures.packs[2], count = 1 }) == 1)
  for _, name in ipairs({ mixtures.packs[1], mixtures.beaker }) do
    assert(lab_input.insert({ name = name, count = 1 }) == 0, "occupied Lab accepted " .. name)
    assert(
      lab_input[1].name == mixtures.packs[2] and lab_input[1].count == 1,
      "competing insertion changed wrong science"
    )
  end
  local blocked_force = game.create_force("blocked-lab-validation")
  blocked_force.research_queue = { "science-validation-research" }
  state.blocked_lab = { force = blocked_force, blocked_ticks = 0 }
  local blocked_lab = state.blocked_lab
  blocked_lab.shell = spawn("lab", -35, -32)
  blocked_lab.source = spawn("wooden-chest", -38, -32)
  blocked_lab.arm = spawn("inserter", -37, -32, defines.direction.west)
  local blocked_pole = spawn("small-electric-pole", -36, -30)
  local blocked_power = spawn("electric-energy-interface", -35, -27)
  for _, entity in ipairs({
    blocked_lab.shell,
    blocked_lab.source,
    blocked_lab.arm,
    blocked_pole,
    blocked_power,
  }) do
    entity.force = blocked_force
  end
  blocked_power.energy = 1000000000
  assert(blocked_lab.source.insert({ name = mixtures.beaker, count = 1 }) == 1)
  state.lab_source = spawn("wooden-chest", -3, 25)
  spawn("inserter", -2, 25, defines.direction.west)
  assert(state.lab_source.insert({ name = mixtures.beaker, count = 4 }) == 4)
  local technology = game.forces.player.technologies["science-validation-research"]
  assert(#technology.research_unit_ingredients == 1, "equal red/green technology not converted")
  assert(technology.research_unit_ingredients[1].name == mixtures.beaker)
  assert(technology.research_unit_count == 5 and technology.research_unit_energy == 120)
  game.forces.player.add_research(technology)
  mixer_cases.setup_timing(state)
  handling_cases.setup_belt_route(state)
  return state
end

return M
