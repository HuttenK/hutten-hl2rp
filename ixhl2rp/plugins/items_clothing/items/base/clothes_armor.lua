if !ix.meta.ItemCloth then
	ix.util.Include("clothes.lua", "shared")
end

local ItemArmor = class("ItemClothArmor")
implements("ItemCloth", "ItemClothArmor")

ItemArmor = ix.meta.ItemClothArmor

function ItemArmor:Init()
	ix.meta.ItemCloth.Init(self)

	self.category = "item.category.clothing_armor"

	self:AddData("value", {
		Transmit = ix.transmit.owner,
	})
end

function ItemArmor:OnInstanced(isCreated)
	if isCreated or !self:GetData("value") then
		self:SetData("value", 1)
	end
end

function ItemArmor:CanEquip(player)
	player = player or self.player

	if self.gender then
		if IsValid(player) and player:GetCharacter():GetGender() != self.gender then
			return false
		end
	end


	return true
end

function ItemArmor:OnEquipped(client)
	ix.meta.ItemCloth.OnEquipped(self, client)

	client.char_outfit.armor[self] = true

	-- Бронежилеты переехали из слота 'torso' в 'vest', но замедление вешает
	-- только нагрудная броня — оба имени слота оставлены для совместимости.
	if self.equip_inv == 'vest' or self.equip_inv == 'torso' then
		if self.armor then
			if self.armor.class == 2 then
				client:SetNWFloat("speed_debuff", 0.85)
			elseif self.armor.class == 3 then
				client:SetNWFloat("speed_debuff", 0.7)
			end
		end
	end
end

function ItemArmor:OnUnequipped(client)
	ix.meta.ItemCloth.OnUnequipped(self, client)

	if client.char_outfit.armor[self] then
		client.char_outfit.armor[self] = nil
	end
	
	if self.equip_inv == 'vest' or self.equip_inv == 'torso' then
		if self.armor then
			client:SetNWFloat("speed_debuff", 1)
		end
	end
end

if CLIENT then
	surface.CreateFont("item.stats", {
		font = "Tahoma",
		size = math.max(ix.UI.Scale(13), 14),
		extended = true,
		weight = 500
	})
	surface.CreateFont("item.stats.bold2", {
		font = "Tahoma",
		size = math.max(ix.UI.Scale(15), 14),
		extended = true,
		weight = 500
	})

	surface.CreateFont("item.stats.bold", {
		font = "Tahoma",
		size = math.max(ix.UI.Scale(17), 17),
		extended = true,
		weight = 500
	})

	function ItemArmor:PaintOver(w, h)
		if self.armor then
			StatRow("armor", L("armorClass", self.armor.class), color_white, tooltip, true)

			if self.armor.density then
				StatRow("density", L("armorFactor", 100 * self.armor.density), color_white, tooltip, true, true)
			end

			if self.inventory_id then
				StatRow("durability", L("armorDurability", (self:GetData("value") or 1) * self.armor.max_durability, self.armor.max_durability), color_white, tooltip, true, true)
			end
			
			if self.armor.coverage then
				StatRow("coverage", L("armorCoverage"), yellowClr, tooltip, true, true)

				local coverages = {}
				for k, v in pairs(self.armor.coverage) do
					if hit_groups[k] then
						coverages[#coverages + 1] = {factor = 100 * v, type = hit_groups[k]}
					end
				end

				table.SortByMember(coverages, "factor")

				for k, v in ipairs(coverages) do
					StatRow("hit"..k, L(v.type, v.factor), yellowClr, tooltip)
				end
			end

			if self.armor.damage then
				StatRow("damage", L("armorDamage"), greenClr, tooltip, true, true)

				local damages = {}
				for k, v in pairs(self.armor.damage) do
					if damage_types[k] then
						local factor = (1 - v)
						if factor == 0 then continue end

						damages[#damages + 1] = {factor = factor, type = damage_types[k]}
					end
				end

				table.SortByMember(damages, "factor")

				for k, v in ipairs(damages) do
					StatRow("dmg"..k, L("armorDamageText", (v.factor > 0 and "+" or "")..tostring(100 * v.factor), L(v.type)), v.factor > 0 and greenClr or redClr, tooltip)
				end
			end

			if self.armor.penetration then
				StatRow("penetration", L("armorPenetration"), greenClr, tooltip, true, true)

				local damages = {}
				for k, v in pairs(self.armor.penetration) do
					if damage_types[k] then
						local factor = (1 * v)
						if factor == 1 then continue end

						damages[#damages + 1] = {factor = factor, type = damage_types[k]}
					end
				end

				table.SortByMember(damages, "factor")

				for k, v in ipairs(damages) do
					StatRow("dmgx"..k, L("armorDamageText", tostring(100 * v.factor), L(v.type)), v.factor > 1 and redClr or greenClr, tooltip)
				end
			end
		end
	end
end

return ItemArmor