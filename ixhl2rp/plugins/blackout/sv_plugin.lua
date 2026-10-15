local PLUGIN = PLUGIN
PLUGIN.unloading = false

util.AddNetworkString("ixBlackoutSync3")
util.AddNetworkString("ixBlackoutElectronics")

PLUGIN.zones     = PLUGIN.zones     or {} -- [name] = { min = Vector, max = Vector, active = bool }
PLUGIN.staging   = PLUGIN.staging   or {} -- [client] = { corner1, corner2 }
PLUGIN.fuseboxes = PLUGIN.fuseboxes or {} -- list of ix_blackout_fusebox entities

-- Switchable / dynamic light entities we can actually control at runtime.
-- NOTE: baked (unnamed) lights are removed after map load and CANNOT be
-- toggled — those are covered by the client-side darkening layer instead.
local LIGHT_CLASSES = {
	-- Baked light styles can affect surfaces across the map. The client volume
	-- mask handles those; only independent runtime lights are switched here.
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
PLUGIN.lightStates = PLUGIN.lightStates or setmetatable({}, {__mode = "k"})

local function lightState(ent)
    local t = ent:GetSaveTable() or {}
    for _, key in ipairs({"m_bState", "m_bSpotlightOn", "m_bOn"}) do
        if t[key] ~= nil then return t[key] == true or t[key] == 1 end
    end
    if ent.ixLightDesired ~= nil then return ent.ixLightDesired end
    -- Named baked lights use the START_OFF spawnflag. Unknown entities are
    -- left alone rather than forcing an originally disabled light on later.
    if ent:GetClass() == "light" or ent:GetClass() == "light_spot" then
        return bit.band(tonumber(ent:GetKeyValues().spawnflags) or 0, 1) == 0
    end
end

function PLUGIN:RefreshLights()
    for _, ent in ipairs(ents.GetAll()) do
        if LIGHT_CLASSES[ent:GetClass()] or self.lightStates[ent] then
            local off = LIGHT_CLASSES[ent:GetClass()] and not self.unloading and (self.IsElectronicsOffAt or self.IsPosBlackedOut)(self, ent:GetPos())
            local saved = self.lightStates[ent]
            if off and not saved then
                local on = lightState(ent)
                if on ~= nil then
                    saved = {on = on}
                    self.lightStates[ent] = saved
                    self.applyingLight = true
                    ent:Input(ent:GetClass() == "point_spotlight" and "LightOff" or "TurnOff")
                    self.applyingLight = nil
                end
            elseif not off and saved then
                self.lightStates[ent] = nil
                ent.ixLightDesired = saved.on
                self.applyingLight = true
                local spot = ent:GetClass() == "point_spotlight"
                ent:Input(saved.on and (spot and "LightOn" or "TurnOn") or (spot and "LightOff" or "TurnOff"))
                self.applyingLight = nil
            end
        end
    end
end

function PLUGIN:RefreshBoxPower()
    for _, box in ipairs(self.fuseboxes) do
        if IsValid(box) and box.SetNoPower then
            box:SetNoPower(not self.unloading and self:IsPosBlackedOut(box:GetPos()) or false)
        end
    end
end

function PLUGIN:AcceptInput(ent, input)
    if self.applyingLight or not LIGHT_CLASSES[ent:GetClass()] then return end
    local saved = self.lightStates[ent]
    input = string.lower(input)
    if not saved then
        if (input == "turnon" or input == "lighton") then ent.ixLightDesired = true
        elseif (input == "turnoff" or input == "lightoff") then ent.ixLightDesired = false
        elseif input == "toggle" then
            local on = lightState(ent)
            if on ~= nil then ent.ixLightDesired = not on end
        end
        return
    end
    if (input == "turnon" or input == "lighton") then saved.on = true return true end
    if (input == "turnoff" or input == "lightoff") then saved.on = false return true end
    if input == "toggle" then saved.on = not saved.on return true end
end

function PLUGIN:SetZoneForcefields()
    ix.DevicePower.RefreshAll()
end

function PLUGIN:SetZoneLights()
    self:RefreshLights()
    self:RefreshBoxPower()
    self:SetZoneForcefields()
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

-- A previously opened context menu still reaches this server-side check.
function PLUGIN:CanPlayerInteractEntity(client, entity)
	return self:PlayerUse(client, entity)
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

		if z.remoteIsolation then
            local previous=z.remotePrevious
            if allWorking then z.remotePrevious=false elseif allBroken then z.remotePrevious=true end
            if previous~=z.remotePrevious then changed=true end
        elseif (z.active and allWorking) then
			z.active = false
			changed = true
		elseif (!z.active and allBroken) then
			z.active = true
			changed = true
		end
	end

	if (changed) then
        self:SetZoneLights()
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

function PLUGIN:HasScrewdriver(client)
	return client:GetCharacter() and client.inventories and
		(client:HasItem("tool_screw"))
end

-- Repair interaction (called from the entity's Use).
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

	if (!self:HasScrewdriver(client)) then
		client:Notify("Нужна отвёртка, чтобы вскрыть и починить электрощит.")
		return
	end

	if (!self:CheckElectricSkill(client, box, self.repairSkill)) then
		return
	end

	return self:BeginFuseboxCalibration(client, box, false)
end

function PLUGIN:BeginFuseboxCalibration(client, box, sabotage)
 local facility = ix.plugin.list.facility_utilities
 if not facility or not facility.BeginFuseboxWork then
  client:Notify("Модуль ремонта недоступен. Обратитесь к администратору.")
  return false
 end
 local ok, message = facility:BeginFuseboxWork(client, box, sabotage)
 if not ok and message then client:Notify(message) end
 return ok
end

function PLUGIN:ApplyRepair(client, box)
 box:SetBroken(false)
 box:EmitSound("buttons/button1.wav")
 self:RecomputeZones()
 self:SaveFuseboxes()
 local zone = self:GetOwningZone(box:GetPos())
 if zone and zone.remoteIsolation then
  client:Notify("Электрощит починен. Цепь изолирована с терминала.")
 elseif zone and zone.active then
  client:Notify("Электрощит починен, но в зоне остались повреждённые щитки.")
 else
  client:Notify("Электрощит починен. Свет снова включён.")
 end
 if client:GetCharacter() then client:GetCharacter():UpdateSkillProgress("electric", self.repairXP) end
end

--
-- Fusebox sabotage — two ways to trigger a blackout:
--   • ЭМИ-инструмент  — мгновенно, без навыков (наведи и активируй);
--   • отвёртка (E)    — мини-игра, требует навык «Электроника» breakSkill.
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

-- Отвёртка: мини-игра с пятью контактами (как ремонт), требует навык «Электроника».
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

	if (!self:HasScrewdriver(client)) then
		client:Notify("Нужна отвёртка, чтобы вскрыть и вывести из строя электрощит.")
		return
	end

	if (!self:CheckElectricSkill(client, box, self.breakSkill)) then
		return
	end

	return self:BeginFuseboxCalibration(client, box, true)
end

-- Регистрируем щиток как цель ЭМИ-инструмента. emp_hack грузится ПОСЛЕ blackout
-- (по алфавиту), поэтому делаем это в InitPostEntity, когда все плагины загружены.
function PLUGIN:RegisterEmpHandler()
	local emp = ix.plugin.list and ix.plugin.list["emp_hack"]

	if (emp and istable(emp.handlers)) then
		emp.handlers["ix_blackout_fusebox"] = function(ent, hacker)
			return PLUGIN:TryBreakEMP(hacker, ent)
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
	box:SetNoPower(self:IsPosBlackedOut(pos))
	box.ixLastSavePos = box:GetPos()
		box.ixLastSaveAng = box:GetAngles()

	if (!bNoSave) then
		self:SaveFuseboxes()
	end

	return box
end

function PLUGIN:SaveFuseboxes()
	-- Не перезаписываем файл, пока не отработала первичная загрузка: иначе любой
	-- ранний вызов (удаление/физган в первые мгновения после старта карты) сохранит
	-- пустой список и сотрёт сохранённые щитки этой карты.
	if (!self.fuseboxesLoaded or self.unloading) then return end
	self:RecomputeZones()

	local out = {}

	for _, box in ipairs(self.fuseboxes) do
		if (IsValid(box)) then
			out[#out + 1] = { pos = box:GetPos(), ang = box:GetAngles(), broken = box:GetBroken() }
			box.ixLastSavePos = box:GetPos()
		box.ixLastSaveAng = box:GetAngles()
		end
	end

	ix.data.Set("blackout_fuseboxes", out)
end

function PLUGIN:LoadFuseboxes()
    if self.fuseboxesLoaded then return end
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

	if (!tr.Hit or tr.HitSky) then
		return "Look at a surface to place the circuit box."
	end

	local ang = (client:GetPos() - tr.HitPos):Angle()
	ang.p = 0
	ang.r = 0
	local pos = tr.HitPos
	if (math.abs(tr.HitNormal.z) < 0.2) then
		-- Cabinet centre follows the crosshair; the post extends below it.
		ang = tr.HitNormal:Angle(); ang.p = 0; ang.r = 0
		pos = pos + tr.HitNormal * 2.5 - Vector(0, 0, 54)
	else
		pos = pos + tr.HitNormal * 0.5
	end

	local box = self:SpawnFusebox(pos, ang)

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
	-- Send raw exceptions separately; the visual volumes below can be split by
	-- nested circuits or generator backup and must not redefine the admin rule.
	net.Start("ixBlackoutElectronics")
		net.WriteBool(self.electronicsRestricted == true and not self.unloading)
		net.WriteUInt(#active, 16)
		for _, z in ipairs(active) do net.WriteVector(z.min); net.WriteVector(z.max) end
	if IsValid(receiver) then net.Send(receiver) else net.Broadcast() end
	active=hook.Run("FacilityBlackoutVolumes",self.zones,active) or active

	net.Start("ixBlackoutSync3")
		net.WriteUInt(#active, 16)
		for _, z in ipairs(active) do
			net.WriteVector(z.min)
			net.WriteVector(z.max)
            net.WriteUInt(math.Clamp(math.Round(z.darkness or 86),0,100),7)
            net.WriteUInt(math.Clamp(math.Round(z.softness or 24),0,128),8)
            net.WriteVector(z.fadeMin or z.min);net.WriteVector(z.fadeMax or z.max)
		end
	if IsValid(receiver) then
		net.Send(receiver)
	else
		net.Broadcast()
	end
end

function PLUGIN:SetElectronicsRestricted(enabled)
	self.electronicsRestricted = enabled == true
	ix.data.Set("blackoutElectronicsRestricted", self.electronicsRestricted)
	local facility = ix.plugin.list.facility_utilities
	if facility and facility.RecomputePower then facility:RecomputePower(0) end
	self:SetZoneLights()
	self:NetworkZones()
end

function PLUGIN:SaveData()
	local out = {}

	for name, z in pairs(self.zones) do
		out[name] = { min = z.min, max = z.max, active = z.active, remoteIsolation=z.remoteIsolation, remotePrevious=z.remotePrevious, areaID=z.areaID, darkness=z.darkness, softness=z.softness }
	end

	ix.data.Set("blackout", out)
end

function PLUGIN:LoadData()
	self.zones = ix.data.Get("blackout") or {}
	self.electronicsRestricted = ix.data.Get("blackoutElectronicsRestricted", false) == true
	self.zonesLoaded = true

	-- Щитки — это просто размещённые сущности и не зависят от карты света, поэтому
	-- грузим их сразу. Так закрывается окно, в котором self.fuseboxes ещё пуст, а
	-- SaveFuseboxes мог бы затереть файл пустым списком.
	self:LoadFuseboxes()

	-- Re-assert active blackouts once map entities exist (switchable lights
	-- spawn enabled by default after a map load).
	timer.Simple(1, function()
        if self.unloading then return end
		self:SetZoneLights()

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

function PLUGIN:PhysgunPickup(client, ent)
    if IsValid(ent) and ent.ixBlackoutFusebox and not client:IsAdmin() then return false end
end

timer.Create("ixBlackoutFuseboxAutosave", 30, 0, function()
	if (!PLUGIN or !istable(PLUGIN.fuseboxes)) then return end

	for _, box in ipairs(PLUGIN.fuseboxes) do
		if (IsValid(box) and (!box.ixLastSavePos or box.ixLastSavePos:DistToSqr(box:GetPos()) > 1 or box.ixLastSaveAng ~= box:GetAngles())) then
			PLUGIN:SaveFuseboxes()
			return
		end
	end
end)

-- Make sure late-joiners receive the active zones.
function PLUGIN:PlayerLoadedCharacter(client)
	timer.Simple(1, function()
		if not self.unloading and IsValid(client) then
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
	height = math.Clamp(tonumber(height) or 1024, 0, 32768)
	if height ~= height then return "Invalid height." end
	if table.Count(self.zones) >= 1024 then return "Maximum number of blackout zones reached." end

	local mn, mx = OrderBox(s[1], s[2])
	mn = mn - Vector(0, 0, 32)     -- small floor margin
	mx = mx + Vector(0, 0, height) -- extend up to cover the building

	local zone = { min = mn, max = mx, active = true }
	self.zones[name] = zone
	self.staging[client] = nil
	if self.PublishZoneArea then self:PublishZoneArea(name) end

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
    zone.remoteIsolation=nil;zone.remotePrevious=nil
	self:SetZoneLights(zone, not zone.active) -- active -> lights off
	self:SetZoneBoxes(zone, zone.active)      -- синхронизируем щитки с ручным переключением
	self:NetworkZones()
	self:SaveData()
	self:SaveFuseboxes()

	return "Blackout zone '" .. name .. "' is now " .. (zone.active and "ON" or "OFF") .. "."
end

function PLUGIN:RemoveZone(name, fromArea)
	local zone = self.zones[name]

	if not zone then
		return "No blackout zone named '" .. name .. "'."
	end

	if not fromArea and zone.areaID and ix.area and ix.area.stored[zone.areaID] then
		ix.area.Remove(zone.areaID)
		return "Blackout zone '" .. name .. "' removed."
	end
	self:SetZoneBoxes(zone, false)
	self.zones[name] = nil
    self:RecomputeZones()
    local facility = ix.plugin.list.facility_utilities
    if facility and facility.RecomputePower then facility:RecomputePower(0) end
    self:SetZoneLights(zone, true)
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

function PLUGIN:OnUnload()
 self:SaveFuseboxes()
 self:SaveData()
 self.unloading = true
 self:RefreshLights()
 ix.DevicePower.RefreshAll()
 timer.Remove("ixBlackoutFuseboxAutosave")
 timer.Remove("ixBlackoutRefresh")
 for _, box in ipairs(self.fuseboxes) do if IsValid(box) then box:Remove() end end
 self.zones = {}
 self:NetworkZones()
end

timer.Create("ixBlackoutRefresh", 1, 0, function()
 if not PLUGIN.unloading then PLUGIN:RefreshLights(); PLUGIN:RefreshBoxPower(); PLUGIN:RegisterEmpHandler() end
end)
