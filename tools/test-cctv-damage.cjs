const path=require('path');process.chdir(path.resolve(__dirname,'..'));
const {run,source,finish}=require('./restored-test-runner.cjs');
const base=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua']);
const camera=source(['ixhl2rp/plugins/cctv/entities/entities/ix_cctv_device.lua','ixhl2rp/plugins/cctv/sv_devices.lua','ixhl2rp/plugins/cctv/sv_surfaces.lua','ixhl2rp/plugins/cctv/sv_network.lua']);
const facility='ix.config.Add=function() end\n'+source(['tools/fixtures/facility.lua',...['sh_core','sh_repair','sh_engineering_games','sh_engineering','sv_store','sv_portables','sv_connections','sv_power','sv_doors','sv_comms','sv_jobs','sv_repair','sv_engineering','sv_devices','sv_network'].map(f=>'ixhl2rp/plugins/facility_utilities/'+f+'.lua')]);
const server=base+'\n'+camera+'\nlocal CCTV=PLUGIN;PLUGIN={}\n'+facility+`
 local F=PLUGIN;F.loaded=true;PLUGIN=CCTV;CCTV:LoadData();PLUGIN=F
 local oldAdmin=admin
 function admin(...) local p=oldAdmin(...);function p.character:GetSkillModified() return 5 end;return p end
 DMG_BUCKSHOT=536870912
 local effects={}
 function EffectData()
  local e={}
  for _,k in ipairs({'Origin','Normal','Magnitude','Scale','Radius'}) do e['Set'..k]=function(self,v) self[k]=v end end
  return e
 end
 function util.Effect(name,data,allow,ignore) effects[#effects+1]={name=name,data=data,allow=allow,ignore=ignore} end
 function damage(kind,amount)
  return {GetDamage=function() return amount or 10 end,IsBulletDamage=function() return kind=='bullet' end,
   IsDamageType=function(_,t) return kind=='shotgun' and t==DMG_BUCKSHOT end}
 end
 function cameraDevice(kind,pos)
  PLUGIN=CCTV;local d,e=makeDevice(kind or 'camera',pos);PLUGIN=F
  function e:NearestPoint() return self.pos end
  function e:WorldToLocalAngles(a) local _,v=WorldToLocal(Vector(),a,Vector(),self.ang);return v end
  function e:LocalToWorldAngles(a) local _,v=LocalToWorld(Vector(),a,Vector(),self.ang);return v end
  return d,e
 end
 function reloadCameras() PLUGIN=CCTV;CCTV:LoadData();PLUGIN=F end
 function jobFor(d) for _,j in pairs(F.store.jobs) do if j.targetKind=='cctv' and j.target==d.id and j.status~='closed' then return j end end end
 function solveRepair(p)
  for i=F.work[p].repair.stage,ix.Facility.repair.contacts do
   local w=F.work[p];local r=w.repair;eq(r.kind,'bolts');local count=r.game.count
   for pair=1,count/2 do for _,index in ipairs({pair,pair+count/2}) do
    local points=ix.Facility.EngineeringBolts(w.entity,{count=count,anchor=r.anchor})
    p.dir=(points[index]-p:GetShootPos()):GetNormalized();clock=clock+.2
    F:EngineeringInput(p,r.token,r.round,'hold',index,0);assert(r.hold)
    clock=r.hold+r.torqueTime*(r.game.lo[index]+r.game.hi[index])/2
    F:EngineeringInput(p,r.token,r.round,'release',index,0)
   end end
  end
 end
 function beginRepair(p,d)
  p.trace={Entity=d.entity,HitPos=d.entity.pos-Vector(2,0,0),HitNormal=Vector(-1,0,0)}
  return F:BeginCameraWork(p,d)
 end
`;
run('A bullet or buckshot breaks only the struck camera once, emits one electrical burst and opens one repair job',server+`
 local d,e=cameraDevice();local shotgun,se=cameraDevice();local mon,me=cameraDevice('monitor');local term,te=cameraDevice('terminal')
 eq(e:OnTakeDamage(damage('bullet',0)),0);eq(e:OnTakeDamage(damage('melee')),0);eq(e:OnTakeDamage(damage('physics')),0)
 eq(me:OnTakeDamage(damage('bullet')),0);eq(te:OnTakeDamage(damage('bullet')),0);eq(#effects,0);eq(d.broken,nil)
 eq(e:OnTakeDamage(damage('bullet',17)),17);eq(d.broken,true);eq(d.on,true);eq(ix.CCTV.Powered(d),false);assert(IsValid(e))
 eq(e.lastSound,'ambient/energy/zap1.wav');eq(e.soundCount,1);eq(#effects,1)
 eq(effects[1].name,'Sparks');vectorNear(effects[1].data.Origin,ix.CCTV.Lens(d));eq(effects[1].ignore,true)
 local j=jobFor(d);assert(j);eq(j.previousOn,nil)
 for i=1,12 do eq(e:OnTakeDamage(damage('bullet')),0) end
 eq(#effects,1);eq(e.soundCount,1);eq(table.Count(F.store.jobs),1)
 eq(se:OnTakeDamage(damage('shotgun')),10);eq(shotgun.broken,true);eq(#effects,2)
 eq(mon.broken,nil);eq(term.broken,nil)
 local wearable=cameraDevice();wearable.bodycam=true;eq(CCTV:BreakCamera(wearable,true),false)
 local wrong=entity(9000,'prop');wrong.CCTVKind='camera';wrong:SetNW2Int('ixCCTVID',d.id)
 eq(ENT.OnTakeDamage(wrong,damage('bullet')),0);eq(#effects,2)
`);
run('A broken camera loses watch and PVS grants while retaining monitor links and cannot be fixed by switches or backup power',server+`
 local p=admin();p.admin=false;local d,e=cameraDevice('camera',Vector(1000,0,64));local mon=cameraDevice('monitor',Vector(20,0,0));mon.camera=d.id
 local feeds,grants=CCTV:ResolveWatch(p,{monitors={mon.id}});eq(#feeds,1)
 CCTV.watchers[p]={grants=grants,expires=clock+1};CCTV:SetupPlayerVisibility(p);eq(#origins,1)
 e:OnTakeDamage(damage('bullet'));origins={};CCTV:SetupPlayerVisibility(p);eq(#origins,0)
 feeds=CCTV:ResolveWatch(p,{monitors={mon.id}});eq(#feeds,0);eq(mon.camera,d.id)
 p.admin=true;feeds=CCTV:ResolveWatch(p,{preview=d.id});eq(#feeds,0)
 for _,on in ipairs({false,true}) do
  assert(CCTV:Action(p,'configure',{id=d.id,name=d.name,on=on,ang=Angle(),fov=75,broken=false}))
  eq(d.broken,true);eq(ix.CCTV.Powered(d),false)
 end
 ix.plugin.list.blackout={IsPosBlackedOut=function() return true end}
 e:SetNW2Bool('ixGeneratorPower',true);eq(ix.CCTV.Powered(d),false)
 eq(CCTV:Snapshot(d).broken,true)
`);
run('Fresh shots on an already damaged camera still zap and spark, with per-camera pellet throttling',server+`
 local d,e=cameraDevice();e:OnTakeDamage(damage('bullet'));local j=jobFor(d)
 for i=1,15 do e:OnTakeDamage(damage('shotgun')) end
 eq(e.soundCount,1);eq(#effects,1)
 clock=clock+.21;e:OnTakeDamage(damage('bullet'));eq(e.soundCount,2);eq(#effects,2)
 eq(e.lastSound,'ambient/energy/zap1.wav');eq(d.broken,true);eq(jobFor(d),j);eq(table.Count(F.store.jobs),1)
 clock=clock+.21;e:OnTakeDamage(damage('melee'));eq(e.soundCount,2)
 local another,ae=cameraDevice();ae:OnTakeDamage(damage('bullet'));eq(ae.soundCount,1);eq(#effects,3)
`);
run('Native E opens the camera bolt game without a job command, and commands cannot start it',server+`
 ix.config.Get=function(k,d) if k=='facilityRepairGame' then return 'contacts' end;return d end
 local p=admin(1);p.admin=false
 local d,e=cameraDevice('camera',Vector(60,0,0));e:OnTakeDamage(damage('bullet'));local j=jobFor(d)
 giveItem(p,'tool_screw');giveItem(p,'facility_spares')
 p.trace={Entity=e,HitPos=e.pos-Vector(2,0,0),HitNormal=Vector(-1,0,0)}
 e:Use(p);local w=F.work[p];assert(w);eq(j.status,'assigned');eq(w.repair.kind,'bolts')
 F:CancelWork(p,nil,true);eq(j.status,'open')
 assert(F:JobAction(p,{id=j.id,command='claim'}));eq(F:JobAction(p,{id=j.id,command='work'}),false)
 eq(F:BeginWork(p,j),false);eq(F.work[p],nil);eq(d.broken,true)
 for _,mode in ipairs({'auto','probe','pressure','bolts','contacts'}) do
  ix.config.Get=function() return mode end;eq(F:EngineeringKind({job=j.id}),'bolts')
 end
`);
run('Physical camera repairs enforce tools, access, exact target, walls, range and exclusive ownership without leaking claims',server+`
 local d,e=cameraDevice('camera',Vector(60,0,0));e:OnTakeDamage(damage('bullet'));local j=jobFor(d)
 local p=admin(0);p.admin=false;giveItem(p,'tool_screw');giveItem(p,'facility_spares')
 eq(beginRepair(p,d),false);eq(j.status,'open');p.card.clearanceLevel=1
 p.trace={Entity=entity(890,'prop')};eq(F:BeginCameraWork(p,d),false);eq(j.status,'open')
 local originalTrace=util.TraceLine;util.TraceLine=function() return {Hit=true} end
 eq(beginRepair(p,d),false);eq(j.status,'open');util.TraceLine=originalTrace
 p.pos=Vector(1000,0,0);eq(beginRepair(p,d),false);p.pos=Vector()
 local other=admin(1);giveItem(other,'tool_screw');giveItem(other,'facility_spares')
 F.work[other]={entity=e};eq(beginRepair(p,d),false);eq(j.status,'open');eq(j.owner,nil);F.work[other]=nil
 assert(beginRepair(other,d));eq(beginRepair(p,d),false);eq(j.owner,other:GetCharacter():GetID())
 F:CancelWork(other,nil,true);assert(beginRepair(p,d))
 local parts=p.items.facility_spares;p.items.tool_screw=nil;F:TickJobs()
 eq(F.work[p],nil);eq(parts.removed,0);eq(d.broken,true);eq(j.status,'open')
`);
run('Camera damage persists across restart and cleanup; missing or full-queue maintenance jobs are recovered without duplicates',server+`
 local d,e=cameraDevice();e:OnTakeDamage(damage('bullet'));local id=d.id
 F:SaveData();reloadCameras();d=CCTV.devices[id];eq(d.broken,true);eq(d.on,true);eq(ix.CCTV.Powered(d),false)
 F.store.jobs={};F:DiscoverJobs();F:DiscoverJobs();eq(table.Count(F.store.jobs),1);assert(jobFor(d));eq(#effects,1)
 CCTV:PreCleanupMap();for _,row in pairs(CCTV.devices) do row.entity:Remove() end
 CCTV:PostCleanupMap();d=CCTV.devices[id];eq(d.broken,true);assert(IsValid(d.entity));eq(#effects,1)
 F.store.jobs={};for i=1,100 do F:NewJob('device',1000+i,'Pending '..i,1) end
 local another,ae=cameraDevice();ae:OnTakeDamage(damage('bullet'));eq(another.broken,true);eq(jobFor(another),nil)
 for _,j in pairs(F.store.jobs) do j.status='closed' end
 F:DiscoverJobs();assert(jobFor(another));assert(jobFor(d));F:DiscoverJobs();eq(table.Count(F.store.jobs),100)
 -- Loading old saves without a broken field must leave healthy cameras usable.
 for _,row in ipairs(stored.foundation_cctv_v1.devices) do row.broken=nil end
 reloadCameras();eq(CCTV.devices[id].broken,false);eq(ix.CCTV.Powered(CCTV.devices[id]),true)
`);
run('Repair consumes one spare kit, preserves the camera switch and needs working power before the feed returns',server+`
 local p=admin(1);p.admin=false;giveItem(p,'tool_screw')
 for _,on in ipairs({true,false}) do
  local d,e=cameraDevice('camera',Vector(60,0,0));d.on=on;e:OnTakeDamage(damage('bullet'));local j=jobFor(d)
  eq(beginRepair(p,d),false);eq(j.status,'open')
  local parts=giveItem(p,'facility_spares');assert(beginRepair(p,d));local w=F.work[p]
  eq(F:CompleteWork(p,w),false);eq(d.broken,true);eq(parts.removed,0)
  ix.plugin.list.blackout={IsPosBlackedOut=function() return true end}
  solveRepair(p);eq(d.broken,false);eq(d.on,on);eq(parts.removed,1);eq(j.status,'closed');eq(ix.CCTV.Powered(d),false)
  F:RepairInput(p,w.repair.token,w.repair.round,true);eq(parts.removed,1)
  e:SetNW2Bool('ixGeneratorPower',true);eq(ix.CCTV.Powered(d),on)
  eq(CCTV:Snapshot(d).broken,false);reloadCameras();d=CCTV.devices[d.id];eq(d.broken,false);eq(d.on,on)
 end
`);
run('Interrupted and unauthorized repairs keep camera damage and parts; a repaired camera can be shot again',server+`
 local d,e=cameraDevice('camera',Vector(60,0,0));e:OnTakeDamage(damage('bullet'));local j=jobFor(d)
 local denied=admin(0);denied.admin=false;eq(F:JobAction(denied,{id=j.id,command='claim'}),false)
 local p=admin(1);p.admin=false;giveItem(p,'tool_screw');local parts=giveItem(p,'facility_spares')
 assert(beginRepair(p,d));p.pos=Vector(1000,0,0);F:TickJobs()
 eq(F.work[p],nil);eq(d.broken,true);eq(parts.removed,0);eq(j.status,'open')
 p.pos=Vector();assert(beginRepair(p,d));solveRepair(p)
 eq(d.broken,false);eq(ix.CCTV.Powered(d),true)
 e:OnTakeDamage(damage('bullet'));eq(d.broken,true);eq(e.soundCount,2);assert(jobFor(d));assert(jobFor(d)~=j)
`);
run('Admin camera faults use durable damage too, preserve an off switch and exclude helmet cameras',server+`
 local p=admin();local d=cameraDevice('camera',Vector(60,0,0));d.on=false
 assert(F:AdminAction(p,{command='cctvFault',id=d.id}));eq(d.broken,true);eq(d.on,false);eq(#effects,0)
 assert(F:AdminAction(p,{command='cctvFault',id=d.id}));eq(table.Count(F.store.jobs),1)
 local j=jobFor(d);eq(j.previousOn,nil);assert(F:JobAction(p,{id=j.id,command='claim'}))
 giveItem(p,'tool_screw');giveItem(p,'facility_spares');assert(beginRepair(p,d));solveRepair(p);eq(d.broken,false);eq(d.on,false)
 local helmet=cameraDevice();helmet.bodycam=true;eq(F:AdminAction(p,{command='cctvFault',id=helmet.id}),false)
`);
const engineering=server;
run('The default camera bolt repair clears gunshot damage only after all five stages and spends one kit',engineering+`
 ix.config.Get=function(k,d) if k=='facilityRepairGame' then return 'auto' end;return d end
 local p=admin(1);p.admin=false;function p.character:GetSkillModified() return 5 end
 local d,e=cameraDevice('camera',Vector(60,0,0));e:OnTakeDamage(damage('bullet'))
 function e:NearestPoint() return self.pos end
 function e:WorldToLocalAngles(a) local _,v=WorldToLocal(Vector(),a,Vector(),self.ang);return v end
 function e:LocalToWorldAngles(a) local _,v=LocalToWorld(Vector(),a,Vector(),self.ang);return v end
 p.trace={Entity=e,HitPos=e.pos-Vector(2,0,0),HitNormal=Vector(-1,0,0)}
 giveItem(p,'tool_screw');local part=giveItem(p,'facility_spares');local j=jobFor(d)
 assert(beginRepair(p,d))
 local w=F.work[p];eq(w.repair.kind,'bolts');eq(F:CompleteWork(p,w),false)
 for stage=1,5 do
  local r=w.repair;eq(r.stage,stage);eq(d.broken,true);eq(part.removed,0)
  local count=r.game.count
  for pair=1,count/2 do for _,index in ipairs({pair,pair+count/2}) do
   local points=ix.Facility.EngineeringBolts(e,{count=count,anchor=r.anchor})
   p.dir=(points[index]-p:GetShootPos()):GetNormalized();clock=clock+.2
   F:EngineeringInput(p,r.token,r.round,'hold',index,0);assert(r.hold)
   clock=r.hold+r.torqueTime*(r.game.lo[index]+r.game.hi[index])/2
   F:EngineeringInput(p,r.token,r.round,'release',index,0)
  end end
 end
 eq(F.work[p],nil);eq(j.status,'closed');eq(d.broken,false);eq(part.removed,1);eq(ix.CCTV.Powered(d),true)
`);
const client=base+'\n'+source(['tools/fixtures/tv-client.lua','tools/fixtures/tv-controls.lua','tools/fixtures/cctv-render.lua','ixhl2rp/plugins/cctv/cl_network.lua','ixhl2rp/plugins/cctv/cl_render.lua']);
run('Client damage updates immediately blank cached footage and reject stale grants until repaired',client+`
 local P=PLUGIN;local d={id=1,kind='camera',name='Cam',on=true,pos=Vector(100,0,0),ang=Angle()};P.devices[1]=d
 local feed={id=1,pos=d.pos,ang=d.ang,received=clock,first=clock-1};P.feeds[1]=feed;P.demand[1]=true
 hooks.PostRender.ixCCTVFeeds();eq(renderCalls,1);assert(P:FeedSlot(1).updated)
 d.broken=true;net.ReadString=function() return util.TableToJSON(d) end;net.handlers.ixCCTVDevice();eq(P.feeds[1],nil)
 local texts={};draw.SimpleText=function(t) texts[t]=true end;P:PaintFeed(1,320,180);assert(texts['КАМЕРА ПОВРЕЖДЕНА']);eq(texts['LIVE  /  320 × 180'],nil)
 -- An old in-flight grant must not resume capture or recognition after the update.
 net.ReadString=function() return util.TableToJSON({feed}) end;net.handlers.ixCCTVFeeds();clock=clock+1
 hooks.PostRender.ixCCTVFeeds();eq(renderCalls,1);eq(P:FeedSlot(1),nil)
 local slot={target={}};P:CaptureFeed(feed,slot);eq(renderCalls,1);eq(slot.updated,nil)
 d.broken=false;net.ReadString=function() return util.TableToJSON(d) end;net.handlers.ixCCTVDevice()
 net.ReadString=function() return util.TableToJSON({feed}) end;net.handlers.ixCCTVFeeds();clock=clock+.3
 hooks.PostRender.ixCCTVFeeds();eq(renderCalls,2);assert(P:FeedSlot(1).updated)
`);
run('Camera LED follows its lens, lights only when actually powered, and exposes native repair instructions',client+'\n'+source(['ixhl2rp/plugins/cctv/cl_camera.lua','ixhl2rp/plugins/cctv/entities/entities/ix_cctv_device.lua'])+`
 local e=entity(800,ix.CCTV.cameraRig.model,Vector(20,30,40),Angle(0,90,0));e.class='ix_cctv_camera';e.CCTVKind='camera'
 function e:GetClass() return self.class end
 function e:GetNW2Bool(k,d) if self[k]~=nil then return self[k] end;return d end
 function e:SetNW2Bool(k,v) self[k]=v end
 e:SetNW2Int('ixCCTVID',8)
 local d={id=8,entityIndex=800,kind='camera',name='Cam',on=true,model=ix.CCTV.cameraRig.model,pos=e.pos,ang=e.ang}
 PLUGIN.devices[8]=d
 local draws=0;local last;local mat
 render.SetMaterial=function(v) mat=v end
 render.DrawSprite=function(pos) draws=draws+1;last=pos end
 ENT.DrawTranslucent(e);eq(draws,2);vectorNear(last,ix.CCTV.CameraIndicator(d));eq(mat.params['$ignorez'],'0')
 d.on=false;ENT.DrawTranslucent(e);eq(draws,2);d.on=true
 ix.plugin.list.blackout={IsElectronicsOffAt=function(_,_,ent) return not ent:GetNW2Bool('ixGeneratorPower',false) end}
 ENT.DrawTranslucent(e);eq(draws,2)
 e:SetNW2Bool('ixGeneratorPower',true);ENT.DrawTranslucent(e);eq(draws,4)
 d.broken=true;ENT.DrawTranslucent(e);eq(draws,4)
 local spec=hooks.GetEquipmentInteraction.ixCCTVCameraRepair(client,e)
 assert(spec.native);eq(spec.options[1].id,'repair')
 d.broken=false;e.pos=Vector(60,100,80);ENT.DrawTranslucent(e);eq(draws,6);vectorNear(last,ix.CCTV.CameraIndicator(d))
 eq(hooks.GetEquipmentInteraction.ixCCTVCameraRepair(client,e),nil)
 d.bodycam=true;ENT.DrawTranslucent(e);eq(draws,6);d.bodycam=false
 d.entityIndex=999;ENT.DrawTranslucent(e);eq(draws,6)
`);
finish();
