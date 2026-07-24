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

-- Ease the inside-darkness strength toward the target, in both directions.
-- math.Approach даёт ПОСТОЯННУЮ скорость, поэтому переход длится предсказуемое
-- время (1 / speed секунд) и не «залипает» на хвосте, как это делает Lerp.
-- This is driven from the render hook below using the same EyePos() as the mask,
-- so the inside/outside decision is always consistent (no one-frame gap).
local function updateDarkness(eye)
	local target = BlackoutFactor(eye)
	local speed = (target > PLUGIN.darkness) and PLUGIN.fadeInSpeed or PLUGIN.fadeOutSpeed

	PLUGIN.darkness = math.Approach(PLUGIN.darkness, target, FrameTime() * speed)
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
	--
	-- Маска красит ЛЮБУЮ геометрию, попавшую внутрь коробки — включая наружную
	-- грань стены, если коробка её пересекает. Снаружи это читается как чёрный
	-- прямоугольник, налепленный на стену. Поэтому силу маски привязываем к
	-- РАССТОЯНИЮ ДО ГРАНИЦЫ зоны, а не до наблюдателя:
	--   • внутри зоны (dist = 0) — полная сила (но её и так перекрывает veil);
	--   • сразу за границей — начинает гаснуть;
	--   • дальше maskFadeDist от границы — маски нет вовсе.
	-- Так издалека прямоугольник не виден, а на подходе к зоне темнота плавно
	-- проявляется. Вблизи снаружи он всё ещё есть — иначе на самой границе был бы
	-- резкий скачок при входе.
	local fade = math.max(PLUGIN.maskFadeDist, 1)

	local list
	for _, z in ipairs(PLUGIN.zones) do
		local mn, mx = z.min, z.max

		if (eye:WithinAABox(mn, mx)) then continue end

		-- Расстояние от глаза до ближайшей грани коробки (0 = внутри).
		local dist = math.sqrt(distToBox2(eye, mn, mx))
		if (dist > fade) then continue end

		local strength = 1 - math.Clamp(dist / fade, 0, 1)
		local alpha = math.floor(PLUGIN.maskDarkness * strength)

		if (alpha > 0) then
			list = list or {}
			list[#list + 1] = {zone = z, alpha = alpha}
		end
	end

	if (not list) then return end

	-- Grow the mask box a touch so walls sitting just outside the zone still darken.
	local pad  = PLUGIN.maskPadding
	local vpad = Vector(pad, pad, pad)

	local layers = math.max(PLUGIN.maskLayers, 1)
	local col    = PLUGIN.maskColor

	render.SetStencilEnable(true)
	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilFailOperation(STENCILOPERATION_KEEP)
	render.SetStencilPassOperation(STENCILOPERATION_KEEP)

	-- Каждую зону рисуем отдельным набором проходов: у них разная дистанция, а
	-- значит и разная сила затемнения, которую не выразить одной общей маской.
	for _, entry in ipairs(list) do
		local z = entry.zone
		local mn, mx = z.min - vpad, z.max + vpad

		-- Сколько можно сузить коробку, не схлопнув её. По вертикали двигаем только
		-- верхнюю грань, поэтому запас там — вся высота, а не половина.
		local size = mx - mn
		local softness = math.Clamp(PLUGIN.maskSoftness, 0, math.max(math.min(size.x, size.y) * 0.5 - 1, 0))
		local softnessTop = math.Clamp(PLUGIN.maskSoftnessTop, 0, math.max(size.z - 1, 0))

		-- Альфа одного слоя: столько, чтобы `layers` слоёв, наложенных друг на
		-- друга, дали ровно entry.alpha. Обычное альфа-смешение перемножает
		-- «пропускание» (1 - a), отсюда корень степени layers.
		local layerAlpha = 255 * (1 - (1 - entry.alpha / 255) ^ (1 / layers))

		for layer = 1, layers do
			-- Слой 1 — полная коробка, дальше сужаем внутрь. Пиксель у самого края
			-- попадает в один слой, в глубине зоны — во все. Пол (min.z) неподвижен.
			local frac = (layers > 1) and ((layer - 1) / (layers - 1)) or 0
			local inset = softness * frac
			local minInset = Vector(inset, inset, 0)
			local maxInset = Vector(inset, inset, softnessTop * frac)

			-- 1) Mask: stencil != 0 where scene geometry is inside this shell.
			render.ClearStencil()
			render.SetStencilReferenceValue(0)
			render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)

			render.OverrideColorWriteEnable(true, false) -- mark only, write no colour
			render.OverrideDepthEnable(true, false)      -- keep depth TEST, write no depth
			render.SetColorMaterial()

			markZoneBox(mn + minInset, mx - maxInset)

			render.OverrideColorWriteEnable(false)
			render.OverrideDepthEnable(false)
			render.CullMode(MATERIAL_CULLMODE_CCW)

			-- 2) Darken the masked pixels (the real surfaces inside the shell).
			render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_NOTEQUAL)
			render.SetStencilReferenceValue(0)
			render.SetStencilZFailOperation(STENCILOPERATION_KEEP)

			cam.Start2D()
				surface.SetDrawColor(col.r, col.g, col.b, layerAlpha)
				surface.DrawRect(0, 0, ScrW(), ScrH())
			cam.End2D()
		end
	end

	render.SetStencilEnable(false)
end)

-- Обесточенное оборудование не открывает своё меню. Сервер всё равно отклонит
-- взаимодействие в PlayerUse, но без этого игрок увидел бы меню на долю секунды.
function PLUGIN:ShowEntityMenu(entity)
	if (self:IsEntityBlackedOut(entity)) then
		return true -- «меню показано» — Helix не открывает своё
	end
end
