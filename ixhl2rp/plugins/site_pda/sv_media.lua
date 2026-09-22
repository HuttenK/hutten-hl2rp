local PLUGIN=PLUGIN
local F=ix.Fieldlink
for _,name in ipairs({"ixFieldlinkUpload","ixFieldlinkPhoto","ixFieldlinkScan"}) do util.AddNetworkString(name) end
local folder="fieldlink_media"
file.CreateDir(folder)
local saved=file.Read(folder.."/index.json","DATA")
PLUGIN.media=saved and util.JSONToTable(saved) or {}
local M=PLUGIN.media
M.devices=M.devices or {}; M.photos=M.photos or {}; M.nextMessage=M.nextMessage or 1
function PLUGIN:SaveMedia()
 file.Write(folder.."/index.json",util.TableToJSON(M))
end
function PLUGIN:MediaDevice(item)
 local identity=item and item:GetData("fieldlinkIdentity")
 if not identity then return end
 local key=tostring(item:GetID())
 local changed=not M.devices[key] or M.devices[key].identity~=identity.id or M.devices[key].name~=identity.name
 if not M.devices[key] then M.devices[key]={photos={},messages={}} end
 local d=M.devices[key]; d.name=identity.name; d.cid=identity.cid; d.identity=identity.id
 if changed then self:SaveMedia() end
 return d
end
function PLUGIN:MediaSnapshot(p,data)
 local d=self:MediaDevice(F.DeviceItem(p)); if not d then return end
 data.photos={}; data.messages=d.messages; data.contacts={}
 for _,id in ipairs(d.photos) do if M.photos[id] then data.photos[#data.photos+1]=M.photos[id] end end
 -- Directory exposes registered online devices, not the holder's real identity.
 for _,other in ipairs(player.GetAll()) do
  local item=F.DeviceItem(other); local identity=F.Identity(other)
  if item and identity and item:GetID()~=data.device and #data.contacts<64 then
   data.contacts[#data.contacts+1]={device=item:GetID(),name=identity.name,cid=identity.cid}
  end
 end
end
function PLUGIN:PhotoAccess(device,id)
 if not isstring(id) or not id:match("^[a-f0-9]+$") or #id~=64 or not M.photos[id] then return false end
 for _,photo in ipairs(device.photos) do if photo==id then return true end end
 for _,message in ipairs(device.messages) do if message.photo==id then return true end end
 return false
end
function PLUGIN:CollectPhotos()
 local used={}
 for _,d in pairs(M.devices) do
  for _,id in ipairs(d.photos) do used[id]=true end
  for _,message in ipairs(d.messages) do if message.photo then used[message.photo]=true end end
 end
 for id in pairs(M.photos) do
  if not used[id] and #id==64 and id:match("^[a-f0-9]+$") then file.Delete(folder.."/"..id..".jpg"); M.photos[id]=nil end
 end
end
function PLUGIN:MediaAction(p,action,payload)
 local item=F.DeviceItem(p); local identity=F.Identity(p)
 if not F.Ready(p) or not identity or tonumber(payload.device)~=item:GetID() then return false end
 local d=self:MediaDevice(item)
 if action=="message" then
  if (p.ixFieldlinkMessageAt or 0)>CurTime() then return false end
  local target=tonumber(payload.target)
  if not target or target%1~=0 or target==item:GetID() then return false end
  local recipient=M.devices[tostring(target)]
  local text=F.Text(payload.text,600); local photo=payload.photo
  if not recipient or (not text and not photo) or (photo and not self:PhotoAccess(d,photo)) then return false end
  local record={id=M.nextMessage,from=item:GetID(),to=target,name=identity.name,cid=identity.cid,
   recipient=recipient.name,text=text or "",photo=photo,time=os.time()}
  M.nextMessage=M.nextMessage+1
  table.insert(d.messages,1,record); table.insert(recipient.messages,1,table.Copy(record))
  while #d.messages>40 do table.remove(d.messages) end
  while #recipient.messages>40 do table.remove(recipient.messages) end
  p.ixFieldlinkMessageAt=CurTime()+2
  self:CollectPhotos(); self:SaveMedia(); self:Send(p,"Сообщение доставлено.")
  for _,other in ipairs(player.GetAll()) do
   local otherItem=F.DeviceItem(other)
   if other~=p and otherItem and otherItem:GetID()==target then self:Send(other,"Новое сообщение FIELDLINK.") end
  end
  return true
 elseif action=="savePhoto" then
  if not self:PhotoAccess(d,payload.id) or #d.photos>=F.photoLimit then return false end
  for _,id in ipairs(d.photos) do if id==payload.id then return false end end
  table.insert(d.photos,1,payload.id); self:SaveMedia(); self:Send(p,"Вложение сохранено в галерее."); return true
 elseif action=="deletePhoto" then
  for i,id in ipairs(d.photos) do if id==payload.id then table.remove(d.photos,i); self:CollectPhotos(); self:SaveMedia(); self:Send(p,"Снимок удалён из альбома."); return true end end
 elseif action=="deleteMessage" then
  for i,message in ipairs(d.messages) do if message.id==tonumber(payload.id) then table.remove(d.messages,i); self:CollectPhotos(); self:SaveMedia(); self:Send(p,"Сообщение удалено."); return true end end
 elseif action=="photo" then
  if not self:PhotoAccess(d,payload.id) or (p.ixFieldlinkDownloadAt or 0)>CurTime() then return false end
  local bytes=file.Read(folder.."/"..payload.id..".jpg","DATA")
  if not bytes or #bytes>F.photoBytes then return false end
  p.ixFieldlinkDownloadAt=CurTime()+1
  local offset=0; local character=p:GetCharacter():GetID(); local device=item:GetID()
  local function send()
   if not IsValid(p) or not F.Ready(p) or p:GetCharacter():GetID()~=character or F.DeviceItem(p):GetID()~=device or not PLUGIN:PhotoAccess(d,payload.id) then return end
   local chunk=bytes:sub(offset+1,offset+F.photoChunk)
   net.Start("ixFieldlinkPhoto"); net.WriteUInt(device,32); net.WriteString(payload.id)
   net.WriteUInt(#bytes,18); net.WriteUInt(offset,18); net.WriteUInt(#chunk,16); net.WriteData(chunk,#chunk); net.Send(p)
   offset=offset+#chunk; if offset<#bytes then timer.Simple(.12,send) end
  end
  send(); return true
 end
 return false
end
-- Upload state is tied to both the holder session and the exact inventory item.
function PLUGIN:PhotoChunk(p,device,total,offset,bytes)
 if not F.Ready(p) or not F.Identity(p) or not isstring(bytes) or #bytes<1 or #bytes>F.photoChunk then return false end
 local item=F.DeviceItem(p)
 if item:GetID()~=device or total<12 or total>F.photoBytes or offset<0 or offset+#bytes>total then return false end
 local d=self:MediaDevice(item)
 if #d.photos>=F.photoLimit then self:Send(p,"Альбом заполнен: удалите снимок."); return false end
 if offset==0 then
  if (p.ixFieldlinkCaptureAt or 0)>CurTime() or table.Count(M.photos)>=2048 then return false end
  p.ixFieldlinkCaptureAt=CurTime()+4
  p.ixFieldlinkUpload={device=device,character=p:GetCharacter():GetID(),total=total,offset=0,parts={},expires=CurTime()+15}
 end
 local u=p.ixFieldlinkUpload
 if not u or u.device~=device or u.character~=p:GetCharacter():GetID() or u.total~=total or u.offset~=offset or u.expires<CurTime() then return false end
 u.parts[#u.parts+1]=bytes; u.offset=u.offset+#bytes
 if u.offset==total then
  p.ixFieldlinkUpload=nil
  local photo=table.concat(u.parts)
  if not F.PhotoJPEG(photo) then return false end
  local id=util.SHA256(photo)
  for _,existing in ipairs(d.photos) do if existing==id then self:Send(p,"Этот снимок уже сохранён."); return true end end
  file.Write(folder.."/"..id..".jpg",photo)
  M.photos[id]=M.photos[id] or {id=id,time=os.time(),name=F.Identity(p).name}
  table.insert(d.photos,1,id); self:SaveMedia(); self:Send(p,"Снимок сохранён на КПК.")
 end
 return true
end
net.Receive("ixFieldlinkUpload",function(bits,p)
 if bits>F.photoChunk*8+100 then return end
 local device,total,offset,size=net.ReadUInt(32),net.ReadUInt(18),net.ReadUInt(18),net.ReadUInt(16)
 if size<1 or size>F.photoChunk then return end
 if not PLUGIN:PhotoChunk(p,device,total,offset,net.ReadData(size)) then p.ixFieldlinkUpload=nil; PLUGIN:Send(p,"Снимок отклонён: проверьте альбом и повторите съёмку.") end
end)
function PLUGIN:ScanIdentity(p)
 local trace=util.TraceLine({start=p:EyePos(),endpos=p:EyePos()+p:EyeAngles():Forward()*256,filter=p,mask=MASK_SHOT})
 local target=trace.Entity; local info
 if IsValid(target) and target:IsPlayer() and target:Alive() and target:GetCharacter() then
  local inventory=target:GetInventory("cid")
  local card=inventory and inventory:GetItems()[1]
  local identity=F.CardIdentity(card)
  if identity then info={name=identity.name,cid=identity.cid,serial=identity.serial} end
 end
 return info
end
net.Receive("ixFieldlinkScan",function(bits,p)
 if bits>0 or not F.Ready(p) or not F.Identity(p) or (p.ixFieldlinkScanAt or 0)>CurTime() then return end
 p.ixFieldlinkScanAt=CurTime()+.6
 local info=PLUGIN:ScanIdentity(p)
 net.Start("ixFieldlinkScan"); net.WriteUInt(F.DeviceItem(p):GetID(),32); net.WriteBool(info~=nil)
 if info then net.WriteString(info.name); net.WriteString(info.cid); net.WriteString(info.serial) end
 net.Send(p)
end)
timer.Create("ixFieldlinkUploadCleanup",10,0,function()
 for _,p in ipairs(player.GetAll()) do if p.ixFieldlinkUpload and p.ixFieldlinkUpload.expires<CurTime() then p.ixFieldlinkUpload=nil end end
end)
