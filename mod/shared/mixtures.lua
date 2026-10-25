local mixtures = {
  packs = { "automation-science-pack", "logistic-science-pack" },
  beaker = "shwc-beaker-red-green",
}
mixtures.outputs = { mixtures.packs[1], mixtures.packs[2], mixtures.beaker }

---Names the mixer output for the science types present at crafting start.
---@param red boolean
---@param green boolean
---@return string? output nil when neither pack is present.
function mixtures.output(red, green)
  if red and green then
    return mixtures.beaker
  end
  return red and mixtures.packs[1] or green and mixtures.packs[2] or nil
end

---@param name string Item name.
---@return boolean
function mixtures.is_beaker(name)
  return name == mixtures.beaker
end

return mixtures
