-- Outermost request guard: public workstations never enter facility, map,
-- account or editor handlers, including requests crafted outside the UI.
local P=PLUGIN
local previousLogin,previousSession,previousPage,previousAction=P.Login,P.Session,P.Page,P.Action
local function publicTerminal(ent)
 return IsValid(ent) and ent:GetClass()=='ix_foundation_public_terminal'
end
local function guest()
 return {name='Открытый доступ'}, {clearanceLevel=0,departmentLabel='Библиотека класса D'}
end
function P:Session(p,token)
 local s=self.sessions[p]
 if not s or not s.public then return previousSession(self,p,token) end
 if s.token~=token then return end
 if not publicTerminal(s.entity) or not self:Near(p,s.entity) or s.character~=p:GetCharacter():GetID() or CurTime()>s.idle or CurTime()>s.expires then
  self:EndSession(p);return
 end
 local identity,card=guest()
 return s,identity,card
end
function P:Login(p,ent)
 if not publicTerminal(ent) then return previousLogin(self,p,ent) end
 if not self:Near(p,ent) then return end
 self:EndSession(p)
 local s={public=true,entity=ent,character=p:GetCharacter():GetID(),idle=CurTime()+600,expires=CurTime()+1800,
  token=util.SHA256(tostring(SysTime())..':'..p:SteamID64()..':'..tostring(math.Rand(0,1e9)))}
 self.sessions[p]=s
 local identity,card=guest()
 self:SendPage(p,s,identity,card,'scip://web')
end
function P:Page(p,s,identity,card,route)
 if not s.public then return previousPage(self,p,s,identity,card,route) end
 local id=isstring(route) and route:match('^scip://web/([a-z0-9_%-]+)$')
 local page
 if route=='scip://web' or (id and self.publicWebPages[id]) then
  page=previousPage(self,p,s,identity,card,route)
 else
  page={route='scip://web/unavailable',name=identity.name,department=card.departmentLabel,level=0,token=s.token,
   title='РЕСУРС НЕДОСТУПЕН',body='Этот терминал содержит только открытую документацию класса D и уборщиков.',rows={}}
 end
 page.publicAccess=true;page.webAdmin=false;page.bookmarks=nil
 if route=='scip://web' then
  page.title='БИБЛИОТЕКА КЛАССА D'
  page.body='Должностные инструкции, устав, контракт, жилищные правила и ориентировочные материалы. Ключ-карта не требуется.'
 end
 for _,row in ipairs(page.rows or {}) do row.level=nil;row.accessLabel=nil end
 if page.webDesign then
  page.webDesign.publicAccess=true;page.webDesign.level=0;page.webDesign.accessLabel=nil
 end
 return page
end
function P:Action(p,action,data)
 if not istable(data) then return end
 if action=='login' then return self:Login(p,data.entity) end
 local current=self.sessions[p]
 if not current or not current.public then return previousAction(self,p,action,data) end
 local s,identity,card=self:Session(p,data.token)
 if not s then return end
 if action=='logout' then self:EndSession(p);return end
 if action~='navigate' or not isstring(data.route) or #data.route>140 then return end
 s.idle=CurTime()+600
 self:SendPage(p,s,identity,card,data.route)
end
