const fs=require('fs'),runtime=require('./glua-runtime.cjs');
module.exports=suite=>{
 const src=fs.readFileSync('helix/gamemode/core/hooks/cl_hooks.lua','utf8');
 const hook=runtime(src.slice(src.indexOf('function GM:PlayerBindPress('),src.indexOf('function GM:CreateMove(')));
 suite('Wheel never opens or advances weapon selection; number keys and confirmation still select slots',
 ['helix/plugins/wepselect.lua'],`
  PLUGIN.index=2;PLUGIN.alpha=0
  for _,bind in ipairs({'invnext','invprev','INVNEXT'}) do
   eq(PLUGIN:PlayerBindPress(p,bind,true),nil) -- lets placement/tool plugins handle scrolling first
   eq(GM:PlayerBindPress(p,bind,true),true) -- blocks the native Source cycle if unused
   eq(PLUGIN.index,2);eq(PLUGIN.alpha,0);eq(picked,nil)
  end
  function PLUGIN:OnIndexChanged(w) self.alpha=1;self.highlighted=w end
  for slot=1,3 do
   eq(PLUGIN:PlayerBindPress(p,'slot'..slot,true),true);eq(PLUGIN.index,slot)
   eq(PLUGIN:PlayerBindPress(p,'+attack',true),true);eq(picked.ixWeaponSlot,slot);eq(PLUGIN.alpha,0)
  end
 `,`
 SERVER=false;CLIENT=true;GM={}
 function Vector() return {} end
 ix.gui={};p={valid=true,InVehicle=function() return false end,GetActiveWeapon=function() return nil end,
 EmitSound=function() end};function LocalPlayer() return p end
 ix.WeaponSlots={Choices=function() return {{ixWeaponSlot=1},{ixWeaponSlot=2},{ixWeaponSlot=3}} end,
 Select=function(w) picked=w end}
 `+hook);
 suite('Movement cannot resume sprint from stale state after a missed release edge', ['ixhl2rp/plugins/!healthsystem/sh_movement.lua'],`
  mv.buttons=IN_SPEED
  PLUGIN:SetupMove(p,mv,{});eq(p.sprint,true)
  clock=clock+3;PLUGIN:SetupMove(p,mv,{});assert(mv.max>65)
  mv.buttons=0 -- release was already processed elsewhere, so no KeyReleased event
  PLUGIN:SetupMove(p,mv,{});eq(p.sprint,false);eq(mv.max,65);eq(mv.clientMax,65)
  clock=clock+2;PLUGIN:SetupMove(p,mv,{});eq(p.sprint,false);eq(mv.clientMax,65)
  mv.buttons=IN_SPEED;p.exhausted=true;PLUGIN:SetupMove(p,mv,{});eq(p.sprint,false)
 `,`
  IN_SPEED=1;IN_JUMP=2;IN_DUCK=4;IN_MOVELEFT=8;IN_MOVERIGHT=16
  bit={band=function(a,b) return a & b end,bnot=function(a) return ~a end}
  function Lerp(f,a,b) return a+(b-a)*f end
  function Vector() return {Normalize=function() end} end
  ix.config.Get=function() return 65 end
  local char={Health=function() return {cachedMovement=1} end,GetID=function() return 1 end}
  p={speedCharID=1,runSpeed=180,GetCharacter=function() return char end,OnGround=function() return true end,
   GetLocalVar=function() end,GetStopModifier=function() return 1 end,IsProne=function() return false end,
   GetNetVar=function(self) return self.exhausted end,GetVelocity=function() return {Length2DSqr=function() return 5000 end} end}
  for method,key in pairs({SprintMove='sprint',SprintSpeed='speed',SpeedDeltaStart='startAt',SpeedDeltaEnd='endAt',RunFading='fading'}) do
   p['Get'..method]=function(self) return self[key] end
   p['Set'..method]=function(self,v) self[key]=v end
  end
  mv={max=65,clientMax=65,GetOldButtons=function() return 0 end,SetOldButtons=function() end,
   GetButtons=function(self) return self.buttons end,KeyDown=function(self,key) return (self.buttons & key)~=0 end,
   GetForwardSpeed=function() return 65 end,GetSideSpeed=function() return 0 end,
   KeyReleased=function() return false end,GetMaxSpeed=function(self) return self.max end,
   SetMaxSpeed=function(self,n) self.max=n end,GetMaxClientSpeed=function(self) return self.clientMax end,
   SetMaxClientSpeed=function(self,n) self.clientMax=n end}
 `);
};
