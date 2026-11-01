const fs = require('fs'), path = require('path');
const {normalize} = require('./glua.cjs');
module.exports = function(suite) {
 const read = p => fs.readFileSync(path.join(__dirname,'..',p),'utf8');
 const hud = read('tools/fixtures/arc9-upstream/cl_hud.lua').split('function SWEP:GetBinding')[0];
 const camera = read('tools/fixtures/arc9-upstream/cl_camera.lua').split('local mathapproach')[0];
 const hooks = read('helix/gamemode/core/hooks/cl_hooks.lua');
 const viewHelpers = hooks.slice(hooks.indexOf('local LOWERED_ANGLES'),hooks.indexOf('function GM:LoadIntro'));
 const view = 'function GM:CalcView(client,' + hooks.split('function GM:CalcView(client,')[1].split('local hookRun')[0];
 const setup = `
 CLIENT=true;SERVER=false;ix.gui={};ix.option={Get=function(k,d) return d end}
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 color_black=Color(0,0,0);draws=0;baseCalls=0;vmCalls=0
 function FrameTime() return 1/60 end;function Lerp(t,a,b) return a+(b-a)*t end
 function math.Approach(a,b,d) return a<b and math.min(a+d,b) or math.max(a-d,b) end
 function ScrW() return 1280 end;function ScrH() return 720 end
 function GetConVar(name) return {GetBool=function() return name=='arc9_cross_enable' or name=='arc9_crosshair_static' end,GetFloat=function() return 1 end} end
 function Material() return {} end
 surface={SetDrawColor=function() end,DrawRect=function() draws=draws+1 end,DrawOutlinedRect=function() end}
 ARC9={ScreenScale=function(n) return n end,ShouldThirdPerson=function() return false end}
 local vec={x=0,y=0,z=0};setmetatable(vec,{__add=function() return vec end,__mul=function() return vec end})
 function vec:ToScreen() return {x=640,y=360} end;function vec:DistToSqr() return 100 end
 local ang={p=0,y=0,r=0};setmetatable(ang,{__add=function() return ang end})
 function ang:Forward() return vec end;ang.Right=ang.Forward;ang.Up=ang.Forward
 function ang:RotateAroundAxis() end
 function Angle() return ang end;angle_zero=ang
 null={valid=false,IsValid=function() return false end}
 body={valid=false,IsValid=function(s) return s.valid end,IsRagdoll=function() return true end,
 LookupAttachment=function() return attachmentIndex or 1 end,GetAttachment=function() return {Pos=90,Ang=ang} end}
 function Entity() return body end
 p={valid=true,alive=true,vars={},ixWasWeaponRaised=false,ixRaisedFraction=0}
 function p:Alive() return self.alive end;function p:GetCharacter() return {} end
 function p:IsPlayer() return true end;function p:IsAdmin() return false end
 function p:GetLocalVar(k,d) if self.vars[k]~=nil then return self.vars[k] end return d end
 function p:GetActiveWeapon() return weapon end;function p:IsWepRaised() return false end
 function p:EyeAngles() return ang end;p.GetViewPunchAngles=p.EyeAngles
 function p:GetShootPos() return vec end;function p:GetVehicle() return null end
 function p:GetRagdollEntity() return body end;function p:ShouldDrawLocalPlayer() return false end
 local localPlayer=p;function LocalPlayer() return localPlayer end
 function setLocalPlayer(v) localPlayer=v end
 util.TraceLine=function() return {Entity=null,StartPos=vec,HitPos=vec} end
 SWEP={};GM={BaseClass={}}
 `;
 const weaponSetup = `
 weapon=setmetatable({valid=true,ARC9=true,owner=p,dt={LastRecoilTime=-100,SightAmount=0},SmoothedMagnification=1},{__index=SWEP})
 function weapon:GetOwner() return self.owner end
 function weapon:GetInspecting() return false end
 function weapon:GetProcessedValue(k) return k=='CrosshairHideDot' and false or 1 end
 function weapon:GetSightDelta() return 0 end
 function weapon:ShouldDrawCrosshair() return false end
 function weapon:GetSmoothedFOVMag() return 2 end
 function GM.BaseClass:CalcView(client,origin,angles,fov)
  baseCalls=baseCalls+1
  local a,b,c=weapon:CalcView(client,origin,angles,fov)
  return {origin=a or origin,angles=b or angles,fov=c or fov}
 end
 function GM.BaseClass:CalcViewModelView(w,vm,op,oa,pos,angles)
  vmCalls=vmCalls+1;assert(w:GetOwner()==p);return pos,angles
 end
 `;
 suite('Helix skips ARC9 crosshair callbacks until a live local player owns the weapon',
 ['helix/plugins/crosshair.lua'],`
 weapon.owner=null
 local ok,err=pcall(weapon.DoDrawCrosshair,weapon,640,360)
 eq(ok,false);assert(err:find('IsAdmin',1,true),'Reproduce reported upstream owner error')
 local attempts=0;local original=weapon.DoDrawCrosshair
 weapon.DoDrawCrosshair=function(...) attempts=attempts+1;return original(...) end
 for _,owner in ipairs({null,{valid=true,IsPlayer=function() return false end},
   {valid=true,IsPlayer=function() return true end}}) do
  weapon.owner=owner;PLUGIN:PostDrawHUD();eq(attempts,0)
 end
 weapon.owner=p;PLUGIN:PostDrawHUD();eq(attempts,1)
 p.vars.knocked=true;PLUGIN:PostDrawHUD();eq(attempts,1);p.vars.knocked=false
 body.valid=true;PLUGIN:PostDrawHUD();eq(attempts,1);body.valid=false
 g_ContextMenu={valid=true,IsVisible=function() return true end};PLUGIN:PostDrawHUD();eq(attempts,1)
 g_ContextMenu=nil;setLocalPlayer(null);PLUGIN:PostDrawHUD();eq(attempts,1);setLocalPlayer(p)
 weapon.owner=null;PLUGIN:PostDrawHUD();eq(attempts,1)
 weapon.owner=p;PLUGIN:PostDrawHUD();eq(attempts,2)
 -- Non-ARC9 SWEPs retain their own crosshair callback contract.
 weapon.ARC9=false;weapon.owner=null;weapon.DoDrawCrosshair=function() attempts=attempts+1 end
 PLUGIN:PostDrawHUD();eq(attempts,3)
 `,setup+normalize(hud)+weaponSetup);
 suite('Ragdoll camera precedes ARC9 callbacks; camera and viewmodel recover after ownership sync',[],`
 weapon.owner=null
 local ok,err=pcall(weapon.CalcView,weapon,p,10,Angle(),90)
 eq(ok,false);assert(err:find('ShouldDrawLocalPlayer',1,true))
 local model={SetAngles=function() end}
 for _,owner in ipairs({null,{valid=true,IsPlayer=function() return false end},
   {valid=true,IsPlayer=function() return true end}}) do
  weapon.owner=owner;local v=GM:CalcView(p,10,Angle(),90)
  eq(v.origin,10);eq(v.fov,90);eq(baseCalls,0)
  eq(GM:CalcViewModelView(weapon,model,10,Angle(),12,Angle()),12);eq(vmCalls,0)
 end
 body.valid=true;p.vars.ragdoll=1
 local v=GM:CalcView(p,10,Angle(),90);eq(v.origin,90);eq(baseCalls,0)
 attachmentIndex=0;v=GM:CalcView(p,10,Angle(),90);eq(v.origin,10);eq(baseCalls,0)
 p.alive=false;attachmentIndex=1;v=GM:CalcView(p,10,Angle(),90);eq(v.origin,90);eq(baseCalls,0)
 p.alive=true;body.valid=false;p.vars.ragdoll=0;weapon.owner=p
 v=GM:CalcView(p,10,Angle(),90);eq(v.origin,10);eq(v.fov,45);eq(baseCalls,1)
 eq(GM:CalcViewModelView(weapon,model,10,Angle(),12,Angle()),12);eq(vmCalls,1)
 `,setup+normalize(camera)+weaponSetup+normalize(viewHelpers+view));
};
