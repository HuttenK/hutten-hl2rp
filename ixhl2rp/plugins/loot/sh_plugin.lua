local PLUGIN = PLUGIN

PLUGIN.name = "Loot System"
PLUGIN.author = "SchwarzKruppzo"
PLUGIN.description = "Adds a enhanced loot system."

ix.util.Include("sv_loot.class.lua")
ix.util.Include("sh_lootcontainer.class.lua")

-- Melee weapons that can ALSO pry/smash open a locked loot container, in
-- addition to each container's canonical Tool (the crowbar). Edit this set to
-- add or remove breaching tools; keys are item uniqueIDs.
ix.loot = ix.loot or {}
ix.loot.breachTools = {tool_hammer=true, tool_woodhammer=true}

ix.util.Include("sh_definitions.lua")
ix.util.Include("sv_hooks.lua")
