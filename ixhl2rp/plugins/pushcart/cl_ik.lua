--[[
	РУКИ НА РУЧКЕ. Своей анимации «толкает тележку» нет ни у одной модели
	сборки, а стоковые позы (свёрток у граждан, бочка у ГО) не совпадают с
	ручкой и у ГО не ходят. Поэтому ноги и корпус - обычная походка модели, а
	руки ставятся на перекладину двухзвенной IK поверх неё: одинаково для
	любой модели на скелете ValveBiped.

	Якорь - точка на ТЕЛЕЖКЕ, а не на кисти: решение по кисти, которую само же
	и двигает, схлопывается в тождество (так погиб прототип IK для TFA).

	Ставится в BuildBonePositions: там видны матрицы этого кадра после
	анимации, и правка не копится от кадра к кадру. Дочерние кости движок за
	нас не двигает - каждый поворот раздаём всему поддереву: плечо - всей
	руке, предплечье - от локтя вниз, разворот кисти - кисти с пальцами,
	сгиб пальца - его звеньям ниже сустава. Сервер не трогается: хитбоксы
	остаются от походки.

	Хват - сверху, как за перекладину: ладонь лежит на трубе, костяшка
	среднего пальца - на ней сверху-спереди, а пальцы ОБХОДЯТ трубу по
	окружности: каждый следующий сустав ставится на окружность обхвата на
	расстоянии своей фаланги (пересечение двух окружностей). Углов сгиба
	нет вовсе - так обхват точный при любых длинах пальцев (проверено на
	бинд-позах граждан, гражданок и ГО). Большой палец обходит трубу с
	обратной стороны, из-под ладони.
]]
local PushCart = ix.PushCart

--[[
	Хват на перекладине в координатах модели тележки (труба на x = 36.3,
	z = 47.2, от y = -12 до 12). Толкающий стоит на +X лицом в -X, значит его
	правая рука - на +Y. Место трубы - одно с Kin: по нему же ход держит её
	перед ногами на уклоне (Kin.HandleShift).
]]
PushCart.GRIP_RIGHT = Vector(PushCart.Kin.HANDLE_X, 9, PushCart.Kin.GRIP_Z)
PushCart.GRIP_LEFT = Vector(PushCart.Kin.HANDLE_X, -9, PushCart.Kin.GRIP_Z)
-- Окружность, по которой ложатся суставы пальцев: труба (радиус 0.9 по
-- вершинам модели) плюс половина толщины пальца.
PushCart.WRAP_RADIUS = 1.25
-- Где на трубе костяшка среднего пальца: градусы от верха к передней стороне.
PushCart.KNUCKLE_ANGLE = 20
-- Куда сперва идёт большой палец: на заднюю сторону трубы, на середину высоты.
PushCart.THUMB_ANGLE = -90
-- Кончик пальца - не кость: продолжаем последнюю фалангу на эту долю.
PushCart.TIP_EXTEND = 0.8

local SIDES = {
	{prefix = "ValveBiped.Bip01_R_", side = 1},
	{prefix = "ValveBiped.Bip01_L_", side = -1}
}
local FINGERS = {
	{"Finger1", "Finger11", "Finger12"},
	{"Finger2", "Finger21", "Finger22"},
	{"Finger3", "Finger31", "Finger32"},
	{"Finger4", "Finger41", "Finger42"}
}
local THUMB = {"Finger0", "Finger01", "Finger02"}

local BLEND_TIME = 0.25
-- Отладка хвата: метки цели запястья, самой кисти и точки на трубе. Не
-- сохраняется в конфиг клиента - не утечёт в игру включённой.
local DEBUG_CONVAR = CreateClientConVar("ix_pushcart_ikdebug", "0", false, false,
	"Метки IK тележки: красная - цель запястья, зелёная - кисть, синяя - хват на трубе.")
local debugPoints = {}
local IK_RANGE = 1500
-- Пальцы - пятнадцать суставов на руку; дальше этого их не разглядеть.
local FINGER_RANGE = 500
-- Куда смотрят локти: вниз и чуть наружу, как у толкающего тележку.
local POLE_OUT = 0.5
local POLE_DOWN = 1
local EPSILON = 0.0001

--[[
	Двухзвенная рука: где встанут локоть и запястье, чтобы запястье пришло в
	target, а длины плеча и предплечья остались своими. Не дотягивается -
	рука вытягивается к цели; локоть сгибается в сторону pole.
	@treturn Vector, Vector новый локоть, новое запястье
]]
function PushCart.SolveArm(shoulder, elbow, wrist, target, pole)
	local upperLength = shoulder:Distance(elbow)
	local lowerLength = elbow:Distance(wrist)
	local toTarget = target - shoulder
	local distance = toTarget:Length()

	if upperLength < EPSILON or lowerLength < EPSILON or distance < EPSILON then
		return elbow, wrist
	end

	local direction = toTarget * (1 / distance)
	local reach = math.Clamp(distance,
		math.abs(upperLength - lowerLength) + 0.01,
		(upperLength + lowerLength) * 0.999)
	local cosine = (upperLength * upperLength + reach * reach - lowerLength * lowerLength)
		/ (2 * upperLength * reach)
	local sine = math.sqrt(math.max(1 - cosine * cosine, 0))
	local bend = pole - direction * pole:Dot(direction)

	-- Полюс вдоль самой руки: сгибаем туда, куда она была согнута.
	if bend:LengthSqr() < EPSILON then
		local current = elbow - shoulder

		bend = current - direction * current:Dot(direction)
	end

	if bend:LengthSqr() < EPSILON then
		return shoulder + direction * upperLength, shoulder + direction * (upperLength + lowerLength)
	end

	bend:Normalize()

	local newElbow = shoulder + direction * (upperLength * cosine) + bend * (upperLength * sine)

	return newElbow, shoulder + direction * reach
end

--[[
	Поворот, переводящий направление from в to, долей weight: ось и угол.
	Нет поворота - nil.
]]
function PushCart.RotationBetween(from, to, weight)
	local fromLength, toLength = from:Length(), to:Length()

	if fromLength < EPSILON or toLength < EPSILON then
		return
	end

	local a, b = from * (1 / fromLength), to * (1 / toLength)
	local axis = a:Cross(b)
	local sine = axis:Length()

	if sine < EPSILON then
		return
	end

	local angle = math.atan2(sine, a:Dot(b)) * (weight or 1)

	return axis * (1 / sine), angle
end

--- Строки 3x3 поворота на angle (радианы) вокруг единичной оси - формула Родрига.
function PushCart.AxisAngleRows(axis, angle)
	local x, y, z = axis.x, axis.y, axis.z
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c

	return {
		{t * x * x + c, t * x * y - s * z, t * x * z + s * y},
		{t * x * y + s * z, t * y * y + c, t * y * z - s * x},
		{t * x * z - s * y, t * y * z + s * x, t * z * z + c}
	}
end

--- Ортонормированный базис по направлению forward и примерному across.
local function Basis(forward, across)
	local f = forward:GetNormalized()
	local k = across - f * across:Dot(f)

	if k:LengthSqr() < EPSILON then
		return
	end

	k:Normalize()

	return f, k, f:Cross(k)
end

--[[
	Поворот, который ставит кисть так, что её «вперёд» (запястье -> средний
	палец) смотрит в forward, а линия костяшек (мизинец -> указательный) - в
	across. Строки 3x3 = B · B0ᵀ, где B0 - нынешний базис кисти, B - нужный.
]]
function PushCart.FrameRows(currentForward, currentAcross, forward, across)
	local f0, k0, n0 = Basis(currentForward, currentAcross)
	local f1, k1, n1 = Basis(forward, across)

	if !f0 or !f1 then
		return
	end

	local from = {f0, k0, n0}
	local to = {f1, k1, n1}
	local rows = {{0, 0, 0}, {0, 0, 0}, {0, 0, 0}}
	local keys = {"x", "y", "z"}

	for i = 1, 3 do
		for j = 1, 3 do
			local sum = 0

			for m = 1, 3 do
				sum = sum + to[m][keys[i]] * from[m][keys[j]]
			end

			rows[i][j] = sum
		end
	end

	return rows
end

--- Поворот строками rows вокруг точки pivot - матрицей, которой умножают кости слева.
local function RowsMatrix(r, pivot)
	local px, py, pz = pivot.x, pivot.y, pivot.z

	return Matrix({
		{r[1][1], r[1][2], r[1][3], px - (r[1][1] * px + r[1][2] * py + r[1][3] * pz)},
		{r[2][1], r[2][2], r[2][3], py - (r[2][1] * px + r[2][2] * py + r[2][3] * pz)},
		{r[3][1], r[3][2], r[3][3], pz - (r[3][1] * px + r[3][2] * py + r[3][3] * pz)},
		{0, 0, 0, 1}
	})
end

local function PivotMatrix(axis, angle, pivot)
	return RowsMatrix(PushCart.AxisAngleRows(axis, angle), pivot)
end

--[[
	Скелет руки модели: номера костей, кто едет с плечом, кто с предплечьем,
	кто с кистью, и звенья пальцев. Считается раз на модель; нет хоть одной
	кости руки ValveBiped - модель оставляем как есть (пальцы необязательны).
]]
local rigs = {}

local function Subtree(entity, root, stop)
	local bones = {}

	for bone = 0, entity:GetBoneCount() - 1 do
		local parent = bone

		while parent and parent >= 0 do
			if stop and parent == stop then
				break
			elseif parent == root then
				bones[#bones + 1] = bone

				break
			end

			parent = entity:GetBoneParent(parent)
		end
	end

	return bones
end

local function LookupChain(entity, prefix, names)
	local chain = {}

	for index, name in ipairs(names) do
		chain[index] = entity:LookupBone(prefix..name)

		if !chain[index] then
			return
		end
	end

	return chain
end

local function GetRig(entity)
	local model = entity:GetModel()

	if rigs[model] != nil then
		return rigs[model]
	end

	local rig = {}

	for index, info in ipairs(SIDES) do
		local upper = entity:LookupBone(info.prefix.."UpperArm")
		local lower = entity:LookupBone(info.prefix.."Forearm")
		local hand = entity:LookupBone(info.prefix.."Hand")

		if !upper or !lower or !hand then
			rigs[model] = false

			return false
		end

		local fingers = {}

		for _, names in ipairs(FINGERS) do
			fingers[#fingers + 1] = LookupChain(entity, info.prefix, names)
		end

		rig[index] = {
			upper = upper,
			lower = lower,
			hand = hand,
			side = info.side,
			upperTree = Subtree(entity, upper, lower),
			lowerTree = Subtree(entity, lower),
			handTree = Subtree(entity, hand),
			fingers = fingers,
			thumb = LookupChain(entity, info.prefix, THUMB)
		}
	end

	rigs[model] = rig

	return rig
end

local function TransformBone(entity, bone, matrix)
	local current = entity:GetBoneMatrix(bone)

	if current then
		entity:SetBoneMatrix(bone, matrix * current)
	end
end

local function TransformBones(entity, bones, matrix)
	for _, bone in ipairs(bones) do
		local current = entity:GetBoneMatrix(bone)

		if current then
			entity:SetBoneMatrix(bone, matrix * current)
		end
	end
end

local function BonePos(entity, bone)
	local matrix = bone and entity:GetBoneMatrix(bone)

	return matrix and matrix:GetTranslation()
end

local function OnCircle(center, front, up, angle)
	local radius = PushCart.WRAP_RADIUS

	return center + front * (radius * math.sin(angle)) + up * (radius * math.cos(angle))
end

--[[
	Следующий сустав пальца: точка окружности обхвата (центр center, в
	плоскости front/up, углы от верха к front) на расстоянии length от
	сустава joint, ближайшая по ходу обхвата (direction: +1 - спереди вниз и
	назад, -1 - наоборот). Окружности не пересекаются - шагаем по окружности
	на угол, стягиваемый хордой length.
]]
function PushCart.WrapTarget(center, front, up, joint, length, direction)
	local radius = PushCart.WRAP_RADIUS
	local relative = joint - center
	local px, py = relative:Dot(front), relative:Dot(up)
	local distance = math.sqrt(px * px + py * py)
	local current = math.atan2(px, py)

	if distance > EPSILON and distance >= math.abs(radius - length) and distance <= radius + length then
		local along = (radius * radius - length * length + distance * distance) / (2 * distance)
		local across = math.sqrt(math.max(radius * radius - along * along, 0))
		local baseX, baseY = along * px / distance, along * py / distance
		local offsetX, offsetY = -py / distance * across, px / distance * across
		local bestX, bestY, bestAdvance

		for sign = 1, -1, -2 do
			local x, y = baseX + offsetX * sign, baseY + offsetY * sign
			local advance = ((math.atan2(x, y) - current) * direction) % (2 * math.pi)

			if advance > 0 and advance <= math.pi and (!bestAdvance or advance < bestAdvance) then
				bestX, bestY, bestAdvance = x, y, advance
			end
		end

		if bestAdvance then
			return center + front * bestX + up * bestY
		end
	end

	local step = 2 * math.asin(math.min(1, length / (2 * radius)))

	return OnCircle(center, front, up, current + direction * step)
end

--[[
	Палец по трубе: фаланга за фалангой поворачивается вокруг своего сустава
	так, чтобы следующий сустав лёг на окружность обхвата, увлекая всё ниже.
	Центр окружности - ось трубы напротив этого сустава.
]]
local function WrapChain(entity, chain, grip, along, front, up, direction, weight, firstAngle)
	local points = {}

	for index, bone in ipairs(chain) do
		points[index] = BonePos(entity, bone)

		if !points[index] then
			return
		end
	end

	points[4] = points[3] + (points[3] - points[2]) * PushCart.TIP_EXTEND

	for joint = 1, 3 do
		local pivot = points[joint]
		local center = grip + along * (pivot - grip):Dot(along)
		local target = joint == 1 and firstAngle and OnCircle(center, front, up, firstAngle)
			or PushCart.WrapTarget(center, front, up, pivot, pivot:Distance(points[joint + 1]), direction)
		local axis, angle = PushCart.RotationBetween(points[joint + 1] - pivot, target - pivot, weight)

		if axis then
			local rotation = PivotMatrix(axis, angle, pivot)

			for below = joint, #chain do
				TransformBone(entity, chain[below], rotation)
			end

			for later = joint + 1, 4 do
				points[later] = rotation * points[later]
			end
		end
	end
end

local identity = Matrix()

-- Длина кисти от запястья до костяшки среднего пальца, если пальцев нет.
local DEFAULT_HAND_LENGTH = 4

local function PlaceArm(entity, arm, cart, weight, rightDir, withFingers)
	local shoulder = BonePos(entity, arm.upper)
	local elbow = BonePos(entity, arm.lower)
	local wrist = BonePos(entity, arm.hand)

	if !shoulder or !elbow or !wrist then
		return
	end

	local middleBase = arm.fingers[2] and BonePos(entity, arm.fingers[2][1])
	local handLength = middleBase and middleBase:Distance(wrist) or DEFAULT_HAND_LENGTH

	--[[
		Кисть ставится от костяшки: она на окружности обхвата под углом
		KNUCKLE_ANGLE, а ладонь идёт по касательной к ней (вперёд и вниз).
		Запястье - на длину своей кисти назад по этой касательной.

		Ручка - там, где тележку РИСУЮТ (ENT:GetDrawPose), и место, и углы:
		углы сущности приходят с интерполяцией, а рисуется она в позе хода, и
		с ними кисти уезжали с трубы на поворотах и уклонах.
	]]
	local cartPos, cartAngles = cart:GetDrawPose()
	local front = -cartAngles:Forward()
	local up = cartAngles:Up()
	local along = cartAngles:Right()
	local grip = LocalToWorld(arm.side > 0 and PushCart.GRIP_RIGHT or PushCart.GRIP_LEFT, angle_zero,
		cartPos, cartAngles)
	local knuckleAngle = math.rad(PushCart.KNUCKLE_ANGLE)
	local handForward = front * math.cos(knuckleAngle) - up * math.sin(knuckleAngle)
	local target = OnCircle(grip, front, up, knuckleAngle) - handForward * handLength
	local pole = rightDir * (arm.side * POLE_OUT) - vector_up * POLE_DOWN
	local newElbow, newWrist = PushCart.SolveArm(shoulder, elbow, wrist, target, pole)

	if DEBUG_CONVAR:GetBool() then
		debugPoints[#debugPoints + 1] = {entity = entity, bone = arm.hand, target = target, grip = grip}
	end

	-- Плечо и предплечье.
	local axis, angle = PushCart.RotationBetween(elbow - shoulder, newElbow - shoulder, weight)
	local first = axis and PivotMatrix(axis, angle, shoulder) or identity
	local movedElbow = first * elbow
	local movedWrist = first * wrist

	axis, angle = PushCart.RotationBetween(movedWrist - movedElbow, newWrist - movedElbow, weight)

	local second = axis and PivotMatrix(axis, angle, movedElbow) or identity

	TransformBones(entity, arm.upperTree, first)
	TransformBones(entity, arm.lowerTree, second * first)

	--[[
		Кисть: ладонью на трубу. «Вперёд» кисти - по касательной, линия
		костяшек - вдоль трубы, указательным внутрь. Для правой руки внутрь -
		это правый вектор тележки (-Y), для левой - наоборот; ладонь при этом
		сама выходит вниз, как у настоящей руки.
	]]
	local middle = arm.fingers[2] and BonePos(entity, arm.fingers[2][1])
	local index = arm.fingers[1] and BonePos(entity, arm.fingers[1][1])
	local pinky = arm.fingers[4] and BonePos(entity, arm.fingers[4][1])
	local handPos = BonePos(entity, arm.hand)

	if !middle or !index or !pinky or !handPos then
		return
	end

	local currentForward = middle - handPos
	local currentAcross = index - pinky
	local forward = LerpVector(weight, currentForward:GetNormalized(), handForward)
	local across = LerpVector(weight, currentAcross:GetNormalized(), along * arm.side)
	local rows = PushCart.FrameRows(currentForward, currentAcross, forward, across)

	if rows then
		TransformBones(entity, arm.handTree, RowsMatrix(rows, handPos))
	end

	if !withFingers then
		return
	end

	-- Пальцы обходят трубу спереди вниз, большой - сзади, из-под ладони.
	for _, chain in ipairs(arm.fingers) do
		WrapChain(entity, chain, grip, along, front, up, 1, weight)
	end

	if arm.thumb then
		WrapChain(entity, arm.thumb, grip, along, front, up, -1, weight, math.rad(PushCart.THUMB_ANGLE))
	end
end

local function BuildArms(entity)
	local cart = entity.ixPushCartIKCart
	local weight = entity.ixPushCartIKWeight or 0

	if weight <= 0 or !IsValid(cart) or !cart.GetDrawPose then
		return
	end

	local distance = EyePos():DistToSqr(entity:GetPos())

	if distance > IK_RANGE * IK_RANGE then
		return
	end

	local rig = GetRig(entity)

	if !rig then
		return
	end

	-- Локти - в стороны от ТЕЛА, а оно стоит вдоль тележки, а не за взглядом (PushCart:BodyYaw, sh_drive.lua).
	local rightDir = Angle(0, PushCart:BodyYaw(entity) or entity:EyeAngles().y, 0):Right()

	local withFingers = distance <= FINGER_RANGE * FINGER_RANGE

	for _, arm in ipairs(rig) do
		PlaceArm(entity, arm, cart, weight, rightDir, withFingers)
	end
end

--[[
	Руки ложатся на ручку и снимаются с неё за BLEND_TIME, а не рывком.
	Обработчик костей вешается только на тех, кто сейчас везёт (или ещё
	отпускает), и снимается следом.
]]
-- Игроки, чьи руки на ручке или ещё сходят с неё: кроме них и тех, кто сейчас везёт, никого не трогаем.
local active = {}

hook.Add("Think", "ixPushCartIK", function()
	local step = FrameTime() / BLEND_TIME

	-- Кто везёт - по реестру тележек (их единицы), а не перебором всех игроков с NW2 каждый кадр.
	for cart in pairs(PushCart.carts) do
		local pusher = IsValid(cart) and cart.GetPusher and cart:GetPusher()

		if IsValid(pusher) and pusher:IsPlayer() then
			active[pusher] = true
		end
	end

	for client in pairs(active) do
		if !IsValid(client) then
			active[client] = nil

			continue
		end

		local cart = client:Alive() and PushCart:GetPushedCart(client) or nil

		if cart then
			client.ixPushCartIKCart = cart
		end

		local weight = math.Approach(client.ixPushCartIKWeight or 0, cart and 1 or 0, step)

		client.ixPushCartIKWeight = weight

		if weight > 0 and !client.ixPushCartIK then
			client.ixPushCartIK = client:AddCallback("BuildBonePositions", BuildArms)
		elseif weight <= 0 then
			if client.ixPushCartIK then
				client:RemoveCallback("BuildBonePositions", client.ixPushCartIK)
				client.ixPushCartIK = nil
			end

			client.ixPushCartIKCart = nil
			active[client] = nil
		end
	end
end)

local DEBUG_TARGET = Color(255, 40, 40)
local DEBUG_HAND = Color(40, 255, 40)
local DEBUG_GRIP = Color(60, 120, 255)

hook.Add("PostDrawTranslucentRenderables", "ixPushCartIKDebug", function(depth, skybox)
	if depth or skybox then
		return
	end

	if !DEBUG_CONVAR:GetBool() then
		debugPoints = {}

		return
	end

	render.SetColorMaterial()

	for _, point in ipairs(debugPoints) do
		render.DrawSphere(point.target, 0.6, 8, 8, DEBUG_TARGET)
		render.DrawSphere(point.grip, 0.5, 8, 8, DEBUG_GRIP)

		local hand = IsValid(point.entity) and point.entity:GetBonePosition(point.bone)

		if hand then
			render.DrawSphere(hand, 0.6, 8, 8, DEBUG_HAND)
		end
	end

	debugPoints = {}
end)
