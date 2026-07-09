local PLUGIN = PLUGIN

PLUGIN.name = "Зоны заражения"
PLUGIN.author = "Claude"
PLUGIN.description = "Зоны, где спавнятся зомби и территория постепенно зарастает чужой флорой (Xen)."

-- Список моделей «флоры». Дополняйте по желанию.
PLUGIN.floraModels = {
	"models/hlvr/distillery_gunk/distillerygunk_gunk.mdl",
	"models/jq/hlvr/props/infestation/p1/rock_1.mdl",
	"models/jq/hlvr/props/infestation/p1/rock_2.mdl",
	"models/jq/hlvr/props/infestation/p1/rock_4.mdl",
	"models/jq/hlvr/props/infestation/p1/rock_5.mdl",
	"models/jq/hlvr/props/infestation/p1/rock_6.mdl",
	"models/jq/hlvr/props/infestation/p1/rock_7.mdl",
	"models/jq/hlvr/props/xenpack/xen_a2_sewer001.mdl",
	"models/jq/hlvr/props/xenpack/xen_blob001.mdl",
	"models/jq/hlvr/props/xenpack/xen_blower002.mdl",
	"models/jq/hlvr/props/xenpack/xen_cluster001b.mdl",
	"models/jq/hlvr/props/xenpack/xen_cluster001b_rev.mdl",
	"models/jq/hlvr/props/xenpack/xen_coral_01.mdl",
	"models/jq/hlvr/props/xenpack/xen_fin001.mdl",
	"models/jq/hlvr/props/xenpack/xen_fin002.mdl",
	"models/jq/hlvr/props/xenpack/xen_fin003.mdl",
	"models/jq/hlvr/props/xenpack/xen_flat_blob01.mdl",
	"models/jq/hlvr/props/xenpack/xen_flat_blob01_barrel_mush01.mdl",
	"models/jq/hlvr/props/xenpack/xen_floor_wall002_wide_flat.mdl",
	"models/jq/hlvr/props/xenpack/xen_pod_structure001.mdl",
	"models/jq/hlvr/props/xenpack/xen_pod_structure002_burst.mdl",
	"models/jq/hlvr/props/xenpack/xen_seed_cluster_stick_1.mdl",
	"models/jq/hlvr/props/xenpack/xen_spore001.mdl",
	"models/jq/hlvr/props/xenpack/xen_strand_anchor003.mdl",
	"models/jq/hlvr/props/xenpack/xen_strand_anchor004.mdl",
	"models/jq/hlvr/props/xenpack/xen_strand_anchor005.mdl",
	"models/jq/hlvr/props/xenpack/xen_strand_anchor006.mdl",
	"models/jq/hlvr/props/xenpack/xen_strand_anchor007.mdl",
	"models/jq/hlvr/props/xenpack/xen_strand_anchor008.mdl",
	"models/jq/hlvr/props/xenpack/xen_tendril_01.mdl",
	"models/jq/hlvr/props/xenpack/xen_tendril_02.mdl",
	"models/jq/hlvr/props/xenpack/xen_web_cone001.mdl",
	"models/jq/hlvr/props/xenpack/xen_web_corner_small003.mdl",
	"models/jq/hlvr/props/xenpack/xen_web_corner_small004.mdl",
	"models/jq/hlvr/props/xenpack/xen_web_corner_small005.mdl",
	"models/jq/hlvr/props/xenpack/xen_web_disc001.mdl",
	"models/jq/hlvr/props/xenpack/xen_web_flat_posable.mdl",
	"models/jq/hlvr/props/xenpack/xen_web_mid.mdl",
	"models/jq/hlvr/props/xenpack/xen_web_wide.mdl",
}

-- Параметры по умолчанию (используются, если в свойствах зоны не задано иное).
PLUGIN.defaults = {
	zombieMax = 6,       -- максимум живых зомби в зоне
	zombieInterval = 8,  -- секунд между попытками спавна зомби
	floraMax = 40,       -- потолок числа пропов-флоры в зоне
	floraInterval = 5,   -- секунд между подсадкой пропа
	activeRadius = 2048, -- зона «активна» (спавнит), если игрок ближе этого к центру или внутри
	despawnDelay = 30,   -- через сколько секунд без игроков убирать зомби зоны
	floraHealth = 40,    -- сколько урона держит один проп-флора, прежде чем разрушится
	suppressDuration = 120, -- на сколько секунд останавливается зарастание после зачистки игроком
	floraGrowTime = 1.2, -- секунд на анимацию «прорастания» флоры (плавное увеличение масштаба)
	floraMaxSlope = 0.3, -- мин. вертикальная составляющая нормали (0..1): ниже — поверхность слишком крутая

	infestationTotal = 25, -- сколько всего флоры нужно СОБРАТЬ, чтобы зачистить зону (потом зона удаляется)
	collectTime = 3,       -- секунд держать E (прогресс-бар), чтобы собрать один проп флоры
	collectRange = 160,    -- макс. дистанция до пропа на момент завершения сбора (юниты)

	-- Токсичный газ: воздействие на игроков БЕЗ защиты внутри зоны (без урона по HP).
	toxicResistNeeded = 50, -- GetRadResistance >= это => считается защищённым (костюм=80, противогаз+фильтр=99)
	toxicBuildTime = 45,    -- секунд без защиты до потери сознания
	toxicRecover = 2,       -- во сколько раз быстрее «выветривается» отравление в безопасности
	falloverTime = 60,      -- секунд лежать без сознания после отравления

	-- Распаковка мешка с отходами (выпуск заражения «в поле»).
	wasteWaveDelay = 4,     -- секунд до второй волны пропов вокруг основного
	wasteWaveCount = 5,     -- сколько пропов во второй волне
	wasteWaveRadius = 140,  -- радиус разброса второй волны (юниты)
}

-- Модели предметов сбора (для прекэша на сервере).
PLUGIN.bagModel   = "models/hlvr/combine_hazardprops/combinehazardprops_clothe.mdl"
PLUGIN.trashModel = "models/hlvr/combine_hazardprops/combinehazardprops_trashbag.mdl"

-- Отравление синхронизируем нативными NWVar (SetNWFloat/SetNWBool) — они не
-- требуют регистрации, в отличие от Helix SetNetVar (тот молча игнорирует
-- незарегистрированный ключ). См. [[helix-data-netvar-registration-gotcha]].

-- Регистрируем тип зоны и редактируемые свойства (доступны в /AreaEdit).
function PLUGIN:SetupAreaProperties()
	ix.area.AddType("infection", "Зона заражения")

	ix.area.AddProperty("zombieMax", ix.type.number, PLUGIN.defaults.zombieMax)
	ix.area.AddProperty("zombieInterval", ix.type.number, PLUGIN.defaults.zombieInterval)
	ix.area.AddProperty("floraMax", ix.type.number, PLUGIN.defaults.floraMax)
	ix.area.AddProperty("floraInterval", ix.type.number, PLUGIN.defaults.floraInterval)
	ix.area.AddProperty("infestationTotal", ix.type.number, PLUGIN.defaults.infestationTotal)
	-- Неразрушимая зона: если включено, зону НЕЛЬЗЯ зачистить сбором флоры —
	-- сколько бы её ни собрали, зона остаётся и продолжает зарастать.
	ix.area.AddProperty("indestructible", ix.type.bool, false)
end

-- Регистрируем тип сразу при загрузке файла — на случай lua_reload,
-- когда хук SetupAreaProperties повторно не вызывается (иначе тип не появится в /AreaEdit).
if (ix.area and ix.area.AddType) then
	PLUGIN:SetupAreaProperties()
end

if (SERVER) then
	ix.util.Include("sv_plugin.lua")
end

ix.util.Include("cl_plugin.lua")

-- Блокируем бег, пока игрок задыхается в газе без защиты (ixToxicChoke). Хук
-- общий (клиент+сервер) — иначе предсказание движения будет «дёргаться».
-- Наш SetupMove идёт после healthsystem (загружается позже по алфавиту), поэтому
-- наш ограничитель скорости — последний и побеждает.
function PLUGIN:SetupMove(ply, mv, cmd)
	if (!ply:GetNWBool("ixToxicChoke", false)) then return end

	-- гасим спринт-режим healthsystem, если он включён
	if (ply.GetSprintMove and ply:GetSprintMove()) then
		ply:SetSprintMove(false)
		ply:SetSprintSpeed(0)
	end

	local walk = ply:GetWalkSpeed()
	mv:SetMaxClientSpeed(walk)
	mv:SetMaxSpeed(walk)
end

-- Очистить разросшуюся флору: имя зоны, "all", или пусто = зона, в которой стоите.
ix.command.Add("InfectionClean", {
	description = "Очистить флору в зоне заражения (аргумент: имя зоны, all, или пусто = текущая).",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, name)
		if (name == "all") then
			local n = 0

			for zoneName, area in pairs(ix.area.stored) do
				if (area.type == "infection") then
					PLUGIN:CleanFlora(zoneName)
					n = n + 1
				end
			end

			return "Флора очищена во всех зонах заражения (" .. n .. ")."
		end

		local zone = (name and name != "") and name or client:GetArea()
		local area = zone and ix.area.stored[zone]

		if (!area or area.type != "infection") then
			return "Вы не в зоне заражения. Укажите имя зоны или 'all'."
		end

		PLUGIN:CleanFlora(zone)

		return "Флора очищена в зоне: " .. zone
	end
})

-- Убрать зомби зоны.
ix.command.Add("InfectionPurge", {
	description = "Убрать зомби в зоне заражения (аргумент: имя зоны, all, или пусто = текущая).",
	adminOnly = true,
	arguments = {
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, name)
		if (name == "all") then
			local n = 0

			for zoneName, area in pairs(ix.area.stored) do
				if (area.type == "infection") then
					PLUGIN:PurgeZombies(zoneName)
					n = n + 1
				end
			end

			return "Зомби убраны во всех зонах заражения (" .. n .. ")."
		end

		local zone = (name and name != "") and name or client:GetArea()
		local area = zone and ix.area.stored[zone]

		if (!area or area.type != "infection") then
			return "Вы не в зоне заражения. Укажите имя зоны или 'all'."
		end

		PLUGIN:PurgeZombies(zone)

		return "Зомби убраны в зоне: " .. zone
	end
})

-- Диагностика: показывает, видит ли сервер зоны заражения и работает ли тик.
ix.command.Add("InfectionDebug", {
	description = "Диагностика плагина зон заражения.",
	adminOnly = true,
	OnRun = function(self, client)
		local function say(text)
			client:ChatPrint(text)
			print(text)
		end

		say("[Infection] тип зарегистрирован: " .. tostring(ix.area and ix.area.types and ix.area.types["infection"] != nil))
		say("[Infection] таймер тика: " .. tostring(timer.Exists("ixInfectionTick")))

		local cur = client:GetArea()
		say("[Infection] ваша текущая зона (GetArea): " .. tostring(cur))

		if (cur and ix.area.stored[cur]) then
			say("[Infection]   тип этой зоны: " .. tostring(ix.area.stored[cur].type))
		end

		local pos = client:GetPos()
		local n = 0

		for name, area in pairs(ix.area.stored or {}) do
			if (area.type == "infection") then
				n = n + 1
				local inside = pos:WithinAABox(area.startPosition, area.endPosition)
				local fc = (PLUGIN.flora and PLUGIN.flora[name] and table.Count(PLUGIN.flora[name])) or 0
				local zc = (PLUGIN.zombies and PLUGIN.zombies[name] and table.Count(PLUGIN.zombies[name])) or 0
				local rem = (PLUGIN.remaining and PLUGIN.remaining[name])
				say(string.format("[Infection]   зона '%s': внутри=%s, осталось_собрать=%s, флора=%d, зомби=%d",
					name, tostring(inside), tostring(rem == nil and "?" or rem), fc, zc))
			end
		end

		say("[Infection] зон типа infection: " .. n)
		say("[Infection] моделей флоры в списке: " .. (PLUGIN.floraModels and #PLUGIN.floraModels or 0))

		return "Диагностика выведена в чат и консоль."
	end
})
