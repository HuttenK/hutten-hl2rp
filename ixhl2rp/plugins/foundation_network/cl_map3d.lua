local N=ix.FoundationNet
N.Map3D={}
local R=N.Map3D
local width,height=2048,1024

-- The addon's documented veto stops both the HUD draw and its texture update.
-- It works regardless of load order without changing files, functions or cvars.
hook.Add("DynamicMinimapShouldDrawHUD","FoundationTerminalMapOnly",function() return false end)

local function failed(message,detail)
 R.error=message;R.detail=detail
 if detail then ErrorNoHalt("[Terminal map] "..tostring(detail).."\n") end
 return false
end
function R.Ensure()
 local e=DynamicMinimap
 if not e or not e.Bake or not e.Bake.IsReady or not e.Bake.IsBusy or not e.Renderer or not e.Renderer.DrawScene
  or not e.Camera or not e.Camera.FinishView or not e.Config or not e.MapData or not e.MapData.Get then
  R.waiting="Ожидание Dynamic 3D Map. Проверьте загрузку аддона на сервере и клиенте."
  R.engine=nil;return false
 end
 if R.engine~=e or R.renderer~=e.Renderer.DrawScene then
  R.engine=e;R.renderer=e.Renderer.DrawScene;R.renderKey=nil;R.error=nil;R.detail=nil;R.requestedBake=nil;R.requestedAt=nil
 end
 R.waiting=nil
 return not R.error
end
function R.BuildView(panel,w,h)
 local a=Angle(panel.threeD and panel.pitch or 90,panel.threeD and panel.yaw or -90,0)
 local view={origin=panel.center,angles=a,target=panel.center,w=w,h=h,ortho=panel.radius/panel.orbitZoom,fov=70,zfar=65536}
 R.engine.Camera.FinishView(view)
 return view
end
-- Sky materials are already omitted by the addon. A 3D skybox's miniature
-- buildings are ordinary geometry, however. Identify its BSP volume and keep
-- the playable side of a proven empty gap; never guess from altitude alone.
function R.SkyFilter()
 local e,map=R.engine,NikNaks and NikNaks.CurrentMap
 if not e or not e.Bake.IsReady() or not map or not map.GetSkyboxSize or not e.Extract or not e.Extract.GetIndex then return end
 local records=e.Extract.GetIndex();if not records then return end
 local props=e.Props and e.Props.GetAll and e.Props.GetAll() or {}
 local cache=R.skyCache
 if cache and cache.map==map and cache.version==e.Bake.Version and cache.records==records and cache.props==props then return cache.filter end
 cache={map=map,version=e.Bake.Version,records=records,props=props};R.skyCache=cache
 local ok,skyMin,skyMax=pcall(map.GetSkyboxSize,map)
 if not ok or not skyMin or not skyMax then return end
 for _,axis in ipairs({'x','y','z'}) do
  if skyMin[axis]~=skyMin[axis] or skyMax[axis]~=skyMax[axis] or math.abs(skyMin[axis])>100000 or math.abs(skyMax[axis])>100000 or skyMin[axis]>=skyMax[axis] then return end
 end
 local lo,hi=Vector(math.huge,math.huge,math.huge),Vector(-math.huge,-math.huge,-math.huge)
 local skyCount,worldCount=0,0
 local hidden=(e.MapData.Get() or {}).hidden or {}
 local function add(rec)
  if not rec.mins or not rec.maxs then return end
  local inside=true
  for _,axis in ipairs({'x','y','z'}) do
   if rec.mins[axis]<skyMin[axis]-2 or rec.maxs[axis]>skyMax[axis]+2 then inside=false end
  end
  if inside then skyCount=skyCount+1;return end
  worldCount=worldCount+1
  for _,axis in ipairs({'x','y','z'}) do lo[axis]=math.min(lo[axis],rec.mins[axis]);hi[axis]=math.max(hi[axis],rec.maxs[axis]) end
 end
 for _,rec in ipairs(records) do if not hidden[rec.id] then add(rec) end end
 for _,rec in ipairs(props) do add(rec) end
 if skyCount==0 or worldCount==0 then return end
 local bestGap=0
 for _,axis in ipairs({'z','x','y'}) do
  local sign,gap,distance
  if hi[axis]<skyMin[axis]-2 then sign=-1;gap=skyMin[axis]-hi[axis];distance=-(hi[axis]+skyMin[axis])*.5
  elseif lo[axis]>skyMax[axis]+2 then sign=1;gap=lo[axis]-skyMax[axis];distance=(lo[axis]+skyMax[axis])*.5 end
  if gap and gap>bestGap then
   local normal=Vector();normal[axis]=sign;bestGap=gap
   cache.filter={normal=normal,distance=distance,low=lo,high=hi}
  end
 end
 return cache.filter
end
function R.MapBounds(full)
 local e=R.engine;if not e or not e.Bake.IsReady() then return end
 local sky=R.SkyFilter();if sky then return sky.low,sky.high end
 if full and e.Bake.GetWorldBounds then return e.Bake.GetWorldBounds() end
 return e.Bake.GetBounds()
end
function R.Status()
 if R.error then return R.error end
 if R.waiting then return R.waiting end
 local e=R.engine
 if e and (e.Bake.IsBusy() or not e.Bake.IsReady()) then
  if e.MapData.HasReceived and not e.MapData.HasReceived() then return "3D-КАРТА · ожидание данных аддона с сервера" end
  return "3D-КАРТА · аддон подготавливает геометрию"
 end
end

-- The external renderer does not unwind its camera/clip stacks on exceptions.
-- Observe only this synchronous render call, restore the engine functions, and
-- unwind anything it left open. No addon function or geometry is replaced.
function R.RenderScene(view,opts,low,high,sky)
 local saved={start=cam.Start,finish=cam.End3D,push=render.PushCustomClipPlane,pop=render.PopCustomClipPlane,
  light=render.PushFlashlightMode,unlight=render.PopFlashlightMode}
 local cameras,planes,lights=0,0,0
 local clipping=render.EnableClipping(low~=nil or sky~=nil)
 local red,green,blue=render.GetColorModulation();local blend=render.GetBlend()
 cam.Start=function(...)
  saved.start(...);cameras=cameras+1
  -- Submit world-space planes inside the addon's own camera context.
  if cameras==1 and low then
   saved.push(Vector(0,0,1),low);planes=planes+1
   saved.push(Vector(0,0,-1),-high);planes=planes+1
  end
  if cameras==1 and sky then saved.push(sky.normal,sky.distance);planes=planes+1 end
 end
 cam.End3D=function(...)
  if cameras==1 then while planes>0 do saved.pop();planes=planes-1 end end
  saved.finish(...);cameras=cameras-1
 end
 render.PushCustomClipPlane=function(...) saved.push(...);planes=planes+1 end
 render.PopCustomClipPlane=function(...) saved.pop(...);planes=planes-1 end
 render.PushFlashlightMode=function(...) saved.light(...);lights=lights+1 end
 render.PopFlashlightMode=function(...) saved.unlight(...);lights=lights-1 end
 local ok,err=xpcall(function()
  R.engine.Renderer.DrawScene(view,opts,true)
 end,debug.traceback)
 cam.Start=saved.start;cam.End3D=saved.finish
 render.PushCustomClipPlane=saved.push;render.PopCustomClipPlane=saved.pop
 render.PushFlashlightMode=saved.light;render.PopFlashlightMode=saved.unlight
 for _=1,planes do saved.pop() end
 for _=1,lights do saved.unlight() end
 for _=1,cameras do saved.finish() end
 render.EnableClipping(clipping);render.CullMode(MATERIAL_CULLMODE_CCW)
 render.OverrideDepthEnable(false,false);render.MaterialOverride();render.SuppressEngineLighting(false)
 render.SetColorModulation(red,green,blue);render.SetBlend(blend);render.SetWriteDepthToDestAlpha(true)
 if not ok then error(err,0) end
end

local function requestBake(e)
 if R.requestedBake or e.Bake.IsBusy() then return end
 -- Let the addon receive its server document before asking its existing baker
 -- to build. Never create an empty replacement map or a second mesh collection.
 if e.MapData.HasReceived and not e.MapData.HasReceived() then return end
 R.requestedBake=true;R.requestedAt=RealTime()
 if e.MapData.CheckBake then e.MapData.CheckBake("foundation terminal")
 elseif e.Bake.Request then e.Bake.Request("foundation terminal") end
end
local function drawScene(panel,w,h,key)
 if not R.Ensure() then return false end
 local e=R.engine
 if e.Bake.IsBusy() then return false end
 if not e.Bake.IsReady() then
  requestBake(e)
  if R.requestedAt and RealTime()-R.requestedAt>3 then
   return failed("Аддон не подготовил карту. Проверьте консоль и повторите загрузку.")
  end
  return false
 end
 if e.Bake.Stats and (e.Bake.Stats.tris or 0)==0 and (e.Bake.Stats.props or 0)==0 then
  return failed("В карте аддона нет видимой геометрии. Доступна схема.")
 end
 local low,high=N.MapSliceBounds(panel);local sky=R.SkyFilter()
 local current=key..":"..(e.Bake.Version or 0)..":"..tostring(panel.mapProps~=false)..":"..tostring(low)..":"..tostring(high)..":"..tostring(sky)
 if current==R.renderKey and R.material and not panel.dirty and RealTime()<(R.nextRefresh or 0) then
  panel.solidMaterial=R.material;panel.solidU=R.u;panel.solidV=R.v;return true
 end
 local view=R.BuildView(panel,w,h)
 if sky then
  -- Cull whole skybox chunks/props before drawing, then clip mixed chunks on
  -- the GPU. Both operate on this terminal's view, not the addon's map data.
  local n=sky.normal;local f=view.frustum;f.count=f.count+1;f[f.count]={n.x,n.y,n.z,sky.distance}
 end
 -- FinishView keeps the UI aspect for both geometry and terminal overlays.
 local scale=math.min(1536/w,1024/h,1)
 view.w=math.max(1,math.floor(w*scale));view.h=math.max(1,math.floor(h*scale))
 -- Honour the addon's clipping convention while imposing both floor bounds.
 local clip=panel.cutaway and (e.Config.Get("dm_cl_clip_invert") and low or high) or nil
 local bg=e.Themes and e.Themes.GetActive().background or Color(5,13,20)
 local pushed=false
 local ok,err=xpcall(function()
  if not R.target then
   R.target=GetRenderTargetEx("foundation_native_map_v2",width,height,RT_SIZE_NO_CHANGE,MATERIAL_RT_DEPTH_SEPARATE,0,0,IMAGE_FORMAT_RGBA8888)
   R.material=CreateMaterial("foundation_native_map_v2","UnlitGeneric",{["$basetexture"]=R.target:GetName(),["$vertexcolor"]=1,["$vertexalpha"]=1,["$ignorez"]=1})
  end
  render.PushRenderTarget(R.target);pushed=true
  render.OverrideAlphaWriteEnable(true,true);render.Clear(bg.r,bg.g,bg.b,255,true,true)
  render.OverrideAlphaWriteEnable(true,false)
  R.RenderScene(view,{clipZ=clip,props=panel.mapProps~=false,marker=false,npcs=false,
   navigation=false,zoneVolumes=false,zoneLabels=false},low,high,sky)
 end,debug.traceback)
 render.OverrideAlphaWriteEnable(false)
 if pushed then render.PopRenderTarget() end
 if not ok then return failed("Ошибка 3D-вида аддона. Доступна схема и повторная загрузка.",err) end
 R.u=view.w/R.target:Width();R.v=view.h/R.target:Height();R.renderKey=current
 R.nextRefresh=RealTime()+.25
 panel.solidMaterial=R.material;panel.solidU=R.u;panel.solidV=R.v
 return true
end
function R.Draw(panel,w,h,key)
 local ok,result=xpcall(function() return drawScene(panel,w,h,key) end,debug.traceback)
 if not ok then return failed("3D-вид аддона недоступен. Доступна схема.",result) end
 return result
end
function R.Retry()
 R.error=nil;R.detail=nil;R.renderKey=nil;R.requestedBake=nil;R.requestedAt=nil
 local ok,err=xpcall(function()
  if R.Ensure() and not R.engine.Bake.IsReady() then requestBake(R.engine) end
 end,debug.traceback)
 if not ok then failed("Не удалось запросить карту аддона. Доступна схема.",err) end
end
hook.Add("DynamicMinimapBaked","FoundationTerminalMapRefresh",function()
 R.renderKey=nil;R.error=nil;R.detail=nil;R.requestedBake=nil;R.requestedAt=nil
end)
concommand.Add("ix_terminal_map_status",function()
 R.Ensure()
 print("[Terminal map] "..(R.Status() or "DynamicMinimap ready"))
 print("[Terminal map] Source: installed DynamicMinimap; minimap HUD disabled by hook")
 print("[Terminal map] Automatic 3D skybox exclusion: "..(R.SkyFilter() and "active" or "no safely separated skybox detected"))
 if R.engine then PrintTable(R.engine.Bake.Stats or {}) end
 if R.detail then print(R.detail) end
end)
