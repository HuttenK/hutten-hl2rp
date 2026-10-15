local PLUGIN = PLUGIN

PLUGIN.name        = "Local Blackout"
PLUGIN.author      = "Hutten"
PLUGIN.description = "Local power failures with spatial darkness, repairable boxes and generator backup."

-- Shading is restricted to the exact zone bounds, viewed from either side.
PLUGIN.maskDarkness = 220
PLUGIN.maskColor = Color(0, 0, 0)
PLUGIN.maskSoftness = 24
PLUGIN.maskSoftnessTop = 24
PLUGIN.maskLayers = 48

-- Circuit box (fusebox) repair — players restore power by fixing a box in the zone.
PLUGIN.repairSkill  = 3     -- required Electronics ("electric") skill level
PLUGIN.repairXP     = 40    -- Electronics XP awarded on a successful repair

-- Circuit box sabotage — trigger a blackout two ways:
--   • EMP tool  — instant, requires NO skill (fire the EMP device at the box);
--   • screwdriver (E) — five-stage minigame, requires Electronics skill breakSkill.
PLUGIN.breakSkill   = 4     -- required Electronics skill for the screwdriver sabotage
PLUGIN.breakXP      = 30    -- Electronics XP awarded on a successful screwdriver sabotage

-- Electric shock: if a character lacks the required Electronics skill and touches
-- a box (repair OR screwdriver sabotage), there's a chance the current knocks them out.
PLUGIN.shockChance   = 0.25 -- 0..1 chance of a shock on an under-skilled interaction
PLUGIN.shockDuration = 10   -- seconds the character is knocked out (ragdolled) by a shock

-- Что обесточивается внутри активной зоны. Ключ — класс сущности.
-- Обесточенная сущность не реагирует на E и не рисует свой экран.
PLUGIN.poweredClasses = {
 ["ix_foundation_terminal"] = true,
 ["ix_foundation_public_terminal"] = true,
	-- Комбайновские замки и двери
	["ix_combinelock"]       = true,

	-- Силовое поле: гасится в SetZoneForcefields, а здесь запрещаем ENT:Use,
	-- иначе комбайн переключением режима снова включит его прямо в темноте.
	["ix_forcefield"]        = true,
 ["ent_cmb_forcefield"] = true,
 ["ix_contrabandscanner"] = true,

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
	if SERVER then local override=hook.Run("FacilityPowerAt",pos);if override~=nil then return override end end
	for _, z in pairs(self.zones) do
		if (z.active == false) then continue end

		if (ix.area.Contains(z, pos)) then
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

-- The global electronics switch is independent of visual darkness and circuit
-- backup. Raw active zones are its exceptions, even when a generator lights one.
function PLUGIN:ElectronicsOverride(pos)
	if self.unloading or not self.electronicsRestricted then return end
	local zones = SERVER and self.zones or self.electronicsZones
	for _, z in pairs(zones or {}) do
		if (not SERVER or z.active == true) and ix.area.Contains(z, pos) then return false end
	end
	return true
end

function PLUGIN:IsElectronicsOffAt(pos, entity)
	if self.unloading then return false end
	local override = self:ElectronicsOverride(pos)
	if override ~= nil then return override end
	if IsValid(entity) and ix.Facility and ix.Facility.EntityBackup(entity) then return false end
	if self:IsPosBlackedOut(pos) then return true end
	-- Normal blackout rules also cover a lock mounted just outside its door.
	return IsValid(entity) and entity:GetClass() == "ix_combinelock"
		and IsValid(entity.door) and self:IsPosBlackedOut(entity.door:GetPos()) or false
end

-- Devices with their own normal power model also participate in the admin mode.
PLUGIN.electronicClasses = {
	ix_boombox=true, ix_stationary_radio=true, ix_vendingmachine=true,
	ix_rationdispenser=true, ix_factory_recycler=true, ix_flood_pump=true,
	ix_scannerterminal=true, ix_unionlight=true,
}

-- Only electronics are blocked; ordinary props, carts and medical beds stay usable.
function PLUGIN:IsEntityBlackedOut(entity)
	if (!IsValid(entity)) then return false end
	local class = entity:GetClass()
	local extra = self.electronicsRestricted and (self.electronicClasses[class]
		or class:sub(1,12) == "ix_facility_" or class:sub(1,8) == "ix_cctv_")
	if not extra and not self:IsPoweredClass(class) then return false end
	return self:IsElectronicsOffAt(entity:GetPos(), entity)
end

ix.lang.AddTable("ru", {
	["blackout.noPower"] = "Нет питания.",
})
ix.lang.AddTable("en", {
	["blackout.noPower"] = "No power.",
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("sh_area.lua")
ix.util.Include("sv_area.lua")
ix.util.Include("sh_commands.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_lighting.lua")
ix.util.Include("cl_settings.lua")
