module.exports=function(suite){
 const fs=require('fs'),path=require('path'),{normalize}=require('./glua.cjs');
 const read=file=>fs.readFileSync(path.join(__dirname,'..',file),'utf8');
 const files=['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua',
  'ixhl2rp/plugins/downed_state/cl_crawl.lua'];
 const setup=read('tools/geometry-fixture.lua')+`
 SERVER=false;CLIENT=true;MOVETYPE_WALK=2
 ix.Downed={};hooks={};hook.Add=function(_,id,fn) hooks[id]=fn end
 p={valid=true,alive=true,character={},vars={crit=true,criticalCrawlUntil=clock+25},locals={},scale=165/180,
  pos=Vector(10,20,30),move=MOVETYPE_WALK}
 function p:Alive() return self.alive end;function p:GetCharacter() return self.character end
 function p:InVehicle() return self.vehicle end
 function p:GetNetVar(k,d) if self.vars[k]~=nil then return self.vars[k] end return d end
 function p:GetLocalVar(k,d) if self.locals[k]~=nil then return self.locals[k] end return d end
 function p:GetModelScale() return self.scale end;function p:GetPos() return self.pos end
 function p:GetViewEntity() return self.viewEntity or self end
 function p:GetMoveType() return self.move end
 function p:CanOverrideView() return self.thirdperson end
 function LocalPlayer() return p end
 `;
 suite('Prone camera overrides a standing origin without movement prediction and scales with height',files,`
 local view={origin=Vector(10,20,94),angles=Angle(50,20,0),fov=90,zfar=9000,drawviewmodel=false}
 local look=Angle(20,75,0)
 for _,height in ipairs({155,165,180,190}) do
  p.scale=height/180
  local result=ix.Downed.ApplyCrawlView(view,p,view.origin,look,90)
  near(result.origin.z,30+18*height/180);eq(result.origin.x,10);eq(result.origin.y,20)
  eq(result.angles,look);eq(result.fov,90);eq(result.drawviewer,false);eq(result.znear,1)
  eq(result.zfar,9000);eq(result.drawviewmodel,false)
 end
 eq(view.origin.z,94);eq(view.znear,nil)
 eq(hooks.ixCriticalCrawlLegs(),true)
 p.vars.crit=nil;eq(ix.Downed.ApplyCrawlView(view,p,view.origin,look,90),view)
 eq(hooks.ixCriticalCrawlLegs(),nil)
 `,setup);
 suite('Crawl view preserves third-person, remote views, fall/ragdoll cameras and recovery',files,`
 local view={origin=Vector(0,0,64),fov=85};local look=Angle()
 local function unchanged() eq(ix.Downed.ApplyCrawlView(view,p,view.origin,look,85),view) end
 p.thirdperson=true;unchanged();p.thirdperson=false
 view.drawviewer=true;unchanged();view.drawviewer=nil
 view.ortho={};unchanged();view.ortho=nil
 p.viewEntity={valid=true};unchanged();p.viewEntity=nil
 p.move=8;unchanged();p.move=2
 p.vars.criticalFallUntil=clock+5;unchanged();eq(hooks.ixCriticalCrawlLegs(),nil);p.vars.criticalFallUntil=nil
 -- The fall flag can reach the client before the ragdoll-local-var clear.
 p.locals.ragdoll=42;unchanged();eq(ix.Downed.Crawling(p),false);p.locals.ragdoll=nil
 p.locals.knocked=true;unchanged();p.locals.knocked=false
 p.alive=false;unchanged();p.alive=true
 p.vehicle=true;unchanged();p.vehicle=false
 p.vars.crit=nil;p.vars.criticalCrawlUntil=nil;unchanged()
 `,setup);
 const dispatcher=read('helix/gamemode/core/libs/sh_plugin.lua');
 const start=dispatcher.indexOf('hook.ixCall = hook.ixCall or hook.Call');
 const dispatch=normalize(dispatcher.slice(start,dispatcher.indexOf('--- Runs the given hook',start)));
 suite('The final crawl view runs after plugin, schema and base cameras and before FOV without changing other hooks',files,`
 local HOOKS_CACHE={}
 local calls=0;ix.PlayerControls={ApplyViewFOV=function(view)
  calls=calls+1;near(view.origin.z,46.5);return view
 end}
 local original={origin=Vector(0,0,99),fov=80}
 hook.Call=function() return original,'base' end
 ${dispatch}
 local a,b=hook.Call('CalcView',{},p,original.origin,Angle(),80)
 near(a.origin.z,46.5);eq(b,'base');eq(calls,1);eq(original.origin.z,99)
 HOOKS_CACHE.CalcView={test=function() return original,'plugin' end}
 a,b=hook.Call('CalcView',{},p,original.origin,Angle(),80);eq(b,'plugin');eq(calls,2)
 HOOKS_CACHE.CalcView=nil;Schema={CalcView=function() return original,'schema' end}
 a,b=hook.Call('CalcView',{},p,original.origin,Angle(),80);eq(b,'schema');eq(calls,3)
 HOOKS_CACHE.Ordinary={test=function() return false,7 end}
 a,b=hook.Call('Ordinary',{});eq(a,false);eq(b,7);eq(calls,3)
 CLIENT=false;a,b=hook.Call('CalcView',{},p);eq(a,original);eq(calls,3)
 `,setup);
};
