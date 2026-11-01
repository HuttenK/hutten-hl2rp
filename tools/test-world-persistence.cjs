const r=require('./restored-test-runner.cjs');
const files=['helix/gamemode/core/libs/sh_propscreens.lua','ixhl2rp/plugins/world_persistence/sh_plugin.lua','ixhl2rp/plugins/world_persistence/sv_store.lua'];
const setup=r.source(['tools/geometry-fixture.lua'])+`
 function isangle(v) return getmetatable(v)==getmetatable(Angle()) end
 function util.TableToJSON(v)
  if type(v)~='table' then return tostring(v) end
  local keys={};for k in pairs(v) do keys[#keys+1]=k end;table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  local out={};for _,k in ipairs(keys) do out[#out+1]=tostring(k)..':'..util.TableToJSON(v[k]) end
  return '{'..table.concat(out,',')..'}'
 end
 local function copy(v)
  if isvector(v) then return Vector(v.x,v.y,v.z) end
  if isangle(v) then return Angle(v.p,v.y,v.r) end
  if type(v)~='table' then return v end
  local t={};for k,x in pairs(v) do t[k]=copy(x) end;return t
 end
 local disk,writes,entities,scheduled={},{},{},{}
 local currentMap='site_a';local unavailable;local errors={}
 function ErrorNoHalt(s) errors[#errors+1]=s end
 SOLID_VPHYSICS=6;ix.util={Include=function() end}
 local function configure()
  function PLUGIN:SetData(data) disk[currentMap]=copy(data);writes[#writes+1]=copy(data) end
  function PLUGIN:GetData(default) return copy(disk[currentMap] or default) end
  ix.plugin.list.world_persistence=PLUGIN
 end
 configure()
 function timer.Create(id,delay,reps,fn) scheduled[id]=fn end
 function timer.Simple(_,fn) scheduled[#scheduled+1]=fn end
 function timer.Remove(id) scheduled[id]=nil end
 local function flush()
  local work=scheduled;scheduled={}
  for id,fn in pairs(work) do if id~='ixWorldEntitiesAutosave' then fn() end end
 end
 function ents.Create(class)
  if unavailable==class then return {valid=false} end
  local e={valid=true,class=class,pos=Vector(),ang=Angle(),model='default',skin=0,color={r=255,g=255,b=255,a=255},material='',bodygroups={},submaterials={},collision=0,vars={}}
  local ph={valid=true,movable=false};function ph:IsMoveable() return self.movable end;function ph:EnableMotion(v) self.movable=v end
  function e:GetPhysicsObject() return ph end;function e:PhysicsInit() self.physicsRebuilt=true end
  function e:GetClass() return self.class end;function e:MapCreationID() return self.mapid or -1 end
  function e:GetNetVar(k,d) if self.vars[k]~=nil then return self.vars[k] end;return d end
  function e:SetNetVar(k,v) self.vars[k]=v end
  for field,accessor in pairs({pos='Pos',ang='Angles',model='Model',skin='Skin',color='Color',material='Material',collision='CollisionGroup'}) do
   e['Get'..accessor]=function(s) return s[field] end;e['Set'..accessor]=function(s,v) s[field]=v end
  end
  function e:GetBodyGroups() return {{id=0},{id=1}} end
  function e:GetBodygroup(i) return self.bodygroups[i] or 0 end;function e:SetBodygroup(i,v) self.bodygroups[i]=v end
  function e:GetMaterials() return {'one','two'} end
  function e:GetSubMaterial(i) return self.submaterials[i] or '' end;function e:SetSubMaterial(i,v) self.submaterials[i]=v end
  function e:Spawn() self.spawned=true end;function e:Activate() end
  function e:Remove() self.valid=false;PLUGIN:EntityRemoved(self) end
  entities[#entities+1]=e;PLUGIN:OnEntityCreated(e);return e
 end
 function ents.FindByClass(class) local found={};for _,e in ipairs(entities) do if e.valid and e.class==class then found[#found+1]=e end end;return found end
 local function fresh()
  for _,e in ipairs(entities) do e.valid=false end
  PLUGIN.records={};PLUGIN.nextID=1;PLUGIN.loaded=nil;PLUGIN.stopping=nil;ix.shuttingDown=nil
  PLUGIN:LoadData();PLUGIN:PostLoadData();flush()
 end
`;
function suite(name,test){r.run(name,setup+r.source(files)+'\n'+test)}
suite('Both terminal classes and uncovered fixtures survive a new session with appearance and physics',`
 PLUGIN:SaveData();eq(#writes,0);PLUGIN:LoadData()
 for class in pairs(PLUGIN.classes) do
  local e=ents.Create(class);e:SetPos(Vector(10,20,30));e:SetAngles(Angle(0,90,0));e:SetModel('custom.mdl');e:SetSkin(2)
  e:SetColor({r=10,g=20,b=30,a=200});e:SetMaterial('surface');e:SetBodygroup(1,3);e:SetSubMaterial(1,'custom/second');e:GetPhysicsObject():EnableMotion(true)
  e.ixPropScreenHostID='screen_test_'..class
  if class=='ix_garbage' then e.nextRespawn=CurTime()+100 end
  e:Spawn()
 end
 flush();PLUGIN:SaveData();eq(#disk[currentMap].entities,4)
 fresh();eq(#disk[currentMap].entities,4)
 for class in pairs(PLUGIN.classes) do
  local e=ents.FindByClass(class)[1];assert(e and e.spawned);eq(#ents.FindByClass(class),1);eq(e.pos.z,30);eq(e.ang.y,90)
  eq(e.skin,2);eq(e.model,'custom.mdl');eq(e.bodygroups[1],3);eq(e.submaterials[1],'custom/second');eq(e.color.a,200);assert(e:GetPhysicsObject():IsMoveable())
  eq(e.ixPropScreenHostID,'screen_test_'..class)
  if class=='ix_garbage' then assert(e.nextRespawn>CurTime()) end
 end
 PLUGIN:LoadData();PLUGIN:PostLoadData();flush();eq(#ents.FindByClass('ix_foundation_terminal'),1)
`);
suite('Movement, explicit deletion and periodic saving update only this maps placements',`
 PLUGIN:LoadData();local e=ents.Create('ix_foundation_terminal');e:Spawn();flush();PLUGIN:SaveData()
 e.pos=Vector(90,80,70);PLUGIN:PhysgunDrop({},e);flush();eq(disk[currentMap].entities[1].pos.x,90)
 currentMap='site_b';fresh();eq(#ents.FindByClass('ix_foundation_terminal'),0)
 currentMap='site_a';fresh();e=ents.FindByClass('ix_foundation_terminal')[1];eq(e.pos.x,90)
 e:Remove();flush();eq(#disk[currentMap].entities,0);fresh();eq(#ents.FindByClass('ix_foundation_terminal'),0)
`);
suite('Cleanup and shutdown preserve placements without duplicates or deletion snapshots',`
 PLUGIN:LoadData();local e=ents.Create('ix_foundation_public_terminal');e:Spawn();flush()
 PLUGIN:PreCleanupMap();e:Remove();PLUGIN:SaveData();eq(#disk[currentMap].entities,1)
 PLUGIN:PostCleanupMap();PLUGIN:LoadData();PLUGIN:PostLoadData();flush();eq(#ents.FindByClass(e.class),1)
 e=ents.FindByClass(e.class)[1];PLUGIN:ShutDown();ix.shuttingDown=true;e:Remove();flush();eq(#disk[currentMap].entities,1)
 fresh();eq(#ents.FindByClass(e.class),1)
`);
suite('Unavailable classes retain their records and restore on retry; corrupt saves are protected',`
 PLUGIN:LoadData();local e=ents.Create('ix_foundation_terminal');e:Spawn();flush();PLUGIN:SaveData()
 unavailable=e.class;fresh();eq(#ents.FindByClass(e.class),0);eq(#disk[currentMap].entities,1);assert(#errors>0)
 unavailable=nil;PLUGIN:LoadData();flush();eq(#ents.FindByClass(e.class),1)
 disk[currentMap]={version=100,entities={}};PLUGIN.loaded=nil;PLUGIN.records={}
 local ok=pcall(PLUGIN.LoadData,PLUGIN);eq(ok,false);PLUGIN:SaveData();eq(disk[currentMap].version,100)
`);
suite('Map entities and existing Helix persistence keep one save owner; other equipment is untouched',`
 PLUGIN:LoadData()
 local map=ents.Create('ix_foundation_terminal');map.mapid=4
 local legacy=ents.Create('ix_foundation_terminal');legacy.vars.Persistent=true
 for _,class in ipairs({'ix_cctv_camera','ix_facility_generator','ix_pushcart','prop_ragdoll','ix_cart_patient'}) do ents.Create(class) end
 flush();PLUGIN:PostLoadData();flush();eq(next(PLUGIN.records),nil)
 local e=ents.Create('ix_foundation_terminal');flush();PLUGIN:SaveData();eq(#disk[currentMap].entities,1)
`);
r.run('Helix persistent props retain screen host identity and rebind after their saved position changes',setup+`
 ix.Net={Type={Bool=1},AddEntityVar=function() end};properties={Add=function() end};COLLISION_GROUP_WORLD=20
 function PLUGIN:OnEntityCreated() end
 function ents.FindByModel(model) local found={};for _,e in ipairs(entities) do if e.valid and e.model==model then found[#found+1]=e end end;return found end
`+r.source(['helix/gamemode/core/libs/sh_propscreens.lua','helix/plugins/persistence.lua'])+`
 local host=ents.Create('prop_physics');host.model='monitor.mdl';host.ixPropScreenHostID='screen_fixture_42'
 local binding=ix.PropScreens.CaptureBinding(host);host:SetPos(Vector(30,0,0));PLUGIN.stored={host};PLUGIN:SaveData()
 eq(disk[currentMap][1].ScreenHostID,'screen_fixture_42');host.valid=false;PLUGIN.stored={};PLUGIN:LoadData()
 local restored=PLUGIN.stored[1];assert(restored and restored~=host);eq(restored.ixPropScreenHostID,'screen_fixture_42')
 eq(restored.pos.x,30);eq(ix.PropScreens.ResolveBinding(binding,'monitor.mdl'),restored)
 eq(restored:GetNetVar('Persistent'),true)
`);
r.run('A failing plugin cannot abort the other shutdown entity saves',`
 local done={};local errors={}
 function ErrorNoHalt(s) errors[#errors+1]=s end
 HOOKS_CACHE={SaveData={}}
 HOOKS_CACHE.SaveData[{uniqueID='broken'}]=function() error('broken inventory') end
 HOOKS_CACHE.SaveData[{uniqueID='terminal'}]=function() done.terminal=true end
 HOOKS_CACHE.SaveData[{uniqueID='cart'}]=function() done.cart=true end
 Schema={name='test',SaveData=function() done.schema=true end}
 hook.ixCall=function() done.gamemode=true end
 GM={};ix.config.Save=function() end
`+r.native('helix/gamemode/core/libs/sh_plugin.lua','function hook.SafeRun(name, ...)', '\nend\n')+'\n'+
r.native('helix/gamemode/core/hooks/sv_hooks.lua','function GM:ShutDown()','function GM:GetGameDescription()')+`
 GM:ShutDown();assert(done.terminal and done.cart and done.schema and done.gamemode);eq(#errors,1);eq(ix.shuttingDown,true)
`);
r.run('Boombox cleanup retains cassette and player item instances without spawning duplicate pickups',r.source(['tools/geometry-fixture.lua'])+`
 ENT={};function include() end;function AddCSLuaFile() end
 ix.BroadcastMedia={ValidSource=function() return true end}
 local disk,boxes,spawns={}, {},0
 local cassette,playerItem={id=10},{id=11}
 ix.Item={instances={[10]=cassette,[11]=playerItem},Spawn=function() spawns=spawns+1 end,LoadInstanceByID=function() error('Existing item reloaded') end}
 function PLUGIN:SetData(value) disk=value end;function PLUGIN:GetData() return disk end
 ents.FindByClass=function() local live={};for _,box in ipairs(boxes) do if box.valid then live[#live+1]=box end end;return live end
 ents.Create=function()
  local box=setmetatable({valid=true,vars={}}, {__index=ENT})
  function box:SetPos(v) self.pos=v end;function box:GetPos() return self.pos end
  function box:SetAngles(v) self.ang=v end;function box:GetAngles() return self.ang end
  function box:Spawn() end;function box:Activate() end
  function box:SetNetVar(k,v) self.vars[k]=v end;function box:GetNetVar(k,d) local v=self.vars[k];if v==nil then return d end;return v end
  boxes[#boxes+1]=box;return box
 end
`+r.source(['ixhl2rp/plugins/cassette_player/sv_plugin.lua','ixhl2rp/plugins/cassette_player/entities/entities/ix_boombox/init.lua'])+`
 PLUGIN:LoadData();local box=ents.Create();box:SetPos(Vector(2,3,4));box:SetAngles(Angle())
 box.cassetteInstanceID=10;box.boomboxItemID=11;box:SetNetVar('boombox_sound','a.wav')
 PLUGIN:PreCleanupMap();eq(#disk,1);box:OnRemove();box.valid=false;eq(spawns,0)
 PLUGIN:SaveData();eq(#disk,1)
 PLUGIN:PostCleanupMap();eq(#boxes,2);eq(boxes[2].cassetteInstanceID,10);eq(boxes[2].boomboxItemID,11)
 eq(ix.Item.instances[10],cassette);eq(ix.Item.instances[11],playerItem)
 PLUGIN:LoadData();PLUGIN:PostCleanupMap();eq(#boxes,2)
 boxes[2]:OnRemove();eq(spawns,2)
`);
r.finish();
