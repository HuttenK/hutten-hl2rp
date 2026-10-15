local H = ix.CharacterHeight

function H.Preview(panel, entity)
 if not IsValid(entity) then return end
 local owner = entity.ProxyOwner
 local scale = IsValid(owner) and owner:GetModelScale() or H.Scale(panel.ixCharacterHeight or H.BASE)
 if not H.Supported(entity) then scale = 1 end
 if math.abs(entity:GetModelScale() - scale) > .00001 then entity:SetModelScale(scale, 0) end
end

-- ARC9 keeps one arm-length cache per model, although height changes the
-- distance between the bones. Use its existing wrapper, not another DoTPIK
-- detour; the SD animation adapter and body-drag repair retain their order.
hook.Add("ixARC9PreArmPose", "ixCharacterHeight", function(weapon, owner)
 if not IsValid(owner) or not owner:IsPlayer() then return end
 local scale, path = owner:GetModelScale(), owner:GetModel()
 local key = path .. ":" .. tostring(scale)
 if weapon.ixHeightArmKey == key then return end
 local forearm = owner:LookupBone("ValveBiped.Bip01_L_Forearm")
 local upper = owner:LookupBone("ValveBiped.Bip01_L_UpperArm")
 local a, b = forearm and owner:GetBoneMatrix(forearm), upper and owner:GetBoneMatrix(upper)
 if not a or not b then return end
 local length = a:GetTranslation():Distance(b:GetTranslation())
 if length <= 0 then return end
 weapon.ixHeightArmKey = key
 weapon.TPIKBoneLengthCache = {model = path, forearmIndex = forearm, length = length}
 weapon.TPIKCache = {}
 weapon.LastTPIKTime = 0
end)
