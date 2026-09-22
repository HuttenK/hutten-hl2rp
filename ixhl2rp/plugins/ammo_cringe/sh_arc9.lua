-- Integration belongs to the schema; ARC9's addon and global SWEP tables stay untouched.
ix.arc9Inventory = ix.arc9Inventory or {}
local A = ix.arc9Inventory

function A.IsClass(class)
	local seen = {}
	while isstring(class) and not seen[class] do
		if class == "arc9_base" then return true end
		seen[class] = true
		local definition = weapons.GetStored(class)
		if not definition then return false end
		if definition.ARC9 then return true end
		class = definition.Base
	end
	return false
end

function A.AmmoItem(ammo)
	ammo = string.lower(ammo or "")
	for id, definition in SortedPairs(ix.Item.stored) do
		if isstring(definition.ammo) and definition.ammo:lower() == ammo then return id, definition end
	end
end

-- Only serialize state, never model/attachment functions or parent references.
function A.AttachmentTree(slots, depth)
	depth = depth or 0
	if depth > 12 then return {} end
	local result = {}
	for i, slot in ipairs(slots or {}) do
		result[i] = {Installed = slot.Installed, ToggleNum = slot.ToggleNum,
			SubAttachments = A.AttachmentTree(slot.SubAttachments, depth + 1)}
	end
	return result
end

if not SERVER then return end

function A.ReturnAmmo(client, ammo, count)
	count = math.max(0, math.floor(tonumber(count) or 0))
	if count == 0 then return true end
	A.Settle(client)
	local id, definition = A.AmmoItem(ammo)
	if not id then
		client:Notify("Нет предмета боеприпасов для " .. tostring(ammo) .. ". Разрядка отменена.")
		return false
	end
	local pending = {}
	while count > 0 do
		local stack = math.min(count, definition.max_stack or definition.ammoAmount or 30)
		local item = ix.Item:Instance(id)
		if not item then
			for _, created in ipairs(pending) do created:Remove(true) end
			return false
		end
		item:SetData("stack", stack)
		pending[#pending + 1] = item
		count = count - stack
	end
	for _, item in ipairs(pending) do
		if not client:AddItem(item) then ix.Item:Spawn(client, nil, item) end
	end
	client:CalculateAmmo(ammo:lower())
	return true
end

function A.Save(item, weapon)
	if not IsValid(weapon) or not weapon.ARC9 or weapon.ixItem ~= item or not weapon.ixInventoryReady then return end
	item:SetData("ammo", math.max(0, weapon:Clip1()))
	item:SetData("ammo2", math.max(0, weapon:Clip2()))
	item:SetData("ammoType", weapon:GetValue("Ammo"))
	item:SetData("ammoType2", weapon:GetValue("UBGLAmmo"))
	item:SetData("arc9_atts", A.AttachmentTree(weapon.Attachments))
end

function A.Bind(item, weapon, client)
	local saved = item:GetData("arc9_atts")
	-- A saved gun is authoritative. Do not prune it against a new owner's
	-- attachment stash or silently replace a caliber conversion with defaults.
	local function available(tree)
		for _, slot in ipairs(tree or {}) do
			if slot.Installed and ARC9 and ARC9.GetAttTable and not ARC9.GetAttTable(slot.Installed) then return false end
			if slot.Installed and ARC9 and ARC9.Blacklist and ARC9.Blacklist[slot.Installed] then return false end
			if not available(slot.SubAttachments) then return false end
		end
		return true
	end
	if istable(saved) and not available(saved) then
		client:Notify("Не хватает установленного аддона с модулями этого оружия. Сохранённые модули и патроны оставлены без изменений.")
		return false
	end
	weapon.ixItem = item
	-- Disposable launchers carry exactly one round in the item, never reserve ammo.
	if item.isDisposableEFT and not weapon.ixDisposableTakeAmmo then
		weapon.ixDisposableTakeAmmo = weapon.TakeAmmo
		weapon.TakeAmmo = function(self, ...)
			local result = self.ixDisposableTakeAmmo(self, ...)
			if self:Clip1() <= 0 and not item:GetData("arc9Spent") then
				item:SetData("arc9Spent", true)
				item:SetData("ammo", 0)
				-- Let the current firing call create its projectile before removing the SWEP.
				timer.Simple(0, function()
					if ix.Item.instances[item.id] == item then item:Remove(true) end
				end)
			end
			return result
		end
	end
	-- Stop delayed initialization/PostModify from minting a magazine or reserve.
	weapon.AlreadyGaveAmmo = true
	weapon.AlreadyGaveUBGLAmmo = true
	weapon.InitialDefaultClip = function() end
	weapon.GetInfiniteAmmo = function() return false end
	weapon.Unload = function(self, ammo)
		if self.ixInventoryRestoring then self:SetClip1(0) return end
		if A.ReturnAmmo(self:GetOwner(), ammo, self:Clip1()) then
			self:SetClip1(0)
			self:SetLoadedRounds(0)
		end
	end
	local originalModify = weapon.PostModify
	weapon.PostModify = function(self, ...)
		local owner = self:GetOwner()
		if self.ixInventoryReady and IsValid(owner) then
			-- ARC9 normally returns UBGL rounds directly to engine reserve.
			-- Return them to item stacks before ARC9 changes the ammo type.
			if self:Clip2() > 0 and (self.LastUBGLAmmo ~= self:GetValue("UBGLAmmo") or
				self.LastUBGLClipSize ~= self:GetValue("UBGLClipSize") or not self:GetValue("UBGL")) then
				if A.ReturnAmmo(owner, self.LastUBGLAmmo, self:Clip2()) then self:SetClip2(0) end
			end
		end
		return originalModify(self, ...)
	end
	weapon.ixInventoryRestoring = true
	if istable(saved) then
		weapon.Attachments = table.Copy(weapon.Attachments)
		-- BuildAttachmentAddresses must not reuse slots from the old tree.
		weapon:DoInvalidateCache()
		weapon:BuildSubAttachments(table.Copy(saved))
		weapon:DoInvalidateCache()
		local function matches(expected, actual)
			for i, slot in ipairs(expected or {}) do
				local restored = actual and actual[i]
				if slot.Installed then
					if not restored or restored.Installed ~= slot.Installed or (restored.ToggleNum or 1) ~= (slot.ToggleNum or 1) then return false end
					if not matches(slot.SubAttachments, restored.SubAttachments) then return false end
				elseif restored and restored.Installed then return false end
			end
			return true
		end
		if not matches(saved, weapon.Attachments) then
			client:Notify("Конфигурация оружия изменилась в аддоне. Сохранённые модули и патроны оставлены без изменений.")
			return false
		end
	end
	weapon.LastAmmo = weapon:GetValue("Ammo")
	weapon.LastClipSize = math.Round(weapon:GetProcessedValue("ClipSize"))
	weapon.LastUBGLAmmo = weapon:GetValue("UBGLAmmo")
	weapon.LastUBGLClipSize = weapon:GetValue("UBGLClipSize")
	weapon:SetBaseSettings()
	local magazines = {}
	for index, keys in ipairs({{"ammo", "ammoType", "Ammo"}, {"ammo2", "ammoType2", "UBGLAmmo"}}) do
		local rounds = math.max(0, item:GetData(keys[1], 0))
		local oldAmmo, newAmmo = item:GetData(keys[2]), weapon:GetValue(keys[3])
		local capacity = math.max(0, weapon:GetCapacity(index == 2))
		local changedCaliber = oldAmmo and newAmmo and oldAmmo:lower() ~= newAmmo:lower()
		local refund = changedCaliber and rounds or math.max(0, rounds - capacity)
		if refund > 0 then
			if not A.ReturnAmmo(client, oldAmmo or newAmmo, refund) then return false end
			rounds = rounds - refund
			item:SetData(keys[1], rounds)
		end
		magazines[index] = rounds
	end
	local rounds = magazines[1]
	if item.isGrenade or item.isGrenadeARC9 or item.isDisposableEFT then rounds = 1 end
	weapon:SetClip1(rounds)
	weapon:SetLoadedRounds(rounds)
	weapon:SetClip2(magazines[2])
	weapon.ixInventoryRestoring = nil
	weapon.ixInventoryReady = true
	weapon:SendWeapon()
	client:CalculateAmmo()
	return true
end
