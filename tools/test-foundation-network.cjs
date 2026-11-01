module.exports=function(suite){
const files=['ixhl2rp/plugins/site_pda/sh_fieldlink.lua','ixhl2rp/plugins/site_pda/sh_identity.lua','ixhl2rp/plugins/foundation_network/sv_network.lua'];
const setup=require('fs').readFileSync(require('path').join(__dirname,'geometry-fixture.lua'),'utf8')+`
 ix.FoundationNet={};Schema={GetCredentialSnapshot=function(_,c) return {name=c.data.name,number=c.data.number} end}
 serial=0;function SysTime() serial=serial+1 return serial end;math.Rand=function() return .5 end
 util.SHA256=function(v) return v end;util.TraceLine=function() return {Hit=blocked,Entity=nil} end
 util.TableToJSON=function(v) snapshot=v;return '{}' end;util.Compress=function(v) return v end
 net.Start=function() end;net.Send=function() end;net.WriteUInt=function() end;net.WriteData=function() end
 function table.Count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
 PLUGIN.SetData=function(self,d) saved=d end;PLUGIN.GetData=function() return nil end
 MASK_SOLID=1;blocked=false;distance=0;blackout=false
 ix.plugin.list.blackout={IsEntityBlackedOut=function() return blackout end}
 terminal={valid=true,GetClass=function() return 'ix_foundation_terminal' end,GetPos=function() return {} end,WorldSpaceCenter=function() return {} end}
 card={isKeycard=true,clearanceLevel=1,departmentLabel='Science',data={name='Alice',cid='42',number='SERIAL42'},GetData=function(self,k,d) if self.data[k]~=nil then return self.data[k] end return d end,GetID=function() return 12 end}
 char={GetID=function() return 7 end};person={valid=true,Alive=function() return true end,GetCharacter=function() return char end,
 InVehicle=function() return false end,GetLocalVar=function(_,k,d) return d end,GetIDCard=function() return card end,
 EyePos=function() return {} end,GetPos=function() return {DistToSqr=function() return distance end} end,
 SteamID64=function() return 'test' end,Notify=function(_,v) notice=v end}
 `;
suite('Foundation accounts reject missing/revoked cards, distance, obstruction, blackout and changed identity',files,`
 local p=PLUGIN
 p:Login(person,terminal);assert(p.sessions[person]);eq(snapshot.name,'Alice');eq(snapshot.route,'scip://home')
 local s=p.sessions[person];assert(p:Session(person,s.token));eq(p:Session(person,'forged'),nil)
 distance=200^2;eq(p:Session(person,s.token),nil);eq(p.sessions[person],nil);distance=0
 blocked=true;p:Login(person,terminal);eq(p.sessions[person],nil);blocked=false
 blackout=true;p:Login(person,terminal);eq(p.sessions[person],nil);blackout=false
 card.data.revoked=true;p:Login(person,terminal);eq(p.sessions[person],nil);card.data.revoked=false
 card.isKeycard=false;p:Login(person,terminal);eq(p.sessions[person],nil);card.isKeycard=true
 card.clearanceLevel=0/0;p:Login(person,terminal);eq(p.sessions[person],nil);card.clearanceLevel=1
 p:Login(person,terminal);s=p.sessions[person];card.data.number='OTHER';eq(p:Session(person,s.token),nil);card.data.number='SERIAL42'
 p:Login(person,terminal);s=p.sessions[person];clock=s.idle+1;eq(p:Session(person,s.token),nil)
 `,setup);
suite('Foundation documents enforce live clearance; private notes and tickets stay in their account',files,`
 local p=PLUGIN;p:Login(person,terminal);local s=p.sessions[person]
 p.store.documents={{id=9,title='Restricted',body='SECRET',level=3,author='Command'}}
 p:Action(person,'navigate',{token=s.token,route='scip://site/9'});assert(snapshot.body~='SECRET')
 p:Action(person,'publish',{token=s.token,title='Forged',body='body',level=1});eq(#p.store.documents,1)
 p:Action(person,'notes',{token=s.token,text='personal'});eq(p.store.accounts[s.identity].notes,'personal')
 p:Action(person,'ticket',{token=s.token,title='Repair',body='Door fault'});eq(#p.store.tickets,1)
 p.store.tickets[2]={id=77,owner='another',title='Private',body='OTHER SECRET',author='Bob',status='Open'}
 p:Action(person,'navigate',{token=s.token,route='scip://service'});eq(#snapshot.rows,1)
 p:Action(person,'closeTicket',{token=s.token,id=77});eq(p.store.tickets[2].status,'Open')
 card.clearanceLevel=3;p:Action(person,'navigate',{token=s.token,route='scip://site/9'});eq(snapshot.body,'SECRET')
 p:Action(person,'publish',{token=s.token,title='New',body='Content',level=4});eq(#p.store.documents,1)
 p:Action(person,'publish',{token=s.token,title='New',body='Content',level=2});eq(#p.store.documents,2)
 p:Action(person,'editDocument',{token=s.token,id=9,title='Updated',body='Revised',level=3});eq(p.store.documents[1].body,'Revised')
 p:Action(person,'search',{token=s.token,text='alice'});eq(#snapshot.rows,1)
 p:Action(person,'search',{token=s.token,text='missing'});eq(#snapshot.rows,0)
 card.clearanceLevel=1;p:Action(person,'navigate',{token=s.token,route='scip://site/9'});assert(snapshot.body~='SECRET')
 p:Action(person,'editDocument',{token=s.token,id=9,title='Attack',body='Changed',level=1});eq(p.store.documents[1].body,'Revised')
 card.data.number='BOB';card.data.name='Bob';p:Login(person,terminal);local b=p.sessions[person]
 p:Action(person,'navigate',{token=b.token,route='scip://notes'});eq(snapshot.notes,'')
 p:Action(person,'logout',{token=b.token});eq(p.sessions[person],nil)
 `,setup);
suite('Facility terminal separates PDA routes and enforces live clearance, power control, suppression and audit',files.concat(['helix/plugins/area/sh_geometry.lua','ixhl2rp/plugins/foundation_network/sv_facility.lua']),`
 local p=PLUGIN;p:Login(person,terminal);local s=p.sessions[person]
 assert(p.store.audit[1].kind=='Вход')
 p:Action(person,'navigate',{token=s.token,route='scip://profile'});eq(snapshot.route,'scip://home')
 p:Action(person,'notes',{token=s.token,text='forged'});eq(p.store.accounts[s.identity].notes,'')
 p:Action(person,'navigate',{token=s.token,route='scip://logs'});eq(#snapshot.rows,0)
 local data={token=s.token,zone='Lab',command='isolate',reason='Maintenance test'}
 p:Action(person,'facility',data);assert(not grid.zones.Lab.active)
 card.clearanceLevel=3;p:Action(person,'facility',data);assert(grid.zones.Lab.active);assert(grid.zones.Lab.remoteIsolation)
 clock=clock+3;data.command='restore';p:Action(person,'facility',data);assert(not grid.zones.Lab.active);assert(not grid.zones.Lab.remoteIsolation)
 clock=clock+3;data.command='suppress';p:Action(person,'facility',data);eq(inf.suppressed.Lab,clock+120)
 local expiry=inf.suppressed.Lab;clock=clock+3;p:Action(person,'facility',data);eq(inf.suppressed.Lab,expiry)
 grid.IsPosBlackedOut=function() return true end;maintenance();eq(inf.suppressed.Lab,nil)
 clock=clock+301;p:Action(person,'facility',data);eq(inf.suppressed.Lab,nil)
 p:Action(person,'navigate',{token=s.token,route='scip://logs'});assert(#snapshot.rows>0)
 eq(p.store.audit[1].reason,'Maintenance test')
 `,setup+`
 game={GetMap=function() return 'testmap' end};terminal.EntIndex=function() return 10 end
 SortedPairs=pairs
 grid=ix.plugin.list.blackout;grid.zones={Lab={active=false}}
 grid.BoxesInZone=function() return {} end;grid.SetZoneLights=function() end;grid.NetworkZones=function() end;grid.SaveData=function() end;grid.RecomputeZones=function() end
 grid.IsPosBlackedOut=function() return false end
 inf={suppressed={},flora={},zombies={},remaining={},defaults={infestationTotal=5}};ix.plugin.list.infectionzone=inf
 ix.area={stored={Lab={type='infection',startPosition=Vector(),endPosition=Vector(2,2,2),properties={}}}}
 timer.Create=function(name,delay,n,fn) if name=='FoundationFacilityMaintenance' then maintenance=fn end end
 `);
const webFiles=files.concat(['ixhl2rp/plugins/foundation_network/sh_webstyles.lua','ixhl2rp/plugins/foundation_network/sv_catalog.lua','ixhl2rp/plugins/foundation_network/sv_facility.lua','ixhl2rp/plugins/foundation_network/sv_web.lua']);
const webSetup=setup+`resource={AddFile=function() end};game={GetMap=function() return 'testmap' end};terminal.EntIndex=function() return 10 end;SortedPairs=pairs;function isbool(v) return type(v)=='boolean' end`;
suite('Department pages enforce live Science, Security and Military cards across catalog, URL, links and editor',webFiles,`
 local p=PLUGIN;person.IsAdmin=function() return true end
 p:Login(person,terminal);local s=p.sessions[person]
 local function page(id) p:Action(person,'navigate',{token=s.token,route='scip://web/'..id});return snapshot end
 for _,rule in ipairs({{'management','science',3},{'security','security',1},{'mtf','military',1},{'security-forces','military',1},{'headquarters','military',1}}) do
  card.department=rule[2];card.clearanceLevel=rule[3];assert(page(rule[1]).webDesign)
  card.clearanceLevel=rule[3]-1
  -- L0 is an invalid private card; test the level rule without constructing a session.
  eq(p:CanReadWeb(card,rule[1],p:WebPages()[rule[1]],s),false)
  card.clearanceLevel=4;card.department=rule[2]=='military' and 'science' or 'military';eq(page(rule[1]).webDesign,nil)
  p:Action(person,'navigate',{token=s.token,route='scip://web'})
  for _,row in ipairs(snapshot.rows) do assert(row.url~='scip://web/'..rule[1]) end
  p:Action(person,'navigate',{token=s.token,route='scip://editor/'..rule[1]});eq(snapshot.webEdit,nil)
  local current=p.store.webPages[rule[1]]
  p:Action(person,'webDelete',{token=s.token,slug=rule[1],revision=current.revision});eq(p.store.webPages[rule[1]],current)
  p.store.webPages.welcome.links={{title='restricted',url='scip://web/'..rule[1]}}
  eq(#page('welcome').webDesign.links,0)
  card.department=rule[2];assert(page(rule[1]).webDesign);assert(snapshot.webDesign.accessLabel:find('L'..rule[3],1,true))
 end
 -- Only access levels migrate. Admin body edits and removed pages survive a reload.
 local pages=p:WebPages();pages.management.body='Administrator article';pages.management.level=2;pages.management.hidden=true
 pages.security.level=2;local revision=pages.management.revision;p.store.webAccessRevision=nil
 p:WebPages();eq(pages.management.level,3);eq(pages.security.level,1);eq(pages.management.body,'Administrator article')
 eq(pages.management.hidden,true);eq(pages.management.revision,revision+1)
 pages.security=nil;p.store.webAccessRevision=nil;p:WebPages();eq(pages.security,nil)
 `,webSetup);
const publicFiles=webFiles.concat(['ixhl2rp/plugins/foundation_network/sv_map.lua','ixhl2rp/plugins/foundation_network/sv_public.lua']);
const publicSetup=webSetup+`
 net.WriteEntity=function() end;person.IsAdmin=function() return true end
 publicTerminal=table.Copy(terminal);publicTerminal.GetClass=function() return 'ix_foundation_public_terminal' end
 person.GetIDCard=function() return nil end
 `;
suite('Public terminal opens without a card and isolates every non-public route, link and mutation',publicFiles,`
 local p=PLUGIN;p:Open(person,publicTerminal);local s=p.sessions[person]
 assert(s and s.public);eq(snapshot.publicAccess,true);eq(snapshot.route,'scip://web');eq(#snapshot.rows,6)
 eq(snapshot.webAdmin,false);eq(table.Count(p.store.accounts),0)
 for _,row in ipairs(snapshot.rows) do assert(p.publicWebPages[row.url:match('^scip://web/(.+)$')]);eq(row.level,nil) end
 for id in pairs(p.publicWebPages) do
  p:Action(person,'navigate',{token=s.token,route='scip://web/'..id})
  assert(snapshot.webDesign and #snapshot.webDesign.body>100);eq(snapshot.webDesign.publicAccess,true)
  for _,link in ipairs(snapshot.webDesign.links) do assert(p.publicWebPages[link.url:match('^scip://web/(.+)$')]) end
 end
 p.MapSnapshot=function() error('Public terminal requested telemetry') end
 for _,route in ipairs({'scip://home','scip://power','scip://infection','scip://logs','scip://map','scip://service','scip://profile','scip://notes','scip://editor','scip://editor/class-d','scip://web/scp-079','scip://web/management','scip://web/security'}) do
  p:Action(person,'navigate',{token=s.token,route=route})
  eq(snapshot.webDesign,nil);eq(snapshot.webEdit,nil);eq(snapshot.mapData,nil);eq(#snapshot.rows,0);eq(snapshot.publicAccess,true)
  eq(snapshot.route,'scip://web/unavailable')
 end
 local page=p.store.webPages['class-d'];local before=snapshot
 for _,action in ipairs({'webSave','webDelete','facility','mapSync','ticket','publish','notes','bookmark','closeTicket','editDocument','search'}) do
  p:Action(person,action,{token=s.token,entity=terminal,public=false,slug='class-d',revision=page.revision,command='isolate',zone='Lab',reason='FORGED',title='FORGED',body='FORGED'})
  eq(snapshot,before);eq(p.store.webPages['class-d'],page);eq(#p.store.tickets,0);eq(table.Count(p.store.accounts),0)
 end
 p:Action(person,'navigate',{token='forged',route='scip://web'});eq(snapshot,before)
 -- Cardless public use must never grant access to the private workstation.
 p:Action(person,'login',{entity=terminal});eq(p.sessions[person],nil)
 `,publicSetup);
suite('Public terminal respects drafts, hidden URLs, session expiry, power, character and proximity',publicFiles,`
 local p=PLUGIN
 local function login() p:Login(person,publicTerminal);assert(p.sessions[person]);return p.sessions[person] end
 local s=login();local pages=p:WebPages();pages['class-d'].hidden=true;pages.janitor.published=false
 p:Action(person,'navigate',{token=s.token,route='scip://web'});eq(#snapshot.rows,4)
 p:Action(person,'navigate',{token=s.token,route='scip://web/class-d'});assert(snapshot.webDesign)
 p:Action(person,'navigate',{token=s.token,route='scip://web/janitor'});eq(snapshot.webDesign,nil)
 distance=129^2;eq(p:Session(person,s.token),nil);distance=0
 s=login();blackout=true;eq(p:Session(person,s.token),nil);p:Login(person,publicTerminal);eq(p.sessions[person],nil);blackout=false
 s=login();blocked=true;eq(p:Session(person,s.token),nil);blocked=false
 s=login();char.GetID=function() return 8 end;eq(p:Session(person,s.token),nil)
 s=login();person.Alive=function() return false end;eq(p:Session(person,s.token),nil);person.Alive=function() return true end
 s=login();clock=s.idle+1;eq(p:Session(person,s.token),nil)
 s=login();clock=s.expires+1;eq(p:Session(person,s.token),nil)
 s=login();p:Action(person,'logout',{token=s.token});eq(p.sessions[person],nil)
 `,publicSetup);
const knowledgeArticles=require('./funclub-full-articles.json').filter(a=>/^# (?:Не знает|Знает)$/m.test(a.body));
const oldKnowledgePages=knowledgeArticles.map(a=>`[${JSON.stringify(a.slug)}]=${JSON.stringify(a.body)}`).join(',');
const cleanKnowledgePages=knowledgeArticles.map(a=>`[${JSON.stringify(a.slug)}]=${JSON.stringify(a.body.split('\n# Знает')[0])}`).join(',');
suite('Both terminals omit player knowledge rules; saved articles migrate without losing edits, visibility or deleted pages',publicFiles,`
 local p=PLUGIN;p:LoadData();local pages=p:WebPages()
 eq(table.Count(oldKnowledgePages),9)
 for id,expected in pairs(cleanKnowledgePages) do eq(pages[id].body,expected) end
 for id,body in pairs(oldKnowledgePages) do pages[id].body=body;pages[id].revision=20 end
 pages.research.hidden=true;pages.research.published=false;pages.research.theme='amber'
 pages.research.links={{title='Keep link',url='scip://web/welcome'}}
 pages['scp-173']=nil
 local custom='# Duties\\nAdmin text mentions Не знает without a heading.\\n## ЗНАЕТ: ##\\nRemove this list.\\n### Details\\nRemove child too.\\n## Next section\\nKeep next section.\\n# Не знает\\nRemove second list.\\n# Procedures\\nKeep procedures.'
 pages.custom={body=custom,title='Admin document',revision=7,published=false,hidden=true,level=4}
 local untouched=pages['scp-049'].body;local untouchedRevision=pages['scp-049'].revision
 p.store.webKnowledgeRevision=nil;p:LoadData()
 for id,expected in pairs(cleanKnowledgePages) do
  eq(pages[id].body,expected);eq(pages[id].revision,21)
  eq(p.store.webKnowledgeBackups[id].body,oldKnowledgePages[id])
 end
 eq(pages.custom.body,'# Duties\\nAdmin text mentions Не знает without a heading.\\n## Next section\\nKeep next section.\\n# Procedures\\nKeep procedures.')
 eq(pages.custom.revision,8);eq(p.store.webKnowledgeBackups.custom.body,custom)
 eq(pages.research.hidden,true);eq(pages.research.published,false);eq(pages.research.theme,'amber')
 eq(pages.research.links[1].title,'Keep link');eq(pages['scp-173'],nil)
 eq(pages['scp-049'].body,untouched);eq(pages['scp-049'].revision,untouchedRevision)
 p.GetData=function() return saved end;p:LoadData();p:WebPages();eq(pages.custom.revision,8)
 person.GetIDCard=function() return card end;card.clearanceLevel=2;p:Login(person,terminal)
 local s=p.sessions[person]
 for _,id in ipairs({'class-d','janitor'}) do
  p:Action(person,'navigate',{token=s.token,route='scip://web/'..id})
  eq(snapshot.webDesign.body,cleanKnowledgePages[id]);eq(snapshot.webKnowledgeBackups,nil)
 end
 person.GetIDCard=function() return nil end;p:Login(person,publicTerminal);s=p.sessions[person]
 for _,id in ipairs({'class-d','janitor'}) do
  p:Action(person,'navigate',{token=s.token,route='scip://web/'..id})
  eq(snapshot.webDesign.body,cleanKnowledgePages[id]);eq(snapshot.webDesign.publicAccess,true)
 end
 `,publicSetup+`;oldKnowledgePages={${oldKnowledgePages}};cleanKnowledgePages={${cleanKnowledgePages}};`);
suite('Military articles migrate to L1, reject other departments at every level and stay closed on public terminals',publicFiles,`
 local p=PLUGIN;p:LoadData();local pages=p:WebPages()
 for id in pairs(p.webMilitaryPages) do pages[id].level=3 end
 pages.headquarters.hidden=true;pages.headquarters.body='Keep admin headquarters text'
 p.store.webMilitaryRevision=nil;p:WebPages()
 for id in pairs(p.webMilitaryPages) do eq(pages[id].level,1) end
 eq(pages.headquarters.hidden,true);eq(pages.headquarters.body,'Keep admin headquarters text')
 person.GetIDCard=function() return card end;p:Login(person,terminal);local s=p.sessions[person]
 for _,department in ipairs({'science','security','military'}) do for level=1,4 do
  card.department=department;card.clearanceLevel=level
  for id in pairs(p.webMilitaryPages) do
   p:Action(person,'navigate',{token=s.token,route='scip://web/'..id})
   eq(snapshot.webDesign~=nil,department=='military')
   if snapshot.webDesign then eq(snapshot.webDesign.level,1);assert(snapshot.webDesign.accessLabel:find('Военное подразделение',1,true)) end
  end
 end end
 person.GetIDCard=function() return nil end;p:Login(person,publicTerminal);s=p.sessions[person]
 for id in pairs(p.webMilitaryPages) do
  p:Action(person,'navigate',{token=s.token,route='scip://web/'..id});eq(snapshot.webDesign,nil)
 end
 pages.headquarters=nil;p.store.webMilitaryRevision=nil;p:WebPages();eq(pages.headquarters,nil)
 `,publicSetup);
suite('Internal browser enforces drafts, card clearance, admin edits, validation, revisions and persistence',webFiles,`
 local p=PLUGIN;person.IsAdmin=function() return false end;p:Login(person,terminal);local s=p.sessions[person]
 p:Action(person,'navigate',{token=s.token,route='scip://web'});eq(#snapshot.rows,17)
 p:Action(person,'navigate',{token=s.token,route='scip://web/welcome'});eq(snapshot.webDesign.template,'portal');eq(snapshot.webDesign.theme,'slate')
 p:Action(person,'navigate',{token=s.token,route='scip://web/medical'});eq(snapshot.webBody,nil);eq(snapshot.webDesign,nil)
 card.clearanceLevel=2;p:Action(person,'navigate',{token=s.token,route='scip://web/medical'});assert(snapshot.webDesign and snapshot.webDesign.body)
 local d={token=s.token,slug='new-site',revision=0,title='Test',summary='Summary',body='# Test\\nText',level=1,published=false,links={{title='Power',url='scip://power'}}}
 p:Action(person,'webSave',d);eq(p.store.webPages['new-site'],nil)
 person.IsAdmin=function() return true end;p:Action(person,'webSave',d);assert(p.store.webPages['new-site']);eq(snapshot.webEdit.revision,1)
 person.IsAdmin=function() return false end;p:Action(person,'navigate',{token=s.token,route='scip://web/new-site'});eq(snapshot.webBody,nil)
 p:Action(person,'navigate',{token=s.token,route='scip://editor/new-site'});eq(snapshot.webEdit,nil)
 person.IsAdmin=function() return true end;d.published=true;d.revision=1;p:Action(person,'webSave',d);eq(p.store.webPages['new-site'].revision,2)
 d.revision=2;d.template='forged';p:Action(person,'webSave',d);eq(p.store.webPages['new-site'].revision,2)
 d.template='bulletin';d.theme='invalid';p:Action(person,'webSave',d);eq(p.store.webPages['new-site'].revision,2)
 d.theme='cyan';d.image='https://outside/image.png';p:Action(person,'webSave',d);eq(p.store.webPages['new-site'].revision,2)
 d.image='hrp-scp-049';p:Action(person,'webSave',d);eq(p.store.webPages['new-site'].revision,3);eq(p.store.webPages['new-site'].image,'hrp-scp-049')
 p:Action(person,'navigate',{token=s.token,route='scip://web/new-site'});eq(snapshot.webDesign.template,'bulletin');eq(snapshot.webDesign.theme,'cyan');eq(snapshot.webDesign.image,'hrp-scp-049')
 d.revision=1
 d.body='stale';p:Action(person,'webSave',d);assert(p.store.webPages['new-site'].body~='stale')
 d.revision=3;d.links={{title='Bad',url='javascript:alert(1)'}};p:Action(person,'webSave',d);eq(p.store.webPages['new-site'].revision,3)
 d.links={};d.level=0/0;p:Action(person,'webSave',d);eq(p.store.webPages['new-site'].revision,3)
 d.level=1;d.slug='../escape';p:Action(person,'webSave',d);eq(p.store.webPages['../escape'],nil)
 person.IsAdmin=function() return false end;p:Action(person,'navigate',{token=s.token,route='scip://web/new-site'});assert(snapshot.webDesign and snapshot.webDesign.body)
 p:Action(person,'webDelete',{token=s.token,slug='new-site',revision=2});assert(p.store.webPages['new-site'])
 person.IsAdmin=function() return true end;p:Action(person,'webDelete',{token=s.token,slug='new-site',revision=3});eq(p.store.webPages['new-site'],nil)
 local legacy=p.store.webPages.engineering;legacy.template=nil;legacy.theme=nil;legacy.body='Admin revised body';local revision=legacy.revision
 p:WebPages();eq(legacy.body,'Admin revised body');eq(legacy.revision,revision);eq(legacy.template,'portal');eq(legacy.theme,'slate')
 local savedPages=p.store.webPages;p.GetData=function() return p.store end;p:LoadData();eq(p:WebPages(),savedPages)
 `,webSetup+`
 game={GetMap=function() return 'testmap' end};terminal.EntIndex=function() return 10 end;SortedPairs=pairs
 ix.data={Get=function(_,default) return default end}
 function isbool(v) return type(v)=='boolean' end
 function table.Copy(v) local r={} for k,x in pairs(v) do r[k]=type(x)=='table' and table.Copy(x) or x end return r end
 `);
suite('Hidden sites persist, require exact authorized URLs and do not leak through catalog or generated links',webFiles,`
 local p=PLUGIN;person.IsAdmin=function() return true end;card.clearanceLevel=3
 p:Login(person,terminal);local s=p.sessions[person]
 local d={token=s.token,slug='archive-delta',revision=0,title='Hidden archive',summary='Private summary',body='Private body',
  level=3,published=true,hidden=true,links={}}
 p:Action(person,'webSave',d);eq(p.store.webPages['archive-delta'].hidden,true);eq(snapshot.webEdit.hidden,true)
 local function navigate(route) p:Action(person,'navigate',{token=s.token,route=route}) end
 local function listed(url) for _,row in ipairs(snapshot.rows or {}) do if row.url==url then return row end end end
 local target='scip://web/archive-delta'
 navigate('scip://web');eq(listed(target),nil)
 navigate('scip://editor');assert(listed('scip://editor/archive-delta').title:find('только по URL',1,true))
 p.store.webPages.welcome.links={{title='Hidden link',url=target},{title='Power',url='scip://power'}}
 person.IsAdmin=function() return false end
 navigate('scip://web');eq(listed(target),nil)
 navigate('scip://web/welcome');eq(#snapshot.webDesign.links,1);eq(snapshot.webDesign.links[1].url,'scip://power');eq(listed(target),nil)
 eq(#p.store.webPages.welcome.links,2) -- filtering is a view, not a destructive edit
 navigate(target);eq(snapshot.webDesign.body,'Private body');assert(snapshot.webDesign)
 navigate('scip://web/archive');eq(snapshot.webBody,nil)
 card.clearanceLevel=2;navigate(target);eq(snapshot.webBody,nil);eq(snapshot.webDesign,nil)
 navigate('scip://editor/archive-delta');eq(snapshot.webEdit,nil)
 d.revision=1;d.hidden=false;p:Action(person,'webSave',d);eq(p.store.webPages['archive-delta'].hidden,true)
 person.IsAdmin=function() return true end;card.clearanceLevel=3
 d.hidden='true';p:Action(person,'webSave',d);eq(p.store.webPages['archive-delta'].revision,1)
 d.hidden=nil;p:Action(person,'webSave',d);eq(p.store.webPages['archive-delta'].hidden,true) -- old client save
 d.revision=2;d.hidden=true;d.published=false;p:Action(person,'webSave',d)
 navigate(target);eq(snapshot.webBody,nil) -- an unlisted draft is still unpublished
 local stored=p.store;p.GetData=function() return stored end;p:LoadData()
 eq(p:WebPages()['archive-delta'].hidden,true)
 d.revision=3;d.published=true;d.hidden=false;p:Action(person,'webSave',d)
 navigate('scip://web');assert(listed(target))
 navigate('scip://web/welcome');eq(#snapshot.webDesign.links,2);assert(listed(target))
 -- Stale updates cannot restore an earlier visibility choice.
 d.hidden=true;p:Action(person,'webSave',d);eq(p.store.webPages['archive-delta'].hidden,false)
 `,webSetup);
suite('SCP catalogue enforces every card level on directory, direct URLs, admin routes and mutation',webFiles,`
 local p=PLUGIN;person.IsAdmin=function() return true end;p:Login(person,terminal);local s=p.sessions[person]
 local expected={['scp-018']=2,['scp-049']=2,['scp-079']=3,['scp-096']=2,['scp-106']=3,['scp-127']=2,
  ['scp-1344']=2,['scp-1509']=2,['scp-173']=2,['scp-1853']=2,['scp-207']=2,['scp-2176']=2,['scp-244']=2,
  ['scp-268']=2,['scp-3114-f']=2,['scp-330']=2,['scp-420-j']=2,['scp-500']=2,['scp-507']=2,['scp-507-f']=2,
  ['scp-7691-c']=3,['scp-912']=2,['scp-914']=2,['scp-939-f']=3,['scp-970-c']=2}
 for level=1,4 do
  card.clearanceLevel=level
  for id,min in pairs(expected) do
   p:Action(person,'navigate',{token=s.token,route='scip://web/'..id})
   eq(snapshot.webDesign~=nil,level>=min);eq(snapshot.webBody,nil)
   if snapshot.webDesign then eq(snapshot.webDesign.level,min);assert(snapshot.webDesign.image);assert(#snapshot.webDesign.body<=64000) end
   p:Action(person,'navigate',{token=s.token,route='scip://editor/'..id});eq(snapshot.webEdit~=nil,level>=min)
  end
  p:Action(person,'navigate',{token=s.token,route='scip://web'});local seen={}
  for _,v in ipairs(snapshot.rows) do seen[v.url]=true end
  for id,min in pairs(expected) do eq(seen['scip://web/'..id]==true,level>=min) end
 end
 card.clearanceLevel=2;local before=p.store.webPages['scp-079']
 p:Action(person,'webDelete',{token=s.token,slug='scp-079',revision=before.revision});eq(p.store.webPages['scp-079'],before)
 card.clearanceLevel=4
 local d=table.Copy(before);d.slug='scp-079';d.token=s.token;d.level=2
 p:Action(person,'webSave',d);eq(p.store.webPages['scp-079'],before)
 d.level=3;d.template='scp079';d.theme='green';p:Action(person,'webSave',d);eq(p.store.webPages['scp-079'].revision,2)
 p.store.webPages['scp-079'].level=1;card.clearanceLevel=2
 p:Action(person,'navigate',{token=s.token,route='scip://web/scp-079'});eq(snapshot.webDesign,nil)
 -- A revoked/removed card invalidates a formerly authorized session.
 card.clearanceLevel=3;card.data.revoked=true;p:Action(person,'navigate',{token=s.token,route='scip://web/scp-079'});eq(p.sessions[person],nil)
 `,webSetup);
suite('Source migration replaces legacy pages with an archival backup and survives reload without resurrecting edits',webFiles,`
 local p=PLUGIN
 local legacy={research={title='ADMIN',body='PRIVATE EDIT',summary='S',level=2,published=false,revision=8,template='portal'},
  records={title='RAISA'},biosafety={title='Old biology'},secret={title='Old hidden',hidden=true},
  ['scp-939']={title='Generic SCP-939'},['scp-3114']={title='Generic SCP-3114'}}
 p.store.webPages=legacy;p.store.documents={{id=7,title='Legacy document'}}
 p:LoadData()
 local pages=p:WebPages();eq(table.Count(pages),60)
 eq(pages.research.title,p.webCatalog.research.title);eq(pages.research.revision,9)
 eq(pages.records,nil);eq(pages.biosafety,nil);eq(pages.secret,nil);eq(pages['scp-939'],nil);eq(pages['scp-3114'],nil)
 assert(pages['scp-939-f']);assert(pages['scp-3114-f']);eq(#p.store.documents,0)
 local backup=p.store.webSourceBackups[p.webSourceRevision]
 eq(backup.pages.research.body,'PRIVATE EDIT');eq(backup.pages.secret.hidden,true);eq(backup.documents[1].id,7)
 pages['scp-173']=nil;pages.research.body='New admin edit';p:WebPages();eq(pages['scp-173'],nil)
 local old=p.store;p.GetData=function() return old end;p:LoadData();p:WebPages()
 eq(p.store.webPages['scp-173'],nil);eq(p.store.webPages.research.body,'New admin edit')
 eq(backup.pages.research.body,'PRIVATE EDIT');eq(table.Count(p.store.webSourceBackups),1)
 local choices={};for _,v in ipairs(ix.FoundationNet.siteTemplates) do choices[v[1]]=true end
 for id,v in pairs(p.webCatalog) do
  assert(choices[v.template]);assert(v.image=='none' or ix.FoundationNet.artwork[v.image])
  assert(#v.title<=220);assert(#v.summary<=400);assert(#v.body<=64000);assert(#v.links<=32)
  assert(v.source:match('^https://hrp%.funclub%.pro/'))
  for _,link in ipairs(v.links) do assert(p.webCatalog[link.url:match('^scip://web/(.+)$')]) end
  if v.category=='scp' then eq(p:WebLevel(id,v),(v.classification=='Кетер' or id=='scp-079') and 3 or 2) end
 end
 `,webSetup);
suite('In-world metadata stays accurate after edits and source URLs never reach readers',webFiles,`
 local p=PLUGIN;person.IsAdmin=function() return true end;card.clearanceLevel=4
 p:Login(person,terminal);local s=p.sessions[person]
 local function navigate(id) p:Action(person,'navigate',{token=s.token,route='scip://web/'..id}) end
 navigate('scp-079');eq(snapshot.webDesign.source,nil);eq(snapshot.webDesign.credit,nil);eq(snapshot.webDesign.code,'SCP-079')
 local d=table.Copy(p.store.webPages['scp-079']);d.slug='scp-079';d.token=s.token;d.hidden=true
 p:Action(person,'webSave',d);navigate('scp-079');eq(snapshot.webDesign.source,nil);eq(snapshot.webDesign.code,'SCP-079')
 d.revision=d.revision+1;d.body='Unsourced replacement';p:Action(person,'webSave',d);navigate('scp-079')
 eq(snapshot.webDesign.source,nil);eq(snapshot.webDesign.classification,nil)
 card.clearanceLevel=2;navigate('contained-objects')
 for _,link in ipairs(snapshot.webDesign.links) do
  assert(link.url~='scip://web/scp-079');assert(link.url~='scip://web/scp-939-f');assert(link.url~='scip://web/scp-106')
 end
 eq(snapshot.webSourceBackups,nil);eq(snapshot.webEdit,nil)
 navigate('biosafety');eq(snapshot.webDesign,nil)
 `,webSetup);
suite('Catalogue UI filters, image/template selection, draft preview and save preserve choices',[
 'tools/terminal-preview-fixture.lua','ixhl2rp/plugins/foundation_network/sh_webstyles.lua',
 'ixhl2rp/plugins/foundation_network/sv_catalog.lua','ixhl2rp/plugins/foundation_network/cl_design.lua',
 'ixhl2rp/plugins/foundation_network/cl_sites.lua','ixhl2rp/plugins/foundation_network/cl_catalog.lua',
 'ixhl2rp/plugins/foundation_network/cl_network.lua'],`
 local N=ix.FoundationNet;local panel=vgui.Create('ixFoundationNetwork');panel.bootAt=0
 local rows={};for id,v in pairs(PLUGIN.webCatalog) do rows[#rows+1]={title=v.title,detail=v.summary,url='scip://web/'..id,image=v.image,category=v.category,level=v.level} end
 local data={route='scip://web',name='Tester',level=4,token='test',rows=rows}
 panel:ApplyPage(data);PreviewLayout(panel)
 local filters,grid
 for _,v in ipairs(panel.body.canvas.children) do if v.class=='DIconLayout' then grid=v elseif #v.children==4 and v.children[1].class=='DButton' then filters=v end end
 eq(#grid.children,60);filters.children[3]:DoClick();eq(panel.webFilter,'scp')
 for _,v in ipairs(panel.body.canvas.children) do if v.class=='DIconLayout' then eq(#v.children,25) end end
 local d=table.Copy(PLUGIN.webCatalog['scp-079']);d.slug='scp-079';d.revision=1;d.minimum=3
 panel:ApplyPage({route='scip://editor/scp-079',name='Tester',level=4,token='test',webEdit=d})
 local buttons={};for _,v in ipairs(panel.body.canvas.children) do if v.class=='DButton' then buttons[#buttons+1]=v end end
 buttons[1]:DoClick();assert(IsValid(panel.modal));eq(#panel.modalScroll.canvas.children,#N.siteTemplates)
 panel.modalScroll.canvas.children[4]:DoClick();assert(not IsValid(panel.modal))
 -- The selected caption is painted dynamically; native button text must stay empty.
 eq(buttons[1].text,'');assert(PreviewSVG(panel):find('Научный журнал',1,true))
 buttons[2]:DoClick();eq(#panel.modalScroll.canvas.children,#N.siteImages)
 panel.modalScroll.canvas.children[5]:DoClick();assert(PreviewSVG(panel):find('SCP-049',1,true))
 buttons[3]:DoClick();assert(IsValid(panel.modal));assert(PreviewSVG(panel):find('СЛУЖЕБНАЯ ДОКУМЕНТАЦИЯ',1,true));panel.modal:Remove()
 local sent;N.Request=function(action,payload) sent=payload;eq(action,'webSave');return true end
 buttons[5]:DoClick();eq(sent.template,'research');eq(sent.image,'hrp-scp-049');eq(sent.theme,'green');eq(sent.published,true);eq(sent.level,3)
 eq(sent.hidden,false)
 local visibility;for _,v in ipairs(panel.body.canvas.children) do if v.class=='DPanel' and #v.children==2 and v.children[1].class=='DButton' then visibility=v end end
 assert(visibility);visibility.children[2]:DoClick();buttons[5]:DoClick();eq(sent.hidden,true)
 buttons[4]:DoClick();eq(sent.published,false);eq(sent.hidden,true)
 d.hidden=true;panel:ApplyPage({route='scip://editor/scp-079',name='Tester',level=4,token='test',webEdit=d})
 buttons={};for _,v in ipairs(panel.body.canvas.children) do if v.class=='DButton' then buttons[#buttons+1]=v end end
 buttons[5]:DoClick();eq(sent.hidden,true)
 assert(PreviewSVG(panel):find('Только по URL',1,true))
 -- Long custom content and extra sections remain present in every new layout.
 for _,template in ipairs(N.siteTemplates) do if N.catalogRenderers[template[1]] then
  local article=table.Copy(d);article.template=template[1];article.body=article.body..'\\n# EXTRA SECTION\\nEXTRA BODY'
  panel:ApplyPage({route='scip://web/test',name='Tester',level=4,token='test',webDesign=article});PreviewLayout(panel)
  local seen={};local function visit(p) seen[p.text]=true;for _,c in ipairs(p.children) do visit(c) end end;visit(panel.body)
  assert(seen['EXTRA BODY']);assert(seen['EXTRA SECTION'] or seen[string.format('%02d   EXTRA SECTION',#N.SiteSections(article.body))])
 end end
 `);
suite('All full roleplay documents render every paragraph without website chrome; catalog search retains filters',[
 'tools/terminal-preview-fixture.lua','ixhl2rp/plugins/foundation_network/sh_webstyles.lua',
 'ixhl2rp/plugins/foundation_network/sv_catalog.lua','ixhl2rp/plugins/foundation_network/cl_design.lua',
 'ixhl2rp/plugins/foundation_network/cl_sites.lua','ixhl2rp/plugins/foundation_network/cl_catalog.lua',
 'ixhl2rp/plugins/foundation_network/cl_network.lua'],`
 local N=ix.FoundationNet;local p=vgui.Create('ixFoundationNetwork');p.bootAt=0
 local opened;gui={OpenURL=function(url) opened=url end}
 local rows={}
 for id,d in pairs(PLUGIN.webCatalog) do
  p:ApplyPage({route='scip://web/'..id,name='Tester',level=4,token='test',webDesign=d});PreviewLayout(p)
  local texts={}
  local function visit(v)
   if v.text then texts[v.text]=true end
   if v.text then assert(not v.text:find('hrp.funclub',1,true));assert(not v.text:find('КРАТКОЕ ИЗЛОЖЕНИЕ',1,true)) end
   for _,c in ipairs(v.children) do visit(c) end
  end
  visit(p.body);eq(opened,nil)
  for _,section in ipairs(N.SiteSections(d.body)) do for _,line in ipairs(section.lines) do assert(texts[line],id) end end
  rows[#rows+1]={title=d.title,detail=d.summary,url='scip://web/'..id,image=d.image~='none' and d.image or nil,category=d.category,level=d.level}
 end
 local data={route='scip://web',name='Tester',level=4,token='test',rows=rows}
 p:ApplyPage(data);PreviewLayout(p)
 local search;for _,v in ipairs(p.body.canvas.children) do if v.class=='DTextEntry' then search=v end end
 assert(search);search:SetText('SCP-507');search:OnChange();PreviewLayout(p)
 local grid;for _,v in ipairs(p.body.canvas.children) do if v.valid and v.class=='DIconLayout' then grid=v end end
 eq(#grid.children,2)
 p.webFilter='scp';p:ApplyPage(data);PreviewLayout(p)
 for _,v in ipairs(p.body.canvas.children) do if v.valid and v.class=='DIconLayout' then eq(#v.children,2) end end
 eq(p.webSearch,'SCP-507')
 `);
suite('Public browser presents only its library, card-free entry and unclassified documents',[
 'tools/terminal-preview-fixture.lua','ixhl2rp/plugins/foundation_network/sh_webstyles.lua',
 'ixhl2rp/plugins/foundation_network/sv_catalog.lua','ixhl2rp/plugins/foundation_network/cl_design.lua',
 'ixhl2rp/plugins/foundation_network/cl_sites.lua','ixhl2rp/plugins/foundation_network/cl_catalog.lua',
 'ixhl2rp/plugins/foundation_network/cl_network.lua'],`
 local p=vgui.Create('ixFoundationNetwork');p.bootAt=0;p.publicAccess=true;p:Login();PreviewLayout(p)
 local svg=PreviewSVG(p);assert(svg:find('Открыть библиотеку',1,true));eq(svg:find('Считать карту',1,true),nil)
 local rows={};for _,id in ipairs({'class-d','janitor','d-charter','d-contract','d-housing','d-orientation'}) do
  local d=PLUGIN.webCatalog[id];rows[#rows+1]={title=d.title,detail=d.summary,url='scip://web/'..id}
 end
 p:ApplyPage({route='scip://web',name='Открытый доступ',department='Библиотека класса D',level=0,token='public',publicAccess=true,rows=rows,webAdmin=true})
 eq(#p.navButtons,2);PreviewLayout(p);svg=PreviewSVG(p)
 eq(svg:find('Досье SCP',1,true),nil);eq(svg:find('Редактор',1,true),nil);eq(svg:find('L0',1,true),nil)
 local request;ix.FoundationNet.Request=function(action,data) request=data.route;return true end
 p.navButtons[1]:DoClick();eq(request,'scip://web')
 local grid;for _,v in ipairs(p.body.canvas.children) do if v.class=='DIconLayout' then grid=v end end
 eq(#grid.children,6);grid.children[2]:DoClick();eq(request,'scip://web/janitor')
 local d=table.Copy(PLUGIN.webCatalog.janitor);d.publicAccess=true;d.level=0
 p:ApplyPage({route='scip://web/janitor',name='Открытый доступ',department='Библиотека класса D',level=0,token='public',publicAccess=true,webDesign=d})
 PreviewLayout(p);svg=PreviewSVG(p);assert(svg:find('ОТКРЫТЫЙ ДОСТУП',1,true));eq(svg:find('ДОПУСК L',1,true),nil)
 p:Login();PreviewLayout(p);svg=PreviewSVG(p);assert(svg:find('Открыть библиотеку',1,true));eq(svg:find('Считать карту',1,true),nil)
 `);
suite('Terminal map page paints its outlines through the real panel tree without a texture lookup',[
 'tools/geometry-fixture.lua','tools/terminal-preview-fixture.lua',
 'ixhl2rp/plugins/foundation_network/cl_design.lua','ixhl2rp/plugins/foundation_network/cl_map.lua',
 'ixhl2rp/plugins/foundation_network/cl_network.lua'],`
 local wall={Vector(-200,0,0),Vector(200,0,0),Vector(200,0,300),Vector(-200,0,300)}
 game={GetMap=function() return 'map-paint-fixture' end,GetWorld=function() return {GetBrushSurfaces=function() return {
  {GetMaterial=function() return {GetName=function() return 'brick' end} end,GetVertices=function() return wall end}
 } end} end};function SysTime() return 0 end
 local function forbidden() error('Map page tried to sample a separate texture') end
 GetRenderTarget=forbidden;CreateMaterial=forbidden;surface.DrawTexturedRectUV=forbidden
 local N=ix.FoundationNet;local p=vgui.Create('ixFoundationNetwork');p.bootAt=0
 p:ApplyPage({route='scip://map',name='Tester',level=3,token='test',title='КАРТА',mapData={origin={0,0,0},name='fixture',areas={{name='БЛОК Д1',min={-300,-300,0},max={300,300,128}}},alerts={
  {name='Power',kind='power',active=true,pos={-800,500,0}},
  {name='Infection',kind='infection',active=true,pos={800,-500,0}}},terminals={}}})
 PreviewLayout(p);N.StepMapGeometry(p.mapPanel.geometry);N.RenderMap(p.mapPanel)
 local view=p.mapPanel.mapView;assert(view and p.mapPanel.mapReady)
 local svg=PreviewSVG(p)
 assert(svg:find('rgb(232,255,255)',1,true));assert(svg:find('rgb(5,13,20)',1,true));assert(svg:find('FLOOR PLAN',1,true))
 assert(svg:find('ЛКМ:',1,true));eq(p.mapPanel.mapView,view)
 local areaText=svg:match('(<text[^>]*>БЛОК Д1</text>)');assert(areaText)
 assert(areaText:find('font-size="22"',1,true));assert(areaText:find('text-anchor="middle"',1,true))
 assert(areaText:find('rgb(240,251,255)',1,true))
 assert(svg:find('rgb(255,198,68)',1,true));assert(svg:find('rgb(255,90,89)',1,true))
 eq(svg:find('Power / НЕТ ПИТАНИЯ',1,true),nil);eq(svg:find('Infection / ЗАРАЖЕНИЕ',1,true),nil)
 p.mapPanel:OnSurfaceWheel(1);p.mapPanel:OnSurfaceDrag(20,30,1);p.mapPanel.nextRender=0
 N.RenderMap(p.mapPanel);assert(p.mapPanel.mapView~=view);assert(p.mapPanel.mapReady)
 `);
suite('Terminal surface rejects blocked/backside/outside clicks and clips/scopes control hit testing', ['ixhl2rp/plugins/foundation_network/cl_surface.lua'],`
 local N=ix.FoundationNet
 N.ScreenGeometry=function() return Vector(0,0,0),{Up=function() return Vector(0,0,1) end,Forward=function() return Vector(1,0,0) end,Right=function() return Vector(0,-1,0) end} end
 local ent={valid=true,GetPos=function() return Vector(0,0,0) end,GetClass=function() return 'ix_foundation_terminal' end};local panel={entity=ent}
 hit=Vector(28,-14,0);local x,y=N.ScreenCursor(panel);near(x,960);near(y,480)
 blocked=true;eq(N.ScreenCursor(panel),nil);blocked=false
 hit=Vector(-1,0,0);eq(N.ScreenCursor(panel),nil)
 hit=Vector(56,-1,0);eq(N.ScreenCursor(panel),nil)
 hit=Vector(28,-14,0);direction=Vector(0,0,1);eq(N.ScreenCursor(panel),nil);direction=Vector(0,0,-1)
 distance=129^2;eq(N.ScreenCursor(panel),nil);distance=0
 -- A vertical, translated monitor: screen-down is world -Z, not world +Y.
 N.ScreenGeometry=function() return Vector(10,20,30),{Up=function() return Vector(1,0,0) end,Forward=function() return Vector(0,1,0) end,Right=function() return Vector(0,0,-1) end} end
 direction=Vector(-1,0,0);hit=Vector(10,48,16)
 x,y=N.ScreenCursor(panel);near(x,960);near(y,480)
 hit=Vector(10,20,30);x,y=N.ScreenCursor(panel);near(x,0);near(y,0)
 hit=Vector(10,48,31);eq(N.ScreenCursor(panel),nil)
 hit=Vector(10,48,-3);eq(N.ScreenCursor(panel),nil)
 local function box(w,h,x,y,z,control)
  return {valid=true,foundationControl=control,GetWide=function() return w end,GetTall=function() return h end,GetPos=function() return x,y end,GetZPos=function() return z end,IsVisible=function() return true end,GetChildren=function(self) return self.children or {} end}
 end
 local root=box(100,100,0,0,0);local low=box(90,90,0,0,1,'button');local high=box(90,90,0,0,2,'button');root.children={low,high}
 eq(N.ScreenHit(root,10,10),high)
 high.IsEnabled=function() return false end;eq(N.ScreenHit(root,10,10),low)
 local clip=box(20,20,0,0,4);clip.children={box(100,100,0,0,0,'button')};root.children={clip}
 eq(N.ScreenHit(root,30,10),nil);assert(N.ScreenHit(root,10,10))
 -- Exercise real projected mouse press/release routing through the popup shield.
 local noop=function() end
 local function widget()
  return setmetatable({valid=true},{__index=function(_,k) return noop end})
 end
 local host,shield=widget(),widget();local creates=0
 vgui={Create=function() creates=creates+1;return creates==1 and host or shield end}
 function ScrW() return 1920 end;function ScrH() return 1080 end;MOUSE_LEFT=1
 local browser=box(1920,1120,0,0,0);browser.entity=ent
 browser.SetParent=noop;browser.SetPos=noop;browser.SetKeyboardInputEnabled=noop
 local button=box(1000,100,400,430,0,'button');browser.children={button}
 local clicks=0;button.DoClick=function() clicks=clicks+1 end
 N.AttachSurface(browser)
 hit=Vector(10,48,16);shield:OnMousePressed(MOUSE_LEFT);eq(clicks,0)
 shield:OnMouseReleased(MOUSE_LEFT);eq(clicks,1)
 shield:OnMousePressed(MOUSE_LEFT);hit=Vector(10,20,30);shield:OnMouseReleased(MOUSE_LEFT);eq(clicks,1)
 hit=Vector(10,48,16);blocked=true;shield:OnMousePressed(MOUSE_LEFT);shield:OnMouseReleased(MOUSE_LEFT);eq(clicks,1)
 blocked=false;browser.busyAt=1;shield:OnMousePressed(MOUSE_LEFT);shield:OnMouseReleased(MOUSE_LEFT);eq(clicks,1);browser.busyAt=nil
 local viewport=box(900,500,0,0,0);viewport.LocalToScreen=function() return 100,250 end;viewport.GetParent=function() return browser end
 browser.LocalToScreen=function() return 0,0 end
 local overflowing=box(900,1000,0,0,0);overflowing.LocalToScreen=function() return 100,10 end;overflowing.GetParent=function() return viewport end
 local l,t,r,b=N.SurfaceClip(overflowing,browser);eq(l,100);eq(t,250);eq(r,1000);eq(b,750)
 overflowing.LocalToScreen=function() return 100,-1500 end;l,t,r,b=N.SurfaceClip(overflowing,browser);eq(t,b)
 `,`
 CLIENT=true;SERVER=false;ix.FoundationNet={};hook.Add=function() end
 local V={};V.__index=V
 function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},V) end
 function V.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
 function V.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
 function V.__mul(a,n) return Vector(a.x*n,a.y*n,a.z*n) end
 function V:GetNormalized() return self*(1/math.sqrt(self:Dot(self))) end
 function V:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
 distance=0;function V:DistToSqr() return distance end
 direction=Vector(0,0,-1);hit=Vector(0,0,0);blocked=false
 function LocalPlayer() return {valid=true,GetPos=function() return Vector(0,0,0) end,EyeAngles=function() return {} end} end
 function EyePos() return Vector(0,0,10) end
 gui={ScreenToVector=function() error('must use player viewport') end};input={GetCursorPos=function() return 960,540 end}
 render={GetViewSetup=function(noPlayer) eq(noPlayer,false);return {origin=hit-direction*10,angles={Forward=function() return direction end,Right=function() return Vector(1,0,0) end,Up=function() return Vector(0,1,0) end},fov=90,width=1920,height=1080,aspect=1920/1080} end}
 util.IntersectRayWithPlane=function() return hit end;util.TraceLine=function() return {Hit=blocked} end
 `);
suite('Workstation shell separates app bar, browser, page viewport and footer; queues page transitions', ['ixhl2rp/plugins/foundation_network/cl_network.lua'],`
 local function rect() return {valid=true,x=0,y=0,w=0,h=0,SetPos=function(s,x,y) s.x=x;s.y=y end,SetSize=function(s,w,h) s.w=w;s.h=h end,GetSize=function(s) return s.w,s.h end,SetVisible=function(s,v) s.visible=v end} end
 local p=setmetatable({token='session',route='scip://web/welcome',navButtons={}},{__index=networkPanel})
 for _,name in ipairs({'body','main','side','bar','back','forward','go','address','close'}) do p[name]=rect() end
 for i=1,9 do p.navButtons[i]=rect() end
 p:PerformLayout(1920,1120)
 assert(p.side.x+p.side.w<p.main.x);assert(p.main.y+p.main.h<=1120-48)
 eq(p.body.y,76);eq(p.bar.visible,true);assert(p.body.y+p.body.h<=p.main.h)
 for _,button in ipairs(p.navButtons) do assert(button.x>=0 and button.x+button.w<=p.side.w+.001 and button.y+button.h<=p.side.h) end
 p.route='scip://map';p:PerformLayout(1920,1120);eq(p.body.y,0);eq(p.bar.visible,false)
 p.token=nil;p:PerformLayout(1920,1120);eq(p.side.visible,false);eq(p.main.y,118)
 local data={route='scip://home'};p:Receive(data);eq(p.queuedPage,data);assert(p.pageReadyAt>RealTime())
 local applied;p.ApplyPage=function(_,d) applied=d end;p:Receive({mapUpdate=true});assert(applied.mapUpdate)
 p.valid=true;p.queuedPage=nil;ix.gui.foundationNetwork=p;ix.FoundationNet.nextRequest=0
 assert(ix.FoundationNet.Request('mapSync'));eq(p.busyAt,nil)
 ix.FoundationNet.nextRequest=0;assert(ix.FoundationNet.Request('navigate'));assert(p.busyAt)
 ix.FoundationNet.nextRequest=0;eq(ix.FoundationNet.Request('mapSync'),false)
 `,`
 CLIENT=true;SERVER=false;ix.gui={};ix.FoundationNet={};ix.option={Get=function() return false end}
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a} end
 surface={CreateFont=function() end};net.Receive=function() end
 net.Start=function() end;net.WriteString=function() end;net.WriteEntity=function() end;net.SendToServer=function() end;util.TableToJSON=function() return '{}' end
 util.Compress=function(v) return v end;net.WriteUInt=function() end;net.WriteData=function() end
 vgui={Register=function(_,p) networkPanel=p end};function RealTime() return 1 end
 `);
suite('Map telemetry is session-gated, bounded, and background refresh cannot extend idle time',files.concat(['ixhl2rp/plugins/foundation_network/sv_facility.lua','ixhl2rp/plugins/foundation_network/sv_map.lua']),`
 local p=PLUGIN;p:Login(person,terminal);local s=p.sessions[person]
 p:Action(person,'navigate',{token=s.token,route='scip://map'});assert(snapshot.mapData);eq(snapshot.mapData.name,'testmap')
 local idle=s.idle;clock=clock+6;p:Action(person,'mapSync',{token=s.token});eq(s.idle,idle);eq(snapshot.mapUpdate,true)
 local before=snapshot;clock=clock+1;p:Action(person,'mapSync',{token=s.token});eq(snapshot,before)
 for i=1,200 do ix.plugin.list.blackout.zones[tostring(i)]={min={x=0,y=0,z=0},max={x=1,y=1,z=1},active=true} end
 local data=p:MapSnapshot(person);eq(#data.alerts,128);assert(data.truncated);eq(data.zones,nil)
 card.data.revoked=true;clock=clock+6;p:Action(person,'mapSync',{token=s.token});eq(p.sessions[person],nil)
 `,setup+`
 game={GetMap=function() return 'testmap' end};terminal.EntIndex=function() return 10 end;SortedPairs=pairs
 person.IsAdmin=function() return false end
 person.GetPos=function() return {x=0,y=0,z=0,DistToSqr=function() return distance end} end
 ix.data={Get=function(_,default) return default end}
 ix.plugin.list.blackout.zones={};ents.FindByClass=function() return {} end
 `);
};
