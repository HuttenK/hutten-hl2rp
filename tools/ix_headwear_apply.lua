-- Client-only reload for the installed helmet flashlight fix.
if SERVER then return end
if not ix or not ix.CharacterHeight then print("[Headwear] Height plugin is not loaded."); return end
if ixHeadwearAudit and ixHeadwearAudit.Stop then ixHeadwearAudit.Stop() end
local path = "gamemodes/ixhl2rp/plugins/character_height/cl_headwear.lua"
local source = file.Read(path, "GAME")
if not source then print("[Headwear] Missing " .. path); return end
local run = CompileString(source, path, false)
if not isfunction(run) then ErrorNoHalt(tostring(run) .. "\n"); return end
local ok, err = xpcall(run, debug.traceback)
if not ok then ErrorNoHalt("[Headwear] " .. err .. "\n"); return end
for _, class in ipairs({"prop_ragdoll", "ix_cart_patient"}) do
 for _, entity in ipairs(ents.FindByClass(class)) do ix.CharacterHeight.WrapHeadwear(entity) end
end
print("[Headwear] Helmet flashlight fix applied. No restart needed.")
