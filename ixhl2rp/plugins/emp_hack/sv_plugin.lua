local PLUGIN = PLUGIN

PLUGIN.disableTime = PLUGIN.disableTime or 30

-- Обработчики взлома по классу сущности. Каждый временно отключает цель и сам
-- восстанавливает её через disableTime. Возвращает текст-уведомление.
local handlers = {}

-- Комбайновский замок: открываем на время.
handlers["ix_combinelock"] = function(ent, client)
	if (!ent:GetLocked()) then return "Замок уже открыт." end

	ent:SetLocked(false)

	timer.Simple(PLUGIN.disableTime, function()
		if (IsValid(ent)) then ent:SetLocked(true) end
	end)

	return "Замок взломан — открыт на " .. PLUGIN.disableTime .. " сек."
end

-- Силовое поле (плагин forcefields): гасим скин/коллизию.
handlers["ix_forcefield"] = function(ent, client)
	if (ent.ixEmpHacked) then return "Поле уже перегружено." end

	ent.ixEmpHacked = true
	ent.on = false
	ent:SetSkin(1)
	if (IsValid(ent.post)) then ent.post:SetSkin(1) end
	ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
	ent:EmitSound("shield/deactivate.wav")
	if (ent.SetDTInt) then ent:SetDTInt(0, 3) end

	timer.Simple(PLUGIN.disableTime, function()
		if (!IsValid(ent)) then return end
		ent.ixEmpHacked = nil
		ent.on = true
		ent:SetSkin(0)
		if (IsValid(ent.post)) then ent.post:SetSkin(0) end
		ent:SetCollisionGroup(COLLISION_GROUP_NONE)
		ent:EmitSound("shield/activate.wav")
		if (ent.SetDTInt) then ent:SetDTInt(0, 1) end
	end)

	return "Силовое поле перегружено на " .. PLUGIN.disableTime .. " сек."
end

-- Комбайновское силовое поле (схема): переводим в режим 3 (выключено/проходимо).
handlers["ent_cmb_forcefield"] = function(ent, client)
	if (ent.ixEmpHacked or (ent.GetBroken and ent:GetBroken())) then return "Поле уже отключено." end

	ent.ixEmpHacked = true
	if (ent.SetForcefield) then ent:SetForcefield(3) end
	ent:EmitSound("combine_tech/forcefield/shield_shutdown2.mp3", 70, 100)

	timer.Simple(PLUGIN.disableTime, function()
		if (!IsValid(ent)) then return end
		ent.ixEmpHacked = nil
		if (ent.SetForcefield) then ent:SetForcefield(1) end
		ent:EmitSound("combine_tech/forcefield/shield_startup.mp3", 70, 100)
	end)

	return "Силовое поле перегружено на " .. PLUGIN.disableTime .. " сек."
end

-- Сканер контрабанды: ставим флаг, его Think пропускает проверки (см. init.lua).
handlers["ix_contrabandscanner"] = function(ent, client)
	ent.ixHackedUntil = CurTime() + PLUGIN.disableTime
	if (ent.SetAlarming) then ent:SetAlarming(false) end
	ent:EmitSound("buttons/combine_button_locked.wav")

	return "Сканер контрабанды отключён на " .. PLUGIN.disableTime .. " сек."
end

-- Мины: ЭМИ их выжигает — обезвреживаем насовсем.
local function mineHandler(ent, client)
	ent:Fire("Disarm", "", 0)
	ent:Fire("Disable", "", 0)
	timer.Simple(0.1, function() if (IsValid(ent)) then ent:Remove() end end)

	return "Мина обезврежена."
end
handlers["combine_mine"] = mineHandler

PLUGIN.handlers = handlers

function PLUGIN:IsHackable(ent)
	if (!IsValid(ent)) then return false end
	if (handlers[ent:GetClass()]) then return true end
	-- дверь с навешенным комбайновским замком
	if (ent.IsDoor and ent:IsDoor() and IsValid(ent.ixLock)) then return true end
	return false
end

function PLUGIN:HackTarget(ent, client)
	if (!IsValid(ent)) then return false end

	-- по двери бьём её замок
	if (ent.IsDoor and ent:IsDoor() and IsValid(ent.ixLock)) then
		ent = ent.ixLock
	end

	local fn = handlers[ent:GetClass()]
	if (!fn) then return false end

	local msg = fn(ent, client)

	-- эффект разряда
	local fx = EffectData()
	fx:SetOrigin(ent:WorldSpaceCenter())
	fx:SetNormal(VectorRand():GetNormalized())
	fx:SetMagnitude(8); fx:SetScale(1); fx:SetRadius(16)
	util.Effect("cball_bounce", fx)
	ent:EmitSound("ambient/energy/zap" .. math.random(1, 3) .. ".wav", 75)

	if (IsValid(client) and msg) then
		client:Notify(msg)
	end

	return true
end

-- Поиск цели для ЭМИ: сначала прямой трейс по взгляду, иначе — ближайшая
-- взламываемая сущность в узком конусе впереди (нужно для сканеров: они нетелесные).
function PLUGIN:FindHackable(client, range)
	local tr = client:GetEyeTrace()

	if (self:IsHackable(tr.Entity) and tr.HitPos:Distance(client:GetShootPos()) <= range) then
		return tr.Entity
	end

	local eyePos = client:GetShootPos()
	local aim = client:GetAimVector()
	local best, bestScore

	local function consider(ent)
		if (!IsValid(ent)) then return end
		-- Сущности без коллизии (сканеры-арки) центром считают пол; даём им
		-- собственную точку прицеливания на высоте арки, иначе конус не ловит.
		local center = (ent.GetEmpAimPos and ent:GetEmpAimPos()) or ent:WorldSpaceCenter()
		local to = center - eyePos
		local dist = to:Length()
		if (dist > range) then return end
		local dot = aim:Dot(to:GetNormalized())
		if (dot < 0.95) then return end -- ~18° конус
		if (!bestScore or dot > bestScore) then best, bestScore = ent, dot end
	end

	for class in pairs(handlers) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			consider(ent)
		end
	end

	return best
end
