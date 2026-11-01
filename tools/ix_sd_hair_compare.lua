if SERVER then return end
local id = "ixSDHairCompare"
if _G.ixSDHairCompareRestore then _G.ixSDHairCompareRestore() end
local names = {"haircurly", "haircurly_black", "haircurly_white", "haircurly2", "haircurly2_black", "haircurly2_white",
 "haircurly3", "haircurly3_black", "haircurly3_white", "hairlong01", "hairlong01_black", "hairlong01_blonde", "hairlong01_red",
 "hairshaved", "hairshaved_black", "hairshaved_white", "hairshaved04", "hairshaved06", "hairshaved06_black",
 "hairshort01", "hairshort01_black", "hairshort01_blonde", "hairshort01_gray", "hairshort01_red", "hairshort01_white"}
local original, report = {}, {materials = {}}
for _, name in ipairs(names) do
 local path = "models/sectorialdistrict/citizens/"..name
 local mat = Material(path)
 if not mat:IsError() then
  original[mat] = {phong = mat:GetInt("$phong"), detail = mat:GetFloat("$detailblendfactor")}
  report.materials[path] = {values = mat:GetKeyValues(), vmt = file.Read("materials/"..path..".vmt", "GAME")}
 end
end
local folder = "ix_sd_hair_audit/compare_"..os.date("%Y%m%d_%H%M%S")
file.CreateDir(folder)
file.Write(folder.."/materials.json", util.TableToJSON(report, true))
local function restore()
 timer.Remove(id)
 hook.Remove("PostRender", id)
 hook.Remove("ShutDown", id)
 for mat, values in pairs(original) do
  if not mat:IsError() then
   if values.phong then mat:SetInt("$phong", values.phong) else mat:SetUndefined("$phong") end
   if values.detail then mat:SetFloat("$detailblendfactor", values.detail) else mat:SetUndefined("$detailblendfactor") end
   mat:Recompute()
  end
 end
 _G.ixSDHairCompareRestore = nil
end
_G.ixSDHairCompareRestore = restore
hook.Add("ShutDown", id, restore)
local stages = {"current", "no_highlight", "no_detail", "neither"}
local stage, deadline = 1, RealTime() + 4
local function apply()
 for mat, values in pairs(original) do
  mat:SetInt("$phong", (stage == 2 or stage == 4) and 0 or values.phong or 0)
  mat:SetFloat("$detailblendfactor", (stage == 3 or stage == 4) and 0 or values.detail or 0)
  mat:Recompute()
 end
end
hook.Add("PostRender", id, function()
 if RealTime() < deadline then return end
 local ok, err = xpcall(function()
  local bytes = render.Capture({format = "jpeg", quality = 92, x = 0, y = 0, w = ScrW(), h = ScrH()})
  if not bytes then error("Unable to capture the game view") end
  file.Write(folder.."/"..stage.."_"..stages[stage]..".jpg", bytes)
  stage = stage + 1
  if stage > #stages then
   restore()
   print("[SD hair] Comparison saved to data/"..folder..". Original settings restored.")
  else
   apply()
   deadline = RealTime() + 3
  end
 end, debug.traceback)
 if not ok then restore(); print("[SD hair] Comparison failed: "..err) end
end)
timer.Create(id, 20, 1, restore)
print("[SD hair] Comparing four lighting settings. Close console and hold still for 14 seconds.")
