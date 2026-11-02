ix.Medicine = ix.Medicine or {}
local M = ix.Medicine
M.Catalog = {
 bandage = {name="Бинт", model="models/props_clutter/bar_rag.mdl", uses=5, kind="bandage", time=8},
 splint = {name="Деревянная шина", model="models/props_clutter/flute.mdl", uses=1, kind="splint", time=8},
 decoction = {name="Отвар", model="models/props/furnitures/mn/mn_pot/mn_pot.mdl", uses=1, capacity=1000, kind="restore", healing=30, time=6},
 herbal_decoction = {name="Травяной отвар", model="models/leon/eldenring/flask.mdl", uses=5, kind="blood", blood=0.25, time=6}
}
function M.Model(def) return def.model end
function M.ResourceCapacity(item)
 local def = M.Catalog[item.uniqueID]
 return def and def.capacity
end
