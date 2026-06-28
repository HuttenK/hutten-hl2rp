ITEM.name = "item.empty_glass_bottle"
ITEM.description = "item.empty_glass_bottle.desc"
ITEM.model = "models/props_junk/garbage_glassbottle003a.mdl"
ITEM.width = 1
ITEM.height = 2
ITEM.volume = 500

-- Пустую бутылку можно взять в руку как импровизированное оружие ближнего боя.
-- Экипировка выдаёт SWEP wm_bottle напрямую — отдельный предмет не создаётся.
ITEM.class = "wm_bottle"
ITEM.weaponCategory = "melee"

function ITEM:IsEquipped()
	return self:GetData("equip") == true
end

function ITEM:WieldBottle(client)
	if !IsValid(client) then return end

	if client:HasWeapon(self.class) then
		client:StripWeapon(self.class)
	end

	local weapon = client:Give(self.class, true)

	if IsValid(weapon) then
		weapon.ixItem = self
		client:SelectWeapon(self.class)
		client:EmitSound("items/ammo_pickup.wav", 60)
		self:SetData("equip", true)
	else
		print(Format("[Helix] Cannot wield bottle - %s does not exist!", self.class))
	end
end

function ITEM:HolsterBottle(client)
	if IsValid(client) and client:HasWeapon(self.class) then
		client:StripWeapon(self.class)
	end

	self:SetData("equip", false)
end

ITEM.functions = ITEM.functions or {}

ITEM.functions.equip = {
	name = "Взять в руку",
	icon = "icon16/lightning.png",
	OnRun = function(item)
		item:WieldBottle(item.player)

		return false
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity) and !item:IsEquipped()
	end
}

ITEM.functions.unequip = {
	name = "Убрать",
	icon = "icon16/lightning_delete.png",
	OnRun = function(item)
		item:HolsterBottle(item.player)

		return false
	end,
	OnCanRun = function(item)
		return !IsValid(item.entity) and item:IsEquipped()
	end
}

-- Перевыдать SWEP при возрождении, если бутылка была в руках.
function ITEM:OnLoadout()
	if self:GetData("equip") then
		self:WieldBottle(self.player)
	end
end

function ITEM:OnDrop(client, inventory)
	local owner = inventory and inventory.owner

	if IsValid(owner) and self:GetData("equip") then
		self:HolsterBottle(owner)
	end
end

function ITEM:OnRemoved()
	local inventory = self.inventory_id and ix.Inventory:Get(self.inventory_id)
	local owner = inventory and inventory.GetOwner and inventory:GetOwner()

	if IsValid(owner) and owner:IsPlayer() and self:GetData("equip") then
		self:HolsterBottle(owner)
	end
end

if SERVER then
	-- Снять "экипировку" при смерти, чтобы бутылка не выдавалась снова при респавне.
	hook.Add("PlayerDeath", "ixGlassBottleUnequip", function(client)
		for _, v in ipairs(client:GetItems()) do
			if v.uniqueID == "empty_glass_bottle" and v:GetData("equip") then
				v:SetData("equip", false)
			end
		end
	end)
end
