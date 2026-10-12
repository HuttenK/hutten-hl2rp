PLUGIN.name = "Downed Experience"
PLUGIN.author = "Hutten"
PLUGIN.description = "Persistent rescue window and cinematic casualty interface."
ix.Downed = ix.Downed or {}
-- Mount the combined ix_crawl_animation_content addon on server AND clients.
-- The original Prone Workshop download lacks the Cellar bridge and can override it.
ix.Net:AddPlayerVar("downedSince", false, nil, ix.Net.Type.Float)
ix.Net:AddPlayerVar("criticalCrawlUntil", false, nil, ix.Net.Type.Float)
ix.util.Include("sh_downed.lua")
ix.util.Include("sh_crawl.lua")
ix.util.Include("sv_downed.lua")
ix.util.Include("cl_downed.lua")
