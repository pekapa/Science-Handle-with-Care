local mixtures = require("shared.mixtures")

data:extend({
  -- Combined red+green science: a fragile Tool whose health records handling wear
  -- and whose durability is its remaining research value.
  {
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
  },
  -- Waste left when a beaker exhausts its wear budget; stacks and takes no more wear.
  {
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
  },
})
