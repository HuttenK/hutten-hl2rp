local PLUGIN = PLUGIN

-- сглаженная «сила» эффекта 0..1
local toxic = 0

-- материалы краевой виньетки (стандартные градиенты GMod)
local gradLeft = Material("vgui/gradient-l")
local gradRight = Material("vgui/gradient-r")
local gradUp = Material("vgui/gradient-u")
local gradDown = Material("vgui/gradient-d")

-- Определяем принадлежность к зоне локально, по границам зон, которые сервер
-- уже синхронизировал в ix.area.stored (через ixAreaSync/ixAreaAdd). Это надёжнее
-- и мгновеннее, чем ждать сетевую переменную с серверного тика (раз в секунду),
-- которая и была причиной «эффект не появляется».
local nextZoneCheck = 0
local cachedInZone = false

local function isInZone()
	local client = LocalPlayer()

	if (!IsValid(client) or !client:Alive()) then
		cachedInZone = false
		return false
	end

	-- пересчитываем ~5 раз в секунду, а не каждый кадр
	if (CurTime() >= nextZoneCheck) then
		nextZoneCheck = CurTime() + 0.2
		cachedInZone = false

		local pos = client:GetPos() + client:OBBCenter()

		for _, area in pairs(ix.area.stored or {}) do
			if (area.type == "infection" and area.startPosition and area.endPosition
				and pos:WithinAABox(area.startPosition, area.endPosition)) then
				cachedInZone = true
				break
			end
		end
	end

	return cachedInZone
end

-- Ядовитый цветовой сдвиг экрана.
hook.Add("RenderScreenspaceEffects", "ixInfectionToxic", function()
	local target = isInZone() and 1 or 0
	toxic = Lerp(FrameTime() * 2.5, toxic, target)

	if (toxic <= 0.01) then return end

	DrawColorModify({
		["$pp_colour_addr"] = 0.12 * toxic,
		["$pp_colour_addg"] = 0.10 * toxic,
		["$pp_colour_addb"] = -0.06 * toxic, -- убираем синий канал → картинка желтеет
		["$pp_colour_brightness"] = -0.02 * toxic,
		["$pp_colour_contrast"] = 1 + (-0.10 * toxic),
		["$pp_colour_colour"] = 1 + (-0.55 * toxic), -- сильная десатурация (болезненный вид)
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0,
	})
end)

-- Жёлто-зелёный смог поверх экрана + пульсация + краевая виньетка.
hook.Add("HUDPaintBackground", "ixInfectionToxicHaze", function()
	if (toxic <= 0.01) then return end

	local w, h = ScrW(), ScrH()
	local pulse = 0.5 + 0.5 * math.sin(CurTime() * 1.5)

	-- общий ядовито-жёлтый налёт (заметно плотнее, чем раньше)
	surface.SetDrawColor(180, 200, 40, (55 + pulse * 30) * toxic)
	surface.DrawRect(0, 0, w, h)

	-- виньетка по краям — более густой смог
	local edge = (90 + pulse * 30) * toxic
	local thickness = math.min(w, h) * 0.28

	surface.SetDrawColor(120, 140, 20, edge)

	surface.SetMaterial(gradLeft)
	surface.DrawTexturedRect(0, 0, thickness, h)

	surface.SetMaterial(gradRight)
	surface.DrawTexturedRect(w - thickness, 0, thickness, h)

	surface.SetMaterial(gradUp)
	surface.DrawTexturedRect(0, 0, w, thickness)

	surface.SetMaterial(gradDown)
	surface.DrawTexturedRect(0, h - thickness, w, thickness)
end)

-- Жёлтый дым, клубящийся вокруг игрока, пока он находится в зоне заражения.
local smokeEmitter
local nextSmoke = 0

hook.Add("Think", "ixInfectionToxicSmoke", function()
	if (!isInZone()) then
		-- вышли из зоны (или умерли) — гасим эмиттер, чтобы не течь
		if (smokeEmitter) then
			smokeEmitter:Finish()
			smokeEmitter = nil
		end

		return
	end

	local client = LocalPlayer()
	local origin = client:GetPos()

	if (!smokeEmitter) then
		smokeEmitter = ParticleEmitter(origin)
	end

	-- держим эмиттер у игрока, чтобы частицы корректно отсекались по дальности
	smokeEmitter:SetPos(origin)

	if (CurTime() < nextSmoke) then return end
	nextSmoke = CurTime() + 0.12

	-- появляемся в случайной точке вокруг игрока, в пределах его роста
	local pos = origin + Vector(math.Rand(-45, 45), math.Rand(-45, 45), math.Rand(-5, 65))

	local particle = smokeEmitter:Add(string.format("particle/smokesprites_%04d", math.random(1, 9)), pos)
	if (!particle) then return end

	particle:SetVelocity(VectorRand() * 6 + Vector(0, 0, 4))
	particle:SetDieTime(math.Rand(1.6, 2.6))
	particle:SetStartAlpha(math.random(45, 75))
	particle:SetEndAlpha(0)
	particle:SetStartSize(math.random(16, 30))
	particle:SetEndSize(math.random(55, 85))
	particle:SetRoll(math.Rand(0, 360))
	particle:SetRollDelta(math.Rand(-0.8, 0.8))
	particle:SetColor(195, 205, 60) -- ядовито-жёлтый
	particle:SetAirResistance(70)
	particle:SetGravity(Vector(0, 0, 6))
	particle:SetCollide(false)
end)

--
-- Делаем зону ВИДИМОЙ снаружи, а не только как экранный фильтр для тех, кто внутри.
-- Две составляющие:
--   1) полупрозрачный жёлто-зелёный объём по коробке зоны (PostDrawTranslucentRenderables)
--   2) жёлтая дымовая стена по вертикальным стенкам зоны (видна издалека и снаружи)
-- Границы зон уже есть на клиенте — сервер синхронизирует их в ix.area.stored.
--

local EDGE_DIST2 = 4000 * 4000 -- дальше этого (в квадрате) дымовую стену зоны не строим

local function eachInfectionZone(fn)
	for _, area in pairs(ix.area.stored or {}) do
		if (area.type == "infection" and area.startPosition and area.endPosition) then
			fn(area.startPosition, area.endPosition)
		end
	end
end

-- Кратчайшее расстояние (в квадрате) от точки до AABB; 0, если точка внутри.
local function distToBox2(pos, mn, mx)
	local cx = math.Clamp(pos.x, mn.x, mx.x)
	local cy = math.Clamp(pos.y, mn.y, mx.y)
	local cz = math.Clamp(pos.z, mn.z, mx.z)

	return pos:DistToSqr(Vector(cx, cy, cz))
end

-- Случайная точка на одной из четырёх вертикальных стенок коробки, со смещением
-- вниз — дым словно скапливается у земли и поднимается вверх.
local function wallPoint(mn, mx)
	local r = math.random(4)
	local x, y

	if (r == 1) then x, y = mn.x, math.Rand(mn.y, mx.y)
	elseif (r == 2) then x, y = mx.x, math.Rand(mn.y, mx.y)
	elseif (r == 3) then x, y = math.Rand(mn.x, mx.x), mn.y
	else x, y = math.Rand(mn.x, mx.x), mx.y end

	local z = mn.z + math.Rand(0, (mx.z - mn.z) * 0.55)

	return Vector(x, y, z)
end

-- Никаких плоских mesh-«стен» больше нет: жёсткие полупрозрачные жёлтые листы
-- по периметру читались именно как стенки и не растворялись. Снаружи зону теперь
-- обозначает только органический дым по периметру (ниже), который реально тает.

-- Жёлтая дымовая стена по периметру зоны.
local edgeEmitter
local edgeNext = 0

hook.Add("Think", "ixInfectionPerimeterSmoke", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		if (edgeEmitter) then edgeEmitter:Finish() edgeEmitter = nil end
		return
	end

	if (CurTime() < edgeNext) then return end
	edgeNext = CurTime() + 0.08

	local eye = client:EyePos()

	-- собираем зоны в пределах дальности
	local near = {}

	eachInfectionZone(function(mn, mx)
		if (distToBox2(eye, mn, mx) <= EDGE_DIST2) then
			near[#near + 1] = {mn, mx}
		end
	end)

	if (#near == 0) then
		if (edgeEmitter) then edgeEmitter:Finish() edgeEmitter = nil end
		return
	end

	if (!edgeEmitter) then edgeEmitter = ParticleEmitter(eye, false) end
	edgeEmitter:SetPos(eye)

	for _, z in ipairs(near) do
		for i = 1, 2 do
			local p = edgeEmitter:Add(string.format("particle/smokesprites_%04d", math.random(1, 9)), wallPoint(z[1], z[2]))
			if (!p) then continue end

			p:SetVelocity(Vector(math.Rand(-4, 4), math.Rand(-4, 4), math.Rand(6, 16)))
			p:SetDieTime(math.Rand(2.2, 3.6))
			p:SetStartAlpha(math.random(35, 60))
			p:SetEndAlpha(0)
			p:SetStartSize(math.random(35, 60))
			p:SetEndSize(math.random(100, 150))
			p:SetRoll(math.Rand(0, 360))
			p:SetRollDelta(math.Rand(-0.5, 0.5))
			p:SetColor(195, 205, 60) -- ядовито-жёлтый
			p:SetAirResistance(70)
			p:SetGravity(Vector(0, 0, 5))
			p:SetCollide(false)
		end
	end
end)

--
-- Отравление токсичным газом — только у незащищённых. Сервер синхронизирует
-- уровень 0..1 в ixToxicLevel. Усиливающиеся экранные эффекты: болезненный
-- зелёный сдвиг, потеря резкости (motion blur) и тёмная виньетка к краям
-- («туннельное зрение» к потере сознания). Урона по HP нет.
--
local poison = 0 -- сглаженный уровень для плавности

local function ToxicLevel()
	local client = LocalPlayer()
	if (!IsValid(client)) then return 0 end

	return client:GetNWFloat("ixToxicLevel", 0)
end

hook.Add("RenderScreenspaceEffects", "ixInfectionPoison", function()
	poison = Lerp(FrameTime() * 3, poison, ToxicLevel())
	if (poison <= 0.01) then return end

	local p = poison

	DrawColorModify({
		["$pp_colour_addr"] = -0.02 * p,
		["$pp_colour_addg"] =  0.05 * p,
		["$pp_colour_addb"] = -0.03 * p,
		["$pp_colour_brightness"] = -0.04 * p,
		["$pp_colour_contrast"]   = 1 - 0.10 * p,
		["$pp_colour_colour"]     = 1 - 0.55 * p,
		["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
	})

	-- дезориентация: «смазывание» картинки, растёт с уровнем отравления
	DrawMotionBlur(0.45 * p, 0.75 * p, 0.012)
end)

-- Вспышка ядовито-зелёного газового облака в точке (распаковка отходов).
net.Receive("ixInfectionGasBurst", function()
	local pos = net.ReadVector()
	local emitter = ParticleEmitter(pos, false)

	if (!emitter) then return end

	for i = 1, 45 do
		local off = VectorRand() * math.Rand(0, 55)
		off.z = math.abs(off.z) * 0.6

		local p = emitter:Add(string.format("particle/smokesprites_%04d", math.random(1, 9)), pos + off)
		if (!p) then continue end

		p:SetVelocity(VectorRand() * 18 + Vector(0, 0, 26))
		p:SetDieTime(math.Rand(2.5, 4.5))
		p:SetStartAlpha(math.random(60, 110))
		p:SetEndAlpha(0)
		p:SetStartSize(math.random(30, 55))
		p:SetEndSize(math.random(95, 150))
		p:SetRoll(math.Rand(0, 360))
		p:SetRollDelta(math.Rand(-0.4, 0.4))
		p:SetColor(150, 200, 60) -- ядовито-зелёный газ
		p:SetAirResistance(80)
		p:SetGravity(Vector(0, 0, 8))
		p:SetCollide(false)
	end

	emitter:Finish()
end)

hook.Add("HUDPaintBackground", "ixInfectionPoisonVignette", function()
	if (poison <= 0.2) then return end

	local a = math.Clamp((poison - 0.2) / 0.8, 0, 1) * 235
	local w, h = ScrW(), ScrH()
	local thick = math.min(w, h) * 0.42

	surface.SetDrawColor(8, 22, 8, a)

	surface.SetMaterial(gradLeft)
	surface.DrawTexturedRect(0, 0, thick, h)
	surface.SetMaterial(gradRight)
	surface.DrawTexturedRect(w - thick, 0, thick, h)
	surface.SetMaterial(gradUp)
	surface.DrawTexturedRect(0, 0, w, thick)
	surface.SetMaterial(gradDown)
	surface.DrawTexturedRect(0, h - thick, w, thick)
end)

-- Постоянный жёлтый дым у распакованных пропов отходов (помечены NWBool на сервере).
local wasteEmitter
local wasteNext = 0

hook.Add("Think", "ixInfectionWasteSmoke", function()
	local client = LocalPlayer()

	if (!IsValid(client)) then
		if (wasteEmitter) then wasteEmitter:Finish() wasteEmitter = nil end
		return
	end

	if (CurTime() < wasteNext) then return end
	wasteNext = CurTime() + 0.12

	local eye = client:EyePos()
	local found = false

	for _, e in ipairs(ents.FindInSphere(eye, 1400)) do
		if (!IsValid(e) or e:GetClass() != "prop_physics") then continue end
		if (!e:GetNWBool("ixInfectWaste", false)) then continue end

		found = true

		if (!wasteEmitter) then wasteEmitter = ParticleEmitter(eye, false) end

		local base = e:WorldSpaceCenter()
		local pos = base + Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(-4, 16))

		local p = wasteEmitter:Add(string.format("particle/smokesprites_%04d", math.random(1, 9)), pos)
		if (!p) then continue end

		p:SetVelocity(Vector(math.Rand(-4, 4), math.Rand(-4, 4), math.Rand(8, 18)))
		p:SetDieTime(math.Rand(1.4, 2.6))
		p:SetStartAlpha(math.random(45, 80))
		p:SetEndAlpha(0)
		p:SetStartSize(math.random(14, 26))
		p:SetEndSize(math.random(45, 80))
		p:SetRoll(math.Rand(0, 360))
		p:SetRollDelta(math.Rand(-0.5, 0.5))
		p:SetColor(205, 210, 70) -- ядовито-жёлтый
		p:SetAirResistance(70)
		p:SetGravity(Vector(0, 0, 6))
		p:SetCollide(false)
	end

	if (wasteEmitter) then
		wasteEmitter:SetPos(eye)

		if (!found) then
			wasteEmitter:Finish()
			wasteEmitter = nil
		end
	end
end)
