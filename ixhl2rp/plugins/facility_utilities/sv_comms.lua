local P,F=PLUGIN,ix.Facility
util.AddNetworkString("ixFacilityTone")
function P:Tone(p,kind)
 if not IsValid(p) then return end
 net.Start("ixFacilityTone");net.WriteUInt(kind,3);net.Send(p)
end
function P:EndCall(id)
 local c=self.calls[id];if not c then return end
 self.calls[id]=nil;self:Tone(c.player,3);self:Tone(c.operator,3)
end
function P:PhysicalSession(p,d)
 return {facilityDevice=d.id,entity=d.entity,character=p:GetCharacter():GetID()}
end
function P:NextCall()
 local best
 for id,c in pairs(self.calls) do if not c.operator and (not best or (c.created or 0)<(self.calls[best].created or 0) or
  ((c.created or 0)==(self.calls[best].created or 0) and id<best)) then best=id end end
 return best
end
function P:UseReceiver(p,d)
 local s=self:PhysicalSession(p,d)
 if not self:OperatorValid(p,s) then return false,"Нужна карта L2 и исправный приёмный интерком." end
 self:PruneComms()
 for id,c in pairs(self.calls) do
  if c.operator==p then self:EndCall(id);return true,"Разговор завершён." end
  if c.session and c.session.facilityDevice==d.id then return false,"Этот интерком уже занят оператором." end
 end
 local id=self:NextCall();if not id then return false,"Вызовов нет. Этот интерком звонит, когда кто-то просит помощь." end
 return self:CommsAction(p,s,{command="accept",id=id})
end
function P:UseAnnouncement(p,d)
 local s=self:PhysicalSession(p,d)
 if not self:OperatorValid(p,s) then return false,"Нужна карта L2 и исправный интерком общего эфира." end
 if self.broadcasts[p] and self.broadcasts[p].global then
  self.broadcasts[p]=nil;self:Tone(p,3);return true,"Общий эфир выключен."
 end
 self:PruneComms()
 for other in pairs(self.broadcasts) do if other~=p then return false,"Уже идёт другое объявление. Дождитесь окончания." end end
 for _,c in pairs(self.calls) do if c.operator==p or c.player==p then return false,"Сначала завершите разговор по интеркому." end end
 self.broadcasts[p]={player=p,character=p:GetCharacter():GetID(),global=true,session=s,untilTime=CurTime()+120}
 for _,listener in ipairs(player.GetAll()) do if F.Active(listener) then self:Tone(listener,4) end end
 self:Audit(p,"Общий голосовой эфир",d.name)
 return true,"ОБЩИЙ ЭФИР: вас слышит весь объект. Говорите кнопкой голосового чата. E — закончить."
end
function P:CallIntercom(p,d)
 if not self:DevicePowered(d) or not F.Near(p,d.entity) then return false,"Переговорное устройство недоступно." end
 local old=self.calls[d.id]
 if old and old.player==p then self:EndCall(d.id);return true,"Вызов завершён." end
 if old then return false,"Линия занята." end
 if (p.ixFacilityCallAt or 0)>CurTime() then return false,"Подождите перед повторным вызовом." end
 if self.broadcasts[p] then return false,"Сначала выключите оповещение." end
 for _,c in pairs(self.calls) do if c.player==p or c.operator==p then return false,"У вас уже есть разговор или вызов." end end
 p.ixFacilityCallAt=CurTime()+4
 self.calls[d.id]={player=p,character=p:GetCharacter():GetID(),created=CurTime(),untilTime=CurTime()+90}
 self:Tone(p,1);d.entity:SetNW2String("ixFacilityState","ОЖИДАНИЕ ОТВЕТА / E — ОТМЕНА")
 return true,"Вызов отправлен. Оставайтесь у устройства; E — отменить."
end
function P:OperatorValid(p,s)
 if s and s.facilityDevice then
  local d=self.store.devices[s.facilityDevice]
  return F.Access(p,2) and d and (d.kind=="receiver" or d.kind=="announcement") and d.entity==s.entity
   and self:DevicePowered(d) and F.Near(p,d.entity,120) and p:GetCharacter():GetID()==s.character or false
 end
 local n=ix.plugin.list.foundation_network
 return F.Access(p,2) and n and s and n:Session(p,s.token)~=nil
end
function P:CommsAction(p,s,data)
 if not self:OperatorValid(p,s) then return false,"Требуется рабочий терминал и L2." end
 if data.command=="broadcastStop" then self.broadcasts[p]=nil;return true,"Микрофон отключён." end
 if data.command=="broadcast" then
  if s.facilityDevice then return false,"Оповещение по секторам доступно на терминале." end
  local circuit=self.store.circuits[data.id];if not circuit then return false,"Выберите сектор." end
  for _,v in pairs(self.broadcasts) do if v.global or (v.circuit==data.id and v.player~=p) then return false,"Канал занят другим объявлением." end end
  for _,c in pairs(self.calls) do if c.operator==p or c.player==p then return false,"Сначала завершите разговор по интеркому." end end
  local found=false
  for _,d in pairs(self.store.devices) do if d.kind=="speaker" and d.circuit==data.id and self:DevicePowered(d) then found=true;d.entity:EmitSound("buttons/blip1.wav",65) end end
  if not found then return false,"В секторе нет работающих громкоговорителей." end
  self.broadcasts[p]={player=p,character=p:GetCharacter():GetID(),circuit=data.id,session=s,untilTime=CurTime()+120}
  self:Audit(p,"Голосовое оповещение",circuit.name)
  return true,"Передача включена на 120 с. Используйте обычную кнопку голосового чата."
 end
 local call=self.calls[data.id];local d=self.store.devices[data.id]
 if not call or not d or not self:DevicePowered(d) then return false,"Вызов уже недоступен." end
 if data.command=="hangup" then
  if call.operator and call.operator~=p then return false,"Линия занята другим оператором." end
  self:EndCall(data.id);return true,"Линия закрыта."
 end
 if data.command~="accept" or (call.operator and call.operator~=p) then return false,"Линия занята." end
 for id,c in pairs(self.calls) do if id~=data.id and c.operator==p then return false,"Сначала завершите текущий разговор." end end
 if call.player==p then return false,"Нельзя принять собственный вызов." end
 call.operator=p;call.session=s;call.operatorCharacter=p:GetCharacter():GetID();call.untilTime=CurTime()+180
 self.broadcasts[p]=nil;self:Tone(call.player,2);self:Tone(p,2)
 return true,"Связь установлена. Используйте обычную кнопку голосового чата."
end
function P:PruneComms()
 if (self.nextCommsPrune or 0)>CurTime() then return end;self.nextCommsPrune=CurTime()+.1
 for id,c in pairs(self.calls) do
  local d=self.store.devices[id]
  if not d or not self:DevicePowered(d) or not F.Near(c.player,d.entity) or c.player:GetCharacter():GetID()~=c.character
   or c.untilTime<CurTime() or (c.operator and (not self:OperatorValid(c.operator,c.session) or c.operator:GetCharacter():GetID()~=c.operatorCharacter)) then self:EndCall(id) end
 end
 for p,b in pairs(self.broadcasts) do
  if (not b.global and not self.store.circuits[b.circuit]) or not self:OperatorValid(p,b.session) or p:GetCharacter():GetID()~=b.character or CurTime()>b.untilTime then self.broadcasts[p]=nil;self:Tone(p,3) end
 end
 local nextCall=self:NextCall()
 for id,d in pairs(self.store.devices) do if IsValid(d.entity) then
  if d.kind=="intercom" then
   local c=self.calls[id];d.entity:SetNW2String("ixFacilityState",c and (c.operator and "ВАМ ОТВЕТИЛИ / E — ЗАВЕРШИТЬ" or "ОЖИДАНИЕ ОТВЕТА / E — ОТМЕНА") or "E — ВЫЗВАТЬ ПОМОЩЬ")
  elseif d.kind=="receiver" then
   local busy;for _,c in pairs(self.calls) do if c.session and c.session.facilityDevice==id then busy=c end end
   local incoming=nextCall and self.store.devices[nextCall]
   d.entity:SetNW2String("ixFacilityState",busy and "РАЗГОВОР / E — ЗАВЕРШИТЬ" or incoming and ("E — ОТВЕТИТЬ: "..incoming.name) or "ПРИЁМ ВЫЗОВОВ / НУЖНА L2")
   if incoming and not busy and self:DevicePowered(d) and CurTime()>(d.nextRing or 0) then d.nextRing=CurTime()+5;d.entity:EmitSound("buttons/blip1.wav",70,100,.8) end
  elseif d.kind=="announcement" then
   local active;for _,b in pairs(self.broadcasts) do if b.global and b.session.facilityDevice==id then active=true end end
   d.entity:SetNW2String("ixFacilityState",active and "ОБЩИЙ ЭФИР / E — ВЫКЛЮЧИТЬ" or "E — ОБЪЯВЛЕНИЕ ВСЕМ / НУЖНА L2")
  end
 end end
 for _,p in ipairs(player.GetAll()) do
  local active=self.broadcasts[p]~=nil
  if not active then for _,c in pairs(self.calls) do if c.operator==p then active=true;break end end end
  p:SetNW2Bool("ixFacilityMic",active)
  local hint=self.broadcasts[p] and (self.broadcasts[p].global and "ВЕСЬ ОБЪЕКТ СЛЫШИТ ВАС" or "ОБЪЯВЛЕНИЕ ПО СЕКТОРУ") or ""
  local physical=self.broadcasts[p] and self.broadcasts[p].session.facilityDevice
  for _,c in pairs(self.calls) do
   if c.operator==p then hint="СВЯЗЬ С ВЫЗЫВАЮЩИМ УСТАНОВЛЕНА";physical=c.session and c.session.facilityDevice
   elseif c.player==p then hint=c.operator and "ДИСПЕТЧЕР ОТВЕТИЛ — ГОВОРИТЕ" or "ВЫЗОВ ОТПРАВЛЕН — ЖДИТЕ ОТВЕТА";physical=true end
  end
  p:SetNW2String("ixFacilityVoiceHint",hint)
  p:SetNW2String("ixFacilityStopHint",hint=="" and "" or physical and "E — закончить" or "Стоп на терминале")
 end
end
function P:VoiceRoute(listener,talker)
 self:PruneComms()
 if not F.Active(listener) or not F.Active(talker) then return end
 local b=self.broadcasts[talker];local gain=0
 if b and b.global then return true,false,"ОБЩИЙ ЭФИР",1 end
 if b then
  for _,d in pairs(self.store.devices) do if d.kind=="speaker" and d.circuit==b.circuit and self:DevicePowered(d) then
   local radius=d.radius or 300;local distance=listener:GetPos():Distance(d.entity:GetPos())
   if distance<radius then gain=math.max(gain,(1-distance/radius)^.5) end
  end end
  if gain>0 then return true,false,"ОПОВЕЩЕНИЕ / "..self.store.circuits[b.circuit].name,gain end
 end
 for id,c in pairs(self.calls) do if c.operator then
  local d=self.store.devices[id]
  if talker==c.player and listener==c.operator then return true,false,"ИНТЕРКОМ / "..d.name,1 end
  if talker==c.operator and listener:GetPos():DistToSqr(d.entity:GetPos())<180^2 then
   return true,false,"ИНТЕРКОМ / "..d.name,math.max(.1,1-listener:GetPos():Distance(d.entity:GetPos())/180)
  end
 end end
end
