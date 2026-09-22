local Item = class("ItemWeapon"):implements("Item")

Item.stackable = false 
Item.isWeapon = true
Item.useSound = 'items/ammo_pickup.wav'
Item.contraband = true
Item.canRename = true
Item.renameField = "customName"

-- Показываем пользовательское имя, если задано
function Item:GetName()
	local custom = self:GetData("customName", "")
	if custom and custom != "" then return custom end
	-- На сервере L() требует игрока (для логов небезопасно) — используем серверобезопасную l()
	return CLIENT and self:GetPrintName() or l(self.name)
end

-- Тултип/инвентарь показывают имя через GetPrintName, поэтому переопределяем именно его
function Item:GetPrintName()
	local custom = self:GetData("customName", "")
	if custom and custom != "" then return custom end

	if CLIENT then
		local ok, result = pcall(L, tostring(self.name or "unknown"))
		return ok and result or self.name
	end

	return self.name
end

function Item:IsEquipped()
	-- equip-данные — достоверный признак экипировки (синхронизируются owner-transmit).
	-- Раньше тут была привязка к self.inventory_type == 'main', но это поле на клиенте
	-- не выставляется приёмником item.sync для предметов в инвентаре, поэтому после
	-- ресинка (например при экипировке второго оружия) кнопка не переключалась на Unequip.
	return self:GetData('equip') == true
end

local function Write_Equip(item, value)
	net.WriteBool(value)
end

local function Read_Equip(item)
	return net.ReadBool(value)
end

local function Write_Ammo(item, value)
	net.WriteInt(value, 32)
end

local function Read_Ammo(item)
	return net.ReadInt(32)
end

local function Write_Durability(item, value)
	net.WriteUInt(value, 3)
end

local function Read_Durability(item)
	return net.ReadUInt(3)
end

function Item:Init()
	self.category = "item.category.weapon"

	self.class = self.class or "weapon_pistol"
	self.weaponCategory = self.weaponCategory or 'primary'
	self.durability = self.durability or 100
	self.hasLock = self.hasLock or false

	self.functions.equip = {
		tip = "equipTip",
		icon = "icon16/box.png",
		OnRun = function(item)
			-- Однорукий персонаж не удержит двуручное оружие — оно падает на землю.
			if ix.Amputation and ix.Amputation.IsTwoHanded(item) then
				local client = item.player

				if IsValid(client) and ix.Amputation.HasKind(client:GetCharacter(), "arm") then
					client:NotifyLocalized("amputation.noTwoHanded")

					return false
				end
			end

			if item.hasLock then
				local client = item.player
				if item:CheckBiolock(client) == false then
					local char = client:GetCharacter()
					local info = {severity = 5}
					char:Health():AddHediff("sparkburn", HITGROUP_LEFTARM, info)
					char:Health():AddHediff("sparkburn", HITGROUP_RIGHTARM, info)

					client:EmitSound("weapons/stunstick/alyx_stunner1.wav")

					ix.Item:DropItem(client, item.id)

					return false
				end
			end
			item:Equip(item.player)
		end,
		OnCanRun = function(item)
			if IsValid(item:GetEntity()) then
				return false
			end

			local client = item.player

			if item.inventory_id then
				local inv = ix.Inventory:Get(item.inventory_id)

				if inv and inv.type != "main" and inv.owner != client then -- cannot equip weapon outside
					return false
				elseif inv and inv.type == "main" and inv.owner != client then -- cannot equip weapon outside
					return false
				end
			end

			return IsValid(client) and !item:IsEquipped()
		end
	}

	-- Ампутация: подменю на 4 конечности. Показывается только у подходящих
	-- клинков и только хирургу с медициной 5. Жертва подтверждает согласие.
	self.functions.amputate = {
		name = "amputation.cut",
		icon = "icon16/cut.png",
		isMulti = true,
		multiOptions = function(item)
			local options = {}

			for _, key in ipairs({"larm", "rarm", "lleg", "rleg"}) do
				options[#options + 1] = {
					name = ix.Amputation.limbs[key].phrase,
					data = {limb = key}
				}
			end

			return options
		end,
		OnRun = function(item, items, data)
			local client = item.player
			local key = data and data.limb

			if !key or !ix.Amputation.limbs[key] then return false end

			if !ix.Amputation.HasSkill(client:GetCharacter()) then
				client:NotifyLocalized("amputation.noSkill")
				return false
			end

			local target = ix.Amputation.GetTarget(client)

			if !IsValid(target) or !target:Alive() then
				client:NotifyLocalized("amputation.noTarget")
				return false
			end

			if ix.Amputation.Get(target:GetCharacter()) then
				client:NotifyLocalized("amputation.targetHasLimb")
				return false
			end

			ix.Amputation.RequestCut(client, target, key, item)

			return false
		end,
		OnCanRun = function(item)
			if IsValid(item:GetEntity()) then return false end
			if !ix.Amputation or !ix.Amputation.IsTool(item) then return false end

			local client = item.player

			return IsValid(client) and ix.Amputation.HasSkill(client:GetCharacter())
		end
	}

	self.functions.unequip = {
		tip = "unequipTip",
		icon = "icon16/box.png",
		OnRun = function(item)
			item:Unequip(item.player, true)
		end,
		OnCanRun = function(item)
			local client = item.player

			return not IsValid(item:GetEntity()) and IsValid(client) and item:IsEquipped()
		end
	}

	self.functions.unloadMagazine = {
		name = "weapon.unloadMagazine",
		icon = "icon16/page_go.png",
		OnRun = function(item)
			for _, pair in ipairs({{"ammo", "ammoType"}, {"ammo2", "ammoType2"}}) do
				local count = item:GetData(pair[1], 0)
				local ammo = item:GetData(pair[2])
				if not ammo and pair[1] == "ammo" then
					local definition = weapons.Get(item.class) or {}
					ammo = definition.Ammo or (definition.Primary or {}).Ammo
				end
				if count > 0 and ix.arc9Inventory.ReturnAmmo(item.player, ammo, count) then item:SetData(pair[1], 0) end
			end
			return false
		end,
		OnCanRun = function(item)
			return not item:IsEquipped() and (item:GetData("ammo", 0) > 0 or item:GetData("ammo2", 0) > 0)
		end
	}

	self.functions.examine = {
		tip = "examineTip",
		OnRun = function(item)
			item.player:ChatNotifyLocalized("weaponSerialNumber", item:GetData("regid"))
		end,
		OnCanRun = function(item)
			return true
		end
	}

	-- Гарантируем флаги на самом инстансе (база — класс, наследование полей ненадёжно)
	self.canRename = true
	self.renameField = "customName"

	self.functions.rename = {
		name = "Переименовать",
		icon = "icon16/textfield_rename.png",
		OnClick = function(item)
			Derma_StringRequest("Переименование оружия", "Введите название:", item:GetData("customName", ""),
				function(text)
					netstream.Start("ixItemRename", item.id, text)
				end)
			return false
		end,
		OnRun = function(item) return false end,
		OnCanRun = function(item)
			-- Переименование оружия — только администрация (пункт скрыт у остальных).
			local ply = item.player or (CLIENT and LocalPlayer())
			return !IsValid(item.entity) and IsValid(ply) and ply:IsAdmin()
		end
	}

	self:AddData("equip", {
		Transmit = ix.transmit.owner,
		Write = Write_Equip,
		Read = Read_Equip
	})

	self:AddData("ammo", {
		Transmit = ix.transmit.owner,
		Write = Write_Ammo,
		Read = Read_Ammo
	})

	self:AddData("regid", {
		Transmit = ix.transmit.none,
	})

	self:AddData("customName", {
		Transmit = ix.transmit.all,
		Write = function(item, value) net.WriteString(value or "") end,
		Read = function(item) return net.ReadString() end,
	})

	self:AddData("locked", {
		Transmit = ix.transmit.none,
	})

	self:AddData("value", {
		Transmit = ix.transmit.none,
	})

	self:AddData("durability", {
		Transmit = ix.transmit.all,
		Write = Write_Durability,
		Read = Read_Durability
	})

	-- Registered in both realms to keep item-data indexes identical.
	self:AddData("arc9_atts", {Transmit = ix.transmit.all})
	self:AddData("ammoType", {Transmit = ix.transmit.none})
	self:AddData("ammoType2", {Transmit = ix.transmit.none})
	self:AddData("ammo2", {Transmit = ix.transmit.owner, Write = Write_Ammo, Read = Read_Ammo})
	self:AddData("arc9Spent", {Transmit = ix.transmit.none})

end

function Item:CheckBiolock(client)
	local lockedBy = self:GetData("locked")

	if client:IsOTA() then
		return true
	end

	if !lockedBy or (lockedBy and lockedBy == client:GetCharacter():GetID()) then
		return true
	end

	return false
end

function Item:AddDurability(x)
	local value = self:GetData("value", 0)
	local newValue = math.Clamp(value + x, 0, self.durability)

	self:SetData("value", newValue)

	local delta = (newValue / self.durability)

	if !self.lastDurability then
		self.lastDurability = delta
	end

	local newDelta = math.abs(self.lastDurability - delta)
	if newDelta >= 0.2 or newDelta < 0 then
		self:SetData("durability", math.min(math.floor(5 * delta), 4))
		self.lastDurability = delta
	end

	if delta <= 0 then
		self:SetData("durability", 5)
		self:OnRemoved()

		return true
	end

	return false
end

function Item:OnInstanced(isCreated)
	if isCreated then
		self:SetData("value", self.durability)
		self:SetData("durability", 4)
		self:SetData("regid", string.format("%s-%d", string.gsub(os.time(), "^(%d%d%d%d%d)(%d%d%d%d%d)", "%1:%2"), self.id))
	end

	if !self:GetData("durability") then
		self:OnInstanced(true)
	end
end

function Item:Equip(client, bNoSelect, bNoSound)
	if not IsValid(client) or not client:GetCharacter() then return false end
	if self:GetData("arc9Spent") then client:Notify("Эта граната уже использована.") return false end
	if not ix.arc9Inventory.IsClass(self.class) then
		client:Notify("Требуется установленное оружие ARC9. Класс предмета: " .. tostring(self.class))
		return false
	end
	client.carryWeapons = client.carryWeapons or {}
	for _, other in pairs(client:GetItems()) do
		if other.id ~= self.id and other.isWeapon and other.weaponCategory == self.weaponCategory and other:GetData("equip") then
			client:NotifyLocalized("weaponSlotFilled", self.weaponCategory)
			return false
		end
	end
	-- Never silently destroy an unlinked weapon and its ammunition.
	local existing = client:GetWeapon(self.class)
	if IsValid(existing) then
		if existing.ixItem == self then return true end
		client:Notify("У вас уже есть оружие этого класса. Сначала уберите его.")
		return false
	end
	local weapon = client:Give(self.class, true)
	if not IsValid(weapon) then
		client:Notify("Не удалось выдать " .. tostring(self.class) .. ". Проверьте серверную консоль.")
		return false
	end
	if self.hasLock and not self:GetData("locked") then self:SetData("locked", client:GetCharacter():GetID()) end
	if not ix.arc9Inventory.Bind(self, weapon, client) then
		weapon.ixItem = nil
		weapon:Remove()
		client:CalculateAmmo()
		return false
	end
	client.carryWeapons[self.weaponCategory] = weapon
	self:SetData("equip", true)
	if not bNoSelect then client:SelectWeapon(self.class) end
	if not bNoSound then client:EmitSound(self.useSound, 80) end
	return true
end

-- Запоминает тип и оба магазина с живого экземпляра ARC9.
function Item:SaveLoadedAmmoType(weapon)
	ix.arc9Inventory.Save(self, weapon)
end

function Item:Unequip(user, bPlaySound, bRemoveItem, previousOwner)
	local client = previousOwner or self:GetOwner()
	if not IsValid(client) then return end
	local weapon = client:GetWeapon(self.class)
	if IsValid(weapon) and weapon.ixItem == self then
		if weapon.CancelReload then weapon:CancelReload() end
		if ix.arc9Inventory.Settle then ix.arc9Inventory.Settle(client) end
		ix.arc9Inventory.Save(self, weapon)
		weapon.ixItem = nil
		client.ixAmmoReady = false
		client:StripWeapon(self.class)
	end
	client.carryWeapons = client.carryWeapons or {}
	client.carryWeapons[self.weaponCategory] = nil
	self:SetData("equip", false)
	client:CalculateAmmo()
	if bPlaySound then client:EmitSound(self.useSound, 80) end
	if bRemoveItem then self:Remove() end
end

function Item:CanTransfer(oldInventory, newInventory, x, y)
	if newInventory and self:GetData("equip") then
		local owner = self:GetOwner()

		if IsValid(owner) then
			owner:NotifyLocalized("equippedWeapon")
		end

		return false
	end

	return true
end

function Item:OnDrop(client, inventory)
	if self:GetData("equip") and inventory then self:Unequip(client, true, false, inventory.owner) end
end

function Item:OnLoadout()
	if self:GetData("equip") then
		if not self:Equip(self.player, true, true) then self:SetData("equip", false) end
	end
end

function Item:OnSave()
	local inventory = ix.Inventory:Get(self.inventory_id)
	
	if !inventory then
		return
	end
	
	local owner = inventory.GetOwner and inventory:GetOwner()

	if IsValid(owner) and owner:IsPlayer() then
		owner.carryWeapons = owner.carryWeapons or {}
		local weapon = owner:GetWeapon(self.class)

		if IsValid(weapon) and weapon.ixItem == self and self:GetData("equip") then
			self:SaveLoadedAmmoType(weapon)
			-- Clip state is saved together by SaveLoadedAmmoType.
		end
	end
end

function Item:OnRemoved()
	local inventory = ix.Inventory:Get(self.inventory_id)
	
	if !inventory then
		return
	end
	
	local owner = inventory.GetOwner and inventory:GetOwner()
	local wasEquipped = self:GetData("equip")
	
	self:SetData("equip", false)

	if IsValid(owner) and owner:IsPlayer() then
		owner.carryWeapons = owner.carryWeapons or {}
		if wasEquipped then
			owner.carryWeapons[self.weaponCategory] = nil
		end

		local weapon = owner:GetWeapon(self.class)

		if IsValid(weapon) and weapon.ixItem == self then
			ix.arc9Inventory.Settle(owner)
			owner.ixAmmoReady = false
			weapon:Remove()
			owner:CalculateAmmo()
		end
	end
end

if CLIENT then
	local durability_state = {
		[0] = {"weaponConditionFaulty", 0.15},
		[1] = {"weaponConditionHeavyWear", 0.25},
		[2] = {"weaponConditionMediumWear", 0.4},
		[3] = {"weaponConditionLightWear", 0.6},
		[4] = {"weaponConditionNew", 0.9},
		[5] = {"weaponConditionBroken", 0}
	}

	local greenClr = Color(50, 200, 50)
	local yellowClr = Color(255, 200, 50)
	local redClr = Color(200, 50, 50)

	local function StatRow(id, text, color, tooltip, bold, bol2)
		local clr = ColorAlpha(color, bold and 40 or 16)
		local s = tooltip:AddRow(id)
		s:SetTextColor(color)
		s:SetFont(bold and (bol2 and "item.stats.bold2" or "item.stats.bold") or "item.stats")
		s:SetText(text)
		s:SizeToContents()
		s.Paint = function(_, w, h)
			surface.SetDrawColor(clr)
			surface.DrawRect(0, 0, w, h)
		end

		return s
	end

	local function ScaleHitChanceByHandsDamage(character)
		local leftHandDamage, rightHandDamage = character:GetLimbDamage(HITGROUP_LEFTARM, true), character:GetLimbDamage(HITGROUP_RIGHTARM, true)

		if (leftHandDamage > 0 or rightHandDamage > 0) then
			return (1 - ((leftHandDamage * 0.5) + (rightHandDamage * 0.5)))
		end

		return 1
	end

	local penetration = L("weaponArmorPenetrationHeader")
	local redClr = Color(200, 50, 50)
	function Item:PopulateTooltip(tooltip)
		if self.isGrenadeARC9 or self.isGrenade then
			return
		end

		local hasLock = self.hasLock
		
		if hasLock then
			local lock = tooltip:AddRowAfter("name", "lock")
			lock:SetText(L("weaponHasBiolock"))
			lock:SetBackgroundColor(redClr)
			lock:SizeToContents()
		end

		local durability = self:GetData("durability")

		if durability then
			local info = durability_state[durability]
			local panel = tooltip:AddRowAfter(hasLock and "lock" or "name", "durability")
			panel:SetBackgroundColor(HSVToColor(120 * info[2], 1, 1))
			panel:SetText(L("weaponConditionLabel", L(info[1])))
			panel:SizeToContents()
		end

		local weapon = weapons.GetStored(self.class)
		if weapon then
			local character = LocalPlayer():GetCharacter()
			local isMelee = weapon.PrimaryBash and (weapon.ClipSize or 0) <= 0
			local primary = weapon.Primary or {}
			local damage = weapon.DamageMax or primary.Damage or weapon.BashDamage or 0

			if weapon.Num then
				damage = damage * weapon.Num
			end

			-- Melee weapons store their schema-controlled damage in Info.Damage
			-- (the SWEP's own Primary.Damage is 0), so show that range instead.
			if istable(self.Info) and istable(self.Info.Damage) then
				StatRow("base", L("weaponStatDamage", self.Info.Damage[1]) .. " – " .. (self.Info.Damage[2] or self.Info.Damage[1]), color_white, tooltip, true)
			else
				StatRow("base", L("weaponStatDamage", damage), color_white, tooltip, true)
			end

			-- Melee weapons: show the real damage type (slash bleeds, club bruises).
			if istable(self.Info) and self.Info.Class then
				local typeText = (self.Info.Class == "club") and L("weaponDamageTypeClub") or L("weaponDamageTypeSlash")
				StatRow("dmgtype", L("weaponStatDamageType", typeText), color_white, tooltip, true)
			end

			if weapon.RPM and !isMelee then
				StatRow("rpm", L("weaponStatRPM", weapon.RPM), color_white, tooltip, true)
			elseif weapon.RPM and isMelee then
				StatRow("attackspeed", L("weaponStatAttackSpeed", math.Round(weapon.RPM / 60, 1)), color_white, tooltip, true)
			end

			if weapon.armor then
				if weapon.armor.penetration then
					StatRow("penetration", penetration, greenClr, tooltip, true)

					local coverages = {}
					for k, v in pairs(weapon.armor.penetration) do
						coverages[#coverages + 1] = {factor = (1 - v) * 100, type = k}
					end

					table.SortByMember(coverages, "type")

					for k, v in ipairs(coverages) do
						StatRow("hit"..k, L("weaponArmorClassLine", v.type, (v.factor > 0 and "+" or "")..v.factor), v.factor > 0 and greenClr or redClr, tooltip)
					end
				end
			end
		end

	end

	function Item:PaintOver(w, h)
		if self:GetData("equip") then
			surface.SetDrawColor(110, 255, 110, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end

		if self.isGrenadeARC9 or self.isGrenade then
			return
		end
		
		local durability = self:GetData("durability")

		if durability then
			local info = durability_state[durability]
			local clr = HSVToColor(120 * info[2], 0.75, 1)

			surface.SetDrawColor(35, 35, 35, 225)
			surface.DrawRect(2, 2, 6, h - 4)

			if durability > 4 then
				durability = 4
			elseif durability == 0 then
				durability = 0.4
			end

			local filledWidth = (h - 6) * (durability / 4)

			surface.SetDrawColor(clr)
			surface.DrawRect(3, math.ceil(h - filledWidth - 3), 4, filledWidth)
		end
	end
end

hook.Add("PlayerDeath", "ixStripClip", function(client)
	client.carryWeapons = {}

	for _, v in pairs(client:GetItems()) do
		if (v.isWeapon and v:GetData("equip")) then
			v:SetData("ammo", 0)
			v:SetData("ammo2", 0)
			v:SetData("equip", false)
		end
	end
end)

return Item
