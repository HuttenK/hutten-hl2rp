ITEM.name = "Склянка с неизвестной жидкостью"
ITEM.description = "Тёмная жидкость без осадка. На горлышке выцарапан крошечный череп, а из всей надписи уцелело лишь «последний глоток». Проверять вкус прежний владелец никому не советовал."
ITEM.model = "models/leon/eldenring/flask.mdl"
ITEM.skin = 2
ITEM.category = "item.category.medical"
ITEM.width = 1
ITEM.height = 2
ITEM.functions.drink = {
 name = "Выпить",
 OnCanRun = function(item)
  local client = item.player
  return IsValid(client) and client:Alive() and client:GetCharacter() ~= nil and
   not client:IsRestricted() and not client:InCriticalState() and
   not client.bUsingMedical and not IsValid(item:GetEntity()) and item:GetOwner() == client
 end,
 OnRun = function(item)
  if not item.functions.drink.OnCanRun(item) then return false end
  local client = item.player
  item:Remove() -- Consume before death hooks can drop the inventory.
  client:EmitSound("npc/barnacle/barnacle_gulp1.wav", 60, 95)
  client:Kill() -- Direct death, bypassing the lethal-damage rescue window.
  return false
 end
}
