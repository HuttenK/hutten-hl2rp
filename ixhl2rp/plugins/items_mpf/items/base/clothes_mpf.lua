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
				-- Держим модель метрополиции «текущей» для системы одежды, иначе
				-- Outfit:Update откатит игрока на гражданскую модель при следующем
				-- обновлении (напр. при надевании шлема/брони на ноги). Базовую
				-- модель для снятия формы берём из char:GetModel() (см. OnUnequipped).
				client.char_outfit.model = model
			end
			client:SetModel(model)
		end

		client:SetSkin(item.uniform or 0)

		-- Метрополицейская модель имеет ненулевые дефолтные бодигруппы (напр. 3, 6, 7),
		-- а SetModel сбрасывает их к этим дефолтам. Обнуляем ВСЕ, затем накладываем
		-- только заданные формой — иначе форма даёт лишние бодигруппы поверх нужных.
		for i = 0, client:GetNumBodyGroups() - 1 do
			client:SetBodygroup(i, 0)
		end

		if item.bodyGroups then
			for k, v in pairs(item.bodyGroups) do
				client:SetBodygroup(k, v)
			end
		end

		-- Броня, надетая поверх формы, использует иные бодигруппы (bodyGroupsMPF),
		-- т.к. раскладка бодигрупп модели метрополиции отличается от гражданских.
		for _, armor in pairs(client:GetItems()) do
			if armor.bodyGroupsMPF and armor:IsEquipped() then
				for k, v in pairs(armor.bodyGroupsMPF) do
					client:SetBodygroup(k, v)
				end
			end
		end
	end)
end

function ItemClothMPF:OnUnequipped(client)
	ix.meta.ItemClothArmor.OnUnequipped(self, client)

	local char = client:GetCharacter()
	if char then
		-- Возвращаем базовую модель персонажа. char_outfit.model мог быть временно
		-- выставлен в модель метрополиции на время ношения формы (см. OnEquipped).
		local baseModel = char:GetModel()
		if baseModel and baseModel != "" then
			if client.char_outfit then
				client.char_outfit.isModelChangedByOutfit = true
				client.char_outfit.model = baseModel
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

	-- Модель сменилась обратно на гражданскую (SetModel сбросил бодигруппы к её
	-- дефолтам). Обновляем одежду, чтобы всё ещё надетая броня пересчитала свои
	-- гражданские бодигруппы на гражданской модели (иначе останутся MPF-значения).
	if client.char_outfit then
		client.char_outfit:Update()
	end
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
