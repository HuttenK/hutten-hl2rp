local P=PLUGIN
local oldPage,oldAction,oldLogin,oldEnd=P.Page,P.Action,P.Login,P.EndSession
local routes={['scip://home']=true,['scip://power']=true,['scip://infection']=true,['scip://logs']=true,['scip://service']=true}
local function count(t) local n=0 for ent in pairs(t or {}) do if IsValid(ent) then n=n+1 end end return n end
local function AreaPowerOff(area, power)
 if not power then return false end
 for _, box in ipairs(ix.area.GetVolumes(area)) do
  if (power.IsElectronicsOffAt or power.IsPosBlackedOut)(power,(box.min+box.max)*.5) then return true end
 end
 return false
end
function P:Audit(p,kind,target,result,reason)
 self.store.audit=self.store.audit or {}
 local identity=self:Identity(p)
 local row={time=os.time(),map=game.GetMap(),actor=identity and identity.name or 'Неизвестная карта',cid=identity and identity.cid or '',kind=kind,target=tostring(target),result=result,reason=reason or ''}
 table.insert(self.store.audit,1,row)
 while #self.store.audit>300 do table.remove(self.store.audit) end
 self.auditDirty=true
end
function P:Login(p,ent)
 local near=self:Near(p,ent)
 if self.sessions[p] then self:EndSession(p) end
 oldLogin(self,p,ent)
 if near then self:Audit(p,'Вход',IsValid(ent) and ent:EntIndex() or '?',self.sessions[p] and 'Разрешён' or 'Отказ') end
end
function P:EndSession(p)
 if self.sessions[p] then self:Audit(p,'Сеанс','Терминал','Завершён') end
 oldEnd(self,p)
end
function P:FoundationDoorAccess(p,ent,allowed,reason)
 if IsValid(p) and p:IsPlayer() then self:Audit(p,'Дверь',ent:EntIndex(),allowed and 'Разрешён' or 'Отказ',reason) end
end
function P:Page(p,s,identity,card,route)
 if route=='scip://service' then
  local page=oldPage(self,p,s,identity,card,route);page.bookmarks=nil;page.title='ЗАЯВКИ НА ОБСЛУЖИВАНИЕ'
  table.insert(page.rows,1,{title='Работы у оборудования',detail='Назначение, место и физическое обслуживание.',url='scip://utilities/jobs'});return page
 end
 local page={route=route,name=identity.name,level=card.clearanceLevel,department=card.departmentLabel or '',token=s.token,rows={}}
 local power=ix.plugin.list.blackout;local infection=ix.plugin.list.infectionzone
 if route=='scip://home' then
  page.title='ДИСПЕТЧЕРСКАЯ ОБЪЕКТА';page.body='Стационарное управление инфраструктурой. L1+: диагностика и заявки. L3+: команды и журнал. Обновите страницу для получения свежих показаний.'
  page.rows={{title='Электроснабжение',url='scip://power'},{title='Биологические зоны',url='scip://infection'},{title='Журнал доступа и команд',url='scip://logs'},{title='Технические заявки',url='scip://service'}}
 elseif route=='scip://power' then
  page.title='ЭЛЕКТРОСНАБЖЕНИЕ';page.body=power and 'Изоляция отключает цепь. Возврат питания не ремонтирует повреждённые щитки. Обесточенный терминал недоступен: восстановление — с другого терминала.' or 'Контроллер электроснабжения не установлен.'
  for name,z in SortedPairs(power and power.zones or {}) do
   local boxes=power:BoxesInZone(z);local broken=0 for _,box in ipairs(boxes) do if box:GetBroken() then broken=broken+1 end end
   local row={title=name,detail=(z.active and 'НЕТ ПИТАНИЯ' or 'ПИТАНИЕ ЕСТЬ')..' / повреждено щитков: '..broken..' из '..#boxes..(z.remoteIsolation and ' / дистанционная изоляция' or '')}
   if card.clearanceLevel>=3 then row.control={action=z.remoteIsolation and 'restore' or 'isolate',zone=name,label=z.remoteIsolation and 'Вернуть цепь в работу' or 'Изолировать цепь'} end
   page.rows[#page.rows+1]=row
  end
 elseif route=='scip://infection' then
  page.title='БИОЛОГИЧЕСКИЙ КОНТРОЛЬ';page.body=infection and 'Подавление останавливает новый рост флоры на 120 секунд. Газ, существующая флора и заражённые остаются опасными. Повторный цикл доступен через 5 минут. При потере питания зоны цикл прекращается.' or 'Датчики заражения недоступны.'
  for name,area in SortedPairs(infection and ix.area.stored or {}) do if area.type=='infection' then
   local props=area.properties or {};local untilTime=(infection.suppressed or {})[name] or 0
   local row={title=name,detail='Флора: '..count(infection.flora[name])..' / заражённые: '..count(infection.zombies[name])..' / остаток сбора: '..tostring(infection.remaining[name] or props.infestationTotal or infection.defaults.infestationTotal)..(props.indestructible and ' / постоянный очаг' or '')..' / подавление: '..math.max(0,math.ceil(untilTime-CurTime()))..' с'}
   if card.clearanceLevel>=3 then row.control={action='suppress',zone=name,label='Запустить подавление роста (120 с)'} end
   page.rows[#page.rows+1]=row
  end end
 elseif route=='scip://logs' and card.clearanceLevel>=3 then
  page.title='ЖУРНАЛ ДОСТУПА И КОМАНД';page.body='Последние 100 из 300 сохраняемых событий. Входы, завершения сеансов, попытки доступа через замки и команды инфраструктуры.'
  for i,row in ipairs(self.store.audit or {}) do if i>100 then break end
   page.rows[#page.rows+1]={title=os.date('%d.%m %H:%M:%S',row.time)..' / '..row.kind..' / '..row.result,detail=row.actor..' ['..row.cid..'] / '..row.map..' / '..row.target..' / '..row.reason}
  end
 else page.title='ДОСТУП ЗАКРЫТ';page.body='Ресурс недоступен. Функции PDA доступны только на PDA.' end
 return page
end
function P:Action(p,action,payload)
 if not istable(payload) then return end
 if action=='login' or action=='logout' or action=='ticket' or action=='closeTicket' then return oldAction(self,p,action,payload) end
 local s,identity,card=self:Session(p,payload.token);if not s then return end
 if action=='navigate' then
  local route=routes[payload.route] and payload.route or 'scip://home'
  s.idle=CurTime()+600;return self:SendPage(p,s,identity,card,route)
 end
 if action~='facility' then return end
 local reason=isstring(payload.reason) and string.Trim(payload.reason):gsub('[%c]',' ') or ''
 local zone=isstring(payload.zone) and payload.zone or ''
 if #zone>200 or #reason<5 or #reason>240 then p:Notify('Укажите причину: 5–240 байт.');return end
 if card.clearanceLevel<3 then self:Audit(p,'Команда',zone,'Отказ','Недостаточный допуск');return end
 if (s.nextControl or 0)>CurTime() then return end
 s.nextControl=CurTime()+2;s.idle=CurTime()+600
 local power=ix.plugin.list.blackout;local inf=ix.plugin.list.infectionzone
 local ok=false;local route='scip://power'
 if payload.command=='isolate' or payload.command=='restore' then
  local z=power and power.zones[zone]
  if z then
   if payload.command=='isolate' and not z.remoteIsolation then z.remotePrevious=z.active;z.remoteIsolation=true;z.active=true;ok=true
   elseif payload.command=='restore' and z.remoteIsolation then z.active=z.remotePrevious==true;z.remoteIsolation=nil;z.remotePrevious=nil;power:RecomputeZones();ok=true end
   if ok then power:SetZoneLights();power:NetworkZones();power:SaveData() end
  end
 elseif payload.command=='suppress' then
  route='scip://infection';local area=ix.area.stored[zone]
  self.cycles=self.cycles or {};self.cycleCooldown=self.cycleCooldown or {}
  if inf and area and area.type=='infection' and (self.cycleCooldown[zone] or 0)<=CurTime() and not AreaPowerOff(area,power) then
   local expires=CurTime()+120
   inf.suppressed[zone]=math.max(inf.suppressed[zone] or 0,expires)
   self.cycles[zone]=expires;self.cycleCooldown[zone]=CurTime()+300;ok=true
  end
 end
 self:Audit(p,payload.command or 'Команда',zone,ok and 'Выполнено' or 'Отказ',reason)
 self:SaveData();self.auditDirty=false
 self:SendPage(p,s,identity,card,route,ok and 'Команда выполнена.' or 'Команда отклонена: проверьте зону, питание и интервал циклов.')
end
timer.Create('FoundationFacilityMaintenance',1,0,function()
 local inf=ix.plugin.list.infectionzone;local power=ix.plugin.list.blackout
 for name,expires in pairs(P.cycles or {}) do
  local area=ix.area.stored[name]
  if not inf or not area or CurTime()>=expires or AreaPowerOff(area,power) then
   if inf and inf.suppressed[name]==expires then inf.suppressed[name]=nil end
   P.cycles[name]=nil
  end
 end
 if P.auditDirty and (P.nextAuditSave or 0)<=CurTime() then P:SaveData();P.auditDirty=false;P.nextAuditSave=CurTime()+10 end
end)
