local PLUGIN = PLUGIN
local arrowCounts = {aoc_itemarrow = 1, aoc_itemquiver = 10}
local weapons = {aoc_itemaxe = "aoc_axe_thrown", aoc_itemdagger = "aoc_dagger_thrown",
 aoc_itemdart = "aoc_dart_thrown", aoc_itemspear = "aoc_spear_thrown"}

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
 local class = entity:GetClass()
 local count, weapon = arrowCounts[class], weapons[class]
 if not count and not weapon then return end
 if entity.Touched or not client:GetCharacter() or not client:Alive() or client:IsRestricted() or
  client:InVehicle() or not client:GetInventory("main") then return false end
 entity.Touched = true
 -- The addon otherwise grants unbacked reserve ammo (and sometimes a free
 -- SWEP). Each pickup supplies either its arrows or one throwable.
 local success
 if weapon then success = ix.weaponInventory.GiveThrowable(client, weapon)
 else success = ix.weaponInventory.ReturnAmmo(client, "arrows", count) end
 if success then entity:Remove()
 else entity.Touched = false end
 return false
end
