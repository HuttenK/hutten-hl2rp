MASK_VISIBLE=99;TEXT_ALIGN_CENTER=1;TEXT_ALIGN_LEFT=0;TEXT_ALIGN_RIGHT=2
local vectorMeta=getmetatable(Vector())
function vectorMeta.__div(v,n) return v*(1/n) end
RENDERGROUP_TRANSLUCENT=1
color_white=Color(255,255,255)
surface.SetDrawColor=function() end;surface.DrawRect=function() end;surface.DrawOutlinedRect=function() end
surface.SetFont=function() end;surface.GetTextSize=function(s) return #s*7,12 end
surface.SetMaterial=function() end;surface.DrawTexturedRectUV=function() end
local alpha=.7
surface.GetAlphaMultiplier=function() return alpha end
surface.SetAlphaMultiplier=function(v) alpha=v end
draw={SimpleText=function() end,RoundedBox=function() end}
RT_SIZE_NO_CHANGE=0;MATERIAL_RT_DEPTH_SEPARATE=1;IMAGE_FORMAT_RGBA8888=0
allocations=0;depth=0;renderCalls=0;errors={};cameraDepth=0
local blend=.4;local tint={.2,.3,.4};local clipping=false
function DisableClipping(v) local old=clipping;clipping=v;return old end
function GetRenderTargetEx(name,w,h,size,dep)
 eq(w,512);eq(h,256);eq(dep,MATERIAL_RT_DEPTH_SEPARATE);allocations=allocations+1
 return {GetName=function() return name end}
end
function CreateMaterial(name,shader,params) return {name=name,shader=shader,params=params} end
render.GetBlend=function() return blend end;render.SetBlend=function(v) blend=v end
render.GetColorModulation=function() return table.unpack(tint) end;render.SetColorModulation=function(...) tint={...} end
render.PushRenderTarget=function(_,x,y,w,h) eq(w,320);eq(h,180);depth=depth+1 end
render.PopRenderTarget=function() depth=depth-1 end
render.Clear=function() end
render.RenderView=function(v)
 assert(ix.CCTV.rendering);eq(depth,1);eq(v.w,320);eq(v.h,180);eq(v.drawhud,false);eq(v.drawviewmodel,false);eq(v.dopostprocess,false)
 renderCalls=renderCalls+1
 hooks.PostRender.ixCCTVFeeds() -- Must not recursively render another feed.
 if failRender then error('injected camera render failure') end
end
render.DrawLine=function() end
cam={Start3D2D=function() cameraDepth=cameraDepth+1 end,End3D2D=function() cameraDepth=cameraDepth-1 end}
function ErrorNoHalt(err) errors[#errors+1]=err end
function clientMonitor(id,pos,camera)
 local e=entity(id,ix.CCTV.kinds.monitor.model,pos or Vector(100,0,0),Angle());e:SetNW2Int('ixCCTVID',id)
 local d={id=id,kind='monitor',name='Monitor '..id,on=true,terminal=0,camera=camera or 1,pos=e.pos,ang=e.ang,entityIndex=id}
 PLUGIN.devices[id]=d;return d,e
end
function inputCommand(left,right)
 return {KeyDown=function(_,key) return key==IN_ATTACK and left or key==IN_ATTACK2 and right or false end,RemoveKey=function() end}
end
function ClientsideModel(model) local e=entity(999,model);return e end
local makePanel=vgui.Create
function vgui.Create(kind)
 local p=makePanel(kind)
 function p:SetKeyboardInputEnabled(v) self.keyboard=v end
 function p:SetCursor(v) self.cursor=v;self.cursorChanges=(self.cursorChanges or 0)+1 end
 local setSize=p.SetSize
 function p:SetSize(w,h) self.resizes=(self.resizes or 0)+1;setSize(self,w,h) end
 function p:MouseCapture(v) self.captured=v end
 return p
end
function gui.IsConsoleVisible() return consoleVisible or false end
function gui.ScreenToVector() return cursorDirection or viewAngle:Forward() end
cursorX,cursorY=960,540
function input.GetCursorPos() return cursorX,cursorY end
function clientTerminal(id,pos,ang)
 local d,e=clientMonitor(id,pos,0);d.kind='terminal';d.name='Terminal '..id;e.ang=ang or Angle();d.ang=e.ang
 return d,e
end
function aimAtTerminal(d,x,y)
 local origin,a,scale=ix.CCTV.TerminalGeometry(d)
 cursorDirection=(origin+a:Forward()*(x*scale)+a:Right()*(y*scale)-client.pos):GetNormalized()
 -- A fixed player view and genuine projected mouse position, independent of
 -- gui.ScreenToVector / whichever offscreen view was rendered last.
 viewAngle=(-a:Up()):Angle()
 local v=render.GetViewSetup(false);local delta=origin+a:Forward()*(x*scale)+a:Right()*(y*scale)-v.origin
 local depth=delta:Dot(v.angles:Forward());local tan=math.tan(math.rad(v.fov*.5))
 local w,h=v.width or ScrW(),v.height or ScrH();local aspect=v.aspect or w/h
 cursorX=(v.x or 0)+w*.5*(1+delta:Dot(v.angles:Right())/(depth*tan))
 cursorY=(v.y or 0)+h*.5*(1-delta:Dot(v.angles:Up())*aspect/(depth*tan))
end
function clientSurface(id,ent,config)
 ent:SetNW2Int('ixCCTVSurfaceID',id)
 local d={id=id,kind='terminal',surface=true,name='Surface '..id,on=true,model=ent:GetModel(),entityIndex=ent:EntIndex(),config=config}
 PLUGIN.devices[id]=d;return d
end
