local PLUGIN = PLUGIN
PLUGIN.name = "Legends Interface"
PLUGIN.author = "Hutten"
PLUGIN.description = "Cinematic character selection and creation."
ix.util.Include("cl_menu.lua")
ix.util.Include("cl_anatomy.lua")
ix.util.Include("cl_gameplay.lua")

if SERVER then resource.AddFile("materials/legends/scp/terminal.jpg") end
