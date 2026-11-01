module.exports=function(suite){
 const fs=require('fs'),path=require('path');
 const read=f=>fs.readFileSync(path.join(__dirname,'..',f),'utf8');
 const setup=['sharedposes','pose-gizmo','body-drag'].map(f=>read('tools/fixtures/'+f+'.lua')).join('\n')+`
 SERVER=false;CLIENT=true
 CreateClientConVar=function() return {GetBool=function() return true end} end
 function LocalPlayer() return carrier end
 function carrier:GetModel() return 'SD model' end
 carrier:SetNW2Entity('ixDraggedBody',body);body:SetNW2Int('ixDragBone',0)
 `;
 const files=['ixhl2rp/plugins/body_drag/sh_drag.lua','ixhl2rp/plugins/body_drag/sh_weapons.lua',
 'ixhl2rp/plugins/arc9_helperbones.lua','ixhl2rp/plugins/body_drag/cl_arms.lua'];
 suite('ARC9 helpers and dragging keep one decorator after 1000 frames and apply the drag pose last',files,`
 local H,D=ix.arc9Helpers,ix.BodyDrag;local capture,repair,drag,native=0,0,0,0
 local order={}
 H.Capture=function() capture=capture+1;order[#order+1]='capture';return {} end
 H.Apply=function() repair=repair+1;order[#order+1]='repair' end
 D.ApplyArm=function() drag=drag+1;order[#order+1]='drag' end
 local w=dragWeapon(carrier);w.ARC9=true;w.DoTPIK=function() native=native+1;order[#order+1]='native' end
 H.Install(w);local installed=w.DoTPIK
 for i=1,1000 do
  H.Install(w);D.WatchARC9(w);eq(w.DoTPIK,installed)
  order={};w:DoTPIK();eq(table.concat(order,','),'capture,native,repair,drag')
 end
 eq(capture,1000);eq(repair,1000);eq(drag,1000);eq(native,1000)
 -- Another one-time decorator can call ours without provoking a wrap contest.
 local foreign=function(self) return installed(self) end;w.DoTPIK=foreign
 for i=1,1000 do H.Install(w);D.WatchARC9(w) end
 eq(w.DoTPIK,foreign);w:DoTPIK();eq(capture,1001);eq(drag,1001)
 carrier:SetNW2Entity('ixDraggedBody',NULL);w:DoTPIK();eq(capture,1002);eq(drag,1001)
 `,setup);
 suite('Live migration peels hundreds of known legacy wrappers without executing them or touching foreign wrappers',files,`
 local H=ix.arc9Helpers;local calls=0;local native=function() calls=calls+1 end;local nested=native
 local source='return function(original) return function(self, ...) return original(self, ...) end end'
 local helper=assert(load(source,'@gamemodes/ixhl2rp/plugins/arc9_helperbones.lua'))()
 local drag=assert(load(source,'@gamemodes/ixhl2rp/plugins/body_drag/cl_arms.lua'))()
 for i=1,400 do nested=helper(drag(nested)) end
 eq(H.UnwrapLegacy(nested),native);eq(calls,0)
 local foreign=assert(load(source,'@addons/foreign/cl_weapon.lua'))()(nested)
 eq(H.UnwrapLegacy(foreign),foreign)
 local w=dragWeapon(carrier);w.ARC9=true;w.DoTPIK=nested
 H.Capture=function() return nil end;ix.BodyDrag.ApplyArm=function() end
 H.Install(w);w:DoTPIK();eq(calls,1);eq(H.wrapped[w].original,native)
 `,setup);
 suite('Repeated arm render passes never rebuild the ragdoll and grip sampling stays once per frame',files,`
 local D=ix.BodyDrag;local rebuilds=0
 body.SetupBones=function() rebuilds=rebuilds+1 end
 local point=D.CacheGrip(body);eq(rebuilds,1)
 for i=1,100 do vectorNear(D.RenderGrip(body),point);D.CacheGrip(body) end
 eq(rebuilds,1);body.ph.pos=Vector(30,12,35);frame=frame+1
 vectorNear(D.CacheGrip(body),body.ph.pos);eq(rebuilds,2)
 for i=1,100 do D.RenderGrip(body) end;eq(rebuilds,2)
 `,setup);
};
