local P=PLUGIN
for _,name in ipairs({'ixStatusHUD','ixStatusHUDEdit','ixStatusHUDSave','ixStatusHUDReady'}) do util.AddNetworkString(name) end
P.status=P.status or {text='',enabled=true,revision=0}
function P:SendStatus(client,editor)
 if editor and (not IsValid(client) or not client:IsAdmin()) then return end
 if client==nil then
  for _,recipient in ipairs(player.GetAll()) do self:SendStatus(recipient) end
  return
 end
 if not IsValid(client) then return end
 local visible=editor or self:CanSeeStatus(client)
 if not editor then client.ixStatusHUDAccess=visible end
 net.Start(editor and 'ixStatusHUDEdit' or 'ixStatusHUD')
 net.WriteString(visible and self.status.text or '');net.WriteBool(visible and self.status.enabled or false);net.WriteUInt(self.status.revision,31)
 net.Send(client)
end
function P:LoadData()
 local data=self:GetData() or {}
 self.status={text=self:ValidateStatus(data.text) or '',enabled=data.enabled~=false,revision=math.Clamp(math.floor(tonumber(data.revision) or 0),0,2147483646)}
 self:SendStatus()
end
function P:SaveData() self:SetData(self.status) end
function P:OpenStatusEditor(client)
 if not IsValid(client) or not client:IsAdmin() then return end
 self:SendStatus(client,true)
end
function P:SetStatus(client,text,enabled,revision)
 if not IsValid(client) or not client:IsAdmin() then return false end
 text=self:ValidateStatus(text)
 if not text or not isbool(enabled) then client:Notify('До 8 строк, 64 символов в строке и 1024 байт UTF-8.');return false end
 if revision~=self.status.revision then client:Notify('Сводка изменена другим администратором. Откройте редактор заново.');return false end
 if text==self.status.text and enabled==self.status.enabled then return true end
 self.status={text=text,enabled=enabled,revision=(self.status.revision+1)%2147483647}
 self:SaveData();self:SendStatus();client:Notify('Оперативная сводка обновлена для сотрудников МОГ.');return true
end
net.Receive('ixStatusHUDSave',function(bits,client)
 if bits>12000 or not IsValid(client) or not client:IsAdmin() or CurTime()<(client.ixStatusWriteAt or 0) then return end
 client.ixStatusWriteAt=CurTime()+.5
 local text=net.ReadString();local enabled=net.ReadBool();local revision=net.ReadUInt(31)
 P:SetStatus(client,text,enabled,revision)
end)
net.Receive('ixStatusHUDReady',function(_,client)
 if not IsValid(client) then return end
 if CurTime()<(client.ixStatusReadAt or 0) then return end
 client.ixStatusReadAt=CurTime()+2;P:SendStatus(client)
end)
function P:PlayerLoadedCharacter(client) self:SendStatus(client) end
-- SetFaction has a custom setter without CharacterVarChanged in this fork.
-- Refresh eligibility after transfers as well as the usual character-load sync.
function P:Think()
 if CurTime()<(self.nextAccessCheck or 0) then return end
 self.nextAccessCheck=CurTime()+.5
 for _,client in ipairs(player.GetAll()) do
  if client.ixStatusHUDAccess~=self:CanSeeStatus(client) then self:SendStatus(client) end
 end
end
