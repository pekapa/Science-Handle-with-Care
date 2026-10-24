local mixtures = require("shared.mixtures")
for _, technology in pairs(data.raw.technology) do
  local unit = technology.unit
  if unit and #unit.ingredients == 2 then
    local amounts = {}
    for _, ingredient in ipairs(unit.ingredients) do
      amounts[ingredient[1]] = ingredient[2]
    end
    if amounts[mixtures.packs[1]] and amounts[mixtures.packs[1]] == amounts[mixtures.packs[2]] then
      unit.ingredients = { { mixtures.beaker, amounts[mixtures.packs[1]] } }
    end
  end
end
local unlocks = data.raw.technology["logistic-science-pack"].effects
unlocks[#unlocks + 1] = { type = "unlock-recipe", recipe = "shwc-mixer" }
