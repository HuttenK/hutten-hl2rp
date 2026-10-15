-- Recovered AUTONOMOUS client/shared source; Foundation integration. See docs/restored-systems-sources.json.
--[[
	ОБЩАЯ ЧАСТЬ: КВАРТИРЫ И СЕТКА.

	И редактор (клиент), и сервер считают одно и то же одной функцией: какая
	квартира под точкой и годится ли каждая клетка под предметом. Разойдись
	они — редактор показывал бы зелёное там, где сервер откажет.
]]

-- Библиотеки плагина грузятся РАНЬШЕ sh_plugin.lua (helix/core/libs/sh_plugin.lua),
-- поэтому пространство имён заводится здесь.
ix.furnish = ix.furnish or {}

-- Режимы редактора: из инвентаря и перестановка поставленного.
FURNISH_MODE_PLACE = 1
FURNISH_MODE_EDIT = 2

-- Шаг сетки и привязки, в юнитах (≈ 15 см).
ix.furnish.cellSize = 8
-- Больше клеток не рисуем: у большого предмета клетка растёт.
ix.furnish.maxCells = 96
-- Шаг поворота колёсиком, в градусах; с зажатым Shift — по одному.
ix.furnish.rotateStep = 15
-- Как далеко от себя можно ставить.
ix.furnish.reach = 220
-- Поверхность считается полом, если нормаль смотрит вверх не меньше этого.
ix.furnish.floorNormal = 0.7

--- Номер квартиры у зоны: свойство «apartment» либо само имя зоны.
function ix.furnish.ApartmentKey(id, info)
	if !istable(info) or (info.type != "apartment" and info.type != "furnishing") then return end

	local key = info.properties and info.properties.apartment

	if !isstring(key) or string.Trim(key) == "" then
		key = id
	end

	return string.lower(string.Trim(tostring(key)))
end

--- Зона-квартира, в которой лежит точка: id, данные, номер.
function ix.furnish.FindApartment(position)
	for id, info in pairs(ix.area and ix.area.stored or {}) do
		local key = ix.furnish.ApartmentKey(id, info)

		if key and isvector(info.startPosition) and isvector(info.endPosition)
			and ix.area.Contains(info, position) then
			return id, info, key
		end
	end
end

--- Все зоны квартиры с данным номером (квартира может состоять из нескольких
--- коробок: комната, кухня, коридор).
function ix.furnish.ApartmentAreas(key)
	local result = {}

	if !isstring(key) or key == "" then return result end

	key = string.lower(string.Trim(key))

	for id, info in pairs(ix.area and ix.area.stored or {}) do
		if ix.furnish.ApartmentKey(id, info) == key then
			result[#result + 1] = info
		end
	end

	return result
end

local function InsideAny(areas, position)
	for _, info in ipairs(areas) do
		if isvector(info.startPosition) and isvector(info.endPosition)
			and ix.area.Contains(info, position) then
			return true
		end
	end

	return false
end

--[[
	ОЦЕНКА МЕСТА.

	mins/maxs — габариты модели (Entity:GetModelBounds, одинаково на обоих
	реалмах), pos/ang — куда ставим, areas — зоны разрешённой квартиры (nil —
	без ограничения по зоне, для администрации), filter — что не мешает (сам
	игрок, призрак или переставляемый предмет).

	Возвращает список клеток {pos, ok} и общий ответ. Клетка годится, если:
	  * она внутри квартиры (и верх предмета над ней — тоже);
	  * под ней есть опора в пределах нескольких юнитов;
	  * столб над ней до высоты предмета свободен.
]]
function ix.furnish.Evaluate(mins, maxs, pos, ang, areas, filter)
	local sizeX = math.max(maxs.x - mins.x, 1)
	local sizeY = math.max(maxs.y - mins.y, 1)
	local height = math.max(maxs.z - mins.z, 2)

	local cell = ix.furnish.cellSize
	local countX, countY = math.ceil(sizeX / cell), math.ceil(sizeY / cell)

	if countX * countY > ix.furnish.maxCells then
		cell = math.sqrt(sizeX * sizeY / ix.furnish.maxCells)
		countX, countY = math.ceil(sizeX / cell), math.ceil(sizeY / cell)

		-- Округление вверх может перешагнуть предел — дотягиваем клетку.
		while countX * countY > ix.furnish.maxCells do
			cell = cell * 1.05
			countX, countY = math.ceil(sizeX / cell), math.ceil(sizeY / cell)
		end
	end

	local stepX, stepY = sizeX / countX, sizeY / countY
	local up = ang:Up()
	-- Столб проверяется коробкой чуть меньше клетки: повёрнутая клетка в
	-- осевой коробке трения шире, и у стены краснело бы лишнее.
	local half = math.min(stepX, stepY) * 0.35
	local hullMins = Vector(-half, -half, 0)
	local hullMaxs = Vector(half, half, math.max(height - 3, 1))

	local cells = {}
	local allOk = true

	for i = 1, countX do
		for j = 1, countY do
			local localPos = Vector(mins.x + (i - 0.5) * stepX, mins.y + (j - 0.5) * stepY, mins.z)
			local world = LocalToWorld(localPos, angle_zero, pos, ang)
			local ok = true

			if areas and (!InsideAny(areas, world + up * 1) or !InsideAny(areas, world + up * (height - 1))) then
				ok = false
			end

			if ok then
				local floor = util.TraceLine({
					start = world + up * 2,
					endpos = world - up * 6,
					filter = filter,
					mask = MASK_SOLID
				})

				ok = floor.Hit and !floor.HitSky and floor.HitNormal.z >= ix.furnish.floorNormal
			end

			if ok then
				local column = util.TraceHull({
					start = world + up * 2,
					endpos = world + up * 2,
					mins = hullMins,
					maxs = hullMaxs,
					filter = filter,
					mask = MASK_SOLID
				})

				ok = !column.Hit and !column.StartSolid
			end

			if !ok then
				allOk = false
			end

			cells[#cells + 1] = {pos = world, ok = ok, w = stepX, h = stepY}
		end
	end

	return cells, allOk
end

--- Привязка к сетке по горизонтали.
function ix.furnish.Snap(position)
	local cell = ix.furnish.cellSize * 0.5

	return Vector(math.Round(position.x / cell) * cell, math.Round(position.y / cell) * cell, position.z)
end

-- Shared so inventory callbacks choose the same placement path in both realms.
function ix.furnish.Supported(item)
 return item and (not item.OnPlace or (ix.meta.ItemBuildable and item.OnPlace==ix.meta.ItemBuildable.OnPlace)) and isstring(item.uniqueID) and not item.wallMount and isstring(item.preview_model) and item.preview_model~=""
  and (item.uniqueID:sub(1,5)=="furn_" or item.uniqueID:sub(1,5)=="cont_")
end
