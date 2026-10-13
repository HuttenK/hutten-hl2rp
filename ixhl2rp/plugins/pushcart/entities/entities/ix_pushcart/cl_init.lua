include("shared.lua")

ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.PopulateEntityInfo = true

-- The smoothed draw pose can extend beyond the entity's current position.
local RENDER_PAD = Vector(32, 32, 32)

-- Bind initialization to a ready local helper. During entity refresh the
-- instance may still resolve methods through the previous registered table.
local function PadRenderBounds(self)
	if self.renderPadded then return end
	local mins, maxs = self:OBBMins(), self:OBBMaxs()
	if (maxs - mins):LengthSqr() < 1 then return end
	if self.GetComposite and self:GetComposite() then
		mins, maxs = self.ChassisMins, self.ChassisMaxs
	end
	self:SetRenderBounds(mins - RENDER_PAD, maxs + RENDER_PAD)
	self.renderPadded = true
end
ENT.PadRenderBounds = PadRenderBounds

-- ShouldCollide (sh_plugin.lua) должен решать одинаково и здесь.
function ENT:Initialize()
	self:SetCustomCollisionCheck(true)
	ix.PushCart:Register(self)
	PadRenderBounds(self)
end

local WHEELS_CONVAR = CreateClientConVar("ix_pushcart_wheels", "1", true, false,
	"Крутящиеся колёса тележки; 0 - обычная модель с неподвижными колёсами.")

-- Колёса в модели отдельной частью тела «wells», и вся она ниже этой высоты.
local WHEEL_TOP = -20.5 -- retired separate-wheel model only
-- Рывок дальше этого за кадр - телепорт или подгрузка, колёса не крутим.
local MAX_STEP = 20

--[[
	Поворотные вилки малых колёс (сторона -X). По вершинам модели: ступицы
	на z 2.5-4.5, стойки до 9.5, площадка на z 10; настил начинается с 13.5,
	так что всё ниже 12 у этих колёс - вилка. Ось поворота вертикальная,
	через центр вилки (x = -31, y = ±18). Большие колёса у ручки - на
	неподвижной оси.
]]
local CASTER_MIN_X, CASTER_MAX_X = -35, -27
local CASTER_MIN_Y, CASTER_MAX_Y = 15, 21
local CASTER_MAX_Z = -22.5 -- retired separate-wheel model only
-- Вилка доворачивается за ходом, град/с; медленнее этого хода (ед/с) - стоит как стояла.
local SWIVEL_RATE = 240
local SWIVEL_MIN_SPEED = 3

--[[
	Отрисовка (ENT:GetDrawPose). Высота, тангаж и крен сглаживаются с этой
	постоянной времени: ступенька в 12 под колесом - один тик, и без
	сглаживания тележка прыгала бы. По горизонтали и курсу - ничего: там
	любое сглаживание - отставание от рук.
]]
local Z_SMOOTH_TAU = 0.03
-- Ниже этого высота и углы считаются догнавшими: отдаётся поза сущности как есть.
local SMOOTH_SNAP_Z = 0.01
local SMOOTH_SNAP_ANGLE = 0.01
-- Смена источника позы (взяли, отпустили, история заново) - переход за столько, а не скачком.
local SOURCE_BLEND = 0.2
-- Дальше этого колёса и вилки не разглядеть: штатная модель одним вызовом
-- вместо холостого прохода, корпуса и шести мешей.
local MESH_DRAW_RANGE = 1200

--[[
	КРУЖАЩИЕСЯ КОЛЁСА.

	Модель статичная: одна кость, ни анимаций, ни поз - колёса не повернуть
	ни костями, ни бодигруппой. Зато они лежат отдельной частью тела, и
	util.GetModelMeshes отдаёт их своим мешем. Из него собираем четыре
	колеса (по четвертям), из остального - корпус, и рисуем всё сами.

	Свет: перед своими мешами штатная модель рисуется вхолостую (без цвета и
	глубины) - она выставляет освещение в этой точке, и меши его берут.
	Если что-то не собралось - обычная DrawModel.
]]
local builtModels = {}

local function BuildMesh(triangles, material)
	local imesh = Mesh(material)

	mesh.Begin(imesh, MATERIAL_TRIANGLES, #triangles / 3)

	for _, vertex in ipairs(triangles) do
		mesh.Position(vertex.pos)
		mesh.Normal(vertex.normal)
		mesh.TexCoord(0, vertex.u, vertex.v)

		local userdata = vertex.userdata

		if istable(userdata) then
			mesh.UserData(userdata[1] or 0, userdata[2] or 0, userdata[3] or 0, userdata[4] or 1)
		elseif vertex.tangent and vertex.binormal then
			local tangent = vertex.tangent
			local handedness = vertex.normal:Cross(tangent):Dot(vertex.binormal) < 0 and -1 or 1

			mesh.UserData(tangent.x, tangent.y, tangent.z, handedness)
		end

		mesh.AdvanceVertex()
	end

	mesh.End()

	return imesh
end

local function SplitWheels(triangles)
	local groups = {}

	for i = 1, #triangles, 3 do
		local a, b, c = triangles[i].pos, triangles[i + 1].pos, triangles[i + 2].pos
		local key = ((a.x + b.x + c.x) > 0 and "f" or "b")..((a.y + b.y + c.y) > 0 and "l" or "r")
		local group = groups[key]

		if !group then
			group = {triangles = {}}
			groups[key] = group
		end

		for k = i, i + 2 do
			local position = triangles[k].pos

			group.triangles[#group.triangles + 1] = triangles[k]
			group.minX = math.min(group.minX or position.x, position.x)
			group.maxX = math.max(group.maxX or position.x, position.x)
			group.minZ = math.min(group.minZ or position.z, position.z)
			group.maxZ = math.max(group.maxZ or position.z, position.z)
		end
	end

	return groups
end

local function BuildCart(model)
	local entries = util.GetModelMeshes(model, 0, 0)

	if !istable(entries) or #entries == 0 then
		return false
	end

	local body, wheels = {}, {}

	for _, entry in ipairs(entries) do
		local maxZ = -math.huge

		for _, vertex in ipairs(entry.triangles) do
			maxZ = math.max(maxZ, vertex.pos.z)
		end

		table.Add(maxZ <= WHEEL_TOP and wheels or body, entry.triangles)
	end

	if #body == 0 or #wheels == 0 then
		return false
	end

	-- Вилки вынимаем из корпуса: они поворачиваются отдельно.
	local forks = {l = {}, r = {}}
	local frame = {}

	for i = 1, #body, 3 do
		local a, b, c = body[i].pos, body[i + 1].pos, body[i + 2].pos
		local x, y, z = (a.x + b.x + c.x) / 3, (a.y + b.y + c.y) / 3, (a.z + b.z + c.z) / 3
		local isFork = z < CASTER_MAX_Z and x > CASTER_MIN_X and x < CASTER_MAX_X
			and math.abs(y) > CASTER_MIN_Y and math.abs(y) < CASTER_MAX_Y
		local target = isFork and forks[y > 0 and "l" or "r"] or frame

		for k = i, i + 2 do
			target[#target + 1] = body[k]
		end
	end

	local material = Material(entries[1].material)
	local built = {
		body = BuildMesh(frame, material),
		wheels = {},
		casters = {}
	}

	for key, group in pairs(SplitWheels(wheels)) do
		local center = Vector((group.minX + group.maxX) * 0.5, 0, (group.minZ + group.maxZ) * 0.5)
		local wheel = {
			mesh = BuildMesh(group.triangles, material),
			center = center,
			back = -center,
			radius = math.max((group.maxZ - group.minZ) * 0.5, 1)
		}
		local fork = key:sub(1, 1) == "b" and forks[key:sub(2, 2)]

		if fork and #fork > 0 then
			local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge

			for _, vertex in ipairs(fork) do
				minX, maxX = math.min(minX, vertex.pos.x), math.max(maxX, vertex.pos.x)
				minY, maxY = math.min(minY, vertex.pos.y), math.max(maxY, vertex.pos.y)
			end

			local pivot = Vector((minX + maxX) * 0.5, (minY + maxY) * 0.5, 0)

			built.casters[#built.casters + 1] = {
				fork = BuildMesh(fork, material),
				wheel = wheel,
				pivot = pivot,
				back = -pivot
			}
		else
			built.wheels[#built.wheels + 1] = wheel
		end
	end

	return built
end

local function GetBuilt(model)
	if builtModels[model] == nil then
		local ok, built = pcall(BuildCart, model)

		builtModels[model] = ok and built or false
	end

	return builtModels[model]
end

-- Рабочие матрицы отрисовки: одни на все тележки, без новой матрицы на каждое колесо каждый кадр.
local wheelMatrix = Matrix()
local wheelAngle = Angle()
local swivelMatrix = Matrix()
local swivelAngle = Angle()
local cartMatrix = Matrix()
local swivelWorld = Matrix()
local partWorld = Matrix()
local scaleVector = Vector()

--[[
	Поворот вилки за ходом: курс её точки в координатах тележки. Колесо
	симметрично - вперёд и назад катится одинаково, поэтому из двух курсов
	берётся ближайший к нынешнему, и задний ход не крутит вилку на 180.
	@treturn number новый угол вилки
]]
function ENT.SwivelTowards(current, movedX, movedY, rate)
	local heading = math.deg(math.atan2(movedY, movedX))

	if math.abs(math.AngleDifference(heading + 180, current)) < math.abs(math.AngleDifference(heading, current)) then
		heading = heading + 180
	end

	return math.ApproachAngle(current, math.NormalizeAngle(heading), rate)
end

function ENT:UpdateCasters(built, transform, angles)
	self.casterState = self.casterState or {}

	local forward, left = angles:Forward(), -angles:Right()
	local frameTime = math.max(FrameTime(), 0.001)

	for index, caster in ipairs(built.casters) do
		local state = self.casterState[index]

		if !state then
			state = {yaw = 0, travel = 0}
			self.casterState[index] = state
		end

		local position = transform * caster.pivot
		local last = state.last

		state.last = position

		if !last then
			continue
		end

		local moved = position - last
		local distance = moved:Length()

		if distance >= MAX_STEP then
			continue
		end

		if distance / frameTime > SWIVEL_MIN_SPEED then
			state.yaw = self.SwivelTowards(state.yaw, moved:Dot(forward), moved:Dot(left), SWIVEL_RATE * frameTime)
		end

		local yaw = math.rad(state.yaw)

		state.travel = state.travel + moved:Dot(forward * math.cos(yaw) + left * math.sin(yaw))
	end
end

function ENT:GetCartMaterial()
	local skin = self:GetSkin()

	if self.cartMaterialSkin != skin then
		local materials = self:GetMaterials()

		self.cartMaterialSkin = skin
		self.cartMaterial = Material(materials[skin + 1] or materials[1] or "")
	end

	return self.cartMaterial
end

function ENT:UpdateWheelTravel(position, angles)
	local last = self.lastWheelPos

	self.lastWheelPos = position
	self.wheelTravel = self.wheelTravel or 0

	if !last then
		return
	end

	local moved = position - last

	if moved:LengthSqr() < MAX_STEP * MAX_STEP then
		self.wheelTravel = self.wheelTravel + moved:Dot(angles:Forward())
	end
end

function ENT:DrawCart(position, angles)
	if self:GetComposite() then
		self:DrawComposite(position, angles)
		return
	end
	-- This model combines wheels and body in one mesh/material. Never split
	-- it using the recovered separate-wheel bodygroup assumptions.
	local built = self:GetModel() != ix.PushCart.MODEL and WHEELS_CONVAR:GetBool() and GetBuilt(self:GetModel())

	if !built or EyePos():DistToSqr(position) > MESH_DRAW_RANGE * MESH_DRAW_RANGE then
		self:DrawModel()

		return
	end

	render.OverrideColorWriteEnable(true, false)
	render.OverrideAlphaWriteEnable(true, false)
	render.OverrideDepthEnable(true, false)
		self:DrawModel()
	render.OverrideDepthEnable(false, false)
	render.OverrideAlphaWriteEnable(false, false)
	render.OverrideColorWriteEnable(false, false)

	--[[
		Матрица - явно из позы отрисовки (ENT:GetDrawPose), а не
		GetWorldTransformMatrix: после SetRenderOrigin/Angles та могла нести
		прошлый кадр, а руки (cl_ik.lua) целятся в эту позу - кисти уезжали бы
		с трубы. Модель вхолостую выше рисуется там же: её ставит PreRender.
	]]
	local transform = cartMatrix
	local scale = self:GetModelScale()

	transform:Identity()
	transform:SetTranslation(position)
	transform:SetAngles(angles)

	if scale != 1 then
		scaleVector:SetUnpacked(scale, scale, scale)
		transform:Scale(scaleVector)
	end

	render.SetMaterial(self:GetCartMaterial())

	cam.PushModelMatrix(transform)
		built.body:Draw()
	cam.PopModelMatrix()

	for _, wheel in ipairs(built.wheels) do
		-- Качение: пройденный путь вдоль +X поворачивает колесо на путь/радиус.
		wheelAngle.p = math.deg(self.wheelTravel / wheel.radius) % 360

		wheelMatrix:Identity()
		wheelMatrix:Translate(wheel.center)
		wheelMatrix:Rotate(wheelAngle)
		wheelMatrix:Translate(wheel.back)

		partWorld:Set(transform)
		partWorld:Mul(wheelMatrix)

		cam.PushModelMatrix(partWorld)
			wheel.mesh:Draw()
		cam.PopModelMatrix()
	end

	self:UpdateCasters(built, transform, angles)

	for index, caster in ipairs(built.casters) do
		local state = self.casterState[index]
		local wheel = caster.wheel

		swivelAngle.y = state.yaw

		swivelMatrix:Identity()
		swivelMatrix:Translate(caster.pivot)
		swivelMatrix:Rotate(swivelAngle)
		swivelMatrix:Translate(caster.back)

		swivelWorld:Set(transform)
		swivelWorld:Mul(swivelMatrix)

		cam.PushModelMatrix(swivelWorld)
			caster.fork:Draw()
		cam.PopModelMatrix()

		-- Колесо поворачивается вместе с вилкой и катится по её курсу.
		wheelAngle.p = math.deg(state.travel / wheel.radius) % 360

		wheelMatrix:Identity()
		wheelMatrix:Translate(wheel.center)
		wheelMatrix:Rotate(wheelAngle)
		wheelMatrix:Translate(wheel.back)

		partWorld:Set(swivelWorld)
		partWorld:Mul(wheelMatrix)

		cam.PushModelMatrix(partWorld)
			wheel.mesh:Draw()
		cam.PopModelMatrix()
	end
end

local compositeMaterial = Material("models/debug/debugwhite")
function ENT:DrawComposite(position, angles)
	render.SetMaterial(compositeMaterial)
	for index, part in ipairs(self.CompositeParts) do
		local shade = index == 1 and Color(93, 109, 102) or (index >= 5 and Color(35, 39, 38) or Color(142, 154, 146))
		render.DrawBox(position, angles, part[1], part[2], shade)
	end
end

-- ─────────────────────────────────────────────────────────────
-- ВЕЩИ В КУЗОВЕ
-- ─────────────────────────────────────────────────────────────

function ENT:ClearCargoModels()
	for _, entry in ipairs(self.cargo or {}) do
		if IsValid(entry.entity) then
			entry.entity:Remove()
		end
	end

	self.cargo = {}
end

function ENT:Draw()
	local position, angles = self:GetDrawPose()

	self:UpdateWheelTravel(position, angles)
	self:DrawCart(position, angles)
end

--[[
	ГДЕ РИСОВАТЬ ТЕЛЕЖКУ. Пока её везёт этот игрок, центр - ровно у его рук
	там, где движок рисует его самого. Курс и хват - из его предсказания хода
	(PushCart.Pred:DrawPose, sh_drive.lua), а где предсказания нет (одиночная
	игра, первые тики захвата) - со снимков хода (Pred:ObservedPose). Сущность
	тележки движок ведёт по своему времени, не по времени тела толкающего, и
	по ней она отставала бы от него: вперёд - в торсе, назад - руки в струну.
	Остальные видят сущность как есть: у них и толкающий, и тележка из
	одного времени.
	Третий ответ - источник ("hands" или "entity"); по его смене отрисовка
	переходит плавно (ENT:GetDrawPose). Предсказание и снимки - один
	источник: обе позы у рук, и переход между ними (история появилась через
	пинг после захвата) начинал бы переход захвата заново.
]]
function ENT:GetSourcePose()
	local PushCart = ix.PushCart
	local client = LocalPlayer()

	-- Сперва дешёвое поле дататейбла: почти все тележки на карте везёт не этот игрок (или никто).
	if IsValid(client) and self:HasDriveVars() and self:GetPusher() == client
		and PushCart:GetPushedCart(client) == self then
		local origin = client:GetPos()
		local frame = FrameNumber()

		-- Позу спрашивают по нескольку раз за кадр (отрисовка, руки, тело): тот же кадр и то же место тела - та же поза.
		if self.handsFrame == frame and self.handsOrigin == origin then
			return self.handsPos, self.handsAng, "hands"
		end

		local pose = self.ixPred and PushCart.Pred:DrawPose(self, origin)
			or PushCart.Pred:ObservedPose(self, client, origin)

		if pose then
			local position, angles = PushCart:PoseTransform(pose)

			self.handsFrame, self.handsOrigin, self.handsPos, self.handsAng = frame, origin, position, angles

			return position, angles, "hands"
		end
	end

	-- Не GetPos: при подмене отрисовки он отдаёт позу прошлого кадра (PushCart:RealPose).
	local position, angles = PushCart:RealPose(self)

	return position, angles, "entity"
end

-- Догнать цель долей alpha; ближе snap - ровно цель, чтобы поза совпала с сущностью и подмену сняли.
local function Converge(current, target, alpha, snap)
	local difference = target - current

	if math.abs(difference) <= snap then
		return target
	end

	return current + difference * alpha
end

local function ConvergeAngle(current, target, alpha, snap)
	local difference = math.AngleDifference(target, current)

	if math.abs(difference) <= snap then
		return target
	end

	return current + difference * alpha
end

local function BlendAngle(t, from, to)
	return Angle(from.p + math.AngleDifference(to.p, from.p) * t, from.y + math.AngleDifference(to.y, from.y) * t,
		from.r + math.AngleDifference(to.r, from.r) * t)
end

--[[
	Шаг отрисовки за кадр, без побочных действий: из состояния прошлого кадра
	base (nil - первый кадр) и позы источника - новое состояние и поза кадра.

	Высота, тангаж и крен сглаживаются (Z_SMOOTH_TAU): ступенька - один тик
	хода, и без этого тележка прыгала бы. Только для глаза - ход считают и
	сервер, и предсказание без сглаживания. Место по горизонтали и курс -
	как есть: там любое сглаживание - отставание от рук.
	Источник сменился (взяли, отпустили) - SOURCE_BLEND переход от позы
	прошлого кадра, а не скачок.
]]
local function StepDraw(base, position, angles, source, frameTime)
	local z, p, r = position.z, angles.p, angles.r
	local blendFrom, blendFromAngles, blend

	if base then
		local alpha = 1 - math.exp(-frameTime / Z_SMOOTH_TAU)

		z = Converge(base.z, position.z, alpha, SMOOTH_SNAP_Z)
		p = ConvergeAngle(base.p, angles.p, alpha, SMOOTH_SNAP_ANGLE)
		r = ConvergeAngle(base.r, angles.r, alpha, SMOOTH_SNAP_ANGLE)

		if source != base.source then
			blendFrom, blendFromAngles, blend = base.pos, base.ang, 0
		else
			blendFrom, blendFromAngles, blend = base.blendFrom, base.blendFromAngles, base.blend
		end
	end

	if z != position.z then
		position = Vector(position.x, position.y, z)
	end

	if p != angles.p or r != angles.r then
		angles = Angle(p, angles.y, r)
	end

	if blendFrom then
		blend = math.min(blend + frameTime / SOURCE_BLEND, 1)

		if blend >= 1 then
			blendFrom, blendFromAngles = nil, nil
		else
			position = blendFrom + (position - blendFrom) * blend
			angles = BlendAngle(blend, blendFromAngles, angles)
		end
	end

	return {
		z = z, p = p, r = r, source = source, pos = position, ang = angles,
		blendFrom = blendFrom, blendFromAngles = blendFromAngles, blend = blend
	}
end

--[[
	Поза, в которой тележку рисуют в этом кадре: корпус, колёса, вещи кузова,
	ящики (PreRender в sh_drive.lua) и руки толкающего (cl_ik.lua) - все из
	одной.

	Кадр шагает один раз, но поза источника снимается при каждом вызове: если
	она другая, чем в прошлый раз за этот кадр, шаг пересчитывается заново от
	того же начала кадра. Так бывает, когда кости толкающего собирают раньше
	отрисовки (чужой Think спросил кость): движок тогда ещё не поставил тело
	туда, где его нарисует, и поза, запомненная с того раза, на весь кадр
	разъезжалась бы с ним.
]]
function ENT:GetDrawPose()
	local frame = FrameNumber()
	local position, angles, source = self:GetSourcePose()
	local state = self.drawState

	if state and state.source == source and self.drawInPos == position and self.drawInAng == angles then
		-- Тот же кадр и та же поза источника - уже посчитано.
		if self.drawFrame == frame then
			return state.pos, state.ang
		end

		--[[
			Стоящая тележка: источник не сдвинулся, перехода нет, сглаживание сошлось ровно на него -
			шаг дал бы то же самое. Таких на карте почти все, и каждый кадр они ничего не считают.
		]]
		if !state.blendFrom and state.pos == position and state.ang == angles then
			return position, angles
		end
	end

	if self.drawFrame != frame then
		self.drawFrame, self.drawBase = frame, state
	end

	state = StepDraw(self.drawBase, position, angles, source, FrameTime())
	self.drawState, self.drawInPos, self.drawInAng = state, position, angles

	return state.pos, state.ang
end

--[[
	Границы отрисовки шире модели: рисуют её в позе хода, а не там, где
	сущность, и с родными границами её отсекало бы у края экрана раньше
	времени. Пока модель не пришла, мерить нечего - снова из Think.
]]
function ENT:Think()
	local PushCart = ix.PushCart
	local client = LocalPlayer()
	if !self.compositePhysics then
		self:InitCompositePhysics()
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:EnableMotion(false) end
		self.renderPadded = nil
	end

	-- Полное обновление зовёт OnRemove у живой сущности - записываемся снова.
	PushCart:Register(self)
	PadRenderBounds(self)

	-- Отпустили: история предсказания и снимки хода больше не нужны, и при следующем захвате им не место.
	if (self.ixPred or self.ixSamples) and (!IsValid(client) or PushCart:GetPushedCart(client) != self) then
		self.ixPred, self.ixSamples = nil, nil
	end

end

function ENT:OnRemove()
	ix.PushCart:Unregister(self)
	self:ClearCargoModels()

	-- Ящикам - их место: подмену отрисовки ставил PreRender (sh_drive.lua).
	for child in pairs(self.overriddenChildren or {}) do
		if IsValid(child) then
			child:SetRenderOrigin(nil)
			child:SetRenderAngles(nil)
		end
	end

	self.overriddenChildren = nil
	-- При полном обновлении сущность не умирает: раскладку и границы надо поставить заново.
	self.cargoRevision = nil
	self.renderPadded = nil
end

function ENT:GetTooltipLines()
	local UI = ix.EconomyUI
	local labelColor = UI and UI.colors.label
	local lines = {
		{text = string.format("Ящиков: %d из %d", self:GetCrateCount(), ix.PushCart.MAX_CRATES), color = labelColor}
	}
	local patient = ix.PushCart.GetPatient and ix.PushCart:GetPatient(self)
	if patient then lines = {{text = "Занята персонажем · весь кузов", color = labelColor}} end

	if IsValid(self:GetPusher()) then
		lines[#lines + 1] = {text = "Везут", color = labelColor}
	end

	lines[#lines + 1] = {text = "E — ДЕЙСТВИЯ"}
	if !patient then
		lines[#lines + 1] = {text = ix.BodyDrag and ix.BodyDrag.Body(LocalPlayer()) and "E — уложить персонажа" or "Поднесите грузовой ящик — он закрепится автоматически"}
	end

	return {
		title = "ГРУЗОВАЯ ТЕЛЕЖКА",
		lines = lines
	}
end

-- Foundation uses the native tooltip callback, not the recovered EconomyUI.
function ENT:OnPopulateEntityInfo(tooltip)
	local info = self:GetTooltipLines()
	local title = tooltip:AddRow("name")
	title:SetText(info.title) title:SetImportant() title:SizeToContents()
	for index, line in ipairs(info.lines) do
		local row = tooltip:AddRow("cart" .. index)
		row:SetText(line.text) row:SizeToContents()
	end
end
