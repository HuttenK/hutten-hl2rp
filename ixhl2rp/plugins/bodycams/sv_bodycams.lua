local P,B=PLUGIN,ix.bodycams
B.records=B.records or {}
local function cctv() return ix.plugin.list.cctv end
function B.RemoveFeed(p)
 local C=cctv();local id=B.records[p]
 B.records[p]=nil
 if IsValid(p) then p:SetNW2Int("ixHelmetCamera",0);p:SetNW2Bool("ixHelmetCameraOn",false) end
 if C and id and C.devices and C.devices[id] and C.devices[id].bodycam then C:DeleteRecord(id) end
end
function B.Refresh(p)
 local C=cctv()
 if not C or not C.loaded or C.restoring or C.stopping or not B.Available(p) then B.RemoveFeed(p);return end
 local helmet=B.WornHelmet(p)
 if not B.Attached(helmet) then B.RemoveFeed(p);return end
 C:Ensure()
 local id=B.records[p];local d=id and C.devices[id]
 if d and (not d.bodycam or d.entity~=p or d.helmetID~=helmet.id) then B.RemoveFeed(p);d=nil end
 if not d then
  if not ix.CCTV.ID(C.nextID) then return end
  d={id=C.nextID,kind="camera",bodycam=true,entity=p,helmetID=helmet.id,fov=90}
  C.nextID=C.nextID+1;C.devices[d.id]=d;B.records[p]=d.id
 end
 local name="Шлем / "..string.utf8sub(p:Name(),1,36)
 local on=B.Enabled(helmet)
 local changed=d.name~=name or d.on~=on
 d.name=name;d.on=on
 p:SetNW2Int("ixHelmetCamera",d.id);p:SetNW2Bool("ixHelmetCameraOn",on)
 if changed then C:SendDevice(d) end
end
function B.Change(p,helmet,action,camera)
 if not B.Available(p) or p:IsRestricted() or not B.Compatible(helmet) or not B.Owns(p,helmet) then return false,"Нужен ваш совместимый шлем." end
 if (p.ixBodycamNext or 0)>CurTime() then return false,"Подождите немного." end
 p.ixBodycamNext=CurTime()+.3
 if action=="attach" then
  if B.Attached(helmet) then return false,"Камера уже установлена." end
  camera=camera or B.FindCamera(p)
  if not B.Owns(p,camera) or camera.uniqueID~="helmet_bodycam" then return false,"Нужна камера на шлем в инвентаре." end
  -- Both operations are synchronous native inventory operations. Attachments
  -- are saved as part of the helmet, not as orphan inventory instances.
  if not camera:Remove(true) then return false,"Не удалось снять камеру с инвентаря." end
  helmet:SetData("helmetCamera",true);helmet:SetData("helmetCameraOn",false)
  B.Refresh(p);return true,"Камера закреплена. Включите её в меню шлема или /Bodycam."
 elseif action=="detach" then
  if not B.Attached(helmet) then return false,"На шлеме нет камеры." end
  if not p:GetInventory("main") then return false,"Инвентарь ещё не загружен." end
  local restored=ix.Item:Instance("helmet_bodycam")
  if not restored then return false,"Не удалось создать предмет камеры." end
  local success=p:AddItem(restored)
  if not success then restored:Remove(true);return false,"Освободите место для камеры. Она остаётся на шлеме." end
  helmet:SetData("helmetCamera",false);helmet:SetData("helmetCameraOn",false)
  B.Refresh(p);return true,"Камера снята и убрана в инвентарь."
 elseif action=="on" or action=="off" or action=="toggle" then
  if not B.Attached(helmet) then return false,"На шлеме нет камеры." end
  local enabled=action=="on" or (action=="toggle" and not B.Enabled(helmet))
  local changed=B.Enabled(helmet)~=enabled
  helmet:SetData("helmetCameraOn",enabled);B.Refresh(p)
  if changed then hook.Run("BodycamStateChanged",p,helmet,enabled) end
  return true,enabled and "Камера включена. Для передачи наденьте шлем." or "Камера выключена."
 end
 return false,"Неизвестное действие."
end
function P:Think()
 if (self.nextBodycamCheck or 0)>CurTime() then return end;self.nextBodycamCheck=CurTime()+.25
 for _,p in ipairs(player.GetAll()) do B.Refresh(p) end
 for p in pairs(B.records) do if not IsValid(p) then B.RemoveFeed(p) end end
end
function P:OnItemEquipped(p,item) if B.Compatible(item) then B.Refresh(p) end end
function P:OnItemUnequipped(p,item) if B.Compatible(item) then B.RemoveFeed(p) end end
function P:InventoryItemRemoved(_,item)
 if not B.Compatible(item) then return end
 for p,id in pairs(B.records) do
  local C=cctv();local d=C and C.devices and C.devices[id]
  if d and d.helmetID==item.id then B.RemoveFeed(p) end
 end
end
function P:DoPlayerDeath(p) B.RemoveFeed(p) end
function P:PlayerDeath(p) B.RemoveFeed(p) end
function P:PlayerDisconnected(p) B.RemoveFeed(p) end
function P:PrePlayerLoadedCharacter(p) p.ixBodycamCharacterLoading=true;B.RemoveFeed(p) end
function P:PlayerLoadedCharacter(p) p.ixBodycamCharacterLoading=nil;B.Refresh(p) end
function P:OnCharacterFallover(p,_,state) if state then B.RemoveFeed(p) end end
function P:OnUnload()
 local players={};for p in pairs(B.records) do players[#players+1]=p end
 for _,p in ipairs(players) do B.RemoveFeed(p) end
end
