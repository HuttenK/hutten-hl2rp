local P=PLUGIN
local N=ix.FoundationNet
for _,name in ipairs({"ixFoundationOpen","ixFoundationRequest","ixFoundationPage","ixFoundationEnd"}) do util.AddNetworkString(name) end
P.store=P.store or {accounts={},documents={},tickets={},nextID=1}
P.sessions={}
local function text(v,max)
 if not isstring(v) or #v>max*4 then return end
 v=string.Trim(v:gsub("[%z\1-\8\11\12\14-\31]",""))
 if #v>max then return end
 return v
end
function P:LoadData()
 local saved=self:GetData(nil,false,true)
 if istable(saved) and istable(saved.accounts) and istable(saved.documents) and istable(saved.tickets) then self.store=saved end
 self.store.nextID=tonumber(self.store.nextID) or 1
 if self.SeedWebCatalog and self:SeedWebCatalog() then self:SaveData() end
end
function P:SaveData() self:SetData(self.store,false,true) end
function P:Identity(p)
 local card=p.GetIDCard and p:GetIDCard()
 local identity=ix.Fieldlink and ix.Fieldlink.CardIdentity(card)
 local level=card and card.clearanceLevel
 if not identity or not isnumber(level) or level~=math.floor(level) or level<1 or level>4 then return end
 return identity,card
end
function P:Near(p,ent)
 if not IsValid(p) or not p:Alive() or not p:GetCharacter() or p:InVehicle() or
  p:GetLocalVar("ragdoll",0)~=0 or p:GetLocalVar("knocked",false) then return false end
 if not IsValid(ent) then return false end
 local facility=ix.Facility and ix.Facility.IsScreen(ent)
 if (ent:GetClass()~="ix_foundation_terminal" and ent:GetClass()~="ix_foundation_public_terminal" and not facility) or p:GetPos():DistToSqr(ent:GetPos())>128^2 then return false end
 if facility then return ix.Facility.Near(p,ent,128) and ent:GetNW2Bool("ixFacilityPowered",false) end
 local blackout=ix.plugin.list.blackout
 if blackout and blackout:IsEntityBlackedOut(ent) then return false end
 local tr=util.TraceLine({start=p:EyePos(),endpos=ent:WorldSpaceCenter(),filter=p,mask=MASK_SOLID})
 return not tr.Hit or tr.Entity==ent
end
function P:EndSession(p)
 self.sessions[p]=nil
 if IsValid(p) then net.Start("ixFoundationEnd");net.Send(p) end
end
function P:Session(p,token)
 local s=self.sessions[p]
 if not s or s.token~=token then return end
 local identity,card=self:Identity(p)
 if not self:Near(p,s.entity) or s.character~=p:GetCharacter():GetID() or not identity or
  s.identity~=identity.id or s.card~=card:GetID() or CurTime()>s.idle or CurTime()>s.expires then
  self:EndSession(p);return
 end
 return s,identity,card
end
function P:Open(p,ent)
 if not self:Near(p,ent) or (p.ixFoundationOpenAt or 0)>CurTime() then return end
 p.ixFoundationOpenAt=CurTime()+1
 self:EndSession(p)
 net.Start("ixFoundationOpen");net.WriteEntity(ent);net.Send(p)
 if ent:GetClass()=="ix_foundation_public_terminal" then self:Login(p,ent) end
end
function P:Login(p,ent)
 if not self:Near(p,ent) then return end
 local identity,card=self:Identity(p)
 if not identity then p:Notify("Экипируйте зарегистрированную ключ-карту Фонда.");return end
 local accounts=self.store.accounts
 if not accounts[identity.id] then
  if table.Count(accounts)>=2000 then p:Notify("Реестр учётных записей заполнен.");return end
  accounts[identity.id]={created=os.time(),notes="",bookmarks={"scip://home","scip://library"}}
 end
 local a=accounts[identity.id];a.name=identity.name;a.cid=identity.cid;a.department=card.departmentLabel or "";a.seen=os.time()
 self:SaveData()
 local s={entity=ent,identity=identity.id,card=card:GetID(),character=p:GetCharacter():GetID(),idle=CurTime()+600,expires=CurTime()+1800,
  token=util.SHA256(tostring(SysTime())..":"..p:SteamID64()..":"..tostring(math.Rand(0,1e9)))}
 self.sessions[p]=s
 local page=ix.Facility and ix.Facility.StartPage(ent)
 self:SendPage(p,s,identity,card,page and ("scip://utilities/"..page) or "scip://home")
end
function P:Page(p,s,identity,card,route)
 local level=math.Clamp(math.floor(card.clearanceLevel),1,4)
 local a=self.store.accounts[identity.id]
 local page={route=route,name=identity.name,level=level,department=card.departmentLabel or "",bookmarks=a.bookmarks,token=s.token,rows={}}
 if route=="scip://home" then
  page.title="ВНУТРЕННЯЯ СЕТЬ ФОНДА";page.body="Защищённый рабочий контур. Выберите ресурс или введите внутренний адрес."
  page.rows={{title="Личный кабинет / удостоверение",url="scip://profile"},{title="Справочник персонала",url="scip://directory"},{title="Документы и внутренние сайты",url="scip://library"},{title="Оперативная сводка FIELDLINK",url="scip://operations"},{title="Личный блокнот",url="scip://notes"},{title="Служебные обращения",url="scip://service"}}
 elseif route=="scip://profile" then
  page.title="ЛИЧНЫЙ КАБИНЕТ";page.profile=Schema:GetCredentialSnapshot(card)
  page.body="Учётная запись: "..identity.cid.."\nПервый вход: "..os.date("%d.%m.%Y",a.created).."\nДоступ подтверждён экипированной ключ-картой."
 elseif route=="scip://directory" then
  page.title="СПРАВОЧНИК ПЕРСОНАЛА";page.body="Сотрудники, зарегистрированные в сети."
  page.search=s.search or ""
  local list={};for _,v in pairs(self.store.accounts) do
   if page.search=="" or string.lower((v.name or "").." "..(v.cid or "")):find(page.search,1,true) then list[#list+1]=v end
  end
  page.body=page.body.."\nНайдено: "..#list..". Показаны первые 80; уточните поиск по имени или номеру."
  table.sort(list,function(x,y) return (x.name or "")<(y.name or "") end)
  for i=1,math.min(#list,80) do local v=list[i];page.rows[#page.rows+1]={title=(v.name or "").." / "..(v.cid or ""),detail=v.department} end
 elseif route=="scip://library" then
  page.title="ДОКУМЕНТЫ И САЙТЫ";page.body="Отображаются ресурсы, доступные по текущему допуску.";page.canPublish=level>=3
  for _,v in ipairs(ix.Fieldlink and ix.Fieldlink.records or {}) do if level>=v.level then page.rows[#page.rows+1]={title=v.title,url="scip://guide/"..v.id,detail=v.tag} end end
  for _,v in ipairs(self.store.documents) do if level>=v.level then page.rows[#page.rows+1]={title=v.title,url="scip://site/"..v.id,detail="Допуск "..v.level.." / "..v.author} end end
 elseif route=="scip://notes" then page.title="ЛИЧНЫЙ БЛОКНОТ";page.notes=a.notes
 elseif route=="scip://service" then
  page.title="СЛУЖЕБНЫЕ ОБРАЩЕНИЯ";page.canManage=level>=3
  for i=#self.store.tickets,1,-1 do local v=self.store.tickets[i]
   if level>=3 or v.owner==identity.id then page.rows[#page.rows+1]={id=v.id,title="#"..v.id.." / "..v.title,detail=v.body,status=v.status,author=v.author};if #page.rows>=20 then break end end
  end
 elseif route=="scip://operations" then
  page.title="ОПЕРАТИВНАЯ СВОДКА"
  local field=ix.plugin.list.site_pda;local state=field and field.state
  page.body=state and ((ix.Fieldlink.alerts[state.alert.level] or "").."\n"..(state.alert.message or "")) or "Оперативный канал недоступен."
  for _,v in ipairs(state and state.directives or {}) do if level>=(v.level or 0) and #page.rows<30 then page.rows[#page.rows+1]={title=v.title or "Директива",detail=v.text or v.body or ""} end end
 else
  local guide=route:match("^scip://guide/([%w_%-]+)$")
  local id=tonumber(route:match("^scip://site/(%d+)$"))
  for _,v in ipairs(guide and (ix.Fieldlink and ix.Fieldlink.records or {}) or self.store.documents) do
   if ((guide and v.id==guide) or (id and v.id==id)) and level>=v.level then
    page.title=v.title;page.body=v.body
    if id and level>=3 then page.editDocument={id=v.id,title=v.title,body=v.body,level=v.level} end
    break
   end
  end
  if not page.title then page.title="РЕСУРС НЕДОСТУПЕН";page.body="Адрес не найден или требуется другой уровень допуска." end
 end
 return page
end
function P:SendPage(p,s,identity,card,route,message)
 local data=self:Page(p,s,identity,card,route);data.message=message
 local raw=util.TableToJSON(data);if not raw or #raw>180000 then return end
 local packed=util.Compress(raw);if not packed or #packed>60000 then return end
 net.Start("ixFoundationPage");net.WriteUInt(#packed,16);net.WriteData(packed,#packed);net.Send(p)
end
function P:Action(p,action,payload)
 if not istable(payload) then return end
 if action=="login" then return self:Login(p,payload.entity) end
 local s,identity,card=self:Session(p,payload.token);if not s then return end
 if action=="logout" then self:EndSession(p);return end
 local route=text(payload.route,140) or "scip://home";local a=self.store.accounts[identity.id]
 s.idle=CurTime()+600
 if action=="notes" then local value=text(payload.text,4000);if not value then return end;a.notes=value;self:SaveData();route="scip://notes"
 elseif action=="bookmark" then
  if not route:match("^scip://[%w_/%-]+$") or #a.bookmarks>=12 then return end
  for _,v in ipairs(a.bookmarks) do if v==route then return end end
  a.bookmarks[#a.bookmarks+1]=route;self:SaveData()
 elseif action=="search" then
  local value=text(payload.text,80);if not value then return end;s.search=string.lower(value);route="scip://directory"
 elseif action=="editDocument" then
  if card.clearanceLevel<3 then return end
  local title,body=text(payload.title,100),text(payload.body,6000);local level=tonumber(payload.level)
  if not title or title=="" or not body or body=="" or not level or level~=math.floor(level) or level<1 or level>card.clearanceLevel then return end
  for _,v in ipairs(self.store.documents) do
   if v.id==payload.id and v.level<=card.clearanceLevel then
    v.title=title;v.body=body;v.level=level;v.author=identity.name;self:SaveData();route="scip://site/"..v.id;break
   end
  end
 elseif action=="publish" then
  if card.clearanceLevel<3 or #self.store.documents>=60 then return end
  local title,body=text(payload.title,100),text(payload.body,6000);local level=tonumber(payload.level)
  if not title or title=="" or not body or body=="" or not level or level~=math.floor(level) or level<1 or level>card.clearanceLevel then return end
  local id=self.store.nextID;self.store.nextID=id+1
  self.store.documents[#self.store.documents+1]={id=id,title=title,body=body,level=level,author=identity.name};self:SaveData();route="scip://site/"..id
 elseif action=="ticket" then
  local title,body=text(payload.title,100),text(payload.body,800)
  if not title or title=="" or not body or body=="" then return end
  local open=0;for _,v in ipairs(self.store.tickets) do if v.owner==identity.id and v.status~="Закрыто" then open=open+1 end end
  if open>=5 then p:Notify("Сначала закройте текущие обращения (не более пяти).");return end
  if #self.store.tickets>=200 then
   local removed=false;for i,v in ipairs(self.store.tickets) do if v.status=="Закрыто" then table.remove(self.store.tickets,i);removed=true;break end end
   if not removed then p:Notify("Очередь обращений заполнена.");return end
  end
  local id=self.store.nextID;self.store.nextID=id+1
  self.store.tickets[#self.store.tickets+1]={id=id,title=title,body=body,owner=identity.id,author=identity.name,status="Открыто"};self:SaveData();route="scip://service"
 elseif action=="closeTicket" then
  for _,v in ipairs(self.store.tickets) do if v.id==payload.id and (card.clearanceLevel>=3 or v.owner==identity.id) then v.status="Закрыто";self:SaveData();break end end
  route="scip://service"
 elseif action~="navigate" then return end
 self:SendPage(p,s,identity,card,route,action~="navigate" and "Изменения сохранены." or nil)
end
net.Receive("ixFoundationRequest",function(bits,p)
 if bits>500000 then return end
 local action=net.ReadString()
 if action~="logout" and (p.ixFoundationRequestAt or 0)>CurTime() then return end
 p.ixFoundationRequestAt=CurTime()+.25
 local entity=net.ReadEntity();local size=net.ReadUInt(16)
 if size<1 or size>60000 then return end
 local packed=net.ReadData(size);if not packed then return end
 local raw=util.Decompress(packed,100000);if not raw or #raw>100000 then return end
 local payload=util.JSONToTable(raw);if not istable(payload) then return end
 payload.entity=entity;P:Action(p,action,payload)
end)
timer.Create("ixFoundationSessions",1,0,function()
 for p,s in pairs(P.sessions) do if not IsValid(p) then P.sessions[p]=nil else P:Session(p,s.token) end end
end)
function P:PlayerDisconnected(p) self.sessions[p]=nil end
function P:PlayerLoadedCharacter(p) self:EndSession(p) end
