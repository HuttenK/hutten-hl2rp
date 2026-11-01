const fs=require('fs'),{normalize}=require('./glua.cjs');
const directory='ixhl2rp/plugins/map_keycards/';
const text=fs.readFileSync(directory+'sv_tsade.lua','utf8');
const maps=JSON.parse(text.match(/\[====\[([\s\S]*?)\]====\]/)[1]);
const lua=v=>v===null?'nil':typeof v==='string'?JSON.stringify(v):typeof v==='object'?
  '{'+Object.entries(v).map(([k,x])=>(Array.isArray(v)?'['+(Number(k)+1)+']':'['+JSON.stringify(k)+']')+'='+lua(x)).join(',')+'}':String(v);
module.exports=run=>{
 const fixtures=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua','tools/fixtures/facility.lua','ixhl2rp/plugins/facility_utilities/sh_core.lua'];
 const source=f=>'do local function source()\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend;source() end\n';
 const setup=fixtures.map(source).join('\n')+`
 profiles=${lua(maps)}
 unpack=table.unpack
 ix.plugin.list.blackout=nil
 facility={loaded=true,store={doors={},circuits={}},Audit=function() end,
  EntityIsolated=function(_,e) return e.isolated==true end,
  DirectGrid=function(_,e) return not e.powerOff end}
 ix.plugin.list.facility_utilities=facility
 function include(name) eq(name,'sv_tsade.lua');return profiles end
 PLUGIN={};P=PLUGIN;ix.plugin.list.map_keycards=P
 function ErrorNoHalt(message) lastError=message end
 commands={};ix.command={Add=function(name,definition) commands[name]=definition end}
 ix.type={number=1,string=2,optional=4,bool=8};bit={bor=function(a,b)return a+b end}
 `+source(directory+'sv_access.lua')+source(directory+'sh_commands.lua')+`
 byID={};all={};profile=profiles.rp_zone_tsade_v1f_us
 function makeMap(definition)
  all={};byID={};local index=0
  for _,g in ipairs(definition.groups) do for _,d in ipairs(g.members) do
   index=index+1;local e=entity(index,d.model,Vector(unpack(d.origin)))
   e.class=d.class;e.name=d.name;function e:GetName()return self.name end
   byID[d.id]=e;all[#all+1]=e
  end end
  ents.GetAll=function()return all end
  P:BuildBindings(definition,all);P.profile=definition;P.ready=true
 end
 makeMap(profile)
 p=admin(2,'security');p.admin=false
 function aim(id)
  local e=byID[id];p.pos=e:GetPos();p.trace={Hit=true,Entity=e,HitPos=e:GetPos()};return e
 end
 button=aim('7744');group=P:FindGroup(button)
 function rule(level,department) P.rules[group.id]={level=level or 2,department=department or ''} end
 `;
 const suite=(name,body)=>run('Map keycards: '+name,[],setup+body);
 // Exercise Helix's real argument introspection, not just the engine fixtures.
 const registrar=`
 ix.command={}
 ix.type={[2]='string',[4]='text',[8]='number',[16]='player',[32]='steamid',
  [64]='character',[128]='bool',string=2,text=4,number=8,player=16,
  steamid=32,character=64,bool=128,optional=256,array=512}
 bit={bor=function(a,b)return a | b end,band=function(a,b)return a & b end,bxor=function(a,b)return a ~ b end}
 string.utf8len=string.len;string.utf8lower=string.lower
 function tobool(v) return v~=nil and v~=false and v~=0 and v~='0' and v~='false' end
 function RealTime() return clock end
 function L(key) return key end
 ix.log.Add=function() end;concommand={Add=function() end}
 CAMI={GetPrivilege=function()return nil end,RegisterPrivilege=function()end,
  PlayerHasAccess=function(client)return client:IsAdmin()end}
 registrationErrors={}
 function ErrorNoHalt(message) registrationErrors[#registrationErrors+1]=message end
 `+source('helix/gamemode/core/libs/sh_command.lua')+source(directory+'sh_commands.lua');
 for(const server of [true,false]) suite(`real Helix registrar and autocomplete expose all four commands (${server?'server':'client'})`,`
  SERVER=${server};CLIENT=${!server}
  ${registrar}
  eq(#registrationErrors,0)
  local matches=ix.command.FindAll('/mapdooraccess',true,true,true);eq(#matches,4)
  eq(matches[1].name,'MapDoorAccess')
  eq(ix.command.list.mapdooraccess.syntax,'<level: number> [department: string]')
  eq(ix.command.list.mapdooraccesstest.syntax,'<enabled: bool>')
  for _,command in ipairs(matches) do
   p.admin=true;eq(command:OnCheckAccess(p),true)
   p.admin=false;eq(command:OnCheckAccess(p),false)
  end
 `);
 suite('real Helix chat dispatch converts levels, optional departments and both test toggles',`
  ${registrar}
  eq(#registrationErrors,0);p.admin=true
  local function chat(text) clock=clock+1;eq(ix.command.Parse(p,text),true) end
  chat('/MapDoorAccess 3 science');eq(P.rules[group.id].level,3);eq(P.rules[group.id].department,'science')
  chat('/MapDoorAccessInfo');assert(p.notices[#p.notices]:find('L3',1,true))
  chat('/MapDoorAccess 2');eq(P.rules[group.id].level,2);eq(P.rules[group.id].department,'')
  p.card=nil;eq(P:PlayerUse(p,button),nil)
  chat('/MapDoorAccessTest true');eq(P:PlayerUse(p,button),false)
  chat('/MapDoorAccessTest false');eq(P:PlayerUse(p,button),nil)
  chat('/MapDoorAccess invalid');eq(P.rules[group.id].level,2);eq(p.notices[#p.notices],'invalidArg')
  chat('/MapDoorAccess');eq(P.rules[group.id].level,2);eq(p.notices[#p.notices],'invalidArg')
  p.admin=false;chat('/MapDoorAccessRemove');assert(P.rules[group.id]);eq(p.notices[#p.notices],'noPerm')
  p.admin=true;chat('/MapDoorAccessRemove');eq(P.rules[group.id],nil)
 `);
 suite('live command refresh repairs both registries without resetting access rules or bindings',`
  ${registrar}
  rule(3,'science');local rules=P.rules;local groups=P.groups
  ix.command.list.mapdooraccess=nil;ix.command.list.mapdooraccesstest=nil
  file={Read=function(path,realm)
   eq(path,'gamemodes/ixhl2rp/plugins/map_keycards/sh_commands.lua');eq(realm,'GAME')
   return ${lua(fs.readFileSync(directory+'sh_commands.lua','utf8'))}
  end}
  function CompileString(text,name) local fn,err=load(text,name);return fn or err end
  local broadcasts=0
  function BroadcastLua(code)
   broadcasts=broadcasts+1
   eq(#ix.command.FindAll('/mapdooraccess'),4)
   local serverRegistry=ix.command.list
   ix.command.list={};SERVER=false;CLIENT=true
   assert(load(code))();eq(#ix.command.FindAll('/mapdooraccess'),4)
   ix.command.list=serverRegistry;SERVER=true;CLIENT=false
  end
  ${source('tools/ix_map_keycards_commands_apply.lua')}
  ${source('tools/ix_map_keycards_commands_apply.lua')}
  eq(broadcasts,2);eq(P.rules,rules);eq(P.groups,groups);eq(P.rules[group.id].level,3)
  eq(#registrationErrors,0)
 `);
 suite('both compiled Tsade maps bind every expected entity once, including paired doors and elevator controls',`
  for _,profile in pairs(profiles) do
   makeMap(profile);eq(#all,734);eq(table.Count(P.groups),334)
   for _,g in pairs(P.groups) do assert(g.complete,g.name);eq(#g.members,#g.definition.members) end
   eq(table.Count(P.byEntity),734)
   eq(P:FindGroup(byID['7729']),P:FindGroup(byID['8165']))
   eq(P:FindGroup(byID['9229']),P:FindGroup(byID['10013']))
   assert(P:FindGroup(byID['866052'])~=P:FindGroup(byID['852132']))
  end
 `);
 suite('wall buttons, both moving leaves and attached visual props use the same current card check',`
  rule(3);eq(P:PlayerUse(p,button),false)
  eq(P:PlayerUse(p,byID['7827']),false);eq(P:PlayerUse(p,byID['7824']),false)
  local prop=entity(9000,'visible');prop.parent=byID['7827'];eq(P:FindGroup(prop),group)
  eq(P:PlayerUse(p,prop),false)
  p.card.clearanceLevel=3;eq(P:PlayerUse(p,button),nil)
  p.card=nil;eq(P:PlayerUse(p,button),false)
  eq(#button.inputs,0);eq(#byID['7827'].inputs,0)
 `);
 suite('two separate controls share clearance; denial feedback is rate limited',`
  local a,b=byID['7729'],byID['8165'];local g=P:FindGroup(a);P.rules[g.id]={level=3,department=''}
  eq(P:PlayerUse(p,a),false);eq(P:PlayerUse(p,b),false);eq(#p.notices,1)
  clock=clock+2;eq(P:PlayerUse(p,b),false);eq(#p.notices,2)
  p.card.clearanceLevel=3;eq(P:PlayerUse(p,a),nil);eq(P:PlayerUse(p,b),nil)
 `);
 suite('missing, invalid, revoked and wrong-department cards are rejected; public access remains explicit',`
  ix.Fieldlink.CardIdentity=function(card) if card and not card.revoked and not card.unissued then return {} end end
  rule(2,'science');eq(P:PlayerUse(p,button),false)
  p.card.department='science';eq(P:PlayerUse(p,button),nil)
  p.card.revoked=true;eq(P:PlayerUse(p,button),false)
  p.card.revoked=false;p.card.unissued=true;eq(P:PlayerUse(p,button),false)
  p.card=nil;rule(0);eq(P:PlayerUse(p,button),nil)
  p.dead=true;eq(P:PlayerUse(p,button),false)
 `);
 suite('server commands enforce admin rights, finite integer levels, departments and trace distance',`
  eq(P:AdminCommand(p,'set',2), 'Только для администрации.');eq(next(P.rules),nil)
  p.admin=true
  for _,level in ipairs({-1,5,1.5,math.huge,0/0}) do P:AdminCommand(p,'set',level);eq(next(P.rules),nil) end
  P:AdminCommand(p,'set',2,'bogus');eq(next(P.rules),nil)
  p.trace.HitPos=p.pos+Vector(300,0,0);P:AdminCommand(p,'set',2);eq(next(P.rules),nil)
  aim('7744');P:AdminCommand(p,'set',3,' SCIENCE ');eq(P.rules[group.id].level,3);eq(P.rules[group.id].department,'science')
  assert(P:AdminCommand(p,'info'):find('L3',1,true));P:AdminCommand(p,'remove');eq(next(P.rules),nil)
  eq(commands.MapDoorAccess.adminOnly,true);eq(commands.MapDoorAccessTest.arguments[1],ix.type.bool)
 `);
 suite('admin bypass can be disabled for solo card tests without bypassing outages or lockdowns',`
  rule(3);p.admin=true;p.card=nil;eq(P:PlayerUse(p,button),nil)
  P:AdminCommand(p,'test',true);eq(P:PlayerUse(p,button),false)
  p.card={clearanceLevel=3,department='security'};eq(P:PlayerUse(p,button),nil)
  button.powerOff=true;eq(P:PlayerUse(p,button),false)
  P:AdminCommand(p,'test',false);eq(P:PlayerUse(p,button),false)
  button.powerOff=false;eq(P:PlayerUse(p,button),nil)
 `);
 suite('electric controls respect outage, generator backup, isolation and inverse-blackout exceptions',`
  rule(2);button.powerOff=true;eq(P:PlayerUse(p,button),false)
  button.ixGeneratorPower=true;eq(P:PlayerUse(p,button),nil)
  button.isolated=true;eq(P:PlayerUse(p,button),false)
  ix.plugin.list.blackout={ElectronicsOverride=function()return false end};eq(P:PlayerUse(p,button),nil)
  ix.plugin.list.blackout.ElectronicsOverride=function()return true end;eq(P:PlayerUse(p,button),false)
  button.isolated=false;eq(P:PlayerUse(p,button),nil) -- cable supply survives global mains restriction
  button.ixGeneratorPower=false;eq(P:PlayerUse(p,button),false)
  P.rules={};eq(P:PlayerUse(p,button),nil)
 `);
 suite('facility faults and lockdown stop initiation without interfering with automatic closing',`
  rule();facility.store.doors[1]={entity=byID['7827'],circuit=1};facility.store.circuits[1]={lockdown=true}
  eq(P:PlayerUse(p,button),false)
  eq(P:AcceptInput(byID['7827'],'Close',p,button),nil)
  facility.store.circuits[1].lockdown=false;facility.store.doors[1].fault=true;eq(P:PlayerUse(p,button),false)
  facility.store.doors[1].fault=false;eq(P:PlayerUse(p,button),nil)
 `);
 suite('direct player I/O cannot bypass rules, including caller-only activations',`
  rule(3)
  for _,input in ipairs({'Press','Use','Toggle','PressIn','PressOut'}) do eq(P:AcceptInput(button,input,p,p),true) end
  for _,input in ipairs({'Open','OpenAwayFrom','Use','Toggle','Unlock','SetPosition'}) do eq(P:AcceptInput(byID['7827'],input,p,p),true) end
  eq(P:AcceptInput(byID['7827'],'Open',nil,p),true)
  eq(P:AcceptInput(button,'Unlock',p,p),nil)
  p.card.clearanceLevel=3;eq(P:AcceptInput(button,'Press',p,p),nil)
 `);
 suite('authorized sequences finish, but grants do not authorize fresh presses or follow a character switch',`
  rule(2);eq(P:PlayerUse(p,button),nil);p.card=nil
  eq(P:AcceptInput(byID['7827'],'Toggle',p,button),nil)
  eq(P:PlayerUse(p,button),false);eq(P:AcceptInput(button,'Press',p,p),true)
  clock=clock+31;eq(P:AcceptInput(byID['7827'],'Toggle',p,button),true)
  p.card={clearanceLevel=2};eq(P:PlayerUse(p,button),nil);p.card=nil
  P:PlayerLoadedCharacter(p);eq(P:AcceptInput(byID['7827'],'Toggle',p,button),true)
 `);
 suite('map emergency relays and closure timing are preserved; master controls are restricted separately',`
  rule(4);local relay=entity(9000,'');relay.class='logic_relay'
  eq(P:AcceptInput(byID['7827'],'Open',p,relay),nil)
  eq(P:AcceptInput(byID['7827'],'Close',p,button),nil)
  eq(P:AcceptInput(byID['7827'],'Lock',p,button),nil)
  eq(P:AcceptInput(byID['7827'],'Open',nil,relay),nil)
  local master=byID['866052'];local g=P:FindGroup(master);P.rules[g.id]={level=4,department=''}
  eq(P:PlayerUse(p,master),false)
 `);
 suite('missing members fail closed; unrelated props and unrestricted controls remain untouched',`
  rule();byID['7827'].valid=false;eq(P:PlayerUse(p,button),false)
  local other=byID['46810'];eq(P:PlayerUse(p,other),nil)
  local prop=entity(9000,'ordinary');eq(P:PlayerUse(p,prop),nil)
  byID['7827'].valid=true;group.complete=false;eq(P:PlayerUse(p,button),false)
 `);
 suite('saved rules survive reload and cleanup with recreated entities; bad records are discarded',`
  p.admin=true;P:AdminCommand(p,'set',3,'science')
  local storedRule=stored.map_keycard_access_v1;eq(storedRule.crc,profile.crc)
  storedRule.rules[tonumber(group.id)]=storedRule.rules[group.id];storedRule.rules[group.id]=nil
  storedRule.rules.garbage={level=4,department=''}
  storedRule.rules['7824']={level=0/0,department=''}
  game.GetMap=function()return 'rp_zone_tsade_v1f_us' end
  P.MapFingerprint=function()return profile.crc end
  P:LoadData();eq(P.rules[group.id].level,3);eq(table.Count(P.rules),1)
  local old=button;makeMap(profile);P:PostCleanupMap();assert(P:FindGroup(byID['7744']));eq(P:FindGroup(old),nil)
  eq(P.rules[group.id].department,'science')
 `);
 suite('changed or unsupported maps never reuse rules or overwrite saved configuration',`
  rule(3);P:SaveData();local previous=stored.map_keycard_access_v1
  game.GetMap=function()return 'rp_zone_tsade_v1f_us' end
  P.MapFingerprint=function()return 'different' end
  P:LoadData();eq(P.ready,false);P:SaveData();eq(stored.map_keycard_access_v1,previous);assert(lastError)
  game.GetMap=function()return 'gm_flatgrass' end;P:LoadData();eq(P.ready,false);eq(next(P.byEntity),nil)
 `);
 suite('facility console also respects local group clearance without recursively invoking itself',`
  local access=P;local door=byID['7827'];rule(3)
  facility.EntityIsolated=function()return false end
  PLUGIN=facility
  ${source('ixhl2rp/plugins/facility_utilities/sv_doors.lua')}
  local d={entity=door,level=1,department='',circuit=0}
  eq(facility:DoorAllowed(p,d),false)
  p.card.clearanceLevel=3;eq(facility:DoorAllowed(p,d),true)
  facility.store.doors[1]=d;d.circuit=1;facility.store.circuits[1]={lockdown=true}
  eq(facility:DoorAllowed(p,d),true);eq(access:PlayerUse(p,button),false)
 `);
 suite('BSP fingerprint reads only the entity lump and safely rejects invalid bounds or unavailable files',`
  local f={closed=false,cursor=0,values={20,2048,4}}
  function f:Read(n) if self.cursor==2048 then return 'data' end return 'VBSP' end
  function f:ReadLong() return table.remove(self.values,1) end
  function f:Size() return 4096 end
  function f:Seek(offset) self.cursor=offset end
  function f:Close() self.closed=true end
  file={Open=function(name,mode,realm) eq(mode,'rb');eq(realm,'GAME');return f end}
  util.CRC=function(raw) eq(raw,'data');return 'crc' end
  eq(P:MapFingerprint(),'crc');eq(f.closed,true)
  f.cursor=0;f.closed=false;f.values={20,2048,5000};eq(P:MapFingerprint(),nil);eq(f.closed,true)
  f.cursor=0;f.closed=false;f.values={20,-1,4};eq(P:MapFingerprint(),nil);eq(f.closed,true)
  file.Open=function()return nil end;eq(P:MapFingerprint(),nil)
 `);
 const reserve=`
  local access=P
  function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
  ix.util={Include=function() end};ix.lang={AddTable=function() end}
  ix.PropScreens={Aim=function() end}
  ix.CCTV={kinds={}}
  PLUGIN={};local B=PLUGIN;ix.plugin.list.blackout=B
  ${source('helix/plugins/area/sh_geometry.lua')}
  ${source('ixhl2rp/plugins/blackout/sh_plugin.lua')}
  B.zones={};B.electronicsRestricted=true;B.SetZoneLights=function() end;B.NetworkZones=function() end
  PLUGIN=facility
  ${['sv_store','sv_connections','sv_power','sv_doors'].map(f=>source('ixhl2rp/plugins/facility_utilities/'+f+'.lua')).join('\n')}
  facility.loaded=true
  local cableID=50000
  function cableItem()
   cableID=cableID+1;local item=giveItem(p,'facility_cable');item.id=cableID
   function item:GetOwner() return p end;function item:GetEntity() return nil end
   return item
  end
  function p:GetInventory() return {Sync=function() end,AddItem=function() return true end} end
  ix.Item={Instance=function() return {Save=function() end,Remove=function() end} end}
  local door=byID['5584'];button=byID['7729'];local otherButton=byID['8165']
  group=access:FindGroup(button);rule(2,'security');p.pos=button:GetPos()
  local function supply(kind,endpoint)
   endpoint=endpoint or button;p.pos=endpoint:GetPos()
   local d=device(kind);d.entity:SetPos(endpoint:GetPos()+Vector(40,0,0))
   d.owner=p:GetCharacter():GetID();d.running=true;d.fuel=100;d.capacity=5;d.charge=10
   local item=cableItem()
   local ok,reason=facility:ConnectGenerator(p,d,endpoint,endpoint:GetPos());assert(ok,reason);eq(item.removed,1)
   return d
  end
 `;
 suite('door or button cables power the complete mechanism, retain clearance, faults and lockdowns',reserve+`
  eq(access:PlayerUse(p,button),false)
  local g=supply('generator',door)
  eq(g.links[1].kind,'mapdoor');eq(g.links[1].group,group.id);eq(g.links[1].crc,profile.crc)
  for _,e in ipairs(group.members) do eq(ix.Facility.EntityBackup(e),true) end
  eq(ix.Facility.EntityBackup(byID['7744']),false)
  eq(access:PlayerUse(p,button),nil);eq(access:PlayerUse(p,otherButton),nil)
  p.card.clearanceLevel=1;eq(access:PlayerUse(p,button),false)
  p.card.clearanceLevel=2;p.card.department='science';eq(access:PlayerUse(p,button),false);p.card.department='security'
  local record={entity=door,level=2,department='security',circuit=1}
  facility.store.doors[1]=record;facility.store.circuits[1]={id=1,zone='missing',lockdown=true}
  eq(access:PlayerUse(p,button),false);eq(facility:DoorAction(p,{}, {id=1,command='open'}),false)
  facility.store.circuits[1].lockdown=false;eq(facility:DoorAllowed(p,record),true)
  record.fault=true;eq(access:PlayerUse(p,button),false);record.fault=false
  g.running=false;facility:RecomputePower(0)
  for _,e in ipairs(group.members) do eq(ix.Facility.EntityBackup(e),false) end
  eq(access:PlayerUse(p,otherButton),false)
  g.running=true;g.fuel=0;facility:RecomputePower(0);eq(access:PlayerUse(p,button),false)
  g.fuel=10;g.fault=true;facility:RecomputePower(0);eq(access:PlayerUse(p,button),false)
  g.fault=false;g.capacity=4;facility:RecomputePower(0);eq(access:PlayerUse(p,button),false)
 `);
 suite('battery uses one door load; another leaf cannot double-connect; unplugging either button clears all parts',reserve+`
  local battery=supply('battery');facility:RecomputePower(1);eq(battery.charge,5)
  eq(access:PlayerUse(p,otherButton),nil)
  local second=device('generator');second.owner=p:GetCharacter():GetID();second.entity:SetPos(door:GetPos())
  p.pos=door:GetPos();local item=cableItem()
  eq(facility:ConnectGenerator(p,second,door,door:GetPos()),false);eq(item.removed,0)
  facility:RecomputePower(1);eq(battery.charge,0);facility:RecomputePower(0)
  eq(access:PlayerUse(p,button),false);eq(access:PlayerUse(p,otherButton),false)
  battery.charge=100;facility:RecomputePower(0);eq(access:PlayerUse(p,button),nil)
  p.pos=otherButton:GetPos();p.trace={Hit=true,Entity=otherButton,HitPos=p.pos}
  facility:SetCableMode(p,'disconnect',0)
  assert(facility:ConnectionAction(p,{command='connect'}));eq(#battery.links,0)
  for _,e in ipairs(group.members) do eq(ix.Facility.EntityBackup(e),false) end
 `);
 suite('saved cables rebind after map entities and keycard groups reload; changed profiles and incomplete groups fail closed',reserve+`
  local battery=supply('battery');local id=battery.id
  facility:SaveData();access:SaveData();access.ready=false
  facility:LoadData();battery=facility.store.devices[id];eq(#battery.links,1)
  eq(facility:ResolvePowerTarget(battery.links[1]),nil)
  makeMap(profile);button=byID['7729'];group=access:FindGroup(button)
  facility:RecomputePower(0);eq(facility:ResolvePowerTarget(battery.links[1]),button)
  eq(access:PlayerUse(p,button),nil);eq(ix.Facility.EntityBackup(byID['8165']),true)
  eq(battery.links[1].point:DistToSqr(Vector()),0)
  battery.links[1].crc='changed-map';facility:RecomputePower(0);eq(access:PlayerUse(p,button),false)
  battery.links[1].crc=profile.crc;facility:RecomputePower(0);eq(access:PlayerUse(p,button),nil)
  byID['5596'].valid=false;facility:RecomputePower(0);eq(access:PlayerUse(p,button),false)
  eq(facility:PowerTarget(button),nil)
 `);
 suite('reserve cannot bypass isolation or cable reach, and does not feed manual doors or unrelated controls',reserve+`
  local g=supply('generator');eq(access:PlayerUse(p,button),nil)
  local savedIsolated=facility.EntityIsolated
  facility.EntityIsolated=function(self,e) return e==otherButton or savedIsolated(self,e) end
  facility:RecomputePower(0);eq(access:PlayerUse(p,button),false)
  facility.EntityIsolated=savedIsolated;facility:RecomputePower(0);eq(access:PlayerUse(p,button),nil)
  g.entity:SetPos(button:GetPos()+Vector(1000,0,0));facility:RecomputePower(0);eq(access:PlayerUse(p,button),false)
  eq(facility:PowerTarget(byID['866052']),nil) -- master control does not energize unrelated doors
  local manual;for _,candidate in pairs(access.groups) do if candidate.kind=='door' and not next(candidate.controls) then manual=candidate.members[1];break end end
  assert(manual);eq(facility:PowerTarget(manual),nil)
 `);
 suite('a cable attached inside a powered exception still supplies the same door button outside it',reserve+`
  B.zones.Powered={min=door:GetPos()-Vector(4,4,4),max=door:GetPos()+Vector(4,4,4),active=true}
  local g=supply('generator',door)
  eq(facility:DirectGrid(door),true);eq(facility:DirectGrid(button),false)
  eq(access:PlayerUse(p,button),nil)
  g.links={};facility:RecomputePower(0);eq(access:PlayerUse(p,button),false)
 `);
};
