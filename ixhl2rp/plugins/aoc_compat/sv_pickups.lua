local PLUGIN = PLUGIN
local pickups = {aoc_itemarrow = {"arrows", 1}, aoc_itemquiver = {"arrows", 10},
 aoc_itemaxe = {"axes", 1}, aoc_itemdagger = {"daggers", 1},
 aoc_itemdart = {"darts", 1}, aoc_itemspear = {"spears", 1}}

function PLUGIN:GetItemPhysicsBounds(entity, item)
 if not item or not item.isWeapon or not isstring(item.class) or
  not item.class:match("^aoc_") or
  not entity:GetModel():lower():match("^models/weapons/ageofchivalry/w_[^/]+%.mdl$") then return end
 -- AoC world meshes are offset from the hand origin; some original PHY files
 -- have a different checksum, and even valid blades are extremely thin.
 -- Only loose inventory items get this box, never held SWEPs or projectiles.
 local mins, maxs = entity:GetModelBounds()
 if not mins or not maxs then return end
 local low, high = Vector(mins.x, mins.y, mins.z), Vector(maxs.x, maxs.y, maxs.z)
 for _, axis in ipairs({"x", "y", "z"}) do
  local a, b = low[axis], high[axis]
  if a ~= a or b ~= b or a < -256 or b > 256 or b < a then return end
  local center, half = (a + b) * 0.5, math.max((b - a) * 0.5, 2)
  low[axis], high[axis] = center - half, center + half
 end
 if (maxs - mins):LengthSqr() == 0 then return end
 return low, high
end

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
