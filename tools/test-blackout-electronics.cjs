const fs=require('fs'),runtime=require('./glua-runtime.cjs');
const source=files=>files.map(f=>'do local function source()\n'+runtime(fs.readFileSync(f,'utf8'))+'\nend;source() end').join('\n');
const section=(file,start,end)=>{const text=fs.readFileSync(file,'utf8');const a=text.indexOf(start),b=text.indexOf(end,a+start.length);if(a<0||b<0)throw Error(file+' section missing');return runtime(text.slice(a,b));};
module.exports=run=>{
 const setup=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua','tools/fixtures/facility.lua'])+`
 ix.util={Include=function() end};ix.lang={AddTable=function() end}
 bit={bor=function(a,b) return a+b end}
 ix.type={bool=1,number=2,color=3,string=4,optional=8};commands={};ix.command={Add=function(k,v) commands[k]=v end}
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 B={};PLUGIN=B;ix.plugin.list.blackout=B
 hook.Run=function() end
 pending={};timer.Simple=function(_,fn) pending[#pending+1]=fn end
 `+source(['helix/plugins/area/sh_geometry.lua','ixhl2rp/plugins/blackout/sh_plugin.lua','ixhl2rp/plugins/blackout/sv_plugin.lua','ixhl2rp/plugins/blackout/sh_commands.lua','helix/gamemode/core/libs/sv_devicepower.lua','helix/gamemode/core/libs/sh_broadcastmedia.lua'])+`
 ix.plugin.list.facility_utilities=nil
 B.LoadFuseboxes=function() end;B.SaveFuseboxes=function() end
 local originalLightUpdate=B.SetZoneLights
 updates=0;B.SetZoneLights=function() updates=updates+1 end
 function zone(active) return {min=Vector(-20,-20,-20),max=Vector(20,20,20),active=active} end
 inside=Vector();outside=Vector(100,0,0)
 B.zones={room=zone(true)}
 function device(id,class,pos) local e=entity(id,'test',pos);e.class=class;return e end
 function restrict(v) B:SetElectronicsRestricted(v) end
 `;
 const suite=(name,body)=>run(name,[],setup+body);
 suite('Electronics restriction uses active raw zones, preserves visual darkness and follows movement',`
  local terminal=device(1,'ix_foundation_terminal',inside)
  eq(B:IsEntityBlackedOut(terminal),true)
  restrict(true);eq(B:IsEntityBlackedOut(terminal),false);eq(B:IsPosBlackedOut(inside),true)
  terminal.pos=outside;eq(B:IsEntityBlackedOut(terminal),true);eq(B:IsPosBlackedOut(outside),false)
  B.zones.room.active=false;terminal.pos=inside;eq(B:IsEntityBlackedOut(terminal),true)
  B.zones={};eq(B:IsEntityBlackedOut(terminal),true)
  B.zones={room=zone(nil)};eq(B:IsEntityBlackedOut(terminal),true)
  B.zones={inactive=zone(false),room=zone(true)};eq(B:IsEntityBlackedOut(terminal),false)
  restrict(false);eq(B:IsEntityBlackedOut(terminal),true);terminal.pos=outside;eq(B:IsEntityBlackedOut(terminal),false)
 `);
 suite('Connected backup and active zones override the mains restriction without changing visual darkness',`
  ix.Facility={EntityBackup=function(e) return e.ixGeneratorPower==true end}
  hook.Run=function(name) if name=='FacilityPowerAt' then return false end end
  local terminal=device(1,'ix_foundation_terminal',outside)
  restrict(true);eq(B:IsEntityBlackedOut(terminal),true)
  terminal.ixGeneratorPower=true;eq(B:IsEntityBlackedOut(terminal),false)
  eq(B:IsElectronicsOffAt(outside),true) -- backup belongs to the endpoint, not its position
  terminal.ixGeneratorPower=false
  terminal.pos=inside;eq(B:IsEntityBlackedOut(terminal),false);eq(B:IsPosBlackedOut(inside),false)
  restrict(false);eq(B:IsEntityBlackedOut(terminal),false)
 `);
 suite('Admin electronics command is explicit, persistent and synchronizes joining clients',`
  eq(commands.BlackoutElectronics.adminOnly,true);eq(commands.BlackoutElectronics.privilege,'Manage Blackouts')
  eq(commands.BlackoutElectronics.arguments[1],ix.type.bool)
  commands.BlackoutElectronics.OnRun(nil,admin(),true)
  eq(stored.blackoutElectronicsRestricted,true);eq(updates,1)
  B:SaveData();B.electronicsRestricted=false;B:LoadData();eq(B.electronicsRestricted,true)
  local p=admin();B:NetworkZones(p)
  local packet=net.packets[#net.packets-1];eq(packet.name,'ixBlackoutElectronics');eq(packet.boolean,true);eq(packet.integer,1);eq(packet.target,p)
  commands.BlackoutElectronics.OnRun(nil,p,false);eq(stored.blackoutElectronicsRestricted,false)
  B:LoadData();eq(B.electronicsRestricted,false)
 `);
 suite('Client electronics exceptions stay separate from generator-adjusted darkness volumes',`
  restrict(true)
  hook.Run=function(name) if name=='FacilityBlackoutVolumes' then return {} end end
  B:NetworkZones();eq(net.packets[#net.packets].integer,0);eq(net.packets[#net.packets-1].integer,1)
  SERVER=false;CLIENT=true
  net.ReadBool=function() return true end;net.ReadUInt=function() return 1 end
  local points={Vector(-20,-20,-20),Vector(20,20,20)}
  net.ReadVector=function() return table.remove(points,1) end
 `+runtime(fs.readFileSync('ixhl2rp/plugins/blackout/cl_plugin.lua','utf8').split('-- Two stencil bits:')[0])+`
  B.zones={};net.handlers.ixBlackoutElectronics()
  eq(B:IsElectronicsOffAt(inside),false);eq(B:IsElectronicsOffAt(outside),true);eq(B:IsPosBlackedOut(inside),false)
  ix.Facility={EntityBackup=function(e) return e:GetNW2Bool('ixGeneratorPower',false) end}
  local terminal=device(81,'ix_foundation_terminal',outside)
  eq(B:IsEntityBlackedOut(terminal),true);terminal:SetNW2Bool('ixGeneratorPower',true);eq(B:IsEntityBlackedOut(terminal),false)
  terminal:SetNW2Bool('ixGeneratorPower',false);eq(B:IsEntityBlackedOut(terminal),true)
 `);
 suite('World electronics block E and stale entity menus without blocking props, patients or carts',`
  restrict(true);local p=admin();p.NotifyLocalized=p.Notify
  for i,class in ipairs({'ix_foundation_terminal','ix_station_stove','ix_facility_speaker','ix_cctv_camera','ix_boombox','ix_stationary_radio','ix_flood_pump','ix_vendingmachine','ix_rationdispenser'}) do
   local e=device(i,class,outside);eq(B:PlayerUse(p,e),false);eq(B:CanPlayerInteractEntity(p,e),false)
   e.pos=inside;eq(B:PlayerUse(p,e),nil)
  end
  for i,class in ipairs({'prop_physics','player','ix_bed','ix_pushcart','ix_item'}) do eq(B:PlayerUse(p,device(50+i,class,outside)),nil) end
 `);
 suite('Forcefields and media use the global electronics rule; EMP and manual state remain separate',`
  restrict(true);local e=device(1,'ix_forcefield',outside)
  eq(ix.DevicePower.IsDisabled(e),true);eq(ix.BroadcastMedia.Powered(e),false)
  e.pos=inside;eq(ix.DevicePower.IsDisabled(e),false);eq(ix.BroadcastMedia.Powered(e),true)
  e.ixHackedUntil=CurTime()+60;eq(ix.DevicePower.IsDisabled(e),true)
  local lock=device(2,'ix_combinelock',inside);lock.door=device(3,'prop_door_rotating',outside)
  eq(B:IsElectronicsOffAt(inside,lock),false)
  lock.pos=outside;lock.door.pos=inside;eq(B:IsElectronicsOffAt(outside,lock),true)
  restrict(false);eq(B:IsElectronicsOffAt(outside,lock),true)
 `);
 suite('Runtime lights restore their original setting across restriction, movement and unload',`
  local e=device(1,'light_dynamic',outside);e.state.m_bState=true
  function e:Input(input) self.lastInput=input end
  ents.GetAll=function() return {e} end
  restrict(true);B:RefreshLights();eq(e.lastInput,'TurnOff')
  e.pos=inside;B:RefreshLights();eq(e.lastInput,'TurnOn')
  e.pos=outside;e.state.m_bState=false;B:RefreshLights();eq(e.lastInput,'TurnOff')
  restrict(false);B:RefreshLights();eq(e.lastInput,'TurnOff')
  restrict(true);e.state.m_bState=true;B.lightStates={};B:RefreshLights()
  B.unloading=true;B:RefreshLights();eq(e.lastInput,'TurnOn');eq(B:IsElectronicsOffAt(outside),false)
 `);
 const facility=source(['ixhl2rp/plugins/facility_utilities/sh_core.lua','ixhl2rp/plugins/facility_utilities/sv_connections.lua','ixhl2rp/plugins/facility_utilities/sv_power.lua','ixhl2rp/plugins/facility_utilities/sv_doors.lua']);
 const reserve=`
  FP={loaded=true,store={circuits={},devices={},doors={}}};PLUGIN=FP
 `+facility+`
  ix.plugin.list.facility_utilities=FP
  function FP:SyncDevice(d) d.entity:SetNW2Bool('ixFacilityPowered',self:DevicePowered(d)) end
  function sourceDevice(kind,id)
   local d={id=id,entity=device(id,'ix_facility_'..kind,Vector(100,0,0)),kind=kind,enabled=true,fuel=20,charge=100,capacity=30,running=true,links={}}
   d.entity.facilityID=id;FP.store.devices[id]=d;return d
  end
  function cable(source,target,kind,id)
   local link={kind=kind or 'entity',id=id,binding={class=target:GetClass(),model=target:GetModel(),mapid=target:MapCreationID(),pos=target:GetPos()}}
   source.links[#source.links+1]=link;FP.linkEntities[link]=target;return link
  end
  restrict(true)
 `;
 suite('Running generators power only their actual cable endpoints under the global restriction',reserve+`
  local g=sourceDevice('generator',1)
  local terminal=device(2,'ix_foundation_terminal',Vector(200,0,0));local neighbour=device(3,'ix_foundation_terminal',Vector(205,0,0))
  local speaker=sourceDevice('speaker',4);speaker.entity.pos=Vector(250,0,0)
  cable(g,terminal);cable(g,speaker.entity,'device',speaker.id);FP:RecomputePower(1)
  eq(B:IsEntityBlackedOut(terminal),false);eq(B:IsEntityBlackedOut(neighbour),true);eq(FP:DevicePowered(speaker),true)
  eq(g.fuel,19);eq(FP:DirectGrid(terminal),false);eq(FP:BatteryMains({entity=terminal}),false)
  eq(B:PlayerUse(admin(),terminal),nil);eq(B:PlayerUse(admin(),g.entity),nil)
  speaker.fault=true;eq(FP:DevicePowered(speaker),false);speaker.fault=false;speaker.enabled=false;eq(FP:DevicePowered(speaker),false)
  speaker.enabled=true
  g.running=false;FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),true);eq(FP:DevicePowered(speaker),false)
  eq(B:PlayerUse(admin(),g.entity),nil) -- start/refuel controls stay accessible
  g.running=true;g.fuel=0;FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),true)
  g.fuel=20;g.fault=true;FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),true)
  g.fault=false;g.enabled=false;FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),true)
  g.enabled=true;FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),false)
  terminal.pos=Vector(2000,0,0);FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),true)
  terminal.pos=Vector(200,0,0);FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),false)
  g.links={};FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),true)
  cable(g,terminal);g.entity.valid=false;FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),true)
 `);
 suite('Battery reserve drains under restriction, stops empty and can recharge from a connected generator',reserve+`
  local battery=sourceDevice('battery',1);battery.charge=10;battery.capacity=5
  local terminal=device(2,'ix_foundation_terminal',Vector(200,0,0));cable(battery,terminal)
  FP:RecomputePower(1);eq(battery.charge,5);eq(B:IsEntityBlackedOut(terminal),false)
  FP:RecomputePower(1);eq(battery.charge,0);FP:RecomputePower(0);eq(B:IsEntityBlackedOut(terminal),true)
  FP:RecomputePower(1);eq(battery.charge,0);eq(FP:BatteryMains(battery),false);eq(B:PlayerUse(admin(),battery.entity),nil)
  local g=sourceDevice('generator',3);g.entity.pos=Vector(150,0,0);cable(g,battery.entity,'battery',battery.id)
  FP:RecomputePower(1);eq(battery.charge,10);eq(battery.chargeSource,'ЗАРЯД: ГЕНЕРАТОР')
  FP:RecomputePower(1);eq(B:IsEntityBlackedOut(terminal),false);eq(battery.charge,15)
  g.running=false;FP:RecomputePower(1);eq(battery.charge,10)
  battery.links={};FP:RecomputePower(1);eq(battery.charge,10);eq(B:IsEntityBlackedOut(terminal),true)
 `);
 suite('Cable power respects source capacity, safety isolation and door access while preserving active-zone exceptions',reserve+`
  local g=sourceDevice('generator',1);g.capacity=5
  local a=device(2,'ix_foundation_terminal',Vector(200,0,0));local b=device(3,'ix_foundation_terminal',Vector(210,0,0))
  cable(g,a);cable(g,b);FP:RecomputePower(0);eq(B:IsEntityBlackedOut(a),false);eq(B:IsEntityBlackedOut(b),true)
  B.zones.safety={min=Vector(190,-20,-20),max=Vector(250,20,20),active=false,remoteIsolation=true}
  FP:RecomputePower(0);eq(B:IsEntityBlackedOut(a),true);eq(FP:EntityIsolated(a),true)
  B.zones.safety.remoteIsolation=false;FP:RecomputePower(0);eq(B:IsEntityBlackedOut(a),false)
  FP.store.circuits.safety={id=1,zone='safety',load=20,priority=1,isolated=true}
  FP:RecomputePower(0);eq(B:IsEntityBlackedOut(a),true);FP.store.circuits={}
  local door=device(4,'prop_door_rotating',Vector(250,0,0));local d={entity=door,level=2,department='security'}
  g.links={};cable(g,door);FP:RecomputePower(0);eq(FP:DoorAllowed(admin(),d),true)
  d.fault=true;eq(FP:DoorAllowed(admin(),d),false);d.fault=false
  local denied=admin(1);denied.admin=false;eq(FP:DoorAllowed(denied,d),false)
  g.running=false;FP:RecomputePower(0);eq(FP:DoorAllowed(admin(),d),false)
  a.pos=inside;eq(B:IsEntityBlackedOut(a),false)
 `);
 suite('Cables can target shut-down radios, media, pumps and runtime lights; powered light state restores correctly',reserve+`
  local g=sourceDevice('generator',1)
  for i,class in ipairs({'ix_boombox','ix_stationary_radio','ix_flood_pump','ix_vendingmachine','light_dynamic','point_spotlight','env_projectedtexture','env_lightglow'}) do
   local e=device(i+1,class,Vector(200,0,0));local link,target=FP:PowerTarget(e)
   assert(link and link.kind=='entity');eq(target,e)
  end
  eq(FP:PowerTarget(device(20,'prop_physics',outside)),nil)
  local light=device(30,'light_dynamic',Vector(200,0,0));light.state.m_bState=true
  function light:Input(input) self.lastInput=input end
  ents.GetAll=function() return {light} end
  B:RefreshLights();eq(light.lastInput,'TurnOff')
  cable(g,light);FP:RecomputePower(0);B:RefreshLights();eq(light.lastInput,'TurnOn')
  g.links={};FP:RecomputePower(0);B:RefreshLights();eq(light.lastInput,'TurnOff')
  light.state.m_bState=false;B.lightStates={};B:RefreshLights();cable(g,light);FP:RecomputePower(0);B:RefreshLights();eq(light.lastInput,'TurnOff')
 `);
 suite('Facility power, batteries and remote doors obey entity location without curing hardware faults',`
  FP={store={circuits={}},backupEntities={}};PLUGIN=FP
 `+facility+`
  restrict(true)
  local e=device(1,'ix_facility_speaker',inside);local d={entity=e,kind='speaker'}
  eq(FP:DevicePowered(d),true);eq(FP:DirectGrid(e),true);eq(FP:BatteryMains(d),true)
  d.fault=true;eq(FP:DevicePowered(d),false);d.fault=false;d.enabled=false;eq(FP:DevicePowered(d),false);d.enabled=true
  e.pos=outside;e.ixGeneratorPower=true;eq(FP:DevicePowered(d),true);eq(FP:DirectGrid(e),false);eq(FP:BatteryMains(d),false)
  d.kind='generator';eq(FP:DevicePowered(d),true)
  ix.Facility.Door=function() return true end;ix.Facility.Access=function() return true end
  eq(FP:DoorAllowed(admin(),d),true);e.ixGeneratorPower=false;eq(FP:DoorAllowed(admin(),d),false)
  e.pos=inside;eq(FP:DoorAllowed(admin(),d),true)
  B.zones.room.remoteIsolation=true;eq(FP:DevicePowered(d),true)
  restrict(false);d.kind='speaker';e.ixGeneratorPower=false;eq(FP:DevicePowered(d),false)
 `);
 suite('CCTV obeys restrictions while manual off and wearable camera batteries retain their meaning',`
 `+source(['ixhl2rp/plugins/cctv/sh_state.lua'])+`
  restrict(true)
  local e=device(1,'ix_cctv_camera',inside)
  ix.CCTV.Transform=function(d) return e.pos,Angle(),e end
  local d={on=true};eq(ix.CCTV.Powered(d),true);e.pos=outside;eq(ix.CCTV.Powered(d),false)
  ix.Facility={EntityBackup=function(e) return e.ixGeneratorPower==true end}
  e.ixGeneratorPower=true;eq(ix.CCTV.Powered(d),true);e.ixGeneratorPower=false
  e.pos=inside;d.on=false;eq(ix.CCTV.Powered(d),false)
  ix.bodycams={Active=function() return true end};d.on=true;d.bodycam=true;e.pos=outside;eq(ix.CCTV.Powered(d),true)
 `);
 suite('Prop-mounted TV screens evaluate their screen position and preserve the manual switch',`
  local P={};local pos=inside;local T={Transform=function() return pos end}
 `+section('ixhl2rp/plugins/tv_screen/cl_plugin.lua','function P:ScreenPowered(s)','function P:DisplayScreen')+`
  ix.Facility={EntityBackup=function(e) return e.ixGeneratorPower==true end}
  restrict(true);local e=device(1,'prop_physics',outside)
  eq(P:ScreenPowered({entity=e,on=true}),true);pos=outside;eq(P:ScreenPowered({entity=e,on=true}),false)
  e.ixGeneratorPower=true;eq(P:ScreenPowered({entity=e,on=true}),true)
  pos=inside;eq(P:ScreenPowered({entity=e,on=false}),false)
 `);
 suite('A pump cannot drain water if power disappears during its interaction',`
  ENT={}
 `+section('ixhl2rp/plugins/flood/entities/entities/ix_flood_pump.lua','function ENT:OnSelectPump(client)','\n\t-- Меню: поднять')+`
  local drained=0;ix.plugin.list.flood={defaults={pumpTime=5},level={room=5},DrainStep=function() drained=drained+1;return 0,true end}
  restrict(true);local e=device(1,'ix_flood_pump',inside);e.OnSelectPump=ENT.OnSelectPump;e.linkedTank={valid=true}
  function e:GetFloodZone() return 'room' end
  local p=admin();p.pos=inside;function p:SetAction(_,_,fn) self.finish=fn end
  e:OnSelectPump(p);assert(p.finish);e.pos=outside;p.finish(p);eq(drained,0)
  e.pos=inside;p.finish(p);eq(drained,1)
 `);
 suite('Recycler completion preserves materials when power is lost before the deferred spawn',`
  ENT={}
 `+section('ixhl2rp/plugins/recyclefactory/entities/entities/ix_factory_recycler.lua','local function powerOff(entity)','\n\tfunction ENT:UpdateTransmitState()')+`
  restrict(true);local e=device(1,'ix_factory_recycler',inside);e.raw=5;e.product='metal';e.workers={}
  e.CreateProduct=ENT.CreateProduct
  function e:GetProduct() return self.product end;function e:SetProduct(v) self.product=v end
  function e:SetRawResource(v) self.raw=v end
  local spawned=0;ix.Item={Instance=function() return {} end,Spawn=function() spawned=spawned+1 end}
  e:CreateProduct(admin());e.pos=outside;pending[#pending]();eq(e.raw,5);eq(e.product,'metal');eq(spawned,0)
  e.pos=inside;e:CreateProduct(admin());pending[#pending]();eq(e.raw,0);eq(e.product,'');eq(spawned,1)
 `);
 suite('Stationary radios stop transmitting without erasing their saved switch state',`
  ENT={}
 `+section('ixhl2rp/plugins/radio/entities/entities/ix_stationary_radio.lua','function ENT:IsOn()','function ENT:GetFrequency')+`
  restrict(true);local e=device(1,'ix_stationary_radio',outside);e.on=true
  function e:GetNetVar() return self.on end;e.IsOn=ENT.IsOn
  eq(e:IsOn(),false);eq(e.on,true);e.pos=inside;eq(e:IsOn(),true)
  e.on=false;eq(e:IsOn(),false);restrict(false);e.pos=outside;e.on=true;eq(e:IsOn(),true)
 `);
 suite('News-editor submission rejects already-open sessions after its terminal loses power',`
  local PLUGIN={editorRadius=140}
 `+section('ixhl2rp/plugins/gonews/sv_plugin.lua','function PLUGIN:NearEditor(client)','-- Рассылка списка новостей')+`
  restrict(true);local e=device(1,'ix_gonews_editor',outside)
  ents.FindInSphere=function() return {e} end
  eq(PLUGIN:NearEditor(admin()),false);e.pos=inside;eq(PLUGIN:NearEditor(admin()),true)
 `);
 suite('Scanner terminals reject new links and eject active pilots on power loss',`
  local PLUGIN={};isentity=IsValid
 `+section('ixhl2rp/plugins/combinescanners/sh_plugin.lua','function PLUGIN:CanEnterToScanner(client, scanner, terminal)','function PLUGIN:CanFoldScanner')+`
  local checkPower;timer.Create=function(_,_,_,fn) checkPower=fn end
 `+section('ixhl2rp/plugins/combinescanners/sv_plugin.lua','timer.Create("ixScannerTerminalPower"','function PLUGIN:SpawnScanner')+`
  restrict(true);local t=device(1,'ix_scannerterminal',outside);local s=device(2,'ix_scanner',outside)
  local p=admin();function p:IsRestricted() return false end
  function s:GetPilot() return self.pilot end;function s:Eject() self.pilot=nil;self.ejected=true end
  eq(PLUGIN:CanEnterToScanner(p,s,t),false);t.pos=inside;eq(PLUGIN:CanEnterToScanner(p,s,t),true)
  s.pilot=p;s.ixControlTerminal=t;ents.FindByClass=function() return {s} end
  checkPower();eq(s.ejected,nil);t.pos=outside;checkPower();eq(s.ejected,true);eq(s.ixControlTerminal,nil)
 `);
 suite('A paid ration waits for power without consuming or duplicating the pending coupon',`
  ENT={}
 `+section('ixhl2rp/entities/entities/ix_rationdispenser.lua','function ENT:SpawnRation(client, coupon, callback, releaseDelay)','function ENT:StartDispense')+`
  restrict(true);local e=device(1,'ix_rationdispenser',outside);e.SpawnRation=ENT.SpawnRation
  local p=admin();local callback=function() end
  e:SpawnRation(p,'coupon',callback,2);eq(#pending,1)
  p.valid=false;pending[1]();eq(#pending,2)
  local delivered=0
  e.SpawnRation=function(_,who,coupon,cb,delay) eq(who,p);eq(coupon,'coupon');eq(cb,callback);eq(delay,2);delivered=delivered+1 end
  e.pos=inside;pending[2]();eq(delivered,1)
 `);
};
