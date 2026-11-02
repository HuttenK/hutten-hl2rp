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
};
