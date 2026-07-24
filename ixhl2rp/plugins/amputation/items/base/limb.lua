-- Отрезанная конечность. Её можно пришить обратно тому, кто её лишился —
-- нужен навык медицины 5 и та самая конечность (правую руку левой не заменить).
local ItemLimb = class("ItemLimb"):implements("Item")

ItemLimb = ix.meta.ItemLimb
ItemLimb.width = 1
ItemLimb.height = 2
ItemLimb.model = "models/gibs/hgibs.mdl"

function ItemLimb:Init()
	self.category = "item.category.medical"

	self.functions.reattach = {
		name = "amputation.reattach",
		icon = "icon16/user_add.png",
		OnRun = function(item)
			local client = item.player
			local character = client:GetCharacter()

			if !ix.Amputation.HasSkill(character) then
				client:NotifyLocalized("amputation.noSkill")
				return false
			end

			local target = ix.Amputation.GetTarget(client)

			if !IsValid(target) or !target:Alive() then
				client:NotifyLocalized("amputation.noTarget")
				return false
			end

			if client.ixAmputationBusy or target.ixAmputationBusy then
				client:NotifyLocalized("amputation.busy")
				return false
			end

			local key = ix.Amputation.Get(target:GetCharacter())

			if !key then
				client:NotifyLocalized("amputation.notMissing")
				return false
			end

			if key != item.limb then
				client:NotifyLocalized("amputation.wrongLimb")
				return false
			end

			ix.Amputation.BeginReattach(client, target, item)

			-- Предмет удаляется только после успешного завершения операции.
			return false
		end,
		OnCanRun = function(item)
			if IsValid(item:GetEntity()) then return false end

			local client = item.player

			return IsValid(client) and ix.Amputation.HasSkill(client:GetCharacter())
		end
	}
end

return ItemLimb
