const fs=require('fs'),path=require('path');
const {normalize}=require('./glua.cjs');
module.exports=suite=>{
 const root=path.resolve(__dirname,'..'),lua=path.join(root,'addons/foundation_map_renderer/lua');
 const manifest=JSON.parse(fs.readFileSync(path.join(lua,'../source-manifest.json'),'utf8'));
 const hash=s=>require('crypto').createHash('sha256').update(s).digest('hex');
 for(const f of manifest.files){if(hash(fs.readFileSync(path.join(lua,f.file)))!==f.sha256)throw Error('Imported renderer drift: '+f.file);}
 for(const match of fs.readFileSync(path.join(lua,'includes/modules/niknaks.lua'),'utf8').matchAll(/AutoInclude\("([^"]+)"\)/g)){
  if(!fs.existsSync(path.join(lua,match[1])))throw Error('Missing distributed dependency: '+match[1]);
 }
 const imports={};function scan(dir){for(const f of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,f.name);if(f.isDirectory())scan(p);else if(f.name.endsWith('.lua'))imports[path.relative(lua,p).replaceAll('\\','/')]=fs.readFileSync(p,'utf8');}}
 scan(path.join(lua,'ix_foundation_map3d'));
 imports['autorun/sh_foundation_map3d.lua']=fs.readFileSync(path.join(lua,'autorun/sh_foundation_map3d.lua'),'utf8');
 const setup='local imports={}\n'+Object.entries(imports).map(([p,s])=>`imports[${JSON.stringify(p)}]=function()\n${normalize(s)}\nend`).join('\n')+ '\nfunction include(p) assert(imports[p],p);return imports[p]() end\n';
 const files=['tools/geometry-fixture.lua','tools/fixtures/map3d.lua','ixhl2rp/plugins/foundation_network/cl_map3d.lua','ixhl2rp/plugins/foundation_network/cl_map.lua'];
 suite('Terminal 3D map loads the isolated renderer lazily and pauses its real bake when closed',files,String.raw`
  local R=ix.FoundationNet.Map3D;eq(ix.FoundationMap3D,nil);eq(next(hooks),nil)
  assert(R.Ensure(),R.detail);local e=R.engine;eq(e.Bake.IsBusy(),false);eq(e.Bake.IsReady(),false)
  eq(e.Camera~=nil,true);eq(e.NPCMarkers,nil);eq(e.Editor,nil);eq(e.Marker,nil);eq(DynamicMinimap,nil)
  eq(hooks.HUDPaint,nil);eq(hooks.PlayerButtonDown,nil);eq(next(net.handlers),nil)
  eq(commands.dm_rebake,nil);eq(table.Count(commands),1)
  memoryCache(e);e.Bake.Start('test',true);assert(e.Bake.IsBusy());hook.Run('Think');eq(renderState.vertices,0)
  e.activeUntil=clock+1;hook.Run('Think');assert(e.Bake.IsReady(),table.concat(errors,'\n'))
  eq(e.Bake.Stats.faces,3);eq(e.Bake.Stats.tris,4);eq(renderState.vertices,12)
  assert(e.Bake.Stats.chunks>0);eq(e.lastError,nil);eq(e.Bake.IsBusy(),false)
 `,setup);
 suite('Terminal 3D camera and overlay projections agree across rotations, aspect ratios and zoom',files,String.raw`
  local R,e=bakeFixture();local p=mapPanelFixture()
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
     local d=pos-actual.origin;local tx=(d:Dot(actual.angles:Right())/actual.ortho.right+1)*.5*size[1]
     local ty=(1-d:Dot(actual.angles:Up())/actual.ortho.bottom)*.5*size[2];near(tx,x);near(ty,y)
    end
   end
  end
  cleanRenderState()
 `,setup);
 suite('Terminal 3D native props prepare on demand, respect the models toggle and stop preparing when closed',files,String.raw`
  local R,e=bakeFixture();local p=mapPanelFixture();p.center=Vector();p.radius=800;p.cutaway=false
  local props={{index=1,model='models/props_c17/bench01a.mdl',mins=Vector(-32,-32,0),maxs=Vector(32,32,64),
   pos=Vector(),ang=Angle(),scale=1,zone=0,r=200,g=200,b=200}}
  e.Props.GetAll=function() return props end;e.Props.Count=function() return #props end;e.Props.IsBuilt=function() return true end
  e.NativeProps.Enable();hook.Run('Think');p.dirty=true
  assert(R.Draw(p,1724,550,'props'),R.detail);eq(propDraws,0) -- queued, not yet prepared
  e.activeUntil=0;hook.Run('Think');eq(propDraws,0)
  e.activeUntil=clock+1;hook.Run('Think');assert(R.Draw(p,1724,550,'props-ready'),R.detail);assert(propDraws>0,table.concat(errors,'\n'))
  local before=propDraws;p.mapProps=false;assert(R.Draw(p,1724,550,'props-off'),R.detail);eq(propDraws,before)
  cleanRenderState()
 `,setup);
 suite('Terminal 3D clipping, draw failure cleanup, fallback and retry keep the terminal usable',files,String.raw`
  local R,e=bakeFixture();local p=mapPanelFixture();p.center=Vector(0,0,48);p.radius=800;p.dirty=true
  assert(R.Draw(p,1724,550,'test'),R.detail);assert(renderState.draws>0);cleanRenderState()
  eq(#renderState.lastPlanes,2);near(renderState.lastPlanes[1].normal.z,-1);near(renderState.lastPlanes[1].distance,-96)
  near(renderState.lastPlanes[2].normal.z,1);near(renderState.lastPlanes[2].distance,-80)
  throwDraw=true;eq(R.Draw(p,1724,550,'failure'),false);assert(R.error);cleanRenderState()
  ix.FoundationNet.RenderMap(p);assert(p.mapReady);eq(p.solidReady,false)
  throwDraw=false;R.Retry();eq(R.error,nil);hook.Run('Think');clock=clock+1
  ix.FoundationNet.RenderMap(p);assert(p.solidReady,R.detail);cleanRenderState()
  local start=e.Bake.Start;e.Bake.Start=function() error('cache open failed') end;e.Bake.Ready=false
  eq(R.Draw(p,1724,550,'cache-failure'),false);assert(R.detail:find('cache open failed',1,true))
  R.Retry();assert(R.error);e.Bake.Start=start
 `,setup);
 suite('Terminal 3D missing module and empty BSP recover to the bright schematic without stale textures',files,String.raw`
  local R=ix.FoundationNet.Map3D;moduleMissing=true
  local p=mapPanelFixture();ix.FoundationNet.RenderMap(p);eq(p.solidReady,false);assert(p.mapReady);assert(R.error)
  moduleMissing=false;R.Retry();assert(R.Ensure());memoryCache(R.engine);bspFaces={}
  clock=clock+1;ix.FoundationNet.RenderMap(p);hook.Run('Think');clock=clock+1;ix.FoundationNet.RenderMap(p)
  assert(R.error:find('BSP'));eq(p.solidReady,false);assert(p.mapReady)
  p.solidReady=true;p.geometry.error='bad geometry';clock=clock+1;ix.FoundationNet.RenderMap(p)
  eq(p.solidReady,false);eq(p.mapReady,false)
 `,setup);
 suite('Terminal 3D overlays retain centred area names and icons-only active incidents on both renderers',files,String.raw`
  local R,e=bakeFixture();local p=mapPanelFixture();local N=ix.FoundationNet
  p:SetData({origin={0,0,0},name='fixture',terminals={},areas={{name='Lobby',min={-100,-100,0},max={100,100,128}}},
   alerts={{name='Silent power label',kind='power',active=true,pos={-100,0,0},low=0,high=128},
    {name='Silent infection label',kind='infection',active=true,pos={100,0,0},low=0,high=128},
    {name='Inactive',kind='power',active=false,pos={0,0,0}}}})
  for _,solid in ipairs({true,false,true}) do
   p.useSolid=solid;clock=clock+1;N.RenderMap(p);assert(p.mapReady,R.detail);eq(p.solidReady,solid)
   local area,icons=nil,0 for _,v in ipairs(p.mapView.labels) do if v.area then area=v elseif v.incident then icons=icons+1 end end
   assert(area);eq(icons,2);local right,up=N.MapAxes(p.yaw,p.pitch)
   local x,y=N.MapProject(Vector(0,0,48),p.center,right,up,550*.5*p.orbitZoom/p.radius,1724,550);near(area.x,x);near(area.y,y)
   paintedTexts={};N.PaintMap(p,1724,620)
   for _,t in ipairs(paintedTexts) do assert(not t:find('Silent',1,true));assert(t~='Inactive') end
  end
  p.data.alerts={};p.dirty=true;clock=clock+1;N.RenderMap(p);eq(#p.markers,1)
  p.layers.areas=false;p.dirty=true;clock=clock+1;N.RenderMap(p);eq(#p.mapView.groups,0)
 `,setup);
 suite('Terminal 3D addon distributes every library recursively without starting server geometry or extra UI',files,String.raw`
  local sent={};AddCSLuaFile=function(p) sent[p]=true end
  file.Find=function(p)
   if p=='ix_foundation_map3d/*' then return {'boot.lua','config.lua','ignore.txt'},{'vendor'} end
   if p=='ix_foundation_map3d/vendor/*' then return {},{'shared','client'} end
   if p=='ix_foundation_map3d/vendor/shared/*' then return {'sh_enums.lua'},{} end
   if p=='ix_foundation_map3d/vendor/client/*' then return {'cl_renderer.lua'},{} end
   if p=='niknaks/*' then return {},{'modules'} end
   if p=='niknaks/modules/*' then return {'sh_bsp_module.lua'},{} end
   error(p)
  end
  include('autorun/sh_foundation_map3d.lua');eq(next(sent),nil)
  SERVER=true;CLIENT=false;include('autorun/sh_foundation_map3d.lua')
  eq(table.Count(sent),6);assert(sent['includes/modules/niknaks.lua']);assert(sent['niknaks/modules/sh_bsp_module.lua'])
  eq(ix.FoundationMap3D,nil);eq(next(hooks),nil);eq(sent['ix_foundation_map3d/ignore.txt'],nil)
 `,setup);
};
if(require.main===module){
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 module.exports((name,files,assertions,setup='')=>{
  const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
  const code=[fs.readFileSync('tools/fixture.lua','utf8'),setup,...files.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend'),assertions].join('\n');
  if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK){
   fs.writeFileSync('docs/map3d-test-expanded.lua',code);
   throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
  }
  console.log('PASS '+name);
 });
}
