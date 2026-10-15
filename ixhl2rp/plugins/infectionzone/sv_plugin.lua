local PLUGIN = PLUGIN
if PLUGIN.CleanupRuntime then PLUGIN:CleanupRuntime() end
PLUGIN.unloading = false
PLUGIN.collections = {}
PLUGIN.wasteGeneration = (PLUGIN.wasteGeneration or 0) + 1

-- Учёт спавненных сущностей по зонам: [имя зоны] = { [ent] = true }
PLUGIN.zombies = PLUGIN.zombies or {}
PLUGIN.flora = PLUGIN.flora or {}
PLUGIN.suppressed = PLUGIN.suppressed or {} -- [имя зоны] = CurTime, до которого зарастание остановлено
PLUGIN.nextSpawn = PLUGIN.nextSpawn or {}   -- [имя зоны] = { zombie = t, flora = t, lastNear = t }
PLUGIN.remaining = PLUGIN.remaining or {}   -- [имя зоны] = сколько флоры ещё осталось СОБРАТЬ (пул заражения)

util.AddNetworkString("ixInfectionGasBurst") -- клиентам: вспышка ядовитого газа в точке

-- Посчитать живые сущности в таблице, попутно чистя невалидные ссылки.
local function countValid(t)
	if (!t) then return 0 end

	local n = 0

	for ent in pairs(t) do
		if (IsValid(ent)) then
			n = n + 1
		else
			t[ent] = nil
		end
	end

	return n
end

local function removeAll(t)
	if (!t) then return end

	for ent in pairs(t) do
		if (IsValid(ent)) then
			ent:Remove()
		end
	end
end

-- Случайная валидная точка на полу внутри AABB-куба зоны.
local function randomGroundPoint(area)
	local boxes = ix.area.GetDisjointVolumes(area) or ix.area.GetVolumes(area)
	local box = boxes[math.random(#boxes)]
	local mins, maxs = box.min, box.max

	local x = math.Rand(mins.x, maxs.x)
	local y = math.Rand(mins.y, maxs.y)

	local tr = util.TraceLine({
		start = Vector(x, y, maxs.z + 16),
		endpos = Vector(x, y, mins.z - 64),
		mask = MASK_SOLID_BRUSHONLY
	})

	if (!tr.Hit or tr.HitSky) then
		return
	end

	-- точка пола должна находиться в пределах высоты зоны
	if (tr.HitPos.z < mins.z - 8 or tr.HitPos.z > maxs.z + 8) then
		return
	end

	return tr.HitPos, tr.HitNormal
end

-- Есть ли рядом живой игрок (внутри зоны или в радиусе активации).
local function hasPlayerNear(area, radius)
	local r2 = radius * radius

	for _, ply in ipairs(player.GetAll()) do
		if (ply:Alive() and ply:GetCharacter()) then
			local pos = ply:GetPos()

			if (ix.area.DistanceSqr(area, pos) <= r2) then
				return true
			end
		end
	end

	return false
end

local function spawnZombie(name, area)
	local pos = randomGroundPoint(area)
	if (!pos) then return end

	-- проверяем, что есть место под габарит зомби
	local tr = util.TraceHull({
		start = pos + Vector(0, 0, 4),
		endpos = pos + Vector(0, 0, 4),
		mins = Vector(-16, -16, 0),
		maxs = Vector(16, 16, 72),
		mask = MASK_NPCSOLID
	})

	if (tr.Hit) then return end

	local zombie = ents.Create("npc_zombie")
	if (!IsValid(zombie)) then return end

	zombie:SetPos(pos + Vector(0, 0, 2))
	zombie:SetAngles(Angle(0, math.random(0, 360), 0))
	zombie:Spawn()
	zombie:Activate()

	zombie.bNoPersist = true
	zombie.ixInfectionZone = name

	PLUGIN.zombies[name] = PLUGIN.zombies[name] or {}
	PLUGIN.zombies[name][zombie] = true
end

local function spawnFlora(name, area)
	local pos, normal = randomGroundPoint(area)
	if (!pos) then return end

	normal = normal or vector_up

	-- Слишком крутые поверхности (стены/потолок) пропускаем — флора «наземная».
	if (normal.z < PLUGIN.defaults.floraMaxSlope) then
		return
	end

	-- Ориентируем проп по нормали: его локальный «верх» смотрит вдоль нормали
	-- поверхности, плюс случайный поворот вокруг неё для разнообразия.
	local ang = normal:Angle()
	ang:RotateAroundAxis(ang:Right(), -90)
	ang:RotateAroundAxis(normal, math.random(0, 360))

	local model = PLUGIN.validFloraModels[math.random(#PLUGIN.validFloraModels)]

	local prop = ents.Create("prop_physics")
	if (!IsValid(prop)) then return end

	prop:SetModel(model)
	-- слегка утапливаем основание вдоль нормали, чтобы флора «прорастала», а не висела
	prop:SetPos(pos - normal * 2)
	prop:SetAngles(ang)
	prop:Spawn()
	prop:Activate()

	-- замораживаем и отключаем «думанье», чтобы не грузить сервер
	local phys = prop:GetPhysicsObject()

	if (IsValid(phys)) then
		phys:EnableMotion(false)
		phys:Sleep()
	end

	prop:SetMoveType(MOVETYPE_NONE)
	prop:AddEFlags(EFL_NO_THINK_FUNCTION)

	-- Анимация «прорастания»: стартуем почти из нуля и плавно вырастаем до полного
	-- размера. Масштаб интерполирует движок (на основе CurTime), Lua-think не нужен,
	-- поэтому EFL_NO_THINK_FUNCTION выставленный выше анимации не мешает.
	prop:SetModelScale(0.01, 0)
	prop:SetModelScale(1, PLUGIN.defaults.floraGrowTime)

	-- большой engine-HP, чтобы движок сам не ломал — «здоровье» считаем вручную
	prop:SetHealth(1000000)
	prop.bNoPersist = true
	prop.ixFloraHP = PLUGIN.defaults.floraHealth
	prop.ixInfectionFlora = name

	PLUGIN.flora[name] = PLUGIN.flora[name] or {}
	PLUGIN.flora[name][prop] = true
end

function PLUGIN:CleanFlora(name)
 if name == "__waste" then self.wasteGeneration = self.wasteGeneration + 1 end
	removeAll(self.flora[name])
	self.flora[name] = {}
end

function PLUGIN:PurgeZombies(name)
	removeAll(self.zombies[name])
	self.zombies[name] = {}
end

-- Спавн одного пропа флоры в конкретной точке (с ориентацией по нормали).
-- Используется при «распаковке» отходов. name — ключ группы (для зон это имя зоны,
-- для свободной флоры из отходов — "__waste", чтобы сбор не трогал логику зон).
function PLUGIN:SpawnFloraAt(pos, normal, name)
 if self.unloading or (name == "__waste" and countValid(self.flora[name]) >= 48) then return end
	normal = normal or vector_up

	local ang = normal:Angle()
	ang:RotateAroundAxis(ang:Right(), -90)
	ang:RotateAroundAxis(normal, math.random(0, 360))

	local prop = ents.Create("prop_physics")
	if (!IsValid(prop)) then return end

	prop:SetModel(self.validFloraModels[math.random(#self.validFloraModels)])
	prop:SetPos(pos - normal * 2)
	prop:SetAngles(ang)
	prop:Spawn()
	prop:Activate()

	local phys = prop:GetPhysicsObject()

	if (IsValid(phys)) then
		phys:EnableMotion(false)
		phys:Sleep()
	end

	prop:SetMoveType(MOVETYPE_NONE)
	prop:AddEFlags(EFL_NO_THINK_FUNCTION)
	prop:SetModelScale(0.01, 0)
	prop:SetModelScale(1, self.defaults.floraGrowTime)
	prop:SetHealth(1000000)
	prop.bNoPersist = true
	prop.ixFloraHP = self.defaults.floraHealth
	prop.ixInfectionFlora = name

	-- помечаем распакованные «отходные» пропы — клиент рисует у них постоянный дым
	if (name == "__waste") then
		prop:SetNWBool("ixInfectWaste", true)
        prop.ixWasteExpires = CurTime() + 300
	end

	self.flora[name] = self.flora[name] or {}
	self.flora[name][prop] = true

	return prop
end

-- Точка на земле для спавна: трасса вниз из позиции, возврат точки и нормали.
local function groundAt(pos)
	local tr = util.TraceLine({
		start = pos + Vector(0, 0, 24),
		endpos = pos - Vector(0, 0, 180),
		mask = MASK_SOLID_BRUSHONLY
	})

	if (!tr.Hit or tr.HitSky) then return end

	return tr.HitPos, tr.HitNormal
end

-- Распаковка мешка с отходами: основной проп заражения перед игроком + облако газа,
-- а через несколько секунд — вторая волна пропов вокруг. Все пропы помечаются
-- "__waste" и собираются обычными пустыми контейнерами (без привязки к зоне).
function PLUGIN:UnpackWaste(client)
	if self.unloading or not IsValid(client) or not client:Alive() or not client:GetCharacter() then return false end
 if CurTime() < (client.ixNextWaste or 0) or countValid(self.flora.__waste) >= 48 then
  client:Notify("Подождите: слишком много заражённых отходов поблизости.")
  return false
 end

	local forward = client:GetForward()
	forward.z = 0
	forward:Normalize()

	local front = client:GetPos() + forward * 64 + Vector(0, 0, 16)
	local center, normal = groundAt(front)

	center = center or (client:GetPos() + forward * 64)
	normal = normal or vector_up

	-- основной проп
	local primary = self:SpawnFloraAt(center, normal, "__waste")
 if not IsValid(primary) then return false end
 client.ixNextWaste = CurTime() + 5
 local generation = self.wasteGeneration

	-- облако ядовитого газа (визуально) для тех, кто рядом
	net.Start("ixInfectionGasBurst")
		net.WriteVector(center)
	net.SendPVS(center)

	-- вторая волна через несколько секунд: пропы по кругу вокруг основного
	timer.Simple(self.defaults.wasteWaveDelay, function()
        if self.unloading or generation ~= self.wasteGeneration or not IsValid(primary) then return end
		for i = 1, self.defaults.wasteWaveCount do
			local a = math.rad(math.random(0, 360))
			local dist = math.Rand(48, self.defaults.wasteWaveRadius)
			local spot = center + Vector(math.cos(a) * dist, math.sin(a) * dist, 0)
			local gpos, gnorm = groundAt(spot)

			if (gpos) then
				local growth = self:SpawnFloraAt(gpos, gnorm, "__waste")
                if IsValid(growth) then growth.ixNoWasteYield = true end
			end
		end

		net.Start("ixInfectionGasBurst")
			net.WriteVector(center)
		net.SendPVS(center)
	end)
 return true
end

-- Игрок собрал один проп флоры контейнером: проп исчезает, в мире появляется
-- предмет «мешок с флорой», пул заражения (remaining) уменьшается. При нуле —
-- проверяем полную зачистку.
function PLUGIN:CollectFlora(prop, client)
	if (!IsValid(prop) or !prop.ixInfectionFlora) then return end

	local name = prop.ixInfectionFlora
	local pos = prop:GetPos()

    if not IsValid(client) or not client:Alive() or not client:GetCharacter() or not client:HasItem("hazard_bag") then return false end
    -- Commit collection only after the reward exists. Secondary waste is safely
    -- neutralised without yielding more bags.
    if not prop.ixNoWasteYield then
        local instance = ix.Item:Instance("trashbag")
        if not instance then return false end
        local reward = ix.Item:Spawn(pos + Vector(0, 0, 6), Angle(0, math.random(0, 360), 0), instance)
        if not IsValid(reward) then instance:Remove(); return false end
    end
    if self.flora[name] then self.flora[name][prop] = nil end
    prop:Remove()

	-- Неразрушимую зону нельзя зачистить: пул не расходуется, счётчик не показываем.
	local zoneArea = ix.area.stored[name]
	local indestructible = zoneArea and zoneArea.properties and zoneArea.properties.indestructible

	-- уменьшаем пул заражения (кроме неразрушимых зон)
	if (not indestructible and self.remaining[name]) then
		self.remaining[name] = math.max(0, self.remaining[name] - 1)
	end

	client:EmitSound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 3) .. ".wav", 65, math.random(95, 105))

	-- расходуем один заряд контейнера; на нуле — контейнер израсходован
	local bagLeft
	local has, bag = client:HasItem("hazard_bag")

	if (has and bag) then
		bagLeft = bag:GetData("uses", bag.uses or 10) - 1

		if (bagLeft <= 0) then
			bag:Remove()
		else
			bag:SetData("uses", bagLeft)
		end
	end

	-- сводный нотифай: сколько ещё собрать (только для зон) и заряды контейнера
	local left = (not indestructible) and self.remaining[name] or nil
	local msg = left and ("Флора собрана. Осталось очистить: " .. left) or "Флора собрана."

	if (bagLeft and bagLeft <= 0) then
		msg = msg .. ". Контейнер израсходован."
	elseif (bagLeft) then
		msg = msg .. ". Зарядов в контейнере: " .. bagLeft
	end

	client:Notify(msg)

	self:CheckCleared(name)
	self:SaveData()
end

-- Зона зачищена полностью? Собрано всё (remaining == 0) и флоры в мире не осталось —
-- убираем зомби, чистим состояние и УДАЛЯЕМ саму зону (повторного заражения нет).
function PLUGIN:CheckCleared(name)
	local area = ix.area.stored[name]
	if (!area or area.type != "infection") then return end

	-- Неразрушимая зона (свойство indestructible в /AreaEdit): не удаляем её,
	-- сколько бы флоры ни собрали.
	if (area.properties and area.properties.indestructible) then return end

	if ((self.remaining[name] or 0) > 0) then return end
	if (countValid(self.flora[name]) > 0) then return end

	self:PurgeZombies(name)

	self.flora[name] = nil
	self.zombies[name] = nil
	self.suppressed[name] = nil
	self.nextSpawn[name] = nil
	self.remaining[name] = nil

	ix.area.Remove(name)

	-- сохраняем удаление зоны, чтобы она не вернулась после рестарта
	local areaPlugin = ix.plugin.list["area"]

	if (areaPlugin and areaPlugin.SaveData) then
		areaPlugin:SaveData()
	end

	self:SaveData()

	for _, ply in ipairs(player.GetAll()) do
		ply:Notify("Зона заражения '" .. name .. "' полностью очищена!")
	end
end

-- Нажатие E по флоре с контейнером в инвентаре запускает сбор (прогресс-бар).
function PLUGIN:CancelCollection(client)
    if not self.collections[client] then return end
    self.collections[client] = nil
    if IsValid(client) then client.ixCollectingFlora = nil; client:SetAction() end
end

function PLUGIN:PlayerActionChanged(client)
    -- Do not erase the replacement action's UI; this hook runs before it starts.
    self.collections[client] = nil
    client.ixCollectingFlora = nil
end

function PLUGIN:PlayerUse(client, entity)
    if not IsValid(entity) or not entity.ixInfectionFlora then return end
    if not client:Alive() or not client:GetCharacter() then return false end
    if self.collections[client] then return false end
    if not client:HasItem("hazard_bag") then
        if (client.ixBagNotify or 0) < CurTime() then
            client.ixBagNotify = CurTime() + 3
            client:Notify("Нужен контейнер для биоматериала.")
        end
        return false
    end
    client:SetAction(false)
    client:SetAction("Сбор заражённой флоры...", self.defaults.collectTime)
    client.ixCollectingFlora = entity
    self.collections[client] = {entity = entity, character = client:GetCharacter(), finish = CurTime() + self.defaults.collectTime}
    return false
end

function PLUGIN:CollectionTick()
    for client, action in pairs(self.collections) do
        local prop = action.entity
        if not IsValid(client) or not client:Alive() or client:GetCharacter() ~= action.character
            or not IsValid(prop) or not client:HasItem("hazard_bag") or not client:KeyDown(IN_USE)
            or client:GetPos():DistToSqr(prop:GetPos()) > self.defaults.collectRange ^ 2
            or client:GetEyeTrace().Entity ~= prop then
            self:CancelCollection(client)
        elseif CurTime() >= action.finish then
            self:CancelCollection(client)
            self:CollectFlora(prop, client)
        end
    end
end

function PLUGIN:AreaDefinitionRemoved(name)
    self:CleanFlora(name); self:PurgeZombies(name)
    self.flora[name], self.zombies[name], self.remaining[name] = nil, nil, nil
    self.suppressed[name], self.nextSpawn[name] = nil, nil
end

-- Урон по флоре: любой урон уменьшает её «здоровье»; уничтожение игроком
-- временно останавливает зарастание зоны (передышка).
function PLUGIN:EntityTakeDamage(target, dmginfo)
	if (!IsValid(target) or !target.ixInfectionFlora) then
		return
	end

	target.ixFloraHP = (target.ixFloraHP or self.defaults.floraHealth) - dmginfo:GetDamage()

	if (target.ixFloraHP > 0) then
		return
	end

	local name = target.ixInfectionFlora
	local attacker = dmginfo:GetAttacker()

	-- если разрушил игрок — даём зоне передышку от зарастания
	if (IsValid(attacker) and attacker:IsPlayer()) then
		self.suppressed[name] = CurTime() + self.defaults.suppressDuration
	end

	-- эффект разрушения
	local effect = EffectData()
	effect:SetOrigin(target:GetPos())
	effect:SetNormal(VectorRand():GetNormalized())
	util.Effect("cball_explode", effect)

	target:EmitSound("ambient/levels/canals/toxic_slime_gurgle" .. math.random(1, 3) .. ".wav", 70, math.random(90, 110))

	if (self.flora[name]) then
		self.flora[name][target] = nil
	end

	target:Remove()

	-- Burning destroys the contamination instead of generating collectible loot.
	-- Clearing all exposed growth also sterilizes the zone's dormant growth pool.
	if dmginfo:IsDamageType(DMG_BURN) or dmginfo:IsDamageType(DMG_SLOWBURN) then
		local area = ix.area.stored[name]
		if area and area.type == "infection" and not (area.properties or {}).indestructible then
			local pool = self.remaining[name] or tonumber((area.properties or {}).infestationTotal) or self.defaults.infestationTotal
			self.remaining[name] = math.max(0, pool - 1)
			if countValid(self.flora[name]) == 0 then self.remaining[name] = 0 end
			self:CheckCleared(name)
			self:SaveData()
		end
	end
end

-- Сообщения о самочувствии по мере отравления (порог -> текст). Отправляются
-- только самому отравленному игроку, по одному разу при росте уровня.
local TOXIC_MSGS = {
	{0.20, "Голова кружится, во рту металлический привкус."},
	{0.40, "Глаза слезятся, в горле першит и щиплет."},
	{0.60, "Голова раскалывается, к горлу подступает тошнота."},
	{0.85, "Вы задыхаетесь, перед глазами всё плывёт..."},
}

function PLUGIN:ToxicSymptom(ply)
	local lvl = ply.ixToxic or 0
	local last = ply.ixToxicMsg or 0

	for _, m in ipairs(TOXIC_MSGS) do
		if (lvl >= m[1] and last < m[1]) then
			ply:ChatPrint(m[2])
			ply.ixToxicMsg = m[1]
		end
	end
end

-- Обновляем «отравление» одного игрока (без урона по HP): копим уровень, пока он
-- без защиты внутри зоны; на максимуме — теряет сознание (падает на falloverTime).
function PLUGIN:UpdateToxicExposure(ply, inside, now)
	if (!ply:Alive() or !ply:GetCharacter()) then
		ply.ixToxic = 0
		ply.ixToxicMsg = nil

		if (ply:GetNWFloat("ixToxicLevel", 0) != 0) then ply:SetNWFloat("ixToxicLevel", 0) end
		if (ply:GetNWBool("ixToxicChoke", false)) then ply:SetNWBool("ixToxicChoke", false) end

		return
	end

	local resist = (ply.GetRadResistance and ply:GetRadResistance()) or 0
	local protected = resist >= self.defaults.toxicResistNeeded
	local choking = inside and not protected

	ply.ixToxic = ply.ixToxic or 0

	-- пока без сознания (ixRagdoll) — не копим, даём «отлежаться»
	local ragdolled = IsValid(ply.ixRagdoll)

	if (choking and not ragdolled) then
		ply.ixToxic = math.min(1, ply.ixToxic + 1 / self.defaults.toxicBuildTime)
		self:ToxicSymptom(ply)

		if (ply.ixToxic >= 1) then
			ply.ixToxic = 0
			ply.ixToxicMsg = nil
			ply:ChatPrint("Вы теряете сознание от отравления...")
			ply:SetRagdolled(true, self.defaults.falloverTime)
		end
	elseif (ply.ixToxic > 0) then
		ply.ixToxic = math.max(0, ply.ixToxic - self.defaults.toxicRecover / self.defaults.toxicBuildTime)

		if (ply.ixToxic == 0 and ply.ixToxicMsg) then
			ply.ixToxicMsg = nil
			ply:ChatPrint("Вы снова можете дышать свободно.")
		end
	end

	local lvl = math.Round(ply.ixToxic, 2)

	if (ply:GetNWFloat("ixToxicLevel", 0) != lvl) then
		ply:SetNWFloat("ixToxicLevel", lvl)
	end

	if (ply:GetNWBool("ixToxicChoke", false) != choking) then
		ply:SetNWBool("ixToxicChoke", choking)
	end
end

function PLUGIN:InfectionTick()
    local controller = ix.plugin.list["scp610_control"]
    local control = controller and controller.settings or {}
    local names = {}
    for _, group in ipairs({self.flora, self.zombies, self.remaining}) do for name in pairs(group) do names[name] = true end end
    for name in pairs(names) do
        local area = ix.area.stored[name]
        if name ~= "__waste" and (not area or area.type ~= "infection") then self:AreaDefinitionRemoved(name) end
    end
    for ent in pairs(self.flora.__waste or {}) do
        if IsValid(ent) and CurTime() >= (ent.ixWasteExpires or 0) then ent:Remove() end
    end
    countValid(self.flora.__waste)
	local now = CurTime()
	local inToxic = {}

	for name, area in pairs(ix.area.stored) do
		if (area.type != "infection") then continue end

		local props = area.properties or {}
		local zombieMax = math.Clamp(tonumber(props.zombieMax) or self.defaults.zombieMax, 0, 32)
		local zombieInterval = math.Clamp(tonumber(props.zombieInterval) or self.defaults.zombieInterval, 1, 3600)
		local floraMax = math.Clamp(tonumber(props.floraMax) or self.defaults.floraMax, 0, 128)
		local floraInterval = math.Clamp(tonumber(props.floraInterval) or self.defaults.floraInterval, 1, 3600)

		self.nextSpawn[name] = self.nextSpawn[name] or {zombie = 0, flora = 0, lastNear = 0}
		local ns = self.nextSpawn[name]

		-- сколько ещё нужно собрать в этой зоне (засеваем при первом тике/после загрузки)
		if (self.remaining[name] == nil) then
			self.remaining[name] = math.Clamp(tonumber(props.infestationTotal) or self.defaults.infestationTotal, 1, 10000)
		end

		local remaining = self.remaining[name]

		-- кто сейчас внутри этой зоны (для смога)
		for _, ply in ipairs(player.GetAll()) do
			if (control.zoneGas ~= false and ply:Alive() and ix.area.Contains(area, ply:GetPos() + ply:OBBCenter())) then
				inToxic[ply] = true
			end
		end

		if (hasPlayerNear(area, self.defaults.activeRadius)) then
			ns.lastNear = now

			local suppressed = self.suppressed[name]
			local canGrow = not control.paused and control.zoneGrowth ~= false and (!suppressed or now >= suppressed)

			-- флора разрастается, но не больше, чем осталось собрать (remaining):
			-- по мере сбора пул сокращается, и в итоге зона зачищается полностью.
			-- Неразрушимая зона игнорирует remaining и зарастает всегда (до floraMax).
			local indestructible = props.indestructible
			local floraCap = indestructible and floraMax or math.min(floraMax, remaining)

			if (canGrow and (indestructible or remaining > 0) and now >= ns.flora and countValid(self.flora[name]) < floraCap) then
				spawnFlora(name, area)
				ns.flora = now + floraInterval
			end

			-- поддерживаем популяцию зомби
			if (not control.paused and control.zoneNPCs ~= false and now >= ns.zombie and countValid(self.zombies[name]) < zombieMax) then
				spawnZombie(name, area)
				ns.zombie = now + zombieInterval
			end
		else
			-- игроков рядом нет — убираем зомби, чтобы они не бродили по пустой карте
			if (ns.lastNear > 0 and (now - ns.lastNear) > self.defaults.despawnDelay
				and countValid(self.zombies[name]) > 0) then
				self:PurgeZombies(name)
			end
		end
	end

	-- обновляем флаг смога и отравление у игроков
	for _, ply in ipairs(player.GetAll()) do
		local val = inToxic[ply] == true

		if (ply:GetNetVar("ixInToxicZone") != val) then
			ply:SetNetVar("ixInToxicZone", val)
		end

		self:UpdateToxicExposure(ply, val, now)
	end
end

function PLUGIN:InfectionInit()
    self.validFloraModels = {}
    for _, model in ipairs(self.floraModels) do
        if util.IsValidModel(model) then self.validFloraModels[#self.validFloraModels + 1] = model end
    end
    if #self.validFloraModels == 0 then self.validFloraModels[1] = "models/props_junk/garbage_bag001a.mdl" end
	-- прекэшим модели флоры и предметов сбора
	for _, model in ipairs(self.validFloraModels) do
		util.PrecacheModel(model)
	end

	if util.IsValidModel(self.bagModel) then util.PrecacheModel(self.bagModel) end
	if util.IsValidModel(self.trashModel) then util.PrecacheModel(self.trashModel) end

	-- подчищаем возможный мусор от прошлой сессии/перезагрузки
	for _, ent in ipairs(ents.GetAll()) do
		if (ent.ixInfectionFlora or ent.ixInfectionZone) then
			ent:Remove()
		end
	end

	self.zombies = {}
	self.flora = {}
	self.suppressed = {}
	self.nextSpawn = {}
	self.remaining = self.remaining or {} -- прогресс сбора сохраняется (см. LoadData)
end

-- Сохраняем прогресс сбора (remaining) по зонам, чтобы он пережил рестарт.
function PLUGIN:SaveData()
	self:SetData(self.remaining)
end

function PLUGIN:LoadData()
	self.remaining = self:GetData() or {}
end

function PLUGIN:InitPostEntity()
	self:InfectionInit()
end

-- Инициализируемся и при обычной загрузке файла (важно для lua_reload, когда InitPostEntity не срабатывает).
PLUGIN:InfectionInit()

timer.Create("ixInfectionTick", 1, 0, function()
	if (PLUGIN.InfectionTick) then
		PLUGIN:InfectionTick()
	end
end)

function PLUGIN:PlayerLoadedCharacter(client)
    self:CancelCollection(client)
    client.ixToxic, client.ixToxicMsg = 0, nil
    client:SetNWFloat("ixToxicLevel", 0); client:SetNWBool("ixToxicChoke", false)
end
function PLUGIN:PlayerDeath(client) self:PlayerLoadedCharacter(client) end
function PLUGIN:PlayerDisconnected(client) self:CancelCollection(client) end
function PLUGIN:CleanupRuntime()
    self.unloading = true
    timer.Remove("ixInfectionTick"); timer.Remove("ixInfectionCollect")
    for client in pairs(self.collections or {}) do self:CancelCollection(client) end
    for _, group in pairs(self.flora or {}) do removeAll(group) end
    for _, group in pairs(self.zombies or {}) do removeAll(group) end
    for _, client in ipairs(player.GetAll()) do
        client.ixToxic, client.ixToxicMsg = 0, nil
        client:SetNWFloat("ixToxicLevel", 0); client:SetNWBool("ixToxicChoke", false)
        client:SetNetVar("ixInToxicZone", false)
    end
end
function PLUGIN:OnUnload() self:SaveData(); self:CleanupRuntime() end
 timer.Create("ixInfectionCollect", .1, 0, function() PLUGIN:CollectionTick() end)
