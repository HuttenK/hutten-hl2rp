--[[
	ХОД ТЕЛЕЖКИ В ДВИЖЕНИИ ТОЛКАЮЩЕГО.

	Тележку, которую везут, шагает Kin.Step (sh_kinematics.lua) - раз на каждую команду
	толкающего, здесь, в его FinishMove, на обоих реалмах. Сервер держит настоящую позу
	(cart.drive) и ставит туда замороженный проп (ENT:ApplyDrive). Клиент толкающего считает
	ту же позу тем же кодом из своей истории по номерам команд (PushCart.Pred), а снимок
	дататейбла - номер команды PushCmd и поза на ней - её подтверждает или правит. Толкающего
	в тележку не пускают, подрезая его же ход в той же команде по настоящей нормали упора:
	на клиенте и сервере выходит одно и то же, без флага, защёлки и второй, рисованной позы.

	Тележка из прежнего кода (без дататейбла хода, см. HasDriveVars) этими хуками не
	трогается: они молчат, пока сущность не умеет ход.
]]

local PLUGIN = PLUGIN
local PushCart = ix.PushCart
local Kin = PushCart.Kin

-- Толкающий дальше этого от места, где его руки на ручке, - его переставили (телепорт): отпустить.
local TELEPORT_GAP = 16
-- Сколько команд клиент помнит позади самой новой.
local HISTORY = 128
--[[
	Расхождение снимка сервера с предсказанием на той же команде, которое ещё шум: поля
	дататейбла - float32, а клиент считает в double. В пределах - клиент оставляет своё,
	иначе его правка сама становилась бы ошибкой на каждом снимке.
]]
local SYNC_YAW = 0.05
local SYNC_RATE = 0.5
local SYNC_HOLD = 0.05
local SYNC_XY = 0.05
local SYNC_Z = 0.1
local SYNC_SLOPE = 0.002
-- Толкающий сдвинулся между двумя командами меньше этого - доля для отрисовки не считается.
local DRAW_STILL = 0.01
local RENDER_RANGE = 1200
-- Ящики рисуются не там, где их сущность: границы отрисовки шире, иначе их отсечёт раньше времени.
local RENDER_PAD = Vector(32, 32, 32)
local DEBUG_INTERVAL = 0.5

local DEBRIS_GROUPS = {
	[COLLISION_GROUP_DEBRIS] = true,
	[COLLISION_GROUP_DEBRIS_TRIGGER] = true,
	[COLLISION_GROUP_INTERACTIVE_DEBRIS] = true
}

--[[
	ЧТО ТЕЛЕЖКЕ НЕ ПОМЕХА - одно правило и для физики (ShouldCollide в sh_plugin.lua), и для
	трасс хода. Брошенные предметы и мелкие пропы она проезжает: банка под колесом валила её
	набок. Ящики груза, другие тележки и всё крупное упираются. Правило зависит только от
	класса и модели и за жизнь сущности не меняется (иначе понадобился бы CollisionRulesChanged).
]]
local function Ignores(other)
	if other:GetClass() == "ix_item" then
		return true
	end

	if other:IsPlayer() or other.isCargoCrate or other.ixIsPushCart or other:GetMoveType() != MOVETYPE_VPHYSICS then
		return false
	end

	return other:BoundingRadius() < PushCart.SMALL_PROP_RADIUS
end

--[[
	Ответ запоминается на самой сущности: правило за её жизнь не меняется (см. выше), а спрашивают
	его физика на каждой паре касаний (ShouldCollide) и трассы хода на каждой встреченной сущности -
	четыре вызова движка каждый раз впустую.
]]
function PushCart:CartIgnores(other)
	local ignores = other.ixCartIgnores

	if ignores == nil then
		ignores = Ignores(other)
		other.ixCartIgnores = ignores
	end

	return ignores
end

--[[
	Фильтр трасс хода - один на файл, без замыкания на каждую тележку: у тележки, поставленной
	до горячей перезагрузки, закэшированное замыкание осталось бы старым. Перед шагом сюда
	кладут ту тележку, которую шагают (PushCart:TraceFor).

	Насквозь: сама тележка и всё к ней прикрученное (ящики), люди, NPC, оружие, мусор (debris)
	и то, что ей не помеха по CartIgnores. Мир, двери, крупные пропы, свободные ящики и другие
	тележки - упор.

	Группа WEAPON - то, сквозь что ходят и люди: ящик или проп в руках ix_hands, лут с NotSolid,
	тела. Иначе ящик, который несут грузить, входил в кузов удерживаемой тележки, и её
	отпускало «упёрлась». Группа доходит до клиента, так что оба реалма видят одно; держателя
	(ixHeldOwner) знает только сервер - по нему реалмы разошлись бы. Сама тележка, пока её везут
	и пока из неё не вышли люди, тоже в WEAPON - и тоже упор.
]]
local filterCart = NULL

local function KinFilter(entity)
	if entity == filterCart then
		return false
	end

	local parent = entity:GetParent()

	if IsValid(parent) and parent == filterCart then
		return false
	end

	if entity:IsPlayer() or entity:IsNPC() or entity:IsNextBot() or entity:IsWeapon() then
		return false
	end

	local group = entity:GetCollisionGroup()

	if DEBRIS_GROUPS[group] then
		return false
	end

	if group == COLLISION_GROUP_WEAPON and !entity.ixIsPushCart then
		return false
	end

	return !PushCart:CartIgnores(entity)
end

local traceStart, traceEnd, traceMins, traceMaxs = Vector(), Vector(), Vector(), Vector()
local traceData = {
	start = traceStart,
	endpos = traceEnd,
	mins = traceMins,
	maxs = traceMaxs,
	mask = MASK_PLAYERSOLID,
	filter = KinFilter
}

--[[
	Трасса для Kin: его таблицы {x, y, z} - в четыре одних и тех же Vector, маска игрока.
	Пандусы из playerclip над лестницами для тележки - земля, как и для людей.
]]
local function Trace(d)
	traceStart:SetUnpacked(d.start.x, d.start.y, d.start.z)
	traceEnd:SetUnpacked(d.endpos.x, d.endpos.y, d.endpos.z)
	traceMins:SetUnpacked(d.mins.x, d.mins.y, d.mins.z)
	traceMaxs:SetUnpacked(d.maxs.x, d.maxs.y, d.maxs.z)

	return util.TraceHull(traceData)
end

--- Трасса Kin для этой тележки: ей же пользуется захват (Kin.FindFree в ENT:StartPush).
function PushCart:TraceFor(cart)
	filterCart = cart

	return Trace
end

-- Driving uses +X towards the handle; the EP2 model has its handle on -X.
function PushCart:PoseTransform(pose)
	local fx, fy, fz, ux, uy, uz = Kin.Basis(pose)
	local bottom = Kin.WHEEL_BOTTOM
	local position = Vector(pose.x - ux * bottom, pose.y - uy * bottom, pose.z0 - uz * bottom)

	return position, self:FlipModelAngles(Vector(fx, fy, fz):AngleEx(Vector(ux, uy, uz)))
end

--[[
	ДАТАТЕЙБЛ ХОДА (ENT:SetupDataTables): поза после команды PushCmd. Пишет сервер после каждой
	команды (ENT:ApplyDrive), читает клиент толкающего (Pred:Sync). Одна пара функций - одна
	раскладка полей на обоих концах.
]]
function PushCart:WriteDrive(cart, S, command)
	local pose = S.pose

	cart:SetPushYaw(pose.yaw)
	cart:SetPushRate(S.rate)
	cart:SetHoldX(S.hx)
	cart:SetHoldY(S.hy)
	cart:SetPoseX(pose.x)
	cart:SetPoseY(pose.y)
	cart:SetPoseZ(pose.z0)
	cart:SetPoseA(pose.a)
	cart:SetPoseB(pose.b)
	cart:SetPushCmd(command)
end

function PushCart:ReadDrive(cart)
	local pose = Kin.Rest(cart:GetPoseX(), cart:GetPoseY(), cart:GetPoseZ(), cart:GetPushYaw(),
		cart:GetPoseA(), cart:GetPoseB())

	return {pose = pose, rate = cart:GetPushRate(), hx = cart:GetHoldX(), hy = cart:GetHoldY()}
end

-- Через обёртку: у тележки из прежнего кода или поставленной до горячей перезагрузки полей хода нет.
local function HasDriveVars(cart)
	return cart.HasDriveVars != nil and cart:HasDriveVars()
end

-- Где руки толкающего (его ноги по горизонтали) для состояния S: центр плюс хват, повёрнутый курсом.
local function PusherFor(S)
	local pose = S.pose

	return pose.x + S.hx * pose.c - S.hy * pose.s, pose.y + S.hx * pose.s + S.hy * pose.c
end

-- ─────────────────────────────────────────────────────────────
-- ПОДРЕЗКА ХОДА ТОЛКАЮЩЕГО
-- ─────────────────────────────────────────────────────────────

-- Из скорости уходит только то, что направлено в упор; вдоль стены идти можно.
local function ClipAgainst(vx, vy, nx, ny)
	local into = vx * nx + vy * ny

	if into < 0 then
		return vx - nx * into, vy - ny * into
	end

	return vx, vy
end

-- Упор без нормали (колёса, уклон, ручка): уходит ход в ту сторону, куда шли.
local function ClipAlong(vx, vy, dx, dy)
	local length = math.sqrt(dx * dx + dy * dy)

	if length < 1e-6 then
		return vx, vy
	end

	dx, dy = dx / length, dy / length

	local along = vx * dx + vy * dy

	if along > 0 then
		return vx - dx * along, vy - dy * along
	end

	return vx, vy
end

local function ClipVelocity(vx, vy, input, info)
	local dx, dy = input.p1x - input.p0x, input.p1y - input.p0y
	local normal = info.normal

	if normal then
		vx, vy = ClipAgainst(vx, vy, normal.x, normal.y)
	else
		vx, vy = ClipAlong(vx, vy, dx, dy)
	end

	-- Скольжение вдоль стены тоже упёрлось: с нормалью - по ней, без - вдоль самого скольжения.
	if info.normal2 then
		vx, vy = ClipAgainst(vx, vy, info.normal2.x, info.normal2.y)
	elseif normal and info.slide and info.slide < 1 then
		local into = dx * normal.x + dy * normal.y

		vx, vy = ClipAlong(vx, vy, dx - normal.x * into, dy - normal.y * into)
	end

	return vx, vy
end

local groundStart, groundEnd = Vector(), Vector()
local groundFilter = {}
local groundData = {
	start = groundStart,
	endpos = groundEnd,
	mask = MASK_PLAYERSOLID,
	collisiongroup = COLLISION_GROUP_PLAYER_MOVEMENT,
	filter = groundFilter
}

--[[
	Высота ног в подрезанной точке. Сперва с той высоты, где ноги оставил движок (p1z): корпус
	там помещается - земля ищется под ним на шаг вниз. Не помещается - точка выше по склону или
	на ступени (движок увёл ноги вниз, а подрезка оставила их наверху): тогда с шага вверх.
	Сразу с шага вверх, как было, нельзя: под потолком ниже 90 (трубы, вагон, низкий проём)
	поднятый корпус начинал в потолке, и толкающего возвращало назад на каждой подрезке - он
	вставал вместо того, чтобы идти вдоль стены. false - корпус не помещается ни так, ни так.
]]
local function GroundAt(client, cart, x, y, z)
	local step = client:GetStepSize()
	local mins, maxs

	if client:Crouching() then
		mins, maxs = client:GetHullDuck()
	else
		mins, maxs = client:GetHull()
	end

	groundStart:SetUnpacked(x, y, z)
	groundEnd:SetUnpacked(x, y, z - step)
	groundData.mins, groundData.maxs = mins, maxs
	groundFilter[1], groundFilter[2] = client, cart

	local tr = util.TraceHull(groundData)

	if tr.StartSolid then
		groundStart:SetUnpacked(x, y, z + step)
		tr = util.TraceHull(groundData)

		if tr.StartSolid then
			return false
		end
	end

	return tr.Hit and tr.HitPos.z or z
end

--[[
	ПОДРЕЗАТЬ ХОД ТОЛКАЮЩЕГО до того, что разрешила тележка, в той же команде: тогда клиент и
	сервер приходят к одному и тому же, и резины нет. В воздухе высоту не трогаем. Не
	помещается в подрезанной точке - остаётся, где стоял, и стоит. Скорость - только через
	mv: ply:SetVelocity прибавляет, а не ставит.
	entry - запись истории клиента: высота ног в ней запоминается вместе с шагом тележки.
	Возвращает, где по горизонтали оказался толкающий.
]]
local function ClampPlayer(client, mv, cart, input, ax, ay, info, entry)
	local velocity = mv:GetVelocity()
	local x, y, z = input.p0x + ax, input.p0y + ay, input.p1z

	if client:OnGround() then
		local groundZ = entry and entry.groundZ

		if groundZ == nil then
			groundZ = GroundAt(client, cart, x, y, z)

			if entry then
				entry.groundZ = groundZ
			end
		end

		if groundZ == false then
			mv:SetOrigin(Vector(input.p0x, input.p0y, input.p0z))
			mv:SetVelocity(Vector(0, 0, velocity.z))

			return input.p0x, input.p0y
		end

		z = groundZ
	end

	local vx, vy = ClipVelocity(velocity.x, velocity.y, input, info)

	mv:SetOrigin(Vector(x, y, z))
	mv:SetVelocity(Vector(vx, vy, velocity.z))

	return x, y
end

local function Clamped(input, ax, ay)
	return ax != input.p1x - input.p0x or ay != input.p1y - input.p0y
end

local function StepState(S, load, top)
	return {pose = S.pose, rate = S.rate, hx = S.hx, hy = S.hy, load = load, top = top}
end

-- ─────────────────────────────────────────────────────────────
-- СЕРВЕР
-- ─────────────────────────────────────────────────────────────

local function Fraction(value)
	return value and string.format("%.2f", value) or "-"
end

local function NormalText(normal)
	return normal and string.format("(%.2f %.2f)", normal.x, normal.y) or "-"
end

-- Колесо: земля / окно (плоскость прежней позы под ним) и что с ним было при общем ходе.
local function WheelsText(pose, base, info)
	if !pose.g then
		return "-"
	end

	local parts = {}

	for i = 1, 4 do
		local anchor = Kin.PlaneAt(base, pose.wx[i], pose.wy[i])

		parts[i] = string.format("%.1f/%.1f %s", pose.g[i], anchor, info.wheel == i and info.why or "ok")
	end

	return table.concat(parts, ", ")
end

local function PrintDebug(client, cart, command, base, S, info)
	local now = CurTime()

	if (cart.nextDriveDebug or 0) > now then
		return
	end

	cart.nextDriveDebug = now + DEBUG_INTERVAL

	local pose = S.pose
	local traces = 0

	for _, count in pairs(info.stats) do
		traces = traces + count
	end

	client:PrintMessage(HUD_PRINTCONSOLE, string.format(
		"[тележка %s, поставлена %s] команда %d: x %.1f y %.1f z %.1f курс %.1f тангаж %.1f крен %.1f "
			.. "поворот %.0f/с руки %.1f %.1f | колёса ПЛ ПП ЗЛ ЗП: %s | общий ход: %s | поворот %s шаг %s "
			.. "скольжение %s нормали %s %s | трасс %d | упор %s%s | в воздухе %s",
		PushCart.BUILD, tostring(cart.spawnBuild or "?"), command, pose.x, pose.y, pose.z0, pose.yaw,
		math.deg(math.atan(pose.a)), math.deg(math.atan(pose.b)), S.rate, S.hx, S.hy,
		WheelsText(pose, base.pose, info), info.why or "прошёл",
		Fraction(info.turn), Fraction(info.walk), Fraction(info.slide), NormalText(info.normal),
		NormalText(info.normal2), traces, info.overlap and "да" or "нет",
		cart.overlapSince and string.format(" %.2f с", now - cart.overlapSince) or "",
		cart.airSince and string.format("%.2f с", now - cart.airSince) or "нет"))
end

--[[
	Перед командой на сервере. Только что взяли (fresh) - хват пересчитывается от того, где
	толкающий стоит на первой команде: между E и ней он мог чуть сдвинуться, а центр тележки
	обязан быть ровно у его рук. Толкающий вдруг далеко от ручки - его переставили: флаг
	отпускания (ENT:ShouldRelease), а шаг пропускается.
]]
local function PrepareServerMove(cart, origin)
	local drive = cart.drive

	if !drive then
		return false
	end

	local pose = drive.pose

	if drive.fresh then
		drive.hx, drive.hy = Kin.HoldOf(origin.x, origin.y, pose)
		drive.fresh = nil
	end

	local x, y = Kin.CenterFor(origin.x, origin.y, pose.yaw, drive.hx, drive.hy)

	if (x - pose.x) ^ 2 + (y - pose.y) ^ 2 > TELEPORT_GAP * TELEPORT_GAP then
		cart.releaseFlag = true

		return false
	end

	return true
end

local function ServerStep(client, mv, cart, command, input)
	local drive = cart.drive

	if !drive then
		return
	end

	local base = StepState(drive, cart:GetCargoLoad(), cart:GetBodyTop())

	filterCart = cart

	local S, ax, ay, info = Kin.Step(Trace, base, input)

	if Clamped(input, ax, ay) then
		ClampPlayer(client, mv, cart, input, ax, ay, info)
	end

	cart.drive = S
	cart:ApplyDrive(S, command)

	-- Счёт времени упора и полёта, отпускает ENT:Think: состояние, а не звук - без IsFirstTimePredicted.
	local now = CurTime()

	cart.overlapSince = info.overlap and (cart.overlapSince or now) or nil
	cart.airSince = !client:OnGround() and (cart.airSince or now) or nil

	--[[
		Ноги дальше HANDLE_DZ по высоте от ручки (сошёл с уступа, пока тянул тележку; уехал на
		лифте без неё): Kin не примет ни одной позы, и толкающий стоит, куда бы ни шёл. Сам он
		не выберется - через HANDLE_RELEASE его отпускает ENT:Think.
	]]
	local handleZ = Kin.HandleZ(S.pose)
	local reach = math.abs(handleZ - mv:GetOrigin().z)

	cart.handleSince = reach > Kin.HANDLE_DZ and (cart.handleSince or now) or nil

	if client.ixPushCartDebug then
		PrintDebug(client, cart, command, base, S, info)
	end
end

-- ─────────────────────────────────────────────────────────────
-- КЛИЕНТ ТОЛКАЮЩЕГО: ИСТОРИЯ ПО НОМЕРАМ КОМАНД
-- ─────────────────────────────────────────────────────────────

--[[
	cart.ixPred = {hist, ack, newest}. hist[n] - состояние после команды n: S, где оказался
	толкающий (px, py), и ключ памятки - на чём и с каким вводом её считали (base, input, load,
	top). ack - последний PushCmd из снимка, newest - самая новая команда.
]]
local Pred = PushCart.Pred or {}

PushCart.Pred = Pred

local function Diverged(S, server)
	local mine, theirs = S.pose, server.pose

	return math.abs(Kin.AngleDiff(mine.yaw, theirs.yaw)) > SYNC_YAW
		or math.abs(S.rate - server.rate) > SYNC_RATE
		or math.abs(S.hx - server.hx) > SYNC_HOLD or math.abs(S.hy - server.hy) > SYNC_HOLD
		or math.abs(mine.x - theirs.x) > SYNC_XY or math.abs(mine.y - theirs.y) > SYNC_XY
		or math.abs(mine.z0 - theirs.z0) > SYNC_Z
		or math.abs(mine.a - theirs.a) > SYNC_SLOPE or math.abs(mine.b - theirs.b) > SYNC_SLOPE
end

--[[
	Команда после поправленной: курс, скорость поворота и хват сдвигаются на ту же поправку,
	центр заново ставится к рукам там, где толкающий тогда стоял, высота - с прежней плоскости.
	Новые таблицы, а не правка на месте: так памятка следующей команды видит, что её база другая.
]]
local function Shifted(entry, dyaw, drate, dhx, dhy)
	local S, pose = entry.S, entry.S.pose
	local yaw = Kin.Norm(pose.yaw + dyaw)
	local hx, hy = S.hx + dhx, S.hy + dhy
	local x, y = Kin.CenterFor(entry.px, entry.py, yaw, hx, hy)
	local moved = Kin.Rest(x, y, Kin.PlaneAt(pose, x, y), yaw, pose.a, pose.b)

	return {
		S = {pose = moved, rate = S.rate + drate, hx = hx, hy = hy, load = S.load, top = S.top},
		px = entry.px,
		py = entry.py
	}
end

--[[
	Команда после поправленной заново шагается от поправленной же, тем же вводом: так история
	сразу совпадает с тем, что посчитает сервер, и следующий снимок поправки уже не требует.
	Сдвиг на ту же поправку (Shifted) - только для записи без ввода (засев со снимка): её шагать
	нечем. Прежде сдвигались все: поворот с инерцией от сдвинутой скорости идёт не так, как от
	настоящей, и при пинге в 200 мс на виражах тележку дёргало поправками до градуса каждый пинг.
]]
local function Restep(cart, entry, base)
	local input = entry.input

	filterCart = cart

	local S, ax, ay, info = Kin.Step(Trace, StepState(base, entry.load, entry.top), input)
	local px, py = input.p1x, input.p1y

	if Clamped(input, ax, ay) then
		px, py = input.p0x + ax, input.p0y + ay
	end

	return {S = S, ax = ax, ay = ay, info = info, base = base, input = input, load = entry.load, top = entry.top,
		px = px, py = py}
end

local function Correct(cart, pred, command, old, server)
	local hist = pred.hist
	local px, py = PusherFor(server)
	local dyaw = Kin.AngleDiff(server.pose.yaw, old.pose.yaw)
	local drate, dhx, dhy = server.rate - old.rate, server.hx - old.hx, server.hy - old.hy
	local previous = {S = server, px = px, py = py}

	hist[command] = previous

	for k = command + 1, pred.newest do
		local entry = hist[k]

		if entry and entry.px then
			if entry.input then
				entry = Restep(cart, entry, previous.S)
			else
				entry = Shifted(entry, dyaw, drate, dhx, dhy)
			end

			hist[k] = entry
			previous = entry
		end
	end
end

--[[
	Сверка со снимком: PushCmd сменился - сервер прислал позу после этой команды. Разошлись
	больше шума - серверная встаёт на место своей, а более поздние сдвигаются на ту же поправку.
	Это нужно и тогда, когда движок повторно команды не прогоняет (cl_pred_optimize 2 - при
	ошибке игрока он их перепрогонит сам, а при ошибке одной тележки нет).

	Своей записи о команде нет (только что взяли: клиент узнал о захвате позже сервера) -
	серверная встаёт в историю, всё старше выбрасывается, а всё НОВЕЕ остаётся. Новее - живые
	предсказания команд, которые сервер ещё не подтвердил, и движок их сам не перепрогонит.
	Прежде здесь начиналась новая история из одной записи: снимок отстаёт от клиента на пинг,
	следующий снова не находил своей записи, и так каждый тик - тележка шагала от позы
	пинговой давности, курс отставал на весь пинг, а новая таблица истории каждый раз
	перезапускала переход отрисовки (ENT:GetDrawPose), и тележку рисовало позади рук.
	Таблица cart.ixPred поэтому одна на весь захват.
]]
function Pred:Sync(cart)
	local command = cart:GetPushCmd()

	if command == 0 then
		cart.ixPred = nil

		return
	end

	local pred = cart.ixPred

	if pred and pred.ack == command then
		return
	end

	local server = PushCart:ReadDrive(cart)
	local entry = pred and pred.hist[command]

	if !entry then
		local px, py = PusherFor(server)
		local seed = {S = server, px = px, py = py}

		if !pred then
			cart.ixPred = {hist = {[command] = seed}, ack = command, newest = command}

			return
		end

		local hist = pred.hist

		for k in pairs(hist) do
			if k < command then
				hist[k] = nil
			end
		end

		hist[command] = seed
		pred.ack, pred.newest = command, math.max(pred.newest, command)

		return
	end

	if Diverged(entry.S, server) then
		Correct(cart, pred, command, entry.S, server)
	end

	pred.ack = command
end

--[[
	Что рисовать толкающему: курс и хват между двумя последними командами - на той доле, на
	какой движок рисует его самого (по его отрисованной позиции между ними). Иначе курс
	тележки обгонял бы его тело на тик. Плоскость - с последней команды.
	Возвращает yaw, hx, hy и позу с плоскостью; nil - истории нет.
	Без истории (одиночная игра) - то же по снимкам хода: Pred:ObservedPose ниже.
]]
function Pred:DrawState(cart, origin)
	local pred = cart.ixPred
	local last = pred and pred.hist[pred.newest]

	if !last then
		return
	end

	local S1 = last.S
	local previous = pred.hist[pred.newest - 1]

	if !previous then
		return S1.pose.yaw, S1.hx, S1.hy, S1.pose
	end

	local S0 = previous.S
	local dx, dy = last.px - previous.px, last.py - previous.py
	local length = dx * dx + dy * dy
	--[[
		Стоит - доля по часам: движок рисует предсказанного игрока между двумя последними командами
		на дробной части времени в тиках (interpolation_amount). Прежде здесь была 1, и разворот на
		месте шёл ступенями по тику.
	]]
	local ticks = CurTime() / engine.TickInterval()
	local t = ticks - math.floor(ticks)

	--[[
		Часы перешли на следующий тик раньше, чем пришла его команда (округление времени у самой
		границы тика), - доля обнулилась, а самая новая команда та же: тележка на кадр отскакивала
		на целый тик назад. При той же команде доля только растёт; ушла назад - тело уже в её конце.
	]]
	if pred.stillCmd == pred.newest and t < pred.stillT then
		t = 1
	end

	pred.stillCmd, pred.stillT = pred.newest, t

	if length >= DRAW_STILL * DRAW_STILL then
		t = math.Clamp(((origin.x - previous.px) * dx + (origin.y - previous.py) * dy) / length, 0, 1)
	end

	local yaw = Kin.Norm(S0.pose.yaw + Kin.AngleDiff(S1.pose.yaw, S0.pose.yaw) * t)

	return yaw, Lerp(t, S0.hx, S1.hx), Lerp(t, S0.hy, S1.hy), S1.pose
end

-- Центр ровно у рук толкающего в origin при этом курсе и хвате, высота - с плоскости.
local function PlaceAt(origin, yaw, hx, hy, plane)
	local x, y = Kin.CenterFor(origin.x, origin.y, yaw, hx, hy)

	return Kin.Rest(x, y, Kin.PlaneAt(plane, x, y), yaw, plane.a, plane.b)
end

-- Поза для отрисовки у толкающего: центр ровно у его отрисованных рук (DrawState), высота с плоскости.
function Pred:DrawPose(cart, origin)
	local yaw, hx, hy, plane = self:DrawState(cart, origin)

	if !yaw then
		return
	end

	return PlaceAt(origin, yaw, hx, hy, plane)
end

--[[
	СВОЙ ТОЛКАЮЩИЙ БЕЗ ИСТОРИИ. В одиночной игре движок не зовёт SetupMove и FinishMove на
	клиенте вовсе (предсказываемые хуки там только серверные), и cart.ixPred не бывает никогда; в
	сетевой её нет первые тики захвата. Тележку тогда рисовали по сущности, а сущность и тело
	толкающего движок ведёт каждое по своему времени: тележка шла чуть позади рук, руки тянулись
	за ней - «тележка лагает».
	Поэтому и здесь центр ставится от того места, где нарисовано тело, а курс, хват и плоскость
	берутся со снимков хода на том времени, на каком нарисовано тело. Каждый снимок - поза после
	команды PushCmd, и толкающий тогда стоял ровно в PusherFor(S).
	* Тело идёт - время по месту: отрезок ломаной этих точек, на котором оно стоит, и доля на нём
	  (как DrawState). Только последние RECENT_SEGMENTS отрезков и только до их нового конца: тело
	  у конца отрезка, после которого стояли, могло простоять там сколько угодно. Прежде ломаная
	  бралась целиком - остановился и повернулся, и тележка держала курс последнего шага до
	  полусекунды, а потом прыгала на 30-50°.
	* Тело стоит (или впереди снимков) - время по часам: номер команды «сейчас» восстанавливается
	  по тому, когда пришли снимки (lead), минус задержка тела в командах (delay). Задержку меряет
	  первый путь, пока тело идёт, - переход между путями без скачка. Прежде здесь брался самый
	  новый снимок как есть, и разворот на месте шёл ступенями по тику.
]]
local SAMPLES = 32
local SAMPLE_REACH = 8
local RECENT_SEGMENTS = 4
--[[
	Тело ближе этого (доля отрезка) к концу отрезка - время по месту не определить: на конце мог
	кончиться ход. При кадрах реже тиков отрезок тянется через пропущенный снимок, и остановка на нём
	читалась как «тело на самом новом снимке» - задержка обнулялась, и разворот на месте шёл впереди тела.
]]
local SEGMENT_END = 1e-3
-- Задержка тела за самым новым снимком, команд, пока её не измерили (одиночная: интерполяция в тик).
local BODY_DELAY = 1
local DELAY_MAX = 6
-- Постоянная времени, с которой оценка задержки догоняет замер, с: не от числа кадров, иначе при 40 к/с она ползла бы.
local DELAY_TAU = 0.1

-- Снимки хода по порядку команд; новый - когда PushCmd сменился. nil - тележку не везут.
function Pred:Observe(cart, pusher)
	local command = cart:GetPushCmd()

	if command == 0 then
		cart.ixSamples = nil

		return
	end

	local samples = cart.ixSamples

	-- Таблица от прежнего кода (горячая перезагрузка посреди захвата): ни задержки, ни lead - заново.
	if samples and samples.delay == nil then
		samples = nil
	end

	local count = samples and #samples or 0

	if count > 0 then
		local last = samples[count]

		if samples.pusher == pusher and last.cmd == command then
			return samples
		end

		-- Другой толкающий или номера пошли заново - прежние точки не его.
		if samples.pusher != pusher or command < last.cmd then
			samples, count = nil, 0
		end
	end

	if !samples then
		samples = {pusher = pusher, delay = BODY_DELAY}
		cart.ixSamples = samples
	end

	if count >= SAMPLES then
		table.remove(samples, 1)
		count = count - 1
	end

	local S = PushCart:ReadDrive(cart)
	local px, py = PusherFor(S)

	--[[
		lead: номер команды минус номер тика, в котором снимок пришёл (целая часть часов). Снимок
		приходит в тик своей команды или позже, поэтому наибольший lead окна - часы. Целая часть, а не
		время прихода: кадр видит снимок с опозданием до кадра, и при кадрах реже тиков часы по времени
		прихода отставали на долю тика. Дробная часть часов - та доля, на которой движок рисует тело.
	]]
	local lead = command - math.floor(CurTime() / engine.TickInterval())

	samples[count + 1] = {cmd = command, S = S, px = px, py = py, lead = lead}

	return samples
end

-- Номер команды «сейчас» по часам снимков (дробный).
local function CommandNow(samples)
	local lead = -math.huge

	for _, sample in ipairs(samples) do
		lead = math.max(lead, sample.lead)
	end

	return CurTime() / engine.TickInterval() + lead
end

local function Between(S0, S1, t)
	local yaw = Kin.Norm(S0.pose.yaw + Kin.AngleDiff(S1.pose.yaw, S0.pose.yaw) * t)

	return yaw, Lerp(t, S0.hx, S1.hx), Lerp(t, S0.hy, S1.hy), S1.pose
end

-- Курс, хват и плоскость на дробном номере команды (за краями окна - крайний снимок).
local function AtCommand(samples, command)
	local count = #samples
	local newest = samples[count].S

	if command >= samples[count].cmd then
		return newest.pose.yaw, newest.hx, newest.hy, newest.pose
	end

	for i = count, 2, -1 do
		local a = samples[i - 1]

		if command >= a.cmd then
			local b = samples[i]

			return Between(a.S, b.S, (command - a.cmd) / (b.cmd - a.cmd))
		end
	end

	local oldest = samples[1].S

	return oldest.pose.yaw, oldest.hx, oldest.hy, oldest.pose
end

--[[
	Где на последних отрезках ломаной снимков стоит тело в origin: номер отрезка (его новый конец) и
	доля на нём; nil - не на них. С нового конца: на стыке двух отрезков (и на ломаной, прошедшей
	себя же) выигрывает новый. Третий ответ - тело впереди самого нового снимка, по ходу последнего
	отрезка: доля за 1 (время им не берётся, только меряется задержка - она около нуля).
]]
local function AlongSamples(samples, origin)
	local count = #samples
	local best, bestT, bestDistance = nil, nil, SAMPLE_REACH * SAMPLE_REACH
	local ahead

	for i = count, math.max(2, count - RECENT_SEGMENTS + 1), -1 do
		local a, b = samples[i - 1], samples[i]
		local dx, dy = b.px - a.px, b.py - a.py
		local length = dx * dx + dy * dy

		if length >= DRAW_STILL * DRAW_STILL then
			local along = ((origin.x - a.px) * dx + (origin.y - a.py) * dy) / length
			local t = math.Clamp(along, 0, 1)
			local ex, ey = origin.x - (a.px + dx * t), origin.y - (a.py + dy * t)
			local distance = ex * ex + ey * ey

			if t < 1 - SEGMENT_END and distance < bestDistance then
				best, bestT, bestDistance = i, t, distance
			elseif i == count and along > 1 + SEGMENT_END then
				local sx, sy = origin.x - (a.px + dx * along), origin.y - (a.py + dy * along)

				if sx * sx + sy * sy < SAMPLE_REACH * SAMPLE_REACH then
					ahead = along
				end
			end
		end
	end

	return best, bestT, !best and ahead or nil
end

-- Поза для отрисовки у своего толкающего без истории: центр у рук в origin, курс и хват со снимков.
function Pred:ObservedPose(cart, pusher, origin)
	local samples = self:Observe(cart, pusher)

	if !samples then
		return
	end

	local count = #samples
	local now = CommandNow(samples)
	local segment, t, ahead = AlongSamples(samples, origin)
	local measured

	if segment then
		local a, b = samples[segment - 1], samples[segment]

		measured = now - (a.cmd + (b.cmd - a.cmd) * t)
	elseif ahead then
		local a, b = samples[count - 1], samples[count]

		measured = now - (a.cmd + (b.cmd - a.cmd) * ahead)
	end

	--[[
		Задержка шагает раз за кадр от той, с которой кадр начался, а не от прошлого вопроса: позу
		спрашивают и до того, как движок поставил тело (кости в чужом Think), и такой замер не должен
		оставаться в оценке. Решает последний вопрос кадра.
	]]
	local frame = FrameNumber()

	if samples.frame != frame then
		samples.frame, samples.delayBase = frame, samples.delay
	end

	samples.delay = measured and Lerp(1 - math.exp(-FrameTime() / DELAY_TAU), samples.delayBase,
		math.Clamp(measured, 0, DELAY_MAX)) or samples.delayBase

	local yaw, hx, hy, plane

	if segment then
		yaw, hx, hy, plane = Between(samples[segment - 1].S, samples[segment].S, t)
	else
		yaw, hx, hy, plane = AtCommand(samples, now - samples.delay)
	end

	-- Для записи кадров (ix_pushcart_trace): отрезок от конца (1 - новейший) и доля; 0 и -1 - время по часам.
	cart.ixAlongSegment, cart.ixAlongT = segment and count - segment + 1 or 0, t or -1
	cart.ixBodyDelay = samples.delay

	return PlaceAt(origin, yaw, hx, hy, plane)
end

-- Самая новая запись раньше команды: база, если предыдущей нет (потеряна или история только началась).
local function OlderEntry(hist, command)
	local best, found

	for k, entry in pairs(hist) do
		if k < command and (!best or k > best) then
			best, found = k, entry
		end
	end

	return found
end

local function Prune(pred, command)
	local hist, oldest = pred.hist, command - HISTORY

	if command - pred.newest > HISTORY then
		for k in pairs(hist) do
			if k < oldest then
				hist[k] = nil
			end
		end
	else
		for k = pred.newest - HISTORY, oldest - 1 do
			hist[k] = nil
		end
	end

	pred.newest = command
end

--[[
	Шаг в предсказании. Движок прогоняет одну и ту же команду снова и снова, пока сервер её не
	подтвердит. Та же база (та же таблица) и тот же ввод - тот же ответ: памятка отдаёт прошлый
	шаг без единой трассы. Подрезка толкающего применяется каждый раз: mv каждый прогон свой.
]]
local function ClientStep(client, mv, cart, command, input)
	local pred = cart.ixPred

	if !pred then
		return
	end

	local hist = pred.hist
	local baseEntry = hist[command - 1] or OlderEntry(hist, command)

	if !baseEntry then
		return
	end

	local load, top = cart:GetCargoLoad(), cart:GetBodyTop()
	local entry = hist[command]
	local same = entry and entry.input and entry.base == baseEntry.S and entry.load == load and entry.top == top
		and Kin.SameInput(entry.input, input)

	if !same then
		filterCart = cart

		local S, ax, ay, info = Kin.Step(Trace, StepState(baseEntry.S, load, top), input)

		entry = {S = S, ax = ax, ay = ay, info = info, base = baseEntry.S, input = input, load = load, top = top}
		hist[command] = entry
	end

	local px, py = input.p1x, input.p1y

	if Clamped(input, entry.ax, entry.ay) then
		px, py = ClampPlayer(client, mv, cart, input, entry.ax, entry.ay, entry.info, entry)
	end

	entry.px, entry.py = px, py

	if command > pred.newest then
		Prune(pred, command)
	end
end

-- ─────────────────────────────────────────────────────────────
-- ХУКИ ХОДА (предсказываемые, оба реалма; ничего не возвращают - чужие хуки не глушатся)
-- ─────────────────────────────────────────────────────────────

function PLUGIN:SetupMove(client, mv, cmd)
	local cart = PushCart:GetPushedCart(client)

	if !cart or !HasDriveVars(cart) then
		client.ixCartMove = nil

		return
	end

	if CLIENT then
		Pred:Sync(cart)
	end

	local origin = mv:GetOrigin()

	if SERVER and !PrepareServerMove(cart, origin) then
		client.ixCartMove = nil

		return
	end

	client.ixCartMove = {cart = cart, n = cmd:CommandNumber(), p0x = origin.x, p0y = origin.y, p0z = origin.z}
end

function PLUGIN:FinishMove(client, mv)
	local move = client.ixCartMove

	if !move then
		return
	end

	client.ixCartMove = nil

	local cart = move.cart

	if !IsValid(cart) then
		return
	end

	local origin = mv:GetOrigin()
	local input = {
		p0x = move.p0x,
		p0y = move.p0y,
		p0z = move.p0z,
		p1x = origin.x,
		p1y = origin.y,
		p1z = origin.z,
		eyeYaw = mv:GetAngles().y,
		dt = engine.TickInterval()
	}

	if SERVER then
		ServerStep(client, mv, cart, move.n, input)
	else
		ClientStep(client, mv, cart, move.n, input)
	end
end

-- ─────────────────────────────────────────────────────────────
-- ТЕЛО ВДОЛЬ ТЕЛЕЖКИ
-- ─────────────────────────────────────────────────────────────

--[[
	Движок разворачивает модель толкающего за взглядом сразу, а тележка поворачивает за взглядом с
	инерцией (Kin.TurnTowards): руки оставались на ручке, а тело уходило вбок, и руки выкручивало за
	спину. Пока везут, модель стоит лицом туда же, куда тележка (по её нарисованной позе), ноги идут
	относительно этого (move_yaw), корпус прямо к ручке (aim_yaw 0), а к взгляду поворачивается одна
	голова (head_yaw, не дальше HEAD_YAW). Взялся и отпустил - тем же переходом, что и руки (вес из
	cl_ik.lua). SetRenderAngles движок сбрасывает сразу после UpdateAnimation, поэтому каждый кадр - так
	же ставит позу act у самого Helix.
]]
local HEAD_YAW = 70

-- Куда смотрит тележка толкающего (её зад - к нему) и насколько тело ей подчинено (0..1); nil - не везёт.
local function CartFacing(client)
	if CLIENT then
		local cart, weight = client.ixPushCartIKCart, client.ixPushCartIKWeight or 0

		if weight <= 0 or !IsValid(cart) or !cart.GetDrawPose then
			return
		end

		local _, angles = cart:GetDrawPose()

		return angles.y, weight
	end

	local cart = PushCart:GetPushedCart(client)

	if cart then
		return cart:GetAngles().y, 1
	end
end

--- Куда повёрнуто тело толкающего: между взглядом и тележкой по весу. nil - тело своё, за взглядом.
function PushCart:BodyYaw(client)
	local facing, weight = CartFacing(client)

	if !facing then
		return
	end

	local own = client:EyeAngles().y

	return own + math.AngleDifference(facing, own) * weight, weight
end

function PLUGIN:UpdateAnimation(client, velocity)
	local yaw, weight = PushCart:BodyYaw(client)

	if !yaw then
		return
	end

	local look = math.AngleDifference(client:EyeAngles().y, yaw)

	client:SetRenderAngles(Angle(0, yaw, 0))

	-- Helix ставит move_yaw от взгляда (GM:CalcMainActivity): ноги шли бы не туда, куда идёт тело.
	if velocity:Length2DSqr() > 0.25 then
		client:SetPoseParameter("move_yaw", math.NormalizeAngle(velocity:Angle().y - yaw))
	end

	client:SetPoseParameter("aim_yaw", look * (1 - weight))
	client:SetPoseParameter("head_yaw", math.Clamp(look * weight, -HEAD_YAW, HEAD_YAW))
end

-- ─────────────────────────────────────────────────────────────
-- ОТРИСОВКА: тележка и ящики на ней - в позе ENT:GetDrawPose, раз за кадр
-- ─────────────────────────────────────────────────────────────

if CLIENT then
	--[[
		Где сущность на самом деле. В GMod GetPos/GetAngles отдают то, что поставили SetRenderOrigin и
		SetRenderAngles, пока те стоят (и сам движок через GetAbsOrigin - тоже). Тележку подменяют
		каждый кадр, и по GetPos она читала СВОЮ ЖЕ позу прошлого кадра: падающая после спавна,
		съезжающая, отпущенная - стояла по нескольку кадров и прыгала («двигается по кадрам»).
		Подмену на время замера снимаем и ставим обратно.
	]]
	function PushCart:RealPose(entity)
		local origin, angles = entity:GetRenderOrigin(), entity:GetRenderAngles()

		if origin then
			entity:SetRenderOrigin(nil)
		end

		if angles then
			entity:SetRenderAngles(nil)
		end

		local position, rotation = entity:GetPos(), entity:GetAngles()

		if origin then
			entity:SetRenderOrigin(origin)
		end

		if angles then
			entity:SetRenderAngles(angles)
		end

		return position, rotation
	end

	local function ReleaseChildren(children, keep)
		if !children then
			return
		end

		for child in pairs(children) do
			if (!keep or !keep[child]) and IsValid(child) then
				child:SetRenderOrigin(nil)
				child:SetRenderAngles(nil)
			end
		end
	end

	-- Снять только то, что ставили сами: чужие подмены отрисовки не трогаем.
	local function ClearOverride(cart)
		if cart.ixRenderOverride then
			cart:SetRenderOrigin(nil)
			cart:SetRenderAngles(nil)
			cart.ixRenderOverride = nil
		end

		ReleaseChildren(cart.overriddenChildren)
		cart.overriddenChildren = nil
	end

	local function ApplyOverride(cart, position, angles)
		cart:SetRenderOrigin(position)
		cart:SetRenderAngles(angles)
		cart.ixRenderOverride = true

		local overridden = {}

		for _, child in ipairs(cart:GetChildren()) do
			if child.isCargoCrate or child.isCartPatient then
				if !child.ixRenderPadded then
					child:SetRenderBounds(child:OBBMins() - RENDER_PAD, child:OBBMaxs() + RENDER_PAD)
					child.ixRenderPadded = true
				end

				local childPosition, childAngles = LocalToWorld(child:GetLocalPos(), child:GetLocalAngles(),
					position, angles)

				child:SetRenderOrigin(childPosition)
				child:SetRenderAngles(childAngles)
				overridden[child] = true
			end
		end

		-- Ящик сняли с тележки, пока его рисовали сдвинутым: вернуть ему его место.
		ReleaseChildren(cart.overriddenChildren, overridden)
		cart.overriddenChildren = overridden
	end

	local function RenderCart(cart, viewer, range)
		if cart:GetPos():DistToSqr(viewer) > range then
			ClearOverride(cart)

			return
		end

		local position, angles = cart:GetDrawPose()
		local realPos, realAng = PushCart:RealPose(cart)

		if position == realPos and angles == realAng then
			ClearOverride(cart)
		else
			ApplyOverride(cart, position, angles)
		end
	end

	function PLUGIN:PreRender()
		local client = LocalPlayer()

		if !IsValid(client) then
			return
		end

		local viewer = client:GetPos()
		local range = RENDER_RANGE * RENDER_RANGE

		for cart in pairs(PushCart.carts) do
			-- Без GetDrawPose - тележка из прежнего кода, она рисует себя сама.
			if IsValid(cart) and cart.GetDrawPose then
				RenderCart(cart, viewer, range)
			end
		end
	end
end
