const fs=require('fs'),runtime=require('./glua-runtime.cjs');
module.exports=nativeSuite=>{
 const suite=(name,files,assertions,setup='')=>nativeSuite(name,[],assertions,setup+'\n'+files.map(f=>'do\n'+runtime(fs.readFileSync(f,'utf8'))+'\nend').join('\n'));
 const base=['tools/geometry-fixture.lua','tools/fixtures/medicine.lua','tools/fixtures/scp-medical.lua',
 'helix/gamemode/core/sh_meta.lua','ixhl2rp/plugins/!healthsystem/libs/sh_hediffs.lua',
 'ixhl2rp/plugins/!healthsystem/sh_hediff.class.lua','ixhl2rp/plugins/!healthsystem/sh_health.class.lua',
 'ixhl2rp/plugins/!healthsystem/sh_effects.define.lua','ixhl2rp/plugins/!healthsystem/sh_scp_effects.lua',
 'ixhl2rp/plugins/medical/libs/sh_catalog.lua','ixhl2rp/plugins/medical/sh_treatment.lua',
 'ixhl2rp/plugins/medical/sv_treatment.lua','ixhl2rp/plugins/scp_npc_compat/sv_medical.lua'];
 suite('049 causes persistent cardiac arrest; only adrenaline clears it and permits stable revival',base,`
 local p=newPatient();local h=p.character.hp
 attack(p,'npc_cpt_scp_049',300)
 assert(p.critical);eq(h:GetConsciousness(),0);assert(findCondition(h,'scp_cardiac'));eq(h:GetPartHealth(3),80)
 ix.Medicine.Apply(medicalItem(p,'eft_propital'),p,p,0)
 eq(h:GetConsciousness(),0);eq(ix.Medicine.CanRevive(p),false)
 local med=medicalItem(p,'epinephrine');assert(ix.Medicine.Eligible(med,p,2))
 ix.Medicine.Apply(med,p,p,2);eq(findCondition(h,'scp_cardiac'),nil);eq(p.critical,false)
 assert(h:GetConsciousness()>=.4);assert(findCondition(h,'epinephrine_revival'))
 `);
 suite('Adrenaline treats the heart during blood loss but cannot revive an unstable patient',base,`
 local p=newPatient();local h=p.character.hp
 h:AddHediff('bleeding',0,{severity=.8});attack(p,'npc_cpt_scp_049',300)
 local med=medicalItem(p,'epinephrine');assert(ix.Medicine.Eligible(med,p,2))
 ix.Medicine.Apply(med,p,p,2);eq(findCondition(h,'scp_cardiac'),nil);assert(p.critical)
 eq(ix.Medicine.CanRevive(p),false);eq(findCondition(h,'bleeding'):GetSeverity(),.8)
 `);
 suite('CB and Unity 939 sever only a severely bitten limb, never on torso hits or fully absorbed damage',base,`
 for _,class in ipairs({'npc_cpt_scp_939_a','npc_cpt_scp_939_b','npc_cpt_scp_939_c','npc_cpt_scpunity_939'}) do
  local p=newPatient();attack(p,class,90,4);eq(p.character.data.amputation,'larm');assert(p.character.hp:GetBleedRate()>0)
  local q=newPatient();attack(q,class,90,2);eq(q.character.data.amputation,nil)
  q=newPatient();attack(q,class,90,4,function() end);eq(q.character.data.amputation,nil);eq(#q.character.hp.hediffs,0)
 end
 local p=newPatient();attack(p,'npc_cpt_scpunity_939',10,7);eq(p.character.data.amputation,nil)
 attack(p,'npc_cpt_scpunity_939',45,7);eq(p.character.data.amputation,'rleg')
 ix.Medicine.Apply(medicalItem(p,'eft_tg12'),p,p,0);eq(p.character.hp:GetBleedRate(),0)
 eq(p.character.data.amputation,'rleg')
 `);
 suite('173 paralysis has no medical cure, including CMS, and reports that clearly',base,`
 for _,class in ipairs({'npc_cpt_scp_173','npc_cpt_scpunity_173','npc_cpt_scpiso_173'}) do
  local p=newPatient();local h=p.character.hp;attack(p,class,200)
  eq(h:GetConsciousness(),1);assert(p.critical);assert(ix.SCPMedicine.IsParalyzed(h))
  eq(#p.chat,1);assert(p.chat[1]:find('не смог свернуть её до конца',1,true))
  attack(p,class,200);eq(#p.chat,1)
  eq(ix.Medicine.Eligible(medicalItem(p,'epinephrine'),p,1),false)
  eq(ix.Medicine.Eligible(medicalItem(p,'eft_splint'),p,1),false)
  local cms=medicalItem(p,'eft_surgery');eq(ix.Medicine.Eligible(cms,p,4),false)
  eq(ix.Medicine.Eligible(cms,p,1),false);ix.Medicine.Apply(cms,p,p,1)
  assert(findCondition(h,'scp_neck'));eq(ix.Medicine.CanRevive(p),false)
  for id in pairs(ix.Medicine.Catalog) do eq(ix.SCPMedicine.Treat(h,medicalItem(p,id),0),0) end
  local stage=findCondition(h,'scp_neck'):Stage()
  assert(stage:find('Лечение пока недоступно',1,true));eq(stage:find('CMS',1,true),nil)
  assert(p.notices[1]:find('Паралич необратим',1,true))
 end
 `);
 const critical=[...base,'ixhl2rp/plugins/downed_state/sh_plugin.lua','ixhl2rp/plugins/downed_state/sh_downed.lua',
 'ixhl2rp/plugins/downed_state/sh_crawl.lua','ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua'];
 const criticalSetup=`ix.Net={AddPlayerVar=function() end,Type={Float=1}};ix.util={Include=function() end}`;
 const nativePatient=`local p=newPatient();local h=p.character.hp
 p.SetCriticalState=FindMetaTable('Player').SetCriticalState
 p.InCriticalState=FindMetaTable('Player').InCriticalState
 `;
 suite('173 immediately immobilizes a conscious living victim without crawl, timeout or spontaneous recovery',critical,nativePatient+`
 p.vehicle=true;attack(p,'npc_cpt_scp_173',200)
 assert(p:InCriticalState());assert(p:Alive());eq(p.engineHealth,1);eq(p.vehicle,false)
 assert(IsValid(p.ixRagdoll));eq(p.ixRagdoll.ixGrace,nil);eq(p.vars.knocked,false)
 assert(ix.Downed.ConsciousParalysis(p));eq(h:GetConsciousness(),1)
 eq(ix.Downed.RescueWindow(p),false);eq(ix.Downed.CanRecover(h),false)
 local body=p.ixRagdoll
 for i=1,60 do clock=clock+4;ix.Downed.CrawlTick(p);h:Tick(p) end
 eq(p.ixRagdoll,body);eq(p.vars.knocked,false);assert(p:InCriticalState());eq(#p.chat,1)
 ix.Medicine.Apply(medicalItem(p,'epinephrine'),p,p,0)
 assert(p:InCriticalState());assert(ix.SCPMedicine.IsParalyzed(h));eq(findCondition(h,'epinephrine_revival'),nil)
 ix.Medicine.Apply(medicalItem(p,'eft_surgery'),p,p,1)
 assert(ix.SCPMedicine.IsParalyzed(h));assert(p:InCriticalState())
 eq(p.vars.scpParalyzed,true);eq(p.vars.knocked,false);eq(p.ixRagdoll,body)
 `,criticalSetup);
 suite('173 paralysis persists through a health reload and surgery on another injury cannot restore movement',critical,nativePatient+`
 attack(p,'npc_cpt_scp_173',200)
 local saved=h:ToSaveable();h:Init(p.character,'health');h:Load({health=saved})
 p.vars={};p.ixRagdoll=nil;p:SetCriticalState(true)
 assert(ix.Downed.ConsciousParalysis(p));eq(ix.Downed.RescueWindow(p),false)
 h:AddHediff('fracture',4,{severity=5})
 local cms=medicalItem(p,'eft_surgery');assert(ix.Medicine.Eligible(cms,p,4))
 ix.Medicine.Apply(cms,p,p,4)
 eq(findCondition(h,'fracture'),nil);assert(ix.SCPMedicine.IsParalyzed(h))
 assert(p:InCriticalState());assert(IsValid(p.ixRagdoll));eq(p.vars.knocked,false)
 assert(ix.Downed.ConsciousParalysis(p));eq(ix.Downed.CanRecover(h),false)
 `,criticalSetup);
 suite('CMS for paralysis alone is rejected at completion without consuming a dose',critical,nativePatient+`
 attack(p,'npc_cpt_scp_173',200)
 local medic=newPatient();local cms=medicalItem(medic,'eft_surgery',5)
 ix.Medicine.Reachable=function() return true end
 cms.inUse=medic;medic.bUsingMedical=true
 medic.ixMedicalSession={item=cms,target=p,patient=p.character,character=medic.character,hitgroup=1}
 ix.Medicine.Finish(medic,true)
 eq(cms.uses,5);assert(ix.SCPMedicine.IsParalyzed(h));eq(p.vars.knocked,false)
 `,criticalSetup);
 suite('Adrenaline can treat simultaneous cardiac arrest without reversing permanent neck paralysis',critical,nativePatient+`
 unpack=unpack or table.unpack
 util.TableToJSON=function() return '[]' end;util.Compress=function(s) return s end;net.WriteData=function() end
 attack(p,'npc_cpt_scp_173',200);h:AddHediff('scp_cardiac',2,{severity=1})
 h:Tick(p);eq(h:GetConsciousness(),0);eq(p.vars.knocked,true)
 local dose=medicalItem(p,'epinephrine');assert(ix.Medicine.Eligible(dose,p,2))
 ix.Medicine.Apply(dose,p,p,2);h:Tick(p)
 eq(findCondition(h,'scp_cardiac'),nil);assert(ix.SCPMedicine.IsParalyzed(h))
 assert(p:InCriticalState());assert(ix.Downed.ConsciousParalysis(p));eq(p.vars.knocked,false)
 eq(findCondition(h,'epinephrine_revival'),nil)
 `,criticalSetup);
 suite('008 progresses through saved health, survives reloading, and serum clears the cause without healing bites',base,`
 local p=newPatient();local h=p.character.hp;attack(p,'npc_cpt_scp_008_1',10,4)
 local infection=findCondition(h,'scp_infection');assert(infection)
 for i=1,5 do infection:OnTick(h) end
 local saved=h:ToSaveable();local severity=infection:GetSeverity()
 h:Init(p.character,'health');h:Load({health=saved})
 infection=findCondition(h,'scp_infection');near(infection:GetSeverity(),severity)
 for i=1,30 do infection:OnTick(h) end
 eq(infection:GetSeverity(),1);assert(p.critical);eq(h:GetConsciousness(),0)
 local serum=medicalItem(p,'scp_008_serum');assert(ix.Medicine.Eligible(serum,p,2))
 ix.Medicine.Apply(serum,p,p,2);eq(findCondition(h,'scp_infection'),nil)
 assert(findCondition(h,'cut'));eq(ix.Medicine.Eligible(serum,p,2),false)
 h:Reset();eq(#h.hediffs,0)
 `);
 suite('1048 obstruction advances without a Kill timer and requires surgery, not a bandage',base,`
 local p=newPatient();local h=p.character.hp;attack(p,'npc_cpt_scp_1048',8)
 local d=findCondition(h,'scp_airway');for i=1,7 do d:OnTick(h) end
 assert(p.critical);eq(ix.Medicine.Eligible(medicalItem(p,'bandage'),p,1),false)
 ix.Medicine.Apply(medicalItem(p,'eft_surgery'),p,p,1);eq(findCondition(h,'scp_airway'),nil)
 assert(ix.Medicine.CanRevive(p))
 `);
 suite('035 corrosion remains curable independently of 106; 966 exhaustion needs L1',base,`
 local p=newPatient();local h=p.character.hp;attack(p,'npc_cpt_scp_035',25,4)
 assert(findCondition(h,'acid'));assert(findCondition(h,'scp_corrosion_035'));eq(findCondition(h,'scp_corrosion'),nil)
 ix.Medicine.Apply(medicalItem(p,'healthkit',400),p,p,4)
 eq(findCondition(h,'acid'),nil);assert(findCondition(h,'scp_corrosion_035'))
 ix.Medicine.Apply(medicalItem(p,'scp_neutralizer'),p,p,2);eq(findCondition(h,'scp_corrosion_035'),nil)
 p=newPatient();h=p.character.hp;attack(p,'npc_cpt_scp_966',20,4)
 eq(ix.SCPMedicine.MovementFactor(h),.6)
 ix.Medicine.Apply(medicalItem(p,'eft_l1'),p,p,2);eq(ix.SCPMedicine.MovementFactor(h),1)
 `);
 suite('106 corrosion is incurable; eTG slows by half for 60 seconds, refreshes without stacking and persists its expiry',base,`
 local now=1000;os.time=function() return now end
 local p=newPatient();local h=p.character.hp;attack(p,'npc_cpt_scpunity_106',25,4)
 local d=findCondition(h,'scp_corrosion');assert(d);local original=d:GetSeverity()
 eq(ix.Medicine.Eligible(medicalItem(p,'scp_neutralizer'),p,2),false)
 ix.Medicine.Apply(medicalItem(p,'scp_neutralizer'),p,p,2);eq(d:GetSeverity(),original)
 ix.Medicine.Apply(medicalItem(p,'eft_etg'),p,p,2)
 eq(d:GetSeverity(),original);eq(ix.SCPMedicine.ProgressionFactor(h,'scp_corrosion'),.5)
 eq(ix.SCPMedicine.ProgressionFactor(h,'scp_infection'),1)
 for i=1,5 do now=now+4;d:OnTick(h) end
 near(d:GetSeverity(),original+.03*5)
 ix.Medicine.Apply(medicalItem(p,'eft_etg'),p,p,2)
 local count=0;for _,v in h:GetHediffs() do if v.uniqueID=='scp_corrosion_support' then count=count+1 end end
 eq(count,1);local support=findCondition(h,'scp_corrosion_support');eq(support.tended_start+support.tended_time,1080)
 local saved=h:ToSaveable();h:Init(p.character,'health');h:Load({health=saved})
 d=findCondition(h,'scp_corrosion');support=findCondition(h,'scp_corrosion_support')
 eq(support.tended_start+support.tended_time,1080);eq(ix.SCPMedicine.ProgressionFactor(h,'scp_corrosion'),.5)
 now=1080;eq(ix.SCPMedicine.ProgressionFactor(h,'scp_corrosion'),1)
 local before=d:GetSeverity();d:OnTick(h);near(d:GetSeverity(),before+.06)
 for i=1,50 do now=now+4;d:OnTick(h) end
 eq(d:GetSeverity(),1);assert(p.critical);eq(ix.Medicine.CanRevive(p),false)
 ix.Medicine.Apply(medicalItem(p,'eft_etg'),p,p,2);eq(d:GetSeverity(),1);assert(p.critical)
 eq(#ix.SCPMedicine.TreatmentMatches(h,medicalItem(p,'eft_etg'),2),0)
 `);
 suite('106 slowdown is applied only after completed treatment; cancelled injections consume nothing',base,`
 local medic,p=newPatient(),newPatient();ix.SCPMedicine.Expose(p,'scp_corrosion',2)
 ix.Medicine.Reachable=function() return true end
 local item=medicalItem(medic,'eft_etg',2)
 local function begin()
  item.inUse=medic;medic.bUsingMedical=true
  medic.ixMedicalSession={item=item,target=p,patient=p.character,character=medic.character,hitgroup=2}
 end
 begin();ix.Medicine.Finish(medic,false);eq(item.uses,2);eq(findCondition(p.character.hp,'scp_corrosion_support'),nil)
 begin();ix.Medicine.Finish(medic,true);eq(item.uses,1);assert(findCondition(p.character.hp,'scp_corrosion_support'))
 near(findCondition(p.character.hp,'scp_corrosion'):GetSeverity(),.1)
 `);
 suite('035 poison projectiles cannot create or cure the irreversible 106 condition',base,`
 local p=newPatient();local h=p.character.hp
 attack(p,'obj_cpt_scp_poisongas',10,4);assert(findCondition(h,'scp_corrosion_035'));eq(findCondition(h,'scp_corrosion'),nil)
 util.AddAttackEffect=function() error('native poison timer must be suppressed') end
 ix.SCPMedicine.Install()
 local q=newPatient();util.AddAttackEffect(scpNPC('npc_cpt_scp_035'),q,10,DMG_POI)
 assert(findCondition(q.character.hp,'scp_corrosion_035'));eq(findCondition(q.character.hp,'scp_corrosion'),nil)
 ix.SCPMedicine.Expose(q,'scp_corrosion',2)
 ix.Medicine.Apply(medicalItem(q,'scp_neutralizer'),q,q,2)
 eq(findCondition(q.character.hp,'scp_corrosion_035'),nil);assert(findCondition(q.character.hp,'scp_corrosion'))
 `);
 suite('SCP burn injuries heal with kits; mauling caps extreme native damage and splits real wounds',base,`
 local p=newPatient();local h=p.character.hp;attack(p,'npc_cpt_scp_457',15,4)
 assert(findCondition(h,'scp_burn'));eq(findCondition(h,'gunshot'),nil);eq(h:GetBleedRate(),0)
 ix.Medicine.Apply(medicalItem(p,'healthkit',400),p,p,4);eq(findCondition(h,'scp_burn'),nil)
 p=newPatient();h=p.character.hp;attack(p,'npc_cpt_scp_096',1000,4)
 eq(h:GetPartHealth(5),0);eq(h:GetPartHealth(3),35)
 `);
 suite('All SCP damage and special effects respect downed, dead, god mode and possession immunity',base,`
 for _,flag in ipairs({'critical','dead','god','controller'}) do
  local p=newPatient();p[flag]=true
  for _,class in ipairs({'npc_cpt_scp_049','npc_cpt_scp_939_a','npc_cpt_scp_173','npc_cpt_scp_008_1'}) do attack(p,class,500,4) end
  eq(ix.SCPMedicine.Expose(p,'scp_infection',2),false);eq(#p.character.hp.hediffs,0);eq(p.character.data.amputation,nil)
 end
 local p=newPatient();p.SCP_Has714=true;attack(p,'npc_cpt_scp_049',300);eq(#p.character.hp.hediffs,0)
 eq(ix.SCPMedicine.Damage(p,scpDamage(scpNPC('npc_cpt_scp_ntf')),wound),false)
 eq(ix.SCPMedicine.Damage(scpNPC('npc_zombie'),scpDamage(scpNPC('npc_cpt_scp_049')),wound),false)
 `);
 suite('Native infection callbacks skip Helix victims and remain unchanged for NPCs across repeated patching',base,`
 local p=newPatient();local other=scpNPC('npc_citizen');local n=scpNPC('npc_cpt_scp_008_1')
 function n:OnHitEntity(list) self.hit=list end
 local original=n.OnHitEntity
 ix.SCPMedicine.Patch(n);ix.SCPMedicine.Patch(n);n:OnHitEntity({p,other})
 eq(#n.hit,1);eq(n.hit[1],other);eq(n.ixSCPMedicalHit,original)
 n=scpNPC('npc_cpt_scp_008');function n:Infect(v) self.native=v end
 ix.SCPMedicine.Patch(n);n:Infect(p);assert(findCondition(p.character.hp,'scp_infection'));eq(n.native,nil)
 n:Infect(other);eq(n.native,other)
 `);
 suite('Patient examination exposes SCP diagnoses and only the correct body-part cures',
 [...base,'ixhl2rp/plugins/medical/sv_examination.lua'],`
 local medic,p=newPatient(),newPatient();attack(p,'npc_cpt_scp_049',300)
 local med=medicalItem(medic,'epinephrine');med.functions={inject={}}
 local transmitted;net.ReadEntity=function() return p end;net.WriteEntity=function() end;net.WriteTable=function(t) transmitted=t end
 ix.Medicine.Reachable=function() return true end
 net.handlers.ixMedicalExamine(16,medic)
 local found=false
 for _,part in ipairs(transmitted.parts) do
  if part.hitgroup==2 then assert(part.injuries[1]:find('SCP%-049'));eq(part.medicines[1],med.id);found=true end
 end
 assert(found)
 `);
 suite('Cancelled SCP treatment consumes no dose; successful completion removes the cause and consumes one',base,`
 local medic,p=newPatient(),newPatient();ix.SCPMedicine.Expose(p,'scp_infection',2)
 ix.Medicine.Reachable=function() return true end
 local item=medicalItem(medic,'scp_008_serum',2)
 item.inUse=medic;medic.bUsingMedical=true
 medic.ixMedicalSession={item=item,target=p,patient=p.character,character=medic.character,hitgroup=2}
 ix.Medicine.Finish(medic,false);eq(item.uses,2);assert(findCondition(p.character.hp,'scp_infection'))
 item.inUse=medic;medic.ixMedicalSession={item=item,target=p,patient=p.character,character=medic.character,hitgroup=2}
 ix.Medicine.Finish(medic,true);eq(item.uses,1);eq(findCondition(p.character.hp,'scp_infection'),nil)
 `);
 suite('Actual health dispatcher invokes the SCP bridge after downed/ragdoll guards and uses real wound application',
 [...base,'ixhl2rp/plugins/!healthsystem/sv_combat.lua'],`
 local p=newPatient();local n=scpNPC('npc_cpt_scp_049');local damage=scpDamage(n,300)
 assert(PLUGIN:EntityTakeDamage(p,damage));assert(findCondition(p.character.hp,'scp_cardiac'))
 p=newPatient();n=scpNPC('npc_cpt_scpunity_939');n.IsPossessed=true
 util.TraceLine=function() return {Entity=p,HitGroup=4} end
 assert(PLUGIN:EntityTakeDamage(p,scpDamage(n,45)));eq(p.character.data.amputation,'larm')
 p=newPatient();n=scpNPC('npc_cpt_scp_457');n.IsPossessed=true
 util.TraceLine=function() return {Entity=p,HitGroup=2} end
 local armor={id=7,armor={coverage={[2]=1},density=.8,max_durability=100,penetration={burn=1},damage={burn=1}},value=.5}
 function armor:GetData() return self.value end;function armor:SetData(_,v) self.value=v end
 p.char_outfit.armor[armor]=true;ix.Item.instances[7]=armor
 assert(PLUGIN:EntityTakeDamage(p,scpDamage(n,20)));assert(armor.value<.5)
 p=newPatient();p.critical=true;ix.Downed={BlockDamage=function(target,dmg) if target.critical then dmg:SetDamage(0);return true end end}
 assert(PLUGIN:EntityTakeDamage(p,scpDamage(n,50)));eq(#p.character.hp.hediffs,0)
 `);
 suite('Untreated systemic collapse ends the fall in unconsciousness rather than allowing conscious crawling',
 [...base,'ixhl2rp/plugins/downed_state/sh_plugin.lua','ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua'],`
 local p=newPatient();attack(p,'npc_cpt_scp_049',300)
 p.vars.criticalFallUntil=10;p.vars.criticalCrawlUntil=35
 ix.Downed.FinishFall(p)
 eq(p.vars.criticalCrawlUntil,nil);eq(p.vars.knocked,true);assert(p.critical)
 `,`ix.Net={AddPlayerVar=function() end,Type={Float=1}};ix.util={Include=function() end}`);
 suite('SCP effect ticks do not cross character switches or resurrect cleared effects after reset',base,`
 local p=newPatient();local h=p.character.hp;ix.SCPMedicine.Expose(p,'scp_infection',2)
 local d=findCondition(h,'scp_infection');local saved=d:GetSeverity()
 p.character=newPatient().character;d:OnTick(h);eq(d:GetSeverity(),saved)
 p.character=h.character;h:Reset();eq(#h.hediffs,0)
 `);
 suite('GLua execution adapter preserves continue, nested loops, local scopes and actual break',[],`
 ${runtime(`local total=0
 for i=1,4 do
  if i==2 then continue end
  local x=i
  for j=1,3 do if j==2 then continue end;total=total+x end
  if i==3 then break end
 end
 eq(total,8)`)}
 `);
};
