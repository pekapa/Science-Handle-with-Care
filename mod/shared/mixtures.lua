local mixtures = {
  packs = { "automation-science-pack", "logistic-science-pack" },
  beaker = "shwc-beaker-red-green",
}
mixtures.outputs = { mixtures.packs[1], mixtures.packs[2], mixtures.beaker }

function mixtures.output(red, green)
  if red and green then
    return mixtures.beaker
  end
  return red and mixtures.packs[1] or green and mixtures.packs[2] or nil
end

function mixtures.is_beaker(name)
  return name == mixtures.beaker
end

return mixtures
