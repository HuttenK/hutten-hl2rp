ITEM.name = "item.flashlight"
ITEM.model = "models/cultist/items/flashlight/w_item_maglite.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.description = "item.flashlight.desc"

function ITEM:OnDrop(client)
	client:SetNWBool("ixFieldFlashlight", false)
	client:Flashlight(false)
end
