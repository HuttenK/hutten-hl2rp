local P=PLUGIN
local previousPage,previousAction=P.Page,P.Action
P.webDepartments={management={id='science',label='Научный отдел',level=3},security={id='security',label='Служба безопасности',level=1}}
P.webMilitaryPages={mtf=true,['security-forces']=true,headquarters=true}
for id in pairs(P.webMilitaryPages) do
 P.webDepartments[id]={id='military',label='Военное подразделение',level=1}
end
P.publicWebPages={['class-d']=true,janitor=true,['d-charter']=true,['d-contract']=true,['d-housing']=true,['d-orientation']=true}
function P:CanReadWeb(card,id,page,s)
 if s and s.public then return self.publicWebPages[id]==true end
 local department=self.webDepartments[id]
 return card.clearanceLevel>=self:WebLevel(id,page) and (not department or card.department==department.id)
end
function P:WebAccessLabel(id,page)
 local department=self.webDepartments[id]
 return 'L'..self:WebLevel(id,page)..(department and (' / '..department.label) or '')
end
local templates={}
for _,v in ipairs(ix.FoundationNet.siteTemplates) do templates[v[1]]=true end
local themes={crimson=true,cyan=true,amber=true,slate=true,green=true}
local images={}
for _,v in ipairs(ix.FoundationNet.siteImages) do images[v[1]]=true end
local function clean(v,max)
 if not isstring(v) or #v>max or v:find('[%z\1-\8\11\12\14-\31]') then return end
 return string.Trim(v)
end
local function slug(v) return isstring(v) and #v>=1 and #v<=40 and v:match('^[a-z0-9][a-z0-9_%-]*$') end
function P:WebPages()
 local changed=self:SeedWebCatalog()
 self.store.webPages=self.store.webPages or {}
 self.store.webSeeds=self.store.webSeeds or {}
 -- Change only the two access levels once; preserve existing articles, hidden
 -- settings, deleted pages and every other administrator edit.
 if self.store.webAccessRevision~='departments-20261002' then
  for id,rule in pairs(self.webDepartments) do
   local page=self.store.webPages[id]
   if page and page.level~=rule.level then
    page.level=rule.level;page.revision=(tonumber(page.revision) or 0)+1
   end
  end
  self.store.webAccessRevision='departments-20261002';changed=true
 end
 -- Existing installations already ran the Science/Security migration.
 if self.store.webMilitaryRevision~='military-20261002' then
  for id in pairs(self.webMilitaryPages) do
   local page=self.store.webPages[id]
   if page and page.level~=1 then
    page.level=1;page.revision=(tonumber(page.revision) or 0)+1
   end
  end
  self.store.webMilitaryRevision='military-20261002';changed=true
 end
 for id,v in pairs(self.store.webPages) do
  if not v.image then v.image='none';changed=true end
  if not v.template then
   v.template='portal';v.theme='slate';changed=true
  end
 end
 if changed then self:SaveData() end
 return self.store.webPages
end
function P:Page(p,s,identity,card,route)
 local admin=not s.public and p.IsAdmin and p:IsAdmin() or false
 local id=route:match('^scip://web/([a-z0-9_%-]+)$')
 local edit=route:match('^scip://editor/([a-z0-9_%-]+)$')
 if route~='scip://web' and route~='scip://editor' and not id and not edit then
  local page=previousPage(self,p,s,identity,card,route);page.webAdmin=admin
  if route=='scip://home' then table.insert(page.rows,1,{title='Браузер внутренних сайтов',url='scip://web'}) end
  return page
 end
 local pages=self:WebPages()
 local page={route=route,name=identity.name,level=card.clearanceLevel,department=card.departmentLabel or '',token=s.token,rows={},webAdmin=admin}
 if route=='scip://web' then
  page.title='АРХИВ УВС-19F';page.body='Служебная документация, досье объектов и инструкции персонала.'
  for key,v in SortedPairs(pages) do if v.published and v.hidden~=true and self:CanReadWeb(card,key,v,s) then
   local meta=self.webCatalog[key]
   page.rows[#page.rows+1]={title=v.title,url='scip://web/'..key,detail=v.summary,image=v.image~='none' and v.image or nil,level=self:WebLevel(key,v),accessLabel=self:WebAccessLabel(key,v),category=meta and meta.category or 'general'}
  end end
 elseif (route=='scip://editor' or edit) and admin then
  page.title='РЕДАКТОР САЙТОВ';page.body='Адрес: латинские буквы, цифры, дефис. Заголовки в тексте начинаются с # . Изменения сохраняются на сервере. Лимиты указаны в байтах UTF-8.'
  if edit and pages[edit] and self:CanReadWeb(card,edit,pages[edit],s) then
   page.webEdit=table.Copy(pages[edit]);page.webEdit.source=nil;page.webEdit.sourceHash=nil;page.webEdit.slug=edit;page.webEdit.level=self:WebLevel(edit,pages[edit]);page.webEdit.minimum=self.webMinimum[edit]
   page.webEdit.accessLabel=self:WebAccessLabel(edit,pages[edit])
  elseif edit then page.title='САЙТ НЕДОСТУПЕН';page.body='Страница не найдена или доступ ограничен.'
  elseif not edit then page.webEdit={slug='',title='',summary='',body='',level=1,published=false,hidden=false,revision=0,links={},template='portal',theme='crimson'} end
  for key,v in SortedPairs(pages) do if self:CanReadWeb(card,key,v,s) then page.rows[#page.rows+1]={title=v.title..(v.published and ' / опубликовано' or ' / черновик')..(v.hidden==true and ' / только по URL' or ''),url='scip://editor/'..key} end end
 elseif id and pages[id] and pages[id].published and self:CanReadWeb(card,id,pages[id],s) then
  local v=pages[id];page.title=v.title;page.body=v.summary
  local meta=self.webCatalog[id] or {}
  -- Keep hidden addresses out of generated navigation as well as the catalog.
  -- Stored links remain intact, so listing the page again restores them.
  local links={}
  for _,link in ipairs(v.links or {}) do
   local target=isstring(link.url) and link.url:match('^scip://web/([a-z0-9_%-]+)$')
   if (not target and not s.public) or (target and pages[target] and pages[target].published and pages[target].hidden~=true and self:CanReadWeb(card,target,pages[target],s)) then links[#links+1]=link end
  end
  local verified=v.source==meta.source and v.title==meta.title and v.summary==meta.summary and v.body==meta.body and v.image==meta.image
  page.webDesign={title=v.title,summary=v.summary,body=v.body,links=links,template=v.template,theme=v.theme,image=v.image,level=self:WebLevel(id,v),revision=v.revision,
   code=verified and meta.code or nil,classification=verified and meta.classification or nil,status=verified and meta.status or nil,
   disruption=verified and meta.disruption or nil,risk=verified and meta.risk or nil,
   documentID=id,accessLabel=self:WebAccessLabel(id,v)}
  for _,link in ipairs(links) do page.rows[#page.rows+1]={title=link.title,url=link.url} end
 else page.title='САЙТ НЕДОСТУПЕН';page.body='Страница не найдена или доступ ограничен.' end
 return page
end
function P:Action(p,action,data)
 if not istable(data) then return end
 local route=isstring(data.route) and data.route or ''
 local webRoute=route=='scip://web' or route=='scip://editor' or route:match('^scip://web/[a-z0-9_%-]+$') or route:match('^scip://editor/[a-z0-9_%-]+$')
 if action~='webSave' and action~='webDelete' and not (action=='navigate' and webRoute) then return previousAction(self,p,action,data) end
 local s,identity,card=self:Session(p,data.token);if not s then return end
 s.idle=CurTime()+600
 if action=='navigate' then return self:SendPage(p,s,identity,card,route) end
 if not p:IsAdmin() then self:Audit(p,'Редактор сайтов','SCiPNet','Отказ','Требуются права администратора');return end
 local pages=self:WebPages();local id=data.slug
 if not slug(id) then p:Notify('Недопустимый адрес сайта.');return end
 local existing=pages[id]
 if not self:CanReadWeb(card,id,existing or {level=1},s) then p:Notify('Требуется карта нужного отдела с достаточным уровнем допуска.');return end
 if (existing and existing.revision or 0)~=data.revision then p:Notify('Страница изменена другим администратором. Откройте её заново.');return end
 if action=='webDelete' then
  if not existing then return end
  pages[id]=nil;self.store.webSeeds[id]=true;route='scip://editor'
 else
  local title,summary,body=clean(data.title,220),clean(data.summary,400),clean(data.body,64000)
  local level=data.level
  local template=data.template or (existing and existing.template) or 'portal'
  local theme=data.theme or (existing and existing.theme) or 'crimson'
  local image=data.image or (existing and existing.image) or 'none'
  -- Old clients omit this field: preserve an existing hidden page on save.
  local hidden=data.hidden
  if hidden==nil then hidden=existing and existing.hidden==true or false end
  if not isbool(hidden) then p:Notify('Выберите видимость сайта: в каталоге или только по URL.');return end
  if not images[image] then p:Notify('Выберите изображение из библиотеки.');return end
  if not templates[template] or not themes[theme] then p:Notify('Выберите шаблон и цветовую тему из списка.');return end
  if not title or title=='' or not summary or not body or not isnumber(level) or level~=math.floor(level) or level<1 or level>4 or not isbool(data.published) or not istable(data.links) or #data.links>32 then p:Notify('Проверьте поля и ограничения длины.');return end
  if level<(self.webMinimum[id] or 1) then p:Notify('Для этого досье требуется минимум L'..self.webMinimum[id]..'.');return end
  if not existing and table.Count(pages)>=128 then p:Notify('Достигнут лимит: 128 сайтов.');return end
  local links={}
  for _,link in ipairs(data.links) do
   if not istable(link) then return end
   local name,url=clean(link.title,220),clean(link.url,100)
   if not name or name=='' or not url or not url:match('^scip://[%w_/%-]+$') then p:Notify('Ссылки должны вести на адрес scip://');return end
   links[#links+1]={title=name,url=url}
  end
  pages[id]={title=title,summary=summary,body=body,level=level,published=data.published,hidden=hidden,links=links,template=template,theme=theme,image=image,revision=(existing and existing.revision or 0)+1,updated=os.time()}
  -- An editor cannot invent source attribution; only exact reviewed content retains it.
  local source=self.webCatalog[id]
  if source and title==source.title and summary==source.summary and body==source.body and image==source.image then pages[id].source=source.source end
  route='scip://editor/'..id
 end
 self:Audit(p,action,id,'Выполнено');self:SaveData();self:SendPage(p,s,identity,card,route,'Сайт сохранён / реестр обновлён.')
end
