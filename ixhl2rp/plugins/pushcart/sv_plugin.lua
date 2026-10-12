-- Reconstructed Foundation backend. API references: game/inventory/sh_storage.lua,
-- sh_inventory.class.lua, and game/items/sh_item.lua (native capitalized APIs).
local PLUGIN = PLUGIN
local P = ix.PushCart
P.recovery = P.recovery or {}
P.entities = P.entities or {}
-- ix_hands asks the core allowlist after plugin vetoes; no permissive hook
-- return here that could hide another plugin's restriction.
ix.allowedHoldableClasses["ix_cargo_crate"] = true

function P:NewUID()
	self.serial = (self.serial or 0) + 1
	return util.CRC(tostring(os.time()) .. ":" .. tostring(SysTime()) .. ":" .. self.serial)
end

function P:Near(client, entity, range)
	if !self:CanOperate(client) or !IsValid(entity) then return false end
	local point = entity:NearestPoint(client:GetShootPos())
	if point:DistToSqr(client:GetShootPos()) > (range or self.USE_RANGE)^2 then return false end
	local tr = util.TraceLine({start = client:GetShootPos(), endpos = point, filter = client, mask = MASK_SOLID})
	return !tr.Hit or tr.Entity == entity or tr.Entity:GetParent() == entity
end

function P:CreateInventory(entity, width, height, record)
	entity.cargoUID = record and record.uid or self:NewUID()
	local inventory = record and record.liveInventory or ix.meta.Inventory:New()
	inventory:SetSize(width, height)
	inventory.title = entity.isCargoCrate and "Грузовой ящик" or "Кузов тележки"
	inventory.type = record and record.inventoryType or ("cargo_" .. entity.cargoUID)
	inventory.owner = entity
	inventory.ixPushCargo = true
	entity:SetInventoryID(inventory.id)
	P.entities[entity.cargoUID] = entity
	entity.cargoLoading = inventory.cargoLoading
	entity.pendingItems = inventory.pendingItems
	entity.unplacedItems = inventory.unplacedItems
	if record and !record.liveInventory and record.items and #record.items > 0 then
		entity.cargoLoading = true
		entity.pendingItems = table.Copy(record.items)
		inventory.cargoLoading = true inventory.pendingItems = entity.pendingItems
		local ids, unresolved = {}, {}
		for _, id in ipairs(record.items) do unresolved[id] = true end
		local function place(item)
			if item.inventory_id or item.inventory_type != inventory.type then unresolved[item.id] = nil return end
			if !inventory:AddItem(item, item.x, item.y, nil, true) and !inventory:AddItem(item, nil, nil, nil, true) then
				ErrorNoHalt("[Push Cart] Cannot fit saved item #" .. item.id .. "; retained for recovery.\n")
			else unresolved[item.id] = nil end
		end
		for _, id in ipairs(record.items) do
			-- Do not let LoadInstanceByID overwrite a live instance held elsewhere.
			local item = ix.Item.instances[id]
			if item then place(item) else ids[#ids + 1] = id end
		end
		local function completed()
			-- Missing definitions produce no item callback. Retain those IDs as well.
			inventory.unplacedItems = {}
			for _, id in ipairs(record.items) do if unresolved[id] then inventory.unplacedItems[#inventory.unplacedItems + 1] = id end end
			if #inventory.unplacedItems == 0 then inventory.unplacedItems = nil end
			inventory.cargoLoading = nil inventory.pendingItems = nil
			local owner = inventory.owner
			if IsValid(owner) then
				owner.cargoLoading = nil owner.pendingItems = nil
				owner.unplacedItems = inventory.unplacedItems
				self:CargoChanged(owner)
			end
			self:QueueSave()
		end
		if #ids == 0 then completed() return inventory end
		ix.Item:LoadInstanceByID(ids, place, completed)
	end
	return inventory
end

function P:HasContents(entity)
	local inv = entity:GetInventory()
	return entity.cargoLoading or (entity.pendingItems and #entity.pendingItems > 0)
		or (entity.unplacedItems and #entity.unplacedItems > 0)
		or (inv and next(inv:GetItems()) != nil)
		or (entity.ixIsPushCart and entity:GetCrateCount() > 0)
end

function P:PendingTransfers(inventory, cancel)
	local pendingIDs = {}
	for id, transfer in pairs(ix.Inventory.pendingTransfers or {}) do
		if istable(transfer) and (transfer.from_id == inventory.id or transfer.to_id == inventory.id) then pendingIDs[#pendingIDs + 1] = id end
	end
	if cancel then for _, id in ipairs(pendingIDs) do ix.Inventory:CancelTransfer(id) end end
	return #pendingIDs > 0
end

function P:CloseInventory(entity)
	local inv = entity:GetInventory()
	if !inv then return end
	self:PendingTransfers(inv, true)
	for _, client in pairs(table.Copy(inv:GetReceivers())) do
		if IsValid(client) and client.ixOpenStorage == inv then
			net.Start("ixStorageExpired") net.WriteUInt(inv.id, 32) net.Send(client)
			ix.storage.RemoveReceiver(client, inv)
		end
	end
end

function P:OpenInventory(client, entity)
	if !IsValid(entity) or !entity.isCargoCrate then return false end
	if !self:Near(client, entity) or entity.cargoLoading or entity.cargoPacking then return false end
	if IsValid(entity:GetParent()) or IsValid(entity.ixHeldOwner) then return false end
	if entity.GetPusher and IsValid(entity:GetPusher()) then return false end
	local inv = entity:GetInventory()
	if !inv then return false end
	if client.ixOpenStorage and client.ixOpenStorage != inv then ix.storage.RemoveReceiver(client, client.ixOpenStorage) end
	ix.storage.Open(client, inv, {name = inv.title, entity = entity, searchTime = 0,
		OnPlayerClose = function() self:CargoChanged(entity) self:QueueSave() end})
	return true
end

function P:CargoChanged(entity)
	if !IsValid(entity) then return end
	if entity.UpdateLoad then entity:UpdateLoad() end
	if entity.ixIsPushCart then
		entity:SetCargoRev((entity:GetCargoRev() + 1) % 2147483647)
		entity:LayoutCrates()
	elseif IsValid(entity:GetParent()) and entity:GetParent().ixIsPushCart then
		entity:GetParent():UpdateLoad()
	end
end

function P:RetryUnplaced(entity, callback)
	local inv = entity:GetInventory()
	if !inv or entity.cargoLoading or self:PendingTransfers(inv) then return 0 end
	local ids = table.Copy(entity.unplacedItems or {})
	local unresolved, missing, recovered = {}, {}, 0
	for _, id in ipairs(ids) do unresolved[id] = true end
	local function place(item)
		if item and item.inventory_type == inv.type and !item.inventory_id then
			if inv:AddItem(item, nil, nil, nil, true) then item:Save() recovered = recovered + 1 unresolved[item.id] = nil end
		elseif item then unresolved[item.id] = nil end
	end
	local function completed()
		local remaining = {}
		for _, id in ipairs(ids) do if unresolved[id] then remaining[#remaining + 1] = id end end
		inv.unplacedItems = #remaining > 0 and remaining or nil
		inv.cargoLoading = nil
		local owner = inv.owner
		if IsValid(owner) then
			owner.unplacedItems = inv.unplacedItems owner.cargoLoading = nil
			self:CargoChanged(owner)
		end
		self:QueueSave()
		if callback then callback(recovered, #remaining) end
	end
	for _, id in ipairs(ids) do
		local item = ix.Item.instances[id]
		if item then place(item) else missing[#missing + 1] = id end
	end
	if #missing > 0 then
		entity.cargoLoading = true inv.cargoLoading = true
		ix.Item:LoadInstanceByID(missing, place, completed)
	else completed() end
	return recovered
end

function P:QueueSave()
	if self.loading or self.cleaning or ix.shuttingDown then return end
	timer.Create("ixPushCartSave", 0.2, 1, function() self.plugin:SaveData() end)
end

function P:Snapshot(entity)
	local inv = entity:GetInventory()
	if !inv then return end
	local ids, seen = {}, {}
	for _, id in ipairs(inv:GetItemsID()) do ids[#ids + 1] = id seen[id] = true end
	for _, source in ipairs({entity.pendingItems or {}, entity.unplacedItems or {}}) do
		for _, id in ipairs(source) do if !seen[id] then ids[#ids + 1] = id seen[id] = true end end
	end
	for _, item in pairs(inv:GetItems()) do item:Save() end
	local record = {uid = entity.cargoUID, inventoryType = inv.type, items = ids,
		width = inv.width, height = inv.height, class = entity:GetClass(), pos = entity:GetPos(), ang = entity:GetAngles()}
	if entity.isCargoCrate then
		record.autoLoadBlockedUID = entity.ixAutoLoadBlockedUID
		record.cartSlot = entity:GetCartSlot()
	end
	if entity.ixIsPushCart then
		record.geometryVersion = self.GEOMETRY_VERSION
		record.crates = {}
		for _, crate in ipairs(entity.crates or {}) do
			if IsValid(crate) then record.crates[#record.crates + 1] = self:Snapshot(crate) end
		end
	end
	return record
end

function PLUGIN:SaveData()
	if P.loading or P.cleaning then return end
	local records = {}
	for cart in pairs(P.carts) do if IsValid(cart) then records[#records + 1] = P:Snapshot(cart) end end
	for crate in pairs(P.crates) do
		if IsValid(crate) and !IsValid(crate:GetParent()) then records[#records + 1] = P:Snapshot(crate) end
	end
	for _, entry in pairs(P.recovery) do
		local record = table.Copy(entry.record)
		record.liveInventory = nil
		record.crates = nil
		record.class = "ix_cargo_crate"
		records[#records + 1] = record
	end
	self:SetData({version = 1, records = records})
end

function P:RestoreRecord(record, live)
	if !istable(record) or !isstring(record.uid) or !isvector(record.pos) then return end
	if IsValid(self.entities[record.uid]) then return self.entities[record.uid] end
	if !live then
		for _, id in ipairs(record.items or {}) do
			local item = ix.Item.instances[id]
			local previous = item and item.inventory_id and ix.Inventory:Get(item.inventory_id)
			if previous and previous.ixPushCargo and previous.type == record.inventoryType and !IsValid(previous.owner) then live = previous break end
		end
	end
	local class = record.class == "ix_pushcart" and "ix_pushcart" or "ix_cargo_crate"
	local entity = ents.Create(class)
	if !IsValid(entity) then return end
	entity.cargoRecord = table.Copy(record)
	entity.cargoRecord.liveInventory = live
	entity.ixAutoLoadBlockedUID = isstring(record.autoLoadBlockedUID) and record.autoLoadBlockedUID or nil
	local ang = record.ang or angle_zero
	local pos = record.pos
	if class == "ix_pushcart" and (record.geometryVersion or 1) < self.GEOMETRY_VERSION then
		-- Preserve the old world-space wheel/deck/hand positions, including tilted saves.
		pos = pos - ang:Up() * self.MODEL_Z_OFFSET
	end
	entity:SetPos(pos)
	entity:SetAngles(ang)
	entity:Spawn()
	if class == "ix_pushcart" then
		for _, child in ipairs(record.crates or {}) do
			local crate = self:RestoreRecord(child)
			if IsValid(crate) then entity:AttachCrate(crate, true) end
		end
	end
	return entity
end

function PLUGIN:LoadData()
	local data = self:GetData() or {}
	P.loading = true
	for _, record in ipairs(data.records or {}) do P:RestoreRecord(record) end
	P.loading = nil
end

-- Cleanup restores the same live item objects, never a second DB instance.
function PLUGIN:PreCleanupMap()
	self:SaveData()
	P.cleaning = true
	P.cleanupRecords = {}
	for _, registry in ipairs({P.carts, P.crates}) do
		for entity in pairs(registry) do
			if IsValid(entity) then
				if entity.StopPush then entity:StopPush() end
				P:CloseInventory(entity)
				P.cleanupRecords[#P.cleanupRecords + 1] = {record = P:Snapshot(entity), inv = entity:GetInventory(), parent = entity:GetParent().cargoUID}
			end
		end
	end
end

function PLUGIN:PostCleanupMap()
	local restored = {}
	for _, entry in ipairs(P.cleanupRecords or {}) do
		entry.record.crates = nil
		local entity = P:RestoreRecord(entry.record, entry.inv)
		restored[entry.record.uid] = entity
	end
	for _, entry in ipairs(P.cleanupRecords or {}) do
		local parent, child = restored[entry.parent], restored[entry.record.uid]
		if IsValid(parent) and IsValid(child) then parent:AttachCrate(child, true) end
	end
	P.cleanupRecords = nil
	P.cleaning = nil
	P:QueueSave()
end

-- Removing a nonempty storage entity recovers its inventory in a loose crate.
-- A failed recovery remains in the save file and is retried on the next load.
function P:Removed(entity)
	self.carts[entity] = nil self.crates[entity] = nil
	self.entities[entity.cargoUID] = nil
	if self.cleaning or ix.shuttingDown then return end
	self:CloseInventory(entity)
	local inv = entity:GetInventory()
	if !inv then return end
	if !entity.cargoConsumed and self:HasContents(entity) then
		local record = self:Snapshot(entity)
		record.class = "ix_cargo_crate" record.crates = nil
		self.recovery[record.uid] = {record = record, inventory = inv}
		timer.Simple(0, function()
			local entry = self.recovery[record.uid]
			if !entry then return end
			if IsValid(self:RestoreRecord(entry.record, entry.inventory)) then self.recovery[record.uid] = nil end
			self:QueueSave()
		end)
	else
		ix.Inventory.stored[inv.id] = nil
	end
	self:QueueSave()
end

function P:Pack(client, entity, itemID)
	if !IsValid(entity) or !entity.ixIsPushCart or itemID != self.ITEM then return false end
	if !self:Near(client, entity) or self:HasContents(entity) or entity.cargoPacking then return false end
	if IsValid(entity:GetParent()) or IsValid(entity.ixHeldOwner) then return false end
	if entity.GetPusher and IsValid(entity:GetPusher()) then return false end
	if ix.storage.InUse(entity:GetInventory()) or self:PendingTransfers(entity:GetInventory()) then return false end
	entity.cargoPacking = true
	local item = ix.Item:Instance(itemID)
	if !item then entity.cargoPacking = nil return false end
	if !client:AddItem(item) then
		-- Native Remove(true) deletes a just-created instance; Remove() only detaches.
		item:Remove(true)
		entity.cargoPacking = nil
		client:Notify("В инвентаре нет места.")
		return false
	end
	item:Save()
	entity.cargoConsumed = true
	entity:Remove()
	self:QueueSave()
	return true
end

function P:Deploy(item, class)
	local client = item.player
	if !IsValid(client) then return false end
	if !self:CanOperate(client) then
		client:Notify("Для установки нужно стоять на земле, вне транспорта и без ограничений движения.")
		return false
	end
	if IsValid(item:GetEntity()) then return false end
	local inv = item.inventory_id and ix.Inventory:Get(item.inventory_id)
	if !inv or inv:GetOwner() != client then
		client:Notify("Сначала переместите предмет в свой инвентарь.")
		return false
	end
	local cart = class == "ix_pushcart"
	local yaw = client:EyeAngles().y + (cart and 180 or 0)
	local forward = Angle(0, client:EyeAngles().y, 0):Forward()
	local point = client:GetPos() + forward * (cart and 76 or 48)
	local floor = util.TraceLine({start = point + Vector(0, 0, 32), endpos = point - Vector(0, 0, 80), filter = client, mask = MASK_SOLID})
	if !floor.Hit or floor.HitNormal.z < 0.8 then client:Notify("Нужна ровная свободная площадка.") return false end
	local pos = floor.HitPos + Vector(0, 0, 1)
	local half = cart and 49 or 17
	local tr = util.TraceHull({start = pos, endpos = pos, mins = Vector(-half, -half, 1), maxs = Vector(half, half, cart and 50 or 30), filter = client, mask = MASK_SOLID})
	if tr.Hit or tr.StartSolid then client:Notify("Недостаточно места для установки.") return false end
	local entity = ents.Create(class)
	if !IsValid(entity) then
		client:Notify("Не удалось создать оборудование. Предмет остался в инвентаре; сообщите администратору.")
		return false
	end
	entity:SetPos(cart and (pos - Vector(0, 0, self.Kin.WHEEL_BOTTOM)) or pos) entity:SetAngles(Angle(0, yaw, 0)) entity:Spawn()
	if !IsValid(entity) or !entity.GetInventory or !entity:GetInventory() then
		if IsValid(entity) then entity.cargoConsumed = true entity:Remove() end
		client:Notify("Не удалось подготовить оборудование. Предмет остался в инвентаре; сообщите администратору.")
		return false
	end
	item:Remove(true)
	self:QueueSave()
	return true
end

function PLUGIN:InventoryItemAdded(old, inventory, item)
	if inventory.ixPushCargo then P:CargoChanged(inventory.owner) item:Save() P:QueueSave() end
	if old and old.ixPushCargo then P:CargoChanged(old.owner) item:Save() P:QueueSave() end
end
function PLUGIN:InventoryItemRemoved(inventory, item)
	if inventory.ixPushCargo then P:CargoChanged(inventory.owner) P:QueueSave() end
end
function PLUGIN:CanTransferItem(item, target, x, y, source)
	for _, inv in ipairs({target, source}) do
		if inv and inv.ixPushCargo then
			local ent = inv.owner
			if !IsValid(ent) or ent.ixIsPushCart or ent.cargoLoading or ent.cargoPacking or IsValid(ent:GetParent())
				or IsValid(ent.ixHeldOwner) or (ent.GetPusher and IsValid(ent:GetPusher())) then return false, "storageInUse" end
		end
	end
end

function PLUGIN:CanMoveItem(item, inventory)
	if !inventory.ixPushCargo then return end
	local entity = inventory.owner
	if !IsValid(entity) or entity.ixIsPushCart or entity.cargoLoading or entity.cargoPacking or IsValid(entity:GetParent())
		or IsValid(entity.ixHeldOwner) or (entity.GetPusher and IsValid(entity:GetPusher())) then return false, "storageInUse" end
	-- Native MoveItem has a veto hook but no post-move hook. Rebuild once the
	-- current synchronous move has finished, including rotation and stacking.
	timer.Create("ixPushCartLayout" .. inventory.id, 0, 1, function()
		if IsValid(entity) then P:CargoChanged(entity) P:QueueSave() end
	end)
end

function PLUGIN:KeyPress(client, key)
	if key != IN_USE or !P:CanOperate(client) then return end
	local target = P:GetPushedCart(client) or P:InteractionTarget(client)
	if IsValid(target) then P:OpenInteraction(client, target) end
end

local function Release(client)
	local cart = P:GetPushedCart(client)
	if cart then cart:StopPush() end
end
function PLUGIN:PlayerDeath(client) Release(client) end
function PLUGIN:PlayerDisconnected(client) Release(client) end
function PLUGIN:PlayerLoadedCharacter(client) Release(client) end
function PLUGIN:CanPlayerHoldObject(client, entity)
	if P:IsPushing(client) or entity.ixIsPushCart or (entity.isCargoCrate and (IsValid(entity:GetParent()) or entity.cargoLoading or ix.storage.InUse(entity:GetInventory()) or P:PendingTransfers(entity:GetInventory()))) then return false end
end
function PLUGIN:PhysgunPickup(client, entity)
	if entity.ixIsPushCart and IsValid(entity:GetPusher()) then return false end
	if entity.isCargoCrate and IsValid(entity:GetParent()) then return false end
end
function PLUGIN:CanTool(client, trace)
	if IsValid(trace.Entity) and (trace.Entity.ixIsPushCart or trace.Entity.isCargoCrate) then return false end
end
function PLUGIN:CanDrive(client, entity)
	if entity.ixIsPushCart or entity.isCargoCrate then return false end
end
function PLUGIN:PlayerSwitchWeapon(client, old, weapon)
	if P:IsPushing(client) and IsValid(weapon) and weapon:GetClass() != "ix_hands" then return true end
end

concommand.Add("ix_pushcart_debug", function(client)
	if IsValid(client) and client:IsAdmin() then client.ixPushCartDebug = !client.ixPushCartDebug end
end)

concommand.Add("ix_pushcart_recover", function(client)
	if !IsValid(client) or !client:IsAdmin() then return end
	local entity = client:GetEyeTrace().Entity
	if !IsValid(entity) or !(entity.ixIsPushCart or entity.isCargoCrate) or !P:Near(client, entity) then return end
	P:RetryUnplaced(entity, function(recovered, remaining)
		if IsValid(client) then client:Notify("Возвращено предметов: " .. recovered .. ". Ожидает восстановления: " .. remaining) end
	end)
end)
