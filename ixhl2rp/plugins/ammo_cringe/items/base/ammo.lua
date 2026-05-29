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

return ItemAmmo
