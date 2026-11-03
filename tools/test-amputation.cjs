const fs=require('fs');
const normalize=require('./glua-runtime.cjs');
module.exports=suite=>{
 const fixture='tools/fixtures/amputation.lua';
 const shared='ixhl2rp/plugins/amputation/sh_plugin.lua';
 const server='ixhl2rp/plugins/amputation/sv_plugin.lua';
 const files=[fixture,shared,server];
 suite('Amputation completion awards remains once, including a full bag, and releases every lock',files,`
  local A=ix.Amputation
  for _,full in ipairs({false,true}) do
   patient.char.data.amputation=nil;surgeon.items={tool};surgeon.full=full;reps=0
   A.BeginCut(surgeon,patient,'larm',tool)
   eq(tool.inUse,surgeon);eq(surgeon.ixAmputationBusy,patient.ixAmputationBusy)
   local finish=timers.ixAmputationcutsurgeon;finish();released()
   local remains=ix.Item.instances[ix.Item.serial];eq(remains.uniqueID,'limb_larm')
   if full then eq(remains.spawned,surgeon);eq(remains.inventory_id,nil) else eq(remains.inventory_id,1) end
   eq(A.Get(patient.char),'larm')
  end
 `);
 suite('Amputation rejects treatment on either participant, locks its tool and permits cancellation by either player',files,`
  local A=ix.Amputation
  surgeon.bUsingMedical=true;A.BeginCut(surgeon,patient,'larm',tool);released();surgeon.bUsingMedical=nil
  patient.ixMedicalSession={};A.BeginCut(surgeon,patient,'larm',tool);released();patient.ixMedicalSession=nil
  ix.Medicine.activeSessions[viewer]={target=patient}
  A.BeginCut(surgeon,patient,'larm',tool);released();ix.Medicine.activeSessions={}
  A.BeginCut(surgeon,patient,'larm',tool)
  eq(hook.Run('CanPlayerDropItem',surgeon,tool),false);eq(hook.Run('CanTransferItem',tool),false)
  patient.reload=true;timers.ixAmputationcutsurgeon();released();patient.reload=false
  eq(hook.Run('CanPlayerDropItem',surgeon,tool),nil)
  A.BeginCut(surgeon,patient,'larm',tool);surgeon.items={};timers.ixAmputationcutsurgeon();released()
  surgeon.items={tool};A.BeginCut(surgeon,patient,'larm',tool);patient.char={data={},GetData=function() end}
  timers.ixAmputationcutsurgeon();released()
 `);
 suite('Death, disconnect and character switches cancel surgery immediately and stale consent cannot restart it',files,`
  local A=ix.Amputation
  for _,event in ipairs({'PlayerDeath','PlayerDisconnected','PrePlayerLoadedCharacter'}) do
   A.BeginCut(surgeon,patient,'larm',tool);hook.Run(event,patient);released()
   A.RequestCut(surgeon,patient,'larm',tool);hook.Run(event,surgeon)
   net.handlers.ixAmputationConsent(0,patient);released()
  end
  A.RequestCut(surgeon,patient,'larm',tool);local old=requestID
  clock=clock+A.consentTimeout+1;delayed[#delayed]();A.RequestCut(surgeon,patient,'larm',tool)
  replyID=old;net.handlers.ixAmputationConsent(0,patient);released()
  replyID=requestID;consent=false;net.handlers.ixAmputationConsent(0,patient);released()
 `);
 suite('Medical treatment rejects an amputation lock in both directions without consuming medicine',
 [...files,'ixhl2rp/plugins/medical/libs/sh_catalog.lua','ixhl2rp/plugins/medical/sv_treatment.lua'],`
  local M,A=ix.Medicine,ix.Amputation
  M.Reachable=function() return true end
  local medicine={player=surgeon,uniqueID='bandage',GetUses=function() return 5 end}
  surgeon.items={tool,medicine}
  M.Eligible=function() return true end
  A.BeginCut(surgeon,patient,'larm',tool)
  eq(M.Begin(medicine,patient,4),false);eq(surgeon.ixMedicalSession,nil);eq(medicine.inUse,nil)
  medicine.inUse=surgeon
  eq(M.ValidSession(surgeon,{target=patient,item=medicine,character=surgeon.char,patient=patient.char}),false)
  A.CancelOperation(patient);released()
 `);
 suite('Bone hiding is cached, networked, preserved through ragdolls and safely rebound on a model/character change',files,`
  local A=ix.Amputation
  patient.scales[3]=Vector(2,2,2);patient.positions[3]=Vector(4,0,0)
  assert(A.Amputate(patient,'larm',true));eq(patient:GetNetVar('ixAmputation'),'larm')
  eq(patient.scales[4],A.scale);eq(patient.scales[2],A.scale);eq(patient.scales[5],A.scale)
  eq(patient.scales[3],Vector(2,2,2))
  local reads,mutations=patient.boneReads,patient.mutations;A.Refresh(patient)
  eq(patient.boneReads,reads);eq(patient.mutations,mutations)
  local rag=person('rag');rag.ragdoll=true;PLUGIN:OnPlayerServerRagdollCreated(patient,rag)
  eq(rag:GetNetVar('ixAmputation'),'larm');eq(rag.scales[2],A.scale)
  patient.model='other.mdl';patient.names[4]='other';patient.names[6]='ValveBiped.Bip01_L_Forearm'
  patient.parents[8]=6;patient.parents[2]=0;patient.parents[5]=0
  PLUGIN:PlayerModelChanged(patient)
  eq(patient.scales[4],A.normal);eq(patient.scales[6],A.scale);eq(patient.scales[8],A.scale)
  eq(patient.scales[3],Vector(2,2,2));eq(patient.positions[3],Vector(4,0,0))
  assert(A.Restore(patient));eq(patient:GetNetVar('ixAmputation'),nil);eq(patient.scales[6],A.normal)
  patient.char=nil;A.Refresh(patient);eq(patient:GetNetVar('ixAmputation'),nil)
 `);
 suite('Render matrices collect every removed child at the joint with positive scale and leave other bones untouched',
 [fixture,shared,'ixhl2rp/plugins/amputation/cl_visuals.lua'],`
  local A=ix.Amputation
  for _,key in ipairs({'larm','rarm','lleg','rleg'}) do
   local p=person(key);p.vars.ixAmputation=key;p.modelScale=.92
   local bones=A.CollectBones(p,A.limbs[key]);local anchor=p:GetBoneMatrix(bones[1]):GetTranslation()
   local intact=p:GetBoneMatrix(0)
   A.BindVisual(p);A.BindVisual(p);eq(p.callbackID,1)
   A.BuildMissingLimb(p);A.BuildMissingLimb(p)
   for _,bone in ipairs(bones) do
    eq(p.matrices[bone]:GetTranslation(),anchor);near(p.matrices[bone]:GetScale().x,.0092)
   end
   eq(p.matrices[0]:GetTranslation(),intact:GetTranslation());eq(p.matrices[0]:GetScale(),Vector(1,1,1))
   p.noMatrix=bones[1];A.BuildMissingLimb(p)
  end
  local copy=person('hands');patient.vars.ixAmputation='rarm'
  A.BindVisual(copy,patient);eq(A.VisualKey(copy),'rarm');A.BuildMissingLimb(copy)
  eq(copy.matrices[8]:GetTranslation(),copy.matrices[6]:GetTranslation())
  patient.vars.ixAmputation=nil;eq(A.VisualKey(copy),nil)
  A.ClearVisualCallbacks();eq(table.Count(copy.callbacks),0);eq(copy.invalidated,true)
 `);
 const meleeSetup=`
 DMG_SLASH=4;DMG_CLUB=128;DMG_BULLET=2
 blade={valid=true,AOC_Melee=true,IsWeapon=function() return true end,GetClass=function() return 'aoc_sword' end}
 damage={amount=20,kind=DMG_SLASH,inflictor=blade,position=Vector(12,34,56)}
 function damage:GetAttacker() return surgeon end
 function damage:GetInflictor() return self.inflictor end
 function damage:GetDamage() return self.amount end
 function damage:GetDamagePosition() return self.position end
 function damage:IsDamageType(kind) return self.kind==kind end
 local A=ix.Amputation;rolls=0;wins=0;rolled=1
 math.random=function() rolls=rolls+1;return rolled end
 A.Amputate=function(_,key) wins=wins+1;return true end
 A.GiveRemains=function(_,key,ground) eq(ground,true) end
 function strike(group) hook.Run('ScalePlayerDamage',patient,group,damage);hook.Run('CharacterBodyDamaged',patient,damage,group) end
 `;
 suite('Melee amputation rolls exactly five of one hundred outcomes and only once per resolved limb hit',
 [...files,'ixhl2rp/plugins/amputation/sv_melee.lua'],meleeSetup+`
  for n=1,100 do rolled=n;strike(4);hook.Run('CharacterBodyDamaged',patient,damage,4) end
  eq(rolls,100);eq(wins,5)
  rolled=1;damage.kind=DMG_CLUB;strike(6);eq(wins,6)
  strike(1);strike(2);strike(0);eq(rolls,101)
  patient.char.data.amputation='rarm';strike(4);eq(rolls,101)
 `);
 suite('Melee chance excludes projectiles, fists, blocked/zero damage, stale hitgroups and unrelated impacts',
 [...files,'ixhl2rp/plugins/amputation/sv_melee.lua'],meleeSetup+`
  damage.amount=0;strike(4);damage.amount=20
  blade.AOC_Hands=true;strike(4);blade.AOC_Hands=nil
  blade.IsFists=true;strike(4);blade.IsFists=nil
  damage.kind=DMG_BULLET;strike(4);damage.kind=DMG_SLASH
  damage.inflictor={valid=true,IsWeapon=function() return false end};strike(4);damage.inflictor=blade
  blade.AOC_Melee=false;strike(4);blade.AOC_Melee=true
  hook.Run('CharacterBodyDamaged',patient,damage,4)
  hook.Run('ScalePlayerDamage',patient,4,damage);clock=clock+1;hook.Run('CharacterBodyDamaged',patient,damage,4)
  hook.Run('ScalePlayerDamage',patient,4,damage);hook.Run('CharacterBodyDamaged',patient,damage,5)
  hook.Run('ScalePlayerDamage',patient,4,damage);damage.position=Vector(1,2,3);hook.Run('CharacterBodyDamaged',patient,damage,4)
  eq(rolls,0);eq(wins,0)
 `);
 const combat=normalize(fs.readFileSync('ixhl2rp/plugins/!healthsystem/sv_combat.lua','utf8'));
 const combatHook=combat.slice(combat.indexOf('function PLUGIN:EntityTakeDamage('),combat.indexOf('\n\ndo\n',combat.indexOf('function PLUGIN:EntityTakeDamage(')));
 suite('Native health damage emits one resolved melee event after wounds and skips protected targets',
 [...files,'ixhl2rp/plugins/amputation/sv_melee.lua'],meleeSetup+`
  local hot_fix,mul_npc={},{}
  local wounds=0
  local function ApplyDamageToPart() wounds=wounds+1;return true end
  local function GetDamageClass() return 'slash' end
  local function SelectRandomPart() error('A resolved limb hit must not choose another limb') end
  DONT_BLEED=-1;DMG_CRUSH=1;DMG_POISON=16;DMG_BUCKSHOT=32;DMG_FALL=64;DMG_ACID=256
  DMG_SHOCK=512;DMG_DROWN=1024;DMG_BURN=2048;DMG_SLOWBURN=4096
  ix.Downed={BlockDamage=function() return protected end}
  function PLUGIN:GetMeleeDamageDef() end
  function patient:SetBloodColor() end;function patient:LastHitGroup() return 4 end
  function surgeon:EntIndex() return 1 end;surgeon.weapon=blade
  function damage:GetDamageType() return self.kind end;function damage:GetAmmoType() return -1 end
  function damage:SetDamage(n) self.amount=n end;function damage:IsExplosionDamage() return false end
  function blade:IsNPC() return false end
  function patient.health:GetConsciousness() return 1 end;function patient.health:GetPercent() return 1 end
  function patient.health:GetPartHealth() return 50 end
  A.Amputate=function(_,key) eq(wounds,1);eq(key,'larm');wins=wins+1;return true end
  ${combatHook}
  hook.Run('ScalePlayerDamage',patient,4,damage);PLUGIN:EntityTakeDamage(patient,damage)
  eq(wounds,1);eq(wins,1);eq(rolls,1)
  protected=true;hook.Run('ScalePlayerDamage',patient,4,damage);PLUGIN:EntityTakeDamage(patient,damage)
  eq(wounds,1);eq(wins,1);eq(rolls,1)
 `);
};
