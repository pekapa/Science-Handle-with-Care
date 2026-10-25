-- luacheck: globals storage game defines prototypes log
local M = {}
function M.panel(player, entity)
  assert(player.opened == entity, "production replaced native machine window")
  assert(not player.gui.screen["shwc-machine"], "custom machine window retained")
  local frame = player.gui.relative["shwc-machine-info"]
  assert(frame and frame.valid, "relative machine information missing")
  assert(
    frame.anchor.names and #frame.anchor.names == 1 and frame.anchor.names[1] == entity.name,
    "relative panel targets wrong prototype"
  )
  return frame
end

function M.credit_display(player, frame, lab, worker, gui)
  storage.machine_guis = { [player.index] = lab }
  storage.labs = { [lab.unit_number] = { worker = worker } }
  local force = lab.force
  local function check(technology, name, amount)
    force.research_queue = {}
    force.technologies[technology].researched = false
    for _, prerequisite in pairs(force.technologies[technology].prerequisites) do
      prerequisite.researched = true
    end
    force.research_queue = { technology }
    assert(
      force.current_research and force.current_research.name == technology,
      "credit test could not select research " .. technology
    )
    worker.set_stored_durability(name, { durability = amount, quality = "normal" })
    gui.tick()
    local rows = frame.credit.children
    assert(#rows == 1, "active research credit row missing or stale")
    local row = rows[1]
    assert(row.pack.sprite == "item/" .. name, "credit row shows wrong research ingredient")
    assert(math.abs(row.remaining.value - amount) < 0.000001, "credit display differs from worker")
    assert(row.remaining.tooltip[2] == tostring(amount), "credit tooltip omits actual balance")
    assert(
      frame.progress.value == force.research_progress,
      "force progress replaced by local credit"
    )
  end
  check("automation", "automation-science-pack", 0.75)
  check("automation", "automation-science-pack", 0.25)
  check("logistics-2", "shwc-beaker-red-green", 0.4)
  check("logistics-2", "shwc-beaker-red-green", 0)
  force.research_queue = {}
  gui.tick()
  assert(#frame.credit.children == 0, "no research retains stale credit rows")
  assert(frame.progress.value == 0, "no research retains force progress")
  log("SCIENCE_GUI_CREDIT PASS production refresh, research changes and zero credit")
end

return M
