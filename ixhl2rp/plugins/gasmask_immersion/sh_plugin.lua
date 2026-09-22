PLUGIN.name = "Equipment Gas Mask Integration"
PLUGIN.author = "Hutten"
PLUGIN.description = "Rebirth gas mask presentation driven by equipped Helix items."

-- Existing, unmodified Workshop dependency. This distributes client content;
-- the addon must still be mounted on the server in the usual way.
if SERVER then resource.AddWorkshop("3337361530") end

ix.util.Include("sh_mask.lua")
ix.util.Include("cl_animation.lua")
ix.util.Include("cl_mask.lua")
