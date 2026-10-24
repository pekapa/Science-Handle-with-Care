local mixtures = {
  packs = { "automation-science-pack", "logistic-science-pack" },
  items = { "shwc-beaker-red", "shwc-beaker-green", "shwc-beaker-red-green" },
}

function mixtures.output(red, green)
  return mixtures.items[(red and 1 or 0) + (green and 2 or 0)]
end

function mixtures.is_beaker(name)
  for _, item in ipairs(mixtures.items) do
    if name == item then
      return true
    end
  end
  return false
end

return mixtures
