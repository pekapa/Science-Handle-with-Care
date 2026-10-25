local mixtures = require("shared.mixtures")

local base_lab = data.raw.lab.lab

-- Hidden worker: an invisible native lab that owns power, modules, research timing
-- and stored credit for one visible Lab.
local worker = table.deepcopy(base_lab)
worker.name = "shwc-lab-worker"
worker.inputs[#worker.inputs + 1] = mixtures.beaker
worker.flags = {
  "not-on-map",
  "not-blueprintable",
  "not-deconstructable",
  "not-in-kill-statistics",
  "placeable-off-grid",
}
worker.minable = nil
worker.selectable_in_game = false
worker.collision_mask = { layers = {} }
worker.collision_box = { { 0, 0 }, { 0, 0 } }
worker.on_animation, worker.off_animation = nil, nil

-- Visible Lab: replaces the base lab with a one-slot container that looks like it,
-- because native lab inventories cannot share one untyped science slot.
local shell = {
  type = "container",
  name = "lab",
  localised_name = { "entity-name.lab" },
  icon = base_lab.icon,
  flags = table.deepcopy(base_lab.flags),
  max_health = base_lab.max_health,
  minable = table.deepcopy(base_lab.minable),
  corpse = base_lab.corpse,
  dying_explosion = base_lab.dying_explosion,
  collision_box = table.deepcopy(base_lab.collision_box),
  selection_box = table.deepcopy(base_lab.selection_box),
  inventory_size = 1,
  inventory_type = "normal",
  picture = table.deepcopy(base_lab.off_animation),
}
rawset(data.raw.lab, "lab", nil)

-- Lab item: an item-with-tags so a mined Lab carries its stored research credit.
local lab_item = table.deepcopy(data.raw.item.lab)
rawset(data.raw.item, "lab", nil)
lab_item.type = "item-with-tags"

data:extend({ worker, shell, lab_item })
