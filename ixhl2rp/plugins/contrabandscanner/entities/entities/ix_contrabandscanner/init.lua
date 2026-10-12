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


-- Slab intersection in scanner-local space catches an entire crossing between polls.
function ENT:SegmentCrosses(a, b)
    local low = {-self:GetScanDepth() * .5, -self:GetScanWidth() * .5, -16}
    local high = {-low[1], -low[2], self:GetScanHeight()}
    local start = {a.x, a.y, a.z}
    local finish = {b.x, b.y, b.z}
    local enter, leave = 0, 1
    for axis = 1, 3 do
        local delta = finish[axis] - start[axis]
        if math.abs(delta) < .0001 then
            if start[axis] < low[axis] or start[axis] > high[axis] then return false end
        else
            local near, far = (low[axis] - start[axis]) / delta, (high[axis] - start[axis]) / delta
            if near > far then near, far = far, near end
            enter, leave = math.max(enter, near), math.min(leave, far)
            if enter > leave then return false end
        end
    end
    return true
end

function ENT:Think()
    local defaults = getDefaults()
    local now = CurTime()
    local disabled = ix.DevicePower.IsDisabled(self)
    self:SetDisabled(disabled)
    self.samples = self.samples or {}
    if disabled then
        self:SetAlarming(false)
        self.inside, self.samples, self.cooldown = {}, {}, {}
        self:NextThink(now + .2)
        return true
    end
    if self:GetAlarming() and now >= (self.alarmUntil or 0) then self:SetAlarming(false) end
    for client in pairs(self.samples) do
        if not IsValid(client) then self.samples[client] = nil; self.inside[client] = nil; self.cooldown[client] = nil end
    end
    for _, client in ipairs(player.GetAll()) do
        local character = client:GetCharacter()
        if client:Alive() and character then
            local world = client:GetPos()
            local pos = self:WorldToLocal(world)
            local inside = self:IsInsideVolume(client)
            local previous = self.samples[client]
            local crossed = false
            -- Discard old, respawned, character-switched and teleport-sized samples.
            if previous and previous.character == character and now - previous.time <= .5
                and world:DistToSqr(previous.world) <= 256 * 256 then
                crossed = self:SegmentCrosses(previous.pos, pos)
            end
            if (inside or crossed) and not self.inside[client] and now >= (self.cooldown[client] or 0) then
                if self:HasContraband(client) then
                    self:TriggerAlarm(client)
                    self.cooldown[client] = now + (defaults.cooldown or 5)
                end
            end
            self.inside[client] = inside or nil
            self.samples[client] = {pos = pos, world = world, time = now, character = character}
        else
            self.inside[client], self.samples[client], self.cooldown[client] = nil, nil, nil
        end
    end
    self:NextThink(now + (defaults.checkInterval or .2))
    return true
end
