module.exports=suite=>{
 const files=['helix/plugins/stamina/sh_plugin.lua','ixhl2rp/plugins/!healthsystem/sh_combat.lua',
  'ixhl2rp/plugins/character_traits/sh_catalog.lua','ixhl2rp/plugins/character_traits/sh_weapons.lua',
  'ixhl2rp/plugins/character_traits/sh_plugin.lua','ixhl2rp/plugins/aoc_compat/sh_sounds.lua','ixhl2rp/plugins/aoc_compat/sh_stamina.lua',
  'ixhl2rp/plugins/aoc_compat/sh_weapons.lua'];
 const setup=`
 ix.AOC={revision=1};ix.meta.character={};ix.config.Add=function() end
 ix.Net={Type={}};function ix.Net:AddPlayerVar() end
 ix.char={RegisterVar=function() end};ix.type={};ix.transmit={};ix.lang={AddTable=function() end}
 MOVETYPE_NOCLIP=8;IN_SPEED=1
 AOC_ATTACK_SLASH=1;AOC_ATTACK_OVERHEAD=2;AOC_ATTACK_STAB=3
 PLAYERANIMEVENT_ATTACK_PRIMARY=101;PLAYERANIMEVENT_ATTACK_SECONDARY=102;PLAYERANIMEVENT_ATTACK_GRENADE=103
 ACT_VM_PRIMARYATTACK=201;ACT_VM_SECONDARYATTACK=202;ACT_VM_HITCENTER=203
 local character=setmetatable({traits={}}, {__index=ix.meta.character})
 function character:GetTraits() return self.traits end
 local meta=FindMetaTable('Player')
 p=setmetatable({valid=true,stm=100,vars={},writes=0,events={}}, {__index=meta})
 function p:GetCharacter() return not self.noCharacter and character or nil end
 function p:GetLocalVar(key,default) return key=='stm' and self.stm or default end
 function p:SetLocalVar(key,n) eq(key,'stm');self.stm=n;self.writes=self.writes+1 end
 function p:GetNetVar(key,default) if self.vars[key]==nil then return default end;return self.vars[key] end
 function p:SetNetVar(key,value) self.vars[key]=value end
 function p:IsPlayer() return not self.npc end
 function p:SteamID() return 'test' end
 function p:GetMoveType() return self.noclip and MOVETYPE_NOCLIP or 0 end
 function p:KeyDown() return self.running end
 function p:GetSprintMove() return true end
 function p:GetVelocity() return {LengthSqr=function() return self.moving and 1 or 0 end} end
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
  p.running=true;p.moving=true;job.fn();eq(p.stm,99)
  p:GetCharacter().traits={wheezing=true,clubfooted=true};p.stm=85;job.fn();near(p.stm,83.9)
  p.running=false;job.fn();eq(p.stm,85)
  p:GetCharacter().traits={};p.stm=0
  hook.Add('AdjustStaminaRegeneration','debuff',function() return 3 end)
  job.fn();eq(p.stm,3)
  hook.Add('AdjustStaminaOffset','debuff',function(_,n) return n*.5 end)
  job.fn();eq(p.stm,4.5)
  p.noclip=true;job.fn();eq(p.stm,4.5)
 `,setup);
 suite('Client predicts five-second recovery and swing refusals without spending stamina twice',files,`
  local w=newMelee();ix.AOC.Prepare(w)
  w:DoAttack(1);eq(p.stm,100);eq(p.writes,0);eq(w.attack,1);eq(p.cries,nil)
  clock=clock+3;p.stm=7;local count=#w.animations
  w:DoAttack(1);eq(#w.animations,count);eq(p.stm,7)
  PLUGIN.predictedStamina=0;p.stm=0
  for i=1,100 do clock=clock+FrameTime();PLUGIN:Think() end
  near(PLUGIN.predictedStamina,100);eq(p.writes,0)
  PLUGIN:OnLocalVarSet('stm',20);eq(PLUGIN.predictedStamina,20)
 `,setup+`SERVER=false;CLIENT=true`);
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
};
