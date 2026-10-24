std = "lua52"
max_line_length = 100

files["mod/data.lua"] = { read_globals = { "data" } }
files["mod/control.lua"] = {
  globals = { "storage" },
  read_globals = { "script", "game", "defines", "prototypes", "settings", "log" },
}
files["mod/shared/**"] = { std = "lua52" }
files["tests/integration/**/data.lua"] = { read_globals = { "data" } }
files["tests/integration/**/control.lua"] = {
  globals = { "storage" },
  read_globals = { "script", "game", "defines", "prototypes", "log" },
}
