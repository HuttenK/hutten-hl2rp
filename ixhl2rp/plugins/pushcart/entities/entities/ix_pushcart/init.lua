AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")
local P, Kin = ix.PushCart, ix.PushCart.Kin

function ENT:Initialize()
	-- Spawn-menu, deployed and restored carts all use the requested mesh.
	-- Keep the custom collision hulls without substituting a procedural body.
	self:SetComposite(false)
	self:SetModel(self.Model)
	self:InitCompositePhysics()
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:SetCustomCollisionCheck(true)
	self:SetBodyTop(Kin.BODY_TOP_EMPTY)
	self.crates = {}
	self.spawnBuild = P.BUILD
	P:Register(self)
	P:CreateInventory(self, P.INV_WIDTH, P.INV_HEIGHT, self.cargoRecord)
	self.cargoRecord = nil
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(45) phys:Wake() end
	self:UpdateLoad()
	P:QueueSave()
end

function ENT:UpdateLoad()
	local crates, weight = {}, 0
	for _, crate in ipairs(self.crates or {}) do
		if IsValid(crate) and crate:GetParent() == self then
			crates[#crates + 1] = crate
			weight = weight + 0.5 + 0.5 * crate:GetCargoLoad()
		end
	end
	self.crates = crates
	self:SetCrateCount(#crates)
	self:SetCargoLoad(math.Clamp(weight / P.MAX_CRATES, 0, 1))
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(45 + self:GetCargoLoad() * 100) end
end

function ENT:CrateSlot(index)
	local bed = self.BedZ
	local columns = #self.CrateColumns
	local column, level = (index - 1) % columns + 1, math.floor((index - 1) / columns)
	local slot = self.CrateColumns[column]
	return Vector(slot.x, slot.y, bed + level * 22), column
end

function ENT:LayoutCrates()
	local top = Kin.BODY_TOP_EMPTY
	for index, crate in ipairs(self.crates or {}) do
		if IsValid(crate) then
			local slot, column = self:CrateSlot(crate:GetCartSlot())
			crate.cartColumn = column
			crate:SetLocalPos(slot)
			crate:SetLocalAngles(angle_zero)
			-- Kinematics traces heights above the wheel plane, not model origin.
			top = math.max(top, slot.z + 22 - Kin.WHEEL_BOTTOM)
		end
	end
	self:SetBodyTop(top)
end

function ENT:ApplyDrive(state, command)
	local pos, ang = P:PoseTransform(state.pose)
	self:SetPos(pos) self:SetAngles(ang)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:SetPos(pos) phys:SetAngles(ang) phys:EnableMotion(false) end
	P:WriteDrive(self, state, command or 0)
end

function ENT:StartPush(client)
	if !P:Near(client, self) or IsValid(self:GetPusher()) or P:IsPushing(client) or self.cargoLoading or self.cargoPacking then return false end
	if ix.storage.InUse(self:GetInventory()) or P:PendingTransfers(self:GetInventory()) or IsValid(client:GetLocalVar("holdingObject")) then return false end
	local pos, ang = self:GetPos(), self:GetAngles()
	if math.abs(math.NormalizeAngle(ang.p)) > 50 or math.abs(math.NormalizeAngle(ang.r)) > 35 then client:Notify("Сначала поставьте тележку на колёса.") return false end
	-- Invert PoseTransform along the actual model normal. The raised origin
	-- is 34 units from the wheel plane: a world-Z offset would move a tilted
	-- cart sideways when its handle is acquired. Project the normal onto the
	-- yaw frame as well, so simultaneous pitch/roll reconstruct the same plane.
	local up = ang:Up()
	local support = pos + up * Kin.WHEEL_BOTTOM
	local yaw = Angle(0, ang.y, 0)
	local pose = Kin.Rest(support.x, support.y, support.z, ang.y,
		-up:Dot(yaw:Forward()) / up.z, up:Dot(yaw:Right()) / up.z)
	pose = Kin.FindFree(P:TraceFor(self), pose, client:GetPos().z, self:GetBodyTop())
	if !pose then client:Notify("Тележка зажата. Освободите место вокруг неё.") return false end
	local hx, hy = Kin.HoldOf(client:GetPos().x, client:GetPos().y, pose)
	if !Kin.HoldInRange(hx, hy, pose) then client:Notify("Подойдите к ручке тележки.") return false end
	P:CloseInventory(self)
	self.drive = {pose = pose, rate = 0, hx = hx, hy = hy, fresh = true, load = self:GetCargoLoad(), top = self:GetBodyTop()}
	self.releaseFlag, self.overlapSince, self.airSince, self.handleSince = nil, nil, nil, nil
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	client.ixPushCart = self
	client:SetNW2Entity("ixPushCart", self)
	self:SetPusher(client)
	client:SelectWeapon("ix_hands")
	self:ApplyDrive(self.drive, 0)
	return true
end

function ENT:StopPush()
	local client = self:GetPusher()
	if IsValid(client) then
		if client.ixPushCart == self then client.ixPushCart = nil client.ixCartMove = nil end
		client:SetNW2Entity("ixPushCart", NULL)
	end
	self:SetPusher(NULL)
	self.drive = nil
	self:SetPushCmd(0)
	self.releaseFlag = nil
	-- Keep player collision disabled until nobody intersects the body.
	self.restoreCollision = true
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(true) phys:Wake() end
	P:QueueSave()
end

function ENT:ShouldRelease()
	local client = self:GetPusher()
	local now = CurTime()
	return !P:CanOperate(client) or client.ixPushCart != self or self.releaseFlag
		or (self.overlapSince and now - self.overlapSince > 0.6)
		or (self.airSince and now - self.airSince > 0.45)
		or (self.handleSince and now - self.handleSince > 0.45)
end

function ENT:CanAttachCrate(crate)
	return P:IsLoadable(crate) and !IsValid(crate:GetParent()) and #self.crates < P.MAX_CRATES
		and !IsValid(self:GetPusher()) and !P:CargoBusy(self) and !P:CargoBusy(crate)
end

function ENT:AttachCrate(crate, restoring)
	if !P:IsLoadable(crate) or IsValid(crate:GetParent()) or #self.crates >= P.MAX_CRATES then return false end
	if !restoring and !self:CanAttachCrate(crate) then return false end
	local occupied = {}
	for _, other in ipairs(self.crates) do
		if IsValid(other) then occupied[other:GetCartSlot()] = true end
	end
	local slot = restoring and crate:GetCartSlot() or 0
	if slot < 1 or slot > P.MAX_CRATES or occupied[slot] then
		for i = 1, P.MAX_CRATES do if !occupied[i] then slot = i break end end
	end
	if slot < 1 or slot > P.MAX_CRATES or occupied[slot] then return false end
	crate:SetCartSlot(slot)
	P:CloseInventory(crate)
	crate:SetParent(self)
	crate:SetMoveType(MOVETYPE_NONE)
	crate:SetNotSolid(true)
	local phys = crate:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(false) end
	self.crates[#self.crates + 1] = crate
	self:UpdateLoad() self:LayoutCrates()
	P:QueueSave()
	return true
end

function ENT:LoadCrate(client, crate)
	if !P:Near(client, self) or !self:CanAttachCrate(crate) or crate.ixHeldOwner != client then return false end
	local hands = client:GetWeapon("ix_hands")
	if !IsValid(hands) or hands.heldEntity != crate then return false end
	hands:DropObject()
	return self:AttachCrate(crate)
end

function ENT:UnloadCrate(client, selected)
	if !P:Near(client, self) or IsValid(self:GetPusher()) or IsValid(client:GetLocalVar("holdingObject")) then return false end
	local crate, index
	for i, candidate in ipairs(self.crates) do
		if IsValid(candidate) and candidate == selected then crate, index = candidate, i break end
	end
	if !IsValid(crate) or crate:GetParent() != self or P:CargoBusy(crate) or P:CargoBusy(self) then return false end
	local yaw = client:EyeAngles().y
	local facing = Angle(0, yaw, 0)
	local origin, pos = client:GetPos() + Vector(0, 0, 25)
	for _, offset in ipairs({Vector(40,0,0), Vector(24,40,0), Vector(24,-40,0), Vector(0,55,0), Vector(0,-55,0)}) do
		local candidate = origin + facing:Forward() * offset.x + facing:Right() * offset.y
		local tr = util.TraceHull({start = candidate, endpos = candidate, mins = Vector(-12,-12,0),
			maxs = Vector(12,12,22), filter = {client, crate}, mask = MASK_SOLID})
		if !tr.Hit and !tr.StartSolid then pos = candidate break end
	end
	if !pos then client:Notify("Нет места, чтобы снять ящик.") return false end
	table.remove(self.crates, index)
	crate.ixAutoLoadBlockedCart = self
	crate.ixAutoLoadBlockedUID = self.cargoUID
	crate:SetParent(NULL)
	crate:SetCartSlot(0)
	crate:SetPos(pos) crate:SetAngles(Angle(0, yaw, 0)) crate:RestorePhysics()
	self:UpdateLoad() self:LayoutCrates()
	P:QueueSave()
	return true
end

function ENT:Use(client)
	P:OpenInteraction(client, self)
end

function ENT:Think()
	if CurTime() >= (self.nextLegacyCargoCheck or 0) then
		self.nextLegacyCargoCheck = CurTime() + 5
		P:MigrateCartInventory(self)
	end
	if self.drive and self:ShouldRelease() then self:StopPush() end
	if self.restoreCollision then
		local occupied = false
		for _, client in ipairs(player.GetAll()) do
			if client:Alive() and client:GetPos():DistToSqr(self:GetPos()) < 90^2 then occupied = true break end
		end
		if !occupied then self:SetCollisionGroup(COLLISION_GROUP_NONE) self.restoreCollision = nil end
	end
	self:NextThink(CurTime() + 0.1)
	return true
end

function ENT:OnRemove()
	self:StopPush()
	if !P.cleaning and !ix.shuttingDown then
		-- Detached crates keep their own inventories and persistence records.
		for _, crate in ipairs(self.crates or {}) do
			if IsValid(crate) then local pos, ang = crate:GetPos(), crate:GetAngles() crate:SetParent(NULL) crate:SetPos(pos) crate:SetAngles(ang) crate:RestorePhysics() end
		end
		self.crates = {} self:SetCrateCount(0)
	end
	P:Removed(self)
end

function ENT:SpawnFunction(client, trace)
	if !client:IsAdmin() or !trace.Hit then return end
	local ent = ents.Create("ix_pushcart")
	ent:SetPos(trace.HitPos + trace.HitNormal * 2 - Vector(0, 0, Kin.WHEEL_BOTTOM))
	ent:SetAngles(Angle(0, client:EyeAngles().y + 180, 0)) ent:Spawn()
	return ent
end
