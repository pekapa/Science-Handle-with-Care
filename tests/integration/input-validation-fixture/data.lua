data.raw.container.lab.factoriopedia_simulation = {
  mods = { "science-handle-with-care", "science-input-validation-fixture" },
  game_view_settings = { show_controller_gui = true },
  generate_map = true,
  checkboard = true,
  init_update_count = 0,
  length = 3600,
  init = 'remote.call("science-input-validation", "start")',
  update = 'remote.call("science-input-validation", "step")',
}
