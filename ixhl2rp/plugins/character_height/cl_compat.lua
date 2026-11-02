local H = ix.CharacterHeight

function H.Preview(panel, entity)
 if not IsValid(entity) then return end
 local owner = entity.ProxyOwner
 local scale = IsValid(owner) and owner:GetModelScale() or H.Scale(panel.ixCharacterHeight or H.BASE)
 if not H.Supported(entity) then scale = 1 end
 if math.abs(entity:GetModelScale() - scale) > .00001 then entity:SetModelScale(scale, 0) end
end
