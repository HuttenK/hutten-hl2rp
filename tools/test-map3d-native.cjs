// Read the user's addon without modifying or repackaging any of its files.
const fs=require('fs'),path=require('path');
const {normalize}=require('./glua.cjs');
module.exports=suite=>{
 const addon=process.env.FOUNDATION_MAP_ADDON || 'E:/map/lua';
 const modules=['shared/sh_enums.lua','shared/sh_util.lua','shared/sh_config.lua','shared/sh_themes.lua','shared/sh_mapdata.lua',
  'client/cl_loading.lua',...['cl_materials','cl_surface_colours','cl_water','cl_extract','cl_relief','cl_spatial','cl_surface_query','cl_props','cl_bake_cache','cl_bake'].map(x=>'client/geometry/'+x+'.lua'),
  ...['cl_camera','cl_native_props','cl_renderzones','cl_renderer','cl_hud'].map(x=>'client/render/'+x+'.lua')];
 const setup='local imports={}\n'+modules.map(p=>`imports[${JSON.stringify(p)}]=function()\n${normalize(fs.readFileSync(path.join(addon,'dynamic_minimap',p),'utf8'))}\nend`).join('\n')+String.raw`
 function loadOriginalAddon()
  timer.Simple=noop;timer.Create=noop
  function LocalPlayer() return {valid=false} end
  cvars={AddChangeCallback=noop};FCVAR_ARCHIVE=1
  local convars={}
  function CreateConVar(name,value)
   local c={value=value};convars[name]=c
   function c:GetString() return tostring(self.value) end
   function c:GetInt() return tonumber(self.value) or 0 end
   c.GetFloat=c.GetInt
   function c:GetBool() return self.value=='1' or self.value=='true' end
   function c:SetString(v) self.value=tostring(v) end
   function c:SetInt(v) self.value=tostring(v) end
   return c
  end
  function GetConVar(name) return convars[name] end
  function RunConsoleCommand(name,v) if convars[name] then convars[name]:SetString(v) end end
  function include() error('Terminal must not include a private renderer') end
  DynamicMinimap={VERSION='3.0.0',DATA_VERSION=1,L=function(s) return s end,Msg=noop,Warn=function(...) errors[#errors+1]=table.concat({...},' ') end}
  local e=DynamicMinimap
 `+modules.map(p=>`imports[${JSON.stringify(p)}]()`+(p==='shared/sh_mapdata.lua'?String.raw`
  document=e.MapData.CreateEmpty();received=true
  e.MapData.Get=function() return document end
  e.MapData.HasReceived=function() return received end
  e.MapData.CheckBake=function(reason) requests=(requests or 0)+1;e.Bake.Request(reason) end
 `:'')).join('\n')+String.raw`
  return e
 end
 function nativeFixture()
  local e=loadOriginalAddon();memoryCache(e)
  e.Bake.Start('fixture',true);hook.Run('Think');assert(e.Bake.IsReady(),table.concat(errors,'\n'))
  local R=ix.FoundationNet.Map3D;assert(R.Ensure(),R.detail)
  return R,e,mapPanelFixture()
 end
 `;
 const files=['tools/geometry-fixture.lua','tools/fixtures/map3d.lua','ixhl2rp/plugins/foundation_network/cl_map_access.lua','ixhl2rp/plugins/foundation_network/cl_map3d.lua','ixhl2rp/plugins/foundation_network/cl_map.lua'];
 suite('Terminal attaches to the installed addon by reference without private loader, separate meshes or config changes',files,String.raw`
  local R,e,p=nativeFixture();local renderer=e.Renderer.DrawScene;local config=e.Config.Get;local chunks=e.Bake.Chunks;local version=e.Bake.Version
  local documentBefore=e.MapData.Get();moduleMissing=true;file.Exists=function() error('No external module check allowed') end
  e.Fullscreen={Open=function() error('Standalone map must stay closed') end,IsOpen=function() return false end}
  ix.FoundationNet.FullscreenMapGate.Apply();eq(e.Fullscreen.Open(),false)
  ix.FoundationMap3D={loaded=true,Bake={Ready=true}} -- obsolete private renderer must be ignored
  assert(R.Draw(p,1724,550,'native'),R.detail);eq(R.engine,DynamicMinimap);eq(R.engine.Bake.Chunks,chunks)
  eq(e.Renderer.DrawScene,renderer);eq(e.Config.Get,config);eq(e.MapData.Get(),documentBefore);eq(e.Bake.Version,version)
  assert(p.solidMaterial);eq(requests,nil);cleanRenderState()
 `,setup);
 suite('Addon HUD veto disables native minimap rendering including loading while leaving terminal and addon functions intact',files,String.raw`
  local R,e,p=nativeFixture();local shouldDraw=e.HUD.ShouldDraw;local hudPaint=hooks.HUDPaint.dm_hud_paint
  function LocalPlayer() return {valid=true} end
  local old=hooks.DynamicMinimapShouldDrawHUD.FoundationTerminalMapOnly
  eq(e.HUD.ShouldDraw(),false);eq(hook.Run('DynamicMinimapShouldDrawHUD'),false)
  local n=renderState.draws;hudPaint();eq(renderState.draws,n)
  e.Bake.Ready=false;e.Loading.Show('panel','GENERATING MAP');hudPaint();eq(renderState.draws,n)
  e.Bake.Ready=true;assert(R.Draw(p,1724,550,'hud-off'),R.detail);assert(renderState.draws>n)
  eq(e.HUD.ShouldDraw,shouldDraw);eq(hooks.HUDPaint.dm_hud_paint,hudPaint)
  hooks.DynamicMinimapShouldDrawHUD.FoundationTerminalMapOnly=nil;eq(e.HUD.ShouldDraw(),true)
  hooks.DynamicMinimapShouldDrawHUD.FoundationTerminalMapOnly=old;eq(e.HUD.ShouldDraw(),false)
 `,setup);
 suite('Terminal uses the addon edited geometry and follows its rebakes instead of rendering the raw schematic',files,String.raw`
  local R,e,p=nativeFixture();eq(e.Bake.Stats.tris,4)
  assert(R.Draw(p,1724,550,'same'),R.detail);local oldVersion=e.Bake.Version
  document.hidden[1]=true;memoryCache(e);e.Bake.Start('saved edit',true)
  eq(R.Draw(p,1724,550,'same'),false) -- do not show half-rebuilt geometry
  hook.Run('Think');eq(e.Bake.Stats.tris,2);assert(e.Bake.Version>oldVersion)
  assert(R.Draw(p,1724,550,'same'),R.detail);eq(R.engine.MapData.Get().hidden[1],true)
  local start=cam.Start;local finish=cam.End3D;local push=render.PushCustomClipPlane
  e.Themes.GetActive=function() return e.Themes.Get('cyberpunk') end
  clock=clock+1;assert(R.Draw(p,1724,550,'same'));eq(cam.Start,start);eq(cam.End3D,finish);eq(render.PushCustomClipPlane,push)
 `,setup);
 suite('Native addon map projection matches terminal overlays for rotated, top-down, wide and tall views',files,String.raw`
  local R,e,p=nativeFixture()
  for _,size in ipairs({{1724,550},{800,900},{3200,550}}) do
   for _,a in ipairs({{-90,90},{35,52},{200,18}}) do
    for _,zoom in ipairs({.5,1,3}) do
     p.threeD=true;p.yaw=a[1];p.pitch=a[2];p.orbitZoom=zoom;p.center=Vector(120,-45,96);p.radius=800
     local v=R.BuildView(p,size[1],size[2]);local pos=Vector(230,70,20)
     local right,up=ix.FoundationNet.MapAxes(p.yaw,p.pitch)
     local x,y=ix.FoundationNet.MapProject(pos,p.center,right,up,size[2]*.5*zoom/p.radius,size[1],size[2])
     local px,py=e.Util.Project(v.projector,pos);near(x,px);near(y,py)
     assert(R.Draw(p,size[1],size[2],table.concat({size[1],a[1],zoom},':')),R.detail)
     local actual=renderState.camera;near(actual.ortho.right/actual.ortho.bottom,size[1]/size[2])
     near(p.solidU,actual.w/2048);near(p.solidV,actual.h/1024)
     local d=pos-actual.origin;near((d:Dot(actual.angles:Right())/actual.ortho.right+1)*.5*size[1],x)
     near((1-d:Dot(actual.angles:Up())/actual.ortho.bottom)*.5*size[2],y)
    end
   end
  end
  cleanRenderState()
 `,setup);
 suite('Native render failures unwind original addon camera, clip and flashlight stacks and retry without rebaking',files,String.raw`
  local R,e,p=nativeFixture();p.center=Vector(0,0,48);p.radius=800;p.dirty=true
  local start,finish,push,pop,light,unlight=cam.Start,cam.End3D,render.PushCustomClipPlane,render.PopCustomClipPlane,render.PushFlashlightMode,render.PopFlashlightMode
  local version=e.Bake.Version
  for _,invert in ipairs({'0','1'}) do
   GetConVar('dm_cl_clip_invert'):SetString(invert)
   assert(R.Draw(p,1724,550,'clip'..invert),R.detail);cleanRenderState()
   eq(#renderState.lastPlanes,3)
   near(renderState.lastPlanes[1].normal.z,1);near(renderState.lastPlanes[1].distance,-8)
   near(renderState.lastPlanes[2].normal.z,-1);near(renderState.lastPlanes[2].distance,-168)
   near(renderState.lastPlanes[3].normal.z,invert=='1' and 1 or -1)
   throwDraw=true;eq(R.Draw(p,1724,550,'fail'..invert),false);assert(R.error);cleanRenderState()
   eq(cam.Start,start);eq(cam.End3D,finish);eq(render.PushCustomClipPlane,push);eq(render.PopCustomClipPlane,pop)
   eq(render.PushFlashlightMode,light);eq(render.PopFlashlightMode,unlight)
   throwDraw=false;R.Retry();eq(R.error,nil);eq(e.Bake.Version,version);assert(R.Draw(p,1724,550,'retry'..invert))
  end
 `,setup);
 suite('Addon load order, missing-addon recovery and receiving map data do not latch a permanent fallback or spam rebuilds',files,String.raw`
  local R=ix.FoundationNet.Map3D;local p=mapPanelFixture()
  eq(R.Draw(p,1724,550,'absent'),false);assert(R.waiting);eq(R.error,nil)
  DynamicMinimap={VERSION='partial'};eq(R.Ensure(),false)
  local e=loadOriginalAddon();memoryCache(e);received=false
  eq(R.Draw(p,1724,550,'loading'),false);eq(R.waiting,nil);eq(requests,nil)
  received=true;eq(R.Draw(p,1724,550,'data'),false);eq(requests,1)
  eq(R.Draw(p,1724,550,'again'),false);eq(requests,1)
  clock=clock+1;hook.Run('Think');assert(e.Bake.IsReady(),table.concat(errors,'\n'))
  assert(R.Draw(p,1724,550,'ready'),R.detail)
  local old=e.Renderer.DrawScene;e.Renderer.DrawScene=function() error('reload') end
  eq(R.Draw(p,1724,550,'reload'),false);e.Renderer.DrawScene=old
  assert(R.Draw(p,1724,550,'reloaded'),R.detail)
  e.Bake.Ready=false;e.MapData.CheckBake=function() requests=requests+1 end
  eq(R.Draw(p,1724,550,'failed-bake'),false);clock=clock+4
  eq(R.Draw(p,1724,550,'failed-bake'),false);assert(R.error)
  local before=requests;eq(R.Draw(p,1724,550,'no-spam'),false);eq(requests,before)
  e.Bake.Ready=true;hook.Run('DynamicMinimapBaked');eq(R.error,nil)
  assert(R.Draw(p,1724,550,'recovered'),R.detail)
 `,setup);
 suite('Terminal frames addon bounds and handles empty maps and unavailable fallback without stale images',files,String.raw`
  local R,e,p=nativeFixture();p.geometry={ready=false,error='schematic unavailable'}
  e.Bake.GetBounds=function() return Vector(100,200,0),Vector(300,400,100) end
  e.Bake.GetWorldBounds=function() return Vector(-1000,-1000,-1000),Vector(1000,1000,1000) end
  p:ResetOrbit(false);near(p.center.x,200);near(p.center.y,300);near(p.center.z,50)
  p:ResetOrbit(true);near(p.center.x,0);near(p.center.z,0)
  ix.FoundationNet.RenderMap(p);assert(p.solidReady,R.detail);assert(p.mapReady)
  e.Bake.Stats={tris=0,props=0};p.dirty=true;clock=clock+1;ix.FoundationNet.RenderMap(p)
  eq(p.solidReady,false);eq(p.mapReady,false);assert(R.error)
 `,setup);
 suite('Native map props prepare through original addon and the terminal model toggle controls their rendering',files,String.raw`
  local R,e,p=nativeFixture();p.center=Vector();p.radius=800;p.cutaway=false
  local props={{index=1,model='models/props_c17/bench01a.mdl',mins=Vector(-32,-32,0),maxs=Vector(32,32,64),pos=Vector(),ang=Angle(),scale=1,zone=0,r=200,g=200,b=200}}
  e.Props.GetAll=function() return props end;e.Props.Count=function() return #props end;e.Props.IsBuilt=function() return true end
  e.NativeProps.Enable();hook.Run('Think');p.dirty=true
  assert(R.Draw(p,1724,550,'props'),R.detail);eq(propDraws,0)
  hook.Run('Think');assert(R.Draw(p,1724,550,'props-ready'),R.detail);assert(propDraws>0,table.concat(errors,'\n'))
  local before=propDraws;p.mapProps=false;assert(R.Draw(p,1724,550,'props-off'),R.detail);eq(propDraws,before);cleanRenderState()
 `,setup);
 suite('Native terminal map retains area centres and icons-only active incidents with live layer and data changes',files,String.raw`
  local R,e,p=nativeFixture();local N=ix.FoundationNet
  p:SetData({origin={0,0,0},name='fixture',terminals={},areas={{name='Lobby',min={-100,-100,0},max={100,100,128}}},
   alerts={{name='Silent power label',kind='power',active=true,pos={-100,0,0},low=0,high=128},
    {name='Silent infection label',kind='infection',active=true,pos={100,0,0},low=0,high=128},
    {name='Inactive',kind='power',active=false,pos={0,0,0}}}})
  for _,solid in ipairs({true,false,true}) do
   p.useSolid=solid;clock=clock+1;N.RenderMap(p);assert(p.mapReady,R.detail);eq(p.solidReady,solid)
   local area,icons=nil,0 for _,v in ipairs(p.mapView.labels) do if v.area then area=v elseif v.incident then icons=icons+1 end end
   assert(area);eq(icons,2);local right,up=N.MapAxes(p.yaw,p.pitch)
   local x,y=N.MapProject(Vector(0,0,128),p.center,right,up,550*.5*p.orbitZoom/p.radius,1724,550);near(area.x,x);near(area.y,y)
   paintedTexts={};N.PaintMap(p,1724,620)
   for _,t in ipairs(paintedTexts) do assert(not t:find('Silent',1,true));assert(t~='Inactive') end
  end
  p.data.alerts={};p.dirty=true;clock=clock+1;N.RenderMap(p);eq(#p.markers,1)
  p.layers.areas=false;p.dirty=true;clock=clock+1;N.RenderMap(p);eq(#p.mapView.groups,0)
 `,setup);
 suite('Layer slider clips native geometry and all overlays together, invalidates caches and keeps height controls independent',files,String.raw`
  local R,e,p=nativeFixture();local N=ix.FoundationNet
  local low,high=N.MapSliceBounds(p);near(low,-8);near(high,168)
  -- Extend playable bounds to include the upper rooms used in this test.
  e.Bake.GetBounds=function() return Vector(-1000,-1000,0),Vector(1000,1000,1200) end
  e.Bake.GetWorldBounds=e.Bake.GetBounds
  p.data.areas={{name='Upstairs',min={-100,-100,250},max={100,100,400}}}
  p.data.alerts={{name='Upper alert',kind='infection',active=true,pos={100,0,300},low=250,high=400}}
  p.data.terminals={{pos={-100,0,300}}}
  local function counts()
   clock=clock+1;N.RenderMap(p);assert(p.mapReady,R.detail)
   local a,i,t=0,0,0;for _,v in ipairs(p.mapView.labels) do if v.area then a=a+1 elseif v.incident then i=i+1 elseif v.text=='T1' then t=t+1 end end
   return a,i,t
  end
  local a,i,t=counts();eq(a,0);eq(i,0);eq(t,0);local key=p.renderKey
  p:SetLayerFraction(.95);a,i,t=counts();eq(a,1);eq(i,1);eq(t,1);assert(p.renderKey~=key)
  low,high=N.MapSliceBounds(p);near(renderState.lastPlanes[1].distance,low);near(renderState.lastPlanes[2].distance,-high)
  local oldHigh,oldLow=high,low;p:Floor(1);low,high=N.MapSliceBounds(p);near(low,oldLow);near(high,math.min(oldHigh+128,1208))
  p:SetLayerFraction(1);eq(N.MapSliceBounds(p),nil);eq(p:GetLayerFraction(),1)
  p:SetLayerFraction(-5);near(p.sliceTop,168);eq(p:GetLayerFraction(),0)
  p:SetLayerFraction(0/0);near(p.sliceTop,168);p:SetLayerFraction(math.huge);near(p.sliceTop,168)
  p:SetLayerFraction(.8);near(p:GetLayerFraction(),.8);p:Home();near(p:GetLayerFraction(),0)
  p:Floor(5);a,i,t=counts();eq(a,1);eq(i,1);eq(t,1)
  local player=false;for _,v in ipairs(p.markers) do if v.title=='ВЫ' then player=true end end;assert(player)
  p.useSolid=false;p:Home();p.threeD=false;p:SetLayerFraction(.95);a,i,t=counts();eq(a,1);eq(i,1);eq(t,1)
  cleanRenderState()
 `,setup);
 suite('Layer slider supports track clicks, fine wheel steps, captured drags and release outside its bounds',files,String.raw`
  local R,e,p=nativeFixture();local N=ix.FoundationNet;MOUSE_LEFT=107;MOUSE_RIGHT=108
  local s={GetWide=function() return 1000 end};N.SetupMapLayerSlider(s,p)
  s:OnSurfacePressed(MOUSE_RIGHT,500);eq(s.dragging,nil);near(p:GetLayerFraction(),0)
  s:OnSurfacePressed(MOUSE_LEFT,500);eq(s.dragging,true);near(p:GetLayerFraction(),.5)
  s:OnSurfaceDrag(10000);eq(p.cutaway,false);near(p:GetLayerFraction(),1)
  s:OnSurfaceReleased(MOUSE_LEFT);s:OnSurfaceDrag(-500);near(p:GetLayerFraction(),1)
  assert(s:OnSurfaceWheel(-1));near(p:GetLayerFraction(),.98)
  s:OnSurfacePressed(MOUSE_LEFT,-500);near(p:GetLayerFraction(),0);s:OnSurfaceDrag(238);near(p:GetLayerFraction(),.25)
  s:OnSurfaceReleased(MOUSE_LEFT);p:Home();near(p:GetLayerFraction(),0)
 `,setup);
 suite('Terminal projected input passes local coordinates to slider and releases capture outside the control', [...files,'ixhl2rp/plugins/foundation_network/cl_surface.lua'],String.raw`
  local R,e,p=nativeFixture();local N=ix.FoundationNet;MOUSE_LEFT=107;MOUSE_RIGHT=108;KEY_ESCAPE=70
  function ScrW() return 1920 end;function ScrH() return 1080 end
  function LocalPlayer() return {EyeAngles=function() return Angle() end} end
  local methods={};methods.__index=methods
  function methods:SetSize(w,h) self.w=w;self.h=h end
  function methods:GetWide() return self.w end;function methods:GetTall() return self.h end
  function methods:SetPos(x,y) self.x=x;self.y=y end;function methods:GetPos() return self.x or 0,self.y or 0 end
  function methods:GetChildren() return self.children end;function methods:GetZPos() return self.z or 0 end
  function methods:SetZPos(z) self.z=z end;function methods:IsVisible() return true end
  function methods:SetParent(v) self.parent=v end;function methods:GetParent() return self.parent end
  function methods:MouseCapture(v) self.captured=v end
  for _,name in ipairs({'SetKeyboardInputEnabled','SetMouseInputEnabled','SetCursor','MakePopup','RequestFocus'}) do methods[name]=noop end
  local function element() return setmetatable({valid=true,children={}},methods) end
  local root=element();root:SetSize(800,500);local slider=element();slider:SetSize(400,76);slider:SetPos(100,60)
  root.children={slider};slider.parent=root;N.SetupMapLayerSlider(slider,p)
  local host,shield=element(),element()
  vgui.Create=function(kind) return kind=='EditablePanel' and host or shield end
  local cursorX,cursorY,down=300,95,false
  N.ScreenCursor=function() return cursorX,cursorY end
  input={IsMouseDown=function(k) return down and k==MOUSE_LEFT end,IsKeyDown=function() return false end}
  gui={IsConsoleVisible=function() return false end,IsGameUIVisible=function() return false end}
  N.AttachSurface(root)
  shield:OnMousePressed(MOUSE_RIGHT);eq(shield.captured,nil);near(p:GetLayerFraction(),0)
  down=true;shield:OnMousePressed(MOUSE_LEFT);eq(shield.captured,true);near(p:GetLayerFraction(),.5)
  cursorX=1000;host:Think();near(p:GetLayerFraction(),1)
  down=false;shield:OnMouseReleased(MOUSE_LEFT);eq(shield.captured,false);eq(slider.dragging,false)
  cursorX=300;host:Think();near(p:GetLayerFraction(),1)
  assert(shield:OnMouseWheeled(-1));near(p:GetLayerFraction(),.98)
  root.busyAt=clock;shield:OnMousePressed(MOUSE_LEFT);near(p:GetLayerFraction(),.98);shield:OnMouseReleased(MOUSE_LEFT)
 `,setup);
 suite('Automatic skybox filtering culls native scenery and clips mixed chunks without hiding playable upper floors or editing addon data',files,String.raw`
  local map=NikNaks.CurrentMap
  map.GetSkyboxSize=function() return Vector(1900,1900,7900),Vector(2600,2600,8600) end
  map.GetBrushBounds=function() return Vector(-1000,-1000,0),Vector(2600,2600,8600) end
  bspFaces[#bspFaces+1]=face({Vector(-256,-256,1800),Vector(256,-256,1800),Vector(256,256,1800),Vector(-256,256,1800)},Vector(0,0,1))
  bspFaces[#bspFaces+1]=face({Vector(2000,2000,8000),Vector(2500,2000,8000),Vector(2500,2500,8000),Vector(2000,2500,8000)},Vector(0,0,1))
  local R,e,p=nativeFixture();local N=ix.FoundationNet
  local chunks=e.Bake.Chunks;local records=e.Extract.GetIndex();local doc=e.MapData.Get();local drawScene=e.Renderer.DrawScene
  local filter=R.SkyFilter();assert(filter);near(filter.normal.z,-1);assert(-filter.distance>1800 and -filter.distance<7900)
  p:ResetOrbit(true);near(p.center.z,900);near(N.MapMaxSliceSpan(p),1816)
  assert(R.Draw(p,1724,550,'sky'),R.detail);eq(#renderState.lastPlanes,1)
  near(renderState.lastPlanes[1].distance,filter.distance)
  local view=R.BuildView(p,1724,550);view.frustum.count=view.frustum.count+1
  local n=filter.normal;view.frustum[view.frustum.count]={n.x,n.y,n.z,filter.distance}
  eq(e.Util.BoxInFrustum(view.frustum,Vector(2000,2000,8000),Vector(2500,2500,8500)),false)
  eq(e.Util.BoxInFrustum(view.frustum,Vector(-256,-256,1700),Vector(256,256,1800)),true)
  p.cutaway=true;p.sliceTop=600;assert(R.Draw(p,1724,550,'sky-slice'),R.detail);eq(#renderState.lastPlanes,4);cleanRenderState()
  throwDraw=true;eq(R.Draw(p,1724,550,'sky-error'),false);cleanRenderState()
  eq(e.Bake.Chunks,chunks);eq(e.Extract.GetIndex(),records);eq(e.MapData.Get(),doc);eq(e.Renderer.DrawScene,drawScene)
  -- A volume interleaved with playable geometry cannot be safely cut away
  -- with one plane. Keep it rather than erasing real map floors.
  map.GetSkyboxSize=function() return Vector(-100,-100,700),Vector(100,100,1000) end
  records[#records+1]={id=99,mins=Vector(-50,-50,800),maxs=Vector(50,50,850)}
  R.skyCache=nil;eq(R.SkyFilter(),nil)
 `,setup);
};
if(require.main===module){
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 module.exports((name,files,assertions,setup='')=>{
  const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
  const code=[fs.readFileSync('tools/fixture.lua','utf8'),setup,...files.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend'),assertions].join('\n');
  if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK){
   fs.writeFileSync('docs/map3d-native-test-expanded.lua',code);
   throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
  }
  console.log('PASS '+name);
 });
}
