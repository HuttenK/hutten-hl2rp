-- Projected HUD drawing boundary; engine visibility is tested manually in GMod.
projectionOrigin=Vector();projectionRight=Vector(1,0,0);projectionUp=Vector(0,1,0)
projectionVisible=true;previewScale=4
local V=getmetatable(Vector())
function V.__div(v,n) return Vector(v.x/n,v.y/n,v.z/n) end
function V:ToScreen()
 local d=self-projectionOrigin
 return {x=ScrW()*.5+d:Dot(projectionRight)*previewScale,y=ScrH()*.5-d:Dot(projectionUp)*previewScale,visible=projectionVisible}
end
previewLines={};previewPolys={};previewErrors={};cameraDepth=0
surface.DrawLine=function(...) previewLines[#previewLines+1]={...} end
surface.DrawPoly=function(points)
 local area=0
 for i,a in ipairs(points) do local b=points[i%#points+1];area=area+a.x*b.y-b.x*a.y end
 assert(area>=0,'Backface preview polygon is culled')
 previewPolys[#previewPolys+1]=points
end
draw.NoTexture=function() end
worldDraws={};local activeCamera,activeMaterial,activeTarget
cam={Start3D2D=function(pos,ang,scale) cameraDepth=cameraDepth+1;activeCamera={pos=pos,ang=ang,scale=scale} end,
 End3D2D=function() cameraDepth=cameraDepth-1;activeCamera=nil end}
surface.SetMaterial=function(m) activeMaterial=m end
surface.DrawTexturedRectUV=function(x,y,w,h,u1,v1,u2,v2)
 local call={material=activeMaterial,sourceMaterial=activeMaterial,w=w,h=h,u1=u1,v1=v1,u2=u2,v2=v2}
 if activeCamera then
  -- Independent implementation of the documented engine model matrix:
  -- SetAngles(angle), SetTranslation(origin), SetScale(scale, -scale, 1).
  local c=activeCamera
  local function point(px,py) return (LocalToWorld(Vector(px*c.scale,-py*c.scale,0),Angle(),c.pos,c.ang)) end
  call.corners={point(x,y),point(x+w,y),point(x+w,y+h),point(x,y+h)}
 end
 if activeTarget then activeTarget.image=call else worldDraws[#worldDraws+1]=call end
end
rtDepth=0;camera2DDepth=0;rtAllocations=0;createdMaterials={};local alpha=1;local clipping=false
RT_SIZE_NO_CHANGE=0;MATERIAL_RT_DEPTH_NONE=2;IMAGE_FORMAT_RGBA8888=0
function GetRenderTargetEx(name,w,h,size,depth)
 assert(size==RT_SIZE_NO_CHANGE and depth==MATERIAL_RT_DEPTH_NONE)
 rtAllocations=rtAllocations+1
 return {name=name,w=w,h=h,GetName=function(self) return self.name end}
end
function CreateMaterial(name,shader,params)
 local mat={name=name,shader=shader,params=params};createdMaterials[#createdMaterials+1]=mat;return mat
end
function DisableClipping(v) local old=clipping;clipping=v;return old end
surface.GetAlphaMultiplier=function() return alpha end
surface.SetAlphaMultiplier=function(v) alpha=v end
local oldRect=surface.DrawRect
surface.DrawRect=function(...) if activeTarget then activeTarget.rectangles=(activeTarget.rectangles or 0)+1 end;oldRect(...) end
cam.Start2D=function() assert(rtDepth==1);camera2DDepth=camera2DDepth+1 end
cam.End2D=function() camera2DDepth=camera2DDepth-1 end
local tint={.4,.5,.6};local blend=.3
render={
 GetViewSetup=TVTestView,
 PushRenderTarget=function(rt) assert(cameraDepth==0 and camera2DDepth==0);rtDepth=rtDepth+1;activeTarget=rt end,
 PopRenderTarget=function() assert(camera2DDepth==0);rtDepth=rtDepth-1;activeTarget=nil end,
 Clear=function(_,_,_,_,clearDepth,stencil) assert(not clearDepth and not stencil);activeTarget.image=nil;activeTarget.rectangles=0 end,
 GetColorModulation=function() return table.unpack(tint) end,SetColorModulation=function(...) tint={...} end,
 GetBlend=function() return blend end,SetBlend=function(v) blend=v end,
 SetMaterial=function(m) activeMaterial=m end,
 DrawQuad=function(a,b,c,d)
  assert(rtDepth==0 and cameraDepth==0 and camera2DDepth==0,'World render nested inside browser/2D draw')
  eq(blend,1);near(tint[1],1);near(tint[2],1);near(tint[3],1)
  eq(activeMaterial.shader,'UnlitGeneric');eq(activeMaterial.params['$ignorez'],'0')
  eq(activeMaterial.params['$translucent'],'0');eq(activeMaterial.params['$nocull'],'1')
  local rt
  for _,slot in pairs(ix.TV.displays) do if slot.material==activeMaterial then rt=slot.target end end
  assert(rt,'World material does not reference a prepared display')
  local img=rt.image or {}
  worldDraws[#worldDraws+1]={corners={a,b,c,d},material=activeMaterial,sourceMaterial=img.material,u2=img.u2,v2=img.v2,rectangles=rt.rectangles}
 end
}
function renderTVFrame()
 clock=clock+.02
 hooks.PreRender.ixTVDisplayTextures()
 hooks.PostDrawTranslucentRenderables.ixTVScreens(false,false,false)
end
function readyTVChannel(id)
 local P,T=PLUGIN,ix.TV;local c=T.Channel(id,'Channel '..id);c.playing=true;c.source='https://example.com/video.webm';P.channels[id]=c
 local material={id=id,GetTexture=function() return {Width=function() return 2048 end,Height=function() return 1024 end} end}
 local html={valid=true,updates=0,scripts={},Remove=function(self) self.valid=false end}
 function html:UpdateHTMLTexture()
  assert(cameraDepth==0 and camera2DDepth==0 and rtDepth==0,'HTML texture updated inside a render camera/target')
  self.updates=self.updates+1
 end
 function html:GetHTMLMaterial() return material end
 function html:RunJavascript(js) self.scripts[#self.scripts+1]=js end
 P.players[id]={status='ready',panel=html,received=clock,created=clock,lastUse=clock,attempt=1}
 return material,html
end
function ErrorNoHalt(err) previewErrors[#previewErrors+1]=err end
