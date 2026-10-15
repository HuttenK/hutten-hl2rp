-- Run in the server console: lua_openscript ix_map_keycards_commands_apply.lua
if not SERVER then
    print("[Map keycards] Run lua_openscript without _cl on the server.")
    return
end
if not ix or not ix.plugin or not ix.plugin.list.map_keycards then
    print("[Map keycards] Plugin is not loaded. Restart the map to load it first.")
    return
end

local path = "gamemodes/ixhl2rp/plugins/map_keycards/sh_commands.lua"
local source = file.Read(path, "GAME")
if not source or source == "" then
    error("[Map keycards] Cannot read " .. path)
end

-- Reload registration only; keep the existing map bindings and saved rules.
local code = string.format([[
if not ix or not ix.command then
    print("[Map keycards] Helix commands are not ready.")
    return
end
local callback = CompileString(%q, "@" .. %q, false)
if not isfunction(callback) then error(callback) end
callback()
for _, name in ipairs({"mapdooraccess", "mapdooraccessremove", "mapdooraccessinfo", "mapdooraccesstest"}) do
    if not ix.command.list[name] then
        error("[Map keycards] Command failed to register: " .. name)
    end
end
print("[Map keycards] " .. (SERVER and "Server" or "Client") .. ": all 4 commands registered.")
]], source, path)

local callback = CompileString(code, "@ix_map_keycards_commands_apply", false)
if not isfunction(callback) then error(callback) end
callback()
BroadcastLua(code)
print("[Map keycards] Command refresh sent to connected clients. Close and reopen chat.")
