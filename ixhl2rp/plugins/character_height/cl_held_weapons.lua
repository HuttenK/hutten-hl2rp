local H = ix.CharacterHeight
if H.ClearWeaponCallbacks then H.ClearWeaponCallbacks() end
local attached = {}

-- Stock weapons may inherit the scaled right-hand bone through bone merging.
-- ARC9/ArcCW assemble their own world models at an authored scale instead.
function H.FixedWeaponBones(weapon)
 local owner = weapon:GetOwner()
 if not IsValid(owner) or not owner:IsPlayer() or weapon.ARC9 or weapon.ArcCW then return end
 local scale = owner:GetModelScale()
 if math.abs(scale - 1) < .00001 then return end
 local handID = weapon:LookupBone("ValveBiped.Bip01_R_Hand")
 local hand = handID and weapon:GetBoneMatrix(handID)
 if not hand then return end
 local inherited = hand:GetScale()
 -- Don't touch a custom renderer that has already removed the body scale.
 if math.abs(inherited.x - scale) > .001 or math.abs(inherited.y - scale) > .001
  or math.abs(inherited.z - scale) > .001 then return end
 local inverse = hand:GetInverse()
 if not inverse then return end
 local normal = Matrix(hand)
 normal:SetScale(Vector(1, 1, 1))
 local transform = normal * inverse
 local matrices = {}
 for bone = 0, weapon:GetBoneCount() - 1 do
  local matrix = weapon:GetBoneMatrix(bone)
  if matrix then matrices[bone] = transform * matrix end
 end
 for bone, matrix in pairs(matrices) do weapon:SetBoneMatrix(bone, matrix) end
end

function H.ClearWeaponCallbacks()
 for weapon, id in pairs(attached) do
  if IsValid(weapon) then weapon:RemoveCallback("BuildBonePositions", id); weapon:InvalidateBoneCache() end
 end
 attached = {}
end

timer.Create("ixCharacterHeightWeapons", .25, 0, function()
 for _, owner in ipairs(player.GetAll()) do
  local weapon = owner:GetActiveWeapon()
  if IsValid(weapon) and not weapon.ARC9 and not weapon.ArcCW and not attached[weapon] then
   attached[weapon] = weapon:AddCallback("BuildBonePositions", H.FixedWeaponBones)
  end
 end
 for weapon in pairs(attached) do if not IsValid(weapon) then attached[weapon] = nil end end
end)
hook.Add("ShutDown", "ixCharacterHeightWeapons", H.ClearWeaponCallbacks)
