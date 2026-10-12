ENT.Type = "anim"
ENT.PrintName = "Грузовой ящик"
ENT.Category = "Foundation — Logistics"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.bNoPersist = true
ENT.isCargoCrate = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "InventoryID")
	self:NetworkVar("Int", 1, "CartSlot")
	self:NetworkVar("Float", 0, "CargoLoad")
end
function ENT:GetInventory() return ix.Inventory:Get(self:GetInventoryID()) end

if SERVER then
	function ENT:RestorePhysics()
		-- A fixed 21 x 21 x 22 box fits each recovered stack column.
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetNotSolid(false)
		self:PhysicsInitBox(ix.PushCart.CRATE_MINS, ix.PushCart.CRATE_MAXS)
		self:SetCollisionBounds(ix.PushCart.CRATE_MINS, ix.PushCart.CRATE_MAXS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_NONE)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:SetMass(10 + self:GetCargoLoad() * 35) phys:EnableMotion(true) phys:Wake() end
	end
	function ENT:Initialize()
		self:SetModel(ix.PushCart.CRATE_MODEL)
		self:SetUseType(SIMPLE_USE)
		local record = self.cargoRecord
		self:SetCartSlot(record and math.Clamp(tonumber(record.cartSlot) or 0, 0, ix.PushCart.MAX_CRATES) or 0)
		ix.PushCart:CreateInventory(self, record and record.width or 4, record and record.height or 4, record)
		self.cargoRecord = nil
		self:RestorePhysics()
		ix.PushCart.crates[self] = true
		self:UpdateLoad()
		ix.PushCart:QueueSave()
	end
	function ENT:UpdateLoad()
		local inv, cells = self:GetInventory(), 0
		if !inv then return end
		for _, item in pairs(inv:GetItems()) do local w, h = inv:GetItemSize(item) cells = cells + w * h end
		self:SetCargoLoad(math.Clamp(cells / (inv.width * inv.height), 0, 1))
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then phys:SetMass(10 + self:GetCargoLoad() * 35) end
	end
	function ENT:Use(client)
		ix.PushCart:OpenInteraction(client, self)
	end
	function ENT:Think()
		ix.PushCart:TryAutoLoad(self)
		self:NextThink(CurTime() + 0.25)
		return true
	end
	function ENT:OnRemove()
		local parent = self:GetParent()
		if IsValid(parent) and parent.ixIsPushCart then
			table.RemoveByValue(parent.crates, self)
			parent:UpdateLoad() parent:LayoutCrates()
		end
		ix.PushCart:Removed(self)
	end
	function ENT:SpawnFunction(client, trace)
		if !client:IsAdmin() or !trace.Hit then return end
		local ent = ents.Create("ix_cargo_crate")
		ent:SetPos(trace.HitPos + trace.HitNormal * 2) ent:Spawn()
		return ent
	end
else
	ENT.PopulateEntityInfo = true
	function ENT:Initialize()
		-- Nonuniform render matrix fits stock crate mesh to the collision and
		-- keeps its bottom at z=0. No Workshop crate asset is required.
		local mn, mx = self:GetModelBounds()
		local size = mx - mn
		local scale = Vector(21 / math.max(size.x, 1), 21 / math.max(size.y, 1), 22 / math.max(size.z, 1))
		local matrix = Matrix()
		matrix:SetTranslation(Vector(-(mx.x + mn.x) * 0.5 * scale.x, -(mx.y + mn.y) * 0.5 * scale.y, -mn.z * scale.z))
		matrix:Scale(scale)
		self:EnableMatrix("RenderMultiply", matrix)
		self:SetCollisionBounds(ix.PushCart.CRATE_MINS, ix.PushCart.CRATE_MAXS)
		self:SetRenderBounds(Vector(-11, -11, 0), Vector(11, 11, 22))
	end
	function ENT:Draw() self:DrawModel() end
	function ENT:OnPopulateEntityInfo(tooltip)
		local title = tooltip:AddRow("name") title:SetText(self.PrintName) title:SetImportant() title:SizeToContents()
		local row = tooltip:AddRow("description")
		row:SetText(IsValid(self:GetParent()) and "E — действия • отсоединить ящик" or "E — действия • поднесите к тележке для погрузки")
		row:SizeToContents()
	end
end
