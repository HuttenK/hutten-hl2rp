ITEM.name = "КПК FIELDLINK"
ITEM.description = "Полевой терминал. Активируйте в инвентаре, выберите КПК в списке оружия и удерживайте R, чтобы поднять или опустить его."
ITEM.model = "models/v_item_pda.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Устройства"
ITEM.functions = ITEM.functions or {}
function ITEM:OnRegistered()
 self:AddData("fieldlinkIdentity",{Transmit=ix.transmit.owner})
 self:AddData("fieldlinkNotes",{Transmit=ix.transmit.none})
end
function ITEM:GetDescription()
 local identity=self:GetData("fieldlinkIdentity")
 return identity and ("Зарегистрирован: "..identity.name.." / CID "..identity.cid..". Доступ следует за устройством.") or
  "Не зарегистрирован. Перетащите CID-карту на КПК в инвентаре, затем выберите регистрацию. Карта не расходуется."
end
ITEM.functions.Activate = {
 name="Активировать", icon="icon16/television.png",
 OnRun=function(item)
  local plugin=ix.plugin.list["site_pda"]
  if plugin and IsValid(item.player) then plugin:ActivatePDA(item.player,item) end
  return false
 end,
 OnCanRun=function(item)
  local p=item.player; local c=IsValid(p) and p:GetCharacter()
  return c and not IsValid(item.entity) and (not c:GetData("fieldlinkEnabled",false) or c:GetData("fieldlinkDevice")~=item:GetID())
 end
}
ITEM.functions.Deactivate = {
 name="Деактивировать", icon="icon16/television_delete.png",
 OnRun=function(item)
  local plugin=ix.plugin.list["site_pda"]
  if plugin and IsValid(item.player) then plugin:DeactivatePDA(item.player) end
  return false
 end,
 OnCanRun=function(item)
  local p=item.player; local c=IsValid(p) and p:GetCharacter()
  return c and not IsValid(item.entity) and c:GetData("fieldlinkEnabled",false) and c:GetData("fieldlinkDevice")==item:GetID()
 end
}
