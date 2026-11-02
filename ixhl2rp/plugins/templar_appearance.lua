PLUGIN.name = "Templar appearance"
PLUGIN.description = "Persistent face and eyes across Templar outfits."

ix.Templar = ix.Templar or {}
local T = ix.Templar
T.models = {}
for _, name in ipairs({"archer_01", "archer_02", "archer_03", "archer_04", "archer_05", "archer_06", "knight_01", "knight_02"}) do
	T.models["models/players/templar_" .. name .. ".mdl"] = true
end

function T.Supported(model) return T.models[tostring(model):lower()] == true end

function T.Apply(entity, character)
	if not IsValid(entity) or not character or not T.Supported(entity:GetModel()) then return end
	-- The twelve faces are skin families, NOT the similarly named Eyes group.
	-- Other group indices differ between the archer and knight models.
	local skin = math.Clamp(character:GetSdSkin() or 0, 0, math.max(0, entity:SkinCount() - 1))
	local eyes = entity:FindBodygroupByName("Yeux/Eyes")
	if entity:GetSkin() ~= skin then entity:SetSkin(skin) end
	if eyes >= 0 then
		local value = math.Clamp(character:GetTemplarEyes() or 0, 0, 2)
		if entity:GetBodygroup(eyes) ~= value then entity:SetBodygroup(eyes, value) end
	end
end

ix.char.RegisterVar("templarEyes", {
	bNoDisplay = true,
	field = "templar_eyes", fieldType = ix.type.number, default = 0,
	Net = {Transmit = ix.transmit.all},
	OnValidate = function(self, value, payload, client)
		local faction = ix.faction.indices[payload.faction]
		local models = faction and faction:GetModels(client, payload.gender) or {}
		local model = models[payload.model]
		if istable(model) then model = model[1] end
		if not T.Supported(model) then return 0 end
		value = value or 0
		if not isnumber(value) or value ~= value or value % 1 ~= 0 or value < 0 or value > 2 then
			return false, "unknownError"
		end
		return value
	end
})

hook.Add("ApplyCharacterModelIdentity", "ixTemplarFace", T.Apply)
