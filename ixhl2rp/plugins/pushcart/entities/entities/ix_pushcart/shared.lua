ENT.Type = "anim"
ENT.PrintName = "Грузовая тележка"
ENT.Author = "Autonomous"
ENT.Category = "Foundation — Logistics"
ENT.Model = "models/props_silo/pushcart.mdl"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.bNoPersist = true
-- Метка для ShouldCollide (sh_plugin.lua): дешевле, чем сравнивать класс.
ENT.ixIsPushCart = true

-- EP2 mesh measurements: wheel contact z=-15.96365, deck z=1.786,
-- curved handles on -X at x=-34.006, y=+/-12, z=35.236.
-- Item, physics, cargo, patients and hand IK all use this model-space frame.
ENT.BedZ = 1.84
ENT.BedMinX = -31
ENT.BedMaxX = 36.5
ENT.BedHalfY = 22

-- Four stacks of two native 21x21x22 crates, lower and clear of the handle.
-- The 1-unit center gap leaves half a unit to each deck edge; crate size
-- is unchanged when loaded or unloaded.
ENT.CrateColumns = {Vector(-10, -11, 0), Vector(16, -11, 0), Vector(-10, 11, 0), Vector(16, 11, 0)}
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

-- Physical chassis, paired handles and wheel assemblies in EP2 model space.
-- Keep these hulls aligned with the driving probes and visible mesh.
ENT.CompositeParts = {
	{Vector(-38, -23, -2.964), Vector(39.72, 23, 1.8)},
	{Vector(-35.01, -19.02, 1.8), Vector(-33, -17.02, 30.24)},
	{Vector(-35.01, 17.01, 1.8), Vector(-33, 19.01, 30.24)},
	{Vector(-35.01, -17.02, 33.2), Vector(-33, -7, 36.24)},
	{Vector(-35.01, 7, 33.2), Vector(-33, 17.01, 36.24)},
	{Vector(-28.4, -16, -15.96365), Vector(-16.4, -12.95, -2.464)},
	{Vector(-28.4, 12.95, -15.96365), Vector(-16.4, 16, -2.464)},
	{Vector(20.39, -16, -15.96365), Vector(32.4, -12.95, -2.464)},
	{Vector(20.39, 12.95, -15.96365), Vector(32.4, 16, -2.464)},
	{Vector(-35.01, -7.01, 25.24), Vector(-33, -5, 33.2)},
	{Vector(-35.01, 4.99, 25.24), Vector(-33, 7, 33.2)}
}
ENT.ChassisMins = Vector(-38, -23, -15.96365)
ENT.ChassisMaxs = Vector(39.72, 23, 36.24)

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
	self:SetCollisionBounds(self.ChassisMins, self.ChassisMaxs)
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
