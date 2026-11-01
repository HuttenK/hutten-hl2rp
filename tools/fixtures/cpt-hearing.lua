hook.Add("EntityEmitSound","CPTBase_DetectEntitySounds",function(data)
	if GetConVarNumber("ai_disabled") == 1 then
		return nil -- Don't alter sound data, proceed
	end
	if GetConVarNumber("cpt_npchearing_advanced") == 0 then
		return nil -- Don't alter sound data, proceed
	end
	if !IsValid(data.Entity) then return nil end
	for _,v in pairs(ents.GetAll()) do
		if IsValid(v) && v:IsNPC() && v != data.Entity && v.CPTBase_NPC && v.UseAdvancedHearing then
			local ent = data.Entity
			local vol = data.SoundLevel
			local pos = data.Pos
			local dvol = data.Volume
			v:AdvancedHearingCode(ent,vol,pos,dvol)
		end
	end
	return nil
end)