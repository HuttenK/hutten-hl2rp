const fs=require('fs'),path=require('path');
module.exports=(suite)=>{
 suite('Sit request works without removed scanner or optional prone methods',
  ['ixhl2rp/plugins/sithelper/sv_plugin.lua'],`
   local v=setmetatable({}, {__add=function(a) return a end,__mul=function(a) return a end})
   function Vector() return v end
   function Angle(_,yaw) return {y=yaw,Forward=function() return v end} end
   math.NormalizeAngle=function(n) return n end
   net.ReadVector=function() return v end;net.ReadAngle=function() return {y=0} end
   net.ReadUInt=function() return 1 end;net.BytesLeft=function() return 0,0 end
   function PLUGIN:ResolvePose() return 41 end
   function PLUGIN:CanSit() return true end
   function PLUGIN:GetPoseOffset() return {x=0,z=0} end
   local p={GetCharacter=function() return {} end,GetNetVar=function() return nil end}
   function p:ForceSequence(seq) eq(seq,41);self.requested=true;return false end
   net.handlers.ixPlayerSit(0,p);eq(p.requested,true)
   clock=clock+3;p.requested=false;p.IsProne=function() return true end
   prone={Exit=function() p.exited=true end}
   net.handlers.ixPlayerSit(0,p);eq(p.exited,true);eq(p.requested,true)
  `);
 const prefix='ixhl2rp/plugins/aoc_compat/';
 const files=['sh_animations.lua','sh_weapons.lua'].map(f=>prefix+f);
 const src=files.map(f=>fs.readFileSync(path.join(__dirname,'..',f),'utf8')).join('\n')+fs.readFileSync(__filename,'utf8');
 const enums=[...new Set(src.match(/\b(?:ACT|GESTURE_SLOT|PLAYERANIMEVENT|MOVETYPE)_[A-Z0-9_]+\b/g))].map((n,i)=>`${n}=${i+100}`).join('\n');
 const setup=enums+`
 ACT_INVALID=-1;ix.AOC={revision=1}
 p={valid=true,model='sd.mdl',count=100,lookups=0,gestures={}}
 function p:IsPlayer() return true end
 function p:GetModel() return self.model end
 function p:GetSequenceCount() return self.count end
 function p:LookupSequence(name) self.lookups=self.lookups+1; if self.missing then return -1 end return self.model=='sd.mdl' and 42 or 73 end
 function p:SelectWeightedSequence() return 27 end
 function p:GetSequenceActivity(seq) return seq+2000 end
 function p:GetActiveWeapon() return self.weapon end
 function p:GetNetVar() return self.forced end
 function p:InVehicle() return self.vehicle end
 function p:IsProne() return self.prone end
 function p:GetMoveType() return 0 end
 function p:Crouching() return self.crouch end
 function p:SequenceDuration() return 0.5 end
 function p:AddVCDSequenceToGestureSlot(slot,seq,cycle,auto) self.gestures[#self.gestures+1]={seq=seq,slot=slot,auto=auto} end
 function p:AnimResetGestureSlot() end
 function weapon(class)
  local w={valid=true,AOC_Base=true,Primary={Ammo='arrows'},class=class,ActivityTranslate={},hold='sword'}
  function w:GetOwner() return p end
  function w:GetClass() return self.class end
  function w:GetHoldType() return self.hold end
  function w:SetWeaponHoldType(hold)
   self.ActivityTranslate[ACT_MP_STAND_IDLE]='wos_aoc_'..hold..'_idle'
   self.ActivityTranslate[ACT_MP_ATTACK_STAND_PRIMARYFIRE]='wos_aoc_'..hold..'_slash_01'
   self.ActivityTranslate[ACT_AOC_BLOCK_UP]='wos_aoc_block_up'
   self.ActivityTranslate[ACT_AOC_BLOCK_IDLE]='wos_aoc_block_idle'
  end
  function w:TranslateActivity(act) self.ActivityTranslate[act]=999;return 999 end
  function w:GetBlock() return self.block end
  p.weapon=w;return w
 end
 timer.jobs={}
 function timer.Remove(k) timer.jobs[k]=nil end
 function timer.Create(k,delay,reps,fn) timer.jobs[k]=fn end
 `;
 for(const client of [true,false]){
  suite(`AoC named animation mappings survive model changes and late wOS reload (${client?'client':'server'})`,files,`
   local A=ix.AOC;local w=weapon('aoc_sword');A.Prepare(w)
   eq(w:TranslateActivity(ACT_MP_STAND_IDLE),2042)
   eq(w.ActivityTranslate[ACT_MP_STAND_IDLE],'wos_aoc_sword_idle')
   local _,seq=A.MainActivity(p,ACT_MP_STAND_IDLE);eq(seq,42)
   for i=1,100 do A.MainActivity(p,ACT_MP_STAND_IDLE) end;eq(p.lookups,1)
   p.model='guard.mdl';local _,other=A.MainActivity(p,ACT_MP_STAND_IDLE);eq(other,73)
   eq(w:TranslateActivity(ACT_MP_STAND_IDLE),2073)
   p.forced=0;eq(A.MainActivity(p,ACT_MP_STAND_IDLE),nil);p.forced=nil
   p.prone=true;eq(A.MainActivity(p,ACT_MP_STAND_IDLE),nil);p.prone=false
   p.vehicle=true;eq(A.MainActivity(p,ACT_MP_STAND_IDLE),nil);p.vehicle=false
   w.hold='halberd';A.revision=A.revision+1;A.Prepare(w)
   eq(w.ActivityTranslate[ACT_MP_STAND_IDLE],'wos_aoc_halberd_idle')
   p.missing=true;A.revision=A.revision+1;eq(A.MainActivity(p,ACT_MP_STAND_IDLE),nil)
   eq(w:TranslateActivity(ACT_MP_STAND_IDLE),ACT_INVALID)
   p.missing=false;A.revision=A.revision+1;local _,restored=A.MainActivity(p,ACT_MP_STAND_IDLE);eq(restored,73)
  `,setup+`\nSERVER=${!client};CLIENT=${client}\n`);
 }
 suite('AoC swing and timed shield gestures use model-local sequences and cancel on weapon switch',files,`
  local A=ix.AOC;local w=weapon('aoc_sword_shield')
  eq(A.AnimationEvent(p,PLAYERANIMEVENT_CUSTOM_GESTURE,PLAYERANIMEVENT_ATTACK_PRIMARY),ACT_INVALID)
  eq(#p.gestures,1);eq(p.gestures[1].seq,42)
  w.block=true;A.AnimationEvent(p,PLAYERANIMEVENT_CUSTOM_GESTURE,PLAYERANIMEVENT_AOC_BLOCK_UP)
  local job;for _,fn in pairs(timer.jobs) do job=fn end;assert(job)
  job();eq(p.gestures[#p.gestures].auto,false)
  local n=#p.gestures;p.weapon=nil;job();eq(#p.gestures,n);p.weapon=w
  p.prone=true;job();eq(#p.gestures,n)
  eq(A.AnimationEvent(p,PLAYERANIMEVENT_CUSTOM_GESTURE,PLAYERANIMEVENT_ATTACK_PRIMARY),ACT_INVALID)
  eq(#p.gestures,n)
 `,setup+'\nSERVER=false CLIENT=true\n');

 for(const client of [true,false]){
  suite(`AoC walking uses a stationary grip without the running pelvis bounce (${client?'client':'server'})`,files,`
   local A=ix.AOC;local w=weapon('aoc_sword_shield');A.Prepare(w)
   local clips={walk_all=10,wos_aoc_run_swordshield=20,wos_aoc_run_swordshield_mod=21,
    wos_aoc_cwalk_swordshield=22,wos_aoc_sword_slash_01=23}
   p.ixAOCSequences=nil;p.layers={};p.starts=0;p.sequence=10;p.cycle=0.37
   function p:LookupSequence(name) return clips[name] or -1 end
   function p:SelectWeightedSequence() return -1 end
   function p:GetSequence() return self.sequence end
   function p:GetCycle() return self.cycle end
   function p:Alive() return not self.dead end
   function p:IsValidLayer(slot) return self.layers[slot]~=nil end
   function p:GetLayerSequence(slot) return self.layers[slot].seq end
   function p:GetLayerWeight(slot) return self.layers[slot].weight end
   function p:AnimResetGestureSlot(slot) self.layers[slot]=nil end
   function p:AnimSetGestureWeight(slot,weight) self.layers[slot].weight=weight end
   function p:SetLayerPlaybackRate(slot,rate) self.layers[slot].rate=rate end
   function p:SetLayerCycle(slot,cycle) self.layers[slot].cycle=cycle end
   function p:AddVCDSequenceToGestureSlot(slot,seq,cycle,auto)
    self.layers[slot]={seq=seq,weight=1,cycle=cycle,rate=1};self.starts=self.starts+1;self.startCycle=cycle
   end
   w.ActivityTranslate[ACT_MP_WALK]='wos_aoc_run_swordshield'
   w.ActivityTranslate[ACT_MP_RUN]='wos_aoc_run_swordshield'
   w.ActivityTranslate[ACT_MP_CROUCHWALK]='wos_aoc_cwalk_swordshield'
   p.layers[GESTURE_SLOT_GRENADE]={seq=0,weight=0,cycle=0,rate=1} -- an allocated but idle overlay is available
   local _,walk=A.MainActivity(p,ACT_MP_WALK);eq(walk,10)
   for i=1,100 do A.MainActivity(p,ACT_MP_WALK);A.UpdateWalkLayer(p) end
   eq(p.starts,1);eq(p:GetLayerSequence(GESTURE_SLOT_GRENADE),21)
   eq(p.startCycle,0) -- no running pelvis phase, even when entering mid-stride
   for _,phase in ipairs({0.38,0.39,0.65,0.98,0.02,0.12}) do
    p.cycle=phase;A.MainActivity(p,ACT_MP_WALK);A.UpdateWalkLayer(p)
    local layer=p.layers[GESTURE_SLOT_GRENADE]
    eq(layer.cycle,0);eq(layer.rate,0)
    layer.cycle=layer.cycle+layer.rate*0.05 -- time alone must not advance the grip
    eq(layer.cycle,0)
   end
   eq(p.starts,1) -- changing cadence and wrapping the step do not restart the layer
   local _,run=A.MainActivity(p,ACT_MP_RUN);eq(run,20);A.UpdateWalkLayer(p)
   eq(p:IsValidLayer(GESTURE_SLOT_GRENADE),false)
   local _,crouch=A.MainActivity(p,ACT_MP_CROUCHWALK);eq(crouch,22)
   A.MainActivity(p,ACT_MP_WALK);A.UpdateWalkLayer(p)
   p.layers[GESTURE_SLOT_ATTACK_AND_RELOAD]={seq=23,weight=1};A.UpdateWalkLayer(p)
   eq(p:IsValidLayer(GESTURE_SLOT_GRENADE),false) -- swings and looping shield blocks win
   p.cycle=0.71;p.layers[GESTURE_SLOT_ATTACK_AND_RELOAD]=nil;A.UpdateWalkLayer(p)
   assert(p:IsValidLayer(GESTURE_SLOT_GRENADE))
   eq(p.startCycle,0);eq(p.layers[GESTURE_SLOT_GRENADE].cycle,0)
   p.layers[GESTURE_SLOT_CUSTOM]={seq=23,weight=1};A.UpdateWalkLayer(p)
   eq(p:IsValidLayer(GESTURE_SLOT_GRENADE),false);p.layers[GESTURE_SLOT_CUSTOM]=nil
   p.ixAOCWalkActionWeapon=w;p.ixAOCWalkActionUntil=clock+1;A.UpdateWalkLayer(p)
   eq(p:IsValidLayer(GESTURE_SLOT_GRENADE),false)
   clock=clock+2;A.UpdateWalkLayer(p);assert(p:IsValidLayer(GESTURE_SLOT_GRENADE))
   p.ixAOCWalkActionWeapon={};p.ixAOCWalkActionUntil=clock+10;A.UpdateWalkLayer(p)
   assert(p:IsValidLayer(GESTURE_SLOT_GRENADE)) -- a previous weapon cannot suppress the new grip
   A.ClearWalkLayer(p)
   p.layers[GESTURE_SLOT_GRENADE]={seq=90,weight=1,rate=0.8,cycle=0.4};A.UpdateWalkLayer(p)
   eq(p:GetLayerSequence(GESTURE_SLOT_GRENADE),90) -- another plugin owns this slot
   eq(p.layers[GESTURE_SLOT_GRENADE].rate,0.8);eq(p.layers[GESTURE_SLOT_GRENADE].cycle,0.4)
   p.layers[GESTURE_SLOT_GRENADE]=nil;A.UpdateWalkLayer(p)
   for _,state in ipairs({'forced','prone','vehicle','dead'}) do
    p[state]=true;A.UpdateWalkLayer(p);eq(p:IsValidLayer(GESTURE_SLOT_GRENADE),false)
    p[state]=nil;A.UpdateWalkLayer(p)
   end
   p.sequence=20;A.UpdateWalkLayer(p);eq(p:IsValidLayer(GESTURE_SLOT_GRENADE),false)
   p.sequence=10;A.UpdateWalkLayer(p)
   p.model='other.mdl';A.UpdateWalkLayer(p);eq(p:IsValidLayer(GESTURE_SLOT_GRENADE),false)
   A.MainActivity(p,ACT_MP_WALK);A.UpdateWalkLayer(p);assert(p:IsValidLayer(GESTURE_SLOT_GRENADE))
   p.weapon=nil;A.UpdateWalkLayer(p);eq(p:IsValidLayer(GESTURE_SLOT_GRENADE),false);p.weapon=w
   A.MainActivity(p,ACT_MP_WALK);A.UpdateWalkLayer(p)
   A.revision=A.revision+1;A.UpdateWalkLayer(p);eq(p:IsValidLayer(GESTURE_SLOT_GRENADE),false)
   clips.walk_all=nil;p.ixAOCSequences=nil;w.ixAOCRevision=A.revision
   local _,fallback=A.MainActivity(p,ACT_MP_WALK);eq(fallback,20) -- no T-pose on incomplete models
   eq(p.ixAOCWalkBase,nil)
  `,setup+`\nSERVER=${!client};CLIENT=${client}\n`);
 }

 const itemSource=fs.readFileSync(path.join(__dirname,'../ixhl2rp/plugins/ammo_cringe/items/base/weapon.lua'),'utf8');
 const {normalize}=require('./glua.cjs');
 const methods='Item={}\n'+normalize(itemSource.slice(itemSource.indexOf('function Item:Equip('),itemSource.indexOf('\nif CLIENT then')));
 const integration=['tools/fixtures/medieval-weapons.lua','tools/fixtures/weapon-slots.lua',
  'ixhl2rp/plugins/ammo_cringe/sh_ammo.lua','ixhl2rp/plugins/ammo_cringe/sh_weapon_slots.lua',
  'ixhl2rp/plugins/ammo_cringe/sh_plugin.lua',...files];
 const actualSetup=methods+'\n'+enums+'\nix.AOC={revision=1}\n';
 const bow=`
  local W=ix.WeaponSlots;local item=ammoItem(3);p:AddItem(item)
  local a=newItem(1);a.class='aoc_longbow';assert(W.Equip(p,a,1));w=W.Live(p,a)
  w.AOC_Base=true;w.Primary={Ammo='XBowBolt'};w.ActivityTranslate={}
  function w:GetHoldType() return 'bow' end
  function w:GetLoaded() return self.loaded end
  function w:SetArrowed(b) self.arrowed=b end
  function w:Holster()
   if self:GetLoaded() then return false end
   if self:Clip1()>0 then p:SetAmmo(p:GetAmmoCount(0)+self:Clip1(),0);self:SetClip1(0) end
   return true
  end
  ix.AOC.Prepare(w)
 `;
 suite('AoC bow holster returns a loaded arrow as an inventory stack exactly once',integration,bow+`
  w.loaded=true;eq(w:Holster(),false);eq(w:Clip1(),1);eq(p:GetAmmoCount(0),3)
  w.loaded=false;assert(w:Holster());eq(w:Clip1(),0);eq(p:GetAmmoCount(0),4)
  assert(w:Holster());p:CalculateAmmo();eq(p:GetAmmoCount(0),4)
  W.Release(p,a);eq(a:GetData('ammo'),0);eq(p:GetAmmoCount(0),4)
 `,actualSetup);
 suite('AoC bow return keeps overflow on ground and retains its arrow on allocation failure',integration,bow+`
  p.full=true;assert(w:Holster());eq(#dropped,1);eq(dropped[1]:GetValue(),1);eq(p:GetAmmoCount(0),3)
  w:SetClip1(1);ix.Item.Instance=function() return nil end
  eq(w:Holster(),false);eq(w:Clip1(),1);eq(#dropped,1)
 `,actualSetup);
 suite('AoC last throw consumes its inventory charge and an empty weapon cannot throw or delete itself',integration,`
  local W=ix.WeaponSlots;local reserve=ammoItem(1);p:AddItem(reserve)
  local a=newItem(1);a.class='aoc_axe_thrown';a.weaponCategory='melee';a.data.ammo=-1
  assert(W.Equip(p,a,3));local w=W.Live(p,a)
  w.AOC_Base=true;w.Primary={Ammo='XBowBolt'};w.ActivityTranslate={}
  function w:GetHoldType() return 'axethrown' end
  function w:GetLoaded() return self.loaded end
  function w:GetNextDraw() return 0 end
  function w:CanPrimaryAttack() return true end
  function w:TakePrimaryAmmo(n) p:SetAmmo(p:GetAmmoCount(0)-n,0) end
  function w:Think() self:TakePrimaryAmmo(1);self.nextFire=clock+1 end
  ix.AOC.Prepare(w);assert(w:CanPrimaryAttack());w:Think()
  eq(p:GetAmmoCount(0),0);eq(inv:GetItems()[1],nil)
  clock=clock+2;w:Think();eq(w.valid,true);eq(w:CanPrimaryAttack(),false)
  p:CalculateAmmo();eq(p:GetAmmoCount(0),0)
  w.loaded=true;eq(W.Busy(w),true);w.loaded=false;w.block=true
  function w:GetBlock() return self.block end;eq(W.Busy(w),true)
 `,actualSetup);
 suite('Recovered AoC projectiles become inventory ammo without granting a second SWEP',integration.concat(prefix+'sv_pickups.lua'),`
  local entity={Touched=false}
  function entity:GetClass() return 'aoc_itemarrow' end
  function entity:Remove() self.removed=true end
  function p:InVehicle() return false end
  ix.Item.stored.arrow={ammo='arrows',max_stack=20}
  -- Reuse the fixture's one registered reserve type for this pickup check.
  local old=ix.weaponInventory.ReturnAmmo;ix.weaponInventory.ReturnAmmo=function(client,ammo,n)
   eq(ammo,'arrows');return old(client,'XBowBolt',n)
  end
  eq(PLUGIN:PlayerCanPickupItem(p,entity),false);eq(entity.removed,true)
  eq(#p.weapons,0);eq(p:GetAmmoCount(0),1)
  PLUGIN:PlayerCanPickupItem(p,entity);eq(p:GetAmmoCount(0),1)
 `,actualSetup);
};
