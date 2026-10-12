ITEM.name = "Камера на шлем"
ITEM.description = "Съёмная камера SCiPNET. Перетащите её на совместимый шлем в инвентаре и выберите «Прикрепить камеру». Также доступно меню шлема. Надетый включённый шлем передаёт изображение на мониторы CCTV."
ITEM.model = "models/cod/bo1/interrogation_room/mtl_p_int_security_camera.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.stackable = false
ITEM.category = "Снаряжение"
-- Native Helix item-on-item drag invokes this combine action. Keep the exact
-- source camera instead of searching for another camera in the inventory.
ITEM.combine = ITEM.combine or {}
ITEM.combine.attachBodycam = {
 name = "Прикрепить камеру", icon = "icon16/camera.png",
 OnCanRun = function(item, target)
  local B=ix.bodycams;local p=item.player
  return B.Owns(p,item) and item.uniqueID=="helmet_bodycam" and B.Compatible(target)
   and B.Owns(p,target) and not B.Attached(target)
 end,
 OnRun = function(item,target)
  local p=item.player
  local _,message=ix.bodycams.Change(p,target,"attach",item)
  if IsValid(p) then p:Notify(message) end
  return false
 end
}
ITEM.functions.attach = {
 name = "Прикрепить к надетому шлему", icon = "icon16/camera.png",
 OnCanRun = function(item)
  local helmet=ix.bodycams.WornHelmet(item.player)
  return ix.bodycams.Owns(item.player,item) and helmet and not ix.bodycams.Attached(helmet)
 end,
 OnRun = function(item)
  local B=ix.bodycams;local helmet=B.WornHelmet(item.player)
  local _,message=B.Change(item.player,helmet,"attach",item)
  item.player:Notify(message)
  return false
 end
}
