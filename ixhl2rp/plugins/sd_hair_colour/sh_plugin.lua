PLUGIN.name = "SD Hair Colour"
PLUGIN.author = "Hutten"
PLUGIN.description = "Independent, saved hair colours for Sectorial District characters."

ix.util.Include("sh_colour.lua")
ix.util.Include("sv_colour.lua")
ix.util.Include("cl_colour.lua")

function PLUGIN:OnUnload()
 if CLIENT and ix.SDHair.Clear then ix.SDHair.Clear() end
end
