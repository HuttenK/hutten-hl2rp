local P = ix.PushCart
util.AddNetworkString("ixPushCartMenu")
util.AddNetworkString("ixPushCartAction")

function P:CargoBusy(entity)
	local inv = entity:GetInventory()
	return !inv or entity.cargoLoading or entity.cargoPacking or ix.storage.InUse(inv) or self:PendingTransfers(inv)
end

function P:InteractionOptions(client, entity)
	if !self:CanInteract(client, entity) then return {} end
	if entity.ixIsPushCart and entity:GetPusher() == client then return {"stop"} end
	local cart = entity.isCartPatient and self:PatientCart(entity) or entity
	local patient = self.GetPatient and self:GetPatient(cart)
	if patient then
		if self:IsPushing(client) or IsValid(cart:GetPusher()) or self:CargoBusy(cart) then return {} end
		local options = {"examinePatient"}
		if !IsValid(client:GetLocalVar("holdingObject")) and !(ix.BodyDrag and ix.BodyDrag.Body(client)) then
			options[#options+1] = "takePatient"
			options[#options+1] = "unloadPatient"
			if entity.ixIsPushCart then options[#options+1] = "push" end
		end
		if entity.isCartPatient and patient:GetNetVar("crit",false) then options[#options+1]="robPatient"; options[#options+1]="finishPatient" end
		return options
	end
	if entity.isCartPatient then return {} end
	if self:CargoBusy(entity) or self:IsPushing(client) then return {} end
	if entity.ixIsPushCart then
		if IsValid(entity:GetPusher()) then return {} end
		local options = {}
		if !IsValid(client:GetLocalVar("holdingObject")) then table.insert(options, 1, "push") end
		if !self:HasContents(entity) then options[#options + 1] = "pack" end
		return options
	end
	local parent = entity:GetParent()
	if IsValid(parent) then
		return parent.ixIsPushCart and !self:CargoBusy(parent) and !IsValid(parent:GetPusher()) and {"detach"} or {}
	end
	if IsValid(entity.ixHeldOwner) then return entity.ixHeldOwner == client and {"drop"} or {} end
	return {"open", "pickup"}
end

function P:OpenInteraction(client, entity)
	if (client.nextPushCartUse or 0) > CurTime() or !self:CanInteract(client, entity) then return end
	client.nextPushCartUse = CurTime() + 0.3
	if entity.ixIsPushCart and ix.BodyDrag and ix.BodyDrag.Body(client) then
		local ok, reason = self:LoadPatient(client,entity)
		if !ok and reason then client:Notify(reason) end
		return
	end
	local options = self:InteractionOptions(client, entity)
	client.ixCartMenuSerial = ((client.ixCartMenuSerial or 0) + 1) % 65536
	client.ixCartMenu = {entity = entity, parent = entity:GetParent(), character = client:GetCharacter(),
		token = client.ixCartMenuSerial, expires = CurTime() + 15, options = options,
		patient = self.GetPatient and self:GetPatient(entity.isCartPatient and self:PatientCart(entity) or entity)}
	net.Start("ixPushCartMenu")
		net.WriteEntity(entity) net.WriteUInt(client.ixCartMenuSerial, 16) net.WriteUInt(#options, 3)
		for _, action in ipairs(options) do net.WriteString(action) end
	net.Send(client)
end

function P:PickupCrate(client, crate)
	if !self:IsLoadable(crate) or IsValid(crate:GetParent()) or self:CargoBusy(crate) then return false end
	local hands = client:GetWeapon("ix_hands")
	if !IsValid(hands) or !hands:CanHoldObject(crate) then return false end
	client:SelectWeapon("ix_hands")
	hands:PickupObject(crate)
	if hands.heldEntity != crate then return false end
	client:SetLocalVar("bIsHoldingObject", true) client:SetLocalVar("holdingObject", crate)
	return true
end

function P:PerformInteraction(client, entity, token, action)
	local menu = client.ixCartMenu
	if !menu or menu.token != token then return false end
	client.ixCartMenu = nil -- A click is consumed once, including a stale click.
	if menu.entity != entity or menu.character != client:GetCharacter() or menu.expires < CurTime()
		or !self:CanInteract(client, entity) or entity:GetParent() != menu.parent then return false end
	if !table.HasValue(menu.options, action) or !table.HasValue(self:InteractionOptions(client, entity), action) then return false end
	local cart = entity.isCartPatient and self:PatientCart(entity) or entity
	if menu.patient != (self.GetPatient and self:GetPatient(cart)) then return false end
	local ok = false
	if action == "takePatient" or action == "unloadPatient" then
		local reason
		ok, reason = self:UnloadPatient(client,cart,action=="takePatient")
		if reason then client:Notify(reason) end
	elseif action == "push" then ok = entity:StartPush(client)
	elseif action == "stop" then entity:StopPush() ok = true
	elseif action == "open" then ok = self:OpenInventory(client, entity)
	elseif action == "pack" then ok = self:Pack(client, entity, self.ITEM)
	elseif action == "pickup" then ok = self:PickupCrate(client, entity)
	elseif action == "detach" then ok = entity:GetParent():UnloadCrate(client, entity)
	elseif action == "drop" then
		local hands = client:GetWeapon("ix_hands")
		if IsValid(hands) and hands.heldEntity == entity and entity.ixHeldOwner == client then hands:DropObject() ok = true end
	end
	-- Push, detach and packing already report their specific failure reason.
	if !ok and (action == "pickup" or action == "drop" or action == "open") then
		client:Notify("Действие недоступно: освободите руки и место рядом с грузом.")
	end
	return ok
end

net.Receive("ixPushCartAction", function(_, client)
	local entity, token, action = net.ReadEntity(), net.ReadUInt(16), net.ReadString()
	P:PerformInteraction(client, entity, token, action)
end)

-- A small loading zone around the deck, expressed in the cart's own axes.
function P:InLoadingZone(cart, crate, padding)
	local point = cart:WorldToLocal(crate:WorldSpaceCenter())
	padding = padding or 0
	return point.x >= cart.BedMinX - 16 - padding and point.x <= cart.BedMaxX + 16 + padding
		and math.abs(point.y) <= cart.BedHalfY + 18 + padding
		and point.z >= cart.BedZ - 10 - padding and point.z <= cart.BedZ + 66 + padding
end

function P:TryAutoLoad(crate)
	if !self:IsLoadable(crate) or IsValid(crate:GetParent()) or self:CargoBusy(crate) then return false end
	local blocked = IsValid(crate.ixAutoLoadBlockedCart) and crate.ixAutoLoadBlockedCart or self.entities[crate.ixAutoLoadBlockedUID or ""]
	if IsValid(blocked) and !self:InLoadingZone(blocked, crate, 14) then
		crate.ixAutoLoadBlockedCart, crate.ixAutoLoadBlockedUID, blocked = nil, nil, nil
	end
	local carts = self:FindCartsNear(crate:GetPos(), 175)
	table.sort(carts, function(a,b) return a:GetPos():DistToSqr(crate:GetPos()) < b:GetPos():DistToSqr(crate:GetPos()) end)
	for _, cart in ipairs(carts) do
		if cart == blocked or cart.cargoUID == crate.ixAutoLoadBlockedUID or !self:InLoadingZone(cart, crate) or !cart:CanAttachCrate(crate) then continue end
		local holder = crate.ixHeldOwner
		local hands = IsValid(holder) and holder:GetWeapon("ix_hands")
		if IsValid(holder) and (!self:CanOperate(holder) or !IsValid(hands) or hands.heldEntity != crate) then return false end
		local filter = {cart, crate}
		if IsValid(holder) then filter[#filter + 1] = holder end
		local slot = cart:CrateSlot(#cart.crates + 1)
		local destination = cart:LocalToWorld(slot)
		local trace = util.TraceHull({start = crate:GetPos(), endpos = destination,
			mins = Vector(-10.5,-10.5,0), maxs = Vector(10.5,10.5,22), filter = filter, mask = MASK_SOLID})
		if trace.Hit or trace.StartSolid then continue end
		-- Release the Helix hand constraint before parenting; engine-held props
		-- (physgun/gravity gun/+use) have their own separate release operation.
		if IsValid(holder) then hands:DropObject() end
		crate:ForcePlayerDrop()
		if cart:AttachCrate(crate) then
			cart:EmitSound("physics/wood/wood_box_impact_soft1.wav", 60, 100, .5)
			return true
		end
	end
	return false
end
