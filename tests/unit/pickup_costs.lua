package.path = "./?.lua;" .. package.path
local constants = require("shared.constants")
assert(constants.pickup_cost["inserter"] == 1)
assert(constants.pickup_cost["burner-inserter"] == 1)
assert(constants.pickup_cost["long-handed-inserter"] == 1)
assert(constants.pickup_cost["fast-inserter"] == 2)
assert(constants.pickup_cost["bulk-inserter"] == 4)
assert(constants.pickup_cost["stack-inserter"] == 4)
print("pickup costs passed")
