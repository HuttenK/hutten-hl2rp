const {source}=require('./restored-test-runner.cjs');
const fs=require('fs'),{normalize}=require('./glua.cjs');
module.exports=suite=>{
 const base=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','tools/fixtures/facility.lua','helix/plugins/area/sh_geometry.lua'];
 const facility=[...base,...['sh_core','sh_repair','sv_store','sv_portables','sv_connections','sv_power','sv_doors','sv_comms','sv_jobs','sv_repair','sv_devices','sv_network'].map(x=>'ixhl2rp/plugins/facility_utilities/'+x+'.lua')];
 const check=(name,test)=>suite(name,[],source(facility)+'\nPLUGIN.loaded=true\n'+test);
 check('Review: ending the last intercom call during the prune gate clears hints on the next eligible pass',`
 local P=PLUGIN;local d=device('intercom');local p=admin()
 assert(P:CallIntercom(p,d));P:PruneComms();assert(p.ixFacilityVoiceHint~='')
 P:EndCall(d.id);P:PruneComms()
 clock=clock+.25;P:PruneComms()
 eq(p.ixFacilityVoiceHint,'');eq(p.ixFacilityStopHint,'');eq(p.ixFacilityMic,false)
 `);
 check('Review: hardware insertion and removal during the prune gate do not consume an idle wake',`
 local P=PLUGIN;local publications=0;local all=player.GetAll
 player.GetAll=function() publications=publications+1;return all() end
 P:PruneComms();eq(publications,1)
 local d=device('intercom');P:PruneComms();eq(publications,1)
 clock=clock+.25;P:PruneComms();eq(publications,2)
 eq(d.entity:GetNW2String('ixFacilityState',''),'E — ВЫЗВАТЬ ПОМОЩЬ')
 P.store.devices[d.id]=nil;P:PruneComms();eq(publications,2)
 clock=clock+.25;P:PruneComms();eq(publications,3)
 clock=clock+.25;P:PruneComms();eq(publications,3)
 `);
 check('Review: changed capacity, enable state, load and same-count link replacement revoke and restore cached allocations',`
 local P=PLUGIN;local a=circuit('A',20,1,true);local b=circuit('B',20,2,true)
 local g=device('generator');g.running=true;g.fuel=100;g.capacity=40
 connectCircuit(g,a);connectCircuit(g,b)
 P:RecomputePower(0);eq(a.powered,true);eq(b.powered,true)
 clock=clock+.25;P:RecomputePower(.25);near(g.fuel,99.75)
 g.capacity=20;P:RecomputePower(.25);eq(a.powered,true);eq(b.powered,false)
 g.enabled=false;P:RecomputePower(.25);eq(a.powered,false);eq(b.powered,false)
 g.enabled=true;a.load=30;P:RecomputePower(.25);eq(a.powered,false);eq(b.powered,true)
 g.capacity=40;P:RecomputePower(.25);eq(a.powered,true);eq(b.powered,false)
 g.links[1],g.links[2]=g.links[2],g.links[1];P:RecomputePower(.25);eq(a.powered,true);eq(b.powered,false)
 local link=g.links[2];local replacement={};for k,v in pairs(link) do replacement[k]=v end
 replacement.zone='B';P.linkEntities[replacement]=P.linkEntities[link];g.links[2]=replacement
 P:RecomputePower(.25);eq(a.powered,false);eq(b.powered,true)
 `);
 check('Review: a lock door entering safety isolation revokes cached direct reserve in the next power tick',`
 local P=PLUGIN;local g=device('generator');g.running=true;g.fuel=100
 local lock=entity(900,'lock',Vector(100,20,20));lock.class='ix_combinelock'
 lock.door=entity(901,'door',Vector(200,20,20));lock.door.class='prop_door_rotating'
 ix.plugin.list.blackout.zones.Outage={min=Vector(90,0,0),max=Vector(110,100,100),active=true}
 ix.plugin.list.blackout.zones.Isolation={min=Vector(400,0,0),max=Vector(500,100,100),remoteIsolation=true}
 local link={kind='entity',binding={class=lock.class,model=lock:GetModel(),pos=lock:GetPos()}}
 g.links={link};P.linkEntities[link]=lock
 P:RecomputePower(0);eq(lock:GetNW2Bool('ixGeneratorPower',false),true)
 lock.door:SetPos(Vector(450,20,20));clock=clock+.25;P:RecomputePower(.25)
 eq(lock:GetNW2Bool('ixGeneratorPower',false),false)
 local rebuild=P.RebuildPowerPlan;local rebuilds=0
 function P:RebuildPowerPlan(dt) rebuilds=rebuilds+1;return rebuild(self,dt) end
 lock.door=entity(902,'door',Vector(450,20,20));lock.door.class='prop_door_rotating'
 P:RecomputePower(.25);eq(rebuilds,1);eq(lock:GetNW2Bool('ixGeneratorPower',false),false)
 lock.door.valid=false;P:RecomputePower(.25);eq(rebuilds,2);eq(lock:GetNW2Bool('ixGeneratorPower',false),true)
 `);
 const hearingFile=fs.readFileSync('tools/fixtures/cpt-hearing.lua','utf8');
 const adapterSetup=source(['tools/geometry-fixture.lua'])+`
 local hooks={};hook.Add=function(e,id,fn) hooks[e]=hooks[e] or {};hooks[e][id]=fn end
 hook.Remove=function(e,id) if hooks[e] then hooks[e][id]=nil end end
 hook.GetTable=function() return hooks end
 local entities={};local scans=0;ents.GetAll=function() scans=scans+1;return entities end
 local raw=${JSON.stringify(hearingFile)}
 file={Read=function() return raw end};util.CRC=function() return '293089188' end
 function GetConVarNumber(k) return k=='ai_disabled' and 0 or 1 end
 assert(load(${JSON.stringify(normalize(hearingFile))},'@addons/cpt_base/lua/autorun/server/cpt_hooks.lua'))()
 local original=hooks.EntityEmitSound.CPTBase_DetectEntitySounds
 local timers={};timer.Simple=function(_,fn) timers[#timers+1]=fn end
 timer.Create=function(id,_,_,fn) timers[id]=fn end;timer.Remove=function(id) timers[id]=nil end
 ix.runtime={Schedule=function() end,Cancel=function() end}
 local function flush() local t=timers;timers={};for k,fn in pairs(t) do if type(k)=='number' then fn() else timers[k]=fn end end end
 local function npc() local e={valid=true,CPTBase_NPC=true,UseAdvancedHearing=true,heard=0}
 function e:IsNPC() return true end;function e:GetClass() return 'npc_cpt_scp_939_a' end
 function e:AdvancedHearingCode() self.heard=self.heard+1 end;return e end
 local sound={Entity={valid=true},SoundLevel=70,Volume=1,Pos=Vector()}
 `;
 suite('Review: mounted CPT bytes do not authorize replacing a pre-existing foreign callback',
 ['ixhl2rp/plugins/performance_runtime/sv_adapters.lua'],`
 local foreignCalls=0;local foreign=function() foreignCalls=foreignCalls+1 end
 hooks.EntityEmitSound.CPTBase_DetectEntitySounds=foreign;flush()
 eq(hooks.EntityEmitSound.CPTBase_DetectEntitySounds,foreign)
 PLUGIN:InstallHearingAdapter();PLUGIN:RestoreAdapters()
 eq(hooks.EntityEmitSound.CPTBase_DetectEntitySounds,foreign)
 hooks.EntityEmitSound.CPTBase_DetectEntitySounds(sound);eq(foreignCalls,1)
 `,adapterSetup);
 suite('Review: a profiler around the installed hearing hook survives retries and unload with original semantics',
 ['ixhl2rp/plugins/performance_runtime/sv_adapters.lua'],`
 local one=npc();entities={one};flush();eq(scans,1)
 local adapted=hooks.EntityEmitSound.CPTBase_DetectEntitySounds;assert(adapted~=original)
 local measurements=0;local measured=function(data) measurements=measurements+1;return adapted(data) end
 hooks.EntityEmitSound.CPTBase_DetectEntitySounds=measured
 for i=1,3 do PLUGIN:InstallHearingAdapter() end
 eq(hooks.EntityEmitSound.CPTBase_DetectEntitySounds,measured)
 measured(sound);eq(one.heard,1);eq(scans,1)
 PLUGIN:RestoreAdapters();eq(hooks.EntityEmitSound.CPTBase_DetectEntitySounds,measured)
 local two=npc();entities={two};measured(sound)
 eq(scans,2);eq(two.heard,1);eq(one.heard,1);eq(measurements,2)
 `,adapterSetup);
 suite('Review: map-created props are never force-slept even when stationary on world geometry',
 ['ixhl2rp/plugins/performance_runtime/sv_adapters.lua'],`
 MOVETYPE_VPHYSICS=6;MASK_SOLID=1;constraint={HasConstraints=function() return false end}
 local ph={valid=true,sleeps=0}
 function ph:IsAsleep() return false end;function ph:IsMoveable() return true end
 function ph:GetVelocity() return Vector() end;function ph:GetAngleVelocity() return Vector() end
 function ph:Sleep() self.sleeps=self.sleeps+1 end
 local e={valid=true};function e:IsNPC() return false end;function e:GetClass() return 'prop_physics' end
 function e:GetPhysicsObject() return ph end;function e:MapCreationID() return 42 end
 function e:GetParent() return nil end;function e:GetOwner() return nil end;function e:IsPlayerHolding() return false end
 function e:GetPhysicsObjectCount() return 1 end;function e:GetMoveType() return MOVETYPE_VPHYSICS end
 function e:GetPos() return Vector() end;function e:OBBMins() return Vector(0,0,-5) end
 function e:LocalToWorld(v) return v end
 util.TraceLine=function() return {HitWorld=true,StartSolid=false} end
 local jobs={};ix.runtime.Schedule=function(id,_,fn) jobs[id]=fn end
 entities={e};flush();local slice=jobs['runtime.restingProps']
 for i=1,10 do slice();clock=clock+1 end;eq(ph.sleeps,0)
 `,adapterSetup);
};
