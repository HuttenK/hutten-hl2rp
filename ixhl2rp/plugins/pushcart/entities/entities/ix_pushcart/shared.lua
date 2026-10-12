ENT.Type = "anim"
ENT.PrintName = "Грузовая тележка"
ENT.Author = "Autonomous"
ENT.Category = "Foundation — Logistics"
ENT.Model = "models/props_junk/pushcart02a.mdl"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.bNoPersist = true
-- Метка для ShouldCollide (sh_plugin.lua): дешевле, чем сравнивать класс.
ENT.ixIsPushCart = true

--[[
	РАЗМЕТКА МОДЕЛИ (PushCart02a, разобрана по .mdl/.vvd).

	Начало координат на 34 единицы выше земли, ручка на +X. Толкающий стоит со
	стороны +X и катит тележку в сторону -X.

	Настил: верх на z = -16.25, по X от -38 до 38, по Y от -23 до 23, но
	стойки ручки стоят на x = 34 - груз кладётся не дальше x = 32.
	Колёса, габарит кузова и низ настила для хода - в sh_kinematics.lua.
]]
ENT.BedZ = -16.2
ENT.BedMinX = -36.5
ENT.BedMaxX = 32
ENT.BedHalfY = 22

-- Four stacks of two native 21x21x22 crates, lower and clear of the handle.
-- The 1-unit center gap leaves half a unit to each deck edge; crate size
-- is unchanged when loaded or unloaded.
ENT.CrateColumns = {Vector(-16, -11, 0), Vector(10, -11, 0), Vector(-16, 11, 0), Vector(10, 11, 0)}
ENT.CratesPerColumn = 2

function ENT:SetupDataTables()
	self:NetworkVar("Int", 3, "InventoryID")
	self:NetworkVar("Bool", 0, "Composite")
	self:NetworkVar("Entity", 0, "Pusher")
	self:NetworkVar("Int", 0, "CrateCount")
	self:NetworkVar("Int", 1, "CargoRev")
	--[[
		Номер команды толкающего, после которой снята поза ниже (0 - не везут или
		ещё не шагнули). Клиент толкающего сверяет по нему своё предсказание
		(PushCart.Pred:Sync в sh_drive.lua).
	]]
	self:NetworkVar("Int", 2, "PushCmd")
	-- Загруженность 0..1: от неё скорость, разгон и поворот (sh_plugin.lua).
	self:NetworkVar("Float", 0, "Load")
	-- Поза хода после команды PushCmd: пишет и читает только PushCart:WriteDrive/ReadDrive.
	self:NetworkVar("Float", 1, "PushYaw")
	self:NetworkVar("Float", 2, "PushRate")
	self:NetworkVar("Float", 3, "HoldX")
	self:NetworkVar("Float", 4, "HoldY")
	self:NetworkVar("Float", 5, "PoseX")
	self:NetworkVar("Float", 6, "PoseY")
	self:NetworkVar("Float", 7, "PoseZ")
	self:NetworkVar("Float", 8, "PoseA")
	self:NetworkVar("Float", 9, "PoseB")
	-- Верх кузова над колёсами: ручка или верхний ящик (ENT:LayoutCrates). Выше - уже не кузов.
	self:NetworkVar("Float", 10, "BodyTop")
end

function ENT:GetInventory()
	return ix.Inventory:Get(self:GetInventoryID())
end

-- Calibrated physical chassis for both the requested mesh and the fallback.
-- Its native PHY bounds extend above the visible handle; these hulls follow
-- the deck/handle/wheels instead, in exactly the same space as the hand IK.
ENT.CompositeParts = {
	{Vector(-38, -23, 13.8), Vector(38, 23, 18.3)},
	{Vector(34.9, -19, 18.3), Vector(37.7, -16.2, 47.2)},
	{Vector(34.9, 16.2, 18.3), Vector(37.7, 19, 47.2)},
	{Vector(35.4, -19, 46.3), Vector(37.2, 19, 48.1)},
	{Vector(-35, -21, 0.5), Vector(-27, -15, 13.8)},
	{Vector(-35, 15, 0.5), Vector(-27, 21, 13.8)},
	{Vector(27, -21, 0.5), Vector(35, -15, 13.8)},
	{Vector(27, 15, 0.5), Vector(35, 21, 13.8)}
}

-- Convert the old ground-based calibration into the requested model origin.
for _, part in ipairs(ENT.CompositeParts) do
	part[1].z = part[1].z + ix.PushCart.MODEL_Z_OFFSET
	part[2].z = part[2].z + ix.PushCart.MODEL_Z_OFFSET
end

function ENT:InitCompositePhysics()
	local hulls = {}
	for _, part in ipairs(self.CompositeParts) do
		local points = {}
		for _, x in ipairs({part[1].x, part[2].x}) do
			for _, y in ipairs({part[1].y, part[2].y}) do
				for _, z in ipairs({part[1].z, part[2].z}) do points[#points + 1] = Vector(x, y, z) end
			end
		end
		hulls[#hulls + 1] = points
	end
	self:PhysicsInitMultiConvex(hulls)
	self:EnableCustomCollisions(true)
	self:SetCollisionBounds(Vector(-38, -23, -34), Vector(43.1, 23, 14.1))
	self.compositePhysics = true
end

--[[
	Умеет ли тележка ход (sh_drive.lua). Поставленная до перезапуска со старым
	кодом полей хода не получила: её хуки хода не трогают, а взяться за неё
	нельзя - пусть поставят заново.
]]
function ENT:HasDriveVars()
	return self.GetPushCmd != nil
end

--[[
	Загрузку читать и писать только через эти обёртки. NetworkVar вешает
	Get/SetLoad на сущность в момент её создания, и тележка, поставленная до
	горячей перезагрузки, их не получает: прямой вызов ронял и предсказание
	шага, и физику толкания.
]]
function ENT:GetCargoLoad()
	return self.GetLoad and math.Clamp(self:GetLoad(), 0, 1) or 0
end

function ENT:SetCargoLoad(load)
	if self.SetLoad then
		self:SetLoad(math.Clamp(load, 0, 1))
	end
end
