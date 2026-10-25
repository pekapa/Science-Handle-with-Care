-- luacheck: globals game
-- luacheck: read globals defines script log
local mixtures = require("__science-handle-with-care__/shared/mixtures")
local wear = require("__science-handle-with-care__/shared/wear")
local support = require("fixture_support")
local spawn, power, worker = support.spawn, support.power, support.worker
local salvage_lab = support.salvage_lab
local M = {}

local function check_blocked_lab(case, tick)
  if case.done then
    return
  end
  local input = case.shell.get_inventory(defines.inventory.chest)
  local native = worker(case.shell)
  local hand = case.arm.held_stack
  local credit = native.get_stored_durability(mixtures.beaker).durability
  assert(
    native.get_inventory(defines.inventory.lab_input).is_empty(),
    "blocked Lab worker buffered"
  )
  if not case.released then
    -- An already-full destination can prevent pickup; obstruct the observed real pickup.
    if not case.obstructed and hand.valid_for_read then
      assert(input.insert({ name = mixtures.packs[2], count = 1 }) == 1)
      case.obstructed = true
    end
    if case.obstructed then
      assert(input[1].name == mixtures.packs[2] and input[1].count == 1, "wrong science escaped")
    else
      assert(input.is_empty(), "Lab received beaker before observed pickup")
    end
    assert(credit == 0 and case.force.research_progress == 0, "blocked Lab admitted science")
    assert(
      case.source.get_item_count(mixtures.beaker) + (hand.valid_for_read and hand.count or 0) == 1,
      "blocked Lab transport lost or duplicated beaker"
    )
    if hand.valid_for_read then
      assert(
        hand.name == mixtures.beaker and wear.from_health(hand.health) == 1,
        "blocked Lab pickup wear changed"
      )
    end
    if case.arm.status == defines.entity_status.waiting_for_space_in_destination then
      assert(
        hand.valid_for_read and case.arm.energy > 0,
        "blocked Lab arm did not attempt delivery"
      )
      case.blocked_ticks = case.blocked_ticks + 1
    else
      case.blocked_ticks = 0
    end
    if case.blocked_ticks == 100 then
      input.clear()
      case.released = true
      log("SCIENCE_LAB_BLOCKED PASS held=100")
    end
    assert(tick < 300 or case.released, "Lab arm never held blocked delivery for 100 ticks")
  elseif credit > 0 and case.force.research_progress > 0 then
    assert(
      input.is_empty() and not hand.valid_for_read,
      "released Lab did not admit delivered beaker"
    )
    assert(case.source.get_item_count(mixtures.beaker) == 0, "released Lab left source beaker")
    case.done = true
    log("SCIENCE_LAB_RELEASED PASS")
  end
  assert(tick < 400 or case.done, "removing wrong science did not permit delivery and research")
end

function M.assert_empty_workers(state)
  for _, entity in pairs(state.surface.find_entities_filtered({ name = "shwc-lab-worker" })) do
    assert(
      entity.get_inventory(defines.inventory.lab_input).is_empty(),
      "hidden physical science buffer"
    )
  end
end

function M.conventional_tick(state, tick)
  if tick == 10 or tick == 20 then
    assert(
      state.conventional_lab.get_inventory(defines.inventory.chest).is_empty(),
      "conventional three-science research blocked required raw ingredient"
    )
    local next_pack = tick == 10 and "logistic-science-pack" or "chemical-science-pack"
    assert(state.conventional_lab.insert({ name = next_pack, count = 1 }) == 1)
  elseif tick == 110 then
    assert(
      state.conventional_force.technologies["science-validation-conventional"].researched,
      "conventional three-science research did not complete"
    )
    assert(
      state.conventional_lab.get_inventory(defines.inventory.chest).is_empty(),
      "conventional research left physical input"
    )
    local native = worker(state.conventional_lab)
    for _, name in ipairs({
      "automation-science-pack",
      "logistic-science-pack",
      "chemical-science-pack",
    }) do
      assert(
        native.get_stored_durability(name).durability < 0.000001,
        "conventional research did not consume exactly one " .. name
      )
    end
  end
end

function M.extended_tick(state, tick)
  local force = game.forces.player
  if tick == 10 then
    assert(
      state.lab.get_inventory(defines.inventory.chest)[1].name == mixtures.packs[2],
      "wrong mixture did not block single physical slot"
    )
    assert(
      worker(state.lab).get_inventory(defines.inventory.lab_input).is_empty(),
      "worker has physical science buffer"
    )
    state.lab.get_inventory(defines.inventory.chest).clear()
    assert(state.lab.insert({ name = mixtures.beaker, count = 1 }) == 1)
  elseif tick == 900 then
    assert(
      game.forces.player.technologies["science-validation-research"].researched,
      "initial native research did not complete"
    )
    assert(
      state.lab_source.get_inventory(defines.inventory.chest).is_empty(),
      "five-unit research left source beakers"
    )
    assert(
      state.lab.get_inventory(defines.inventory.chest).get_item_count(mixtures.beaker) == 0,
      "five-unit research left physical beakers"
    )
    assert(
      worker(state.lab).get_stored_durability(mixtures.beaker).durability < 0.000001,
      "five-unit research left unexpected credit"
    )
    state.lab.insert({ name = mixtures.beaker, count = 1 })
    force.research_queue = { "science-validation-credit" }
    state.other_lab = spawn("lab", 12, 25)
    power(12, 27)
    worker(state.other_lab).disabled_by_script = true
    state.other_lab.insert({ name = mixtures.beaker, count = 1 })
    state.health_lab = spawn("lab", 42, 25)
    power(42, 27)
    local committed = state.health_lab.get_inventory(defines.inventory.chest)
    assert(committed.insert({ name = mixtures.beaker, count = 1, health = wear.to_health(9) }) == 1)
  elseif tick == 930 then
    local credit = worker(state.health_lab).get_stored_durability(mixtures.beaker).durability
    assert(credit > 0 and credit < 1, "worn beaker did not become native credit")
    assert(
      worker(state.health_lab).get_module_inventory().insert({ name = "speed-module", count = 1 })
        == 1
    )
    local mined = game.create_inventory(8)
    local native = worker(state.health_lab)
    salvage_lab(state.health_lab, mined)
    assert(not native.valid, "script removal orphaned worker")
    assert(mined.get_item_count("speed-module") == 1, "removal lost worker module")
    local tagged = assert(mined.find_item_stack("lab"), "removal lost credit item")
    assert(#tagged.tags.sciencecredits == 1, "removal lost tagged credit")
    assert(
      math.abs(tagged.tags.sciencecredits[1].durability - credit) < 0.000001,
      "removal changed fractional mixed credit"
    )
    mined.destroy()
  elseif tick == 960 then
    state.independent_credit = worker(state.lab).get_stored_durability(mixtures.beaker).durability
    assert(
      state.independent_credit > 0 and state.independent_credit < 1,
      "primary lab not consuming credit"
    )
    state.lab_pole.destroy()
    worker(state.lab).energy = 0
    state.progress_before_other = game.forces.player.research_progress
    worker(state.other_lab).disabled_by_script = false
  elseif tick == 1020 then
    assert(
      worker(state.lab).get_stored_durability(mixtures.beaker).durability
        == state.independent_credit,
      "other lab spent paused primary credit"
    )
    assert(
      game.forces.player.research_progress > state.progress_before_other,
      "second lab did not advance shared research"
    )
    state.other_credit = worker(state.other_lab).get_stored_durability(mixtures.beaker).durability
    assert(
      state.other_credit > 0 and state.other_credit < 1,
      "second lab has no independent credit"
    )
    force.research_queue = { "science-validation-raw" }
    state.other_lab.insert({ name = mixtures.packs[1], count = 1 })
    state.lab.insert({ name = mixtures.packs[1], count = 1 })
    state.lab_pole = spawn("small-electric-pole", -1, 27)
    state.tagged_input_shell = spawn("lab", 24, 25)
    power(24, 27)
    assert(state.tagged_input_shell.insert({ name = mixtures.packs[1], count = 1 }) == 1)
  elseif tick == 1050 then
    state.tagged_input_worker = worker(state.tagged_input_shell)
    state.tagged_input_worker.disabled_by_script = true
    state.tagged_shell_credit =
      state.tagged_input_worker.get_stored_durability(mixtures.packs[1]).durability
    assert(state.tagged_shell_credit > 0 and state.tagged_shell_credit < 1)
    assert(
      worker(state.lab).get_stored_durability(mixtures.beaker).durability
        == state.independent_credit,
      "research switch erased primary credit"
    )
    assert(
      worker(state.other_lab).get_stored_durability(mixtures.beaker).durability
        == state.other_credit,
      "research switch erased second credit"
    )
    assert(
      game.forces.player.research_progress > 0,
      "single-science research did not use raw science"
    )
    local raw = worker(state.other_lab).get_stored_durability(mixtures.packs[1]).durability
    assert(raw > 0 and raw < 1, "raw science did not retain fractional native credit")
    force.research_queue = { "science-validation-credit" }
  elseif tick == 1100 then
    worker(state.other_lab).disabled_by_script = true
    state.robot_credit = {}
    for _, name in ipairs(worker(state.other_lab).prototype.lab_inputs) do
      state.robot_credit[name] = worker(state.other_lab).get_stored_durability(name).durability
    end
    assert(
      worker(state.other_lab)
        .get_module_inventory()
        .insert({ name = "productivity-module", count = 1 }) == 1
    )
    state.robot_worker = worker(state.other_lab)
    state.robot_shell = state.other_lab
    local port = spawn("roboport", 18, 33)
    port.energy = 100000000
    spawn("small-electric-pole", 20, 31)
    local source = spawn("electric-energy-interface", 23, 31)
    source.energy = 1000000000
    state.robot_chest = spawn("storage-chest", 18, 29)
    assert(port.insert({ name = "construction-robot", count = 10 }) == 10)
    assert(state.robot_shell.insert({ name = "lab", count = 2 }) == 2)
    assert(state.robot_shell.order_deconstruction(game.forces.player))
    local incoming = state.tagged_input_shell.get_inventory(defines.inventory.chest)[1]
    incoming.set_stack({ name = "lab", count = 1 })
    incoming.tags = {
      sciencecredits = { { name = mixtures.packs[2], durability = 0.375, quality = "normal" } },
      fixture_marker = "already-credited-input",
      fixture_metadata = { value = 17 },
    }
    assert(state.tagged_input_shell.order_deconstruction(game.forces.player))
    local primary_credit = worker(state.lab).get_stored_durability(mixtures.beaker).durability
    assert(
      primary_credit < state.independent_credit,
      "matching research did not resume primary credit"
    )
    local other_credit = worker(state.other_lab).get_stored_durability(mixtures.beaker).durability
    assert(other_credit < state.other_credit, "matching research did not resume second credit")
  end
end

function M.robot_tick(state)
  if not state.robot_shell then
    return
  end
  local delivered = state.robot_chest.get_inventory(defines.inventory.chest)
  if
    not state.robot_mined
    and not state.robot_shell.valid
    and not state.tagged_input_shell.valid
    and delivered.get_item_count("lab") == 5
    and delivered.get_item_count("productivity-module") == 1
  then
    assert(
      not state.robot_shell.valid and not state.robot_worker.valid,
      "robot mining left shell or worker"
    )
    local input = state.robot_chest.get_inventory(defines.inventory.chest)
    assert(not state.tagged_input_worker.valid, "tagged-input mining orphaned worker")
    state.extra_labs = game.create_inventory(8)
    local incoming_count, shell_count = 0, 0
    for i = 1, #input do
      local stack = input[i]
      if stack.valid_for_read and stack.name == "lab" and stack.tags.sciencecredits then
        local tags = stack.tags
        if tags.fixture_marker then
          assert(tags.fixture_marker == "already-credited-input", "input marker overwritten")
          assert(tags.fixture_metadata.value == 17, "input metadata overwritten")
          assert(#tags.sciencecredits == 1, "input gained credit")
          local credit = tags.sciencecredits[1]
          assert(
            credit.name == mixtures.packs[2]
              and credit.durability == 0.375
              and credit.quality == "normal",
            "tagged input credit overwritten"
          )
          incoming_count = incoming_count + stack.count
          assert(state.extra_labs.insert(stack) == stack.count)
          stack.clear()
        elseif #tags.sciencecredits == 1 and tags.sciencecredits[1].name == mixtures.packs[1] then
          assert(
            math.abs(tags.sciencecredits[1].durability - state.tagged_shell_credit) < 0.000001,
            "tagged-input shell credit changed"
          )
          shell_count = shell_count + stack.count
          assert(state.extra_labs.insert(stack) == stack.count)
          stack.clear()
        end
      end
    end
    assert(incoming_count == 1, "tagged Lab input lost or duplicated")
    assert(shell_count == 1, "tagged-input shell credit lost or duplicated")
    local lab
    for i = 1, #input do
      local stack = input[i]
      if stack.valid_for_read and stack.name == "lab" and stack.tags.sciencecredits then
        lab = stack
        break
      end
    end
    assert(lab, "robot did not deliver credited mined lab")
    assert(lab.tags and lab.tags.sciencecredits, "robot mined lab lost credit tags")
    assert(lab.count == 1, "robot mining tagged multiple Lab items with the same credit")
    local untagged = 0
    for i = 1, #input do
      local stack = input[i]
      if stack.valid_for_read and stack.name == "lab" and not stack.tags.sciencecredits then
        untagged = untagged + stack.count
        assert(state.extra_labs.insert(stack) == stack.count)
        stack.clear()
      end
    end
    assert(untagged == 2, "robot mining changed untagged Lab input items")
    assert(input.get_item_count("lab") == 1, "robot mining returned extra credit carriers")
    log("SCIENCE_TAGGED_INPUT_ROBOT PASS incoming=1 shell=1 original=1 untagged=2")

    assert(input.get_item_count("productivity-module") == 1, "robot mining lost native module")
    local tags = lab.tags
    local restored = {}
    for _, credit in ipairs(tags.sciencecredits) do
      restored[credit.name] = credit.durability
    end
    for name, amount in pairs(state.robot_credit) do
      assert(
        math.abs((restored[name] or 0) - amount) < 0.000001,
        "robot mining changed " .. name .. " credit"
      )
    end
    state.robot_ghost = state.surface.create_entity({
      name = "entity-ghost",
      inner_name = "lab",
      position = { 12, 25 },
      force = game.forces.player,
    })
    -- Actual robot placement consumes the tagged item delivered by construction robots.
    state.robot_mined = true
  elseif state.robot_mined and not state.robot_rebuilt and not state.robot_ghost.valid then
    local shell = assert(
      state.surface.find_entities_filtered({ name = "lab", position = { 12, 25 }, radius = 1 })[1],
      "robot rebuilt shell absent"
    )
    state.restored_robot_lab = shell
    local native = worker(shell)
    local raw = native.get_stored_durability(mixtures.packs[1]).durability
    assert(
      math.abs(raw - state.robot_credit[mixtures.packs[1]]) < 0.000001,
      "robot build lost fractional raw credit"
    )
    local mixed = native.get_stored_durability(mixtures.beaker).durability
    if mixed > 0 and mixed < state.robot_credit[mixtures.beaker] then
      state.robot_rebuilt = true
    end
  end
end

function M.blocked_delivery_tick(state, tick)
  check_blocked_lab(state.blocked_lab, tick)
end

function M.tick(state, tick)
  if tick == 90 then
    state.credit_before_pause = worker(state.lab).get_stored_durability(mixtures.beaker).durability
    assert(
      state.credit_before_pause > 0 and state.credit_before_pause < 1,
      "native lab has no fractional credit: "
        .. state.credit_before_pause
        .. " energy="
        .. worker(state.lab).energy
        .. " status="
        .. worker(state.lab).status
    )
    state.lab_pole.destroy()
    worker(state.lab).energy = 0
  elseif tick == 180 then
    state.lab_pole = spawn("small-electric-pole", -1, 27)
  elseif tick == 2000 then
    assert(
      state.robot_mined,
      "robot mining/delivery deadline exceeded: original="
        .. tostring(state.robot_shell.valid)
        .. " tagged="
        .. tostring(state.tagged_input_shell.valid)
        .. " Labs="
        .. state.robot_chest.get_item_count("lab")
        .. " modules="
        .. state.robot_chest.get_item_count("productivity-module")
    )
  elseif tick == 2300 then
    assert(state.robot_rebuilt, "robot rebuild/research deadline exceeded")
  elseif tick == 2350 then
    local shell = state.restored_robot_lab
    local native = worker(shell)
    native.disabled_by_script = true
    assert(native.get_module_inventory().insert({ name = "speed-module", count = 1 }) == 1)
    state.lifecycle_credit = {}
    for _, name in ipairs(native.prototype.lab_inputs) do
      state.lifecycle_credit[name] = native.get_stored_durability(name).durability
    end
    script.raise_script_built({ entity = shell })
    assert(worker(shell) == native, "duplicate build replaced worker")
    assert(#shell.surface.find_entities_filtered({
      name = "shwc-lab-worker",
      position = shell.position,
      radius = 0.1,
    }) == 1, "duplicate build orphaned worker")
    local clone = assert(shell.clone({ position = { 52, 25 } }), "native shell clone failed")
    local clone_worker = worker(clone)
    local duplicate = native.clone({ position = clone.position })
    assert(not duplicate or not duplicate.valid, "native worker clone orphaned paid science")
    assert(clone_worker.get_module_inventory().is_empty(), "clone duplicated modules")
    for _, name in ipairs(clone_worker.prototype.lab_inputs) do
      assert(clone_worker.get_stored_durability(name).durability == 0, "clone duplicated credit")
    end
    clone.destroy({ raise_destroy = true })
    assert(not clone_worker.valid, "cloned shell removal orphaned worker")
    assert(shell.teleport({ 14, 25 }), "same-surface shell teleport failed")
    state.lifecycle_worker = native
  elseif tick == 2351 then
    local shell = state.restored_robot_lab
    local native = worker(shell)
    assert(
      not state.lifecycle_worker.valid or native == state.lifecycle_worker,
      "teleport orphaned old worker"
    )
    assert(
      native.get_module_inventory().get_item_count("speed-module") == 1,
      "teleport lost module"
    )
    for name, amount in pairs(state.lifecycle_credit) do
      assert(
        math.abs(native.get_stored_durability(name).durability - amount) < 0.000001,
        "duplicate build or teleport changed " .. name .. " credit"
      )
    end
    native.destroy({ raise_destroy = true })
    assert(not shell.valid, "worker removal left unpaired shell")
  end
end

function M.checkpoint(state)
  state.credit_checkpoint = worker(state.lab).get_stored_durability(mixtures.beaker).durability
  assert(state.credit_checkpoint == state.credit_before_pause, "power interruption spent credit")
end

function M.resumed(state)
  local credit = worker(state.lab).get_stored_durability(mixtures.beaker).durability
  assert(credit == state.credit_checkpoint, "reload lost credit")
end

function M.finish(state)
  local input = state.lab.get_inventory(defines.inventory.chest)
  assert(#input == 1, "lab physical input size changed")
  assert(
    game.forces.player.technologies["science-validation-research"].researched,
    "native five-beaker research did not complete"
  )
end

return M
