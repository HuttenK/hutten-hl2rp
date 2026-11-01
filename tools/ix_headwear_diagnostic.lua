-- Temporary client-only comparison. No damage, physics or inventory changes.
if SERVER then return end
print("[Headwear audit] Loaded. Close the console and keep the affected bodies in view for 4 seconds.")
if ixHeadwearAudit and ixHeadwearAudit.Stop then ixHeadwearAudit.Stop() end
local H = ix and ix.CharacterHeight
if not H or not H.BeginHeadwear then print("[Headwear audit] Height plugin is not loaded."); return end
local A = {original = H.BeginHeadwear, stage = 1, after = RealTime() + 2}
ixHeadwearAudit = A
local directory = "ix_headwear_audit/" .. os.date("%Y%m%d-%H%M%S")
file.CreateDir(directory)
local function matrix(m)
 if not m then return end
 return {position = m:GetTranslation(), angles = m:GetAngles(), scale = m:GetScale()}
end
local function inspect()
 local rows = {}
 for _, e in ipairs(ents.GetAll()) do
  if IsValid(e) and (e:IsPlayer() or e:GetClass() == "prop_ragdoll" or e:GetClass() == "ix_cart_patient")
   and e:GetPos():DistToSqr(LocalPlayer():GetPos()) < 1500^2 then
   local row = {class = e:GetClass(), id = e:EntIndex(), model = e:GetModel(), scale = e:GetModelScale(),
    skin = e:GetSkin(), position = e:GetPos(), angles = e:GetAngles(), groups = {}, materials = {}, bones = {}}
   for _, group in ipairs(e:GetBodyGroups()) do row.groups[tostring(group.id)] = e:GetBodygroup(group.id) end
   for index, name in ipairs(e:GetMaterials()) do
    row.materials[index] = {name = name, override = e:GetSubMaterial(index - 1), error = Material(name):IsError()}
   end
   for bone = 0, e:GetBoneCount() - 1 do
    row.bones[tostring(bone)] = {name = e:GetBoneName(bone), parent = e:GetBoneParent(bone), matrix = matrix(e:GetBoneMatrix(bone))}
   end
   rows[#rows + 1] = row
  end
 end
 return {entities = rows, map = game.GetMap(), view = render.GetViewSetup(false)}
end
function A.Stop()
 if H.BeginHeadwear == A.disabled then H.BeginHeadwear = A.original end
 hook.Remove("PostRender", "ixHeadwearAudit")
 timer.Remove("ixHeadwearAuditTimeout")
 if ixHeadwearAudit == A then ixHeadwearAudit = nil end
end
A.disabled = function() end
hook.Add("PostRender", "ixHeadwearAudit", function()
 if RealTime() < A.after or gui.IsGameUIVisible() or gui.IsConsoleVisible() then return end
 local target = render.GetRenderTarget()
 if target and not target:GetName():lower():find("_rt_fullframefb", 1, true) then return end
 local ok, err = xpcall(function()
  local name = A.stage == 1 and "current" or "native-headwear"
  local png = render.Capture({format = "png", x = 0, y = 0, w = ScrW(), h = ScrH(), alpha = false})
  if png then file.Write(directory .. "/" .. name .. ".png", png) end
  if A.stage == 1 then
   file.Write(directory .. "/state.json", util.TableToJSON(inspect(), true))
   H.ClearHeadwear()
   H.BeginHeadwear = A.disabled
   A.stage, A.after = 2, RealTime() + .3
  else
   A.Stop()
   print("[Headwear audit] Saved " .. directory .. "; original rendering restored.")
  end
 end, debug.traceback)
 if not ok then A.Stop(); ErrorNoHalt("[Headwear audit] " .. err .. "\n") end
end)
timer.Create("ixHeadwearAuditTimeout", 45, 1, function() A.Stop(); print("[Headwear audit] Timed out; original rendering restored.") end)
