local mixtures = require("shared.mixtures")

-- Mixer machine: a script-driven Assembling machine 1 locked to the intake recipe.
local mixer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
mixer.name = "shwc-mixer"
mixer.minable.result = mixer.name
mixer.fixed_recipe = "shwc-intake"
mixer.show_recipe_icon = false
-- Runtime owns the ingredients, including the refund when this machine is mined.
mixer.return_ingredients_on_change = false
mixer.crafting_categories = { "shwc-intake" }
mixer.energy_usage = "90kW"
mixer.energy_source.drain = "3kW"
mixer.module_slots = 0
mixer.allowed_effects = {}

-- Mixer item: places the mixer machine.
local item = table.deepcopy(data.raw.item["assembling-machine-1"])
item.name = "shwc-mixer"
item.place_result = item.name

data:extend({
  -- Crafting category that only the mixer can run.
  { type = "recipe-category", name = "shwc-intake" },
  mixer,
  item,
  -- Player recipe for the mixer item, unlocked by Logistic science in data-final-fixes.
  {
    type = "recipe",
    name = "shwc-mixer",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "assembling-machine-1", amount = 1 },
      { type = "item", name = "electronic-circuit", amount = 5 },
    },
    results = { { type = "item", name = "shwc-mixer", amount = 1 } },
  },
  -- Hidden fixed recipe: its ingredients give the mixer native input slots and its
  -- results give it output slots. Runtime performs the actual crafting.
  {
    type = "recipe",
    name = "shwc-intake",
    icon = "__base__/graphics/icons/automation-science-pack.png",
    icon_size = 64,
    categories = { "shwc-intake" },
    hidden = true,
    enabled = true,
    energy_required = 1,
    ingredients = {
      { type = "item", name = mixtures.packs[1], amount = 1 },
      { type = "item", name = mixtures.packs[2], amount = 1 },
    },
    results = {
      { type = "item", name = mixtures.packs[1], amount = 1 },
      { type = "item", name = mixtures.packs[2], amount = 1 },
      { type = "item", name = mixtures.beaker, amount = 1 },
    },
    allow_productivity = false,
  },
})
