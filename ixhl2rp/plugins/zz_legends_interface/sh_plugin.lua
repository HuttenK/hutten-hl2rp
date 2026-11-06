local PLUGIN = PLUGIN
PLUGIN.name = "Medieval Interface"
PLUGIN.author = "Hutten"
PLUGIN.description = "Medieval character menus, inventory and HUD."
ix.util.Include("cl_menu.lua")
ix.util.Include("cl_anatomy.lua")
ix.util.Include("cl_gameplay.lua")

if SERVER then
 resource.AddFile("sound/medieval_ui/menu.mp3")
 for _,name in ipairs({"hall_v3","panel_v2","button_v2","slot_v2","slot_selected_v2","divider_v2"}) do
  resource.AddFile("materials/"..name..".png")
 end
end
