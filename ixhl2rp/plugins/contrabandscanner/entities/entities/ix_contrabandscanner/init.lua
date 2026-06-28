AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

-- Тюнинг-настройки читаем «вживую» (плагин мог загрузиться после сущности).
local function getDefaults()
	return (ix.contraband and ix.contraband.plugin and ix.contraband.plugin.defaults) or {}
end

function ENT:Initialize()
	-- Невидимая компактная модель как «база» сущности; саму модель НЕ рисуем
	-- (в Draw() не вызываем DrawModel), поэтому видна только неоновая арка.
	self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_NONE)          -- игроки свободно проходят сквозь
	self:DrawShadow(false)
	self:SetNoDraw(false)

	-- значения по умолчанию (могут быть переопределены командой/загрузкой)
	if (self:GetScanWidth() <= 0)  then self:SetScanWidth(80)  end
	if (self:GetScanHeight() <= 0) then self:SetScanHeight(86) end
	if (self:GetScanDepth() <= 0)  then self:SetScanDepth(28)  end

	self.inside = {}     -- [player] = был ли внутри в прошлый тик
	self.cooldown = {}   -- [player] = CurTime, до которого не тревожить повторно

	self:NextThink(CurTime() + 0.1)
end

-- client:GetItems() (без аргумента) уже собирает предметы из ВСЕХ инвентарей
-- игрока (main + рюкзак/сумки) — см. game/inventory/sh_player.lua.
function ENT:HasContraband(client)
	for _, item in pairs(client:GetItems()) do
		if (ix.contraband.IsItemIllegal(item)) then
			return true
		end
	end

	return false
end

-- Граница зоны: игрок (его ноги) внутри ориентированного бокса сканера.
function ENT:IsInsideVolume(client)
	local lp = self:WorldToLocal(client:GetPos())
	local hw = self:GetScanWidth() * 0.5
	local hd = self:GetScanDepth() * 0.5
	local h  = self:GetScanHeight()

	return math.abs(lp.x) <= hd
		and math.abs(lp.y) <= hw
		and lp.z >= -16 and lp.z <= h
end

function ENT:TriggerAlarm(client)
	local defaults = getDefaults()

	self:SetAlarming(true)
	self:EmitSound("npc/scanner/scanner_siren1.wav", 80)
	self.alarmUntil = CurTime() + (defaults.alarmTime or 4)

	-- Текстовое уведомление о пронесённой контрабанде убрано по просьбе —
	-- остаётся только сирена и визуальная тревога самого сканера.
end

-- Точка прицеливания для ЭМИ: середина арки (сама сущность нетелесная и стоит
-- центром у пола, поэтому ЭМИ-конус её иначе не захватывает).
function ENT:GetEmpAimPos()
	return self:GetPos() + self:GetUp() * (self:GetScanHeight() * 0.5)
end

function ENT:Think()
	local defaults = getDefaults()

	-- ЭМИ-взлом: пока отключён — не сканируем.
	if (self.ixHackedUntil and CurTime() < self.ixHackedUntil) then
		if (self:GetAlarming()) then self:SetAlarming(false) end
		self:NextThink(CurTime() + 0.3)
		return true
	end

	-- снять тревогу по таймеру
	if (self:GetAlarming() and self.alarmUntil and CurTime() >= self.alarmUntil) then
		self:SetAlarming(false)
	end

	local now = CurTime()

	for _, client in ipairs(player.GetAll()) do
		if (!client:Alive() or !client:GetCharacter()) then
			self.inside[client] = nil
			continue
		end

		local inside = self:IsInsideVolume(client)

		-- срабатываем в момент ВХОДА в зону (не каждый тик)
		if (inside and !self.inside[client]) then
			local cd = self.cooldown[client]

			if (!cd or now >= cd) then
				if (self:HasContraband(client)) then
					self:TriggerAlarm(client)
				end

				self.cooldown[client] = now + (defaults.cooldown or 5)
			end
		end

		self.inside[client] = inside or nil
	end

	self:NextThink(now + (defaults.checkInterval or 0.2))
	return true
end
