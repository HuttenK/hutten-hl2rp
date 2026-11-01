-- Local/listen-server console: lua_openscript ix_scp_compat_apply.lua
if CLIENT then print("[SCP compatibility] Use lua_openscript (without _cl).") return end
if not ix or not ix.SCPCompat or not ix.SCPCompat.Install then
    print("[SCP compatibility] Join the gamemode first.")
    return
end
local path = "gamemodes/ixhl2rp/plugins/scp_npc_compat/sv_control.lua"
local source = file.Read(path, "GAME")
if not source then print("[SCP compatibility] Missing " .. path) return end
local apply = CompileString(source, "@" .. path, false)
if not isfunction(apply) then print(apply) return end
local ok, err = xpcall(function()
    apply()
    ix.SCPCompat.Install()
end, debug.traceback)
if not ok then print("[SCP compatibility] Reload failed: " .. tostring(err)) return end
print("[SCP compatibility] Control fix applied. Try Control NPC again.")
