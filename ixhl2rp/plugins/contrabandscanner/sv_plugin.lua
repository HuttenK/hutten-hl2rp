local PLUGIN = PLUGIN

-- [client] = первая отмеченная точка (ждём вторую), как при создании зон.
PLUGIN.pendingPoint = PLUGIN.pendingPoint or {}

-- Создать сканер по двум точкам (как два угла зоны):
--   гориз. расстояние между точками = ширина + ориентация (люди идут поперёк линии);
--   разница по высоте = высота арки (если мала — берётся высота по умолчанию).
function PLUGIN:CreateScannerFromPoints(client, p1, p2)
	local widthDir = p2 - p1
	widthDir.z = 0

	local width = widthDir:Length()

	if (width < 16) then
		return false, "Точки слишком близко друг к другу — отметьте противоположные стороны прохода."
	end

	widthDir:Normalize()

	-- проход перпендикулярен линии между точками
	local forwardDir = Vector(-widthDir.y, widthDir.x, 0)
	local ang = Angle(0, forwardDir:Angle().yaw, 0)

	-- высота: из вертикальной разницы точек, иначе по умолчанию
	local heightDiff = math.abs(p2.z - p1.z)
	local height = (heightDiff >= 16) and heightDiff or self.defaults.height

	-- основание сканера — середина по горизонтали, на нижней из двух точек
	local origin = Vector((p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5, math.min(p1.z, p2.z))

	local scanner = ents.Create("ix_contrabandscanner")

	if (!IsValid(scanner)) then
		return false, "Не удалось создать сущность сканера."
	end

	scanner:SetPos(origin)
	scanner:SetAngles(ang)
	scanner:Spawn()
	scanner:SetScanWidth(math.Clamp(width, 16, 1024))
	scanner:SetScanHeight(math.Clamp(height, 16, 1024))
	scanner:SetScanDepth(self.defaults.depth)

	self:SaveData()

	return true, string.format("Сканер установлен (%dШ x %dВ).",
		scanner:GetScanWidth(), scanner:GetScanHeight())
end

-- Ближайший сканер к точке, куда смотрит игрок (сущность SOLID_NONE, поэтому
-- трассировка её не цепляет — ищем ближайший к HitPos в пределах радиуса).
function PLUGIN:FindAimedScanner(client)
	local target = client:GetEyeTrace().HitPos
	local best, bestDist

	for _, ent in ipairs(ents.FindByClass("ix_contrabandscanner")) do
		local dist = ent:GetPos():DistToSqr(target)

		if (!best or dist < bestDist) then
			best, bestDist = ent, dist
		end
	end

	-- в пределах ~200 юнитов от прицела
	if (best and bestDist <= 200 * 200) then
		return best
	end

	-- запасной вариант — ближайший к самому игроку
	best, bestDist = nil, nil

	for _, ent in ipairs(ents.FindByClass("ix_contrabandscanner")) do
		local dist = ent:GetPos():DistToSqr(client:GetPos())

		if (!best or dist < bestDist) then
			best, bestDist = ent, dist
		end
	end

	if (best and bestDist <= 256 * 256) then
		return best
	end
end

-- Сохраняем все размещённые сканеры (поза + размеры) для восстановления после рестарта.
function PLUGIN:SaveData()
	local data = {}

	for _, ent in ipairs(ents.FindByClass("ix_contrabandscanner")) do
		data[#data + 1] = {
			pos = ent:GetPos(),
			ang = ent:GetAngles(),
			w = ent:GetScanWidth(),
			h = ent:GetScanHeight(),
			d = ent:GetScanDepth()
		}
	end

	self:SetData(data)
end

function PLUGIN:LoadData()
	local data = self:GetData()

	if (!data) then return end

	for _, info in ipairs(data) do
		local scanner = ents.Create("ix_contrabandscanner")

		if (!IsValid(scanner)) then continue end

		scanner:SetPos(info.pos)
		scanner:SetAngles(info.ang)
		scanner:Spawn()
		scanner:SetScanWidth(info.w or self.defaults.width)
		scanner:SetScanHeight(info.h or self.defaults.height)
		scanner:SetScanDepth(info.d or self.defaults.depth)
	end
end
