-- Drawing command recorder with transparent target/blend validation.
-- This checks Lua render contracts and geometry, not GPU rasterisation.
CLIENT=true;SERVER=false
screenW,screenH=1920,1080;clock=20;windows=true;alphaMultiplier=1
drawn={};targets={};materialNames={};errors={};events={};captureCount=0;blits=0;polys=0;texts=0;lines=0;matrixCreates=0
local target,clipping,alphaWrite,blend=nil,false,false,nil
local rtStack,modelStack,contextStack={},{},{}
local matrix=nil
function ScrW() return target and target.width or screenW end
function ScrH() return target and target.height or screenH end
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
function Vector(x,y,z) return {x=x,y=y,z=z} end
function Angle(p,y,r) return {p=p,y=y,r=r} end
function Matrix()
 matrixCreates=matrixCreates+1
 return {angle=0,x=0,y=0,SetAngles=function(self,v) self.angle=v.y end,SetTranslation=function(self,v) self.x=v.x;self.y=v.y end}
end
function math.atan2(y,x) return math.atan(y,x) end
function string.Explode(sep,s) local out={};for v in (s..sep):gmatch('(.-)'..sep) do out[#out+1]=v end;return out end
function isbool(v) return type(v)=='boolean' end
system={IsWindows=function() return windows end}
function DisableClipping(value) local old=clipping;clipping=value;return old end
function ErrorNoHalt(message) errors[#errors+1]=message end
BLEND_SRC_ALPHA=4;BLEND_ONE_MINUS_SRC_ALPHA=5;BLEND_ONE=1;BLENDFUNC_ADD=0
RT_SIZE_NO_CHANGE=1;MATERIAL_RT_DEPTH_NONE=2;IMAGE_FORMAT_RGBA8888=0
function GetRenderTargetEx(name,w,h,mode,depth,flags,rtflags,format)
 eq(mode,RT_SIZE_NO_CHANGE);eq(depth,MATERIAL_RT_DEPTH_NONE);eq(format,IMAGE_FORMAT_RGBA8888)
 if failCreate then error('injected target allocation failure') end
 if not targets[name] then
  targets[name]={name=name,width=clampedWidth or w,height=clampedHeight or h,requestedWidth=w,requestedHeight=h,ops={},
   GetName=function(self) return self.name end,Width=function(self) return self.width end,Height=function(self) return self.height end}
 end
 eq(targets[name].requestedWidth,w);eq(targets[name].requestedHeight,h)
 return targets[name]
end
function CreateMaterial(name,shader,data)
 eq(shader,'UnlitGeneric');eq(data['$translucent'],1);eq(data['$vertexcolor'],1);eq(data['$vertexalpha'],1)
 materialNames[name]=true
 return {target=targets[data['$basetexture']]}
end
render={}
function render.GetRenderTarget() return nestedTarget or target end
function render.PushRenderTarget(rt) rtStack[#rtStack+1]=target or false;target=rt;captureCount=captureCount+1;events[#events+1]='push' end
function render.PopRenderTarget() target=table.remove(rtStack);if target==false then target=nil end;events[#events+1]='pop' end
function render.OverrideAlphaWriteEnable(enabled,value) alphaWrite=enabled and value or false end
function render.OverrideBlend(enabled,...) blend=enabled and {...} or nil end
function render.Clear(r,g,b,a,depth,stencil)
 assert(target);eq(alphaWrite,true);eq(r,0);eq(g,0);eq(b,0);eq(a,0);eq(depth,false);eq(stencil,false)
 target.ops={}
end
cam={}
function cam.Start2D() contextStack[#contextStack+1]=matrix or false;matrix=nil end
function cam.End2D() matrix=table.remove(contextStack);if matrix==false then matrix=nil end end
function cam.PushModelMatrix(m,multiply)
 modelStack[#modelStack+1]=matrix or false
 if multiply and matrix then
  local a=math.rad(matrix.angle)
  matrix={x=matrix.x+m.x*math.cos(a)-m.y*math.sin(a),y=matrix.y+m.x*math.sin(a)+m.y*math.cos(a),angle=matrix.angle+m.angle}
 else matrix=m end
end
function cam.PopModelMatrix() matrix=table.remove(modelStack);if matrix==false then matrix=nil end end
local font,color,material=nil,Color(255,255,255),nil
local fonts={}
surface={}
function surface.CreateFont(name,data) fonts[name]=data end
function surface.SetFont(name) font=name end
function surface.GetTextSize(value)
 local data=fonts[font];local width=0
 for _,code in utf8.codes(value) do width=width+data.size*(code>127 and .6 or .56) end
 return width,data.size
end
function surface.GetAlphaMultiplier() return alphaMultiplier end
function surface.SetMaterial(value) material=value end
function surface.SetDrawColor(r,g,b,a) color=type(r)=='table' and table.Copy(r) or Color(r,g,b,a) end
local function record(op)
 if target then
  eq(clipping,true);eq(alphaWrite,true)
  eq(blend[1],BLEND_SRC_ALPHA);eq(blend[2],BLEND_ONE_MINUS_SRC_ALPHA);eq(blend[3],BLENDFUNC_ADD)
  eq(blend[4],BLEND_ONE);eq(blend[5],BLEND_ONE_MINUS_SRC_ALPHA);eq(blend[6],BLENDFUNC_ADD)
  for i=1,#op.xy,2 do
   assert(op.xy[i]>=0 and op.xy[i]<=target.width,'capture X outside target')
   assert(op.xy[i+1]>=0 and op.xy[i+1]<=target.height,'capture Y outside target')
  end
  target.ops[#target.ops+1]=op
 else drawn[#drawn+1]=op end
end
function surface.DrawPoly(points)
 polys=polys+1
 if target and failPoly then failPoly=false;error('injected polygon failure') end
 local op={kind='poly',color=table.Copy(color),xy={}}
 for _,p in ipairs(points) do op.xy[#op.xy+1]=p.x;op.xy[#op.xy+1]=p.y end
 record(op)
end
function surface.DrawLine(x,y,xx,yy) lines=lines+1;record({kind='line',color=table.Copy(color),xy={x,y,xx,yy}}) end
function surface.DrawTexturedRectUV(x,y,w,h,u,v,uu,vv)
 eq(target,nil);eq(blend[1],BLEND_ONE);eq(blend[2],BLEND_ONE_MINUS_SRC_ALPHA);eq(blend[3],BLENDFUNC_ADD)
 eq(color.r,255);eq(color.g,255);eq(color.b,255);eq(color.a,255)
 -- Model the engine helper's documented half-texel inset. The supplied UVs
 -- must cancel it rather than silently shrinking/resampling the cached image.
 local tw,th=material.target.width,material.target.height
 near(u*(1-1/tw)+.5/tw,0);near(v*(1-1/th)+.5/th,0)
 near(uu*(1-1/tw)+.5/tw,w/tw);near(vv*(1-1/th)+.5/th,h/th)
 if failBlit then failBlit=false;error('injected image draw failure') end
 blits=blits+1
 for _,op in ipairs(material.target.ops) do
  local copy=table.Copy(op)
  for i=1,#copy.xy,2 do
   assert(copy.xy[i]<=w and copy.xy[i+1]<=h,'capture cropped visible content')
   copy.xy[i]=copy.xy[i]+x;copy.xy[i+1]=copy.xy[i+1]+y
  end
  drawn[#drawn+1]=copy
 end
end
draw={NoTexture=function() material=nil end}
function draw.SimpleText(value,name,x,y,ink)
 texts=texts+1
 if target and failText then failText=false;error('injected text failure') end
 x,y=math.ceil(x),math.ceil(y)
 surface.SetFont(name)
 local width,height=surface.GetTextSize(value)
 -- Text is clipped in untransformed VGUI space, so its source must be positive.
 assert(x>=0 and y>=0 and x+width<=ScrW() and y+height<=ScrH())
 local angle=matrix and matrix.angle or 0;local a=math.rad(angle)
 local op={kind='text',text=value,font=name,color=table.Copy(ink),angle=angle,xy={}}
 for _,p in ipairs({{x,y},{x+width,y},{x,y+height},{x+width,y+height}}) do
  op.xy[#op.xy+1]=(matrix and matrix.x or 0)+p[1]*math.cos(a)-p[2]*math.sin(a)
  op.xy[#op.xy+1]=(matrix and matrix.y or 0)+p[1]*math.sin(a)+p[2]*math.cos(a)
 end
 record(op)
end
function ResetDrawing() drawn={};polys=0;texts=0;lines=0;blits=0 end
function CheckState()
 eq(target,nil);eq(clipping,false);eq(alphaWrite,false);eq(blend,nil);eq(matrix,nil)
 eq(#rtStack,0);eq(#modelStack,0);eq(#contextStack,0)
end
function SameDrawing(a,b)
 eq(#a,#b)
 for i,op in ipairs(a) do
  local other=b[i];eq(op.kind,other.kind);eq(op.text,other.text);eq(op.font,other.font);eq(op.angle,other.angle)
  for k,v in pairs(op.color) do near(v,other.color[k]) end
  eq(#op.xy,#other.xy);for j,v in ipairs(op.xy) do near(v,other.xy[j]) end
 end
end
function ResourceCount() local n=0;for _ in pairs(targets) do n=n+1 end;return n end
function NewBody()
 local state={parts={}}
 for i=1,7 do state.parts[i]={id=i+10,hitgroup=i,ratio=1} end
 return state
end
ix.util={Include=function() end};ix.command={Add=function() end};ix.gui={};ix.option={Get=function() return reduced end}
FACTION_MTF=3;statusFaction=3;alive=true
local statusCharacter={GetFaction=function() return statusFaction end}
local person={valid=true,Alive=function() return alive end,GetCharacter=function() if not statusNoCharacter then return statusCharacter end end}
function LocalPlayer() return person end
gui={IsGameUIVisible=function() return gameMenu or false end}
statusEnabled=true;statusRevision=4
net.ReadString=function() return statusText end;net.ReadBool=function() return statusEnabled end;net.ReadUInt=function() return statusRevision end
