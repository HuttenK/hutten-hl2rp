if SERVER then return end
print("[SD colour] Checking mounted textures and current appearance...")
local report = {time=os.date("%Y-%m-%d %H:%M:%S"), assets={}, entities={}}
local H = ix and ix.SDHair
report.loaded = H and isfunction(H.Apply) or false
local count = 0
for _, family in ipairs({"haircurly", "haircurly2", "haircurly3", "hairlong01", "hairshaved", "hairshaved04", "hairshaved06", "hairshort01"}) do
 local present = file.Exists("materials/models/hutten/sd_hair/" .. family .. ".vtf", "GAME")
 report.assets[family] = present
 if present then count = count + 1 end
end
local ok, err = xpcall(function()
 if not report.loaded then return end
 for _, entity in ipairs(player.GetAll()) do
  if H.Supported(entity:GetModel()) then
   local character = entity:GetCharacter()
   local row = {index=entity:EntIndex(), model=entity:GetModel(), skin=entity:GetSkin(),
    localPlayer=entity==LocalPlayer(), saved=H.Saved(character), network=entity:GetNetVar("sdHairColor"), slots={}}
   H.Update(entity)
   for index, name in ipairs(entity:GetMaterials()) do
    if string.find(string.lower(name), "hair", 1, true) then
     local override = entity:GetSubMaterial(index-1)
     local original = Material(name)
     local slot = {index=index-1, source=name, override=override, sourceFlags=original:GetInt("$flags")}
     if override and override ~= "" then
      local material = Material(override:gsub("^!", ""))
      local texture = material:GetTexture("$basetexture")
      slot.error, slot.shader = material:IsError(), material:GetShader()
      slot.texture = texture and texture:GetName() or false
      slot.colour = tostring(material:GetVector("$color2"))
      slot.phong = material:GetInt("$phong")
      slot.flags = material:GetInt("$flags")
      slot.alphaTest = bit.band(slot.flags or 0, 256) ~= 0
      slot.noCull = bit.band(slot.flags or 0, 8192) ~= 0
      slot.alphaReference = material:GetFloat("$alphatestreference")
     end
     row.slots[#row.slots+1] = slot
    end
   end
   report.entities[#report.entities+1] = row
   print("[SD colour] Character:", character and character:GetName() or "unavailable", "Saved:", row.saved, "Network:", row.network)
  end
 end
end, debug.traceback)
report.error = not ok and err or nil
file.CreateDir("ix_sd_hair_audit")
file.Write("ix_sd_hair_audit/colour.json", util.TableToJSON(report, true))
print("[SD colour] Loaded:", report.loaded, "Mounted textures:", count .. "/8")
print("[SD colour] Saved data/ix_sd_hair_audit/colour.json")
if not ok then print("[SD colour] Error:", err) end
