local PLUGIN = PLUGIN

PLUGIN.name = "Ammo Inventory Sync"
PLUGIN.author = "Fix"
PLUGIN.description = "Makes weapons pull ammo directly from the inventory."

local playerMeta = FindMetaTable("Player")

function playerMeta:CalculateAmmo(ammoType)
	if not SERVER then return end
	local character = self:GetCharacter()
	if not character then return end
	local inventory = self:GetInventory("main")
	if not inventory then return end

	-- If ammoType is specified, we only tally that. Otherwise tally all.
	local totals = {}

	for _, item in pairs(inventory:GetItems()) do
		if item.ammo then
			local aType = item.ammo:lower()
			if not ammoType or aType == ammoType then
				local stackAmount = (item.GetValue and item:GetValue()) or item:GetData("stack") or item.ammoAmount or 30
				totals[aType] = (totals[aType] or 0) + stackAmount
			end
		end
	end

	self.ixAmmoTracker = self.ixAmmoTracker or {}

	if ammoType then
		local t = totals[ammoType] or 0
		self:SetAmmo(t, ammoType)
		self.ixAmmoTracker[ammoType] = t
	else
		for k, v in pairs(self.ixAmmoTracker) do
			self:SetAmmo(0, k)
		end

		for aType, amount in pairs(totals) do
			self:SetAmmo(amount, aType)
			self.ixAmmoTracker[aType] = amount
		end
	end
end

if SERVER then
	-- Constantly check if the engine ammo went down (which means the weapon consumed it)
	function PLUGIN:PlayerTick(client)
		if not client:Alive() or not client:GetCharacter() then return end

		client.ixAmmoTracker = client.ixAmmoTracker or {}

		local weapon = client:GetActiveWeapon()
		if IsValid(weapon) then
			local primaryAmmo = weapon:GetPrimaryAmmoType()
			if primaryAmmo > 0 then
				local ammoName = game.GetAmmoName(primaryAmmo)
				if not ammoName then return end
				ammoName = ammoName:lower()

				local currentAmmo = client:GetAmmoCount(primaryAmmo)
				local trackedAmmo = client.ixAmmoTracker[ammoName] or 0
				
				-- The player used ammo (e.g. reloaded or fired)
				if currentAmmo < trackedAmmo then
					local diff = trackedAmmo - currentAmmo
					local inventory = client:GetInventory("main")
					
					if inventory then
						for _, item in pairs(inventory:GetItems()) do
							if item.ammo and item.ammo:lower() == ammoName then
								local stack = (item.GetValue and item:GetValue()) or item:GetData("stack") or item.ammoAmount or 30
								if stack > diff then
									item:SetData("stack", stack - diff)
									diff = 0
									break
								else
									diff = diff - stack
									item:Remove()
								end
							end
						end
					end
					
					-- Update the tracker
					client.ixAmmoTracker[ammoName] = currentAmmo

				-- Ammo somehow increased (gave ammo via engine weapon spawn). 
				-- Strip the excess to stay synced with the inventory items!
				elseif currentAmmo > trackedAmmo then
					client:SetAmmo(trackedAmmo, primaryAmmo)
				end
			end
		end
	end

	function PLUGIN:PlayerLoadedCharacter(client, character, currentChar)
		timer.Simple(0.5, function()
			if IsValid(client) then
				client:CalculateAmmo()
			end
		end)
	end

	-- InventoryItemAdded(oldInv, newInv, item) fires when an item enters any inventory.
	-- oldInv is nil when the item is spawned directly in; both are set on transfers.
	-- Helix inventories store the owner as a plain .owner property.
	function PLUGIN:InventoryItemAdded(oldInv, newInv, item)
		if not item.ammo then return end
		local ammoType = item.ammo:lower()

		-- Item arrived in a player's inventory — sync their reserve up.
		if newInv and IsValid(newInv.owner) and newInv.owner:IsPlayer() then
			local owner = newInv.owner
			timer.Simple(0.1, function()
				if IsValid(owner) then owner:CalculateAmmo(ammoType) end
			end)
		end

		-- Item left a player's inventory (transfer between inventories) — sync down.
		if oldInv and IsValid(oldInv.owner) and oldInv.owner:IsPlayer() then
			local owner = oldInv.owner
			timer.Simple(0.1, function()
				if IsValid(owner) then owner:CalculateAmmo(ammoType) end
			end)
		end
	end

	-- InventoryItemRemoved(inv, item[, newInv]) fires when an item is removed
	-- without going through Transfer (e.g. dropped to world, destroyed).
	function PLUGIN:InventoryItemRemoved(inv, item, newInv)
		if not item.ammo then return end
		-- Only handle cases where the item is NOT going to another inventory
		-- (transfers are already handled by InventoryItemAdded above).
		if newInv then return end

		local ammoType = item.ammo:lower()
		if inv and IsValid(inv.owner) and inv.owner:IsPlayer() then
			local owner = inv.owner
			timer.Simple(0.1, function()
				if IsValid(owner) then owner:CalculateAmmo(ammoType) end
			end)
		end
	end
end

ix.command.Add("AmmoDebug", {
	description = "Print ammo debugging info to see why your weapon isn't reloading.",
	adminOnly = false,
	OnRun = function(self, client)
		local weapon = client:GetActiveWeapon()
		if not IsValid(weapon) then
			return "You must be holding a weapon!"
		end

		local primaryAmmo = weapon:GetPrimaryAmmoType()
		local ammoName = game.GetAmmoName(primaryAmmo) or "unknown"
		local currentAmmo = client:GetAmmoCount(primaryAmmo)
		local trackedAmmo = (client.ixAmmoTracker and client.ixAmmoTracker[ammoName:lower()]) or 0
		local clip = weapon:Clip1()
		local dataAmmo = weapon.ixItem and weapon.ixItem:GetData("ammo", 0) or "N/A"

		local invAmmo = 0
		local inventory = client:GetInventory("main")
		if inventory then
			for _, item in pairs(inventory:GetItems()) do
				if item.ammo and item.ammo:lower() == ammoName:lower() then
					local stackAmount = (item.GetValue and item:GetValue()) or item:GetData("stack") or item.ammoAmount or 30
					invAmmo = invAmmo + stackAmount
				end
			end
		end

		local msg = string.format("Weapon: %s | AmmoType: %s | Clip: %s | ItemDataAmmo: %s | EngineReserve: %d | Tracked: %d | InventoryTally: %d", 
			weapon:GetClass(), ammoName, tostring(clip), tostring(dataAmmo), currentAmmo, trackedAmmo, invAmmo)
		
		client:ChatPrint(msg)
		print(msg)
	end
})

-- ============================================================
-- Бутылка ближнего боя: SWEP wm_bottle при удаче ломается и сам меняется на
-- wm_bottle_broken (логика внутри SWEP-а, функция brokebottle). Синхронизируем
-- предмет в инвентаре по weapon.ixItem: источник (empty_glass_bottle или
-- wm_bottle) -> wm_bottle_broken, либо удаляем, если бутылка разлетелась
-- полностью. Это единственный способ получить "розочку".
-- ============================================================
if SERVER then
	local function HandleBottleGone(owner, item)
		if not IsValid(owner) or not owner:IsPlayer() or not owner:Alive() then return end

		-- Намеренное снятие и смерть выставляют equip=false — тогда ничего не делаем.
		if not item or not item.GetData or item:GetData("equip") ~= true then return end

		item:SetData("equip", false)
		item:Remove()

		-- Полное разбитие (без розочки) — бутылки просто больше нет.
		if not owner:HasWeapon("wm_bottle_broken") then return end

		-- Разбилась в розочку: выдаём соответствующий предмет, уже "в руках".
		local brokenWep = owner:GetWeapon("wm_bottle_broken")
		local instance = ix.Item:Instance("wm_bottle_broken")

		if not instance then return end

		if not owner:AddItem(instance) then
			ix.Item:Spawn(owner, nil, instance)
		end

		instance:SetData("equip", true)

		if IsValid(brokenWep) then
			brokenWep.ixItem = instance
			owner.carryWeapons = owner.carryWeapons or {}
			owner.carryWeapons[instance.weaponCategory or "melee"] = brokenWep
		end
	end

	hook.Add("WeaponEquip", "ixBottleBreakSync", function(weapon)
		if not IsValid(weapon) or weapon:GetClass() ~= "wm_bottle" then return end

		-- Ждём кадр, чтобы владелец и weapon.ixItem успели проставиться.
		timer.Simple(0, function()
			if not IsValid(weapon) then return end

			local owner = weapon:GetOwner()
			if not IsValid(owner) or not owner:IsPlayer() then return end

			weapon:CallOnRemove("ixBottleBreakSync", function(wep)
				local item = wep.ixItem

				-- Ждём, пока SWEP закончит ломаться (выдаст/не выдаст wm_bottle_broken).
				timer.Simple(0, function()
					HandleBottleGone(owner, item)
				end)
			end)
		end)
	end)
end
