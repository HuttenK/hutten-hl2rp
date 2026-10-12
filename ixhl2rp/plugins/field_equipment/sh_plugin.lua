local PLUGIN = PLUGIN
PLUGIN.name = "Field equipment"
PLUGIN.author = "Hutten"
PLUGIN.description = "Plate carriers and inventory-controlled field equipment."
ix.field = ix.field or {}
ix.util.Include("sh_plates.lua")
ix.util.Include("sv_equipment.lua")
ix.util.Include("cl_equipment.lua")
