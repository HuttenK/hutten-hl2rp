// Paint the production map badges using the offline VGUI adapter, not a mock UI.
const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');const root=path.join(__dirname,'..');
const files=['tools/fixture.lua','tools/geometry-fixture.lua','tools/terminal-preview-fixture.lua',
 'ixhl2rp/plugins/foundation_network/cl_design.lua','ixhl2rp/plugins/foundation_network/cl_map.lua'];
const action=`
 game={GetMap=function() return 'incident-preview' end,GetWorld=function() return {GetBrushSurfaces=function() return {} end} end}
 local p=vgui.Create('ixFoundationMap');p:SetSize(1100,620)
 p.geometry={ready=true,faces={},edges={}}
 local function room(x,y,w,h)
  local v={Vector(x,y,0),Vector(x+w,y,0),Vector(x+w,y+h,0),Vector(x,y+h,0)}
  for i=1,4 do p.geometry.edges[#p.geometry.edges+1]={a=v[i],b=v[i%4+1]} end
 end
 room(-1200,-1000,1400,2000);room(200,-1000,600,600);room(200,-400,600,700);room(200,300,600,700)
 p:SetData({name='OFFLINE PREVIEW',origin={-1800,-1600,0},areas={},terminals={},alerts={
  {name='Электрощитовая',kind='power',active=true,pos={100,580,0}},
  {name='Новая зона',kind='infection',active=true,pos={100,-500,0}}}})
 p.center=Vector(0,0,0);p.radius=1500;p.cutaway=false
 ix.FoundationNet.RenderMap(p);assert(p.mapReady,p.renderError)
 return PreviewSVG(p)
`;
const code=files.map(f=>'do\n'+normalize(fs.readFileSync(path.join(root,f),'utf8'))+'\nend').join('\n')+'\n'+action;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
const svg=to_jsstring(lua.lua_tostring(L,-1)).replace('width="1920" height="1120" viewBox="0 0 1920 1120"','width="1100" height="620" viewBox="0 0 1100 620"');
fs.writeFileSync(path.join(root,'docs/map-incidents-preview.svg'),svg);
console.log('docs/map-incidents-preview.svg');
