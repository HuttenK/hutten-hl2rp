local PLUGIN=PLUGIN
local F=ix.Fieldlink
util.AddNetworkString("ixFieldlinkRequest")
util.AddNetworkString("ixFieldlinkSnapshot")
util.AddNetworkString("ixFieldlinkClose")
PLUGIN.state=PLUGIN.state or {nextID=1,incidents={},directives={},alert={level=1,message="Ожидайте указаний руководителя смены.",by="Система",time=0}}
function PLUGIN:SaveData() self:SetData(self.state) end
function PLUGIN:LoadData()
 local saved=self:GetData()
 if istable(saved) and istable(saved.incidents) and istable(saved.directives) and istable(saved.alert) then
  self.state=saved; self.state.nextID=tonumber(saved.nextID) or 1
 end
end
function PLUGIN:HasPDAItem(p) return IsValid(p) and p.HasItem and p:HasItem("pda") end
function PLUGIN:RegisterPDA(p,device,card)
 if not IsValid(p) or not p:Alive() or not p:GetCharacter() or not p.HasItemByID then return false end
 if not device or device.uniqueID~="pda" or device:GetData("fieldlinkIdentity") or not card or card.equip_inv~="cid" then return false end
 local hasDevice,ownedDevice=p:HasItemByID(device:GetID())
 local hasCard,ownedCard=p:HasItemByID(card:GetID())
 if not hasDevice or ownedDevice~=device or not hasCard or ownedCard~=card then return false end
 local identity=F.CardIdentity(card)
 if not identity then p:Notify("CID не содержит действительных регистрационных данных."); return false end
 self.state.clearances=self.state.clearances or {}
 local clearance=tonumber(self.state.clearances[identity.id]) or 0
 if clearance~=clearance then clearance=0 end
 identity.clearance=math.Clamp(math.floor(clearance),0,4); identity.registered=os.time()
 device:SetData("fieldlinkIdentity",identity)
 device:SetData("fieldlinkNotes","")
 if self.MediaDevice then self:MediaDevice(device); self:SaveMedia() end
 p:Notify("КПК зарегистрирован: "..identity.name.." / CID "..identity.cid)
 p:EmitSound("fieldlink/ui/register.wav",55,100,.5)
 return true
end
function PLUGIN:GrantPDA(p)
 local c=p:GetCharacter()
 local item=F.DeviceItem(p)
 if not c or not p:Alive() or not item or not c:GetData("fieldlinkEnabled",false) then return end
 local device=p:GetWeapon(F.class)
 if IsValid(device) and (device.ixFieldlinkCharacter~=c:GetID() or device.ixFieldlinkItem~=item:GetID()) then p:StripWeapon(F.class); device=nil end
 if not IsValid(device) then
  local previous=p:GetActiveWeapon()
  device=p:Give(F.class,true)
  if IsValid(previous) and p:GetActiveWeapon()==device then p:SelectWeapon(previous:GetClass()) end
 end
 if IsValid(device) then device.ixFieldlinkCharacter=c:GetID(); device.ixFieldlinkItem=item:GetID() end
 return device
end
function PLUGIN:ActivatePDA(p,item)
 if not item or not p:Alive() or not p:GetCharacter() or not p.HasItemByID then return end
 local owned,found=p:HasItemByID(item:GetID())
 if not owned or found~=item or item.uniqueID~="pda" then return end
 p:GetCharacter():SetData("fieldlinkDevice",item:GetID())
 p:GetCharacter():SetData("fieldlinkEnabled",true)
 local w=self:GrantPDA(p)
 p:Notify(IsValid(w) and "FIELDLINK добавлен в выбор оружия. Выберите КПК и удерживайте R, чтобы поднять его." or "Не удалось загрузить SWEP PDA.")
end
function PLUGIN:DeactivatePDA(p)
 local c=p:GetCharacter()
 if c then c:SetData("fieldlinkEnabled",false); c:SetData("fieldlinkDevice",nil) end
 p:StripWeapon(F.class)
end
function PLUGIN:PdaOff(p)
 local device=p:GetWeapon(F.class)
 if not IsValid(device) then return end
 device:CustomEquip(false)
 if p:GetActiveWeapon()==device and p.SetWepRaised then p:SetWepRaised(false,device) end
end
net.Receive("ixFieldlinkClose",function(_,p) PLUGIN:PdaOff(p) end)
function PLUGIN:Snapshot(p)
 local c=p:GetCharacter(); local level=F.Clearance(p); local item=F.DeviceItem(p); local identity=F.Identity(p)
 local data={recipient=c:GetID(),device=item:GetID(),registered=identity~=nil,character=identity and identity.id or 0,
 name=identity and identity.name or "Незарегистрированное устройство",cid=identity and identity.cid or "—",clearance=level,alert=self.state.alert,
 incidents={},directives={},records={},notes=item:GetData("fieldlinkNotes",""),map=game.GetMap(),time=os.time()}
 if not identity then data.alert={level=1,message="Регистрация не выполнена"}; return data end
 if self.MediaSnapshot then self:MediaSnapshot(p,data) end
 for _,v in ipairs(self.state.incidents) do if F.CanReadIncident(p,v) then data.incidents[#data.incidents+1]=v end end
 for _,v in ipairs(self.state.directives) do if level>=v.level then data.directives[#data.directives+1]=v end end
 for _,v in ipairs(F.records) do if level>=v.level then data.records[#data.records+1]=v end end
 return data
end
function PLUGIN:Send(p,message)
 if not F.Ready(p) then return end
 local data=self:Snapshot(p); data.message=message
 local encoded=util.Compress(util.TableToJSON(data))
 if not encoded or #encoded>60000 then return end
 net.Start("ixFieldlinkSnapshot"); net.WriteUInt(#encoded,16); net.WriteData(encoded,#encoded); net.Send(p)
end
local function Find(list,id)
 for _,record in ipairs(list) do if record.id==id then return record end end
end
local function MakeRoom(list)
 if #list<40 then return true end
 for n=#list,1,-1 do if list[n].status=="closed" then table.remove(list,n); return true end end
 return false
end
function PLUGIN:Handle(p,action,payload)
 if not F.Ready(p) or not istable(payload) then return false end
 local identity=F.Identity(p); local item=F.DeviceItem(p); local level=F.Clearance(p)
 if action=="sync" then self:Send(p); return true end
 if not identity or tonumber(payload.device)~=item:GetID() then return false end
 if action=="message" or action=="photo" or action=="savePhoto" or action=="deletePhoto" or action=="deleteMessage" then
  return self.MediaAction and self:MediaAction(p,action,payload) or false
 end
 local id=identity.id; local name=identity.name
 local message
 if action=="notes" then
  local raw=payload.text
  if type(raw)~="string" or #raw>8000 then return false end
  local text=raw=="" and "" or F.Text(raw,2000)
  if text==nil then return false end
  item:SetData("fieldlinkNotes",text); message="Блокнот сохранён."
 elseif action=="incident" then
  if (p.ixFieldlinkReportAt or 0)>CurTime() then self:Send(p,"Перед следующим сообщением подождите 10 секунд."); return false end
  local title=F.Text(payload.title,72); local body=F.Text(payload.body,600); local location=F.Text(payload.location,72)
  local category=tonumber(payload.category)
  if not title or not body or not location or not category or not F.categories[category] then return false end
  if not MakeRoom(self.state.incidents) then self:Send(p,"Очередь заполнена. Дежурный должен закрыть старые записи."); return false end
  local pos=p:GetPos()
  table.insert(self.state.incidents,1,{id=self.state.nextID,title=title,body=body,location=location,category=category,
   authorID=id,author=name,status="open",time=os.time(),map=game.GetMap(),position={x=math.Round(pos.x),y=math.Round(pos.y),z=math.Round(pos.z)}})
  self.state.nextID=self.state.nextID+1; p.ixFieldlinkReportAt=CurTime()+10; message="Инцидент передан дежурному."
 elseif action=="publish" then
  if level<3 then return false end
  local title=F.Text(payload.title,72); local body=F.Text(payload.body,600); local required=tonumber(payload.level)
  if not title or not body or not required or required%1~=0 or required<0 or required>level then return false end
  if not MakeRoom(self.state.directives) then self:Send(p,"Очередь директив заполнена."); return false end
  table.insert(self.state.directives,1,{id=self.state.nextID,title=title,body=body,level=required,author=name,status="open",time=os.time()})
  self.state.nextID=self.state.nextID+1; message="Директива опубликована."
 elseif action=="alert" then
  if level<3 then return false end
  local alert=tonumber(payload.level); local text=F.Text(payload.text,220)
  if not alert or not F.alerts[alert] or not text then return false end
  self.state.alert={level=alert,message=text,by=name,time=os.time()}; message="Режим объекта обновлён."
 elseif action=="claim" or action=="resolve" or action=="release" then
  local incident=payload.kind=="incident"
  if not incident and payload.kind~="directive" then return false end
  local record=Find(incident and self.state.incidents or self.state.directives,tonumber(payload.id))
  if not record or record.status=="closed" then return false end
  if incident then if level<2 then return false end elseif level<record.level then return false end
  if action=="claim" then
   if record.ownerID then self:Send(p,"Запись уже назначена другому сотруднику."); return false end
   record.ownerID=id; record.owner=name; record.status="assigned"; message="Вы назначены исполнителем."
  else
   if incident then if not F.CanResolve(p,record) then return false end
   elseif record.ownerID~=id and level<3 then return false end
   if action=="release" then record.ownerID=nil; record.owner=nil; record.status="open"; message="Назначение освобождено."
   else record.status="closed"; record.closedBy=name; record.closedAt=os.time(); message="Запись закрыта." end
  end
 else return false end
 self:SaveData(); self:Send(p,message)
 return true
end
net.Receive("ixFieldlinkRequest",function(bits,p)
 if bits>70000 or not F.Ready(p) or (p.ixFieldlinkRequestAt or 0)>CurTime() then return end
 p.ixFieldlinkRequestAt=CurTime()+0.35
 local action=net.ReadString(); local encoded=net.ReadString()
 if #encoded>8500 then return end
 local payload=util.JSONToTable(encoded)
 if not PLUGIN:Handle(p,action,payload) then PLUGIN:Send(p,"Запрос отклонён: проверьте поля, допуск и актуальность записи.") end
end)
-- Inventory activation grants the selectable weapon; closing its UI only lowers it.
timer.Create("ixFieldlinkAccess",0.5,0,function()
 for _,p in ipairs(player.GetAll()) do
  local c=p:GetCharacter()
  if p:Alive() and c and c:GetData("fieldlinkEnabled",false) and F.DeviceItem(p) then
   PLUGIN:GrantPDA(p)
  else
   if IsValid(p:GetWeapon(F.class)) then p:StripWeapon(F.class) end
   if c and c:GetData("fieldlinkEnabled",false) and not F.DeviceItem(p) then c:SetData("fieldlinkEnabled",false); c:SetData("fieldlinkDevice",nil) end
  end
 end
end)
ix.command.Add("PDASetClearance",{
 description="Назначить допуск FIELDLINK по экипированной CID-карте персонажа (0–4).",adminOnly=true,
 arguments={ix.type.character,ix.type.number},
 OnRun=function(self,p,target,value)
  if value~=value or value%1~=0 or value<0 or value>4 then return "Укажите целый допуск от 0 до 4." end
  local owner=target:GetPlayer()
  local inventory=IsValid(owner) and owner:GetCharacter()==target and owner:GetInventory("cid")
  local card=inventory and inventory:GetItems()[1]
  local identity=F.CardIdentity(card)
  if not identity then return "Персонаж должен экипировать заполненную CID-карту." end
  PLUGIN.state.clearances=PLUGIN.state.clearances or {}
  PLUGIN.state.clearances[identity.id]=value; PLUGIN:SaveData()
  return "Допуск FIELDLINK для "..identity.name..": "..value
 end
})
