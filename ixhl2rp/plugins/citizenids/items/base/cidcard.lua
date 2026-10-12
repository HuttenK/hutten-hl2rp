local Item=class("ItemIdentityDocument")
implements("ItemEquipable","ItemIdentityDocument")
Item=ix.meta.ItemIdentityDocument
Item.isIdentityDocument=true
Item.isKeycard=false
-- Only retained so papers left in the old slot can be moved out safely.
Item.equip_inv="cid"
Item.equip_slot=nil
Item.stackable=false
Item.max_stack=1
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


function Item:Init() end
function Item:CanEquip() return false end
function Item:GetDescription() return "Удостоверение личности. Владелец: "..self:GetData("name","Не указано") end
function Item:OnRegistered()
 self:AddData("portrait",{Transmit=ix.transmit.none})
 ix.meta.ItemEquipable.Init(self)
 self.functions.equip=nil
 self.category="Документы"; self.skin=19
 for _,key in ipairs({"name","number","birthDate","nationality","sex","issued","expires","authority"}) do
  self:AddData(key,{Transmit=ix.transmit.owner})
 end
 self.functions.inspectDocument={name="Осмотреть документ",icon="icon16/vcard.png",
  OnCanRun=function(item) return not IsValid(item:GetEntity()) end,
  OnRun=function(item) Schema:ShowIdentityDocument(item.player,item); return false end}
 self.functions.showDocument={name="Показать документ",icon="icon16/user.png",
  OnCanRun=function(item) return not IsValid(item:GetEntity()) end,
  OnRun=function(item)
   local target=item.player:GetEyeTraceNoCursor().Entity
   if IsValid(target) and target:IsPlayer() and target:GetPos():DistToSqr(item.player:GetPos())<=150^2 then
    Schema:ShowIdentityDocument(target,item,item.player)
   else item.player:Notify("Посмотрите на человека рядом.") end
   return false
  end}
 self.functions.devEdit={name="Редактировать (администратор)",icon="icon16/wrench.png",
  OnCanRun=function(item) return item.player:IsAdmin() end,
  OnRun=function(item) netstream.Start(item.player,"ixCitizenIDEdit",item:GetID(),item.data,false); return false end}
end
function Item:OnInstanced(created)
 if created then
  local n=Schema:ZeroNumber(generateCardNumber(self:GetID()),10)
  self:SetData("number",string.format("%s-%d",string.gsub(n,"^(%d%d)(%d%d%d%d)(%d%d%d%d)","%1-%2-%3"),n%97))
  self:SetData("issued",os.date("%d.%m.%Y")); self:SetData("authority","Регистрационная служба")
 end
 -- Retired cards may contain old links. Papers never retain electronic access.
 local legacy=self.data.access~=nil or self.data.datafileID~=nil or self.data.cid~=nil
 self.data.access=nil; self.data.datafileID=nil; self.data.cid=nil
 if legacy and SERVER then self:SetData("name",self:GetData("name","")) end
end
function Item:SetupCharacter(character)
 self:SetData("name",character:GetName())
 if not self:GetData("sex") then self:SetData("sex",character:GetGender()==GENDER_FEMALE and "Ж" or "М") end
end
function Item:OnEquipped() end
function Item:OnUnequipped() end
return Item
