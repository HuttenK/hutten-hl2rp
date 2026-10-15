if (SERVER) then return end

local PLUGIN = PLUGIN

-- Restore the previous instance before a plugin reload takes ownership again.
if (PLUGIN.ClearHairLighting) then
	PLUGIN:ClearHairLighting()
end

local prefix = "models/sectorialdistrict/citizens/"
local hairMaterials = {
	"haircurly", "haircurly_black", "haircurly_white",
	"haircurly2", "haircurly2_black", "haircurly2_white",
	"haircurly3", "haircurly3_black", "haircurly3_white",
	"hairlong01", "hairlong01_black", "hairlong01_blonde", "hairlong01_red",
	"hairshaved", "hairshaved_black", "hairshaved_white", "hairshaved04",
	"hairshaved06", "hairshaved06_black",
	"hairshort01", "hairshort01_black", "hairshort01_blonde",
	"hairshort01_gray", "hairshort01_red", "hairshort01_white"
}
local repaired = {}
local enabled = true
local hookID = "ixSDHairLighting"

local function TextureName(texture)
	return texture and string.lower(texture:GetName()):gsub("\\", "/"):gsub("%.vtf$", "")
end

function PLUGIN:ApplyHairLighting()
	if (!enabled) then return end

	for _, name in ipairs(hairMaterials) do
		local material = Material(prefix..name)

		if (!material:IsError() and string.lower(material:GetShader()) == "vertexlitgeneric") then
			local texture = material:GetTexture("$lightwarptexture")
			local textureName = TextureName(texture)
			-- Keep deliberate third-party diffuse ramps. GMod returns an error
			-- texture, rather than nil, for an undefined texture parameter.
			if (!textureName or textureName == "error" or textureName == prefix.."lightwarp_hair") then
				local changes = repaired[material] or {}
				local changed = false
				if (textureName == prefix.."lightwarp_hair") then
					changes.warp = changes.warp or texture
					material:SetUndefined("$lightwarptexture")
					changed = true
				end
				-- Live comparison isolates the excessive sheen to the Phong pass.
				-- Keep the original colour, normals, detail and strand alpha.
				local phong = material:GetInt("$phong")
				if (phong and phong ~= 0) then
					changes.phong = changes.phong or phong
					material:SetInt("$phong", 0)
					changed = true
				end
				if (changed) then repaired[material] = changes; material:Recompute() end
			end
		end
	end
end

function PLUGIN:ClearHairLighting()
	enabled = false
	hook.Remove("InitPostEntity", hookID)
	hook.Remove("OnReloaded", hookID)
	hook.Remove("ShutDown", hookID)

	for material, changes in pairs(repaired) do
		-- Do not overwrite a different correction installed later by another addon.
		if (!material:IsError()) then
			local changed = false
			local name = TextureName(material:GetTexture("$lightwarptexture"))
			if (changes.warp and (!name or name == "error")) then
				material:SetTexture("$lightwarptexture", changes.warp)
				changed = true
			end
			if (changes.phong and material:GetInt("$phong") == 0) then
				material:SetInt("$phong", changes.phong)
				changed = true
			end
			if (changed) then material:Recompute() end
		end
	end

	repaired = {}
end

function PLUGIN:OnUnload()
	self:ClearHairLighting()
end

hook.Add("InitPostEntity", hookID, function()
	PLUGIN:ApplyHairLighting()
end)

hook.Add("OnReloaded", hookID, function()
	PLUGIN:ApplyHairLighting()
end)

hook.Add("ShutDown", hookID, function()
	PLUGIN:ClearHairLighting()
end)

-- Also covers loading the plugin after InitPostEntity has already fired.
timer.Simple(0, function()
	if (enabled) then
		PLUGIN:ApplyHairLighting()
	end
end)
