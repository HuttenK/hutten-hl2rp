const {native}=require('./restored-test-runner.cjs');
module.exports=suite=>{
 const batch=native('helix/gamemode/game/items/sh_item.class.lua','function ITEM:SetData(','function ITEM:GetData(');
 const save=native('helix/gamemode/game/items/sh_item.class.lua','\tfunction ITEM:SaveData()','\tfunction ITEM:Save()');
 const queue=native('helix/gamemode/game/items/sh_item.lua','\tfunction Item:SaveData()','\tfunction Item:SyncAll(');
 const itemSetup=`
 ITEM={};ix.Item={instances={},items_to_savedata={}};Item=ix.Item
 ${batch}\n${save}\n${queue}
 db={};writes=0;syncs=0;serializations=0
 util.TableToJSON=function(data) serializations=serializations+1;return table.Copy(data) end
 mysql={Update=function()
  local q={};function q:Update(_,v) self.data=v end;function q:Where(_,id) self.id=id end
  function q:Execute() writes=writes+1;db[self.id]=self.data end;return q
 end}
 function makeItem(id)
  local item=setmetatable({id=id,data={},vars={},vars_id={},data_callbacks={}},{__index=ITEM})
  function item:GetID() return self.id end;function item:GetData(key) return self.data[key] end
  for _,key in ipairs({'ammo','ammo2','ammoType','ammoType2','arc9_atts','extra'}) do
   item.vars[key]={Sync=function() syncs=syncs+1 end};item.vars_id[#item.vars_id+1]=key
  end
  ix.Item.instances[id]=item;return item
 end
 `;
 suite('ARC9 idle saves do zero writes; multi-field edits save once, including nested attachments and nil clears',
 ['ixhl2rp/plugins/ammo_cringe/sh_arc9.lua'],`
 local A=ix.arc9Inventory;local item=makeItem(1)
 local w={valid=true,ARC9=true,ixItem=item,ixInventoryReady=true,clip=30,clip2=1,ammo='rifle',ammo2='grenade',
  Attachments={{Installed='scope',ToggleNum=1,SubAttachments={{Installed='lens'}}}},
  Clip1=function(self) return self.clip end,Clip2=function(self) return self.clip2 end,
  GetValue=function(self,k) if k=='Ammo' then return self.ammo else return self.ammo2 end end}
 eq(A.Save(item,w),true);eq(writes,1);eq(syncs,5);eq(db[1].ammo,30)
 local oldTree=item.data.arc9_atts
 for i=1,100 do eq(A.Save(item,w),false) end
 eq(writes,1);eq(syncs,5);eq(serializations,1);eq(item.data.arc9_atts,oldTree)
 w.clip=24;w.clip2=0;w.ammo2=nil;w.Attachments[1].SubAttachments[1].ToggleNum=2
 eq(A.Save(item,w),true);eq(writes,2);eq(syncs,9)
 eq(db[1].ammo,24);eq(db[1].ammo2,0);eq(db[1].ammoType2,nil)
 eq(db[1].arc9_atts[1].SubAttachments[1].ToggleNum,2)
 eq(oldTree[1].SubAttachments[1].ToggleNum,nil)
 w.ixInventoryReady=false;w.clip=0;A.Save(item,w);eq(writes,2)
 `,itemSetup);
 suite('Synchronous item batches preserve callbacks, nested batches, other-item writes and error recovery',[],`
 local item,other=makeItem(1),makeItem(2)
 item.data_callbacks.ammo=function(self,value)
  self:SetDataBatch({{'extra',value+1}})
  other:SetData('ammo',10)
  eq(db[1],nil) -- another item's flush cannot expose this partial batch
 end
 item:SetDataBatch({{'ammo',5},{'ammo2',2}})
 eq(writes,2);eq(db[1].extra,6);eq(db[1].ammo2,2);eq(db[2].ammo,10)
 item.data_callbacks.ammo=nil
 item.data_callbacks.ammo2=function() error('test callback failure') end
 local ok=pcall(item.SetDataBatch,item,{{'ammo',3},{'ammo2',1}})
 eq(ok,false);eq(item.ixDataBatchDepth,0);eq(writes,3)
 item.data_callbacks.ammo2=nil;item:SetData('ammo',0);eq(writes,4);eq(db[1].ammo,0)
 item.vars.extra.NoSave=true;item:SetDataBatch({{'extra',99}});eq(writes,4)
 `,itemSetup);
 const filterSetup=`
 ix.voice={};timers={};hooks={};routes={};setCalls=0;clearCalls=0;routeCalls=0;enabled=true
 CreateConVar=function() return {GetBool=function() return enabled end} end
 timer.Create=function(n,_,_,fn) timers[n]=fn end
 hook.Add=function(n,id,fn) hooks[n]=fn end
 concommand={Add=function() end};require=function() end
 eightbit={EFF_RADIO=5,IsHookAvailable=function() return true end,
 SetReceiverEffect=function(a,b,e) setCalls=setCalls+1;routes[a..':'..b]=e end,
 ClearReceiverEffect=function(a,b) clearCalls=clearCalls+1;routes[a..':'..b]=nil end,
 ClearPlayer=function(id) for k in pairs(routes) do if k:match('^'..id..':') or k:match(':'..id..'$') then routes[k]=nil end end end}
 function person(id)
  return {valid=true,id=id,character={},UserID=function(self) return self.id end,
  IsSpeaking=function(self) return self.speaking end,GetCharacter=function(self) return self.character end}
 end
 allPlayers={};for i=1,40 do allPlayers[i]=person(i) end
 `;
 suite('40 idle voice users do zero pair routes; one speaker does 40; unchanged native filters are not rewritten',
 ['ixhl2rp/plugins/proximity_voice/sv_filter.lua'],`
 local V=ix.voice;V.Route=function(listener,talker) routeCalls=routeCalls+1;return not listener.denied,false,'' end
 for i=1,10 do timers.ixRadioFilterRoutes() end;eq(routeCalls,0);eq(setCalls,0)
 allPlayers[1].speaking=true;timers.ixRadioFilterRoutes();eq(routeCalls,40);eq(setCalls,39)
 timers.ixRadioFilterRoutes();eq(routeCalls,80);eq(setCalls,39)
 allPlayers[2].denied=true;timers.ixRadioFilterRoutes();eq(routes['2:1'],nil);eq(clearCalls,1)
 allPlayers[1].speaking=false;timers.ixRadioFilterRoutes();eq(next(routes),nil);eq(routeCalls,120)
 timers.ixRadioFilterRoutes();eq(routeCalls,120);eq(clearCalls,39)
 local p=allPlayers[1];p.ixRadioVoice={expires=clock+1,character=p.character}
 timers.ixRadioFilterRoutes();eq(routeCalls,160)
 clock=clock+2;timers.ixRadioFilterRoutes();eq(routeCalls,160);eq(next(routes),nil)
 p.speaking=true;timers.ixRadioFilterRoutes();enabled=false;timers.ixRadioFilterRoutes();eq(next(routes),nil)
 `,filterSetup);
 const receiver=native('helix/entities/entities/ix_item.lua',"\tnet.Receive('item.entity.action'",'\nelse\n');
 suite('Stale or replaced world-item requests are ignored before method/bit reads; valid actions still execute',[],`
 ${receiver}
 local receive=net.handlers['item.entity.action']
 entity=nil;receive(20,client);eq(reads,0)
 entity={valid=true,GetClass=function() return 'prop_physics' end};receive(20,client);eq(reads,0)
 entity=world;receive(20,client);eq(reads,0)
 world.item=item;item.entity=world;actionID=9;receive(20,client);eq(runs,0)
 actionID=1;distance=10000;receive(20,client);eq(runs,0)
 distance=100;receive(20,client);eq(runs,1)
 world.valid=false;receive(20,client);eq(runs,1)
 `,`
 reads=0;runs=0;distance=100;local point={DistToSqr=function() return distance end}
 client={valid=true,GetCharacter=function() return {} end,GetPos=function() return point end}
 world={valid=true,GetClass=function() return 'ix_item' end,GetItem=function(self) return self.item end,GetPos=function() return point end}
 item={functions_bits=2,functions_id={[1]='take'},functions={take={}}}
 net.ReadEntity=function() return entity end;net.ReadUInt=function() reads=reads+1;return actionID end
 ix.Item={PerformItemEntityAction=function(_,p,i,e,id) eq(p,client);eq(i,item);eq(e,world);eq(id,1);runs=runs+1 end}
 `);
 const pda=native('ixhl2rp/plugins/site_pda/cl_device.lua','local function Device()','hook.Add("CreateMove"');
 suite('PDA blocked-menu close is bounded under lag, retries, and resets after close or device replacement',[],`
 local F=ix.Fieldlink
 ${pda}
 for i=1,120 do clock=10+i/120;think() end
 eq(sent,1)
 clock=11.1;think();eq(sent,2)
 weapon.equipped=false;think();weapon.equipped=true;clock=11.11;think();eq(sent,3)
 weapon=makeWeapon();clock=11.12;think();eq(sent,4)
 blocked=false;clock=11.2;think();eq(sent,4)
 blocked=true;clock=12.2;think();eq(sent,5)
 `,`
 ix.Fieldlink={class='pda'};ix.gui={};sent=0;blocked=true
 function makeWeapon() return {valid=true,equipped=true,GetClass=function() return 'pda' end,
  GetPDAEquipped=function(self) return self.equipped end} end
 weapon=makeWeapon();local c={GetID=function() return 1 end,GetData=function() return 2 end}
 local p={valid=true,GetCharacter=function() return c end,Alive=function() return true end,
  GetLocalVar=function() return 0 end,HasItem=function() return true end,GetActiveWeapon=function() return weapon end}
 function LocalPlayer() return p end;function RealTime() return clock end
 gui={IsConsoleVisible=function() return blocked end,IsGameUIVisible=function() return false end}
 hook.Add=function(_,_,fn) think=fn end;net.Start=function() end;net.SendToServer=function() sent=sent+1 end
 `);
 const bleedingSetup=`
 SERVER=false;CLIENT=true;clock=0;PLUGIN={};updates={};hooks={};bursts=0;created=0;particles=0;lifetimes={}
 local vec=getmetatable(Vector());function vec:DistToSqr(other) local d=self-other;return d:Dot(d) end
 hook.Add=function(n,id,fn) hooks[id]=fn end
 timer.Create=function(n,_,_,fn) updates[n]=fn end
 effects={Register=function(e) bleedingEffect=e end}
 function makeBleeder(id)
  return {valid=true,id=id,pos=Vector(id,0,0),bleeding=true,
   Alive=function(self) return not self.dead end,GetNetVar=function(self,k) if k=='isBleeding' then return self.bleeding end end,
   GetPos=function(self) return self.pos end,LookupBone=function() return 1 end,
   GetBonePosition=function(self) return self.pos,Angle() end}
 end
 local observer={valid=true,EyePos=function() return Vector() end}
 function LocalPlayer() return observer end
 function Entity() end
 allPlayers={makeBleeder(1)}
 function EffectData()
  return {SetEntity=function(self,v) self.entity=v end,GetEntity=function(self) return self.entity end,
   SetOrigin=function(self,v) self.pos=v end,GetOrigin=function(self) return self.pos end,
   SetAngles=function(self,v) self.ang=v end,GetAngles=function(self) return self.ang end}
 end
 seen={};function util.Effect(_,data)
  bursts=bursts+1;seen[data.entity]=(seen[data.entity] or 0)+1
  bleedingEffect.Init({},data)
 end
 function VectorRand() return Vector(1,1,1) end
 function math.Rand(a,b) return (a+b)/2 end
 function ParticleEmitter()
  created=created+1
  return {valid=true,SetPos=function() end,Finish=function(self) self.valid=false end,
   Add=function(_,material)
    if rejectParticles then return end
    particles=particles+1
    return setmetatable({SetDieTime=function(_,v) lifetimes[#lifetimes+1]=v end},{__index=function() return function() end end})
   end}
 end
 `;
 // The general vector fixture supplies engine-like Angle basis operations.
 const {read}=require('./restored-test-runner.cjs');
 const vectors=read('tools/fixtures/sharedposes.lua')+'\n'+read('tools/fixtures/pose-gizmo.lua');
 for(const fps of [30,60,144]) suite(`Bleeding emission stays at 20 Hz at ${fps} FPS and reuses a patient emitter`,
 ['ixhl2rp/plugins/!healthsystem/cl_fx.lua'],`
 updates.ixBleedingUpdate()
 for frame=1,${fps} do clock=frame/${fps};PLUGIN:DrawBleeding();PLUGIN:DrawBleeding() end
 assert(bursts>=19 and bursts<=21,tostring(bursts));eq(created,1);eq(particles,bursts*10)
 near(lifetimes[1],.2)
 local old=bursts;clock=20;PLUGIN:DrawBleeding();eq(bursts,old+1) -- no catch-up storm
 rejectParticles=true;clock=21;PLUGIN:DrawBleeding() -- exhausted particle allocation is safe
 allPlayers[1].bleeding=false;updates.ixBleedingUpdate();eq(next(seen)~=nil,true)
 allPlayers[1].bleeding=true;updates.ixBleedingUpdate();clock=22;PLUGIN:DrawBleeding();eq(created,2)
 hooks.ixBleedingEmitters()
 `,vectors+'\n'+bleedingSetup);
 suite('Bleeding budget is fair across 20 casualties and never catches up after a long frame',
 ['ixhl2rp/plugins/!healthsystem/cl_fx.lua'],`
 allPlayers={};for i=1,20 do allPlayers[i]=makeBleeder(i) end
 updates.ixBleedingUpdate()
 for i=1,20 do clock=i*.05;PLUGIN:DrawBleeding() end
 eq(bursts,120);for _,p in ipairs(allPlayers) do eq(seen[p],6) end
 local before=bursts;clock=100;PLUGIN:DrawBleeding();eq(bursts,before+6)
 `,vectors+'\n'+bleedingSetup);
 suite('Medical idle Think never enumerates all players; active sessions keep cancellation and disconnect cleanup',
 ['tools/fixtures/medicine.lua','ixhl2rp/plugins/medical/libs/sh_catalog.lua','ixhl2rp/plugins/medical/sh_treatment.lua','ixhl2rp/plugins/medical/sv_treatment.lua'],`
 player.GetAll=function() error('idle population scan') end
 for i=1,100 do hooks.Think.ixMedicalSessions() end
 local p=newMedic();local item=medicalItem(p,'morphine',3)
 ix.Medicine.Begin(item,p,0);assert(ix.Medicine.activeSessions[p]);eq(item.uses,3)
 p.restricted=true;hooks.Think.ixMedicalSessions();eq(item.uses,3);eq(next(ix.Medicine.activeSessions),nil);flush()
 p.restricted=false;item.player=p;ix.Medicine.Begin(item,p,0);assert(ix.Medicine.activeSessions[p])
 hooks.PlayerDisconnected.ixMedicalCleanup(p);eq(item.inUse,nil);eq(next(ix.Medicine.activeSessions),nil)
 `);
 for(const file of ['gonews/entities/entities/ix_gonews_terminal.lua','taskboard/entities/entities/ix_taskboard.lua']) {
  const think=native('ixhl2rp/plugins/'+file,'\tfunction ENT:Think()','\tfunction ENT:DrawScreen()');
  suite('Client terminal scheduler uses its half-second interval: '+file,[],`
  local DRAW_DIST2=100;local SCALE=.1
  ${think}
  local ent=setmetatable({m_bInitialized=true,GetPos=function() return {} end,
   SetNextClientThink=function(self,at) self.nextThink=at end},{__index=ENT})
  eq(ent:Think(),true);near(ent.nextThink,clock+.5)
  `,`ENT={};function EyePos() return {DistToSqr=function() return 1000 end} end`);
 }
 suite('Performance capture is opt-in, duration-bounded, reports hitches and counters, and removes its sampling hook',
 ['ixhl2rp/plugins/performance_monitor/sh_plugin.lua'],`
 eq(hooks.Tick,nil);ix.performance.Count('idle',99)
 local denied={valid=true,IsSuperAdmin=function() return false end}
 commands.ix_perf_server(denied,'',{'10'});eq(ix.performance.capture,nil)
 commands.ix_perf_server(nil,'',{'10'});assert(hooks.Tick)
 local callback=hooks.Tick;ix.performance.Count('saved',2)
 at=at+.015;callback();at=at+.2;callback();at=at+10;callback()
 eq(hooks.Tick,nil);eq(ix.performance.capture,nil);eq(writes,1)
 eq(report.counters.saved,2);eq(report.counters.idle,nil);eq(report.samples,3);eq(report.gapsOver100ms,2)
 assert(report.intervalMaxMs>=10000);eq(report.population[1].players,0)
 ix.performance.Count('saved',10);eq(report.counters.saved,2)
 `,`
 hooks={};commands={};at=0;writes=0;collectgarbage=function() return 64 end
 GetConVar=function() return nil end
 ix.util={Include=function() end}
 hook.Add=function(n,id,fn) hooks[n]=fn end;hook.Remove=function(n) hooks[n]=nil end
 concommand={Add=function(n,fn) commands[n]=fn end};SysTime=function() return at end
 game={GetMap=function() return 'test_map' end};engine={TickInterval=function() return 1/66 end}
 ents.GetCount=function() return 50 end;player.GetAll=function() return {} end
 file={CreateDir=function() end,Write=function(path) assert(path:find('ix_performance/server_',1,true));writes=writes+1 end}
 util.TableToJSON=function(value) report=value;return '{}' end
 `);
};
