local ItemClothMPF = class("ItemClothMPF")
implements("ItemClothArmor", "ItemClothMPF")

ItemClothMPF = ix.meta.ItemClothMPF
ItemClothMPF.model = "models/items/mpfequipment.mdl"
ItemClothMPF.equip_inv = 'torso'
ItemClothMPF.equip_slot = nil
ItemClothMPF.iconCam = {
	pos = Vector(-0.20621359348297, -84.556304931641, 423.92922973633),
	ang = Angle(78.628517150879, 90.203117370605, 0),
	fov = 3.2292894524527,
}
ItemClothMPF.isMPF = true
ItemClothMPF.rebelReplacement = {
	[GENDER_MALE] = "models/autonomous/eurasia_nemanus/metropolice/male_rebel.mdl",
	[GENDER_FEMALE] = "models/autonomous/eurasia_nemanus/metropolice/female_rebel.mdl"
}

local vector_origin = vector_origin or Vector()

function ItemClothMPF:Init()
	ix.meta.ItemClothArmor.Init(self)

	self.width = 2
	self.height = 2

	self.uniform = self.uniform or 0
	self.primaryVisor = self.primaryVisor or vector_origin
	self.secondaryVisor = self.secondaryVisor or vector_origin
	self.specialization = self.specialization or nil

	self.category = "item.category.clothing_mpf"

	self:AddData("armband", {
		Transmit = ix.transmit.owner,
	})

	self:AddData("captured", {
		Transmit = ix.transmit.owner,
	})

	self.functions.devEdit = {
		name = "item.mpf_devMakeCaptured",
		icon = "icon16/wrench.png",
		OnClick = function(item)

		end,
		OnRun = function(item)
			item:SetData("captured", true)

			return false
		end,
		OnCanRun = function(item)
			return item:GetData("captured", false) != true and (!item.player:IsCombine() or item.player:IsAdmin())
		end
	}
end

function ItemClothMPF:OnInstanced(isCreated)
	ix.meta.ItemClothArmor.OnInstanced(self, isCreated)

	if isCreated then
		self:SetData("armband", 0)
		self:SetData("captured", false)
	end
end

function ItemClothMPF:OnGetReplacement(client, char)
	if self:GetData("captured") == true then
		return self.rebelReplacement[char:GetGender()] or self.rebelReplacement[GENDER_MALE]
	else
		return self.genderReplacement[char:GetGender()] or self.genderReplacement[GENDER_MALE]
	end
end

local armbandRank = {
	[0] = "R",
	[1] = "i4",
	[2] = "i3",
	[3] = "i2",
	[4] = "i1",
	[5] = "RL",
	[6] = "RC",
	[7] = "OVERSEER",
	[8] = "OVERSEER",
	[9] = "SF"
}

function ItemClothMPF:UpdateMPF(client, armband)
	if client:Team() == FACTION_MPF then
		client:SetPrimaryVisorColor(self.primaryVisor)
		client:SetSecondaryVisorColor(self.secondaryVisor)

		local name = client:GetName()
		local format = "(c24%:).*(°.*)"
		local ranks = string.match(name, "c24%:(.*)°.*")

		if ranks then
			local a = string.Explode(":", ranks)
			local spec = Schema:GetPlayerCombineSpec(client)

			ranks = string.Replace(ranks, a[1], armbandRank[armband])

			if a[2] then
				if !self.specialization then
					ranks = string.Replace(ranks, ":"..a[2], "")
				else
					ranks = string.Replace(ranks, a[2], a[2] or self.specialization)
				end
			else
				ranks = ranks..(self.specialization and (":"..self.specialization) or "")
			end

			local newName = string.gsub(name, format, "%1"..ranks.."%2")

			client:GetCharacter():SetVar("oldName", name, true)
			client:GetCharacter():SetName(newName)
		end
	elseif client:IsCombine() and client:Team() != FACTION_MPF then
		client:SetPrimaryVisorColor(self.primaryVisor)
		client:SetSecondaryVisorColor(self.secondaryVisor)
	else
		client:SetPrimaryVisorColor(vector_origin)
		client:SetSecondaryVisorColor(vector_origin)
	end
end

function ItemClothMPF:OnEquipped(client)
	ix.meta.ItemClothArmor.OnEquipped(self, client)

	local armband = self:GetData("armband", 0)
	client:SetNWInt("sg_uniform", self.uniform)
	client:SetNWInt("sg_armband", armband)
	self:UpdateMPF(client, armband)

	local item = self
	timer.Simple(0, function()
		if not IsValid(client) then return end
		if not item:IsEquipped() then return end

		local char = client:GetCharacter()
		if not char then return end

		local model = item:OnGetReplacement(client, char)
		if model and model != "" then
			if client.char_outfit then
				client.char_outfit.isModelChangedByOutfit = true
			end
			client:SetModel(model)
		end

		client:SetSkin(item.uniform or 0)

		if item.bodyGroups then
			for k, v in pairs(item.bodyGroups) do
				client:SetBodygroup(k, v)
			end
		end
	end)
end

function ItemClothMPF:OnUnequipped(client)
	ix.meta.ItemClothArmor.OnUnequipped(self, client)

	local char = client:GetCharacter()
	if char then
		local baseModel = (client.char_outfit and client.char_outfit.model) or char:GetModel()
		if baseModel and baseModel != "" then
			if client.char_outfit then
				client.char_outfit.isModelChangedByOutfit = true
			end
			client:SetModel(baseModel)
		end
	end

	if self.bodyGroups then
		for k, _ in pairs(self.bodyGroups) do
			client:SetBodygroup(k, 0)
		end
	end

	client:SetSkin(0)
	client:SetNWInt("sg_uniform", 0)
	client:SetNWInt("sg_armband", 0)
	client:SetPrimaryVisorColor(vector_origin)
	client:SetSecondaryVisorColor(vector_origin)
end

local yellowClr = Color(255, 200, 50)
function ItemClothMPF:PopulateTooltip(tooltip)
	if self:GetData("captured") == true then
		local clr = ColorAlpha(yellowClr, 16)
		local s = tooltip:AddRowAfter("name", "captured")
		s:SetTextColor(yellowClr)
		s:SetFont("item.stats.bold2")
	    s:SetText(L("mpfCapturedInsignia"))
		s:SizeToContents()
		s.Paint = function(_, w, h)
			surface.SetDrawColor(clr)
			surface.DrawRect(0, 0, w, h)
		end
	end

	ix.meta.ItemClothArmor.PopulateTooltip(self, tooltip)
end

return ItemClothMPF
