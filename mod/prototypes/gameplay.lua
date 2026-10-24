local mixtures = require("shared.mixtures")
local prototypes = { { type = "recipe-category", name = "shwc-intake" } }
for index, name in ipairs(mixtures.items) do
  local icons = {
    { icon = "__base__/graphics/icons/automation-science-pack.png", icon_size = 64 },
  }
  if index == 2 then
    icons[1].icon = "__base__/graphics/icons/logistic-science-pack.png"
  elseif index == 3 then
    icons[2] = {
      icon = "__base__/graphics/icons/logistic-science-pack.png",
      icon_size = 64,
      scale = 0.35,
      shift = { 8, 8 },
    }
  end
  prototypes[#prototypes + 1] = {
    type = "tool",
    name = name,
    icons = icons,
    subgroup = "science-pack",
    order = "z[shwc]-" .. index,
    stack_size = 1,
    flags = { "not-stackable" },
    durability = 1,
    durability_description_key = "description.science-pack-remaining-amount",
    localised_description = { "item-description.shwc-beaker" },
  }
end
prototypes[#prototypes + 1] = {
  type = "item",
  name = "shwc-denatured-science",
  icons = {
    {
      icon = "__base__/graphics/icons/automation-science-pack.png",
      icon_size = 64,
      tint = { 0.6, 0.3, 0.8, 1 },
    },
  },
  subgroup = "science-pack",
  order = "z[shwc]-waste",
  stack_size = 1000,
}
local mixer = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-1"])
mixer.name = "shwc-mixer"
mixer.minable.result = mixer.name
mixer.fixed_recipe = "shwc-intake"
mixer.crafting_categories = { "shwc-intake" }
mixer.energy_usage = "90kW"
mixer.energy_source.drain = "3kW"
mixer.module_slots = 0
mixer.allowed_effects = {}
prototypes[#prototypes + 1] = mixer
local lab = table.deepcopy(data.raw.lab.lab)
lab.name = "shwc-lab"
lab.minable.result = lab.name
for _, item in ipairs(mixtures.items) do
  lab.inputs[#lab.inputs + 1] = item
end
prototypes[#prototypes + 1] = lab
for _, name in ipairs({ "shwc-mixer", "shwc-lab" }) do
  local base = name == "shwc-mixer" and "assembling-machine-1" or "lab"
  local item = table.deepcopy(data.raw.item[base])
  item.name = name
  item.place_result = name
  prototypes[#prototypes + 1] = item
  prototypes[#prototypes + 1] = {
    type = "recipe",
    name = name,
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = base, amount = 1 },
      { type = "item", name = "electronic-circuit", amount = 5 },
    },
    results = { { type = "item", name = name, amount = 1 } },
  }
end
prototypes[#prototypes + 1] = {
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
    { type = "item", name = mixtures.items[1], amount = 1 },
    { type = "item", name = mixtures.items[2], amount = 1 },
    { type = "item", name = mixtures.items[3], amount = 1 },
  },
  allow_productivity = false,
}
data:extend(prototypes)
