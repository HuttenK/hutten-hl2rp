const {source,native}=require('./restored-test-runner.cjs');
const fs=require('fs');
const {normalize}=require('./glua.cjs');
module.exports=suite=>{
 const scheduler='ixhl2rp/plugins/performance_runtime/sv_scheduler.lua';
 const schedulerSetup=`
 local hooks={};hook.Add=function(e,id,fn) hooks[e]=hooks[e] or {};hooks[e][id]=fn end
 hook.Remove=function(e,id) if hooks[e] then hooks[e][id]=nil end end
 local cpu=0;function SysTime() return cpu end
 local errors={};function ErrorNoHalt(s) errors[#errors+1]=s end
 `;
 suite('Maintenance budgets stagger work, slice fairly, avoid catch-up storms and back off errors',[scheduler],`
 local R=ix.runtime;local calls={}
 for i=1,20 do R.Schedule('job'..i,10,function() calls[i]=(calls[i] or 0)+1;cpu=cpu+.002;return false end,{delay=0}) end
 R.Step();eq(table.Count(calls),1)
 for i=1,19 do R.Step() end
 eq(table.Count(calls),20);for _,n in pairs(calls) do eq(n,1) end
 for i=1,20 do R.Cancel('job'..i) end
 R.Schedule('once',10,function() calls.once=(calls.once or 0)+1 end,{delay=0})
 clock=1000;R.Step();R.Step();eq(calls.once,1);eq(R.jobs.once.due,1010)
 R.Schedule('bad',.1,function() error('intentional') end,{delay=0})
 R.Step();eq(#errors,1);for i=1,10 do clock=clock+.1;R.Step() end;eq(#errors,1)
 clock=1006;R.Step();eq(#errors,1);clock=1036;R.Step();eq(#errors,2)
 R.Schedule('phaseA',10,function() end);R.Schedule('phaseB',10,function() end)
 assert(R.jobs.phaseA.due~=R.jobs.phaseB.due)
 PLUGIN:OnUnload();eq(#R.order,0);eq(next(R.jobs),nil);eq(hooks.Think.ixRuntimeMaintenance,nil);eq(R.active,false)
 `,schedulerSetup+`function table.Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end`);
 suite('Maintenance cancellation and replacement during callbacks cannot starve neighbours',[scheduler],`
 local R=ix.runtime;local seen={}
 R.Schedule('a',1,function() seen.a=true;R.Cancel('a');R.Cancel('c') end,{delay=0})
 R.Schedule('b',1,function() seen.b=true;R.Schedule('b',1,function() seen.new=true end,{delay=0}) end,{delay=0})
 R.Schedule('c',1,function() error('cancelled job ran') end,{delay=0})
 R.Schedule('d',1,function() seen.d=true end,{delay=0})
 R.Step();R.Step();assert(seen.a and seen.b and seen.d and seen.new);eq(#errors,0)
 `,schedulerSetup);
 const base=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','tools/fixtures/facility.lua','helix/plugins/area/sh_geometry.lua'];
 const facility=[...base,...['sh_core','sh_repair','sv_store','sv_portables','sv_connections','sv_power','sv_doors','sv_comms','sv_jobs','sv_repair','sv_devices','sv_network'].map(x=>'ixhl2rp/plugins/facility_utilities/'+x+'.lua')];
 function power(name,test){suite(name,[],source(facility)+'\nPLUGIN.loaded=true\n'+test)}
 power('Power plan reuse advances resources and invalidates fault, priority, zone, source replacement and live cable obstruction',`
 local P=PLUGIN;local a=circuit('A',30,1,true),b
 b=circuit('B',30,5,true)
 local g=device('generator');g.running=true;g.fuel=50;g.capacity=40
 local endpoint=connectCircuit(g,a);connectCircuit(g,b)
 local builds=0;local build=P.RebuildPowerPlan
 function P:RebuildPowerPlan(dt) builds=builds+1;return build(self,dt) end
 P:RecomputePower(0);eq(a.powered,true);eq(b.powered,false);eq(builds,1)
 for i=1,3 do clock=clock+.25;P:RecomputePower(.25) end
 eq(builds,1);near(g.fuel,49.25)
 b.priority=0;P:RecomputePower(.25);eq(builds,2);eq(a.powered,false);eq(b.powered,true)
 g.fault=true;P:RecomputePower(.25);eq(a.powered,false);eq(b.powered,false);g.fault=false
 P:RecomputePower(.25);eq(b.powered,true)
 ix.plugin.list.blackout.zones.B.remoteIsolation=true;P:RecomputePower(.25);eq(b.powered,false);eq(a.powered,true)
 ix.plugin.list.blackout.zones.B.remoteIsolation=nil
 local replacement={};for k,v in pairs(g) do replacement[k]=v end;P.store.devices[g.id]=replacement
 P:RecomputePower(.25);eq(P.powerPlan.gens[1],replacement)
 local trace=util.TraceLine;util.TraceLine=function() return {Hit=true} end
 P:RecomputePower(.25);eq(a.powered,false);eq(b.powered,false);util.TraceLine=trace
 P:RecomputePower(.25);eq(b.powered,true)
 endpoint:SetPos(Vector(10000,0,0));P:RecomputePower(.25);eq(a.powered,false)
 `);
 power('Power depletion revokes reserve within same tick and charger fuel is finite',`
 local P=PLUGIN;local c=circuit('A',20,1,true)
 local g=device('generator');g.running=true;g.fuel=.1;g.capacity=30;connectCircuit(g,c)
 P:RecomputePower(.25);near(g.fuel,0);eq(g.running,false);eq(c.powered,false)
 local b=device('battery');b.capacity=25;b.charge=20;connectCircuit(b,c)
 ix.plugin.list.blackout.zones.Source={min=Vector(-100,-100,-100),max=Vector(200,200,200),active=true}
 P:RecomputePower(.5);near(b.charge,10);eq(c.powered,true)
 P:RecomputePower(.5);eq(c.powered,false);near(b.charge,10) -- cannot sustain a whole circuit below its load
 b.charge=20;P:RecomputePower(1);near(b.charge,0);eq(c.powered,false)
 `);
 power('Empty intercom service avoids repeated all-player publication but wakes for new hardware and calls',`
 local P=PLUGIN;local calls=0;local players=player.GetAll
 player.GetAll=function() calls=calls+1;return players() end
 P:PruneComms();eq(calls,1);clock=clock+.25;P:PruneComms();eq(calls,1)
 local d=device('intercom');P:PruneComms();eq(calls,2)
 clock=clock+6;P:PruneComms();eq(calls,3)
 `);
 power('Facility record persistence keeps stable IDs and dirty state across failed commit; load failure never uses stale legacy',`
 local P=PLUGIN;local d=device('generator');local c=circuit('A');local saved;local loadError
 ix.recordStore={Split=function(s) return s end,Join=function(s) return s end,
 Save=function(ns,s) eq(ns,'facility_utilities/test_map');saved=table.Copy(s);return true end,
 Load=function() if loadError then return nil,loadError end;return saved end}
 P.dirty=true;P:SaveData();eq(P.dirty,false);assert(saved.devices[d.id]);assert(saved.circuits[c.id])
 ix.recordStore.Save=function() return false,'disk full' end;P.dirty=true;eq(pcall(P.SaveData,P),false);eq(P.dirty,true)
 loadError='corrupt';eq(pcall(P.LoadData,P),false)
 `);

 suite('World background capture is bounded and explicit saves, additions, removals and failed commits remain durable',
 ['ixhl2rp/plugins/world_persistence/sv_store.lua'],`
 local P=PLUGIN;P.loaded=true;P.classes={test=true};P.nextID=31
 local captures=0;local saved;local failure=false
 game={GetMap=function() return 'testmap' end}
 ix.recordStore={Save=function(ns,rows) eq(ns,'world_persistence/testmap');if failure then return false,'disk full' end;saved=table.Copy(rows);return true end}
 function P:Eligible(e) return IsValid(e) end
 function P:Capture(e,id) captures=captures+1;return {id=id,value=e.value} end
 for i=1,30 do P.records[i]={entity={valid=true,value=i},data={id=i,value=i}} end
 eq(P:AutosaveStep(),false);eq(captures,8);eq(saved,nil)
 P.records[20]=nil;P.records[31]={entity={valid=true,value=31},data={id=31,value=31}};P.nextID=32
 P.records[1].entity.value=999;P:SaveData();eq(saved['entity:1'].value,999);eq(saved['entity:20'],nil);eq(saved['entity:31'].value,31)
 while P:AutosaveStep()==false do end
 eq(saved['entity:1'].value,999);eq(saved['entity:20'],nil);eq(saved['entity:31'].value,31)
 failure=true;eq(pcall(P.SaveData,P),false);P.records[1].entity.value=1000;failure=false;P:ShutDown();eq(saved['entity:1'].value,1000)
 `);
 const adapterSetup=source(['tools/geometry-fixture.lua'])+schedulerSetup+`
 local V=getmetatable(Vector());function V:DistToSqr(b) local x,y,z=self.x-b.x,self.y-b.y,self.z-b.z;return x*x+y*y+z*z end
 local raw=${JSON.stringify(fs.readFileSync('tools/fixtures/cpt-hearing.lua','utf8'))}
 file={Read=function() return raw end};util.CRC=function() return '293089188' end
 local gets=0;local entities={};ents.GetAll=function() gets=gets+1;return entities end
 hook.GetTable=function() return hooks end
 assert(load(${JSON.stringify(normalize(fs.readFileSync('tools/fixtures/cpt-hearing.lua','utf8')))},'@lua/autorun/server/cpt_hooks.lua'))()
 local original=hooks.EntityEmitSound.CPTBase_DetectEntitySounds
 local config={ai_disabled=0,cpt_npchearing_advanced=1};function GetConVarNumber(k) return config[k] end
 local timers={};timer.Simple=function(_,fn) timers[#timers+1]=fn end;timer.Create=function(id,_,_,fn) timers[id]=fn end
 timer.Remove=function(id) timers[id]=nil end
 local jobs={};ix.runtime={Schedule=function(id,_,fn) jobs[id]=fn end}
 local function npc()
  local e={valid=true,CPTBase_NPC=true,UseAdvancedHearing=true,heard=0}
  function e:IsNPC() return true end;function e:GetClass() return 'npc_cpt_scp_939_a' end
  function e:AdvancedHearingCode(ent,level,pos,volume) self.heard=self.heard+1;self.last={ent,level,pos,volume} end
  return e
 end
 function flush() local t=timers;timers={};for k,fn in pairs(t) do if type(k)=='number' then fn() else timers[k]=fn end end end
 `;
 suite('CPT hearing adapter scans once, preserves live eligibility and sound arguments, tracks equal-count replacement and restores original hook',
 ['ixhl2rp/plugins/performance_runtime/sv_adapters.lua'],`
 local one,two=npc(),npc();two.IsPossessed=true
 entities={one,two};flush();eq(gets,1)
 local emitter={valid=true};local sound={Entity=emitter,SoundLevel=85,Pos=Vector(100,0,0),Volume=.75}
 for i=1,50 do hooks.EntityEmitSound.CPTBase_DetectEntitySounds(sound) end
 eq(gets,1);eq(one.heard,50);eq(two.heard,50);eq(one.last[2],85);eq(one.last[4],.75)
 one.UseAdvancedHearing=false;hooks.EntityEmitSound.CPTBase_DetectEntitySounds(sound);eq(one.heard,50)
 hooks.EntityRemoved.ixRuntimeEntities(two);two.valid=false
 local replacement=npc();hooks.OnEntityCreated.ixRuntimeEntities(replacement);flush()
 hooks.EntityEmitSound.CPTBase_DetectEntitySounds(sound);eq(replacement.heard,1)
 config.ai_disabled=1;hooks.EntityEmitSound.CPTBase_DetectEntitySounds(sound);eq(replacement.heard,1)
 config.ai_disabled=0;config.cpt_npchearing_advanced=0;hooks.EntityEmitSound.CPTBase_DetectEntitySounds(sound);eq(replacement.heard,1)
 PLUGIN:RestoreAdapters();eq(hooks.EntityEmitSound.CPTBase_DetectEntitySounds,original)
 PLUGIN:RestoreAdapters();eq(hooks.EntityEmitSound.CPTBase_DetectEntitySounds,original)

 `,adapterSetup);

 suite('Unknown CPT hearing implementation is retained without replacement or errors',
 ['ixhl2rp/plugins/performance_runtime/sv_adapters.lua'],`
 util.CRC=function() return 'unknown' end;flush()
 eq(hooks.EntityEmitSound.CPTBase_DetectEntitySounds,original)
 file.Read=function() return nil end;PLUGIN:InstallHearingAdapter();eq(hooks.EntityEmitSound.CPTBase_DetectEntitySounds,original)
 `,adapterSetup);
 suite('Ordinary prop sleep is sliced and excludes ragdolls, held, moving, parented and constrained bodies',
 ['ixhl2rp/plugins/performance_runtime/sv_adapters.lua'],`
 MOVETYPE_VPHYSICS=6;MASK_SOLID=1
 constraint={HasConstraints=function(e) return e.constrained end}
 local ph={valid=true,vel=Vector(),angvel=Vector(),sleeps=0}
 function ph:IsAsleep() return false end;function ph:IsMoveable() return true end
 function ph:GetVelocity() return self.vel end;function ph:GetAngleVelocity() return self.angvel end;function ph:Sleep() self.sleeps=self.sleeps+1 end
 local e={valid=true,pos=Vector()}
 function e:IsNPC() return false end;function e:GetClass() return 'prop_physics' end;function e:GetPhysicsObject() return ph end
 function e:MapCreationID() return -1 end
 function e:GetParent() return self.parent end;function e:GetOwner() return nil end;function e:IsPlayerHolding() return self.held end
 function e:GetPhysicsObjectCount() return 1 end;function e:GetMoveType() return MOVETYPE_VPHYSICS end
 function e:GetPos() return self.pos end;function e:OBBMins() return Vector(0,0,-5) end;function e:LocalToWorld(v) return v end
 local trace={HitWorld=true,StartSolid=false};util.TraceLine=function() return trace end
 entities={e};flush();local slice=jobs['runtime.restingProps']
 slice();clock=clock+4;slice();eq(ph.sleeps,1)
 e.parent={valid=true};slice();clock=clock+4;slice();eq(ph.sleeps,1);e.parent=nil
 for _,field in ipairs({'held','constrained','ixRuntimeKeepAwake'}) do
  e[field]=true;slice();clock=clock+4;slice();eq(ph.sleeps,1);e[field]=false
 end
 ph.vel=Vector(1,0,0);slice();clock=clock+4;slice();eq(ph.sleeps,1)
 ph.vel=Vector();trace.HitWorld=false;slice();clock=clock+4;slice();eq(ph.sleeps,1)
 `,adapterSetup);
};
