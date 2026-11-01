module.exports = function(suite) {
 const permissions=`
 CAMI={RegisterPrivilege=function() end,PlayerHasAccess=function() return false end}
 local char={GetID=function() return 7 end}
 p={valid=true,GetCharacter=function() return char end}
 body={valid=true,vars={ixCorpse=true},GetClass=function() return 'prop_ragdoll' end}
 function body:GetNetVar(k,d) if self.vars[k]~=nil then return self.vars[k] end return d end
 function p:GetEyeTrace() return {Entity=body} end
 `;
 for (const realm of [true,false]) suite('Corpse pickup respects persistence and keeps living ragdoll/prop ownership in '+(realm?'server':'client')+' realm',
 ['helix/plugins/propprotect.lua'],`
 eq(PLUGIN:PhysgunPickup(p,body),nil)
 if SERVER then eq(PLUGIN:OnPhysgunReload(nil,p),nil) end
 body.vars.ixCorpse=false; eq(PLUGIN:PhysgunPickup(p,body),false)
 body.vars.ixCorpse=true; body.vars.Persistent=true; eq(PLUGIN:PhysgunPickup(p,body),false)
 body.vars.Persistent=false; body.GetClass=function() return 'prop_physics' end
 eq(PLUGIN:PhysgunPickup(p,body),false)
 p.GetCharacter=function() return nil end; eq(PLUGIN:PhysgunPickup(p,body),false)
 `,permissions+'\nSERVER='+realm+'; CLIENT='+!realm);
 const setup = `
 ix.config.Add=function() end
 local config={persistentCorpses=true,corpseMax=8,corpseDecayTime=60}
 ix.config.Get=function(k,d) if config[k]~=nil then return config[k] end return d end
 COLLISION_GROUP_WEAPON=11
 timer.Exists=function() return false end
 ix.storage={Close=function() end}
 spawned=0; transferred=0
 function corpse()
  spawned=spawned+1
  local r={valid=true,id=spawned,callbacks={}}
  function r:EntIndex() return self.id end
  function r:SetNetVar(k,v) self[k]=v end
  function r:SetCollisionGroup(v) self.group=v end
  function r:SetNotSolid(v) self.notSolid=v end
  function r:RemoveCallOnRemove(k) self.callbacks[k]=nil end
  function r:CallOnRemove(k,fn) self.callbacks[k]=fn end
  function r:Remove() if not self.valid then return end; self.valid=false; for _,fn in pairs(self.callbacks) do fn(self) end end
  return r
 end
 client={valid=true,alive=false,vars={}}
 function client:Alive() return self.alive end
 function client:SetShouldServerRagdoll(v) self.engine=v end
 function client:SetLocalVar(k,v) self.vars[k]=v end
 function client:SteamID() return 'test' end
 function client:CreateServerRagdoll() return corpse() end
 hook.Run=function(k,...) if k=='OnPlayerCorpseCreated' then transferred=transferred+1 end end
 `;
 suite('Corpse death callbacks are idempotent, reuse downed bodies, and reset only on spawn',
 ['ixhl2rp/plugins/persistent_corpses.lua'], `
 local down=corpse(); client.ixRagdoll=down
 local fixer=0; down:CallOnRemove('fixer',function() fixer=fixer+1 end)
 PLUGIN:DoPlayerDeath(client); PLUGIN:DoPlayerDeath(client)
 eq(spawned,1); eq(transferred,1); eq(client.ixRagdoll,nil); eq(client.ixDeathCorpse,down)
 eq(down.group,11); eq(down.notSolid,false); eq(down.callbacks.fixer,nil)
 down:Remove(); PLUGIN:DoPlayerDeath(client); eq(spawned,1); eq(fixer,0)
 PLUGIN:PlayerSpawn(client); eq(client.engine,false)
 PLUGIN:DoPlayerDeath(client); eq(spawned,2); eq(transferred,2)
 `,setup);
 suite('Corpse cleanup respects limit under removal callbacks; old bodies cannot clear a newer death camera',
 ['ixhl2rp/plugins/persistent_corpses.lua'], `
 PLUGIN:DoPlayerDeath(client); local old=client.ixDeathCorpse
 PLUGIN:PlayerSpawn(client); PLUGIN:DoPlayerDeath(client); local current=client.ixDeathCorpse
 client.vars.ragdoll=current.id
 old:Remove(); eq(client.vars.ragdoll,current.id); eq(#PLUGIN.corpses,1)
 for i=1,5 do PLUGIN:PlayerSpawn(client); PLUGIN:DoPlayerDeath(client) end
 local newest=client.ixDeathCorpse
 table.insert(PLUGIN.corpses,{valid=false})
 PLUGIN:CleanupCorpses(2); eq(#PLUGIN.corpses,2); eq(newest.valid,true); eq(current.valid,false)
 PLUGIN:CleanupCorpses(0); eq(#PLUGIN.corpses,0); eq(newest.valid,false)
 `,setup);
 const collisionSetup=`
 AddCSLuaFile=function() end
 COLLISION_GROUP_WEAPON=11
 hooks={}; hook.Add=function(event,id,fn) hooks[event]=fn end
 hook.Remove=function(event) hooks[event]=nil end
 function body()
  return {valid=true,GetClass=function() return 'prop_ragdoll' end,IsPlayer=function() return false end,
   SetCustomCollisionCheck=function(self,v) self.custom=v end,SetNotSolid=function(self,v) self.notSolid=v end,
   SetCollisionGroup=function(self,v) self.group=v end}
 end
 `;
 suite('Bodies ignore players while staying physical; successful physgun pickup cancels animation without granting permissions',
 ['addons/death_animations/lua/autorun/sh_bd_ragdoll_collision.lua'], `
 local r=body(); hooks.OnEntityCreated(r); eq(r.group,11); eq(r.notSolid,false); eq(r.custom,false)
 local p={valid=true,GetClass=function() return 'player' end,IsPlayer=function() return true end}
 eq(hooks.ShouldCollide,nil); eq(hooks.PhysgunPickup,nil)
 local stopped=false; r.AnimModule={valid=true,Remove=function() stopped=true end}
 hooks.OnPhysgunPickup(p,r); eq(stopped,true); eq(r.BD_AnimationInterrupted,true)
 `,collisionSetup);
 suite('No-player ragdoll filtering is also present on the client',
 ['addons/death_animations/lua/autorun/sh_bd_ragdoll_collision.lua'], `
 local r=body(); hooks.OnEntityCreated(r); eq(r.custom,false); eq(r.group,nil)
 local p={valid=true,GetClass=function() return 'player' end,IsPlayer=function() return true end}
 eq(hooks.ShouldCollide,nil)
 `,collisionSetup+'\nSERVER=false; CLIENT=true');
 const animationSetup=`
 ENT={}; AddCSLuaFile=function() end; include=function() end
 SOLID_NONE=0; MOVETYPE_NONE=0; COLLISION_GROUP_IN_VEHICLE=10
 GetConVar=function() return {GetBool=function() return false end} end
 math.Rand=function(a,b) return (a+b)/2 end
 function driver(rag)
  local d=setmetatable({valid=true,Ragdoll=rag,cycles=0},{__index=ENT})
  function d:SetNoDraw(v) self.hidden=v end
  function d:SetSolid(v) self.solid=v end
  function d:SetNotSolid(v) self.notSolid=v end
  function d:SetMoveType(v) end
  function d:SetCollisionGroup(v) end
  function d:SetPlaybackRate(v) end
  function d:LookupBone(name) if name=='pelvis' then return 0 end end
  function d:GetCycle() return self.cycles end
  function d:Remove() self.valid=false; self:OnRemove() end
  return d
 end
 function target()
  local p={valid=true,motion=false,EnableMotion=function(self,v) self.motion=v end,Wake=function() end}
  local r={valid=true,physics=p,held=false}
  function r:GetPhysicsObjectCount() return 2 end
  function r:GetPhysicsObjectNum(i) return p end
  function r:TranslatePhysBoneToBone(i) return i end
  function r:GetBoneName(i) return i==0 and 'pelvis' or 'extra_workshop_bone' end
  function r:IsPlayerHolding() return self.held end
  return r
 end
 `;
 suite('Death controller skips extra bones, never creates invisible support props, and releases held bodies',
 ['addons/death_animations/lua/entities/hari_ragdoll_animation/init.lua'], `
 ents.Create=function() error('Controller must not spawn support props') end
 local r=target(); local d=driver(r); d:Initialize(); r.AnimModule=d
 eq(d.hidden,true); eq(d.solid,0); eq(#d.BonePairs,1); eq(d.BonePairs[1].bone,0); eq(r.physics.motion,true)
 r.held=true; d:Think(); eq(d.valid,false); eq(r.AnimModule,nil); eq(r.BD_AnimationInterrupted,true)
 `,animationSetup);
 suite('Server death controller runs active physics updates without client-only SetupBones',
 ['addons/death_animations/lua/entities/hari_ragdoll_animation/init.lua'], `
 local r=target(); local d=driver(r); d:Initialize(); r.AnimModule=d
 eq(d.SetupBones,nil)
 local destination=100; local orientation={}; local updates=0
 d.PoseOffset=0
 function d:GetBonePosition(bone)
  self.reads=(self.reads or 0)+1
  if self.reads==1 then return destination,orientation end
 end
 function r.physics:GetPos() return {} end
 function r.physics:ComputeShadowControl(data)
  updates=updates+1; eq(data.pos,destination); eq(data.angle,orientation)
 end
 util.TraceLine=function() return {Hit=false} end
 function d:NextThink(time) self.nextThink=time end
 clock=clock+0.05
 eq(d:Think(),true); eq(updates,1); eq(d.valid,true); eq(d.nextThink,clock)
 `,animationSetup);
 suite('Death animation anchors at physical pelvis once and fades control before completion',
 ['addons/death_animations/lua/entities/hari_ragdoll_animation/init.lua'], `
 -- Scalar positions represent vertical height for this root-offset regression.
 local r=target(); local d=driver(r); d:Initialize()
 d.Anchor={physics=r.physics,bone=0}
 function d:GetPos() return 40 end
 function d:GetBonePosition() return 80,{} end
 local actual=40
 function r.physics:GetPos() return actual end
 eq(d:AlignPose(),true); eq(d.PoseOffset,-40)
 actual=45; eq(d:AlignPose(),true); eq(d.PoseOffset,-40)
 util.TraceLine=function() return {Hit=false} end
 function d:NextThink() end
 function r.physics:ComputeShadowControl(data) self.control=data end
 d:Think(); eq(r.physics.control.pos,40); near(r.physics.control.maxspeed,80)
 d.cycles=d.CycleEnd-0.1; d:Think(); near(r.physics.control.maxspeed,40)
 local other=driver(target()); other:Initialize()
 function other:GetPos() return 40 end
 function other:GetBonePosition() return 40 end
 eq(other:AlignPose(),false); eq(other.PoseOffset,nil)
 `,animationSetup);
 suite('Death controller has bounded lifetime and safely releases removed bodies or unsupported rigs',
 ['addons/death_animations/lua/entities/hari_ragdoll_animation/init.lua'], `
 local r=target(); local d=driver(r); d:Initialize(); r.AnimModule=d
 clock=d.ExpiresAt+1; d:Think(); eq(d.valid,false); eq(r.AnimModule,nil)
 r=target(); d=driver(r); d:Initialize(); r.valid=false; d:Think(); eq(d.valid,false)
 r=target(); r.GetBoneName=function() return 'alien_bone' end
 d=driver(r); d:Initialize(); eq(d.valid,false); eq(r.physics.motion,false)
 `,animationSetup);
 suite('Helix disables stock death bodies; disabled player animations never remove players; delayed fallover validates ownership',
 ['addons/death_animations/lua/autorun/server/sv_sdohnahyi.lua'], `
 ix.char={}
 local p={valid=true,IsPlayer=function() return true end,SetShouldServerRagdoll=function(self,v) self.engine=v end,
 Remove=function() error('A player must never be removed') end,Alive=function() return true end}
 hooks.PlayerSpawn(p); eq(p.engine,false)
 cvars.bd_enable_players.value=0
 hooks.CreateEntityRagdoll(p,{valid=true}); eq(p.valid,true)
 cvars.bd_enable_players.value=1
 local rag={valid=true}; p.ixRagdoll=rag
 hooks.OnCharacterFallover(p,rag,true); p.ixRagdoll=nil; queued[1]()
 -- A stale fallover would reach ents.Create and fail the test.
 `,`
 hooks={}; queued={}; cvars={}
 hook.Add=function(event,id,fn) hooks[event]=fn end
 CreateConVar=function(name,v)
  local c={value=v}; function c:GetBool() return tonumber(self.value)~=0 end
  function c:GetFloat() return tonumber(self.value) end
  function c:GetString() return tostring(self.value) end
  cvars[name]=c; return c
 end
 RunConsoleCommand=function() end
 timer.Simple=function(_,fn) queued[#queued+1]=fn end
 ents.Create=function() error('Stale fallover attempted to animate') end
 `);
};
