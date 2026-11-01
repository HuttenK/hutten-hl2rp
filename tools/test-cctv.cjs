const fs=require('fs'),{normalize}=require('./glua.cjs');
module.exports=runSuite=>{
 const suite=(name,files,assertions)=>runSuite(name,[],files.map(f=>'do local function includeFile()\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend;includeFile() end').join('\n')+`
  local function terminalPoint(id,kind,value)
   for _,b in ipairs(PLUGIN:TerminalLayout(id)) do if b.kind==kind and b.value==value then return b.x+8,b.y+8 end end
   error('Missing terminal control '..kind..':'..tostring(value))
  end
  local function terminalButton(id,kind,value) local x,y=terminalPoint(id,kind,value);return PLUGIN:TerminalHit(id,x,y) end
 `+assertions);
 const base=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua'];
 const server=[...base,'ixhl2rp/plugins/cctv/entities/entities/ix_cctv_device.lua','ixhl2rp/plugins/cctv/sv_devices.lua','ixhl2rp/plugins/cctv/sv_surfaces.lua','ixhl2rp/plugins/cctv/sv_network.lua'];
 suite('CCTV monitor placement attaches to the chosen model without spawning a TV and validates links atomically',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();P:PostLoadData();local p=admin()
  local host=entity(700,'models/custom_monitor.mdl',Vector(50,0,64))
  p.trace={Hit=true,Entity=host,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0)}
  p.admin=false;eq(P:Action(p,'place',{kind='monitor'}),false);p.admin=true
  local count=table.Count(entities);local ok,_,id=P:Action(p,'place',{kind='monitor'});assert(ok)
  local d=P.devices[id];eq(d.kind,'monitor');eq(d.entity,host);eq(d.model,host:GetModel());eq(table.Count(entities),count)
  eq(d.camera,0);eq(d.terminal,0);eq(P:CanOperate(p,id),false)
  local camera=makeDevice('camera',Vector(1000,0,64));local terminal=makeDevice('terminal',Vector(20,0,64))
  local cfg=table.Copy(d.config);cfg.w=80;cfg.h=45
  assert(P:Action(p,'configure',{id=id,name='Wall display',on=true,config=cfg,terminal=terminal.id,camera=camera.id}))
  eq(d.camera,camera.id);eq(d.terminal,terminal.id);eq(d.config.w,80)
  cfg.w=90
  eq(P:Action(p,'configure',{id=id,name='Invalid',on=false,config=cfg,terminal=camera.id,camera=camera.id}),false)
  eq(d.config.w,80);eq(d.name,'Wall display');eq(d.on,true)
  eq(P:Action(p,'configure',{id=id,name='Invalid',on=false,config=cfg,terminal=terminal.id,camera=terminal.id}),false)
  eq(d.config.w,80);eq(d.camera,camera.id)
  eq(P:Action(p,'placeSurface',{kind='camera'}),false)
  eq(P:Action(p,'placeSurface',{kind='terminal',id=id}),false);eq(d.kind,'monitor')
  p.admin=false;assert(P:CanWatch(p,id));local feeds=P:ResolveWatch(p,{monitors={id}});eq(#feeds,1);eq(feeds[1].id,camera.id)
  assert(P:Action(p,'switch',{terminal=terminal.id,monitor=id,camera=camera.id}))
  ix.plugin.list.blackout={IsPosBlackedOut=function() return true end};eq(P:CanWatch(p,id),false)
 `);
 suite('CCTV surface monitors retain configuration through load and transfer, and screen removal keeps the prop',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();P:PostLoadData();local p=admin()
  local camera=makeDevice('camera');local terminal=makeDevice('terminal')
  local legacy,old=makeDevice('monitor');legacy.name='Monitor A';legacy.camera=camera.id;legacy.terminal=terminal.id;legacy.on=false
  local host=entity(700,'models/custom_monitor.mdl',Vector(50,0,64))
  p.trace={Hit=true,Entity=host,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0)}
  assert(P:Action(p,'placeSurface',{kind='monitor',id=legacy.id}));eq(IsValid(old),false)
  eq(P.devices[legacy.id],legacy);eq(legacy.camera,camera.id);eq(legacy.terminal,terminal.id)
  P:SaveData();P:LoadData();P:PostLoadData();local d=P.devices[legacy.id]
  eq(d.entity,host);eq(d.kind,'monitor');eq(d.name,'Monitor A');eq(d.camera,camera.id);eq(d.terminal,terminal.id);eq(d.on,false)
  eq(#ents.FindByClass('ix_cctv_monitor'),0)
  local other=entity(701,'models/wide_monitor.mdl',Vector(80,0,64));p.trace.Entity=other;p.trace.HitPos=Vector(75,0,64)
  assert(P:Action(p,'placeSurface',{kind='monitor',id=d.id}));eq(d.entity,other);eq(d.camera,camera.id);eq(d.terminal,terminal.id)
  assert(IsValid(host));eq(ix.PropScreens.Has(host,'ixCCTVSurfaceID',d.id),false)
  assert(P:Action(p,'remove',{id=d.id}));assert(IsValid(other));eq(P.devices[d.id],nil)
  local ok,_,id=P:Action(p,'placeSurface',{kind='monitor'});assert(ok);other:Remove();eq(P.devices[id],nil)
 `);
 suite('CCTV monitor surfaces use their full rectangle for admin E and enforce their own quota',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();P:PostLoadData();local p=admin()
  local host=entity(700,'models/wide_monitor.mdl',Vector(50,0,64))
  p.trace={Hit=true,Entity=host,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0)}
  local ok,_,id=P:Action(p,'placeSurface',{kind='monitor'});assert(ok);local d=P.devices[id]
  d.config.w=100;d.config.h=10;local center,ang=C.Screen(d)
  p.pos=center+ang:Forward()*40+ang:Up()*40
  function p:GetAimVector() return -ang:Up() end
  eq(C.AimTerminal(p,P.devices),d)
  local opened=0;P.OpenAdmin=function(_,client,kind,selected) eq(client,p);eq(kind,nil);eq(selected,id);opened=opened+1 end
  P:KeyPress(p,IN_USE);eq(opened,1);eq(P:PlayerUse(p,host),false)
  clock=clock+1;p.admin=false;P:KeyPress(p,IN_USE);eq(opened,1)
  p.pos=center-ang:Up()*40;eq(C.AimTerminal(p,P.devices),nil)
  p.pos=center+ang:Up()*40;util.TraceLine=function() return {Hit=true} end;eq(C.AimTerminal(p,P.devices),nil)
  util.TraceLine=function() return {Hit=false} end;p.admin=true;C.kinds.monitor.limit=1
  eq(P:Action(p,'placeSurface',{kind='monitor'}),false)
  assert(P:Action(p,'placeSurface',{kind='terminal'}))
 `);
 suite('CCTV spawn-menu monitor opens surface placement and never returns or creates a host prop',
 [...server,'ixhl2rp/plugins/cctv/entities/entities/ix_cctv_monitor.lua'],`
  PLUGIN:LoadData();local p=admin();local count=table.Count(entities);local opened=0
  PLUGIN.OpenAdmin=function(_,client,kind) eq(client,p);eq(kind,'monitor');opened=opened+1 end
  eq(ENT:SpawnFunction(p),nil);eq(opened,1);eq(table.Count(entities),count)
  p.admin=false;ENT:SpawnFunction(p);eq(opened,1)
 `);
 suite('CCTV places only authorized devices using authoritative traces, validates names and rejects invalid configuration',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();local p=admin()
  p.trace={Hit=true,HitWorld=true,HitPos=Vector(80,0,64),HitNormal=Vector(-1,0,0)}
  p.admin=false;eq(P:Action(p,'place',{kind='camera'}),false);eq(table.Count(P.devices),0)
  p.admin=true;assert(P:Action(p,'place',{kind='camera',pos=Vector(9000,0,0)}));local cam=P.devices[1]
  vectorNear(cam.entity:GetPos(),Vector(68.7,0,62.2));eq(cam.kind,'camera')
  assert(P:Action(p,'configure',{id=1,name='Северный коридор',on=true,ang={p=0,y=90,r=0},fov=60}))
  eq(cam.name,'Северный коридор');near(cam.entity:GetAngles().y,90)
  eq(P:Action(p,'configure',{id=1,name='bad',on=true,ang={p=0,y=math.huge,r=0},fov=60}),false)
  eq(P:Action(p,'configure',{id=1,name='bad',on=true,ang={p=0,y=0,r=0},fov=0/0}),false)
  eq(cam.name,'Северный коридор');eq(C.Name(string.rep('Я',49)),nil);eq(C.Name('a\\nb'),nil)
  p.trace.HitPos=Vector(9000,0,0);eq(P:Action(p,'place',{kind='monitor'}),false)
  p.trace.HitPos=Vector(80,0,64);p.trace.HitSky=true;eq(P:Action(p,'place',{kind='monitor'}),false)
 `);
 suite('CCTV terminal changes only linked monitors and enforces distance, walls, character and power on the server',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();local p=admin()
  local cam=makeDevice('camera',Vector(1000,0,64));local term=makeDevice('terminal',Vector(20,0,64))
  local first=makeDevice('monitor',Vector(40,0,64));local second=makeDevice('monitor',Vector(50,0,64));local other=makeDevice('monitor')
  for _,m in ipairs({first,second}) do assert(P:Action(p,'configure',{id=m.id,name=m.name,on=true,terminal=term.id,camera=0})) end
  p.admin=false;assert(P:Action(p,'switch',{terminal=term.id,monitor=first.id,camera=cam.id}))
  eq(first.camera,cam.id);eq(second.camera,0);eq(other.camera,0)
  assert(P:Action(p,'switch',{terminal=term.id,monitor=0,camera=cam.id}));eq(second.camera,cam.id);eq(other.camera,0)
  eq(P:Action(p,'configure',{id=cam.id}),false)
  p.pos=Vector(1000,0,64);eq(P:Action(p,'switch',{terminal=term.id,monitor=0,camera=cam.id}),false)
  p.pos=Vector(0,0,64);util.TraceLine=function() return {Hit=true} end;eq(P:CanOperate(p,term.id),false)
  util.TraceLine=function() return {Hit=false} end;p.noCharacter=true;eq(P:CanOperate(p,term.id),false);p.noCharacter=false
  term.on=false;eq(P:CanOperate(p,term.id),false);term.on=true
  ix.plugin.list.blackout={IsPosBlackedOut=function() return true end};eq(P:CanOperate(p,term.id),false)
 `);
 suite('CCTV persists names, angles and links, retains unresolved bindings, and survives cleanup and shutdown',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();local cam,ce=makeDevice('camera',Vector(1000,0,64))
  local term=makeDevice('terminal');local mon=makeDevice('monitor');mon.camera=cam.id;mon.terminal=term.id
  cam.name='North';ce:SetAngles(Angle(25,45,0));P:SaveData();local ids={cam.id,term.id,mon.id};local nextID=P.nextID
  P:LoadData();eq(table.Count(P.devices),3);eq(P.nextID,nextID);eq(P.devices[cam.id].name,'North')
  near(P.devices[cam.id].entity:GetAngles().p,25);eq(P.devices[mon.id].camera,cam.id)
  P.devices[cam.id].entity:Remove();eq(P.devices[cam.id],nil);eq(P.devices[mon.id].camera,0)
  P:LoadData();eq(table.Count(P.devices),2);eq(P.devices[mon.id].camera,0)
  P:PreCleanupMap();for _,d in pairs(P.devices) do d.entity:Remove() end
  P:PostCleanupMap();eq(table.Count(P.devices),2);eq(P.devices[mon.id].terminal,term.id)
  P:ShutDown();for _,d in pairs(P.devices) do d.entity:Remove() end
  eq(#stored.foundation_cctv_v1.devices,2)
 `);
 suite('CCTV subscriptions grant only visible nearby monitor feeds, deduplicate views, expire and limit remote PVS',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();local p=admin();p.admin=false
  local cameras,monitors={},{}
  for i=1,6 do local cam=makeDevice('camera',Vector(2000+i*100,0,64));local mon=makeDevice('monitor',Vector(100+i*10,0,64));mon.camera=cam.id;cameras[i]=cam;monitors[i]=mon.id end
  local feeds,grants=P:ResolveWatch(p,{monitors=monitors,preview=cameras[6].id});eq(#feeds,4);eq(#grants,4)
  P.devices[monitors[2]].camera=cameras[1].id;feeds,grants=P:ResolveWatch(p,{monitors=monitors});eq(#feeds,3)
  P.watchers[p]={grants=grants,expires=clock+1};P:SetupPlayerVisibility(p);eq(#origins,3)
  P.devices[monitors[1]].on=false;origins={};P:SetupPlayerVisibility(p);eq(#origins,2)
  p.pos=Vector(10000,0,64);origins={};P:SetupPlayerVisibility(p);eq(#origins,0)
  feeds=P:ResolveWatch(p,{monitors=monitors,preview=cameras[6].id});eq(#feeds,0)
  p.admin=true;feeds,grants=P:ResolveWatch(p,{preview=cameras[6].id});eq(#feeds,1)
  P.watchers[p]={grants=grants,expires=clock+1};clock=clock+2;P:SetupPlayerVisibility(p);eq(#origins,0)
  p.pos=Vector(0,0,64);p.admin=false;util.TraceLine=function() return {Hit=true} end
  feeds=P:ResolveWatch(p,{monitors=monitors});eq(#feeds,0)
  local reads=0;net.ReadString=function() reads=reads+1;return '' end
  net.handlers.ixCCTVWatch(20000,p);eq(reads,0);net.handlers.ixCCTVAction(50000,p);eq(reads,0)
 `);
 suite('CCTV quotas and device protections block player tampering without affecting ordinary props',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();local p=admin();p.admin=false
  local cam,ent=makeDevice('camera');eq(P:PhysgunPickup(p,ent),false);eq(P:CanTool(p,{Entity=ent}),false);eq(P:CanProperty(p,'remove',ent),false)
  eq(P:CanPlayerSpawnSENT(p,C.kinds.camera.class),false);eq(P:CanTool(p,{Entity=entity(5,'models/test.mdl')}),nil)
  p.admin=true;eq(P:PhysgunPickup(p,ent),nil)
  for i=2,C.kinds.camera.limit do makeDevice('camera') end
  eq(P:HasSpace('camera'),false);eq(P:CanPlayerSpawnSENT(p,C.kinds.camera.class),false);assert(P:HasSpace('monitor'))
 `);
 const client=[...base,'tools/fixtures/tv-client.lua','tools/fixtures/tv-controls.lua','tools/fixtures/cctv-render.lua','ixhl2rp/plugins/cctv/cl_network.lua','ixhl2rp/plugins/cctv/cl_render.lua','ixhl2rp/plugins/cctv/cl_controls.lua','ixhl2rp/plugins/cctv/cl_terminal.lua','ixhl2rp/plugins/cctv/cl_placement.lua','ixhl2rp/plugins/cctv/cl_surfaces.lua'];
 suite('CCTV monitor editor previews and saves camera links, dimensions and same-kind transfer without a prop ghost',client,`
  local P,C=PLUGIN,ix.CCTV
  local camera=clientMonitor(1,Vector(1000,0,64));camera.kind='camera'
  clientTerminal(2,Vector(30,0,64))
  local host=entity(700,'models/custom_monitor.mdl',Vector(50,0,64))
  local d=clientSurface(100,host,{x=8,y=0,z=0,p=0,yaw=90,r=90,w=80,h=40})
  d.kind='monitor';d.camera=1;d.terminal=2
  P.Request=function(_,action,v) lastAction=action;lastData=table.Copy(v) end
  P:OpenAdminUI(100);eq(P.preview,1);eq(P.editSurface.kind,'monitor')
  uiFind('DButton','Пропорции видео 16:9'):DoClick();near(P.editSurface.config.h,45)
  for _,panel in ipairs(uiPanels) do if panel.valid and panel.kind=='DComboBox' and panel.choices[1] then panel:OnSelect(1,'None',0) end end
  eq(P.preview,0);eq(P.editSurface.camera,0);eq(d.camera,1)
  uiFind('DButton','Сохранить экран'):DoClick();eq(lastAction,'configure');eq(lastData.camera,0);eq(lastData.terminal,2);near(lastData.config.h,45)
  uiFind('DButton','Перенести экран на другой prop'):DoClick();eq(P.placing,'monitor');eq(P.replaceTerminal,100);eq(P.ghost,nil);eq(P.preview,0)
  client.trace={Hit=true,Entity=host,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0)}
  hooks.CreateMove.ixCCTVPlacement(inputCommand(false,false));eq(P.surfacePlacement.kind,'monitor')
  hooks.CreateMove.ixCCTVPlacement(inputCommand(true,false));eq(lastAction,'placeSurface');eq(lastData.kind,'monitor');eq(lastData.id,100);eq(lastData.config,nil)
  P:OpenSurfaceEditor(100);uiFind('DButton','Добавить ещё один экран'):DoClick();eq(P.placing,'monitor');eq(P.replaceTerminal,nil)
 `);
 suite('CCTV render budget shares duplicate feeds, caps cameras and restores state after errors without recursion',client,`
  local P,C=PLUGIN,ix.CCTV;client.pos=Vector();viewAngle=Angle()
  for id=1,4 do P.devices[id]={id=id,kind='camera',name='Cam '..id,on=true,pos=Vector(1000,0,0),ang=Angle()};P.demand[id]=true end
  local start=clock
  for n=1,120 do
   clock=start+n/60
   for id=1,4 do P.feeds[id]={id=id,pos=Vector(1000,0,0),ang=Angle(),fov=75,received=clock,first=start-1} end
   hooks.PostRender.ixCCTVFeeds()
  end
  assert(renderCalls<=32 and renderCalls>=24);eq(allocations,4);eq(depth,0);eq(C.rendering,false)
  for id=1,4 do assert(P:FeedSlot(id).updated) end
  local before=renderCalls;P.demand={};clock=clock+1;hooks.PostRender.ixCCTVFeeds();eq(renderCalls,before)
  P.demand={[1]=true};P.feeds[1].received=clock;failRender=true;clock=clock+.2;hooks.PostRender.ixCCTVFeeds()
  eq(depth,0);eq(C.rendering,false);near(render.GetBlend(),.4);local r,g,b=render.GetColorModulation();near(r,.2);near(g,.3);near(b,.4);eq(DisableClipping(false),false)
  eq(#errors,1);eq(P:FeedSlot(1).updated,nil);failRender=false
  clock=clock+.2;P.feeds[1].received=clock;hooks.PostRender.ixCCTVFeeds();assert(P:FeedSlot(1).updated);eq(allocations,4)
 `);
 suite('CCTV ignores distant and obstructed monitors and sends only nearby unique feed requests',client,`
  local P,C=PLUGIN,ix.CCTV;client.pos=Vector();viewAngle=Angle()
  clientMonitor(10,Vector(100,0,0),1);clientMonitor(11,Vector(150,0,0),1);clientMonitor(12,Vector(-100,0,0),2);clientMonitor(13,Vector(5000,0,0),3)
  hooks.Think.ixCCTVClient();eq(#P.visible,2);local packet=net.packets[#net.packets];eq(packet.name,'ixCCTVWatch')
  local v=util.JSONToTable(packet.value);eq(#v.monitors,1);eq(v.preview,0)
  clock=clock+1;util.TraceLine=function() return {Hit=true} end;hooks.Think.ixCCTVClient();eq(#P.visible,0)
  v=util.JSONToTable(net.packets[#net.packets].value);eq(#v.monitors,0)
  client.dead=true;P:OnUnload();eq(hooks.PostRender.ixCCTVFeeds,nil);eq(hooks.ShouldDrawLocalPlayer.ixCCTVLocalPlayer,nil)
 `);
 suite('CCTV UI configures a monitor link, names a camera and switches only from the chosen terminal',client,`
  local P,C=PLUGIN,ix.CCTV;client.pos=Vector();viewAngle=Angle()
  P.devices[1]={id=1,kind='camera',name='North camera',on=true,pos=Vector(1000,0,0),ang=Angle(),fov=75}
  local terminal=clientTerminal(2,Vector(20,0,0));terminal.name='Security console'
  local mon=clientMonitor(3,Vector(40,0,0),1);mon.terminal=2
  P.Request=function(_,action,data) lastAction=action;lastData=table.Copy(data) end
  P:OpenAdminUI(3);uiFind('DButton','Сохранить настройки'):DoClick();eq(lastAction,'configure');eq(lastData.terminal,2);eq(lastData.camera,1)
  P:OpenAdminUI(1);eq(P.preview,1);uiFind('DTextEntry','North camera'):SetText('Named camera');uiFind('DButton','Сохранить настройки'):DoClick();eq(lastData.name,'Named camera')
  P:OpenTerminalUI(2);eq(P.preview,0)
  P:ActivateTerminalButton(2,terminalButton(2,'camera',1));eq(lastAction,'switch');eq(lastData.terminal,2);eq(lastData.monitor,0);eq(lastData.camera,1)
  local host=P.terminalUI.host;client.pos=Vector(5000,0,0);host:Think();eq(P.terminalUI,nil);eq(host.valid,false)
 `);
 suite('CCTV entity classes appear beside Foundation terminals and retain authorized spawn behavior',server,`
  local saved=ENT
  ${['camera','monitor','terminal'].map(kind=>`do ENT={}\n${normalize(fs.readFileSync('ixhl2rp/plugins/cctv/entities/entities/ix_cctv_'+kind+'.lua','utf8'))}\neq(ENT.Category,'Foundation');eq(ENT.SubCategory,'CCTV');eq(ENT.Base,'ix_cctv_device');eq(ENT.CCTVKind,'${kind}');eq(ENT.Spawnable,${kind!=='terminal'});eq(ENT.AdminOnly,true);assert(ENT.IconOverride) end`).join('\n')}
  ENT=saved;PLUGIN:LoadData();local p=admin()
  local definition=setmetatable({CCTVKind='camera'},{__index=ENT})
  local trace={Hit=true,HitPos=Vector(40,0,64),HitNormal=Vector(-1,0,0)}
  p.admin=false;eq(definition:SpawnFunction(p,trace,'ix_cctv_camera'),nil)
  p.admin=true;local ent=definition:SpawnFunction(p,trace,'ix_cctv_camera')
  assert(IsValid(ent));eq(ent:GetClass(),'ix_cctv_camera');eq(table.Count(PLUGIN.devices),1)
 `);
 suite('CCTV world terminal lists every named camera and linked monitor with pagination, selection and live updates',client,`
  local P=PLUGIN;client.pos=Vector(70,0,0);local term=clientTerminal(100,Vector(20,0,0))
  for id=1,14 do P.devices[id]={id=id,kind='camera',name='Camera '..id,on=id~=14,pos=Vector(1000,0,0),ang=Angle()} end
  for id=20,27 do local m=clientMonitor(id,Vector(40,0,0),1);m.terminal=100 end
  P:OpenTerminalUI(100);local s=P.terminalUI.state
  local rows=P:TerminalLayout(100);eq(#rows.cameras,14);eq(rows.cameraPages,3);eq(rows.monitorPages,2)
  eq(terminalButton(100,'camera',1).value,1)
  P:ScrollTerminal(100,-1,500);P:ScrollTerminal(100,-1,500);P:ScrollTerminal(100,-1,500);eq(s.cameraPage,3)
  local b=terminalButton(100,'camera',14);eq(b.value,14);eq(b.detail,'НЕТ СИГНАЛА')
  P:ScrollTerminal(100,-1,50);eq(s.monitorPage,2)
  P:ActivateTerminalButton(100,terminalButton(100,'monitor',25));eq(s.monitor,25)
  P.Request=function(_,action,v) lastAction=action;lastData=v end
  P:ActivateTerminalButton(100,b);eq(lastData.camera,14);eq(lastData.monitor,25);eq(lastData.terminal,100)
  P.devices[25].terminal=101;rows=P:TerminalLayout(100);eq(s.monitor,0)
  P.devices[13]=nil;P.devices[14]=nil;rows=P:TerminalLayout(100);eq(s.cameraPage,2)
  for _,m in ipairs(rows.monitors) do m.terminal=101 end
  eq(terminalButton(100,'camera',7),nil);eq(#P:TerminalLayout(100).cameras,12)
 `);
 suite('CCTV projected terminal input matches rotated screen coordinates and rejects backsides, walls and missed clicks',client,`
  local P,C=PLUGIN,ix.CCTV
  for _,angle in ipairs({Angle(),Angle(0,95,0),Angle(15,-50,23)}) do
   local d,e=clientTerminal(100,Vector(20,0,64),angle);local center,a,w,h=C.Screen(d)
   client.pos=center+a:Up()*55
   aimAtTerminal(d,400,210);local x,y=P:TerminalCursor(100);near(x,400);near(y,210)
   eq(C.TerminalRay(d,client.pos,a:Up()),nil)
   eq(C.TerminalRay(d,center-a:Up()*55,a:Up()),nil)
   aimAtTerminal(d,900,210);eq(P:TerminalCursor(100),nil)
   aimAtTerminal(d,400,210);util.TraceLine=function() return {Hit=true} end;eq(P:TerminalCursor(100),nil)
   util.TraceLine=function() return {Hit=false} end
  end
  local d=clientTerminal(100,Vector(20,0,64));client.pos=Vector(80,0,64)
  P.devices[1]={id=1,kind='camera',name='Camera',on=true,pos=Vector(1000,0,0),ang=Angle()}
  local m=clientMonitor(2,Vector(30,0,64),1);m.terminal=100
  P.Request=function(_,a,v) lastAction=a;lastData=v end
  P:OpenTerminalUI(100);local host=P.terminalUI.host;eq(host.kind,'EditablePanel');eq(host.keyboard,false)
  local bx,by=terminalPoint(100,'camera',1)
  aimAtTerminal(d,bx,by);host:OnMousePressed(MOUSE_LEFT);host:OnMouseReleased(MOUSE_LEFT);eq(lastAction,nil)
  host:Think();eq(host.cursor,'hand');host:OnMousePressed(MOUSE_LEFT)
  aimAtTerminal(d,900,by);host:OnMouseReleased(MOUSE_LEFT);eq(lastAction,nil);eq(host.captured,false)
  aimAtTerminal(d,bx,by);host:OnMousePressed(MOUSE_LEFT);host:OnMouseReleased(MOUSE_LEFT)
  eq(lastAction,'switch');eq(lastData.camera,1);eq(lastData.monitor,0)
  local cmd={ClearMovement=function(self) self.movement=true end,ClearButtons=function(self) self.buttons=true end,SetViewAngles=function(self,v) self.angles=v end}
  hooks.CreateMove.ixCCTVTerminalInput(cmd);assert(cmd.movement and cmd.buttons and cmd.angles)
  host:OnMousePressed(MOUSE_RIGHT);eq(P.terminalUI,nil);eq(host.valid,false)
 `);
 suite('CCTV terminal hover stays in the player viewport across camera captures without resetting its cursor or layout',client,`
  local P,C=PLUGIN,ix.CCTV;client.pos=Vector(80,0,64)
  local d=clientTerminal(100,Vector(20,0,64))
  P.devices[1]={id=1,kind='camera',name='Camera',on=true,pos=Vector(1000,0,0),ang=Angle()}
  local m=clientMonitor(2,Vector(30,0,64),1);m.terminal=100
  local sw,sh=1920,1080;ScrW=function() return sw end;ScrH=function() return sh end
  -- Include an offset viewport and a CalcView origin distinct from the player.
  render.GetViewSetup=function(noPlayer)
   eq(noPlayer,false)
   return {origin=client.pos+Vector(0,2,3),angles=viewAngle,fov=viewFOV,
    width=sw-100,height=sh-80,x=50,y=40,aspect=(sw-100)/(sh-80)}
  end
  local bx,by=terminalPoint(100,'camera',1)
  aimAtTerminal(d,bx,by);P:OpenTerminalUI(100);local host=P.terminalUI.host
  host:Think();eq(host.cursor,'hand');eq(host.cursorChanges,2);eq(host.resizes,1)
  local capture=render.RenderView
  render.RenderView=function(v)
   capture(v)
   EyePos=function() return v.origin end
   EyeAngles=function() return v.angles end
   gui.ScreenToVector=function() return v.angles:Forward() end
  end
  for i=1,24 do
   local slot={target={}}
   P:CaptureFeed({id=1,pos=Vector(1000+i,0,0),ang=Angle(i,i*10,0)},slot)
   assert(slot.updated);host:Think()
   eq(P.terminalUI.hover,'camera:1');eq(host.cursor,'hand')
   local x,y=P:TerminalCursor(100);near(x,bx);near(y,by)
  end
  eq(host.cursorChanges,2);eq(host.resizes,1)
  -- Keep hit testing accurate at low/high FOV and after a resolution change.
  for _,fov in ipairs({55,100,150}) do
   viewFOV=fov;aimAtTerminal(d,bx,by);host:Think();eq(host.cursor,'hand')
   local x,y=P:TerminalCursor(100);near(x,bx);near(y,by)
  end
  sw,sh=1600,900;aimAtTerminal(d,bx,by);host:Think();host:Think()
  eq(host.resizes,2);eq(host.cursorChanges,2)
  P.Request=function(_,action) lastAction=action end
  host:OnMousePressed(MOUSE_LEFT);host:OnMouseReleased(MOUSE_LEFT);eq(lastAction,'switch')
  aimAtTerminal(d,700,420);host:Think();host:Think();eq(host.cursor,'arrow');eq(host.cursorChanges,3)
  aimAtTerminal(d,bx,by);host:Think();eq(host.cursorChanges,4)
  host:OnMousePressed(MOUSE_RIGHT);eq(P.terminalUI,nil);eq(host.valid,false)
 `);
 suite('CCTV terminal draws the list in world space without extra captures and closes on power loss or removal',client,`
  local P,C=PLUGIN,ix.CCTV;client.pos=Vector(80,0,64);local d=clientTerminal(100,Vector(20,0,64))
  P.devices[1]={id=1,kind='camera',name='Named Camera',on=true,pos=Vector(1000,0,0),ang=Angle()}
  local m=clientMonitor(2,Vector(30,0,64),1);m.terminal=100
  local painted={};draw.SimpleText=function(text) painted[text]=true end
  P:DrawScreen(d);assert(painted['001 / Named Camera']);eq(cameraDepth,0);eq(renderCalls,0);eq(allocations,0)
  near(surface.GetAlphaMultiplier(),.7);near(render.GetBlend(),.4);eq(DisableClipping(false),false)
  P:OpenTerminalUI(100);eq(P.preview,0);P:OpenTerminalUI(100);local host=P.terminalUI.host
  d.on=false;host:Think();eq(P.terminalUI,nil);eq(host.valid,false);d.on=true
  P:OpenTerminalUI(100);host=P.terminalUI.host;P.devices[100]=nil;host:Think();eq(P.terminalUI,nil)
  P.devices[100]=d;P:OpenTerminalUI(100);host=P.terminalUI.host;util.TraceLine=function() return {Hit=true} end
  host:Think();eq(P.terminalUI,nil);util.TraceLine=function() return {Hit=false} end
  P:OpenTerminalUI(100);P:OnUnload();eq(P.terminalUI,nil);eq(hooks.CreateMove.ixCCTVTerminalInput,nil)
 `);
 suite('CCTV attaches control screens to chosen props, follows transforms, transfers legacy links and preserves host props',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();P:PostLoadData();local p=admin()
  local host=entity(700,'models/props/cs_office/computer_monitor.mdl',Vector(50,0,64),Angle(5,35,10))
  p.trace={Hit=true,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0),Entity=host}
  local ok,_,id=P:Action(p,'placeSurface',{});assert(ok);local d=P.devices[id]
  eq(d.entity,host);eq(d.surface,true);eq(host:GetNW2Int('ixCCTVSurfaceID'),id);eq(#ents.FindByClass('ix_cctv_terminal'),0)
  local cfg=d.config;local expected=LocalToWorld(Vector(cfg.x,cfg.y,cfg.z),Angle(cfg.p,cfg.yaw,cfg.r),host:GetPos(),host:GetAngles())
  vectorNear(C.Screen(d),expected)
  host:SetAngles(Angle(10,80,5));host:SetPos(Vector(90,20,64));P:PhysgunDrop(p,host)
  expected=LocalToWorld(Vector(cfg.x,cfg.y,cfg.z),Angle(cfg.p,cfg.yaw,cfg.r),host:GetPos(),host:GetAngles());vectorNear(C.Screen(d),expected)
  vectorNear(C.Vector(d.binding.pos),host:GetPos())
  local term,old=makeDevice('terminal');local mon=makeDevice('monitor');mon.terminal=term.id
  local second=entity(701,'models/test.mdl',Vector(50,0,64));p.trace.Entity=second
  assert(P:Action(p,'placeSurface',{id=term.id}));eq(mon.terminal,term.id);eq(IsValid(old),false);eq(P.devices[term.id].entity,second)
  assert(P:Action(p,'placeSurface',{id=id}));eq(P.devices[term.id].entity,second) -- both screens share the host
  assert(P:Action(p,'remove',{id=id}));eq(IsValid(host),true);eq(host:GetNW2Int('ixCCTVSurfaceID'),0)
  P:OnUnload();eq(IsValid(second),true)
 `);
 suite('CCTV prop bindings preserve model presets, delete explicitly removed hosts and wait for delayed restores',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();P:PostLoadData();local p=admin()
  local host=entity(700,'models/test.mdl',Vector(50,0,64));host.mapid=-1
  p.trace={Hit=true,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0),Entity=host}
  local ok,_,id=P:Action(p,'placeSurface',{});assert(ok);local mon=makeDevice('monitor');mon.terminal=id
  local cfg=table.Copy(P.devices[id].config);cfg.w=60;cfg.h=40
  assert(P:Action(p,'surfacePreset',{id=id,config=cfg}));eq(stored.foundation_cctv_presets_v1[host.model].w,60)
  P:SaveData();P:PreCleanupMap();host:Remove();assert(P.devices[id]);eq(#stored.foundation_cctv_v1.devices,2)
  P:LoadData();assert(P.devices[id]);eq(P.devices[id].entity,nil)
  host=entity(900,'models/test.mdl',Vector(50,0,64));host.mapid=-1
  P:PostLoadData();eq(P.devices[id].entity,host);eq(P.surfacePresets[host.model].w,60)
  P:PostLoadData();assert(P.devices[id]) -- repeated completion cannot erase an already-bound screen
  host:Remove();eq(P.devices[id],nil);eq(P.devices[mon.id].terminal,0);eq(#stored.foundation_cctv_v1.devices,1)
  p.trace.Entity=entity(901,'models/test.mdl',Vector(50,0,64));ok,_,id=P:Action(p,'placeSurface',{preset=true});assert(ok);eq(P.devices[id].config.w,60)
  P:PreCleanupMap();p.trace.Entity:Remove();P:LoadData();P:PostLoadData();assert(P.devices[id])
  clock=clock+90;P:Think();P:SaveData();eq(#stored.foundation_cctv_v1.devices,2)
  local late=entity(902,'models/test.mdl',Vector(50,0,64));late.mapid=-1
  clock=clock+3;P:Think();eq(P.devices[id].entity,late)
 `);
 suite('CCTV admins can explicitly delete a saved screen whose prop has not returned',server,`
  local P=PLUGIN;P:LoadData();local p=admin();local host=entity(700,'models/test.mdl',Vector(50,0,64));host.mapid=-1
  p.trace={Hit=true,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0),Entity=host}
  local ok,_,id=P:Action(p,'placeSurface',{});assert(ok);P:SaveData();host.valid=false
  P:LoadData();P:PostLoadData();assert(P.devices[id]);eq(IsValid(P.devices[id].entity),false)
  p.admin=false;eq(P:Action(p,'remove',{id=id}),false);assert(P.devices[id])
  p.admin=true;assert(P:Action(p,'remove',{id=id}));eq(P.devices[id],nil)
  P:LoadData();P:PostLoadData();eq(P.devices[id],nil)
 `);
 suite('CCTV unresolved monitor and terminal links survive repeated saves before their shared host returns',server,`
  local P=PLUGIN;P:LoadData();P:PostLoadData();local p=admin()
  local host=entity(710,'models/test.mdl',Vector(50,0,64));host.mapid=-1
  p.trace={Hit=true,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0),Entity=host}
  local _,_,terminal=P:Action(p,'placeSurface',{})
  local _,_,monitor=P:Action(p,'placeSurface',{kind='monitor'})
  local camera=makeDevice('camera');P.devices[monitor].terminal=terminal;P.devices[monitor].camera=camera.id
  P:SaveData();local identity=host.ixPropScreenHostID
  P:PreCleanupMap();host:Remove();P:LoadData();P:PostLoadData()
  for i=1,3 do clock=clock+40;P:Think();P:SaveData() end
  eq(#stored.foundation_cctv_v1.devices,3);eq(P.devices[monitor].terminal,terminal);eq(P.devices[monitor].camera,camera.id)
  P:LoadData();P:PostLoadData();eq(P.devices[monitor].terminal,terminal)
  local restored=entity(711,'models/test.mdl',Vector(65,0,64));restored.mapid=-1;restored.ixPropScreenHostID=identity
  clock=clock+3;P:Think();eq(P.devices[monitor].entity,restored);eq(P.devices[terminal].entity,restored)
  eq(P.devices[monitor].camera,camera.id)
  restored:Remove();eq(P.devices[monitor],nil);eq(P.devices[terminal],nil)
 `);
 suite('CCTV multiple screens share a prop, keep independent links, follow movement and survive reload and individual removal',server,`
  local P,C,S=PLUGIN,ix.CCTV,ix.PropScreens;P:LoadData();P:PostLoadData();local p=admin()
  local host=entity(700,'models/test.mdl',Vector(50,0,64));local ids={}
  for i=1,3 do
   p.trace={Hit=true,HitPos=Vector(45,(i-1)*40,64),HitNormal=Vector(-1,0,0),Entity=host}
   local ok,_,id=P:Action(p,'placeSurface',{preset=true});assert(ok);ids[i]=id
   if i==1 then assert(P:Action(p,'surfacePreset',{id=id,config=P.devices[id].config})) end
   assert(S.Has(host,'ixCCTVSurfaceID',id));near(C.Screen(P.devices[id]).y,(i-1)*40)
  end
  local monitors={};for i,id in ipairs(ids) do monitors[i]=makeDevice('monitor');monitors[i].terminal=id end
  p.pos=Vector(0,40,64);eq(C.AimTerminal(p,P.devices).id,ids[2])
  host:SetPos(Vector(60,0,64));P:Sync(p);local packets=#net.packets;P:PhysgunDrop(p,host);eq(#net.packets,packets+3)
  P:SaveData();P:LoadData();P:PostLoadData()
  for i,id in ipairs(ids) do assert(S.Has(host,'ixCCTVSurfaceID',id));eq(P.devices[id].entity,host);eq(P.devices[monitors[i].id].terminal,id) end
  assert(P:Action(p,'remove',{id=ids[2]}));eq(S.Has(host,'ixCCTVSurfaceID',ids[2]),false)
  for _,i in ipairs({1,3}) do assert(C.SurfaceTransform(P.devices[ids[i]]));eq(P.devices[monitors[i].id].terminal,ids[i]) end
  eq(P.devices[monitors[2].id].terminal,0);eq(IsValid(host),true)
  P:EntityRemoved(host);eq(P.devices[ids[1]],nil);eq(P.devices[ids[3]],nil)
 `);
 suite('CCTV moving one screen preserves neighbors on both source and destination props',server,`
  local P,S=PLUGIN,ix.PropScreens;P:LoadData();P:PostLoadData();local p=admin()
  local a=entity(700,'models/test.mdl',Vector(50,0,64));local b=entity(701,'models/test.mdl',Vector(80,0,64));local ids={}
  for i,host in ipairs({a,a,b}) do p.trace={Hit=true,Entity=host,HitPos=host:GetPos(),HitNormal=Vector(-1,0,0)};local ok,_,id=P:Action(p,'placeSurface',{});assert(ok);ids[i]=id end
  assert(P:Action(p,'placeSurface',{id=ids[1]}))
  eq(S.Has(a,'ixCCTVSurfaceID',ids[1]),false);assert(S.Has(a,'ixCCTVSurfaceID',ids[2]))
  assert(S.Has(b,'ixCCTVSurfaceID',ids[1]));assert(S.Has(b,'ixCCTVSurfaceID',ids[3]))
  P:DeleteRecord(ids[1]);eq(b:GetNW2Int('ixCCTVSurfaceID'),ids[3]);assert(S.Has(b,'ixCCTVSurfaceID',ids[3]))
 `);
 suite('Mixed CCTV and TV screens on one prop dispatch each E press only to the nearest aimed screen',server,`
  local CCTV=PLUGIN;CCTV:LoadData();CCTV:PostLoadData()
  PLUGIN={};ix.plugin.list.tv_screen=PLUGIN
  do local function loadMedia()
   ${normalize(fs.readFileSync('helix/gamemode/core/libs/sh_broadcastmedia.lua','utf8'))}
  end;loadMedia() end
  do local function loadTV()
   ${normalize(fs.readFileSync('ixhl2rp/plugins/tv_screen/sh_state.lua','utf8'))}
  end;loadTV() end
  do local function loadTV()
   ${normalize(fs.readFileSync('ixhl2rp/plugins/tv_screen/sv_plugin.lua','utf8'))}
  end;loadTV() end
  local TV=PLUGIN;TV:Initialize();local p=admin();local host=entity(700,'models/test.mdl',Vector(50,0,64))
  p.trace={Hit=true,Entity=host,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0)}
  local ok,_,c=CCTV:Action(p,'placeSurface',{});assert(ok)
  p.trace.HitPos=Vector(50,0,64);local ok,_,back=TV:Action(p,'place',{channel=1});assert(ok)
  p.trace.HitPos=Vector(45,60,64);local ok,_,side=TV:Action(p,'place',{channel=2});assert(ok)
  local opened=0;CCTV.SendOpen=function(_,_,_,id) eq(id,c);opened=opened+1 end;p.admin=false
  for _,reverse in ipairs({false,true}) do
   clock=clock+1;p.pos=Vector(0,0,64)
   if reverse then TV:KeyPress(p,IN_USE);CCTV:KeyPress(p,IN_USE) else CCTV:KeyPress(p,IN_USE);TV:KeyPress(p,IN_USE) end
   eq(TV.screens[back].on,true);eq(TV.screens[side].on,true)
  end
  eq(opened,2);clock=clock+1;p.pos=Vector(0,60,64);CCTV:KeyPress(p,IN_USE);TV:KeyPress(p,IN_USE)
  eq(opened,2);eq(TV.screens[side].on,false);eq(TV.screens[back].on,true)
  eq(CCTV:PlayerUse(p,host),nil);eq(TV:PlayerUse(p,host),false)
 `);
 suite('Shared prop screen memberships preserve legacy bindings and reject partial or recycled IDs',client,`
  local S,C=ix.PropScreens,ix.CCTV;local host=entity(700,'models/test.mdl',Vector(50,0,64))
  local first=clientSurface(1,host,{x=0,y=0,z=0,p=0,yaw=90,r=90,w=32,h=23.2})
  assert(S.Has(host,'ixCCTVSurfaceID',1));S.Bind(host,'ixCCTVSurfaceID',11)
  local second=table.Copy(first);second.id=11;second.config.y=40
  assert(C.SurfaceTransform(first));assert(C.SurfaceTransform(second));eq(S.Has(host,'ixCCTVSurfaceID',111),false)
  S.Unbind(host,'ixCCTVSurfaceID',1);eq(C.SurfaceTransform(first),nil);assert(C.SurfaceTransform(second))
  eq(host:GetNW2Int('ixCCTVSurfaceID'),11);S.Unbind(host,'ixCCTVSurfaceID',11);eq(S.Occupied(host),false)
  S.Bind(host,'ixCCTVSurfaceID',1);host.valid=false;entity(700,'models/test.mdl',Vector(50,0,64))
  eq(C.SurfaceTransform(first),nil)
 `);
 suite('Prop screen membership stays within network string limits at the full TV quota and clears stale chunks',server,`
  local S=ix.PropScreens;local host=entity(700,'models/test.mdl')
  local rawSet=host.SetNW2String
  function host:SetNW2String(key,value) assert(#value<=511);rawSet(self,key,value) end
  for id=999800,999927 do S.Bind(host,'ixTVScreenID',id) end
  eq(table.Count(S.IDs(host,'ixTVScreenID')),128)
  for id=999800,999927 do assert(S.Has(host,'ixTVScreenID',id)) end
  eq(S.Has(host,'ixTVScreenID',999928),false);assert(host:GetNW2Int('ixTVScreenIDChunks')>1)
  for id=999800,999926 do S.Unbind(host,'ixTVScreenID',id) end
  eq(host:GetNW2Int('ixTVScreenID'),999927);eq(host:GetNW2Int('ixTVScreenIDChunks'),1);eq(host:GetNW2String('ixTVScreenIDs2'),'')
  S.Unbind(host,'ixTVScreenID',999927);eq(S.Occupied(host),false);eq(S.Has(host,'ixTVScreenID',999927),false)
 `);
 suite('CCTV surface placement and use enforce authoritative traces, bounds, server access and screen-facing interaction',server,`
  local P,C=PLUGIN,ix.CCTV;P:LoadData();P:PostLoadData();local p=admin()
  local host=entity(700,'models/test.mdl',Vector(2000,0,64))
  p.trace={Hit=true,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0),Entity=host}
  p.admin=false;eq(P:Action(p,'placeSurface',{}),false);p.admin=true
  host:SetNW2Int('ixTVScreenID',1) -- a TV may coexist on another face
  p.trace.HitWorld=true;eq(P:Action(p,'placeSurface',{}),false);p.trace.HitWorld=false
  p.trace.HitPos=Vector(500,0,64);eq(P:Action(p,'placeSurface',{}),false);p.trace.HitPos=Vector(45,0,64)
  local ok,_,id=P:Action(p,'placeSurface',{});assert(ok);local d=P.devices[id]
  p.admin=false;assert(P:CanOperate(p,id)) -- nearby screen on a prop whose origin is far away
  P:KeyPress(p,IN_USE);eq(net.packets[#net.packets].name,'ixCCTVOpen');eq(P:PlayerUse(p,host),false)
  p.pos=Vector(60,0,64);eq(P:CanOperate(p,id),false) -- backside
  p.pos=Vector(0,0,64);util.TraceLine=function() return {Hit=true} end;eq(P:CanOperate(p,id),false)
  util.TraceLine=function() return {Hit=false} end;d.on=false;eq(P:CanOperate(p,id),false);d.on=true
  p.admin=true;local cfg=table.Copy(d.config);cfg.w=0/0
  eq(P:Action(p,'configure',{id=id,name='Changed',on=true,config=cfg}),false);eq(d.name,'Экран CCTV '..id)
 `);
 suite('CCTV custom-size screens keep all controls and cursor mapping inside wide, tall and rotated surfaces',client,`
  local P,C=PLUGIN,ix.CCTV
  for _,size in ipairs({{70,25},{20,60},{32,23.2}}) do
   local ent=entity(700,'models/test.mdl',Vector(50,0,64),Angle(15,130,10))
   local d=clientSurface(100,ent,{x=8,y=0,z=0,p=0,yaw=90,r=90,w=size[1],h=size[2]})
   local center,a=C.Screen(d);client.pos=center+a:Up()*60
   aimAtTerminal(d,770,465);local x,y=P:TerminalCursor(100);near(x,770);near(y,465)
   local o,_,scale=C.TerminalGeometry(d)
   assert(C.terminalWidth*scale<=size[1]+.0001 and C.terminalHeight*scale<=size[2]+.0001)
   P:DrawScreen(d);eq(cameraDepth,0);eq(#errors,0)
   ent:SetNW2Int('ixCCTVSurfaceID',999);eq(P:TerminalCursor(100),nil)
  end
  eq(renderCalls,0);eq(allocations,0)
 `);
 suite('CCTV prop editor previews precise adjustments, saves configuration and reuses model placement presets',client,`
  local P,C=PLUGIN,ix.CCTV
  local ent=entity(700,'models/test.mdl',Vector(50,0,64));local d=clientSurface(100,ent,{x=8,y=0,z=0,p=0,yaw=90,r=90,w=32,h=23.2})
  P.Request=function(_,action,v) lastAction=action;lastData=table.Copy(v) end
  P:OpenAdminUI(100);assert(P.editSurface);eq(P.window.w,480)
  uiFind('DButton','Ширина +'):DoClick();near(P.editSurface.config.w,32.1);near(d.config.w,32)
  keys[KEY_LSHIFT]=true;uiFind('DButton','Ширина +'):DoClick();keys[KEY_LSHIFT]=false;near(P.editSurface.config.w,32.11)
  uiFind('DButton','Сохранить экран'):DoClick();eq(lastAction,'configure');near(lastData.config.w,32.11)
  uiFind('DButton','Сохранить размещение для модели'):DoClick();eq(lastAction,'surfacePreset')
  P.surfacePresets[d.model]={x=120,y=10,z=20,p=0,yaw=45,r=90,w=80,h=60}
  uiFind('DButton','Загрузить пресет модели'):DoClick();near(P.editSurface.config.x,120);near(P.editSurface.config.w,80)
  uiFind('DButton','Перенести экран на другой prop'):DoClick();eq(P.placing,'terminal');eq(P.replaceTerminal,100);eq(P.editSurface,nil)
  P:OpenSurfaceEditor(100);uiFind('DButton','Добавить ещё один экран'):DoClick();eq(P.placing,'terminal');eq(P.replaceTerminal,nil)
 `);
 suite('CCTV surface placement previews on arbitrary props, reuses the TV guide and sends no client coordinates',client,`
  local P,C=PLUGIN,ix.CCTV;local ent=entity(700,'models/test.mdl',Vector(50,0,64))
  client.trace={Hit=true,HitPos=Vector(45,0,64),HitNormal=Vector(-1,0,0),Entity=ent}
  P.Request=function(_,action,v) lastAction=action;lastData=v end
  P:BeginPlacement('terminal',123);eq(P.ghost,nil)
  hooks.CreateMove.ixCCTVPlacement(inputCommand(false,false));assert(P.surfacePlacement);eq(P.surfacePlacement.entity,ent)
  local tv={PaintScreenPreview=function(self) guide=self;return true end};ix.plugin.list.tv_screen=tv
  hooks.HUDPaint.ixCCTVSurfaceGuide();eq(guide.placement,true);eq(guide.placementPreview.entity,ent);eq(tv.placement,nil)
  keys[KEY_R]=true;hooks.CreateMove.ixCCTVPlacement(inputCommand(false,false));keys[KEY_R]=false;eq(P.useSurfacePreset,false)
  hooks.CreateMove.ixCCTVPlacement(inputCommand(true,false));eq(lastAction,'placeSurface');eq(lastData.id,123);eq(lastData.preset,false);eq(lastData.config,nil);eq(P.surfacePlacement,nil)
 `);
 suite('CCTV placement waits for released clicks, shows a ghost, sends a bounded placement request and cancels',client,`
  local P,C=PLUGIN,ix.CCTV;client.trace={Hit=true,HitWorld=true,HitPos=Vector(80,0,64),HitNormal=Vector(-1,0,0)}
  P.Request=function(_,action,data) lastAction=action;lastData=data end
  P:BeginPlacement('camera');assert(IsValid(P.ghost));hooks.CreateMove.ixCCTVPlacement(inputCommand(true,false));eq(lastAction,nil)
  hooks.CreateMove.ixCCTVPlacement(inputCommand(false,false));assert(P.placementPos)
  hooks.CreateMove.ixCCTVPlacement(inputCommand(true,false));eq(lastAction,'place');eq(lastData.kind,'camera');eq(P.placing,nil);eq(P.ghost,nil)
  P:BeginPlacement('monitor');hooks.CreateMove.ixCCTVPlacement(inputCommand(false,false));hooks.CreateMove.ixCCTVPlacement(inputCommand(false,true));eq(P.placing,nil)
 `);
};
if(require.main===module){
 const f=require('fengari');let passed=0;
 module.exports((name,files,assertions)=>{
  const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
  const source=fs.readFileSync('tools/fixture.lua','utf8')+'\n'+assertions;
  const status=f.lauxlib.luaL_dostring(L,f.to_luastring(source));
  if(status!==f.lua.LUA_OK){fs.writeFileSync('docs/cctv-test-expanded.lua',source);throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));}
  console.log('PASS '+name);passed++;
 });
 console.log(passed+' CCTV regression suites passed. Mocked engine APIs; live rendering requires an in-game check.');
}
