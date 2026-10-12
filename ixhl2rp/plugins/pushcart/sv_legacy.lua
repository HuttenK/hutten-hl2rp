local P = ix.PushCart

-- Preserve old inventory items without keeping a second, larger world crate.
function P:ConvertCrateItem(item, original)
	if !IsValid(original) or item:GetEntity() != original or item.inventory_id or item.ixCrateConverting then return false end
	item.ixCrateConverting = true
	local crate = ents.Create("ix_cargo_crate")
	if !IsValid(crate) then item.ixCrateConverting = nil return false end
	crate:SetPos(original:LocalToWorld(Vector(0, 0, original:OBBMins().z)))
	crate:SetAngles(original:GetAngles())
	crate:Spawn()
	if !IsValid(crate) or !crate.GetInventory or !crate:GetInventory() then
		if IsValid(crate) then crate.cargoConsumed = true crate:Remove() end
		item.ixCrateConverting = nil
		return false
	end
	original.ixIsSafe = true
	item:Remove(true)
	ix.Item.entities[item.id] = nil
	original:Remove()
	item:SetEntity(nil)
	self:QueueSave()
	return true
end

-- The retired cart inventory remains an internal save handle. If an older
-- save contains loose cargo, move the same inventory to a physical recovery
-- crate, retaining its dimensions, item IDs and unresolved definitions.
function P:MigrateCartInventory(cart)
	local inv = cart:GetInventory()
	if !inv or cart.cargoLoading or cart.cargoPacking or IsValid(cart:GetPusher())
		or ix.storage.InUse(inv) or self:PendingTransfers(inv) then return false end
	if next(inv:GetItems()) == nil and #(cart.unplacedItems or {}) == 0 then return false end
	local pos
	for _, offset in ipairs({Vector(0, 52, cart.BedZ), Vector(0, -52, cart.BedZ), Vector(-75, 0, cart.BedZ), Vector(75, 0, cart.BedZ)}) do
		local point = cart:LocalToWorld(offset)
		local trace = util.TraceHull({start = point, endpos = point, mins = self.CRATE_MINS, maxs = self.CRATE_MAXS, mask = MASK_SOLID})
		if !trace.Hit and !trace.StartSolid then pos = point break end
	end
	if !pos then return false end -- Retry when there is room; never discard cargo.
	local record = self:Snapshot(cart)
	record.uid, record.class, record.crates, record.pos = self:NewUID(), "ix_cargo_crate", nil, pos
	record.ang = angle_zero
	record.autoLoadBlockedUID = cart.cargoUID
	local crate = self:RestoreRecord(record, inv)
	if !IsValid(crate) or crate:GetInventory() != inv then return false end
	self:CreateInventory(cart, self.INV_WIDTH, self.INV_HEIGHT, {uid = cart.cargoUID,
		inventoryType = "cargo_empty_" .. cart.cargoUID})
	self:CargoChanged(cart)
	self:QueueSave()
	return true
end
