--[[
	КИНЕМАТИКА ТЕЛЕЖКИ (ix.PushCart.Kin).

	Пока тележку везут, у неё ровно одна поза, и считает её Kin.Step - раз на
	каждую команду толкающего, на сервере и в предсказании его клиента, одним и
	тем же кодом на одних и тех же данных. Прежде «тележкой» были сразу три
	вещи: четыре замера под колёсами, другое физическое тело и третья поза,
	нарисованная клиентом, - и каждая правка лишь переносила зазор между ними.

	Модуль чистый: ни одного вызова движка. Мир виден только через переданную
	функцию trace(d) с договором util.TraceHull: d.start, d.endpos, d.mins и
	d.maxs - таблицы {x, y, z}; у результата нужны StartSolid, Hit, Fraction,
	HitPos.z и HitNormal.x/.y. Поэтому его целиком гоняют офлайн
	(tests/pushcart_kinematic_spec.lua), а сервер и клиент дают один результат.

	Одно тело. Колёса - четыре замера и опорная плоскость по трём из них. Всё,
	что выше плоскости на CLEARANCE и до top, - кузов, и в стены упирается он.
	CLEARANCE - это сразу низ настила, наибольшая ступень вверх и наибольший
	спуск за команду: на том, что колёса принимают, кузов лечь не может, а то,
	что колёса не принимают, кузов встречает стенкой.

	Поза: {x, y, yaw, c, s, z0, a, b, cp, cr, g[4], wx[4], wy[4]}.
	a = dz/dx вдоль +X (к ручке), b = dz/dy вдоль +Y (влево), cp и cr -
	1/sqrt(1 + a²) и 1/sqrt(1 + b²). Колёса по порядку FL, FR, RL, RR: перёд
	на -X (поворотные колёса), лево на +Y.
	Состояние: S = {pose, rate, hx, hy, load, top}; (hx, hy) - где руки
	толкающего в осях тележки, после каждого шага центр тележки ровно
	CenterFor(ноги толкающего, yaw, hx, hy).
]]

ix.PushCart = ix.PushCart or {}

local PushCart = ix.PushCart
local Kin = PushCart.Kin or {}

PushCart.Kin = Kin

-- EP2 VVD wheel centers, rotated into the driving frame (+X to the handle).
local HALF_BASE = 24.3965
local WHEEL_CENTER_X = -1.9975
local HALF_TRACK = 14.47
local BODY_MIN_X = -39.72
local BODY_MAX_X = 38
local BODY_HALF_Y = 23
-- Низ настила по .phy.
local CLEARANCE = 13
-- Верх ручки. Ящики поднимают его (BodyTop в дататейбле тележки).
local BODY_TOP_EMPTY = 52.25
-- EP2 model origin is roughly 16 units above its wheel contact plane.
local WHEEL_BOTTOM = -15.96365
-- Пятно колеса (-2, -2, 0)..(2, 2, 1).
local PROBE = 2
-- Полуширина столбика по периметру кузова и зазор над CLEARANCE.
local COLUMN = 0.5
local LIFT = 0.1
-- Полосы под днищем: тянутся вдоль тележки на этих y.
local BELLY_LINES = {-15, -9, -3, 3, 9, 15}
local BELLY_HALF = 3
local BELLY_HEIGHT = 3
--[[
	Круче этого земля - стена, а не уклон: позу НЕ подрезают до предела, её
	отвергают. Лестница 8/12 даёт на пике около 38°. На 10/10 вверх следующая
	поза круче 45° - тележка встаёт; вниз раньше ложится днищем на кромки.
]]
local MAX_PITCH = 45
local MAX_ROLL = 25
-- Pusher feet stay at x=52 in the driving frame, roughly 18 units behind
-- the handle. HandleShift compensates for the 51.2-unit grip height when
-- the cart pitches/rolls, keeping the wrists reachable on slopes.
local REACH = 52
local HOLD_EASE = 60
local HOLD_TAU = 0.2
local HOLD_CREEP = 5
-- В каких пределах хват (за вычетом сдвига перекладины на уклоне) можно взять и удержать.
local HOLD_MIN_X = 30
local HOLD_MAX_X = 100
local HOLD_MAX_Y = 45
-- Хват, пересчитанный HoldOf, совпадает с прежним до этого шума: поворачивать и доводить нечего.
local HOLD_SAME = 1e-9
-- Reject a pose when the handle is more than HANDLE_DZ above/below its
-- level-ground height relative to the pusher's feet.
-- Tops of the two curved handles: model (-34.006, +/-12, 35.236).
local HANDLE_X = 34.006
local HANDLE_DZ = 30
local GRIP_Z = 35.236
local GRIP_HEIGHT = GRIP_Z - WHEEL_BOTTOM
--[[
	Шагов деления пополам, когда ход упёрся: точность 1/16 хода команды (сотые
	доли единицы), а каждый шаг у стены стоит до 16 трасс (4 колеса и 12 на кузов).
]]
local BISECT = 4
-- Остаток хода короче 0.05 вдоль стены не скользит: лишние трассы ради ничего.
local SLIDE_MIN = 0.05 * 0.05
-- Высвобождение при захвате: столько шагов во все восемь сторон.
local FREE_STEPS = {2, 4, 6}
local FREE_DIRECTIONS = 8

local WHEELS = {{-1, 1}, {-1, -1}, {1, 1}, {1, -1}}

Kin.HALF_BASE, Kin.HALF_TRACK = HALF_BASE, HALF_TRACK
Kin.WHEEL_CENTER_X = WHEEL_CENTER_X
Kin.BODY_MIN_X, Kin.BODY_MAX_X, Kin.BODY_HALF_Y = BODY_MIN_X, BODY_MAX_X, BODY_HALF_Y
Kin.CLEARANCE, Kin.BODY_TOP_EMPTY, Kin.WHEEL_BOTTOM = CLEARANCE, BODY_TOP_EMPTY, WHEEL_BOTTOM
Kin.PROBE, Kin.COLUMN, Kin.LIFT = PROBE, COLUMN, LIFT
Kin.BELLY_LINES, Kin.BELLY_HALF, Kin.BELLY_HEIGHT = BELLY_LINES, BELLY_HALF, BELLY_HEIGHT
Kin.MAX_PITCH, Kin.MAX_ROLL = MAX_PITCH, MAX_ROLL
Kin.REACH, Kin.HOLD_EASE, Kin.HOLD_TAU, Kin.HOLD_CREEP = REACH, HOLD_EASE, HOLD_TAU, HOLD_CREEP
Kin.HOLD_MIN_X, Kin.HOLD_MAX_X, Kin.HOLD_MAX_Y = HOLD_MIN_X, HOLD_MAX_X, HOLD_MAX_Y
Kin.HANDLE_X, Kin.HANDLE_DZ, Kin.GRIP_Z, Kin.GRIP_HEIGHT = HANDLE_X, HANDLE_DZ, GRIP_Z, GRIP_HEIGHT
Kin.BISECT = BISECT
Kin.WHEELS = WHEELS

local function V(x, y, z)
	return {x = x, y = y, z = z}
end

--[[
	Свои Lerp/Clamp/Approach и углы вместо движковых: модуль не зависит от
	движка, и обе стороны считают по одной и той же формуле.
]]
local function AngleDiff(a, b)
	return (a - b + 180) % 360 - 180
end

local function Norm(a)
	return (a + 180) % 360 - 180
end

local function Lerp(t, a, b)
	return a + (b - a) * t
end

local function Clamp(value, low, high)
	return math.min(math.max(value, low), high)
end

local function Approach(current, target, step)
	if current < target then
		return math.min(current + step, target)
	end

	return math.max(current - step, target)
end

local function Count(ctx, key)
	local stats = ctx.stats

	if stats then
		stats[key] = (stats[key] or 0) + 1
	end
end

Kin.AngleDiff, Kin.Norm = AngleDiff, Norm

--[[
	Поворот с инерцией - прежний закон ENT:TurnTowards, только без состояния
	на сущности: скорость разворота набирается и гасится ускорением, тормозить
	начинает заранее (не выше sqrt(2 * ускорение * остаток)), последний шаг не
	перелетает курс. Чем тяжелее груз, тем медленнее и разгон, и предел.
]]
function Kin.TurnTowards(yaw, rate, wanted, dt, load)
	local maxRate = Lerp(load, PushCart.TURN_RATE_EMPTY, PushCart.TURN_RATE_FULL)
	local accel = Lerp(load, PushCart.TURN_ACCEL_EMPTY, PushCart.TURN_ACCEL_FULL)
	local left = AngleDiff(wanted, yaw)
	local braking = math.sqrt(2 * accel * math.abs(left))
	local desired = Clamp(left > 0 and braking or -braking, -maxRate, maxRate)

	rate = Approach(rate, desired, accel * dt)

	local step = rate * dt

	-- Не сам wanted: курс 180 и -180 один, но рысканье прыгнуло бы на 360.
	if left == 0 or (step * left > 0 and math.abs(step) >= math.abs(left)) then
		return Norm(yaw + left), 0
	end

	return Norm(yaw + step), rate
end

--[[
	Плоскость, на которой стоит жёсткая тележка о четырёх колёсах: ВЫСОКАЯ
	диагональ и ещё одно колесо, четвёртое на своей земле или над ней. Из двух
	годных треугольников берётся более плоский; центр лежит на диагонали, так
	что высота центра у обоих одна. Не максимум по осям: тот ставил начало на
	высокий борт и потом ещё накренял вокруг него - перепад считался дважды.
	g = {FL, FR, RL, RR}; halfBase/halfTrack - половины базы и колеи по горизонтали.
]]
function Kin.FitSupport(g, halfBase, halfTrack)
	local fl, fr, rl, rr = g[1], g[2], g[3], g[4]
	local s = (fl + rr) - (fr + rl)
	local length, width = 2 * halfBase, 2 * halfTrack
	local z0, a1, b1, a2, b2

	if s >= 0 then
		z0 = (fl + rr) * 0.5
		a1, b1 = (rr - fr) / length, (fl - fr) / width
		a2, b2 = (rl - fl) / length, (rl - rr) / width
	else
		z0 = (fr + rl) * 0.5
		a1, b1 = (rl - fl) / length, (fl - fr) / width
		a2, b2 = (rr - fr) / length, (rl - rr) / width
	end

	if a2 * a2 + b2 * b2 < a1 * a1 + b1 * b1 then
		return z0, a2, b2
	end

	return z0, a1, b1
end

function Kin.PlaneAt(pose, x, y)
	local dx, dy = x - pose.x, y - pose.y

	return pose.z0 + pose.a * (dx * pose.c + dy * pose.s) + pose.b * (-dx * pose.s + dy * pose.c)
end

-- Точка модели (lx, ly) на наклонной плоскости: мировые X, Y и высота плоскости под ней.
function Kin.PointAt(pose, lx, ly)
	local hx, hy = lx * pose.cp, ly * pose.cr
	local x = pose.x + hx * pose.c - hy * pose.s
	local y = pose.y + hx * pose.s + hy * pose.c

	return x, y, pose.z0 + pose.a * hx + pose.b * hy
end

local PROBE_MINS = V(-PROBE, -PROBE, 0)
local PROBE_MAXS = V(PROBE, PROBE, 1)

-- Колесо: самая высокая земля в окне anchor ± CLEARANCE. Начали в твёрдом - стена, пусто - обрыв.
function Kin.Probe(trace, x, y, anchor)
	local tr = trace({
		start = V(x, y, anchor + CLEARANCE),
		endpos = V(x, y, anchor - CLEARANCE),
		mins = PROBE_MINS,
		maxs = PROBE_MAXS
	})

	if tr.StartSolid then
		return nil, "wall"
	end

	if !tr.Hit then
		return nil, "void"
	end

	return tr.HitPos.z
end

--[[
	Поза в (x, y, yaw). Окно каждого колеса - от плоскости ПРЕЖНЕЙ позы под
	этим колесом: ступень или стена решается по преемственности, а не по
	высоте центра или ног (от ног на лестнице стена принималась за ступень и
	наоборот). Потом опорная плоскость, уклон и высота ручки.
	nil, причина[, колесо] - колесо на стене, над обрывом, слишком круто
	или ручку утянуло от ног.
]]
function Kin.EvalPose(trace, x, y, yaw, prev, ctx)
	local r = math.rad(yaw)
	local pose = {x = x, y = y, yaw = yaw, c = math.cos(r), s = math.sin(r), cp = prev.cp, cr = prev.cr}
	local halfBase, halfTrack = HALF_BASE * pose.cp, HALF_TRACK * pose.cr
	local g, wx, wy = {}, {}, {}

	for i = 1, 4 do
		local wheel = WHEELS[i]
		local hx, hy = wheel[1] * halfBase + WHEEL_CENTER_X * pose.cp, wheel[2] * halfTrack
		local wheelX = x + hx * pose.c - hy * pose.s
		local wheelY = y + hx * pose.s + hy * pose.c
		local z, why = Kin.Probe(trace, wheelX, wheelY, Kin.PlaneAt(prev, wheelX, wheelY))

		Count(ctx, "probes")

		if !z then
			return nil, why, i
		end

		g[i], wx[i], wy[i] = z, wheelX, wheelY
	end

	local z0, a, b = Kin.FitSupport(g, halfBase, halfTrack)
	-- FitSupport returns the height at the axle midpoint, not the model origin.
	z0 = z0 - a * WHEEL_CENTER_X * pose.cp

	if math.deg(math.atan(math.abs(a))) > MAX_PITCH or math.deg(math.atan(math.abs(b))) > MAX_ROLL then
		return nil, "slope"
	end

	pose.z0, pose.a, pose.b, pose.g, pose.wx, pose.wy = z0, a, b, g, wx, wy
	pose.cp, pose.cr = 1 / math.sqrt(1 + a * a), 1 / math.sqrt(1 + b * b)

	-- CHANGED: высота ручки - условие годности позы, а не повод отпустить.
	local feetZ = ctx.feetZ

	if feetZ then
		local handleZ = Kin.HandleZ(pose)

		if math.abs(handleZ - feetZ) > HANDLE_DZ then
			return nil, "handle"
		end
	end

	return pose
end

-- Столбики по периметру кузова в порядке обхода; длинные борта разбиты посередине.
local PERIMETER

do
	local x0, x1 = BODY_MIN_X + COLUMN, BODY_MAX_X - COLUMN
	local halfY = BODY_HALF_Y - COLUMN
	local xm = (x0 + x1) * 0.5

	PERIMETER = {{x0, -halfY}, {x0, halfY}, {xm, halfY}, {x1, halfY}, {x1, -halfY}, {xm, -halfY}}
end

Kin.PERIMETER = PERIMETER

--[[
	Прямоугольная трасса полуширины h под наклонным днищем: её плоский низ
	поднят на перепад плоскости поперёк неё, чтобы она не находила землю,
	которая на деле ниже настила.
]]
function Kin.TiltLift(pose, h)
	return CLEARANCE + LIFT + h * (math.abs(pose.a) + math.abs(pose.b))
end

local function ColumnHull(top)
	return V(-COLUMN, -COLUMN, 0), V(COLUMN, COLUMN, top - CLEARANCE - LIFT)
end

--[[
	Кузов свободен, если ни одна грань периметра ничего не пересекает: по
	тонкой трассе на ребро, от угла к углу по наклонной плоскости. Точно при
	любом угле стены, выпуклые углы между столбиками тоже ловятся.
]]
function Kin.BodyFree(trace, pose, top, ctx)
	local mins, maxs = ColumnHull(top)
	local lift = Kin.TiltLift(pose, COLUMN)
	local count = #PERIMETER

	for i = 1, count do
		local p, q = PERIMETER[i], PERIMETER[i % count + 1]
		local ax, ay, az = Kin.PointAt(pose, p[1], p[2])
		local bx, by, bz = Kin.PointAt(pose, q[1], q[2])
		local tr = trace({
			start = V(ax, ay, az + lift),
			endpos = V(bx, by, bz + lift),
			mins = mins,
			maxs = maxs
		})

		Count(ctx, "edges")

		if tr.Hit or tr.StartSolid then
			return false
		end
	end

	return Kin.BellyFree(trace, pose, ctx)
end

local BELLY_MINS = V(-BELLY_HALF, -BELLY_HALF, 0)
local BELLY_MAXS = V(BELLY_HALF, BELLY_HALF, BELLY_HEIGHT)

--[[
	Середина днища. Сбоку в кузов входит только через периметр, а снизу -
	когда плоскость колёс опустилась на то, что стоит под днищем (столбик у
	подножия бордюра). Шесть полос вдоль тележки, каждая - трасса полуширины 3
	по наклонному днищу: при курсе 0 они кроют |y| <= 18, при любом другом
	перекрываются и нигде не вылезают за габарит (15 + 3 * sqrt2 < 23).
]]
function Kin.BellyFree(trace, pose, ctx)
	local inset = BELLY_HALF * 1.4143
	local x0, x1 = BODY_MIN_X + inset, BODY_MAX_X - inset
	local lift = Kin.TiltLift(pose, BELLY_HALF)

	for _, lineY in ipairs(BELLY_LINES) do
		local ax, ay, az = Kin.PointAt(pose, x0, lineY)
		local bx, by, bz = Kin.PointAt(pose, x1, lineY)
		local tr = trace({
			start = V(ax, ay, az + lift),
			endpos = V(bx, by, bz + lift),
			mins = BELLY_MINS,
			maxs = BELLY_MAXS
		})

		Count(ctx, "belly")

		if tr.Hit or tr.StartSolid then
			return false
		end
	end

	return true
end

-- Где будут столбики позы B; B может быть ещё не оценённой целью (без плоскости).
local function TargetPoint(A, B, lx, ly)
	local hx, hy = lx * A.cp, ly * A.cr
	local r = math.rad(B.yaw)
	local c, s = math.cos(r), math.sin(r)
	local x, y = B.x + hx * c - hy * s, B.y + hx * s + hy * c
	local z = B.z0 and Kin.PlaneAt(B, x, y) or Kin.PlaneAt(A, x, y)

	return x, y, z
end

--[[
	Момент удара кузова между двумя позами: каждый столбик идёт по своей хорде.
	Возвращает долю хода и горизонтальную нормаль удара. Столбик, начавший в
	твёрдом, пропускается: с телом, свободным в A (это обеспечивает Step), так
	бывает только на самом стыке.
]]
function Kin.Columns(trace, A, B, top, ctx)
	local mins, maxs = ColumnHull(top)
	local lift = Kin.TiltLift(A, COLUMN)
	local best, normal = 1, nil

	for _, point in ipairs(PERIMETER) do
		local ax, ay, az = Kin.PointAt(A, point[1], point[2])
		local bx, by, bz = TargetPoint(A, B, point[1], point[2])
		local tr = trace({
			start = V(ax, ay, az + lift),
			endpos = V(bx, by, bz + lift),
			mins = mins,
			maxs = maxs
		})

		Count(ctx, "columns")

		if !tr.StartSolid and tr.Hit and tr.Fraction < best then
			local nx, ny = tr.HitNormal.x, tr.HitNormal.y
			local length = math.sqrt(nx * nx + ny * ny)

			best = tr.Fraction
			normal = length > 0.1 and V(nx / length, ny / length, 0) or nil
		end
	end

	return best, normal
end

--[[
	Одна трасса нулевой длины на оба тела сразу: чисто - разбирать нечего.

	Коробка трассы плоская: её низ - самая низкая точка днища, на весь габарит. На уклоне
	круче ~10° (на 81 длины подъём больше CLEARANCE) под высоким концом в неё заведомо входит
	сама земля, по которой едут, - трасса впустую, а за ней шёл разбор упора на 63 трассы на
	каждой команде любого пандуса и лестницы. Если плоскость колёс хоть в одном углу коробки
	выше её низа, трассы нет, ответ nil: «не знаю», и Step проверяет ход точно (см. там).
]]
function Kin.Broadphase(trace, A, B, top, ctx)
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

	for _, pose in ipairs({A, B}) do
		for _, point in ipairs(PERIMETER) do
			local x, y, z = Kin.PointAt(pose, point[1], point[2])

			minX, maxX = math.min(minX, x), math.max(maxX, x)
			minY, maxY = math.min(minY, y), math.max(maxY, y)
			minZ = math.min(minZ, z + CLEARANCE + LIFT)
			maxZ = math.max(maxZ, z + top)
		end
	end

	minX, maxX, minY, maxY = minX - COLUMN, maxX + COLUMN, minY - COLUMN, maxY + COLUMN

	for _, pose in ipairs({A, B}) do
		if Kin.PlaneAt(pose, minX, minY) > minZ or Kin.PlaneAt(pose, minX, maxY) > minZ
			or Kin.PlaneAt(pose, maxX, minY) > minZ or Kin.PlaneAt(pose, maxX, maxY) > minZ then
			return nil
		end
	end

	local center = V((minX + maxX) * 0.5, (minY + maxY) * 0.5, minZ)
	local tr = trace({
		start = center,
		endpos = center,
		mins = V(minX - center.x, minY - center.y, 0),
		maxs = V(maxX - center.x, maxY - center.y, maxZ - minZ)
	})

	Count(ctx, "broad")

	return !(tr.Hit or tr.StartSolid)
end

--[[
	Сдвинуть годную позу A к (tx, ty, tyaw). Возвращает самую дальнюю годную
	позу, достигнутую долю хода и нормаль упора (nil, если встали колёса или
	уклон, а не кузов).

	CHANGED: лазейки «начали в твёрдом - тело не проверять» больше нет. Здесь
	A всегда свободна (Step проверяет это заранее и иначе замирает), поэтому
	тележку ничто не вдавит глубже в стену.
]]
function Kin.TryMove(trace, A, tx, ty, tyaw, top, ctx)
	local B = Kin.EvalPose(trace, tx, ty, tyaw, A, ctx)

	if B and Kin.Broadphase(trace, A, B, top, ctx) then
		return B, 1
	end

	local function Ok(pose)
		return pose != nil and Kin.BodyFree(trace, pose, top, ctx)
	end

	local f, normal = Kin.Columns(trace, A, B or {x = tx, y = ty, yaw = tyaw}, top, ctx)

	if f >= 1 and Ok(B) then
		return B, 1
	end

	-- Уже вплотную по этому ходу: искать нечего.
	if f <= 0 then
		return A, 0, normal
	end

	local dyaw = AngleDiff(tyaw, A.yaw)

	local function At(t)
		return Kin.EvalPose(trace, Lerp(t, A.x, tx), Lerp(t, A.y, ty), Norm(A.yaw + dyaw * t), A, ctx)
	end

	if f < 1 then
		local C = At(f)

		if Ok(C) then
			return C, f, normal
		end
	end

	local low, high, best = 0, f, A

	for _ = 1, BISECT do
		local middle = (low + high) * 0.5
		local M = At(middle)

		if Ok(M) then
			best, low = M, middle
		else
			high = middle
		end
	end

	return best, low, normal
end

-- Центр тележки для толкающего в (px, py), держащего её за (hx, hy) в осях тележки.
function Kin.CenterFor(px, py, yaw, hx, hy)
	local r = math.rad(yaw)
	local c, s = math.cos(r), math.sin(r)

	return px - (hx * c - hy * s), py - (hx * s + hy * c)
end

function Kin.HoldOf(px, py, pose)
	local dx, dy = px - pose.x, py - pose.y

	return dx * pose.c + dy * pose.s, -dx * pose.s + dy * pose.c
end

--[[
	На сколько наклон уводит перекладину по горизонтали в осях курса против ровного (вперёд к
	толкающему, влево): перекладина - на HANDLE_X вдоль оси тележки и на GRIP_HEIGHT по её «вверх»,
	а «вверх» = (-a, -b, 1) / sqrt(1 + a² + b²) (Kin.Basis).
]]
function Kin.HandleShift(pose)
	local a, b = pose.a, pose.b
	local tilt = GRIP_HEIGHT / math.sqrt(1 + a * a + b * b)

	return HANDLE_X * (pose.cp - 1) - a * tilt, -b * tilt
end

--[[
	Высота перекладины за вычетом её высоты над плоскостью на ровном (GRIP_HEIGHT): на ровном это
	плоскость под ней, и окно HANDLE_DZ значит то же, что значило. Не продолжение плоскости колёс
	под перекладину: на крутом уклоне она до 58 от центра, задняя ось - 23, и продолжение уходит до
	30 под настоящий пол, на котором стоит толкающий. Тогда на подъёме от 41° (и задом вниз, и задом
	вверх 35-38° на краю корпуса) каждая поза отвергалась «ручкой», и тележка вставала насовсем.
]]
function Kin.HandleZ(pose)
	local a, b = pose.a, pose.b
	local sx, sy = Kin.HandleShift(pose)

	return pose.z0 + a * (HANDLE_X + sx) + b * sy + GRIP_HEIGHT * (math.sqrt(1 + a * a + b * b) - 1)
end

-- Хват годен; с позой - за вычетом сдвига перекладины на уклоне (на крутом спуске ноги ближе 30 к центру).
function Kin.HoldInRange(hx, hy, pose)
	if pose then
		local sx, sy = Kin.HandleShift(pose)

		hx, hy = hx - sx, hy - sy
	end

	return hx >= HOLD_MIN_X and hx <= HOLD_MAX_X and math.abs(hy) <= HOLD_MAX_Y
end

--[[
	Хват ещё держит - мягче, чем годен для захвата: вперёд годится и как есть, и за вычетом сдвига
	перекладины, вбок - за вычетом. В яме (спуск круче 30° сразу в такой же подъём) цель хвата за
	одну длину тележки уходит на 43, доводка за ней не успевает, и по строгой мерке толкающий
	«стоял перед ручкой» - сервер молча отпускал тележку на дне.
]]
function Kin.HoldKept(hx, hy, pose)
	if !pose then
		return Kin.HoldInRange(hx, hy)
	end

	return Kin.HoldInRange(hx, hy, pose) or Kin.HoldInRange(hx + Kin.HandleShift(pose), hy, pose)
end

-- Шаг доводки хвата к цели за тик: экспонента, но не быстрее HOLD_EASE и не медленнее HOLD_CREEP.
local function HoldStep(diff, dt)
	return math.min(HOLD_EASE * dt, math.max(math.abs(diff) * (1 - math.exp(-dt / HOLD_TAU)), HOLD_CREEP * dt))
end

--[[
	Оси позы для угла сущности: вперёд f = (c, s, a) / sqrt(1 + a²) и вверх
	u = f × l, где l = (-s, c, b) / sqrt(1 + b²). Шесть чисел: f и u.
]]
function Kin.Basis(pose)
	local fx, fy, fz = pose.c * pose.cp, pose.s * pose.cp, pose.a * pose.cp
	local lx, ly, lz = -pose.s * pose.cr, pose.c * pose.cr, pose.b * pose.cr
	local ux, uy, uz = fy * lz - fz * ly, fz * lx - fx * lz, fx * ly - fy * lx
	local length = math.sqrt(ux * ux + uy * uy + uz * uz)

	return fx, fy, fz, ux / length, uy / length, uz / length
end

-- Поза без замеров колёс: затравка для FindFree по тому, как тележка стоит.
function Kin.Rest(x, y, z0, yaw, a, b)
	local r = math.rad(yaw)

	a, b = a or 0, b or 0

	return {
		x = x,
		y = y,
		yaw = yaw,
		c = math.cos(r),
		s = math.sin(r),
		z0 = z0,
		a = a,
		b = b,
		cp = 1 / math.sqrt(1 + a * a),
		cr = 1 / math.sqrt(1 + b * b)
	}
end

--[[
	NEW: высвобождение при захвате. Отпущенная тележка - физический проп, она
	может стоять носом в стене или под низкой полкой, а Step требует свободной
	исходной позы. Пробуем, где стоит, потом на 2, 4 и 6 во все восемь сторон;
	первая годная и свободная поза - та, за которую берутся. Нет такой - nil,
	тележка зажата.
]]
function Kin.FindFree(trace, prev, feetZ, top, ctx)
	ctx = ctx or {stats = {}}
	ctx.feetZ = feetZ

	local function Try(x, y)
		local pose = Kin.EvalPose(trace, x, y, prev.yaw, prev, ctx)

		if pose and Kin.BodyFree(trace, pose, top, ctx) then
			return pose
		end
	end

	local pose = Try(prev.x, prev.y)

	if pose then
		return pose
	end

	for _, distance in ipairs(FREE_STEPS) do
		for i = 0, FREE_DIRECTIONS - 1 do
			local r = 2 * math.pi * i / FREE_DIRECTIONS

			pose = Try(prev.x + distance * math.cos(r), prev.y + distance * math.sin(r))

			if pose then
				return pose
			end
		end
	end
end

-- Тот же ли ввод: памятка клиента пропускает повторный прогон команды только на точно тех же числах.
function Kin.SameInput(a, b)
	return a.p0x == b.p0x and a.p0y == b.p0y and a.p0z == b.p0z
		and a.p1x == b.p1x and a.p1y == b.p1y and a.p1z == b.p1z
		and a.eyeYaw == b.eyeYaw and a.dt == b.dt
end

local function NewState(S, pose, rate, hx, hy)
	return {pose = pose, rate = rate, hx = hx, hy = hy, load = S.load, top = S.top}
end

--[[
	ОДИН ШАГ = одна команда толкающего. Чистая функция: те же (S, input) - тот
	же результат на сервере и в предсказании клиента.

	input = {p0x, p0y, p0z, p1x, p1y, p1z, eyeYaw, dt}: ноги толкающего до и
	после движкового хода этой команды, его взгляд и длина тика.
	Возвращает новое S, разрешённый толкающему сдвиг (ax, ay) и info: turn,
	walk, slide - доли хода; normal, normal2 - нормали упора; overlap; why и
	wheel - почему не прошёл общий ход; stats - счёт трасс.
]]
function Kin.Step(trace, S, input)
	local stats = {}
	local ctx = {stats = stats}
	local info = {stats = stats}
	local A, top, dt = S.pose, S.top, input.dt
	local yaw1, rate1 = Kin.TurnTowards(A.yaw, S.rate, input.eyeYaw + 180, dt, S.load)
	-- Цель хвата - перекладина на том же месте перед ногами при наклоне исходной позы (оба реалма одинаково).
	local shiftX, shiftY = Kin.HandleShift(A)
	local hx1 = Approach(S.hx, REACH + shiftX, HoldStep(REACH + shiftX - S.hx, dt))
	local hy1 = Approach(S.hy, shiftY, HoldStep(shiftY - S.hy, dt))
	local dx, dy = input.p1x - input.p0x, input.p1y - input.p0y

	-- Всё сразу - обычный случай: четыре колеса и одна широкая трасса.
	ctx.feetZ = input.p1z

	local tx, ty = Kin.CenterFor(input.p1x, input.p1y, yaw1, hx1, hy1)
	local B, why, wheel = Kin.EvalPose(trace, tx, ty, yaw1, A, ctx)

	if B then
		local clear = Kin.Broadphase(trace, A, B, top, ctx)

		--[[
			Уклон, на котором широкая фаза бессильна (nil): весь ход проверяется так же, как первая
			попытка TryMove, - столбики по своим хордам и кузов в B. На чистом пандусе это 22 трассы
			вместо 63 разбора на поворот и шаг. Исходная поза здесь не проверяется: B свободна и
			столбики дошли - значит, ход ни во что не вдавил, даже если A в чём-то стояла.
		]]
		if clear == nil then
			clear = Kin.Columns(trace, A, B, top, ctx) >= 1 and Kin.BodyFree(trace, B, top, ctx)
		end

		if clear then
			return NewState(S, B, rate1, hx1, hy1), dx, dy, info
		end
	end

	info.why, info.wheel = why or "body", wheel

	--[[
		CHANGED: исходная поза уже в чём-то (ящики подняли верх под потолком,
		в тележку закрылась дверь, клиент разошёлся с сервером). Тележка
		замирает как есть, поворот гаснет, толкающий ходит свободно, а руки
		съезжают вслед за ним. Сервер отпускает её через полсекунды; глубже
		её не загонит ничто.
	]]
	if !Kin.BodyFree(trace, A, top, ctx) then
		local hx, hy = Kin.HoldOf(input.p1x, input.p1y, A)

		info.overlap = true

		return NewState(S, A, 0, hx, hy), dx, dy, info
	end

	--[[
		Упёрлись: сперва поворот (и доводка рук) вокруг ПРЕЖНЕГО места
		толкающего. Не довернулась - скорость поворота в ноль, иначе она копится
		и тележку потом рвёт. Руки пересчитываются от того, куда она встала, -
		центр снова ровно там, где их держат.
	]]
	ctx.feetZ = input.p0z

	local R, turned = A, 1

	--[[
		Курс тот же, хват тот же (с точностью до шума HoldOf) - поворачивать нечего: A и есть итог
		поворота, без пустой проверки в 22 трассы на каждой упёршейся команде.
	]]
	if yaw1 != A.yaw or math.abs(hx1 - S.hx) > HOLD_SAME or math.abs(hy1 - S.hy) > HOLD_SAME then
		local rx, ry = Kin.CenterFor(input.p0x, input.p0y, yaw1, hx1, hy1)

		R, turned = Kin.TryMove(trace, A, rx, ry, yaw1, top, ctx)
	end

	local rate = turned >= 1 and rate1 or 0
	local hx, hy = Kin.HoldOf(input.p0x, input.p0y, R)

	info.turn = turned

	-- Потом сам шаг, и одно скольжение остатка вдоль того, во что упёрлись.
	ctx.feetZ = input.p1z

	local T, walked, normal = Kin.TryMove(trace, R, R.x + dx, R.y + dy, R.yaw, top, ctx)
	local ax, ay = dx * walked, dy * walked

	info.walk, info.normal = walked, normal

	if walked < 1 and normal then
		local restX, restY = dx * (1 - walked), dy * (1 - walked)
		local into = restX * normal.x + restY * normal.y
		local sx, sy = restX - normal.x * into, restY - normal.y * into

		if sx * sx + sy * sy > SLIDE_MIN then
			local slid, normal2

			T, slid, normal2 = Kin.TryMove(trace, T, T.x + sx, T.y + sy, T.yaw, top, ctx)
			ax, ay = ax + sx * slid, ay + sy * slid
			info.slide, info.normal2 = slid, normal2
		end
	end

	return NewState(S, T, rate, hx, hy), ax, ay, info
end
