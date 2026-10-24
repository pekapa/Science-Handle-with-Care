local composition = {}

-- Input is a map of science item name -> positive integer quantity.
-- Callers must verify that names refer to allowed science items in the game.
function composition.key(ingredients)
  assert(type(ingredients) == "table", "composition must be a table")
  local names = {}
  for name, quantity in pairs(ingredients) do
    assert(type(name) == "string" and #name > 0, "item names must be nonempty strings")
    assert(
      type(quantity) == "number"
        and quantity > 0
        and quantity <= 9007199254740991
        and quantity % 1 == 0,
      "quantities must be exact positive integers"
    )
    names[#names + 1] = name
  end
  assert(#names > 0, "composition must contain at least one item")
  table.sort(names)
  local parts = {}
  for _, name in ipairs(names) do
    -- Length-prefix names so separators inside a name cannot cause collisions.
    parts[#parts + 1] = #name
      .. ":"
      .. name
      .. "="
      .. string.format("%.0f", ingredients[name])
      .. ";"
  end
  return table.concat(parts)
end

return composition
