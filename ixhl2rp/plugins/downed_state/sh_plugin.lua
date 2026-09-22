PLUGIN.name = "Downed Experience"
PLUGIN.author = "Hutten"
PLUGIN.description = "Persistent rescue window and cinematic casualty interface."
ix.Downed = ix.Downed or {}
ix.Downed.HoldTime = 1.5
ix.Net:AddPlayerVar("downedSince", false, nil, ix.Net.Type.Float)
ix.config.Add("downedFinishDamage", 15, "Minimum direct combat damage to finish a downed character.", nil,
    {category = "Health", data = {min = 1, max = 100}})
ix.util.Include("sh_downed.lua")
ix.util.Include("sv_downed.lua")
ix.util.Include("cl_downed.lua")
