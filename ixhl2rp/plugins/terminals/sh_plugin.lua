
PLUGIN.name = "Loyalist Terminals"
PLUGIN.author = "Zombine"
PLUGIN.description = "Adds loyalist terminals for players to view their loyalty points."

if (CLIENT) then
	PLUGIN.points = 0
end

if (SERVER) then
	util.AddNetworkString("ixTerminalResponse")
	util.AddNetworkString("ixTerminalRetrieveInfo")
	util.AddNetworkString("ixTerminalRequest")
end

ix.util.Include("thirdparty/cl_3d2dui.lua")
ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_hooks.lua")
