if SERVER then return end
print("[SD hair] Reading client materials...")
local report = {time = os.date("%Y-%m-%d %H:%M:%S"), materials = {}, entities = {}}
local plugin = ix and ix.plugin and ix.plugin.list.sd_material_repair
report.fixLoaded = plugin and isfunction(plugin.ApplyHairLighting) or false
local prefix = "models/sectorialdistrict/citizens/"
local names = {"haircurly", "haircurly_black", "haircurly_white", "haircurly2", "haircurly2_black", "haircurly2_white",
 "haircurly3", "haircurly3_black", "haircurly3_white", "hairlong01", "hairlong01_black", "hairlong01_blonde", "hairlong01_red",
 "hairshaved", "hairshaved_black", "hairshaved_white", "hairshaved04", "hairshaved06", "hairshaved06_black",
 "hairshort01", "hairshort01_black", "hairshort01_blonde", "hairshort01_gray", "hairshort01_red", "hairshort01_white"}
local function Inspect(name)
 if report.materials[name] then return end
 local mat = Material(name)
 local result = {error = mat:IsError(), shader = mat:GetShader(), textures = {}, values = {}}
 for _, key in ipairs({"$basetexture", "$bumpmap", "$lightwarptexture", "$phongwarptexture", "$envmap", "$detail"}) do
  local texture = mat:GetTexture(key)
  result.textures[key] = texture and texture:GetName() or false
 end
 for _, key in ipairs({"$phong", "$phongboost", "$phongexponent", "$detailblendfactor", "$halflambert", "$selfillum", "$flags", "$flags2"}) do
  result.values[key] = mat:GetFloat(key) or false
 end
 for _, key in ipairs({"$color2", "$phongfresnelranges", "$phongtint"}) do
  local value = mat:GetVector(key)
  result.values[key] = value and tostring(value) or false
 end
 report.materials[name] = result
end
local ok, err = xpcall(function()
 for _, name in ipairs(names) do Inspect(prefix..name) end
 for _, ent in ipairs(ents.GetAll()) do
  if IsValid(ent) and string.find(string.lower(ent:GetModel() or ""), "models/sd/citizens/", 1, true) then
   local item = {index = ent:EntIndex(), model = ent:GetModel(), skin = ent:GetSkin(), materials = {}, submaterials = {}}
   for index, name in ipairs(ent:GetMaterials()) do
    if string.find(string.lower(name), "hair", 1, true) then
     item.materials[index] = name; Inspect(name)
     local override = ent:GetSubMaterial(index - 1)
     if override and override ~= "" then item.submaterials[index] = override; Inspect(string.gsub(override, "^!", "")) end
    end
   end
   report.entities[#report.entities + 1] = item
  end
 end
end, debug.traceback)
report.error = not ok and err or nil
file.CreateDir("ix_sd_hair_audit")
file.Write("ix_sd_hair_audit/latest.json", util.TableToJSON(report, true))
local loaded, original, noWarp = 0, 0, 0
for _, mat in pairs(report.materials) do
 if not mat.error then
  loaded = loaded + 1
  if not mat.textures["$lightwarptexture"] then noWarp = noWarp + 1
  elseif string.find(string.lower(mat.textures["$lightwarptexture"]), "lightwarp_hair", 1, true) then original = original + 1 end
 end
end
print("[SD hair] Fix loaded:", report.fixLoaded, "Materials:", loaded, "Original warp:", original, "No warp:", noWarp)
print("[SD hair] Saved data/ix_sd_hair_audit/latest.json")
if not ok then print("[SD hair] Error:", err) end
