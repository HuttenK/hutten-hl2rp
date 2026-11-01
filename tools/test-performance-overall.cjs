const {native,source}=require('./restored-test-runner.cjs');
module.exports=suite=>{
 const shot=native('tools/fixtures/arc9-upstream/sh_shoot.lua','function SWEP:DoProjectileAttack(','local runHook = {}');
 suite('Installed ARC9 firing path uses full-distance hitscan, retains hit callbacks and pellets, and preserves explicit special projectiles',[],`
 local physics=false;local hit=true;local fired,simulated,rockets,callbacks=0,0,0,0
 local bulletPhysics={GetBool=function() return physics end};local bulletPhysicsshotguns={GetBool=function() return false end}
 local fireBullets={};local minphysrange=100;local black={};local sp=false
 local values={Num=1,Distance=20000,ImpactForce=1,DamageMax=35,Penetration=4}
 local swepGetProcessedValue=function(_,key) return values[key] end
 local CalcSpreadDir=function() return Vector(1,0,0) end
 local owner={valid=true,IsNPC=function() return false end,IsPlayer=function() return true end,
  LagCompensation=function(s,v) s.lag=v end,GetVehicle=function() return nil end,
  FireBullets=function(s,b)
   fired=fired+1;assert(s.lag);eq(b.Distance,physics and minphysrange or values.Distance)
   if hit then b.Callback(s,{Fraction=.5},{SetDamage=function(_,d) eq(d,35) end}) end
  end}
 engine={TickCount=function() return 1 end};Angle=function(a) return a end
 SWEP={GetOwner=function() return owner end,ShouldTracer=function() return true end,EntIndex=function() return 1 end,
  ShootPhysBulletBinding=function() simulated=simulated+1 end,ShootRocket=function() rockets=rockets+1 end,
  AfterShotFunction=function(_,tr,dmg,range,pen) callbacks=callbacks+1;eq(pen,4) end}
 ${shot}
 SWEP:DoProjectileAttack(Vector(),{},0);eq(fired,1);eq(callbacks,1);eq(simulated,0);eq(owner.lag,false)
 hit=false;SWEP:DoProjectileAttack(Vector(),{},0);eq(fired,2);eq(simulated,0)
 values.Num=8;hit=true;SWEP:DoProjectileAttack(Vector(),{},0);eq(fired,10);eq(callbacks,9);eq(simulated,0)
 values.Num=1;physics=true;SWEP:DoProjectileAttack(Vector(),{},0);eq(simulated,0)
 hit=false;SWEP:DoProjectileAttack(Vector(),{},0);eq(simulated,1)
 physics=false;values.ShootEnt='rocket';SWEP:DoProjectileAttack(Vector(),{},0);eq(rockets,1)
 values.ShootEnt=nil;values.AlwaysPhysBullet=true;SWEP:DoProjectileAttack(Vector(),{},0);eq(simulated,2)
 `,source(['tools/geometry-fixture.lua']));
 suite('Power ordering reuses unchanged work and invalidates equal-count replacement, priority, kind and removal',
 ['ixhl2rp/plugins/facility_utilities/sv_power.lua'],`
 PLUGIN.store={circuits={a={id=1,priority=2},b={id=2,priority=1}},devices={a={id=1,kind='battery'},b={id=2,kind='generator'}}}
 local c=PLUGIN:PowerOrder('circuits');eq(c[1].id,2);eq(PLUGIN:PowerOrder('circuits'),c)
 PLUGIN.store.circuits.a.priority=0;local c2=PLUGIN:PowerOrder('circuits');assert(c2~=c);eq(c2[1].id,1)
 local replacement={id=1,priority=0};PLUGIN.store.circuits.a=replacement;eq(PLUGIN:PowerOrder('circuits')[1],replacement)
 PLUGIN.store.circuits.b=nil;eq(#PLUGIN:PowerOrder('circuits'),1)
 local d=PLUGIN:PowerOrder('devices');eq(d[1].id,2);eq(PLUGIN:PowerOrder('devices'),d)
 PLUGIN.store.devices.b.kind='battery';eq(PLUGIN:PowerOrder('devices')[1].id,1)
 `);
 suite('World autosave skips identical snapshots but movement, deletion and shutdown still persist',
 ['ixhl2rp/plugins/world_persistence/sv_store.lua'],`
 PLUGIN.loaded=true;PLUGIN.nextID=2;PLUGIN.records={[1]={entity={valid=true},data={id=1}}}
 local revision=1;local writes=0
 function PLUGIN:Eligible() return true end
 function PLUGIN:Capture() return {id=1,pos=revision} end
 function PLUGIN:SetData(data) writes=writes+1;saved=data end
 util.TableToJSON=function(t) return tostring(t.nextID)..':'..tostring(t.entities[1] and t.entities[1].pos) end
 PLUGIN:SaveData(true);eq(writes,1);PLUGIN:SaveData(true);eq(writes,1)
 revision=2;PLUGIN:SaveData(true);eq(writes,2);eq(saved.entities[1].pos,2)
 PLUGIN:ShutDown();eq(writes,3)
 PLUGIN.records={};PLUGIN:SaveData(true);eq(writes,4);eq(#saved.entities,0)
 `);
 const geometry=source(['tools/geometry-fixture.lua'])+`
 local V=getmetatable(Vector())
 function V:WithinAABox(a,b) return self.x>=a.x and self.y>=a.y and self.z>=a.z and self.x<=b.x and self.y<=b.y and self.z<=b.z end
 function V:DistToSqr(b) return (self-b):LengthSqr() end
 `;
 suite('ARC9 policy disables normal and shotgun physical bullets at startup and after config changes, without touching special projectile definitions',
 ['ixhl2rp/plugins/arc9_compat.lua'],`
 eq(settings.arc9_bullet_physics.value,false);eq(settings.arc9_bullet_physics_shotguns.value,false)
 eq(settings.arc9_hud_force_disable.value,true);eq(settings.arc9_ricochet.value,false);eq(settings.arc9_mod_penetration.value,false)
 settings.arc9_bullet_physics.value=true;timers.ixARC9ServerPolicy();eq(settings.arc9_bullet_physics.value,false)
 local count=writes;timers.ixARC9ServerPolicy();eq(writes,count)
 PLUGIN:OnUnload();eq(timers.ixARC9ServerPolicy,nil)
 `,`
 settings={};writes=0;timers={}
 for _,n in ipairs({'arc9_bullet_physics','arc9_bullet_physics_shotguns','arc9_hud_force_disable','arc9_ricochet','arc9_mod_penetration'}) do
  settings[n]={value=true,GetBool=function(s) return s.value end,SetBool=function(s,v) writes=writes+1;s.value=v end}
 end
 GetConVar=function(n) return settings[n] end
 timer.Create=function(n,_,_,fn) timers[n]=fn end;timer.Remove=function(n) timers[n]=nil end
 `);
 suite('Legacy volumes reuse allocations, notice in-place endpoint edits and preserve exact union gaps and edits',
 ['helix/plugins/area/sh_geometry.lua'],`
 local a={min=Vector(),max=Vector(10,10,10)}
 local boxes=ix.area.GetVolumes(a);eq(ix.area.GetVolumes(a),boxes);eq(ix.area.Measure(a),1000)
 a.max.x=20;assert(ix.area.GetVolumes(a)~=boxes);eq(ix.area.Measure(a),2000)
 assert(ix.area.SetVolumes(a,{{min=Vector(),max=Vector(10,10,10)},{min=Vector(20,0,0),max=Vector(30,10,10)}}))
 eq(ix.area.Contains(a,Vector(15,5,5)),false);eq(ix.area.Contains(a,Vector(25,5,5)),true);eq(ix.area.Measure(a),2000)
 assert(ix.area.SetVolumes(a,{{min=Vector(),max=Vector(30,10,10)}}))
 eq(ix.area.Contains(a,Vector(15,5,5)),true);eq(ix.area.Measure(a),3000)
 `,geometry);
 suite('Flood scans at 5 Hz while applying force every tick, stops outside the exact volume and restores original damping',
 ['helix/plugins/area/sh_geometry.lua','ixhl2rp/plugins/flood/sv_plugin.lua'],`
 local area={min=Vector(),max=Vector(100,100,100)}
 PLUGIN.defaults={submergeDepth=20,buoyancyAccel=600,linearDamp=8,angularDamp=9}
 function PLUGIN:GetAreaBounds(a) return a.min,a.max end
 for i=1,10 do clock=10+i*.015;PLUGIN:ApplyBuoyancy('a',area,80) end
 eq(searches,1);eq(forces,10);eq(dampWrites,1)
 e.pos=Vector(200,50,10);clock=10.16;PLUGIN:ApplyBuoyancy('a',area,80);eq(forces,10)
 clock=11;PLUGIN:DrownTick();eq(linear,2);eq(angular,3);eq(PLUGIN.wetEnts[e],nil)
 e.pos=Vector(50,50,10);PLUGIN:ApplyBuoyancy('a',area,80);eq(searches,2);eq(forces,11)
 PLUGIN:OnUnload();eq(linear,2);eq(angular,3);eq(next(PLUGIN.wetEnts),nil)
 `,geometry+`
 searches=0;forces=0;dampWrites=0;linear=2;angular=3
 local phys={valid=true,IsMotionEnabled=function() return true end,GetMass=function() return 5 end,Wake=function() end,
 GetDamping=function() return linear,angular end,SetDamping=function(_,l,a) linear=l;angular=a;dampWrites=dampWrites+1 end,
 ApplyForceCenter=function() forces=forces+1 end}
 e={valid=true,pos=Vector(50,50,10),GetClass=function() return 'prop_physics' end,GetPhysicsObject=function() return phys end,
 WorldSpaceCenter=function(s) return s.pos end}
 ents.FindInBox=function() searches=searches+1;return {e} end
 `);
 suite('Routine combat award summaries retain totals and identity and flush on disconnect and shutdown',
 ['ixhl2rp/plugins/!!skills/libs/sh_actions.lua'],`
 local p={GetName=function() return 'Thomas' end,SteamID=function() return 'STEAM_1' end}
 local c={GetPlayer=function() return p end,GetID=function() return 7 end}
 for i=1,50 do ix.action:QueueCombatAward(c,{name='shoot',skill='guns'},.5) end
 eq(#logs,0);timers.ixCombatAwardLogs();eq(#logs,1)
 assert(logs[1]:find('x50',1,true));assert(logs[1]:find('25.00 XP',1,true));assert(logs[1]:find('character 7',1,true))
 ix.action:QueueCombatAward(c,{name='shoot',skill='guns'},2);hooks.PlayerDisconnected(p);eq(#logs,2)
 p.phase=true;ix.action:QueueCombatAward(c,{name='shoot',skill='guns'},1);hooks.ShutDown();eq(#logs,2);eq(#privateLogs,1)
 eq(next(ix.action.pendingAwards),nil)
 `,`
 timers={};hooks={};logs={};privateLogs={}
 timer.Create=function(n,_,_,f) timers[n]=f end;hook.Add=function(e,_,f) hooks[e]=f end
 Msg=function() end;ix.log.AddRaw=function(s) logs[#logs+1]=s end
 ix.log.CallHandler=function(_,_,s) privateLogs[#privateLogs+1]=s end
 `);
 const subtitle=native('ixhl2rp/plugins/subtitlepoint/sh_plugin.lua','\tPLUGIN.subtitlePoints =','\nend\n\n--');
 suite('Subtitle movement sends only changed positions with a revision; new clients and structural edits get complete snapshots',[],`
 ${subtitle}
 local e={valid=true,LocalToWorld=function() return Vector(30,40,50) end};PLUGIN.SaveData=function() end
 PLUGIN.subtitlePoints={{pos=Vector(),payload={text='first'},attachEnt=e,attachOffset={0,0,0}},
 {pos=Vector(100,100,100),payload={text='second'}}}
 PLUGIN:SyncSubtitlePoints();eq(messages[1].name,'ixSubtitlePointSync');eq(messages[1].args[2],1)
 hooks.ixSubtitlePointPropUpdate();eq(messages[2].name,'ixSubtitlePointPositions')
 local updates=messages[2].args[2];eq(#updates,1);eq(updates[1][1],1);eq(updates[1].payload,nil)
 clock=clock+.2;hooks.ixSubtitlePointPropUpdate();eq(#messages,2)
 local p={valid=true};PLUGIN:PlayerInitialSpawn(p);eq(messages[3].target,p);eq(#messages[3].args[1],2)
 PLUGIN:RemoveSubtitlePoint(1);eq(messages[4].args[2],2);eq(#messages[4].args[1],1)
 `,geometry+`
 hooks={};messages={};hook.Add=function(_,id,f) hooks[id]=f end
 netstream.Start=function(target,name,...) messages[#messages+1]={target=target,name=name,args={...}} end
 `);
 const clientPositions=native('ixhl2rp/plugins/subtitlepoint/sh_plugin.lua','\tlocal pointRevision=0','\n\t-- ── Нажатие E');
 suite('Subtitle client rejects stale movement after removal and accepts current revision positions',[],`
 local subtitlePoints={}
 ${clientPositions}
 netstream.handlers.ixSubtitlePointSync({{pos={1,2,3},payload={text='new'}}},5)
 netstream.handlers.ixSubtitlePointPositions(4,{{1,Vector(90,90,90)}});eq(subtitlePoints[1].pos.x,1)
 netstream.handlers.ixSubtitlePointPositions(5,{{1,Vector(9,8,7)}});eq(subtitlePoints[1].pos.x,9)
 `,geometry);
 const adaptersSetup=`
 SERVER=false;CLIENT=true;hooks={};timers={};all={};searches=0;sdCalls=0;draws=0;hotChecks=0
 function hook.Add(event,id,fn) hooks[event]=hooks[event] or {};hooks[event][id]=fn end
 function hook.Remove(event,id) if hooks[event] then hooks[event][id]=nil end end
 function hook.GetTable() return hooks end
 function timer.Create(id,delay,reps,fn) timers[id]=fn end
 function timer.Remove(id) timers[id]=nil end;function timer.Exists(id) return timers[id]~=nil end
 ents.GetAll=function() searches=searches+1;return all end
 SDDClass={Apply=function(e) sdCalls=sdCalls+1;e.mat='dclass' end}
 timers['SDDClass.Entities']=function() end
 function ent(model)
  return {valid=true,model=model,group=0,mat='',GetModel=function(s) return s.model end,
   GetBodyGroups=function() return {{id=1,name='torso'}} end,GetBodygroup=function(s) return s.group end,
   GetMaterials=function() return {'models/sectorialdistrict/citizens/city_top3'} end,GetSubMaterial=function(s) return s.mat end,
   GetNWInt=function() return 1 end,IsVehicle=function() return false end,DrawModel=function() draws=draws+1 end}
 end
 localPlayer=ent('player');function LocalPlayer() return localPlayer end
 ArcticNVGs_Enabled=true;ArcticNVGs={[1]={ThermalVision=true}}
 ArcticNVGs_GetWHOT=function(e) hotChecks=hotChecks+1;return IsValid(e) and e.hot end
 originalThermal=function() error('unoptimized hook called') end
 hook.Add('PreDrawEffects','ArcticNVGs_PreDrawEffects',originalThermal)
 render={GetBlend=function() return .8 end,GetColorModulation=function() return .1,.2,.3 end,
 SetBlend=function(v) blend=v end,SuppressEngineLighting=function(v) lighting=v end,
 SetColorModulation=function(r,g,b) colors={r,g,b} end}
 function ErrorNoHalt() errors=(errors or 0)+1 end
 `;
 suite('SD adapter skips unchanged application, detects bodygroup/external material edits and restores original hooks on unload',
 ['ixhl2rp/plugins/render_efficiency/cl_adapters.lua'],`
 local e=ent('models/sd/citizens/citizen_male_01.mdl')
 for i=1,100 do SDDClass.Apply(e) end;eq(sdCalls,1)
 e.group=3;SDDClass.Apply(e);eq(sdCalls,2)
 e.mat='changed';SDDClass.Apply(e);eq(sdCalls,3)
 clock=clock+3;SDDClass.Apply(e);eq(sdCalls,4)
 e.model='other';SDDClass.Apply(e);eq(sdCalls,5)
 eq(timers['SDDClass.Entities'],nil);PLUGIN:OnUnload()
 assert(timers['SDDClass.Entities']);eq(hooks.PreDrawEffects.ArcticNVGs_PreDrawEffects,originalThermal)
 `,adaptersSetup);
 suite('Thermal adapter does not rebuild whole entity lists per render and notices same-count replacement; rendering errors restore state',
 ['ixhl2rp/plugins/render_efficiency/cl_adapters.lua'],`
 local a=ent('a');a.hot=true;hooks.OnEntityCreated.ixEfficientRenderEntities(a)
 local f=hooks.PreDrawEffects.ArcticNVGs_PreDrawEffects
 for i=1,60 do f() end;eq(searches,1);eq(draws,60)
 a.valid=false;hooks.EntityRemoved.ixEfficientRenderEntities(a)
 local b=ent('b');b.hot=true;hooks.OnEntityCreated.ixEfficientRenderEntities(b);clock=clock+.2;f();eq(draws,61);eq(searches,1)
 b.DrawModel=function() error('draw failure') end;f();eq(blend,.8);eq(lighting,false);eq(colors[2],.2);eq(errors,1)
 f();eq(errors,1)
 `,adaptersSetup);
};
