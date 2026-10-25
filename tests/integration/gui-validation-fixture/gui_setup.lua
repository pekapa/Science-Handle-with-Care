-- luacheck: globals storage game defines prototypes log
local M = {}
function M.mixer(state, player, position)
  local mixer = player.surface.create_entity({
    name = "shwc-mixer",
    position = { position.x + 4, position.y },
    force = player.force,
    raise_built = true,
  })
  state.mixer = mixer
  assert(mixer, "could not create test mixer beside player")
  return mixer
end

function M.lab(state, player, mixer)
  local lab = player.surface.create_entity({
    name = "lab",
    position = { mixer.position.x + 5, mixer.position.y },
    force = player.force,
    raise_built = true,
  })
  state.lab = lab
  assert(lab, "could not create test lab")
  local worker = player.surface.find_entities_filtered({
    name = "shwc-lab-worker",
    position = lab.position,
    limit = 1,
  })[1]
  state.worker = worker
  assert(worker, "production lab worker missing")
  return lab, worker
end

function M.teardown(state)
  local player = state.player
  if player and player.valid then
    player.opened = nil
    local foreign = player.gui.screen.foreign
    if foreign then
      foreign.destroy()
    end
  end
  for _, name in ipairs({ "lab", "mixer", "worker" }) do
    local entity = state[name]
    if entity and entity.valid then
      entity.destroy({ raise_destroy = true })
    end
    state[name] = nil
  end
end
return M
