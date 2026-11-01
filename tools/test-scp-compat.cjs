module.exports=function(suite){
 const fs=require('fs'),path=require('path'),{normalize}=require('./glua.cjs');
 const read=f=>fs.readFileSync(path.join(__dirname,'..',f),'utf8');
 const setup=read('tools/geometry-fixture.lua')+'\n'+read('tools/fixtures/scp-compat.lua');
 const files=['ixhl2rp/plugins/scp_npc_compat/sh_plugin.lua','ixhl2rp/plugins/scp_npc_compat/sv_control.lua','ixhl2rp/plugins/scp_npc_compat/sv_compat.lua'];
 suite('CPT relations wait for Initialize and retain native factions unless explicitly overridden', ['ixhl2rp/plugins/npc_relations.lua'],`
  local calls=0;npc.MemoryTable=nil
  function npc:AddEntityRelationship() error('native engine relation must not bypass CPT memory') end
  function npc:SetRelationship(_,value) assert(self.MemoryTable);calls=calls+1;self.relation=value end
  PLUGIN:OnEntityCreated(npc);eq(calls,0);advance(0);eq(calls,0)
  npc.MemoryTable={};PLUGIN:OnEntityCreated(npc);advance(0);eq(calls,0)
  ix.faction.indices[1].npcRelations[npc.class]=D_LI
  PLUGIN:OnEntityCreated(npc);eq(calls,0);advance(0);eq(calls,1);eq(npc.relation,D_LI)
  p.character.GetFaction=function() return 9 end;PLUGIN:PlayerSpawn(p);advance(0);eq(calls,1)
  npc.valid=false;PLUGIN:OnEntityCreated(npc);advance(0);eq(calls,1)
 `,setup);
 suite('CPT possession exits without death, respawn, inventory loss or health/model changes',files,`
  advance(0);local C=ix.SCPCompat;eq(sent[1],'weapons/weapon_cpt_base/sh_anim.lua')
  local oldPos=p.pos;assert(npc:ControlNPC(true,p));eq(C.Controlled(p),npc)
  eq(p.active,NULL);eq(p.weapons[1],oldWeapon);eq(npc.entered,1);eq(p.IsPossessing,true)
  npc:ControlNPC(false);eq(C.Controlled(p),nil);eq(p.active,oldWeapon);eq(p.deployed,true)
  eq(p.pos,oldPos);eq(p.hp,73);eq(p.armor,21);eq(p.model,'citizen.mdl');eq(oldWeapon.clip,23)
  eq(oldWeapon.itemID,680);eq(oldWeapon.attachments.scope,true);eq(p.move,2);eq(p.god,false)
  eq(p.noDraw,false);eq(p.notSolid,false);eq(npc.exited,1);eq(C.sessions[p],nil)
  npc:ControlNPC(false);eq(npc.exited,1)
 `,setup);
 suite('CPT possession preserves observer state and rejects busy, injured, forbidden and hijacked controllers',files,`
  advance(0);local C=ix.SCPCompat
  p.vars.crit=true;eq(C.Start(npc,p),false);p.vars.crit=nil
  p.locals.ragdoll=42;eq(C.Start(npc,p),false);p.locals.ragdoll=nil
  p.nw.ixDraggedBody={valid=true};eq(C.Start(npc,p),false);p.nw.ixDraggedBody=nil
  p.restricted=true;eq(C.Start(npc,p),false);p.restricted=false
  npc.Possessor_CanBePossessed=false;eq(C.Start(npc,p),false);npc.Possessor_CanBePossessed=true
  veto='CanProperty';eq(C.Start(npc,p),false);veto=nil
  p.move=8;p.noDraw=true;p.notSolid=true;p.god=true;p.noTarget=true
  assert(C.Start(npc,p));eq(C.Start(npc,newPlayer()),false);eq(C.Start(npc,p),false)
  C.Stop(p);eq(p.move,8);eq(p.noDraw,true);eq(p.notSolid,true);eq(p.god,true);eq(p.noTarget,true)
 `,setup);
 suite('Possession reads actual solid flags and restores collision with unrelated flags present',files,`
  advance(0);local C=ix.SCPCompat
  eq(p.IsSolidFlagSet,nil) -- Not a Garry's Mod Entity method; do not invent it in fixtures.
  for _,initiallyNotSolid in ipairs({false,true}) do
   p.notSolid=initiallyNotSolid;p.solidFlags=2+8+16
   local flagsBefore=p:GetSolidFlags()
   assert(C.Start(npc,p));eq(p.notSolid,true)
   C.Stop(p);eq(p.notSolid,initiallyNotSolid);eq(p:GetSolidFlags(),flagsBefore)
   eq(p.active,oldWeapon)
  end
 `,setup);
 suite('CPT cleanup handles NPC removal, death, character changes, player disconnect and callback failure',files,`
  advance(0);local C=ix.SCPCompat
  assert(C.Start(npc,p));npc.valid=false;C.Tick();eq(C.sessions[p],nil);eq(p.active,oldWeapon)
  npc.valid=true;npc.controller=NULL;assert(C.Start(npc,p));npc.hp=0;C.Tick();eq(C.sessions[p],nil)
  npc.hp=200;assert(C.Start(npc,p));hook.Run('PrePlayerLoadedCharacter',p);eq(C.sessions[p],nil)
  assert(C.Start(npc,p));hook.Run('PlayerDisconnected',p);eq(C.sessions[p],nil);eq(npc.IsPossessed,false)
  p.move=2;p.active=oldWeapon
  npc.Possess_OnPossessed=function() error('callback failed') end
  eq(C.Start(npc,p),false);eq(C.sessions[p],nil);eq(p.noDraw,false);eq(p.god,false);eq(#errors,1)
 `,setup);
 suite('Missing CPT player freeze supports overlapping hits without changing other Freeze ownership',files,`
  advance(0);local C=ix.SCPCompat;p.frozen=true
  p:CPT_Freeze(true);advance(.1);p:CPT_Freeze(true);p:CPT_Freeze(false)
  assert(p:GetNW2Float('ixSCPStunUntil',0)>clock);eq(p.frozen,true)
  p:CPT_Freeze(false);eq(p:GetNW2Float('ixSCPStunUntil',0),0);eq(p.frozen,true)
  p:CPT_Freeze(true);advance(6);timer.created.ixSCPStuns();eq(p:GetNW2Float('ixSCPStunUntil',0),0)
  p:CPT_Freeze(2);hook.Run('PlayerSpawn',p);eq(p:GetNW2Float('ixSCPStunUntil',0),0)
 `,setup);
 suite('SCP-939 bite handles custom models without an eyes attachment and knockback uses Helix body',files,`
  advance(0);npc:OnHitEntity({p});eq(p.dsp,32);eq(particlePos.z,67)
  advance(.6);eq(p:GetNW2Float('ixSCPStunUntil',0),0)
  p:CPT_CreateRagdolledPlayer(Vector(1,2,3),npc);eq(p.knockdown[1],true);eq(p.knockdown[2],3)
  eq(p.legacyKnockdown,nil);p.knockdown=nil;p.vars.crit=true
  p:CPT_CreateRagdolledPlayer(Vector(),npc);eq(p.knockdown,nil)
 `,setup);
 suite('Controller aim packets reject other players, arbitrary entities and malformed coordinates',files,`
  advance(0);local C=ix.SCPCompat;assert(C.Start(npc,p));local initial=npc.aim
  net.entity=npc;net.aim=Vector(5,6,7);C.ReceiveAim(0,newPlayer());eq(npc.aim,initial)
  net.entity={valid=true};C.ReceiveAim(0,p);eq(npc.aim,initial)
  net.entity=npc;net.aim=Vector(0/0,1,2);C.ReceiveAim(0,p);eq(npc.aim,initial)
  net.aim=Vector(math.huge,1,2);C.ReceiveAim(0,p);eq(npc.aim,initial)
  net.aim=Vector(5,6,7);C.ReceiveAim(0,p);eq(npc.aim,net.aim)
  local accepted=npc.aim;net.aim=Vector(9,9,9);C.ReceiveAim(0,p);eq(npc.aim,accepted)
 `,setup);
 suite('CPT early relationship query is safe, and possessed legacy aim remains a Vector',files,`
  advance(0);local original=npc.ControlMovement;ix.SCPCompat.PatchEntity(npc);eq(npc.ControlMovement,original)
  npc.MemoryTable=nil;eq(npc:GetRelationship(p),D_NU);npc.MemoryTable={[D_LI]={[p]=true}}
  eq(npc:GetRelationship(p),D_LI);assert(ix.SCPCompat.Start(npc,p));npc.enemy=p
  assert(isvector(npc:Possess_AimTarget()));npc:ControlMovement();eq(npc.moves,1)
  p.keys[IN_USE]=true;npc:ControlMovement();eq(ix.SCPCompat.sessions[p],nil)
 `,setup);
 suite('SCP-079 keeps camera traces valid and safely releases control when all cameras disappear',files,`
  advance(0);npc.class='npc_cpt_scp_079';local camera=newNPC('ent_cpt_scp_camera')
  function camera:SetCameraOwner(v) self.owner=v end;function camera:GetCameraOwner() return self.owner end
  function npc:GetCurrentCamera() return self.CurrentCamera end
  function npc:SetCurrentCamera(v) self.CurrentCamera=v;v:SetCameraOwner(self) end
  npc.tbl_Cameras={camera};npc.CurrentCamera=camera;camera.owner=npc
  function npc:Possess_Think(owner) owner:SpectateEntity(self:GetCurrentCamera()) end
  function npc:Possess_CustomCommands() assert(isvector(camera.CameraHitPosition));self.custom=true end
  ix.SCPCompat.PatchEntity(npc);ix.SCPCompat.PatchEntity(camera)
  assert(ix.SCPCompat.Start(npc,p));npc:ControlMovement();eq(npc.custom,true);eq(p.observerTarget,camera)
  eq(npc:GetNW2Entity('ixSCPCamera'),camera);camera.valid=false;npc:ControlMovement()
  eq(ix.SCPCompat.sessions[p],nil);eq(p.active,oldWeapon)
 `,setup);
 const clientFiles=[...files,'ixhl2rp/plugins/scp_npc_compat/cl_control.lua'];
 const dispatchSource=read('helix/gamemode/core/libs/sh_plugin.lua');
 const first=dispatchSource.indexOf('hook.ixCall = hook.ixCall or hook.Call');
 const dispatcher=normalize(dispatchSource.slice(first,dispatchSource.indexOf('--- Runs the given hook',first)));
 suite('Verified possession camera and scroll run before Helix hooks; normal player hooks remain unchanged',clientFiles,`
  advance(0);local C=ix.SCPCompat;assert(C.Start(npc,p));CLIENT=true
  local HOOKS_CACHE={CalcView={human=function() error('human camera must not run') end}}
  hook.Call=function() return 'normal',7 end
  ${dispatcher}
  local view=hook.Call('CalcView',{},p,Vector(),Angle(),90)
  assert(isvector(view.origin));eq(view.drawviewmodel,false);eq(net.sentEntity,npc);eq(net.sends,1)
  eq(hook.Call('PlayerBindPress',{},p,'invnext',true),true);eq(p.CPTBase_Possessor_Zoom,105)
  local a,b=hook.Call('Unrelated',{});eq(a,'normal');eq(b,7)
  eq(hook.Call('PlayerNoClip',{},p,true),false)
  C.Stop(p);HOOKS_CACHE.CalcView=nil;a,b=hook.Call('CalcView',{},p);eq(a,'normal');eq(b,7)
 `,setup);
 suite('Possession movement keeps original attack/reload keys but locks the invisible human body',files,`
  advance(0);local C=ix.SCPCompat;assert(C.Start(npc,p))
  local command={ClearButtons=function() error('CPT needs original control keys') end}
  eq(C.OverrideHook('StartCommand',p,command),true)
  local move={SetOrigin=function(self,v) self.origin=v end,SetVelocity=function(self,v) self.velocity=v end,
   SetForwardSpeed=function(self,v) self.forward=v end,SetSideSpeed=function(self,v) self.side=v end,SetUpSpeed=function(self,v) self.up=v end}
  eq(C.OverrideHook('SetupMove',p,move),true);eq(move.origin.z,325);eq(move.forward,0);eq(move.velocity:Length(),0)
  eq(C.OverrideHook('SetupMove',newPlayer(),move),false)
 `,setup);
 suite('Possession protects the hidden character before Helix injuries but leaves NPC damage unchanged',files,`
  advance(0);local C=ix.SCPCompat;assert(C.Start(npc,p))
  local damage={value=50,SetDamage=function(self,v) self.value=v end}
  local handled,result=C.OverrideHook('EntityTakeDamage',p,damage)
  eq(handled,true);eq(result,true);eq(damage.value,0)
  handled,result=C.OverrideHook('PlayerShouldTakeDamage',p,npc);eq(handled,true);eq(result,false)
  handled,result=C.OverrideHook('PlayerSwitchWeapon',p,NULL,oldWeapon);eq(handled,true);eq(result,true)
  damage.value=50;eq(C.OverrideHook('EntityTakeDamage',npc,damage),false);eq(damage.value,50)
  C.Stop(p);eq(C.OverrideHook('EntityTakeDamage',p,damage),false)
 `,setup);
 suite('Removed SCP still runs its saved client-effect cleanup exactly once',files,`
  advance(0);local C=ix.SCPCompat;local exits=0
  npc.Possess_OnStopPossessing=function(_,owner) eq(owner,p);exits=exits+1 end
  assert(C.Start(npc,p));npc.valid=false;npc.Possess_OnStopPossessing=nil
  C.Tick();C.Tick();eq(exits,1);eq(p.active,oldWeapon)
 `,setup);
 suite('Reinstall after AutoRefresh retains the addon movement function instead of nesting wrappers',files,`
  advance(0);local C=ix.SCPCompat;local native=npc.ixCPTOriginalMovement
  local previous=C.ControlMovement
  C.ControlMovement=function(self) return previous(self) end
  C.Install();eq(npc.ixCPTOriginalMovement,native);eq(npc.ControlMovement,C.ControlMovement)
  assert(C.Start(npc,p));npc:ControlMovement();eq(npc.moves,1)
 `,setup);
};
