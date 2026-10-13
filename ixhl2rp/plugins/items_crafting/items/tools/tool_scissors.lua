ITEM.name = "item.tool_scissors"
ITEM.description = "item.tool_scissors.desc"
ITEM.model = "models/cod/bo1/interrogation_room/p_int_surgical_clippers.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.cost = 15
ITEM.DurabilityCraft = 20

ITEM.combine = ITEM.combine or {}
ITEM.combine.breakx = {
	name = "Разорвать",
	OnRun = function(item, targetItem, items)
		if targetItem.IsEquipped and targetItem:IsEquipped() then
			return
		end

		local client = item.player
		
		targetItem:Remove()

		item:TakeDurability(10, client)

		if math.random(1, 100) < 51 then
			local new_item = ix.Item:Instance("mat_cloth")
			client:AddItem(new_item)
		end

		return
	end,
	OnCanRun = function(item, targetItem)
		if item == targetItem then
			return false
		end

		if targetItem.BreakDown then
			return targetItem.BreakDownType == "cloth"
		end
		
		return false
	end
}