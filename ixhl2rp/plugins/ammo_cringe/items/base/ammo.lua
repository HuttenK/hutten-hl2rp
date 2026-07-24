local ItemAmmo = class("ItemAmmo")
implements("ItemStackable", "ItemAmmo")

ItemAmmo = ix.meta.ItemAmmo
ItemAmmo.contraband = true

function ItemAmmo:Init()
	ix.meta.ItemStackable.Init(self)

	self.category = "item.category.ammo"
end

function ItemAmmo:OnInstanced(isCreated)
	-- Always sync max_stack to ammoAmount so the combine handler
	-- caps transfers correctly for this specific ammo type.
	self.max_stack = self.ammoAmount or 30

	if isCreated then
		-- Initialise the stack count to the full box size instead of
		-- ItemStackable's generic default_stack (16).
		self:SetData("stack", self.ammoAmount or 30)
	end
end

-- ВАЖНО: крафт (ixcraft, results-цикл) читает stackable_legacy и max_stack с
-- ОПРЕДЕЛЕНИЯ предмета (ix.Item:Get), а НЕ с инстанса. На определении эти поля
-- через классовую иерархию доходили ненадёжно → stackable_legacy оказывался
-- ложным, и крафт уходил в else-ветку, создавая `amount` отдельных предметов по
-- 1 патрону вместо стака. К тому же max_stack на определении оставался базовым
-- (32), из-за чего 90 патронов дробились бы на 32+32+26. OnRegistered вызывается
-- движком Helix (ITEM:Register) уже ПОСЛЕ того, как файл предмета выставил
-- ammoAmount — фиксируем оба поля прямо на определении, для всех типов патронов.
function ItemAmmo:OnRegistered()
	self.stackable_legacy = true
	self.max_stack = self.ammoAmount or 30
end

return ItemAmmo
