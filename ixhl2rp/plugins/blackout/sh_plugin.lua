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

-- Circuit box (fusebox) repair — players restore power by fixing a box in the zone.
PLUGIN.repairTime   = 30    -- seconds of hold-E repair
PLUGIN.repairSkill  = 3     -- required Electronics ("electric") skill level
PLUGIN.repairXP     = 40    -- Electronics XP awarded on a successful repair

-- Circuit box sabotage — trigger a blackout two ways:
--   • EMP tool  — instant, requires NO skill (fire the EMP device at the box);
--   • screwdriver (hold-E) — progress bar, requires Electronics skill breakSkill.
PLUGIN.breakTime    = 30    -- seconds of hold-E screwdriver sabotage (same bar as repair)
PLUGIN.breakSkill   = 4     -- required Electronics skill for the screwdriver sabotage
PLUGIN.breakXP      = 30    -- Electronics XP awarded on a successful screwdriver sabotage

-- Electric shock: if a character lacks the required Electronics skill and touches
-- a box (repair OR screwdriver sabotage), there's a chance the current knocks them out.
PLUGIN.shockChance   = 0.25 -- 0..1 chance of a shock on an under-skilled interaction
PLUGIN.shockDuration = 10   -- seconds the character is knocked out (ragdolled) by a shock

ix.util.Include("sv_plugin.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("cl_plugin.lua")
