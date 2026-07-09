local PLUGIN = PLUGIN

PLUGIN.name = "MPF Items"
PLUGIN.author = "SchwarzKruppzo"
PLUGIN.description = ""

-- Tag the metropolice uniform models with an Appearance modelClass so armor
-- items can expose a separate "mpf" bodygroup variant (their bodygroup layout
-- differs from citizen models). See items_clothing base clothes.lua OnRegistered.
if ix.Appearance then
	ix.Appearance:SetModelClass("models/autonomous/eurasia_nemanus/metropolice/male.mdl", "mpf")
	ix.Appearance:SetModelClass("models/autonomous/eurasia_nemanus/metropolice/female.mdl", "mpf")
	ix.Appearance:SetModelClass("models/autonomous/eurasia_nemanus/metropolice/male_rebel.mdl", "mpf")
	ix.Appearance:SetModelClass("models/autonomous/eurasia_nemanus/metropolice/female_rebel.mdl", "mpf")
end

if CLIENT then
	local MPF_MODELS = {
		["models/autonomous/eurasia_nemanus/metropolice/male.mdl"]         = true,
		["models/autonomous/eurasia_nemanus/metropolice/female.mdl"]       = true,
		["models/autonomous/eurasia_nemanus/metropolice/male_rebel.mdl"]   = true,
		["models/autonomous/eurasia_nemanus/metropolice/female_rebel.mdl"] = true,
	}

	-- Keywords iterated first so higher-priority entries win.
	local VISOR_KEYWORDS = { "trivisor_glow", "visor_glow", "lens_glow", "trivisor", "visor", "lens", "eye", "glass" }

	local matIndexCache   = {}   -- model -> { visor=N }
	local playerVisorData = {}   -- SteamID64 -> { mat, lastColor, index }

	-- One-shot debug: print all materials for the first MPF player seen.
	local debuggedModel = nil
	local function DebugMaterials(ply)
		local model = ply:GetModel()
		if debuggedModel == model then return end
		debuggedModel = model
		local mats = ply:GetMaterials()
		print("[MPF] Full material list for: " .. model)
		for i, m in ipairs(mats) do
			print(string.format("  mat[%d] %s", i - 1, m))
		end
	end

	local function GetMatIndices(ply)
		local model = ply:GetModel()
		if matIndexCache[model] then return matIndexCache[model] end
		local mats = ply:GetMaterials()
		local result = { visor = 1 }
		for _, kw in ipairs(VISOR_KEYWORDS) do
			for idx, path in ipairs(mats) do
				if string.find(string.lower(path), kw, 1, true) then
					result.visor = idx - 1
					goto visorFound
				end
			end
		end
		::visorFound::
		matIndexCache[model] = result
		return result
	end

	local function GetVisorData(ply)
		local id = ply:SteamID64()
		if not id then return nil end
		if not playerVisorData[id] then
			local idx  = GetMatIndices(ply).visor
			local mats = ply:GetMaterials()
			local base = mats and mats[idx + 1] or ""
			local mat  = CreateMaterial("mpf_visor_" .. id, "VertexLitGeneric", {
				["$basetexture"] = base,
				["$additive"]    = "1",
				["$color2"]      = "[1 1 1]",
				["$nolod"]       = "1",
			})
			playerVisorData[id] = { mat = mat, lastColor = Vector(-1,-1,-1), index = idx }
		end
		return playerVisorData[id]
	end

	hook.Add("EntityRemoved", "mpf.visor.cleanup", function(ent)
		if not ent:IsPlayer() then return end
		local id = ent:SteamID64()
		if id then
			playerVisorData[id] = nil
		end
	end)

	hook.Add("PrePlayerDraw", "mpf.visor.render", function(ply)
		if not MPF_MODELS[ply:GetModel()] then return end
		if ply:GetNWInt("sg_uniform", 0) == 0 then return end

		DebugMaterials(ply)

		local pColor = ply:GetPrimaryVisorColor()
		if pColor.x ~= 0 or pColor.y ~= 0 or pColor.z ~= 0 then
			local vd = GetVisorData(ply)
			if vd then
				if vd.lastColor ~= pColor then
					vd.mat:SetVector("$color2", pColor)
					vd.lastColor = Vector(pColor)
				end
				render.MaterialOverrideByIndex(vd.index, vd.mat)
			end
		end
	end)

	hook.Add("PostPlayerDraw", "mpf.visor.render", function(ply)
		if not MPF_MODELS[ply:GetModel()] then return end
		if ply:GetNWInt("sg_uniform", 0) == 0 then return end
		local idx = GetMatIndices(ply)
		render.MaterialOverrideByIndex(idx.visor, nil)
	end)
end

ix.Net:AddPlayerVar("PrimaryVisorColor", false, nil, ix.Net.Type.Vector)
ix.Net:AddPlayerVar("SecondaryVisorColor", false, nil, ix.Net.Type.Vector)

local playerMeta = FindMetaTable("Player")

function playerMeta:SetPrimaryVisorColor(color)
	self:SetNetVar("PrimaryVisorColor", color)
end

function playerMeta:GetPrimaryVisorColor()
	return self:GetNetVar("PrimaryVisorColor", Vector(0, 0, 0))
end

function playerMeta:SetSecondaryVisorColor(color)
	self:SetNetVar("SecondaryVisorColor", color)
end

function playerMeta:GetSecondaryVisorColor()
	return self:GetNetVar("SecondaryVisorColor", Vector(0, 0, 0))
end

if SERVER then
	-- Reset visual state immediately on character load.
	-- Items are not available yet here (inventories load asynchronously after this hook).
	function PLUGIN:PlayerLoadedCharacter(client, character, lastChar)
		client.ArmorItems = {}
		client:SetNWInt("sg_uniform", 0)
		client:SetNWInt("sg_armband", 0)
		client:SetPrimaryVisorColor(Vector(0, 0, 0))
		client:SetSecondaryVisorColor(Vector(0, 0, 0))
	end

	-- Restore MPF visual state once inventories have been loaded.
	-- CharacterLoaded fires before GM:CharacterLoaded (which calls CreateInventories).
	-- timer.Simple(0) defers one think — by then SQLite has finished loading items.
	function PLUGIN:CharacterLoaded(character)
		local client = character:GetPlayer()
		if not IsValid(client) then return end

		timer.Simple(0, function()
			if not IsValid(client) then return end
			if not client:GetCharacter() then return end

			client.ArmorItems = {}

			for _, item in pairs(client:GetItems()) do
				if item.Stats then
					client.ArmorItems[item] = true
				end
				if item.isMPF and item:IsEquipped() then
					local armband = item:GetData("armband", 0)
					client:SetNWInt("sg_uniform", item.uniform or 0)
					client:SetNWInt("sg_armband", armband)
					client:SetPrimaryVisorColor(item.primaryVisor or Vector(0, 0, 0))
					client:SetSecondaryVisorColor(item.secondaryVisor or Vector(0, 0, 0))
					client:SetSkin(item.uniform or 0)
					-- Обнуляем все дефолтные бодигруппы модели, затем накладываем
					-- только заданные формой (см. clothes_mpf.lua OnEquipped).
					for i = 0, client:GetNumBodyGroups() - 1 do
						client:SetBodygroup(i, 0)
					end
					if item.bodyGroups then
						for k, v in pairs(item.bodyGroups) do
							client:SetBodygroup(k, v)
						end
					end

					-- Держим модель метрополиции текущей для системы одежды и
					-- накладываем MPF-бодигруппы надетой брони (шлем/ноги).
					if client.char_outfit then
						client.char_outfit.model = client:GetModel()
					end
					for _, armor in pairs(client:GetItems()) do
						if armor.bodyGroupsMPF and armor:IsEquipped() then
							for k, v in pairs(armor.bodyGroupsMPF) do
								client:SetBodygroup(k, v)
							end
						end
					end
				end
			end
		end)
	end
end
