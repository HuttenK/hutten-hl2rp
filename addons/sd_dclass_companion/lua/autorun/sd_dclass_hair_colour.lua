-- Compatibility for gamemode versions that copied Source's packed material
-- flags with GetFloat. Ship with the hair atlases so Workshop clients also get
-- their transparency, without overriding the character's chosen colour.
if SERVER then AddCSLuaFile(); return end

SDDClassHairColour = SDDClassHairColour or {}
local D = SDDClassHairColour
local mask = 256 + 8192 + 2097152 + 67108864 + 536870912

-- Avoid stacking wrappers when the addon itself is refreshed.
if ix and ix.SDHair and ix.SDHair.Material == D.wrapper then
 ix.SDHair.Material = D.original
end
D.wrapper, D.original = nil, nil

local function Install()
 local H = ix and ix.SDHair
 if not H or not isfunction(H.Material) or H.Material == D.wrapper then return end
 local original, repaired = H.Material, {}
 D.original = original
 D.wrapper = function(name, colour)
  local override = original(name, colour)
  if not isstring(override) or not override:match("^!ix_sd_hair_v%d+_") or repaired[override] then
   return override
  end
  local source, target = Material(name), Material(override:sub(2))
  if source:IsError() or target:IsError() then return override end
  local sourceFlags, targetFlags = source:GetInt("$flags"), target:GetInt("$flags")
  if sourceFlags == nil or targetFlags == nil then return override end
  local flags = bit.bor(bit.band(targetFlags, bit.bnot(mask)), bit.band(sourceFlags, mask))
  if flags ~= targetFlags then target:SetInt("$flags", flags) end
  repaired[override] = true
  return override
 end
 H.Material = D.wrapper
end

-- Autorun precedes the Helix plugin. Attach before drawing, and reattach only
-- if a later plugin reload replaces its material factory. No entity scans.
hook.Add("PreRender", "SDDClassHairColourFlags", Install)
Install()
