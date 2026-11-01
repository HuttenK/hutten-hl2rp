// Optional integration checks against the user's unmodified external addon Lua.
// Usage: node tools/test-scp-addon-integration.cjs "E:\\SCP addons"
// The ordinary regression suite never depends on these third-party files.
const fs=require('fs'),path=require('path');
const {run,read,source,finish}=require('./restored-test-runner.cjs');
const {normalize}=require('./glua.cjs');
const addons=process.argv[2]||process.env.SCP_ADDONS;
if(!addons) throw Error('Supply the read-only SCP addon directory.');
const external=relative=>fs.readFileSync(path.join(addons,relative),'utf8').replace(/\r\n/g,'\n');
function functions(relative,names){
 const text=external(relative);
 return names.map(name=>{
  const first=text.indexOf('function ENT:'+name+'('),last=text.indexOf('\n------',first);
  if(first<0||last<0) throw Error('Addon function boundary missing: '+name);
  return normalize(text.slice(first,last));
 }).join('\n');
}
const compat='\n'+source(['ixhl2rp/plugins/scp_npc_compat/sh_plugin.lua','ixhl2rp/plugins/scp_npc_compat/sv_control.lua','ixhl2rp/plugins/scp_npc_compat/sv_compat.lua'])+'\n';
const base=read('tools/geometry-fixture.lua')+'\n'+read('tools/fixtures/scp-compat.lua')+`
 IN_WEAPON1=1048576;IN_WEAPON2=2097152;IN_SCORE=65536;MOVETYPE_FLY=4
 ACT_JUMP=1;ACT_GLIDE=2;ACT_LAND=3
 function table.Count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
 function table.Empty(t) for k in pairs(t) do t[k]=nil end end
 function table.HasValue(t,x) for _,v in pairs(t) do if v==x then return true end end return false end
 function Sound(s) return s end
 function p:GetForward() return self.angles:Forward() end
 function p:GetRight() return self.angles:Right() end
 function p:GetUp() return self.angles:Up() end
 function npc:GetCollisionBounds() return Vector(-15,-15,0),Vector(15,15,50) end
 function npc:CPT_GetCenter() return self:GetPos()+self:OBBCenter() end
 function npc:GetSequence() return 1 end
 function npc:GetSequenceGroundSpeed() return 120 end
 function npc:GetActivity() return 0 end
 function npc:GetMoveType() return 3 end
 function npc:IsValid() return self.valid end
 function npc:CPT_PlaySound(name) self.sound=name end
 npc.IsPlayingActivity=true;npc.CanMove=false
 ENT=npc
 `+normalize(external('CPTBase/lua/entities/npc_cpt_base/controller.lua'))+'\n';
const cb=name=>'SCP CB SNPCS/lua/entities/'+name+'/init.lua';
run('Actual CPT forward, strafe, sprint and idle movement still reach native navigation',base+compat+`
 npc.CanMove=true;npc.IsPlayingActivity=false
 function RunTrace() return {Hit=false} end
 function npc:OBBMins() return Vector(-15,-15,0) end
 function npc:GetMaxYawSpeed() return 180 end
 function npc:ApplyAngles(pos) self.facing=pos end
 function npc:GoToPosition(pos,mode) self.destination=pos;self.mode=mode end
 function npc:CPT_StopMovement() self.stopped=true end
 advance(0);assert(ix.SCPCompat.Start(npc,p))
 p.angles=Angle(0,0,0);p.keys={[IN_FORWARD]=true};npc:ControlMovement()
 near(npc.destination.x,npc.pos.x+120);eq(npc.mode,1)
 p.keys={[IN_MOVERIGHT]=true,[IN_SPEED]=true};npc:ControlMovement()
 near(npc.destination.y,npc.pos.y-120);eq(npc.mode,2)
 p.keys={};npc:ControlMovement();eq(npc.stopped,true)
 `);
run('Actual CPT controller dispatches attacks, voice/reload and release without consuming inventory',base+
 functions(cb('npc_cpt_scp_939_a'),['Possess_OnPossessed','Possess_Secondary','Possess_Reload'])+compat+`
 advance(0);npc.NextHearSoundT=0;local attacks=0
 function npc:DoAttack() attacks=attacks+1 end
 assert(ix.SCPCompat.Start(npc,p))
 p.keys[IN_ATTACK]=true;npc:ControlMovement();eq(attacks,1)
 p.keys={[IN_ATTACK2]=true};npc:ControlMovement();eq(npc.sound,'Idle')
 advance(6);p.keys={[IN_RELOAD]=true};npc:ControlMovement();eq(npc.sound,'Voice_Random')
 eq(p.weapons[1],oldWeapon);p.keys={[IN_USE]=true};npc:ControlMovement();eq(p.active,oldWeapon)
 `);
run('Actual Unity SCP-650 teleport receives a Vector even with a remembered enemy',base+
 functions('Unity SCP SNPCS/lua/entities/npc_cpt_scpunity_650/init.lua',['Possess_OnPossessed','Possess_Primary'])+compat+`
 npc.class='npc_cpt_scpunity_650';advance(0)
 function npc:SCP_CanBeSeen() return false end;function npc:SCP_CanBeSeen_NPC() return false end
 function npc:Teleport(pos) assert(isvector(pos));self.teleport=pos end
 assert(ix.SCPCompat.Start(npc,p));npc:SetEnemy(p);npc:SetPossessorAimPos(Vector(17,18,19))
 p.keys[IN_ATTACK]=true;npc:ControlMovement();eq(npc.teleport.x,17);eq(npc.teleport.z,19)
 `);
run('Legacy watched/rage movement lock stops locomotion without swallowing release or ability keys',base+compat+`
 advance(0);assert(ix.SCPCompat.Start(npc,p));local attacks=0
 function npc:DoAttack() attacks=attacks+1 end
 npc.ixCPTOriginalMovement=function() error('watched SCP must not move') end
 npc.Possessor_CanMove=false;p.keys={[IN_FORWARD]=true,[IN_ATTACK]=true};npc:ControlMovement();eq(attacks,1)
 npc.Possessor_CanMove=true;npc.ixCPTOriginalMovement=function(self) self.moved=true end
 npc:ControlMovement();eq(npc.moved,true)
 npc.Possessor_CanMove=false;p.keys={[IN_USE]=true};npc:ControlMovement();eq(p.active,oldWeapon)
 `);
run('Actual SCP-106 zoom ability and attack/reload keys are reached independently',base+
 functions(cb('npc_cpt_scp_106'),['Possess_Zoom'])+compat+`
 npc.class='npc_cpt_scp_106';npc.P_NextTeleportT=0;advance(0)
 local victim=newPlayer();allPlayers={p,victim};allEntities={npc}
 function npc:DoWallTeleport(target) self.wallTarget=target end
 function npc:Possess_Reload(owner) eq(owner,p);self.reload=true end
 assert(ix.SCPCompat.Start(npc,p));p.keys={[IN_ZOOM]=true,[IN_RELOAD]=true};npc:ControlMovement()
 eq(npc.wallTarget,victim);eq(npc.reload,true);eq(npc.P_NextTeleportT,clock+7)
 `);
const source079=functions(cb('npc_cpt_scp_079'),['Possess_CustomCommands','Possess_ActivatePrimary','Possess_LockDoors',
 'Possess_ReleaseDoors','Possess_CameraUp','Possess_CameraDown','Possess_OnPossessed','Possess_DoChat079',
 'Possess_OnStopPossessing','Possess_Think']);
run('Actual SCP-079 callbacks drive doors, cameras, HUD counters and cleanup after removal',base+source079+compat+`
 npc.class='npc_cpt_scp_079';npc.tbl_LockedDoors={};npc.AuxiliaryPower=100;npc.MaxAuxiliaryPower=100
 npc.Tier=1;npc.ExperiencePoints=0;npc.NextTierUnlock=20;npc.NextUseAbilityT=0
 local cameras={newNPC('ent_cpt_scp_camera'),newNPC('ent_cpt_scp_camera')}
 for _,camera in ipairs(cameras) do
  function camera:SetCameraOwner(owner) self.owner=owner end
  function camera:GetCameraOwner() return self.owner end
 end
 npc.tbl_Cameras=cameras;npc.CurrentCamera=cameras[1]
 function npc:GetCurrentCamera() return self.CurrentCamera end
 function npc:GetCurrentCameraID() return self.CurrentCamera==cameras[1] and 1 or 2 end
 function npc:SetCurrentCamera(camera) self.CurrentCamera=camera;camera:SetCameraOwner(self) end
 function npc:CanUseAux(value) return self.AuxiliaryPower>=value end
 function npc:RemoveAux(value,xp) self.AuxiliaryPower=self.AuxiliaryPower-value end
 npc.SetNWInt=npc.SetNW2Entity;npc.SetNWBool=npc.SetNW2Entity
 function p:ConCommand(cmd) eq(cmd,'cpt_scp_togglepcvision');self.pcvision=not self.pcvision end
 local door={valid=true,IsValid=function() return true end,GetClass=function() return 'func_door' end,
  Fire=function(self,cmd) self.action=cmd end,EmitSound=function() end}
 nearby={door};allEntities={npc,cameras[1],cameras[2]};advance(0)
 assert(ix.SCPCompat.Start(npc,p));eq(p.pcvision,true)
 p.keys={[IN_ATTACK]=true};npc:ControlMovement();eq(door.action,'Toggle');eq(npc.AuxiliaryPower,90)
 advance(2);p.keys={[IN_ATTACK2]=true};npc:ControlMovement();eq(door.action,'Lock');eq(#npc.tbl_LockedDoors,1)
 advance(2);p.keys={[IN_JUMP]=true};npc:ControlMovement();eq(door.action,'Unlock');eq(#npc.tbl_LockedDoors,0)
 local previous=npc:GetCurrentCamera();p.keys={[IN_SPEED]=true};npc:ControlMovement()
 assert(npc:GetCurrentCamera()~=previous);eq(npc.nw.CPTBase_SCP079_AuxCount,80)
 npc.valid=false;ix.SCPCompat.Tick();eq(p.pcvision,false);eq(p.active,oldWeapon)
 `);
finish();
