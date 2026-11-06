module.exports=suite=>{
 const files=['helix/plugins/stamina/sh_plugin.lua','ixhl2rp/plugins/!healthsystem/sh_combat.lua',
  'ixhl2rp/plugins/character_traits/sh_catalog.lua','ixhl2rp/plugins/character_traits/sh_weapons.lua',
  'ixhl2rp/plugins/character_traits/sh_plugin.lua','ixhl2rp/plugins/aoc_compat/sh_sounds.lua','ixhl2rp/plugins/aoc_compat/sh_swing.lua','ixhl2rp/plugins/aoc_compat/sh_stamina.lua',
  'ixhl2rp/plugins/aoc_compat/sh_bow.lua','ixhl2rp/plugins/aoc_compat/sh_weapons.lua'];
 const setup=`
 ix.AOC={revision=1};ix.meta.character={};ix.config.Add=function() end
 ix.Net={Type={}};function ix.Net:AddPlayerVar() end
 ix.char={RegisterVar=function() end};ix.type={};ix.transmit={};ix.lang={AddTable=function() end}
 MOVETYPE_NOCLIP=8;IN_SPEED=1;IN_DUCK=2
 AOC_ATTACK_SLASH=1;AOC_ATTACK_OVERHEAD=2;AOC_ATTACK_STAB=3
 PLAYERANIMEVENT_ATTACK_PRIMARY=101;PLAYERANIMEVENT_ATTACK_SECONDARY=102;PLAYERANIMEVENT_ATTACK_GRENADE=103
 ACT_VM_PRIMARYATTACK=201;ACT_VM_SECONDARYATTACK=202;ACT_VM_HITCENTER=203
 local character=setmetatable({traits={}}, {__index=ix.meta.character})
 function character:GetTraits() return self.traits end
 function character:GetData(key,default) return self.data and self.data[key] or default end
 local meta=FindMetaTable('Player')
 p=setmetatable({valid=true,stm=100,vars={},locals={},writes=0,deadlineWrites=0,events={}}, {__index=meta})
 function p:GetCharacter() return not self.noCharacter and character or nil end
 function p:GetActiveWeapon() return self.weapon end
 function p:GetLocalVar(key,default)
  if key=='stm' then return self.stm end
  if self.locals[key]~=nil then return self.locals[key] end
  return default
 end
 function p:SetLocalVar(key,n)
  if key=='stm' then self.stm=n;self.writes=self.writes+1
  else eq(key,'stmRegenAt');self.locals[key]=n;self.deadlineWrites=self.deadlineWrites+1 end
 end
 function p:GetNetVar(key,default) if self.vars[key]==nil then return default end;return self.vars[key] end
 function p:SetNetVar(key,value) self.vars[key]=value end
 function p:IsPlayer() return not self.npc end
 function p:SteamID() return 'test' end
 function p:GetMoveType() return self.noclip and MOVETYPE_NOCLIP or 0 end
 function p:KeyDown(key) return (key==IN_SPEED and self.running) or (key==IN_DUCK and self.crouching) or false end
 function p:Crouching() return self.ducked end
 function p:GetSprintMove() return true end
 function p:GetVelocity()
  local length=function() return self.moving and 1 or 0 end
  return {LengthSqr=length,Length2DSqr=length}
 end
 function moveCommand() PLUGIN:StartCommand(p,{KeyDown=function(_,key) return p:KeyDown(key) end}) end
 function p:DoAnimationEvent(event) self.events[#self.events+1]=event end
 function p:GetPos() return 'attacker_position' end
 function p:EmitSound(...) self.cries=self.cries or {};self.cries[#self.cries+1]={...} end
 CHAN_VOICE=2
 function RecipientFilter()
  local filter={players={}}
  function filter:AddPAS(pos) self.pas=pos;self.players.nearby=true end
  function filter:AddPlayer(client) self.players[client]=true end
  return filter
 end
 function p:GetSuitPower() error('Helix swings must not depend on HEV') end
 function p:SetSuitPower() error('Helix swings must not spend HEV') end
 function p:AOC_SetNextStamina() error('Helix swings must not suspend HEV recovery') end
 local vm={valid=true,SetPlaybackRate=function(self,n) self.rate=n end}
 function p:GetViewModel() return vm end
 function LocalPlayer() return p end
 function FrameTime() return .05 end
 function math.Remap(n,a,b,c,d) return c+(n-a)/(b-a)*(d-c) end
 timer.jobs={}
 function timer.Create(id,interval,reps,fn) timer.jobs[id]={interval=interval,fn=fn} end
 function newMelee()
  local w={valid=true,AOC_Base=true,AOC_Melee=true,ActivityTranslate={},class='aoc_longsword',nextFire=0,
   Primary={Drain=8,Duration=1.3,Sound='slash',{Time=.3,Damage=30}},
   Secondary={Drain=13,Duration=1.8,Sound='overhead',{Time=.5,Damage=50}},
   Tertiary={Drain=20,Duration=2,Sound='stab',{Time=.4,Damage=40}},fallbacks=0,animations={}}
  function w:GetOwner() return p end
  function w:GetClass() return self.class end
  function w:GetHoldType() return 'sword' end
  function w:CanPrimaryAttack() return not self.block and clock>=self.nextFire end
  function w:DoAttack() self.fallbacks=self.fallbacks+1 end
  function w:EmitSound(s) self.sound=s end
  function w:EmitPredictedSound(s) self.denied=s end
  function w:SendWeaponAnim(a) self.animations[#self.animations+1]=a end
  function w:SequenceDuration() return 2 end
  for method,key in pairs({SetNextPrimaryFire='nextFire',SetNextSecondaryFire='nextSecondary',SetNextBlock='nextBlock',
   SetCurrentAttack='attack',SetSliceTime='sliceTime',SetCurrentSlice='slice',SetNextHolster='holsterAt',SetNextIdle='idleAt'}) do
   w[method]=function(self,value) self[key]=value end
  end
  return w
 end
 `;
 suite('AoC swings spend Helix stamina once, including misses, and reject blocked/cooldown/invalid/exhausted attempts',files,`
  local w=newMelee();ix.AOC.Prepare(w);local attack=w.DoAttack
  ix.AOC.Prepare(w);eq(w.DoAttack,attack)
  for kind,cost in ipairs({8,13,20}) do
   clock=clock+3;local before,writes=p.stm,p.writes
   w:DoAttack(kind)
   eq(p.stm,before-cost);eq(p.writes,writes+1);eq(w.attack,kind);eq(w.slice,1);eq(w.sliceTime,clock)
   eq(w.animations[#w.animations],200+kind);eq(p.events[#p.events],100+kind)
   eq(w.idleAt,clock+2);eq(w.fallbacks,0);eq(#p.cries,kind)
   near(p:GetLocalVar('stmRegenAt'),clock+6)
   w:DoAttack(kind);eq(p.writes,writes+1) -- held fire/cooldown cannot charge again
  end
  clock=clock+3;local before=p.stm
  w:DoAttack(999);eq(p.stm,before)
  w.block=true;w:DoAttack(1);eq(p.stm,before);w.block=false
  p.stm=20;w:DoAttack(3);eq(p.stm,0);eq(p:GetNetVar('brth'),true)
  clock=clock+3;local count=#w.animations;local writes=p.writes
  w:DoAttack(1);eq(#w.animations,count);eq(p.writes,writes);eq(w.denied,'HL2Player.UseDeny');near(w.nextFire,clock+.25)
  -- NPCs and non-character owners use their original addon entry point.
  clock=clock+1;p.npc=true;w:DoAttack(1);eq(w.fallbacks,1);eq(p.writes,writes)
  p.npc=false;p.noCharacter=true;w:DoAttack(1);eq(w.fallbacks,2);eq(p.writes,writes)
  eq(#p.cries,4) -- three normal swings and the last swing that emptied stamina
 `,setup);
 suite('Strong retains timing bonuses with the same swing cost; Weak cannot bypass strength restrictions',files,`
  local char=p:GetCharacter();local w=newMelee();ix.AOC.Prepare(w)
  char.traits={strong=true};w:DoAttack(1);eq(p.stm,92)
  near(w.Primary.Duration,1.3/1.08);near(w.Primary[1].Time,.3/1.08)
  near(w.idleAt,clock+2/1.08);near(p:GetViewModel().rate,1.08)
  near(p:GetLocalVar('stmRegenAt'),clock+2/1.08+4)
  eq(w.Primary.Drain,8);eq(w.Primary[1].Damage,30)
  clock=clock+3;w:DoAttack(1);eq(p.stm,84);near(w.Primary.Duration,1.3/1.08)
  char.traits={weak=true};clock=clock+3;local count=#w.animations
  w:DoAttack(1);eq(#w.animations,count);eq(p.stm,84)
  char.traits={};w:DoAttack(1);eq(p.stm,76);eq(w.Primary.Duration,1.3);eq(p:GetViewModel().rate,1)
 `,setup);
 suite('Helix server stamina refills 100 in five seconds and preserves exhaustion, perk caps, sprint costs and regeneration hooks',files,`
  hook.Add('CharacterMaxStamina','traits',function(char) return PLUGIN:CharacterMaxStamina(char) end)
  hook.Add('AdjustStaminaOffsetRunning','traits',function(client,offset) return PLUGIN:AdjustStaminaOffsetRunning(client,offset) end)
  PLUGIN:PostPlayerLoadout(p);local job=timer.jobs.ixStamtest;eq(job.interval,.25)
  p.stm=0;p.vars.brth=true
  for i=1,19 do clock=clock+job.interval;job.fn();eq(p.stm,i*5) end
  eq(p.vars.brth,nil);clock=clock+.25;job.fn();eq(p.stm,100)
  job.fn();eq(p.stm,100)
  p.running=true;p.moving=true;moveCommand();job.fn();eq(p.stm,99)
  p:GetCharacter().traits={wheezing=true,clubfooted=true};p.stm=85;job.fn();near(p.stm,83.9)
  p.running=false;moveCommand();job.fn();near(p.stm,83.9)
  clock=clock+4;job.fn();eq(p.stm,85)
  p:GetCharacter().traits={};p.stm=0
  hook.Add('AdjustStaminaRegeneration','debuff',function() return 3 end)
  job.fn();eq(p.stm,3)
  hook.Add('AdjustStaminaOffset','debuff',function(_,n) return n*.5 end)
  job.fn();eq(p.stm,4.5)
  p.noclip=true;job.fn();eq(p.stm,4.5)
 `,setup);
 suite('Client waits after the swing, respects server deadlines and predicts recovery without spending stamina twice',files,`
  local w=newMelee();ix.AOC.Prepare(w)
  local started=clock
  w:DoAttack(1);eq(p.stm,100);eq(p.writes,0);eq(w.attack,1);eq(p.cries,nil)
  clock=clock+3;p.stm=7;local count=#w.animations
  w:DoAttack(1);eq(#w.animations,count);eq(p.stm,7)
  PLUGIN.predictedStamina=0;p.stm=0
  clock=started+5.99;PLUGIN:Think();eq(PLUGIN.predictedStamina,0)
  clock=started+6
  for i=1,100 do clock=clock+FrameTime();PLUGIN:Think() end
  near(PLUGIN.predictedStamina,100);eq(p.writes,0)
  PLUGIN:OnLocalVarSet('stm',20);eq(PLUGIN.predictedStamina,20)
  p.locals.stmRegenAt=clock+5;PLUGIN:Think();eq(PLUGIN.predictedStamina,20)
  clock=clock+5;PLUGIN:Think();eq(PLUGIN.predictedStamina,21)
  -- A character change clears the previous local prediction along with the server deadline.
  p.ixStaminaRegenAt=clock+100;p.ixStaminaExerting=true;p.locals.stmRegenAt=0
  PLUGIN:OnLocalVarSet('stmRegenAt',0)
  PLUGIN:Think();eq(PLUGIN.predictedStamina,22);eq(p.ixStaminaExerting,nil)
 `,setup+`SERVER=false;CLIENT=true`);
 suite('Repeated swings deplete the pool; changing weapons and regeneration bonuses cannot bypass four seconds of rest',files,`
  PLUGIN:PostPlayerLoadout(p);local tick=timer.jobs.ixStamtest.fn
  local w=newMelee();ix.AOC.Prepare(w)
  for swing=1,5 do
   w:DoAttack(3);eq(p.stm,100-swing*20)
   for step=1,12 do clock=clock+.25;tick();eq(p.stm,100-swing*20) end
  end
  local deadline=p:GetLocalVar('stmRegenAt');eq(p:GetNetVar('brth'),true)
  local other=newMelee();ix.AOC.Prepare(other);other:DoAttack(1)
  eq(p:GetLocalVar('stmRegenAt'),deadline);eq(p.stm,0)
  hook.Add('AdjustStaminaOffset','bonus',function(_,offset) return offset+10 end)
  clock=deadline-.01;tick();eq(p.stm,0)
  hook.Remove('AdjustStaminaOffset','bonus')
  clock=deadline;tick();eq(p.stm,5)
  for i=1,19 do clock=clock+.25;tick() end
  eq(p.stm,100);eq(p:GetNetVar('brth'),nil)
 `,setup);
 suite('Sprint and crouch block recovery even while exhausted; walking and sparse deadline messages preserve rest',files,`
  PLUGIN:PostPlayerLoadout(p);local tick=timer.jobs.ixStamtest.fn
  p.stm=0;p.vars.brth=true;p.running=true;p.moving=true
  for i=1,40 do moveCommand();clock=clock+.25;tick();eq(p.stm,0) end
  eq(p.deadlineWrites,0) -- no per-command or per-tick network writes during a long sprint
  p.running=false;moveCommand();eq(p.deadlineWrites,1)
  -- Ordinary walking can continue throughout the rest period.
  for i=1,15 do clock=clock+.25;moveCommand();tick();eq(p.stm,0) end
  eq(p.deadlineWrites,1)
  clock=clock+.25;moveCommand();tick();eq(p.stm,5)
  p.moving=false;p.crouching=true
  for i=1,24 do moveCommand();clock=clock+.25;tick();eq(p.stm,5) end
  p.crouching=false;p.ducked=true;moveCommand() -- still physically crouching after releasing CTRL
  eq(p.deadlineWrites,1)
  p.ducked=false;moveCommand();eq(p.deadlineWrites,2)
  clock=clock+3.9;tick();eq(p.stm,5)
  clock=clock+.11;tick();eq(p.stm,10)
  -- A tap shorter than the stamina tick also restarts the cooldown.
  p.crouching=true;moveCommand();clock=clock+.01;p.crouching=false;moveCommand()
  tick();eq(p.stm,10);clock=clock+3.99;tick();eq(p.stm,10)
  clock=clock+.02;tick();eq(p.stm,15)
 `,setup);
 suite('Other stamina costs also delay natural recovery, without blocking explicit restoration or leaking into a new character',files,`
  PLUGIN:PostPlayerLoadout(p);local tick=timer.jobs.ixStamtest.fn
  p:ConsumeStamina(20);tick();eq(p.stm,80)
  p:RestoreStamina(5);eq(p.stm,85);tick();eq(p.stm,85)
  clock=clock+3.99;tick();eq(p.stm,85)
  clock=clock+.02;tick();eq(p.stm,90)
  p:ConsumeStamina(10);p.ixStaminaExerting=true
  p:GetCharacter().data={stamina=50}
  PLUGIN:PlayerLoadedCharacter(p,p:GetCharacter())
  eq(p:GetLocalVar('stmRegenAt'),0);eq(p.ixStaminaExerting,nil)
  tick();eq(p.stm,55)
  local writes=p.deadlineWrites;p.noclip=true;p.crouching=true;moveCommand()
  eq(p.deadlineWrites,writes);eq(p.ixStaminaExerting,nil)
  p.noclip=false;p.noCharacter=true;moveCommand();eq(p.ixStaminaExerting,nil)
 `,setup);
 suite('Longbow draw drains 15 per second until shot, cancellation or exhaustion, retaining an unspent arrow',files,`
  IN_ATTACK=16;local held=true;local keys=p.KeyDown
  function p:KeyDown(key) if key==IN_ATTACK then return held end;return keys(self,key) end
  local w={valid=true,StaminaDrain=15,clip=1}
  p.weapon=w
  function w:GetOwner() return p end;function w:GetLoaded() return self.loaded end
  function w:Clip1() return self.clip end;function w:Ammo1() return 0 end
  function w:PrimaryAttack() if self.clip>0 then self.loaded=true;self.shootAt=clock+1 end end
  function w:SecondaryAttack() self.loaded=false;self.shootAt=0 end
  function w:Think() assert(not self.loaded,'native HEV branch ran') end
  function w:GetShootTime() return self.shootAt end;function w:SetShootTime(t) self.shootAt=t end
  function w:SetLoaded(b) self.loaded=b end;function w:SequenceDuration() return 1 end
  function w:SetNextIdle() end;function w:SetNextPrimaryFire(t) self.nextFire=t end
  function w:SendWeaponAnim() end;function w:EmitSound() end
  function w:TakePrimaryAmmo(n) self.clip=self.clip-n end
  local V={Angle=function() return 0 end};V.__index=V;V.__mul=function(a) return a end;V.__add=V.__mul
  vector_up=setmetatable({},V);function p:GetAimVector() return vector_up end;function p:GetShootPos() return vector_up end
  function Angle() return 0 end;function p:ViewPunch() end;function p:DoAttackEvent() end;function p:AOC_SetNextStamina() end
  local arrows=0;ents={Create=function(id) eq(id,'aoc_firedarrow');arrows=arrows+1
   local arrow={valid=true,GetPhysicsObject=function() return nil end};return setmetatable(arrow,{__index=function() return function() end end}) end}
  ix.AOC.PrepareBow(w);ix.AOC.PrepareBow(w)
  PLUGIN:PostPlayerLoadout(p);local tick=timer.jobs.ixStamtest.fn
  local function steps(n) for i=1,n do clock=clock+.25;moveCommand();tick();w:Think() end end
  w:PrimaryAttack();steps(4);eq(p.stm,85);eq(arrows,0)
  w:SecondaryAttack();moveCommand();steps(15);eq(p.stm,85);eq(w.clip,1)
  steps(1);eq(p.stm,90)
  p.stm=7.5;w:PrimaryAttack();steps(2);eq(p.stm,0);eq(w.loaded,false);eq(w.clip,1);eq(arrows,0)
  w:PrimaryAttack();eq(w.loaded,false)
  p.stm=100;w:PrimaryAttack();steps(1);held=false;steps(2);eq(arrows,0)
  steps(1);eq(arrows,1);eq(w.clip,0);eq(w.loaded,false);eq(p.stm,85)
  steps(1);eq(arrows,1);eq(p.stm,85)
  w.clip=1;held=true;w:PrimaryAttack();steps(1);local before=p.stm
  p.weapon=nil;moveCommand();tick();eq(p.stm,before) -- removed/switched bow
 `,setup);
 suite('Attack cries randomly select all four clips and reach the attacker plus nearby listeners on one voice channel',files,`
  local w=newMelee();ix.AOC.Prepare(w)
  local chosen,rolls=1,0
  math.random=function(low,high) eq(low,1);eq(high,4);rolls=rolls+1;return chosen end
  for i=1,4 do
   chosen=i;clock=clock+3;w:DoAttack(1)
   local sound=p.cries[i]
   eq(sound[1],'medieval/combat/scream_'..i..'.wav');eq(sound[2],80);eq(sound[3],100);near(sound[4],.85)
   eq(sound[5],CHAN_VOICE);eq(sound[6],0);eq(sound[7],0)
   eq(sound[8].pas,p:GetPos());eq(sound[8].players[p],true);eq(sound[8].players.nearby,true)
   w:DoAttack(1);eq(#p.cries,i) -- immediate second input/cooldown is silent
  end
  clock=clock+3;p.stm=0;w:DoAttack(1);eq(#p.cries,4);eq(rolls,4)
 `,setup);
 suite('All attack cry assets are registered for client download',[
  'ixhl2rp/plugins/aoc_compat/sh_sounds.lua'],`
  eq(#downloads,4)
  for i=1,4 do eq(downloads[i],'sound/medieval/combat/scream_'..i..'.wav') end
 `,`ix.AOC={};downloads={};resource.AddFile=function(path) downloads[#downloads+1]=path end`);
 suite('A late melee tick sweeps every due direction, confirms the crosshair once and stops at the first contact',files,`
  local w=newMelee()
  local a,b,c={p=0,y=-25},{p=2,y=-1},{p=0,y=15}
  angle_zero={p=0,y=0}
  w.Primary={{Angle=a,Start=0,End=60,Time=.40},{Angle=a,Start=0,End=60,Time=.41},
   {Angle=b,Start=2,End=64,Time=.42},{Angle=c,Start=0,End=70,Time=.43},Range=70}
  function w:GetSliceTime() return self.sliceTime end
  function w:GetCurrentSlice() return self.slice end
  function w:GetCurrentAttack() return self.attack end
  function w:Think()
   self.nativeTicks=(self.nativeTicks or 0)+1
   if self.sliceTime>0 and clock-self.sliceTime>=self.Primary[self.slice].Time then error('overdue contact left for native Think') end
  end
  function w:Slice(_,_,s)
   self.rays[#self.rays+1]=s.Angle
   if s.Angle==angle_zero then eq(s.Start,0);eq(s.End,70) end
   return s.Angle==self.contact
  end
  ix.AOC.Prepare(w);ix.AOC.Prepare(w)
  local function start(contact) w.rays={};w.contact=contact;w.sliceTime=clock;w.attack=1;w.slice=1 end
  start(angle_zero);clock=clock+.39;w:Think();eq(#w.rays,0)
  clock=clock+.08;w:Think();eq(#w.rays,3);eq(w.rays[1],a);eq(w.rays[2],b);eq(w.rays[3],angle_zero)
  eq(w.sliceTime,0);w:Think();eq(#w.rays,3)
  start(a);clock=clock+.8;w:Think();eq(#w.rays,1);eq(w.slice,0) -- wall/block consumes the swing
  start(nil);clock=clock+.8;w:Think();eq(#w.rays,4);eq(w.rays[4],c);eq(w.slice,0)
  start(c);clock=clock+.405;w:Think();eq(w.slice,2)
  clock=clock+.4;w:Think();eq(w.rays[#w.rays],c);eq(w.slice,0)
 `,setup);
};
