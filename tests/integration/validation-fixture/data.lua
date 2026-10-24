data:extend({
  {
    type = "technology",
    name = "science-validation-research",
    icon = "__base__/graphics/technology/automation.png",
    icon_size = 256,
    unit = {
      count = 5,
      time = 2,
      ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } },
    },
  },
})

for _, name in ipairs({ "science-validation-credit", "science-validation-raw" }) do
  data:extend({
    {
      type = "technology",
      name = name,
      icon = "__base__/graphics/technology/automation.png",
      icon_size = 256,
      unit = {
        count = 100,
        time = 10,
        ingredients = name == "science-validation-credit"
            and { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 } }
          or { { "automation-science-pack", 1 } },
      },
    },
  })
end
