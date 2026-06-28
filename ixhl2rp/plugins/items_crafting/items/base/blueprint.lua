local Item = class("ItemBlueprint"):implements("Item")

Item.name = "item.blueprint"
Item.description = "item.blueprint.desc"
Item.category = "item.category.misc"
Item.model = "models/props_lab/binderbluelabel.mdl"
Item.width = 1
Item.height = 1
Item.rarity = 2
Item.stackable = false

-- Child items set ITEM.recipe to the recipe uniqueID this schematic teaches.

function Item:Init()
	self.functions = self.functions or {}

	self.functions.Learn = {
		name = "blueprint.learn",
		icon = "icon16/book_open.png",
		OnRun = function(item)
			local client = item.player
			local character = IsValid(client) and client:GetCharacter()
			local recipeID = item.recipe

			if !character or !recipeID or !(ix.Craft and ix.Craft.recipes[recipeID]) then
				return false
			end

			local learned = character:GetData("craftLearned", {})

			if learned[recipeID] then
				client:NotifyLocalized("blueprint.alreadyKnown")
				return false
			end

			learned[recipeID] = true
			character:SetData("craftLearned", learned)

			client:NotifyLocalized("blueprint.learned", L(ix.Craft.recipes[recipeID].name, client))
			item:Remove()

			return false
		end,
		OnCanRun = function(item)
			return item.recipe != nil and !IsValid(item:GetEntity())
		end
	}
end

return Item
