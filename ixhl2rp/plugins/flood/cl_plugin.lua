local PLUGIN = PLUGIN

PLUGIN.level = PLUGIN.level or {}

-- Уровни воды приходят с сервера.
netstream.Hook("flood.sync", function(levels)
	PLUGIN.level = istable(levels) and levels or {}
end)

-- ==== Материал поверхности ====
-- Refract-шейдер даёт «искажение» того, что под водой (нужен render.UpdateRefractTexture).
-- Если шейдер/нормаль недоступны — падаем на простую полупрозрачную заливку.
-- $bluramount — размытие преломления: выше = мутнее, ближе к настоящей воде.
local MAT_WATER = CreateMaterial("ixFloodWaterRefract", "Refract", {
	["$refractamount"] = "0.07",
	["$normalmap"]     = "effects/water_warp01", -- из HL2 VPK, резолвится в рантайме
	["$bluramount"]    = "4",
	["$translucent"]   = "1",
})

-- $vertexcolor обязателен, иначе цвет из DrawQuad не применяется и рисуется
-- белая текстура (вода выглядела «белой»). $vertexalpha — чтобы работала прозрачность.
local MAT_FLAT = CreateMaterial("ixFloodWaterFlat", "UnlitGeneric", {
	["$basetexture"] = "color/white",
	["$translucent"] = "1",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
})

-- Заметный сине-зелёный: теперь $vertexcolor работает, поэтому это синий (а не белый).
-- Альфа держим высокой, иначе вода почти прозрачная и кажется «невидимой».
local SURFACE_TINT = Color(33, 95, 120, 165)
local OVERSHOOT = 96 -- на сколько юнитов плоскость заходит за границы зоны (прячем край в стенах)
local LIGHT_FLOOR = 0.10 -- минимальная яркость: чтобы в полной темноте вода была тёмной, но не исчезала

-- Освещённость точки из карты освещения мира (0..1 на канал). Так вода темнеет
-- в тёмном коллекторе и светлеет под лампами, а не светится сама по себе.
local function SampledLight(pos)
	local c = render.GetLightColor(pos)
	return math.Clamp(c.x, LIGHT_FLOOR, 1), math.Clamp(c.y, LIGHT_FLOOR, 1), math.Clamp(c.z, LIGHT_FLOOR, 1)
end

-- Нарисовать одну плоскость воды (с обеих сторон, чтобы видеть и снизу).
local function DrawWaterPlane(mins, maxs, lvl)
	local x1, y1 = mins.x - OVERSHOOT, mins.y - OVERSHOOT
	local x2, y2 = maxs.x + OVERSHOOT, maxs.y + OVERSHOOT
	local z = lvl

	local a = Vector(x1, y1, z)
	local b = Vector(x2, y1, z)
	local c = Vector(x2, y2, z)
	local d = Vector(x1, y2, z)

	-- Освещённость поверхности (берём над центром зоны, чуть выше воды).
	local lr, lg, lb = SampledLight(Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, z + 4))

	-- Преломление: захватываем текущий кадр и рисуем искажающий материал.
	if (!MAT_WATER:IsError()) then
		-- «дыхание» искажения — поверхность кажется живой/движущейся
		MAT_WATER:SetFloat("$refractamount", 0.06 + math.sin(CurTime() * 1.7) * 0.035)

		render.UpdateRefractTexture()
		render.SetMaterial(MAT_WATER)
		render.DrawQuad(a, b, c, d)
		render.DrawQuad(d, c, b, a) -- обратная сторона (вид снизу)
	end

	-- Цветовой оттенок поверх, промодулированный освещением мира (тёмный в темноте).
	local tint = Color(SURFACE_TINT.r * lr, SURFACE_TINT.g * lg, SURFACE_TINT.b * lb, SURFACE_TINT.a)

	render.SetMaterial(MAT_FLAT)
	render.DrawQuad(a, b, c, d, tint)
	render.DrawQuad(d, c, b, a, tint)

	-- Френель-блик: под острым углом поверхность светлеет (отражение), как у воды.
	local center  = Vector((mins.x + maxs.x) * 0.5, (mins.y + maxs.y) * 0.5, z)
	local viewDir = center - EyePos()
	viewDir:Normalize()
	local fres = 1 - math.abs(viewDir.z)
	fres = fres * fres

	if (fres > 0.01) then
		local sheen = Color(120 * lr, 150 * lg, 185 * lb, fres * 140)
		render.SetMaterial(MAT_FLAT)
		render.DrawQuad(a, b, c, d, sheen)
		render.DrawQuad(d, c, b, a, sheen)
	end
end

function PLUGIN:PostDrawTranslucentRenderables(bDepth, bSkybox)
	if (bSkybox) then return end

	for name, area in pairs(ix.area.stored or {}) do
		if (area.type == "flood") then
			local lvl = self.level[name]
			local mins, maxs = self:GetAreaBounds(area)

			if (lvl and mins and lvl > mins.z) then
				DrawWaterPlane(mins, maxs, lvl)
			end
		end
	end
end

-- ==== Подводный пост-эффект (главный «продающий» слой) ====
local UNDERWATER_COLOR = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0.02,
	["$pp_colour_addb"] = 0.04,
	["$pp_colour_brightness"] = -0.03,
	["$pp_colour_contrast"] = 0.92,
	["$pp_colour_colour"] = 0.55,        -- к серому → приглушённые цвета
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0.12,
	["$pp_colour_mulb"] = 0.18,
}

local function IsEyeUnderwater()
	local eye = EyePos()
	local lvl = PLUGIN:WaterLevelAt(eye)
	return lvl and eye.z < lvl
end

function PLUGIN:RenderScreenspaceEffects()
	if (!IsEyeUnderwater()) then return end

	-- Лёгкое мерцание яркости — имитация бликов-каустик от поверхности.
	UNDERWATER_COLOR["$pp_colour_brightness"] = -0.04 + math.sin(CurTime() * 2.2) * 0.022
	DrawColorModify(UNDERWATER_COLOR)

	-- Мутная заливка, тоже промодулированная светом: под водой в темноте — темно.
	local lr, lg, lb = SampledLight(EyePos())
	surface.SetDrawColor(20 * lr, 75 * lg, 100 * lb, 170)
	surface.DrawRect(0, 0, ScrW(), ScrH())

	DrawMotionBlur(0.2, 0.7, 0.01)
end

-- ==== Звук/всплеск при погружении-выныривании ====
function PLUGIN:Think()
	local under = IsEyeUnderwater()

	if (under != self.wasUnderwater) then
		self.wasUnderwater = under

		local ply = LocalPlayer()
		if (IsValid(ply)) then
			ply:EmitSound(under and "ambient/water/water_spray1.wav" or "ambient/water/water_splash" .. math.random(1, 3) .. ".wav", 65)
		end
	end

	-- Пузырьки перед камерой под водой (несколько за тик — плотнее «вода»).
	if (under and (self.nextBubble or 0) < CurTime()) then
		self.nextBubble = CurTime() + 0.07

		local emitter = ParticleEmitter(EyePos())
		if (emitter) then
			for i = 1, 3 do
				local p = emitter:Add("effects/bubble", EyePos() + EyeAngles():Forward() * math.Rand(16, 40) + VectorRand() * 16)
				if (p) then
					p:SetVelocity(Vector(0, 0, math.Rand(20, 45)) + VectorRand() * 8)
					p:SetDieTime(math.Rand(0.8, 1.6))
					p:SetStartAlpha(150)
					p:SetEndAlpha(0)
					p:SetStartSize(math.Rand(1, 3))
					p:SetEndSize(math.Rand(3, 6))
					p:SetGravity(Vector(0, 0, 12))
					p:SetColor(200, 220, 230)
				end
			end
			emitter:Finish()
		end
	end
end
