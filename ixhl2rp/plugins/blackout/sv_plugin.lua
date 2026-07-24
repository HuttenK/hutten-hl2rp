local PLUGIN = PLUGIN

util.AddNetworkString("ixBlackoutSync")

PLUGIN.zones     = PLUGIN.zones     or {} -- [name] = { min = Vector, max = Vector, active = bool }
PLUGIN.staging   = PLUGIN.staging   or {} -- [client] = { corner1, corner2 }
PLUGIN.fuseboxes = PLUGIN.fuseboxes or {} -- list of ix_blackout_fusebox entities

-- Switchable / dynamic light entities we can actually control at runtime.
-- NOTE: baked (unnamed) lights are removed after map load and CANNOT be
-- toggled — those are covered by the client-side darkening layer instead.
local LIGHT_CLASSES = {
	["light"]                = true,
	["light_spot"]           = true,
	["light_dynamic"]        = true,
	["point_spotlight"]      = true,
	["env_projectedtexture"] = true,
	["env_lightglow"]        = true,
}

local function OrderBox(a, b)
	return Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)),
	       Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
end

-- Комбайновские силовые поля внутри зоны. При обесточивании поле гаснет и
-- становится проходимым — как в режиме 3 (выключено), но НЕ трогая настроенный
-- админом режим: он восстанавливается вместе с питанием.
function PLUGIN:SetZoneForcefields(zone, bOn)
	for _, ff in ipairs(ents.FindByClass("ix_forcefield")) do
		if (!ff:GetPos():WithinAABox(zone.min, zone.max)) then continue end

		if (!bOn) then
			-- Уже обесточено — второй раз не выключаем (и не помним "off" как исходное).
			if (ff.ixBlackoutOff) then continue end

			ff.ixBlackoutOff = true
			ff.ixBlackoutWasOn = ff.on

			if (ff.on) then
				ff.on = false
				ff:SetSkin(1)
				if (IsValid(ff.post)) then ff.post:SetSkin(1) end
				ff:SetCollisionGroup(COLLISION_GROUP_WORLD)
				ff:EmitSound("shield/deactivate.wav")
			end
		elseif (ff.ixBlackoutOff) then
			ff.ixBlackoutOff = nil

			-- Поле, выключенное админом до блэкаута, остаётся выключенным.
			if (ff.ixBlackoutWasOn) then
				ff.on = true
				ff:SetSkin(0)
				if (IsValid(ff.post)) then ff.post:SetSkin(0) end
				ff:SetCollisionGroup(COLLISION_GROUP_NONE)
				ff:EmitSound("shield/activate.wav")
			end

			ff.ixBlackoutWasOn = nil
		end
	end
end

-- Turn switchable lights inside a zone off (bOn = false) or on (bOn = true).
-- Заодно это единственная точка переключения питания зоны: сюда же повешены
-- силовые поля, чтобы не дублировать вызовы по всем местам смены состояния.
function PLUGIN:SetZoneLights(zone, bOn)
	for _, e in ipairs(ents.FindInBox(zone.min, zone.max)) do
		if LIGHT_CLASSES[e:GetClass()] then
			e:Fire(bOn and "TurnOn" or "TurnOff")
		end
	end

	self:SetZoneForcefields(zone, bOn)
end

--
-- Circuit box (fusebox) repair system.
--

-- IsPosBlackedOut / IsEntityBlackedOut объявлены в sh_plugin.lua: клиенту они
-- нужны для гашения экранов терминалов и телевизоров.

-- Обесточенное оборудование не реагирует на E. Серверная проверка — основная:
-- клиентские подавления меню лишь убирают лишний интерфейс.
function PLUGIN:PlayerUse(client, entity)
	-- Замок обесточивается сам по себе (см. ENT:Toggle) — здесь дверь НЕ подменяем на
	-- замок: иначе незапертую дверь с замком нельзя было бы открыть в темноте. Сама
	-- дверь не «питается», поэтому её использование блэкаут не трогает.
	if (!self:IsEntityBlackedOut(entity)) then return end

	-- E удерживают — уведомление не должно сыпаться каждый кадр.
	if ((client.ixBlackoutNotify or 0) < CurTime()) then
		client.ixBlackoutNotify = CurTime() + 2
		client:NotifyLocalized("blackout.noPower")
	end

	return false
end

local function BoxVolume(zone)
	local size = zone.max - zone.min

	return size.x * size.y * size.z
end

-- Зоны вкладываются друг в друга: общегородская накрывает поздания, у каждого из
-- которых своя. Точка принадлежит САМОЙ ТЕСНОЙ зоне, которая её содержит — так
-- щиток внутри дома управляет только домом, а не городом заодно.
function PLUGIN:GetOwningZone(pos)
	local best, bestVolume

	for _, z in pairs(self.zones) do
		if (!pos:WithinAABox(z.min, z.max)) then continue end

		local volume = BoxVolume(z)

		if (!bestVolume or volume < bestVolume) then
			best, bestVolume = z, volume
		end
	end

	return best
end

-- Валидные щитки, ПРИНАДЛЕЖАЩИЕ зоне (заодно чистим невалидные ссылки).
-- Щиток внутри вложенной зоны сюда не попадает — он принадлежит ей, а не этой.
function PLUGIN:BoxesInZone(zone)
	local t = {}

	for i = #self.fuseboxes, 1, -1 do
		local box = self.fuseboxes[i]

		if (!IsValid(box)) then
			table.remove(self.fuseboxes, i)
		elseif (self:GetOwningZone(box:GetPos()) == zone) then
			t[#t + 1] = box
		end
	end

	return t
end

-- Насильно выставить состояние всех щитков зоны (для админ-команд).
function PLUGIN:SetZoneBoxes(zone, broken)
	for _, box in ipairs(self:BoxesInZone(zone)) do
		box:SetBroken(broken)
	end
end

-- Пересчитать питание зон ИЗ состояния щитков (с гистерезисом):
--   • зона гаснет, только когда СЛОМАНЫ ВСЕ её щитки (диверсия);
--   • зона зажигается, только когда ПОЧИНЕНЫ ВСЕ её щитки (ремонт);
--   • промежуточное состояние (часть сломана) — не меняем.
-- Зоны без щитков управляются только админ-командами и здесь не трогаются.
function PLUGIN:RecomputeZones()
	local changed = false

	for _, z in pairs(self.zones) do
		local boxes = self:BoxesInZone(z)
		if (#boxes == 0) then continue end

		local allBroken, allWorking = true, true
		for _, b in ipairs(boxes) do
			if (b:GetBroken()) then allWorking = false else allBroken = false end
		end

		if (z.active and allWorking) then
			z.active = false
			self:SetZoneLights(z, true)
			changed = true
		elseif (!z.active and allBroken) then
			z.active = true
			self:SetZoneLights(z, false)
			changed = true
		end
	end

	if (changed) then
		self:NetworkZones()
		self:SaveData()
	end

	return changed
end

--
-- Electric shock — punishment for touching a box without the required skill.
--

-- Разряд молний по игроку + искры (визуал).
local function electricArc(client)
	if (!IsValid(client)) then return end

	local center = client:WorldSpaceCenter()

	local arc = EffectData()
		arc:SetEntity(client)
		arc:SetOrigin(center)
		arc:SetMagnitude(2)
		arc:SetScale(1)
		arc:SetRadius(12)
	util.Effect("TeslaHitBoxes", arc) -- дуги молний по хитбоксам игрока

	local sp = EffectData()
		sp:SetOrigin(center)
		sp:SetNormal(VectorRand():GetNormalized())
		sp:SetMagnitude(3)
		sp:SetScale(2)
		sp:SetRadius(4)
	util.Effect("Sparks", sp)
end

-- Ударить игрока током: нокаут на shockDuration секунд + электро-эффекты.
function PLUGIN:ElectricShock(client, box)
	if (!IsValid(client) or !client:GetCharacter()) then return end

	if (IsValid(box)) then
		box:EmitSound("ambient/energy/spark6.wav", 72)
	end
	client:EmitSound("ambient/energy/zap1.wav", 78, math.random(90, 110))

	electricArc(client)

	-- роняем персонажа (нокаут)
	client:SetRagdolled(true, self.shockDuration)

	-- продолжаем искрить, пока лежит без сознания
	local id = "ixBlackoutShock" .. client:EntIndex()
	timer.Create(id, 0.7, math.max(1, math.floor(self.shockDuration / 0.7)), function()
		if (!IsValid(client)) then
			timer.Remove(id)
			return
		end

		electricArc(client)
	end)

	client:Notify("Вас ударило током! Не хватает навыка «Электроника».")
end

-- Проверка навыка «Электроника» при работе со щитком. Возвращает true, если можно
-- продолжать. При нехватке навыка есть шанс shockChance получить разряд (нокаут),
-- иначе — обычный отказ.
function PLUGIN:CheckElectricSkill(client, box, needed)
	local character = client:GetCharacter()
	if (!character) then return false end

	if (character:GetSkillModified("electric") >= needed) then
		return true
	end

	if (math.random() < self.shockChance) then
		self:ElectricShock(client, box)
	else
		client:Notify("Требуется навык «Электроника» " .. needed .. " уровня.")
	end

	return false
end

-- Hold-E repair interaction (called from the entity's Use).
function PLUGIN:TryRepair(client, box)
	if (!IsValid(client) or !IsValid(box)) then return end

	if (box.ixRepairing) then
		if (box.ixRepairing != client and (client.ixFuseNotify or 0) < CurTime()) then
			client.ixFuseNotify = CurTime() + 3
			client:Notify("Кто-то уже чинит электрощит.")
		end

		return
	end

	if (!box:GetBroken()) then
		client:Notify("Этот электрощит исправен — чинить нечего.")
		return
	end

	local character = client:GetCharacter()
	if (!character) then return end

	if (!client:HasItem("wm_screwdriver")) then
		client:Notify("Нужна отвёртка, чтобы вскрыть и починить электрощит.")
		return
	end

	if (!self:CheckElectricSkill(client, box, self.repairSkill)) then
		return
	end

	box.ixRepairing = client
	box:StartSparks(self.repairTime)

	client:SetAction("Ремонт электрощита...", self.repairTime)
	client:DoStaredAction(box, function()
		if (IsValid(box)) then
			box.ixRepairing = nil
			box:StopSparks()
		end

		if (!IsValid(client) or !IsValid(box)) then return end

		if (!client:HasItem("wm_screwdriver")) then
			client:Notify("Ремонт прерван: нет отвёртки.")
			return
		end

		if (box:GetBroken()) then
			box:SetBroken(false)
			box:EmitSound("buttons/button1.wav")
			self:RecomputeZones()
			self:SaveFuseboxes()

			-- Судим по СВОЕЙ зоне щитка: под общегородским блэкаутом IsPosBlackedOut
			-- всегда true, и починка последнего щитка в доме врала бы про «остались».
			local zone = self:GetOwningZone(box:GetPos())

			if (zone and zone.active) then
				client:Notify("Электрощит починен, но в зоне остались повреждённые щитки.")
			else
				client:Notify("Электрощит починен. Свет снова включён.")
			end

			if (client:GetCharacter()) then
				client:GetCharacter():UpdateSkillProgress("electric", self.repairXP)
			end
		else
			client:Notify("Электрощит уже исправен.")
		end
	end, self.repairTime, function()
		if (IsValid(box)) then
			box.ixRepairing = nil
			box:StopSparks()
		end

		if (IsValid(client)) then
			client:SetAction()
			client:Notify("Ремонт прерван.")
		end
	end, 150)
end

--
-- Fusebox sabotage — two ways to trigger a blackout:
--   • ЭМИ-инструмент  — мгновенно, без навыков (наведи и активируй);
--   • отвёртка (E)    — с прогресс-баром, требует навык «Электроника» breakSkill.
--

-- Общий эффект вывода щитка из строя (после всех проверок).
function PLUGIN:ApplyBreak(client, box, xp)
	box:SetBroken(true)
	box:EmitSound("ambient/energy/spark6.wav", 70)
	self:RecomputeZones()
	self:SaveFuseboxes()

	local zone = self:GetOwningZone(box:GetPos())

	if (zone and zone.active) then
		client:Notify("Электрощит выведен из строя. Электричество отключено.")
	else
		client:Notify("Электрощит выведен из строя. В зоне ещё остались рабочие щитки.")
	end

	if (xp and xp > 0 and client:GetCharacter()) then
		client:GetCharacter():UpdateSkillProgress("electric", xp)
	end
end

-- ЭМИ-инструмент: мгновенно, без навыков. Вызывается из обработчика emp_hack.
function PLUGIN:TryBreakEMP(client, box)
	if (!IsValid(client) or !IsValid(box)) then return false end

	if (box:GetBroken()) then
		client:Notify("Этот электрощит уже выведен из строя.")
		return false
	end

	self:ApplyBreak(client, box, 0) -- без опыта: моментальный ЭМИ-саботаж
	return true
end

-- Отвёртка: удержание E с прогресс-баром (как ремонт), требует навык «Электроника».
function PLUGIN:TryBreakScrewdriver(client, box)
	if (!IsValid(client) or !IsValid(box)) then return end

	if (box.ixRepairing) then
		if (box.ixRepairing != client and (client.ixFuseNotify or 0) < CurTime()) then
			client.ixFuseNotify = CurTime() + 3
			client:Notify("Кто-то уже работает с электрощитом.")
		end

		return
	end

	if (box:GetBroken()) then
		client:Notify("Этот электрощит уже выведен из строя.")
		return
	end

	local character = client:GetCharacter()
	if (!character) then return end

	if (!client:HasItem("wm_screwdriver")) then
		client:Notify("Нужна отвёртка, чтобы вскрыть и вывести из строя электрощит.")
		return
	end

	if (!self:CheckElectricSkill(client, box, self.breakSkill)) then
		return
	end

	box.ixRepairing = client
	box:StartSparks(self.breakTime)

	client:SetAction("Саботаж электрощита...", self.breakTime)
	client:DoStaredAction(box, function()
		if (IsValid(box)) then
			box.ixRepairing = nil
			box:StopSparks()
		end

		if (!IsValid(client) or !IsValid(box)) then return end

		if (!client:HasItem("wm_screwdriver")) then
			client:Notify("Прервано: нет отвёртки.")
			return
		end

		if (!box:GetBroken()) then
			self:ApplyBreak(client, box, self.breakXP)
		end
	end, self.breakTime, function()
		if (IsValid(box)) then
			box.ixRepairing = nil
			box:StopSparks()
		end

		if (IsValid(client)) then
			client:SetAction()
			client:Notify("Саботаж прерван.")
		end
	end, 150)
end

-- Регистрируем щиток как цель ЭМИ-инструмента. emp_hack грузится ПОСЛЕ blackout
-- (по алфавиту), поэтому делаем это в InitPostEntity, когда все плагины загружены.
function PLUGIN:RegisterEmpHandler()
	local emp = ix.plugin.list and ix.plugin.list["emp_hack"]

	if (emp and istable(emp.handlers)) then
		emp.handlers["ix_blackout_fusebox"] = function(ent, hacker)
			PLUGIN:TryBreakEMP(hacker, ent)
			-- Возвращаем nil: TryBreakEMP сам уведомляет игрока.
		end
	end
end

function PLUGIN:InitPostEntity()
	self:RegisterEmpHandler()
end

--
-- Fusebox spawning & persistence.
--

function PLUGIN:SpawnFusebox(pos, ang, broken, bNoSave)
	local box = ents.Create("ix_blackout_fusebox")

	if (!IsValid(box)) then return end

	box:SetPos(pos)
	box:SetAngles(ang or Angle(0, 0, 0))
	box:Spawn()
	box:Activate()

	self.fuseboxes[#self.fuseboxes + 1] = box

	-- Свежая установка: состояние берём по СВОЕЙ зоне щитка (самой тесной из тех,
	-- что его накрывают). Загрузка из сейва: восстанавливаем сохранённое состояние.
	if (broken == nil) then
		local zone = self:GetOwningZone(pos)
		broken = (zone != nil and zone.active) or false
	end
	box:SetBroken(broken)
	box.ixLastSavePos = box:GetPos()

	if (!bNoSave) then
		self:SaveFuseboxes()
	end

	return box
end

function PLUGIN:SaveFuseboxes()
	-- Не перезаписываем файл, пока не отработала первичная загрузка: иначе любой
	-- ранний вызов (удаление/физган в первые мгновения после старта карты) сохранит
	-- пустой список и сотрёт сохранённые щитки этой карты.
	if (!self.fuseboxesLoaded) then return end

	local out = {}

	for _, box in ipairs(self.fuseboxes) do
		if (IsValid(box)) then
			out[#out + 1] = { pos = box:GetPos(), ang = box:GetAngles(), broken = box:GetBroken() }
			box.ixLastSavePos = box:GetPos()
		end
	end

	ix.data.Set("blackout_fuseboxes", out)
end

function PLUGIN:LoadFuseboxes()
	self.fuseboxes = {}

	for _, v in ipairs(ix.data.Get("blackout_fuseboxes") or {}) do
		self:SpawnFusebox(v.pos, v.ang, v.broken, true)
	end

	-- С этого момента SaveFuseboxes разрешён (первичная загрузка завершена).
	self.fuseboxesLoaded = true
end

-- Command helpers.
function PLUGIN:PlaceFusebox(client)
	local tr = client:GetEyeTrace()

	if (!tr.Hit) then
		return "Look at a surface to place the circuit box."
	end

	local ang = (client:GetPos() - tr.HitPos):Angle()
	ang.p = 0
	ang.r = 0

	local box = self:SpawnFusebox(tr.HitPos, ang)

	if (!IsValid(box)) then
		return "Failed to create the circuit box."
	end

	return "Circuit box placed. It is repairable while its zone is blacked out."
end

function PLUGIN:RemoveFusebox(client)
	local ent = client:GetEyeTrace().Entity

	if (!IsValid(ent) or !ent.ixBlackoutFusebox) then
		return "Look at a circuit box to remove it."
	end

	ent:Remove()

	return "Circuit box removed."
end

-- Send the currently-active zone volumes to client(s) for screen darkening.
function PLUGIN:NetworkZones(receiver)
	local active = {}

	for _, z in pairs(self.zones) do
		if z.active then
			active[#active + 1] = z
		end
	end

	net.Start("ixBlackoutSync")
		net.WriteUInt(#active, 8)
		for _, z in ipairs(active) do
			net.WriteVector(z.min)
			net.WriteVector(z.max)
		end
	if IsValid(receiver) then
		net.Send(receiver)
	else
		net.Broadcast()
	end
end

function PLUGIN:SaveData()
	local out = {}

	for name, z in pairs(self.zones) do
		out[name] = { min = z.min, max = z.max, active = z.active }
	end

	ix.data.Set("blackout", out)
end

function PLUGIN:LoadData()
	self.zones = ix.data.Get("blackout") or {}

	-- Щитки — это просто размещённые сущности и не зависят от карты света, поэтому
	-- грузим их сразу. Так закрывается окно, в котором self.fuseboxes ещё пуст, а
	-- SaveFuseboxes мог бы затереть файл пустым списком.
	self:LoadFuseboxes()

	-- Re-assert active blackouts once map entities exist (switchable lights
	-- spawn enabled by default after a map load).
	timer.Simple(1, function()
		for _, z in pairs(self.zones) do
			if z.active then
				self:SetZoneLights(z, false)
			end
		end

		self:NetworkZones()
	end)
end

-- Персистентность позиции щитков. SaveFuseboxes раньше вызывался только при
-- установке/удалении, поэтому переставленный админ-инструментами щиток после
-- рестарта возвращался на место спавна. Сохраняем при выключении сервера и
-- периодически, если позиция изменилась.
function PLUGIN:ShutDown()
	self:SaveFuseboxes()
end

function PLUGIN:PhysgunDrop(client, ent)
	if (IsValid(ent) and ent.ixBlackoutFusebox) then
		self:SaveFuseboxes()
	end
end

timer.Create("ixBlackoutFuseboxAutosave", 30, 0, function()
	if (!PLUGIN or !istable(PLUGIN.fuseboxes)) then return end

	for _, box in ipairs(PLUGIN.fuseboxes) do
		if (IsValid(box) and (!box.ixLastSavePos or box.ixLastSavePos:DistToSqr(box:GetPos()) > 1)) then
			PLUGIN:SaveFuseboxes()
			return
		end
	end
end)

-- Make sure late-joiners receive the active zones.
function PLUGIN:PlayerLoadedCharacter(client)
	timer.Simple(1, function()
		if IsValid(client) then
			self:NetworkZones(client)
		end
	end)
end

--
-- Command logic (called from the shared command layer; runs server-side only).
--

function PLUGIN:MarkCorner(client)
	local pos = client:GetEyeTrace().HitPos
	local s = self.staging[client] or {}

	if not s[1] then
		s[1] = pos
	else
		s[2] = pos
	end

	self.staging[client] = s

	if s[1] and s[2] then
		return "Both corners marked. Use /BlackoutCreate <name> [height]."
	end

	return "First corner marked. Look at the opposite corner and run this again."
end

function PLUGIN:CreateZone(client, name, height)
	local s = self.staging[client]

	if not (s and s[1] and s[2]) then
		return "Mark two corners first with /BlackoutCorner."
	end

	if self.zones[name] then
		return "A blackout zone named '" .. name .. "' already exists."
	end

	-- Коробка должна перекрывать самую высокую стену внутри зоны: там, где верхняя
	-- грань режет стену, на ней остаётся горизонтальная полоса затемнения.
	height = math.max(tonumber(height) or 1024, 0)

	local mn, mx = OrderBox(s[1], s[2])
	mn = mn - Vector(0, 0, 32)     -- small floor margin
	mx = mx + Vector(0, 0, height) -- extend up to cover the building

	local zone = { min = mn, max = mx, active = true }
	self.zones[name] = zone
	self.staging[client] = nil

	self:SetZoneLights(zone, false)
	self:SetZoneBoxes(zone, true) -- любые щитки уже внутри новой (тёмной) зоны — сломаны
	self:NetworkZones()
	self:SaveData()
	self:SaveFuseboxes()

	return "Blackout zone '" .. name .. "' created and activated."
end

function PLUGIN:ToggleZone(name)
	local zone = self.zones[name]

	if not zone then
		return "No blackout zone named '" .. name .. "'."
	end

	zone.active = not zone.active
	self:SetZoneLights(zone, not zone.active) -- active -> lights off
	self:SetZoneBoxes(zone, zone.active)      -- синхронизируем щитки с ручным переключением
	self:NetworkZones()
	self:SaveData()
	self:SaveFuseboxes()

	return "Blackout zone '" .. name .. "' is now " .. (zone.active and "ON" or "OFF") .. "."
end

function PLUGIN:RemoveZone(name)
	local zone = self.zones[name]

	if not zone then
		return "No blackout zone named '" .. name .. "'."
	end

	self:SetZoneLights(zone, true) -- restore lights
	self:SetZoneBoxes(zone, false) -- щитки удаляемой зоны считаем рабочими
	self.zones[name] = nil
	self:NetworkZones()
	self:SaveData()
	self:SaveFuseboxes()

	return "Blackout zone '" .. name .. "' removed."
end

function PLUGIN:ListZones(client)
	local any = false

	for name, z in pairs(self.zones) do
		any = true
		client:ChatPrint(string.format("%s — %s", name, z.active and "ON" or "OFF"))
	end

	if not any then
		return "No blackout zones defined."
	end
end

-- Clean up staging if an admin disconnects mid-selection.
function PLUGIN:PlayerDisconnected(client)
	self.staging[client] = nil
end
