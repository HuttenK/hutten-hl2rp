ix.Medicine = ix.Medicine or {}
local M = ix.Medicine
M.Catalog = {
 bandage = {name="Льняная повязка", model="models/props_wasteland/prison_pillow001a.mdl", uses=1, kind="bandage", wounds=3, time=8},
 splint = {name="Деревянная шина", model="models/props_debris/wood_board04a.mdl", uses=1, kind="splint", time=8}
}
function M.Model(def) return def.model end
function M.ResourceCapacity(item)
 local def = M.Catalog[item.uniqueID]
 return def and def.capacity
end
