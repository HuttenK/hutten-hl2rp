local Item = class("ItemKeycard")
implements("ItemEquipable", "ItemKeycard")

Item = ix.meta.ItemKeycard

Item.isKeycard = true
Item.equip_inv = 'cid'
Item.equip_slot = nil
Item.stackable = false
Item.max_stack = 1
Item.cardType = 0

CARDTYPE_NONE = 0
CARDTYPE_MED = 1
CARDTYPE_CWU = 2
CARDTYPE_UNION = 3
CARDTYPE_CITY = 4

local prime = 9999999787 -- prime % 4 = 3! DO NOT CHANGE EVER
local offset = 100000 -- slightly larger than sqrt(prime) is ok. DO NOT CHANGE EVER
local block = 100000000
local function generateCardNumber(id)
	id = (id + offset) % prime

	local cardNum = 0

	for _ = 1, math.floor(id/block) do
		cardNum = (cardNum + (id * block) % prime) % prime
	end

	cardNum = (cardNum + (id * (id % block) % prime)) % prime

	if (2 * id < prime) then
		return cardNum
	else
		return prime - cardNum
	end
end

function Item:GetDescription()
 if self.isKeycard then
  return "Фонд SCP / "..(self.departmentLabel or "").." / Уровень "..self.clearanceLevel..". Доступ только по служебной необходимости. Проверка — в терминале SCiPNet."
 end
 return "Удостоверение личности. Владелец: "..self:GetData("name","Не указано")
end

function Item:CanEquip(client) return self.isKeycard==true end

function Item:GetRarity()
	return self.cardType
end

function Item:Init() end

-- Item templates set their fields after Base(); configure actions at registration.
function Item:OnRegistered()
 self:AddData("portrait",{Transmit=ix.transmit.none})
	ix.meta.ItemEquipable.Init(self)
	self.combine=self.combine or {}
	self.combine.fieldlinkRegister={
		name="Зарегистрировать КПК по ключ-карте",
		OnCanRun=function(card,device)
			return card.isKeycard and device.uniqueID=="pda" and
				ix.Fieldlink and ix.Fieldlink.CardIdentity(card)~=nil or false
		end,
		OnRun=function(card,device)
			local plugin=ix.plugin.list.site_pda
			if plugin then plugin:RegisterPDA(card.player,device,card) end
			return false
		end
	}

	self.category = self.isKeycard and "Ключ-карты SCP" or "Документы"
 self.model="models/cultist/items/keycards/w_keycard.mdl"
 -- Skin comes from the concrete clearance card template.
 for _,key in ipairs({"issued","expires","authority","position","site","callsign","restrictions"}) do
  self:AddData(key,{Transmit=ix.transmit.owner})
 end

	self.functions.devEdit = {
		name = "Редактировать (администратор)",
		icon = "icon16/wrench.png",
		OnClick = function(item)
			
		end,
		OnRun = function(item)
			netstream.Start(item.player, "ixCitizenIDEdit", item:GetID(), item.data, item.isKeycard==true)
			return false
		end,
		OnCanRun = function(item)
			return item.player:IsAdmin()
		end
	}

	self:AddData("name", {
		Transmit = ix.transmit.owner,
	})

	self:AddData("cid", {
		Transmit = ix.transmit.owner,
	})

	self:AddData("number", {
		Transmit = ix.transmit.owner,
	})

	self:AddData("access", {
		Transmit = ix.transmit.owner,
	})

	self:AddData("datafileID", {
		Transmit = ix.transmit.owner,
	})
end

function Item:OnInstanced(isCreated)
	if isCreated then
        self:SetData("issued",os.date("%d.%m.%Y"))
        self:SetData("authority",self.isKeycard and "Фонд SCP / Бюро допуска персонала" or "Регистрационная служба")
        if self.isKeycard then self:SetData("site","Объект — не назначен"); self:SetData("restrictions","Доступ по служебной необходимости; передача запрещена") end
		local cardNumber = Schema:ZeroNumber(generateCardNumber(self:GetID()), 10)
		self:SetData("number", string.format("%s-%d",
			string.gsub(cardNumber, "^(%d%d)(%d%d%d%d)(%d%d%d%d)", "%1%-%2%-%3"),
			Schema:ZeroNumber(cardNumber % 97, 2)
		))

		self:SetData("access", self.access or {})
	end

	if self.isKeycard then hook.Run("OnIDCardInstanced", self) else self:SetData("access",{}) end
end

function Item:SetupCharacter(character)
	self:SetData("name", character:GetName())
	self:SetData("cid", "000-00")
	self:SetData("datafileID", character:GetID())
end

function Item:CreateDatafile(client)
	if IsValid(client) then
		local character = client:GetCharacter()

		self:SetData("name", character:GetName())
		self:SetData("cid", Schema:ZeroNumber(math.random(1, 99999), 5))

		hook.Run("OnIDCardUpdated", self)
	end
end

function Item:OnEquipped(client)
	if self.isKeycard then ix.Datafile:OnCardEquipped(client, self, true) end
end

function Item:OnUnequipped(client)
	if self.isKeycard then ix.Datafile:OnCardEquipped(client, self, false) end
end

if CLIENT then
 function Item:PopulateTooltip(tooltip)
  local row=tooltip:AddRowAfter("description","document")
  row:SetText("Номер документа: "..self:GetData("number","—"))
  row:SizeToContents()
 end
end

return Item
