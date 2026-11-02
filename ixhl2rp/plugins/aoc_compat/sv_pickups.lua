local PLUGIN = PLUGIN
local pickups = {aoc_itemarrow = {"arrows", 1}, aoc_itemquiver = {"arrows", 10},
 aoc_itemaxe = {"axes", 1}, aoc_itemdagger = {"daggers", 1},
 aoc_itemdart = {"darts", 1}, aoc_itemspear = {"spears", 1}}

function PLUGIN:PlayerCanPickupItem(client, entity)
 local data = pickups[entity:GetClass()]
 if not data then return end
 if entity.Touched or not client:GetCharacter() or not client:Alive() or client:IsRestricted() or
  client:InVehicle() or not client:GetInventory("main") then return false end
 entity.Touched = true
 -- The addon otherwise grants unbacked reserve ammo (and sometimes a free
 -- SWEP). Recover real inventory stacks instead; full bags drop the stack.
 if ix.weaponInventory.ReturnAmmo(client, data[1], data[2]) then entity:Remove()
 else entity.Touched = false end
 return false
end
