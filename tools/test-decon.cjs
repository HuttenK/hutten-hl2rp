const {run,source,native,base,finish}=require('./restored-test-runner.cjs');
const facility=['sh_core','sh_repair','sv_store','sv_connections','sv_power','sv_doors','sv_comms','sv_jobs','sv_repair','sv_devices','sv_network'].map(f=>'ixhl2rp/plugins/facility_utilities/'+f+'.lua');
const env=source([...base,...facility])+`
 local facility=PLUGIN;facility.loaded=true
 ix.util={Include=function() end};ix.area={stored={}};ix.config.Add=function() end
 local oldEntity=entity
 function entity(...)
  local e=oldEntity(...)
  function e:GetOwner() return self.owner end
  function e:GetClass() return self.class or 'prop_physics' end
  function e:StopSound() end
  function e:IsNPC() return self.npc==true end
  function e:IsPlayer() return self.player==true end
  function e:Health() return self.hp or 100 end
  return e
 end
 local original=admin
 function user()
  local p=original();p.admin=false
  function p:IsNPC() return false end
  function p:GetNW2Bool(k,d) if self[k]~=nil then return self[k] end;return d end
  function p:GetNetVar(k,d) if self[k]~=nil then return self[k] end;return d end
  function p:SetNWFloat(k,v) self[k]=v end
  function p:SetNWBool(k,v) self[k]=v end
  function p:WorldSpaceCenter() return self:GetPos() end
  function p:SetAction(text) hook.Run('PlayerActionChanged',self,text);self.action=text end
  return p
 end
 local make=device
 function equipment(kind)
  local saved=PLUGIN;PLUGIN=facility;local d=make(kind);PLUGIN=saved
  d.entity.pos=Vector(30,0,0);return d
 end
 util.TraceLine=function() return {Hit=wall==true} end
 ents.FindInSphere=function() return nearby or {} end
 local blocked=false
 local nativePower=facility.DevicePowered
 function facility:DevicePowered(d) return not blocked and not d.fault and d.enabled~=false end
 function power(v) blocked=not v end
 function otherSession(p,mode)
  local s={character=p:GetCharacter(),item={inUse=p},entity=entity(9800,'',Vector())}
  if mode=='medical' then p.ixMedicalSession=s;p.bUsingMedical=true
  else s.character=p:GetCharacter():GetID();s.repair={stage=2,round=3};s.fusebox=mode=='fusebox';facility.work[p]=s end
  return s
 end
 function unchanged(p,mode,s)
  if mode=='medical' then eq(p.ixMedicalSession,s);eq(p.bUsingMedical,true);eq(s.item.inUse,p)
  else eq(facility.work[p],s);eq(s.repair.stage,2);eq(s.repair.round,3) end
 end
 PLUGIN={};ix.plugin.list.decontamination=PLUGIN
`+source(['helix/plugins/area/sh_geometry.lua','ixhl2rp/plugins/decontamination/sh_plugin.lua','ixhl2rp/plugins/decontamination/sv_decon.lua'])+`
 local P=PLUGIN
 hook.Add('PlayerActionChanged','decon',function(p) P:PlayerActionChanged(p) end)
 ix.plugin.list.scp610_control={settings={zoneGas=true},pending={},Is610=function(_,e) return IsValid(e) and e:GetClass():find('npc_vj_scp_610_',1,true)==1 end}
 function npc(class) local e=entity(900,'',Vector(40,0,0));e.npc=true;e.class=class or 'npc_vj_scp_610_1';return e end
 function remains()
  local e=entity(1000,'',Vector(45,0,0));e.class='prop_ragdoll';P:MarkRemains(npc(),e);return e
 end
`;
function suite(name,test){run(name,env+test)}
suite('Shower clears real exposure after eight seconds without health/progression changes',`
 local d,p=equipment('decon_shower'),user();p.ixToxic=.6;p.ixToxicMsg=.4;p.health=22
 P:Use(p,d.entity);assert(P.actions[p]);clock=clock+7;P:Think();eq(p.ixToxic,.6)
 clock=clock+1;P:Think();eq(p.ixToxic,0);eq(p.ixToxicMsg,nil);eq(p.ixToxicLevel,0);eq(p.ixToxicChoke,false);eq(p.health,22);eq(P.actions[p],nil)
`);
suite('Toxic area refuses shower; disabled zone gas permits it and interruption does not cleanse',`
 local d,p=equipment('decon_shower'),user();p.ixToxic=.4
 ix.area.stored.a={type='infection',startPosition=Vector(-10,-10,-10),endPosition=Vector(60,60,80)}
 P:Use(p,d.entity);eq(P.actions[p],nil)
 ix.plugin.list.scp610_control.settings.zoneGas=false;clock=clock+1;P:Use(p,d.entity);assert(P.actions[p])
 p.pos=Vector(25,0,0);clock=clock+8;P:Think();eq(p.ixToxic,.4);eq(P.actions[p],nil)
`);
suite('Power loss, device motion, character switch, damage and replacement cancel',`
 for _,mode in ipairs({'power','move','character','damage','replacement'}) do
  power(true);local d,p=equipment('decon_shower'),user();p.ixToxic=.7
  P:Use(p,d.entity);assert(P.actions[p])
  if mode=='power' then power(false) elseif mode=='move' then d.entity.pos=Vector(35,0,0)
  elseif mode=='character' then p.character={GetID=function() return 42 end}
  elseif mode=='damage' then P:EntityTakeDamage(p,{GetDamage=function() return 5 end}) else p:SetAction('other') end
  clock=clock+9;P:Think();eq(p.ixToxic,.7);eq(P.actions[p],nil);eq(P.occupants[d.entity],nil)
 end
`);
suite('One shower occupant and clearance apply; use again cancels',`
 local d,a,b=equipment('decon_shower'),user(),user()
 d.level=4;b.card.clearanceLevel=1;P:Use(b,d.entity);eq(P.actions[b],nil)
 P:Use(a,d.entity);assert(P.actions[a]);b.card.clearanceLevel=4;clock=clock+1;P:Use(b,d.entity);eq(P.actions[b],nil)
 P:Use(a,d.entity);eq(P.actions[a],nil);eq(P.occupants[d.entity],nil)
`);
suite('Disposal only consumes trusted dead infected NPC ragdoll and cancels pending regrowth',`
 local d,p=equipment('decon_disposal'),user();local corpse=remains();nearby={corpse}
 local c=ix.plugin.list.scp610_control;c.pending[corpse]={at=999}
 P:Use(p,d.entity);assert(P.actions[p]);clock=clock+8;P:Think()
 eq(IsValid(corpse),false);eq(c.pending[corpse],nil)
`);
suite('Arbitrary props, player corpses, live infected NPCs and loot containers are never accepted',`
 local e=entity(2000,'',Vector());e.class='prop_ragdoll';eq(P:IsRemains(e),false)
 local p=user();P:MarkRemains(p,e);eq(P:IsRemains(e),false)
 local normal=npc('npc_citizen');P:MarkRemains(normal,e);eq(P:IsRemains(e),false)
 local valid=remains();valid.ixInventoryID=4;eq(P:IsRemains(valid),false)
 valid.ixInventoryID=nil;P:OnPlayerCorpseCreated(p,valid);eq(P:IsRemains(valid),false)
 eq(P:IsRemains(npc()),false)
`);
suite('Removing or moving corpse during disposal cannot remove another object',`
 local d,p=equipment('decon_disposal'),user();local corpse=remains();nearby={corpse}
 P:Use(p,d.entity);assert(P.actions[p]);corpse.pos=Vector(1000,0,0)
 local other=remains();nearby={other};clock=clock+8;P:Think();assert(IsValid(corpse));assert(IsValid(other));eq(P.actions[p],nil)
`);
suite('Sensor counts relevant nearby threats and closest zone boundary; offline never CLEAR',`
 local d=equipment('decon_sensor');local corpse=remains();local infected=npc();local ordinary=npc('npc_citizen')
 local flora=entity(3000,'',Vector());flora.ixInfectionFlora='test';nearby={corpse,infected,ordinary,flora}
 ix.area.stored.a={type='infection',startPosition=Vector(300,0,0),endPosition=Vector(5000,50,50)}
 ix.area.stored.b={type='infection',startPosition=Vector(1000,0,0),endPosition=Vector(5000,50,50)}
 local counts=P:Scan(d);eq(counts.zones,1);eq(counts.npcs,1);eq(counts.flora,1);eq(counts.remains,1);eq(d.entity.ixDeconAlarm,true)
 power(false);P:Scan(d);eq(d.entity.ixDeconAlarm,false);assert(d.entity.ixDeconStatus:find('НЕТ ПИТАНИЯ',1,true))
`);
suite('New kinds use native facility records and persistence; no parallel storage',`
 eq(ix.Facility.kinds.decon_shower.name,'Душ деконтаминации')
 local d=equipment('decon_sensor');d.fault=true;d.radius=220;d.name='Gate detector';facility:SaveData()
 local saved=stored.foundation_utilities_v1;eq(#saved.devices,1);eq(saved.devices[1].kind,'decon_sensor');eq(saved.devices[1].fault,true)
 eq(saved.devices[1].radius,220);eq(saved.devices[1].name,'Gate detector')
`);
suite('Native facility power honors fault, grid loss and direct generator power; target is connectable',`
 local d=equipment('decon_shower');facility.DevicePowered=nativePower
 ix.plugin.list.blackout.IsPosBlackedOut=function() return true end
 eq(facility:DevicePowered(d),false)
 d.entity:SetNW2Bool('ixGeneratorPower',true);eq(facility:DevicePowered(d),true)
 d.fault=true;eq(facility:DevicePowered(d),false);d.fault=false
 local target,ent=facility:PowerTarget(d.entity);eq(target.kind,'device');eq(target.id,d.id);eq(ent,d.entity)
`);
suite('Native SCP610 corpse adapters tag both VJ callback generations with death spawning disabled',`
 local C=ix.plugin.list.scp610_control;C.entities={};C.growthClasses={};C.settings.growthInterval=180;C.settings.deathSpawns=false
 function C:IsSterilized() return false end
 do local P=C
 `+native('ixhl2rp/plugins/scp610_control/sv_control.lua','function P:Adapt(ent)','function P:TryGrowth(ent)')+`
 end
 hook.Add('SCP610CorpseCreated','decon',function(s,c) P:SCP610CorpseCreated(s,c) end)
 for _,kind in ipairs({'npc_vj_scp_610_1','npc_vj_scp_610_6'}) do
  local n=npc(kind);local called=0
  n.OnCreateDeathCorpse=function() called=called+1 end
  C:Adapt(n)
  for _,method in ipairs({'OnCreateDeathCorpse','CustomOnDeath_AfterCorpseSpawned'}) do
   local corpse=entity(9000,'',Vector());corpse.class='prop_ragdoll'
   n[method](n,nil,nil,corpse);eq(P:IsRemains(corpse),true);eq(C.pending[corpse],nil)
  end
  eq(called,1)
 end
`);
suite('Accepted medical, device repair and fusebox sessions reject shower and disposal starts',`
 for _,mode in ipairs({'medical','repair','fusebox'}) do for _,kind in ipairs({'decon_shower','decon_disposal'}) do
  local d,p=equipment(kind),user();local corpse=remains();nearby={corpse};p.ixToxic=.7
  local s=otherSession(p,mode);P:Use(p,d.entity);clock=clock+9;P:Think()
  eq(P.actions[p],nil);eq(p.ixToxic,.7);assert(IsValid(corpse));unchanged(p,mode,s)
 end end
`);
suite('Medical, device repair or fusebox begun during shower/disposal cancels without touching native work',`
 for _,mode in ipairs({'medical','repair','fusebox'}) do for _,kind in ipairs({'decon_shower','decon_disposal'}) do
  local d,p=equipment(kind),user();local corpse=remains();nearby={corpse};p.ixToxic=.7
  P:Use(p,d.entity);assert(P.actions[p]);local s=otherSession(p,mode);p.action='native subsystem display'
  clock=clock+9;P:Think()
  eq(P.actions[p],nil);eq(P.occupants[d.entity],nil);eq(p.ixToxic,.7);assert(IsValid(corpse))
  eq(p.action,'native subsystem display');unchanged(p,mode,s)
 end end
`);
finish();
