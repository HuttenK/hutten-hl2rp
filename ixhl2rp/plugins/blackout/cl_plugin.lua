local PLUGIN = PLUGIN

PLUGIN.zones    = PLUGIN.zones    or {} -- list of { min = Vector, max = Vector }
PLUGIN.darkness = PLUGIN.darkness or 0  -- current eased effect strength (0..1)

net.Receive("ixBlackoutSync", function()
	local count = net.ReadUInt(8)
	local zones = {}

	for i = 1, count do
		local mn = net.ReadVector()
		local mx = net.ReadVector()
		zones[i] = { min = mn, max = mx }
	end

	PLUGIN.zones = zones
end)

-- Uniform: 1 if the point is inside any zone, 0 otherwise. Inside is just "lights
-- out" everywhere; the from-outside mask handles the spatial look.
local function BlackoutFactor(pos)
	for _, z in ipairs(PLUGIN.zones) do
		if (pos:WithinAABox(z.min, z.max)) then
			return 1
		end
	end

	return 0
end

-- Ease the inside-darkness strength toward the target. Enter: snap to dark
-- instantly (no lighting "flash" at the boundary). Leave: ease back smoothly.
-- This is driven from the render hook below using the same EyePos() as the mask,
-- so the inside/outside decision is always consistent (no one-frame gap).
local function updateDarkness(eye)
	local target = BlackoutFactor(eye)

	if (target >= PLUGIN.darkness) then
		PLUGIN.darkness = target
	else
		PLUGIN.darkness = Lerp(FrameTime() * PLUGIN.fadeSpeed, PLUGIN.darkness, target)
	end
end

--
-- From-outside presence via a STENCIL VOLUME MASK. We mark the screen pixels
-- whose scene geometry lies inside a zone's box (z-fail stencil volume test),
-- then darken only those pixels. So looking THROUGH an opening you see the room's
-- real surfaces go dark; solid walls occlude the box geometry, so there's no
-- x-ray and no floating sheet. Depth-correct by construction.
--
-- Drawn in the OPAQUE pass: solid geometry (world + players + props + NPCs) is
-- darkened, but translucent effects (fire, particles, sprites, glows) render in
-- the later translucent pass and so stay fully lit -- no exception list needed.
--

local DRAW_DIST2 = PLUGIN.maskDrawDist * PLUGIN.maskDrawDist

-- Shortest distance (squared) from a point to an AABB; 0 if the point is inside.
local function distToBox2(pos, mn, mx)
	local cx = math.Clamp(pos.x, mn.x, mx.x)
	local cy = math.Clamp(pos.y, mn.y, mx.y)
	local cz = math.Clamp(pos.z, mn.z, mx.z)

	return pos:DistToSqr(Vector(cx, cy, cz))
end

local ANG0  = Angle(0, 0, 0)
local VZERO = Vector(0, 0, 0)

-- Mark one zone box into the stencil with a z-fail volume count. Two passes on
-- opposite face sets: INCR on z-fail for one, DECR for the other. A pixel ends
-- non-zero exactly when its scene geometry sits between the box's front and back
-- faces (i.e. inside the box). NOTEQUAL-0 later is winding-independent.
local function markZoneBox(mn, mx)
	local maxs = mx - mn

	render.SetStencilZFailOperation(STENCILOPERATION_INCR)
	render.CullMode(MATERIAL_CULLMODE_CW)
	render.DrawBox(mn, ANG0, VZERO, maxs, color_white)

	render.SetStencilZFailOperation(STENCILOPERATION_DECR)
	render.CullMode(MATERIAL_CULLMODE_CCW)
	render.DrawBox(mn, ANG0, VZERO, maxs, color_white)
end

local lastFrame = -1

hook.Add("PostDrawOpaqueRenderables", "ixBlackoutStencil", function(bDepth, bSkybox, bSkybox3D)
	if (bDepth or bSkybox or bSkybox3D) then return end
	if (#PLUGIN.zones == 0) then PLUGIN.darkness = 0 return end

	local eye = EyePos()

	-- Advance the eased darkness once per frame (this hook can fire several times
	-- per frame for reflections/RTs), using this same eye -> no boundary gap/flash.
	local fn = FrameNumber()
	if (fn ~= lastFrame) then
		lastFrame = fn
		updateDarkness(eye)
	end

	-- Inside view: if the eye is inside a zone, darken the whole frame here in the
	-- opaque pass (so translucent effects render over it and stay lit). Drawn before
	-- the mask so it still runs when the only zone is the one you're standing in.
	local d = PLUGIN.darkness
	if (d > 0.01) then
		local a = math.floor((d ^ PLUGIN.veilPower) * PLUGIN.veilAlpha)
		if (a > 0) then
			cam.Start2D()
				surface.SetDrawColor(0, 0, 0, a)
				surface.DrawRect(0, 0, ScrW(), ScrH())
			cam.End2D()
		end
	end

	-- Drawable zones: within range, and the eye is NOT inside (inside is handled by
	-- the veil just above, and z-fail is cleanest when the camera is outside).
	local list
	for _, z in ipairs(PLUGIN.zones) do
		local mn, mx = z.min, z.max
		if (distToBox2(eye, mn, mx) <= DRAW_DIST2 and not eye:WithinAABox(mn, mx)) then
			list = list or {}
			list[#list + 1] = z
		end
	end

	if (not list) then return end

	-- 1) Build the mask: stencil != 0 where scene geometry is inside a zone box.
	render.ClearStencil()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
	render.SetStencilFailOperation(STENCILOPERATION_KEEP)
	render.SetStencilPassOperation(STENCILOPERATION_KEEP)

	render.OverrideColorWriteEnable(true, false) -- mark only, write no colour
	render.OverrideDepthEnable(true, false)      -- keep depth TEST, write no depth
	render.SetColorMaterial()

	-- Grow the mask box a touch so walls sitting just outside the zone still darken.
	local pad  = PLUGIN.maskPadding
	local vpad = Vector(pad, pad, pad)

	for _, z in ipairs(list) do
		markZoneBox(z.min - vpad, z.max + vpad)
	end

	render.OverrideColorWriteEnable(false)
	render.OverrideDepthEnable(false)
	render.CullMode(MATERIAL_CULLMODE_CCW)

	-- 2) Darken the masked pixels (the real surfaces inside the zone).
	render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NOTEQUAL)
	render.SetStencilReferenceValue(0)
	render.SetStencilZFailOperation(STENCILOPERATION_KEEP)

	cam.Start2D()
		surface.SetDrawColor(0, 0, 0, PLUGIN.maskDarkness)
		surface.DrawRect(0, 0, ScrW(), ScrH())
	cam.End2D()

	render.SetStencilEnable(false)
end)
