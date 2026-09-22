-- Loaded by Helix before medical item definitions.
-- Inventory owns every dose. EFT supplies presentation, never a second health pool.
ix.Medicine = ix.Medicine or {}
local M = ix.Medicine
M.Catalog = {
 bandage = {name="Жгут CAT", model="cat", uses=1, kind="bandage", wounds=3, time=8},
 healthvial = {name="Аптечка АИ-2", model="automedkit", uses=3, kind="kit", wounds=2, time=10},
 healthkit = {name="Аптечка Salewa", model="salewa", uses=4, kind="kit", wounds=4, time=12},
 painkiller = {name="Анальгин", model="anaglin", uses=4, kind="painkiller", pain=180, time=5},
 morphine = {name="Морфин", model="injector", skin=1, uses=1, kind="painkiller", pain=300, time=4},
 epinephrine = {name="Адреналин", model="injector", skin=7, uses=1, kind="stimulant", pain=90, time=4},
 eft_afak = {name="Аптечка AFAK", model="afak", uses=5, kind="kit", wounds=5, time=14},
 eft_grizzly = {name="Медицинский набор Grizzly", model="grizzly", uses=8, kind="kit", wounds=8, time=16},
 eft_splint = {name="Алюминиевая шина", model="alusplint", uses=1, kind="splint", time=8},
 eft_surgery = {name="Хирургический набор CMS", model="surgicalkit", uses=5, kind="surgery", time=20},
 eft_augmentin = {name="Аугментин", model="augmentin", uses=1, kind="painkiller", pain=120, time=5},
 eft_propital = {name="Пропитал", model="injector", skin=9, uses=1, kind="stimulant", pain=240, wounds=2, time=4},
 eft_etg = {name="eTG-change", model="injector", skin=5, uses=1, kind="kit", wounds=6, time=4},
 eft_l1 = {name="L1", model="injector", skin=4, uses=1, kind="stimulant", pain=120, time=4},
 eft_tg12 = {name="Загустин", model="injector", skin=13, uses=1, kind="bandage", wounds=8, time=4}
}

function M.Model(def, view)
 return "models/weapons/sweps/eft/"..def.model.."/"..(view and "v" or "w").."_meds_"..def.model..".mdl"
end


-- Resource capacities are independent of the legacy dose count (used for migration).
for id, capacity in pairs({healthvial=100, healthkit=400, eft_afak=400, eft_grizzly=1600}) do
 local def=M.Catalog[id]
 def.capacity=capacity; def.bleedCost=50; def.hpCost=1
end
function M.ResourceCapacity(item)
 local def=M.Catalog[item.uniqueID]
 return def and def.capacity
end
