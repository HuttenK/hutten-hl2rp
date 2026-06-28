local PLUGIN = PLUGIN

PLUGIN.name        = "Local Blackout"
PLUGIN.author      = "Hutten"
PLUGIN.description = "Admin-defined box zones that kill switchable map lights and darken the screen of players inside them."

-- Tweakables (client darkening strength).
PLUGIN.fadeSpeed   = 3      -- how fast the screen clears as you leave (higher = snappier)
PLUGIN.veilPower   = 2.2    -- shapes the fade-out curve as you leave the zone
PLUGIN.veilAlpha   = 240    -- max inside darkness (255 = pure black; lower = brighter)

-- From-outside view: a stencil volume mask darkens the REAL interior surfaces of
-- the zone (visible through openings, occluded by solid walls -- no x-ray).
PLUGIN.maskDarkness = 245   -- 0..255 darkness applied to surfaces inside the zone (255 = pure black)
PLUGIN.maskDrawDist = 6000  -- past this distance from a zone, skip its mask
PLUGIN.maskPadding  = 8     -- units the mask box is grown by, so bordering walls darken too

ix.util.Include("sv_plugin.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("cl_plugin.lua")
