//ix.util.Include("equipable.lua", "shared")

local ItemCloth = class("ItemCloth")
implements("ItemEquipable", "ItemCloth")

ItemCloth = ix.meta.ItemCloth
ItemCloth.category = 'Clothes'

-- Maps equip_inv slot names to ix.Appearance.Slot values.
-- Custom values (>=10) are used for slots not in the default Appearance.Slot table.
--
-- NOTE: torso and legs intentionally use custom slots 13/14 instead of the
-- standard Appearance.Slot.Torso (2) / Appearance.Slot.Legs (3).
-- The framework's default SlotEffects for slots 2 and 3 attach bodyMasks
-- ("Torso" and "Legs") that force extra bodygroups on the player model —
-- e.g. "Legs" sets [3]=1 and [5]=1, which visibly changes the Neck and Torso
-- bodygroups on civilian models even when only pants are equipped.
-- Using slots 13/14 avoids those SlotEffects while preserving per-slot
-- collision detection (one item per slot number).
local EQUIP_INV_TO_APPEARANCE_SLOT = {
	head      = 1,  -- ix.Appearance.Slot.Head  (no SlotEffect)
	torso     = 13, -- custom: avoids Torso SlotEffect bodyMask
	legs      = 14, -- custom: avoids Legs  SlotEffect bodyMask
	boots     = 4,  -- ix.Appearance.Slot.Boots    (no SlotEffect)
	socks     = 5,  -- ix.Appearance.Slot.Socks    (no SlotEffect)
	backpack  = 6,  -- ix.Appearance.Slot.Backpack (no SlotEffect)
	suit      = 7,  -- ix.Appearance.Slot.Suit     (SlotEffect intentional here)
	mask      = 10, -- custom: face masks / gasmasks / glasses
	hands     = 11, -- equip_inv 'hands' (gloves)
	gloves    = 11, -- alias
	belt      = 12, -- custom: belts

	-- Броня носится поверх одежды, поэтому у неё собственные слоты Appearance:
	-- иначе бронежилет вытеснил бы рубашку (13), а поножи — штаны (14).
	vest           = 15, -- equip_inv 'vest' (бронежилеты)
	legprotection  = 16, -- equip_inv 'legprotection' (защита ног)

	-- Очки носятся отдельным слотом от 'mask' (маски/противогазы), поэтому у них
	-- собственный Appearance-слот: иначе очки вытесняли бы маску и наоборот.
	glasses        = 17, -- equip_inv 'glasses' (очки)
}

function ItemCloth:Init()
	ix.meta.ItemEquipable.Init(self)

	self.category = "item.category.clothing"

	self:AddData("filter", {
		Transmit = ix.transmit.none,
	})

	-- Fix: the base equipable.lua OnRun ignores the return value of Transfer.
	-- When the target equip slot is already occupied, CanTransfer returns false
	-- and Transfer returns (false, "notAllowed"), but the base code still calls
	-- SendDeltaTransfer unconditionally.  That net message tells the client the
	-- item was moved from the main inventory to the equip inventory; the client
	-- removes it from the main grid but cannot place it in the occupied slot, so
	-- the item appears to "disappear".
	-- Override here to call SendDeltaTransfer only when Transfer succeeds.
	local itemSelf = self
	self.functions.equip.OnRun = function(item)
		local inventory = item.player:GetInventory(itemSelf.equip_inv)
		if not inventory then return end

		local x, y
		if itemSelf.equip_slot then
			x = 1
			y = itemSelf:GetEquipmentSlot(itemSelf.equip_slot)
		end

		if IsValid(item.entity) then
			-- Item is a world entity being picked up directly into equip slot.
			local bSuccess, err = inventory:AddItem(item, x, y)
			if bSuccess then
				item.entity:Delete()
				inventory:SendDeltaAdd(item.id)
				item:Equip(item.player, bSuccess)
			else
				item.player:NotifyLocalized(err or "unknownError")
			end
			return bSuccess
		else
			if not itemSelf:IsEquipped() then
				local old_inventory = ix.Inventory:Get(item.inventory_id)
				if not old_inventory then return end

				local old_x, old_y = item.x, item.y
				local old_w, old_h = old_inventory:GetItemSize(item)

				local bSuccess, reason = old_inventory:Transfer(item.id, inventory, x, y, false)
				if bSuccess then
					-- Only notify the client that the item moved when it actually did.
					inventory:SendDeltaTransfer(item.id, old_inventory, old_x, old_y, old_w, old_h)
				else
					-- Transfer failed (slot occupied or other reason).
					-- Do NOT call SendDeltaTransfer — client inventory state is still
					-- correct and the item remains visible in the main inventory.
					old_inventory:SyncTo(item.player)
				end
			end
		end
	end
end

function ItemCloth:OnEquipped(client)
	local model = false
	local char = client:GetCharacter()

	if isfunction(self.OnGetReplacement) then
		model = self:OnGetReplacement(client, char)
	elseif (self.replacement or self.replacements) then
		if (istable(self.replacements)) then
			if (#self.replacements == 2 and isstring(self.replacements[1])) then
				model = client:GetModel():gsub(self.replacements[1], self.replacements[2])
			else
				for _, v in ipairs(self.replacements) do
					model = client:GetModel():gsub(v[1], v[2])
				end
			end
		else
			model = self.replacement or self.replacements
		end
	elseif (self.genderReplacement) then
		model = self.genderReplacement[char:GetGender()] or self.genderReplacement[GENDER_MALE]
	end

	local bodyGroups = (self.bodyGroups or {})

	if self.GetOutfitBodyGroups then
		bodyGroups = self:GetOutfitBodyGroups(client)
	end

	client.char_outfit:AddItem(self, model, bodyGroups)
	client.char_outfit:Update()

	if self.isGasmask then
		client.char_outfit.gasmask = self
	end

	if self.skinGroups then
		for k, v in pairs(self.skinGroups or {}) do
			client:SetNWInt("sg_"..k, v)
		end
	end
end

function ItemCloth:OnUnequipped(client)
	client.char_outfit:RemoveItem(self)
	client.char_outfit:Update()

	if self.isGasmask then
		client.char_outfit.gasmask = nil
	end

	if self.skinGroups then
		for k, v in pairs(self.skinGroups or {}) do
			client:SetNWInt("sg_"..k, 0)
		end
	end
end

function ItemCloth:OnRegistered()
	local id = #ix.outfits + 1

	if isfunction(self.GetOutfitData) then
		ix.outfits[id] = self:GetOutfitData()

		self.outfit_id = id
	end

	-- Auto-register with ix.Appearance system for items that have bodyGroups
	-- but were not manually given a displayID. This allows Outfit:Update() to
	-- apply the bodygroup changes through the new appearance pipeline.
	if not self.displayID and self.bodyGroups and next(self.bodyGroups) then
		local slot = EQUIP_INV_TO_APPEARANCE_SLOT[self.equip_inv] or ix.Appearance.Slot.Torso
		local info = {
			slot       = slot,
			bodyGroups = self.bodyGroups,
			layer      = ix.Appearance.Layer.Main,
		}

		-- Characters wearing an MPF uniform use the metropolice model
		-- (Appearance modelClass "mpf"), whose bodygroup layout differs from
		-- citizen models. If the item defines bodyGroupsMPF, expose it as an
		-- "mpf" variant so Outfit:Update applies those indices on a uniformed
		-- character instead of the citizen bodygroups (and never clobbers them).
		if self.bodyGroupsMPF and next(self.bodyGroupsMPF) then
			info.variants = {
				mpf = { bodyGroups = self.bodyGroupsMPF }
			}
		end

		-- То же самое для формы ополчения (модели conscript, modelClass "militia",
		-- регистрируются в items_clothing/sh_plugin.lua).
		-- ВАЖНО: проверяем istable, а НЕ next() — пустая таблица здесь осмысленна и
		-- означает «на этой модели предмет не даёт бодигрупп вообще». Без явного
		-- пустого варианта Outfit:Update откатился бы на базовые (гражданские)
		-- bodyGroups, т.к. resolve выглядит как variants[modelClass] or displayInfo.
		if istable(self.bodyGroupsMilitia) then
			info.variants = info.variants or {}
			info.variants.militia = { bodyGroups = self.bodyGroupsMilitia }
		end

		self.displayID = ix.Appearance:New(self.uniqueID, info)
	end
end

return ItemCloth
