include("shared.lua")

local beamMat = Material("sprites/physbeam.vmt")

local COLOR_IDLE  = Color(70, 200, 255)   -- неоновый циан в покое
local COLOR_ALARM = Color(255, 45, 45)    -- красный при тревоге

local SWEEP_V = 0.9   -- скорость горизонтальной линии (снизу вверх), проходов/сек
local SWEEP_H = 0.6   -- скорость вертикальной линии (вбок), проходов/сек

function ENT:Initialize()
	self:UpdateBounds()
end

-- Габариты рендера зависят от сетевых размеров — обновляем, пока они приходят.
function ENT:UpdateBounds()
	local hw = self:GetScanWidth() * 0.5
	local hd = self:GetScanDepth() * 0.5
	local h  = self:GetScanHeight()

	self:SetRenderBounds(
		Vector(-hd - 8, -hw - 8, -8),
		Vector(hd + 8, hw + 8, h + 8)
	)

	self.boundsKey = hw + h + hd
end

local function beam(a, b, width, color)
	render.SetMaterial(beamMat)
	render.DrawBeam(a, b, width, 0, 1, color)
end

function ENT:Draw()
	-- НЕ рисуем базовую модель — видна только неоновая арка.
	local hw = self:GetScanWidth() * 0.5
	local h  = self:GetScanHeight()

	if (hw <= 0 or h <= 0) then return end

	-- пересчитать границы, если размер изменился
	if (self.boundsKey != (hw + h + self:GetScanDepth() * 0.5)) then
		self:UpdateBounds()
	end

	local alarm = self:GetAlarming()
	local col = alarm and COLOR_ALARM or COLOR_IDLE

	-- мигание при тревоге
	if (alarm) then
		local pulse = 0.5 + 0.5 * math.abs(math.sin(CurTime() * 8))
		col = Color(col.r, col.g * pulse, col.b * pulse)
	end

	-- углы рамки в локальном пространстве (плоскость арки: x = 0)
	local BL = self:LocalToWorld(Vector(0, -hw, 0))
	local BR = self:LocalToWorld(Vector(0,  hw, 0))
	local TL = self:LocalToWorld(Vector(0, -hw, h))
	local TR = self:LocalToWorld(Vector(0,  hw, h))

	-- неоновая рамка (стойки + верхняя перекладина), двойной слой для свечения
	beam(BL, TL, 9, ColorAlpha(col, 60))
	beam(BR, TR, 9, ColorAlpha(col, 60))
	beam(TL, TR, 9, ColorAlpha(col, 60))

	beam(BL, TL, 2.5, col)
	beam(BR, TR, 2.5, col)
	beam(TL, TR, 2.5, col)

	-- слабая нижняя планка по полу
	beam(BL, BR, 2, ColorAlpha(col, 120))

	-- сканирующая линия СНИЗУ ВВЕРХ
	local zt = (CurTime() * SWEEP_V) % 1
	local z = zt * h
	local sA = self:LocalToWorld(Vector(0, -hw, z))
	local sB = self:LocalToWorld(Vector(0,  hw, z))
	beam(sA, sB, 10, ColorAlpha(col, 50))
	beam(sA, sB, 3, ColorAlpha(col, 220))

	-- сканирующая линия СБОКУ В БОК
	local yt = (CurTime() * SWEEP_H) % 1
	local y = -hw + yt * (2 * hw)
	local vA = self:LocalToWorld(Vector(0, y, 0))
	local vB = self:LocalToWorld(Vector(0, y, h))
	beam(vA, vB, 10, ColorAlpha(col, 50))
	beam(vA, vB, 3, ColorAlpha(col, 220))
end
