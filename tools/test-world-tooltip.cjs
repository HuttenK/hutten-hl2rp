module.exports=suite=>{
 const setup=`
 SERVER=false;CLIENT=true
 function DEFINE_BASECLASS() BaseClass={} end
 function AccessorFunc(t,key,name) t['Get'..name]=function(s) return s[key] end;t['Set'..name]=function(s,v) s[key]=v end end
 registered={};vgui={Register=function(name,p) registered[name]=p end,CursorVisible=function() return cursorVisible end}
 viewport={1280,720};function ScrW() return viewport[1] end;function ScrH() return viewport[2] end
 client={valid=true,IsWepRaised=function(s) return s.raised end};function LocalPlayer() return client end
 local V={};V.__index=V
 function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
 function V.__mul(a,n) return Vector(a.x*n,a.y*n,a.z*n) end
 projection=99;cameraDepth=0;cameraStarts=0;cameraX=0
 cam={Start3D=function(...)
  eq(select('#',...),0);cameraDepth=cameraDepth+1;cameraStarts=cameraStarts+1;projection=1
 end,End3D=function() cameraDepth=cameraDepth-1 end}
 function V:ToScreen()
  assert(cameraDepth==1,'Projection must run only inside the HUD camera')
  return {x=ScrW()*.5+(self.x-cameraX)*projection,y=ScrH()*.5-self.z*projection,visible=self.y>=0}
 end
 entity={valid=true,angle=0}
 function entity:OBBMins() return Vector(-180,-30,-80) end
 function entity:OBBMaxs() return Vector(180,30,80) end
 function entity:OBBCenter() return Vector(0,0,0) end
 function entity:LookupBone() return self.bone end
 function entity:GetBonePosition(id) assert(id>=0);return self.bonePos end
 function entity:LocalToWorld(p)
  local c,s=math.cos(self.angle),math.sin(self.angle)
  return Vector(p.x*c-p.y*s,p.x*s+p.y*c+100,p.z)
 end
 function entity:GetRotatedAABB() error('Do not rotate the local box twice') end
 ix.gui={};gui={MousePos=function() return 30,50 end}
 surface={SetDrawColor=function() end,DrawLine=function() end,DrawRect=function() end}
 render={SetScissorRect=function() end};derma={SkinFunc=function() end};function DisableClipping() end
 function newTooltip()
  local p=setmetatable({valid=true,bEntity=true,entity=entity,bArrowFollowEntity=true,w=300,h=100,
   arrowX=0,arrowY=0,x=0,y=0,fraction=1,bDrawArrow=true},{__index=registered.ixTooltip})
  function p:GetSize() return self.w,self.h end
  function p:GetPos() return self.x,self.y end
  function p:SetPos(x,y) self.x,self.y=x,y end
  function p:GetChildren() return {} end
  function p:ScreenToLocal(x,y) return x-self.x,y-self.y end
  function p:MoveToFront() end
  function p:Remove() self.bClosing=true end
  ix.gui.entityInfo=p;return p
 end
 `;
 const files=['helix/gamemode/core/derma/cl_tooltip.lua'];
 suite('World tooltip and leader use one main-view projection despite alternating viewmodel cameras',files,`
  local p=newTooltip()
  for i=1,8 do
   projection=i%2==0 and 1 or 5;p:Think();hook.Run('PreDrawHUD');eq(cameraDepth,0)
   eq(p.x,730);eq(p.y,310);eq(p.arrowX,640);eq(p.arrowY,360)
   projection=99;p:Paint(p.w,p.h);eq(p.x,730);eq(p.arrowX,640)
  end
  cameraX=20;hook.Run('PreDrawHUD');eq(p.x,710);eq(p.arrowX,620)
  cameraX=0;entity.angle=math.pi/2;hook.Run('PreDrawHUD');eq(p.x,704)
  entity.bone=0;entity.bonePos=Vector(20,100,30);hook.Run('PreDrawHUD');eq(p.arrowX,660);eq(p.arrowY,330)
  client.raised=true;hook.Run('PreDrawHUD');eq(p.x,490);eq(p.y,492)
  client.raised=false;hook.Run('PreDrawHUD');eq(p.x,704)
 `,setup);
 suite('Tooltip stays on small screens; closing, minimal and cursor tooltips keep their existing behavior',files,`
  local p=newTooltip();viewport={807,796};p.w=380
  hook.Run('PreDrawHUD');eq(p.x,427);assert(p.x+p.w<=ScrW())
  viewport={200,80};hook.Run('PreDrawHUD');eq(p.x,0);eq(p.y,0)
  viewport={1280,720};p.w=300;hook.Run('PreDrawHUD')
  local starts=cameraStarts;local x=p.x;p.bClosing=true;cameraX=100
  hook.Run('PreDrawHUD');p:Think();eq(cameraStarts,starts);eq(p.x,x)
  p.bClosing=false;p.bMinimal=true;hook.Run('PreDrawHUD');eq(cameraStarts,starts)
  p.bMinimal=false;p.bEntity=false;p.mousePadding=16;cursorVisible=true;p:Think()
  eq(p.x,46);eq(p.y,50);hook.Run('PreDrawHUD');eq(cameraStarts,starts)
  cursorVisible=false;p:Think();eq(p.bClosing,true)
 `,setup);
};
