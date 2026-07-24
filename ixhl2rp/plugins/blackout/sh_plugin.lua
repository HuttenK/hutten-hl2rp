local PLUGIN = PLUGIN

PLUGIN.name        = "Local Blackout"
PLUGIN.author      = "Hutten"
PLUGIN.description = "Admin-defined box zones that kill switchable map lights and darken the screen of players inside them."

-- Tweakables (client darkening strength).
-- Вход и выход затемняются симметрично: мгновенный «щелчок» на границе читался
-- как баг. Скорости — доли единицы в секунду, т.е. 0.8 ≈ 1.25 с на полный переход.
PLUGIN.fadeInSpeed  = 0.8   -- how fast the screen darkens as you enter (higher = snappier)
PLUGIN.fadeOutSpeed = 0.6   -- how fast the screen clears as you leave
PLUGIN.veilPower    = 2.2   -- shapes the fade curve (higher = darkness holds off longer)
PLUGIN.veilAlpha    = 240   -- max inside darkness (255 = pure black; lower = brighter)

-- From-outside view: a stencil volume mask darkens the REAL surfaces standing
-- inside the zone -- street, road, building faces, props. Occluded by solid
-- geometry, so there is no x-ray and no floating sheet.
PLUGIN.maskDarkness = 200   -- 0..255 darkness applied to surfaces inside the zone (255 = pure black)
PLUGIN.maskColor    = Color(4, 6, 16) -- «чёрный» ночи: чуть синий, не абсолютный ноль

-- Сила маски привязана к расстоянию до ГРАНИЦЫ зоны, а не до наблюдателя: внутри —
-- полная, за границей плавно гаснет, дальше maskFadeDist от края — не рисуется.
-- Издалека прямоугольник на стене не виден, на подходе темнота проявляется сама.
PLUGIN.maskFadeDist = 600   -- на сколько юнитов за границей зоны маска угасает до нуля
PLUGIN.maskPadding  = 4     -- units the mask box is grown by, so bordering walls darken too

-- Мягкий край. Голая AABB режет открытую землю (и стены) идеально прямой линией —
-- глаз читает это как баг рендера, а не как темноту. Гасим слоями вложенных
-- коробок: у края пиксель накрыт одним слоем, в глубине — всеми.
--
-- Низ НЕ размываем: нижняя грань уходит под пол, и градиент там только осветлил
-- бы дорогу. Верх размываем отдельно и шире — иначе высокая стена получает
-- горизонтальную полосу по срезу коробки.
PLUGIN.maskSoftness    = 160 -- ширина градиента у боковых стенок зоны (юниты)
PLUGIN.maskSoftnessTop = 256 -- ширина градиента у ВЕРХНЕЙ грани зоны (юниты)
PLUGIN.maskLayers      = 5   -- ступеней в градиенте (больше = глаже и дороже)

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

-- Что обесточивается внутри активной зоны. Ключ — класс сущности.
-- Обесточенная сущность не реагирует на E и не рисует свой экран.
PLUGIN.poweredClasses = {
	-- Комбайновские замки и двери
	["ix_combinelock"]       = true,

	-- Силовое поле: гасится в SetZoneForcefields, а здесь запрещаем ENT:Use,
	-- иначе комбайн переключением режима снова включит его прямо в темноте.
	["ix_forcefield"]        = true,

	-- Терминалы
	["ix_gonews_terminal"]   = true,
	["ix_gonews_editor"]     = true,
	["ix_civil_terminal"]    = true,
	["ix_loyalist_terminal"] = true,
	["ix_datafile_terminal"] = true,
	["ix_taskboard"]         = true,

}

-- Классы с переменным именем. ixcraft регистрирует ОТДЕЛЬНЫЙ класс на каждый
-- верстак («ix_station_station_stove», «ix_station_station_tokar» и т.д.), а
-- раздатчики пайков различаются суффиксом. Точное совпадение тут не работает.
PLUGIN.poweredPrefixes = {
	"ix_station_",      -- верстаки
	"ix_rationfactory_" -- раздатчики пайков и штамповщик
}

-- Общая для обоих реалмов проверка точки.
--
-- На сервере PLUGIN.zones хранит ВСЕ зоны с полем active; клиенту присылаются
-- только активные, и поля active у них нет. Поэтому пропускаем лишь те зоны,
-- у которых active явно выставлен в false.
function PLUGIN:IsPosBlackedOut(pos)
	for _, z in pairs(self.zones) do
		if (z.active == false) then continue end

		if (pos:WithinAABox(z.min, z.max)) then
			return true
		end
	end

	return false
end

-- Питается ли класс от сети: точное имя либо один из префиксов.
function PLUGIN:IsPoweredClass(class)
	if (self.poweredClasses[class]) then return true end

	for _, prefix in ipairs(self.poweredPrefixes) do
		if (string.sub(class, 1, #prefix) == prefix) then
			return true
		end
	end

	return false
end

-- Обесточена ли конкретная сущность: её класс питается от сети и она внутри тёмной зоны.
function PLUGIN:IsEntityBlackedOut(entity)
	if (!IsValid(entity)) then return false end
	if (!self:IsPoweredClass(entity:GetClass())) then return false end

	return self:IsPosBlackedOut(entity:GetPos())
end

ix.lang.AddTable("ru", {
	["blackout.noPower"] = "Нет питания.",
})
ix.lang.AddTable("en", {
	["blackout.noPower"] = "No power.",
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("cl_plugin.lua")
