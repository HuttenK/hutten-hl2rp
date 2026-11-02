PLUGIN.name = "Templar appearance"
PLUGIN.description = "Persistent face and eyes across Templar outfits."

ix.Templar = ix.Templar or {}
local T = ix.Templar
T.models = {}
T.families = {}
for _, name in ipairs({"archer_01", "archer_02", "archer_03", "archer_04", "archer_05", "archer_06", "knight_01", "knight_02"}) do
	T.models["models/players/templar_" .. name .. ".mdl"] = true
	T.families["models/players/templar_" .. name .. ".mdl"] = name:match("^(%a+)_")
end

function T.Supported(model) return T.models[tostring(model):lower()] == true end
function T.Family(model) return T.families[tostring(model):lower()] end

function T.Apply(entity, character)
	if not IsValid(entity) then return end
	local family = T.Family(entity:GetModel())
	local outfit = entity.char_outfit
	if character and family then
		-- The twelve faces are skin families, NOT the similarly named Eyes group.
		-- Other group indices differ between the archer and knight models.
		local skin = math.Clamp(character:GetSdSkin() or 0, 0, math.max(0, entity:SkinCount() - 1))
		local eyes = entity:FindBodygroupByName("Yeux/Eyes")
		if entity:GetSkin() ~= skin then entity:SetSkin(skin) end
		if eyes >= 0 then
			local value = math.Clamp(character:GetTemplarEyes() or 0, 0, 2)
			if entity:GetBodygroup(eyes) ~= value then entity:SetBodygroup(eyes, value) end
		end
		-- Full-model clothes skip ordinary layered bodygroups. Apply only the
		-- explicitly mapped Templar equipment after both model and face are set.
		for _, info in pairs(outfit and outfit.displayIds or {}) do
			local groups = info.templarBodyGroups and info.templarBodyGroups[family]
			for group, value in pairs(groups or {}) do
				if group < entity:GetNumBodyGroups() and value < entity:GetBodygroupCount(group) and entity:GetBodygroup(group) ~= value then
					entity:SetBodygroup(group, value)
				end
			end
		end
	end
	if SERVER and outfit then
		-- Admin model changes or removing a Templar uniform on a non-Templar
		-- character must not leave an invisible helmet granting protection.
		for item in pairs(outfit.armor or {}) do
			if item.templarHelmet then
				outfit.armor[item] = character ~= nil and item:IsProtectionActive(entity) or false
			end
		end
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
