-- Engine boundaries only. Tests run the imported extractor, baker and renderer.
SERVER=false;CLIENT=true;ix.FoundationNet={};errors={};commands={};hooks={}
function noop() end
collectgarbage=noop -- Fengari does not expose host GC.
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
color_white=Color(255,255,255)
function ColorAlpha(c,a) return Color(c.r,c.g,c.b,a) end
function RealTime() return clock end
function SysTime() return clock end
function FrameTime() return .016 end
function MsgC(...) end
function ErrorNoHalt(s) errors[#errors+1]=s end
function PrintTable() end
function table.Count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
function math.Rand(a,b) return (a+b)*.5 end
math.atan2=math.atan
bit={band=function(a,b) return a & b end,bor=function(a,b) return a | b end,lshift=function(a,b) return a << b end,rshift=function(a,b) return a >> b end}
bit.bxor=function(a,b) return (a>2147483647 and a-4294967296 or a) ~ b end
local V=getmetatable(Vector())
local originalVector=Vector
function Vector(x,y,z) if isvector(x) then return originalVector(x.x,x.y,x.z) end return originalVector(x,y,z) end
function V:Normalize() local n=self:Length();if n>0 then self.x=self.x/n;self.y=self.y/n;self.z=self.z/n end;return n end
function V:SetUnpacked(x,y,z) self.x=x;self.y=y;self.z=z end
function V:Set(v) self:SetUnpacked(v.x,v.y,v.z) end
function V:Add(v) self:Set(self+v) end
function V:Sub(v) self:Set(self-v) end
function V:Mul(n) self:Set(self*n) end
function V:Unpack() return self.x,self.y,self.z end
function V:DistToSqr(v) return (self-v):LengthSqr() end
function hook.Add(event,id,fn) hooks[event]=hooks[event] or {};hooks[event][id]=fn end
function hook.Remove(event,id) if hooks[event] then hooks[event][id]=nil end end
function hook.Run(event,...) for _,fn in pairs(hooks[event] or {}) do local result=fn(...);if result~=nil then return result end end end
concommand={Add=function(id,fn) commands[id]=fn end}
file={Exists=function(p,realm) return realm=='LUA' and not moduleMissing end,CreateDir=noop,Read=function() return nil end,Find=function() return {},{} end}
util.CRC=function(s) return tostring(#s) end
util.TableToJSON=function() return '{}' end
util.JSONToTable=function() return nil end
function LocalPlayer() error('Map must not access the HUD/follow-player camera') end
function face(vertices,normal,texture,displacement)
 return {GetVertexs=function() return vertices end,GetNormal=function() return normal end,GetTexture=function() return texture or 'concrete/wall' end,
  ShouldRender=function() return true end,IsSkyBox=function() return texture=='tools/toolsskybox' end,IsSkyBox3D=function() return false end,
  GetTexInfo=function() return {flags=0} end,IsDisplacement=function() return displacement or false end,GetBModel=function() return 0 end,IsTranslucent=function() return false end,
  GenerateVertexTriangleData=function() return {{pos=vertices[1]},{pos=vertices[2]},{pos=vertices[3]},{pos=vertices[1]},{pos=vertices[3]},{pos=vertices[4]}} end}
end
bspFaces={
 face({Vector(-256,-256,0),Vector(256,-256,0),Vector(256,256,0),Vector(-256,256,0)},Vector(0,0,1)),
 face({Vector(-256,-256,0),Vector(-256,256,0),Vector(-256,256,256),Vector(-256,-256,256)},Vector(1,0,0)),
 face({Vector(-256,-256,256),Vector(-256,256,256),Vector(256,256,256),Vector(256,-256,256)},Vector(0,0,-1)),
 face({Vector(1000,1000,256),Vector(1000,1500,256),Vector(1500,1500,256)},Vector(0,0,-1),'tools/toolsskybox')}
NikNaks={CurrentMap={GetFaces=function() return bspFaces end,GetMapRevision=function() return 1 end,GetStaticProps=function() return {} end,
 GetBrushBounds=function() return Vector(-256,-256,0),Vector(256,256,256) end}}
game={GetMap=function() return 'fixture' end,GetWorld=function() return {GetBrushSurfaces=function() return {} end} end}
local materialMeta={GetTexture=function() return {IsError=function() return false end} end,IsError=function() return false end,
 GetName=function(self) return self.name end,SetTexture=noop,SetVector=noop,SetFloat=noop,GetFloat=function() return 0 end,GetInt=function() return 0 end}
function CreateMaterial(name,shader,params) return setmetatable({name=name,shader=shader,params=params},{__index=materialMeta}) end
function Material(name) return CreateMaterial(name,'',{}) end
function GetRenderTargetEx(name,w,h) return {GetName=function() return name end,Width=function() return w end,Height=function() return h end} end
RT_SIZE_NO_CHANGE=0;MATERIAL_RT_DEPTH_SEPARATE=1;IMAGE_FORMAT_RGBA8888=0
MATERIAL_CULLMODE_CW=1;MATERIAL_CULLMODE_CCW=0;MATERIAL_TRIANGLES=1
renderState={targets=0,cameras=0,flashlights=0,planes={},draws=0,vertices=0,clipping=false,blend=1,colour={1,1,1}}
local s=renderState
render={
 PushRenderTarget=function(t) s.targets=s.targets+1 end,PopRenderTarget=function() s.targets=s.targets-1 end,
 OverrideAlphaWriteEnable=function(v) s.alphaOverride=v end,Clear=noop,ClearDepth=noop,
 PushFlashlightMode=function() s.flashlights=s.flashlights+1 end,PopFlashlightMode=function() s.flashlights=s.flashlights-1 end,
 SetWriteDepthToDestAlpha=function(v) s.depthAlpha=v end,
 EnableClipping=function(v) local old=s.clipping;s.clipping=v;return old end,
 PushCustomClipPlane=function(n,d) s.planes[#s.planes+1]={normal=n,distance=d};s.lastPlanes=table.Copy(s.planes) end,
 PopCustomClipPlane=function() table.remove(s.planes) end,
 SetColorModulation=function(...) s.colour={...} end,GetColorModulation=function() return table.unpack(s.colour) end,
 SetMaterial=noop,MaterialOverride=function(m) s.overrideMaterial=m end,SuppressEngineLighting=function(v) s.lighting=v end,
 OverrideDepthEnable=function(v) s.depthOverride=v end,CullMode=function(v) s.cull=v end,
 SetBlend=function(v) s.blend=v end,GetBlend=function() return s.blend end,
 SetLightingMode=noop,SetModelLighting=noop,ResetModelLighting=noop,SetAmbientLight=noop,SetLocalModelLights=noop}
cam={Start=function(v) s.cameras=s.cameras+1;s.camera=v end,End3D=function() s.cameras=s.cameras-1 end}
function Mesh()
 return {Draw=function() s.draws=s.draws+1;if throwDraw then error('injected GPU draw failure') end end,Destroy=noop}
end
RENDERGROUP_BOTH=0;propDraws=0
function ClientsideModel(name)
 return {valid=true,SetNoDraw=noop,DrawShadow=noop,SetLOD=noop,GetMaterials=function() return {} end,
  SetSubMaterial=noop,SetPos=noop,SetAngles=noop,SetSkin=noop,SetModelScale=noop,SetupBones=noop,
  DrawModel=function() propDraws=propDraws+1 end,Remove=function(self) self.valid=false end}
end
mesh={Begin=noop,Position=function() s.vertices=s.vertices+1 end,Color=noop,TexCoord=noop,Normal=noop,AdvanceVertex=noop,End=noop}
surface={CreateFont=noop,SetDrawColor=noop,DrawRect=noop,DrawPoly=noop,DrawLine=noop,SetMaterial=noop,DrawTexturedRectUV=noop,SetFont=noop,GetTextSize=function(t) return #t*9,28 end}
paintedTexts={};draw={NoTexture=noop,SimpleText=function(t) paintedTexts[#paintedTexts+1]=t end}
vgui={Register=function(_,p) mapPanel=p end}
function mapPanelFixture()
 local p=setmetatable({valid=true,SetTall=noop,GetTall=function() return 620 end,GetWide=function() return 1724 end},{__index=mapPanel})
 p:Init();p.geometry={ready=true,faces={},edges={}};p:SetData({origin={0,0,0},name='fixture',areas={},alerts={},terminals={}})
 return p
end
function memoryCache(e)
 -- Binary disk cache is an engine API boundary; all geometry paths remain real.
 e.BakeCache.Has=function() return false end;e.BakeCache.Load=function() return nil end
 e.BakeCache.Begin=function() return nil end;e.BakeCache.Save=function() return true end;e.BakeCache.Abort=noop
end
function bakeFixture()
 local R=ix.FoundationNet.Map3D;assert(R.Ensure(),R.detail);local e=R.engine;memoryCache(e)
 e.activeUntil=clock+1;e.Bake.Start('fixture',true);hook.Run('Think')
 assert(e.Bake.IsReady(),table.concat(errors,'\n'));assert(not e.Bake.IsBusy())
 return R,e
end
function cleanRenderState()
 eq(s.targets,0);eq(s.cameras,0);eq(s.flashlights,0);eq(#s.planes,0)
 eq(s.clipping,false);eq(s.alphaOverride,false);eq(s.depthOverride,false);eq(s.lighting,false);eq(s.cull,MATERIAL_CULLMODE_CCW)
end
