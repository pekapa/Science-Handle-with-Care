local mixtures = require("shared.mixtures")
local prototypes = { { type = "recipe-category", name = "shwc-intake" } }
prototypes[#prototypes + 1] = {
  type = "tool",
  name = mixtures.beaker,
  icons = {
    { icon = "__base__/graphics/icons/automation-science-pack.png", icon_size = 64 },
    {
      icon = "__base__/graphics/icons/logistic-science-pack.png",
      icon_size = 64,
      scale = 0.35,
      shift = { 8, 8 },
    },
  },
  subgroup = "science-pack",
  order = "z[shwc]-beaker",
  stack_size = 1,
  flags = { "not-stackable" },
  durability = 1,
  durability_description_key = "description.science-pack-remaining-amount",
  localised_description = { "item-description.shwc-beaker" },
}
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
mixer.show_recipe_icon = false
-- Runtime owns the ingredients, including the refund when this machine is mined.
mixer.return_ingredients_on_change = false
mixer.crafting_categories = { "shwc-intake" }
mixer.energy_usage = "90kW"
mixer.energy_source.drain = "3kW"
mixer.module_slots = 0
mixer.allowed_effects = {}
prototypes[#prototypes + 1] = mixer
local base_lab = data.raw.lab.lab
local worker = table.deepcopy(base_lab)
worker.name = "shwc-lab-worker"
worker.inputs[#worker.inputs + 1] = mixtures.beaker
worker.flags = {
  "not-on-map",
  "not-blueprintable",
  "not-deconstructable",
  "not-in-kill-statistics",
  "placeable-off-grid",
}
worker.minable = nil
worker.selectable_in_game = false
worker.collision_mask = { layers = {} }
worker.collision_box = { { 0, 0 }, { 0, 0 } }
worker.on_animation, worker.off_animation = nil, nil
prototypes[#prototypes + 1] = worker
local shell = {
  type = "container",
  name = "lab",
  localised_name = { "entity-name.lab" },
  icon = base_lab.icon,
  flags = table.deepcopy(base_lab.flags),
  max_health = base_lab.max_health,
  minable = table.deepcopy(base_lab.minable),
  corpse = base_lab.corpse,
  dying_explosion = base_lab.dying_explosion,
  collision_box = table.deepcopy(base_lab.collision_box),
  selection_box = table.deepcopy(base_lab.selection_box),
  inventory_size = 1,
  inventory_type = "normal",
  picture = table.deepcopy(base_lab.off_animation),
}
rawset(data.raw.lab, "lab", nil)
prototypes[#prototypes + 1] = shell
local lab_item = table.deepcopy(data.raw.item.lab)
rawset(data.raw.item, "lab", nil)
lab_item.type = "item-with-tags"
prototypes[#prototypes + 1] = lab_item
local item = table.deepcopy(data.raw.item["assembling-machine-1"])
item.name = "shwc-mixer"
item.place_result = item.name
prototypes[#prototypes + 1] = item
prototypes[#prototypes + 1] = {
  type = "recipe",
  name = "shwc-mixer",
  enabled = false,
  energy_required = 2,
  ingredients = {
    { type = "item", name = "assembling-machine-1", amount = 1 },
    { type = "item", name = "electronic-circuit", amount = 5 },
  },
  results = { { type = "item", name = "shwc-mixer", amount = 1 } },
}
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
    { type = "item", name = mixtures.packs[1], amount = 1 },
    { type = "item", name = mixtures.packs[2], amount = 1 },
    { type = "item", name = mixtures.beaker, amount = 1 },
  },
  allow_productivity = false,
}
data:extend(prototypes)
