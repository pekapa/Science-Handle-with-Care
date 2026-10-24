package.path = "./?.lua;" .. package.path
local composition = require("shared.composition")
local function rejects(call)
  assert(not pcall(call), "invalid input was accepted")
end
local a = { ["automation-science-pack"] = 2, ["logistic-science-pack"] = 1 }
local b = { ["logistic-science-pack"] = 1, ["automation-science-pack"] = 2 }
assert(composition.key(a) == composition.key(b))
b["automation-science-pack"] = 3
assert(composition.key(a) ~= composition.key(b))
assert(composition.key({ ["a=1;b"] = 2 }) ~= composition.key({ a = 1, b = 2 }))
for _, invalid in ipairs({
  {},
  { a = 0 },
  { a = -1 },
  { a = 0.5 },
  { a = "2" },
  { [1] = 2 },
  { [""] = 1 },
  { a = math.huge },
  { a = 9007199254740992 },
}) do
  rejects(function()
    composition.key(invalid)
  end)
end
print("composition identity passed")
