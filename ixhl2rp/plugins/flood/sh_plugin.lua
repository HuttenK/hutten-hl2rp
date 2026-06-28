local PLUGIN = PLUGIN

PLUGIN.name = "Затопление"
PLUGIN.author = "Claude"
PLUGIN.description = "Управляемое админами затопление замкнутых зон (подвалы, каналы, тоннели) с откачкой воды и плавучестью предметов."

-- Текущий уровень воды по зонам: [имя зоны] = абсолютная Z поверхности воды.
-- Сервер — источник истины; клиенту приходит через netstream "flood.sync".
PLUGIN.level = PLUGIN.level or {}

PLUGIN.defaults = {
	-- Плавучесть (подбирается на месте).
	buoyancyAccel = 900,   -- целевое ускорение вверх у дна (ед/с^2); чуть больше гравитации (600), чтобы всплывало
	submergeDepth = 24,    -- на какой глубине предмет считается полностью погружённым
	linearDamp    = 2.5,   -- линейное демпфирование в воде (вязкость)
	angularDamp   = 3.0,   -- угловое демпфирование (чтобы не крутилось бесконечно)

	-- Движение/утопление/плавание.
	slowFactor    = 0.5,   -- множитель горизонтальной скорости в воде
	swimSpeed     = 110,   -- вертикальная скорость гребка (Пробел — вверх, Ctrl — вниз)
	floatDepth    = 46,    -- на сколько ног уходит под воду при «зависании» (голова торчит)
	maxAir        = 12,    -- секунд воздуха под водой
	drownDamage   = 8,     -- урон за тик утопления
	drownInterval = 1,     -- секунд между тиками урона при нехватке воздуха

	-- Откачка.
	pumpStep      = 12,    -- на сколько юнитов опускается вода за один цикл откачки
	pumpTime      = 4,     -- секунд держать E на насосе за один цикл

	-- Кабель насос<->бак.
	maxCableLength = 400,        -- макс. дистанция между насосом и баком при соединении
	cableWidth     = 3,          -- толщина видимого кабеля
	cableMaterial  = "cable/cable2", -- промышленный кабель (есть в базовом GMod)
	linkTimeout    = 30,         -- сколько секунд «висит» выбранный для соединения насос
}

-- Нормализованные границы зоны (мин/макс по каждой оси).
-- ВАЖНО: клиент получает углы зоны из net "ixAreaAdd" БЕЗ сортировки
-- (helix/plugins/area/cl_hooks.lua), поэтому startPosition/endPosition НЕ
-- гарантированно являются мин/макс. Сортируем сами — иначе вода рисуется
-- узкой полосой по центру и подводные эффекты не срабатывают.
function PLUGIN:GetAreaBounds(area)
	local s, e = area.startPosition, area.endPosition
	if (!s or !e) then return end

	return Vector(math.min(s.x, e.x), math.min(s.y, e.y), math.min(s.z, e.z)),
	       Vector(math.max(s.x, e.x), math.max(s.y, e.y), math.max(s.z, e.z))
end

-- Поверхность воды в точке pos: возвращает (уровеньZ, имяЗоны), если точка внутри
-- затопленной зоны и ниже поверхности; иначе nil. Общая для клиента и сервера.
function PLUGIN:WaterLevelAt(pos)
	for name, area in pairs(ix.area.stored or {}) do
		if (area.type == "flood") then
			local lvl = self.level[name]
			local mins, maxs = self:GetAreaBounds(area)

			if (lvl and mins and maxs and lvl > mins.z) then
				if (pos.x >= mins.x and pos.x <= maxs.x
				and pos.y >= mins.y and pos.y <= maxs.y
				and pos.z <= lvl and pos.z >= mins.z - 64) then
					return lvl, name
				end
			end
		end
	end
end

-- Регистрируем тип зоны (idempotent — переживает lua_reload).
function PLUGIN:SetupAreaProperties()
	ix.area.AddType("flood", "Зона затопления")
end

if (ix.area and ix.area.AddType) then
	PLUGIN:SetupAreaProperties()
end

if (SERVER) then
	ix.util.Include("sv_plugin.lua")
end

ix.util.Include("cl_plugin.lua")

-- Плавание: когда игрок по пояс в воде — замедляем по горизонтали и даём
-- вертикальный контроль (Пробел вверх, Ctrl вниз, иначе — плавно всплывает).
-- Общий хук (клиент+сервер) для корректного предсказания.
function PLUGIN:SetupMove(ply, mv, cmd)
	local d = self.defaults

	-- мёртв или не в воде → вернуть гравитацию и выйти
	local lvl
	if (ply:Alive()) then
		lvl = self:WaterLevelAt(mv:GetOrigin() + Vector(0, 0, 36)) -- вода по пояс?
	end

	if (!lvl) then
		if (SERVER and ply.ixFloodSwim) then
			ply:SetGravity(1)
			ply.ixFloodSwim = nil
		end

		return
	end

	local origin = mv:GetOrigin()

	-- почти отключаем гравитацию, чтобы вертикалью управлял наш код
	if (SERVER and !ply.ixFloodSwim) then
		ply:SetGravity(0.08)
		ply.ixFloodSwim = true
	end

	-- замедляем горизонталь
	local speed = ply:GetWalkSpeed() * d.slowFactor
	mv:SetMaxClientSpeed(speed)
	mv:SetMaxSpeed(speed)

	local vel     = mv:GetVelocity()
	local buttons = mv:GetButtons()
	local up      = bit.band(buttons, IN_JUMP) != 0
	local down    = bit.band(buttons, IN_DUCK) != 0

	if (up and !down) then
		vel.z = d.swimSpeed
	elseif (down and !up) then
		vel.z = -d.swimSpeed
	else
		-- лёгкая плавучесть: дрейфуем так, чтобы голова торчала над водой
		local floatFeetZ = lvl - d.floatDepth
		vel.z = math.Clamp((floatFeetZ - origin.z) * 3, -55, 55)
	end

	mv:SetVelocity(vel)
end

-- ==== Админ-команды ====
-- Разрешить уровня зоны: имя, "here"/пусто = текущая зона игрока.
local function ResolveZone(client, name)
	local zone = (name and name != "" and name != "here") and name or client:GetArea()
	local area = zone and ix.area.stored[zone]

	if (!area or area.type != "flood") then
		return nil, "Вы не в зоне затопления. Укажите имя зоны."
	end

	return zone, area
end

ix.command.Add("FloodSet", {
	description = "Установить абсолютную высоту воды (Z) в зоне затопления.",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.number, ix.type.optional),
		bit.bor(ix.type.string, ix.type.optional),
	},
	OnRun = function(self, client, z, name)
		local zone, areaOrErr = ResolveZone(client, name)
		if (!zone) then return areaOrErr end

		if (!z) then return "Укажите высоту Z." end

		PLUGIN:SetLevel(zone, z)
		return "Уровень воды в зоне '" .. zone .. "' установлен на Z=" .. math.Round(PLUGIN.level[zone] or z) .. "."
	end
})

ix.command.Add("FloodRaise", {
	description = "Поднять воду в текущей зоне на N юнитов (по умолчанию 16).",
	adminOnly = true,
	arguments = { bit.bor(ix.type.number, ix.type.optional) },
	OnRun = function(self, client, amount)
		local zone, area = ResolveZone(client)
		if (!zone) then return area end

		local cur = PLUGIN.level[zone] or area.startPosition.z
		PLUGIN:SetLevel(zone, cur + (amount or 16))
		return "Вода в '" .. zone .. "' поднята до Z=" .. math.Round(PLUGIN.level[zone]) .. "."
	end
})

ix.command.Add("FloodLower", {
	description = "Опустить воду в текущей зоне на N юнитов (по умолчанию 16).",
	adminOnly = true,
	arguments = { bit.bor(ix.type.number, ix.type.optional) },
	OnRun = function(self, client, amount)
		local zone, area = ResolveZone(client)
		if (!zone) then return area end

		local cur = PLUGIN.level[zone] or area.startPosition.z
		PLUGIN:SetLevel(zone, cur - (amount or 16))
		return "Вода в '" .. zone .. "' опущена до Z=" .. math.Round(PLUGIN.level[zone]) .. "."
	end
})

ix.command.Add("FloodFill", {
	description = "Залить текущую зону до потолка (верх AABB).",
	adminOnly = true,
	arguments = { bit.bor(ix.type.string, ix.type.optional) },
	OnRun = function(self, client, name)
		local zone, area = ResolveZone(client, name)
		if (!zone) then return area end

		PLUGIN:SetLevel(zone, area.endPosition.z)
		return "Зона '" .. zone .. "' залита до потолка."
	end
})

ix.command.Add("FloodDrain", {
	description = "Осушить зону (имя, all, или пусто = текущая).",
	adminOnly = true,
	arguments = { bit.bor(ix.type.string, ix.type.optional) },
	OnRun = function(self, client, name)
		if (name == "all") then
			local n = 0
			for zoneName, area in pairs(ix.area.stored) do
				if (area.type == "flood") then
					PLUGIN:SetLevel(zoneName, area.startPosition.z)
					n = n + 1
				end
			end
			return "Осушено зон: " .. n .. "."
		end

		local zone, area = ResolveZone(client, name)
		if (!zone) then return area end

		PLUGIN:SetLevel(zone, area.startPosition.z)
		return "Зона '" .. zone .. "' осушена."
	end
})

ix.command.Add("FloodDebug", {
	description = "Диагностика плагина затопления.",
	adminOnly = true,
	OnRun = function(self, client)
		local function say(t) client:ChatPrint(t) print(t) end

		say("[Flood] тип зарегистрирован: " .. tostring(ix.area and ix.area.types and ix.area.types["flood"] != nil))
		say("[Flood] ваша зона: " .. tostring(client:GetArea()))

		local n = 0
		for name, area in pairs(ix.area.stored or {}) do
			if (area.type == "flood") then
				n = n + 1
				local lvl = PLUGIN.level[name]
				say(string.format("[Flood]   '%s': дно Z=%d, потолок Z=%d, вода Z=%s",
					name, math.Round(area.startPosition.z), math.Round(area.endPosition.z),
					lvl and math.Round(lvl) or "осушено"))
			end
		end
		say("[Flood] зон затопления: " .. n)

		return "Диагностика выведена в чат и консоль."
	end
})
