// Production native paint/layout callbacks exported through the offline adapter.
// This verifies UI geometry and paint composition, not GMod rendering/footage.
const fs=require('fs'),path=require('path'),f=require('fengari'),{normalize}=require('./glua.cjs');
const sharp=require('C:/Users/q1236/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out=path.join('.runtime','device-ui-redesign-20261009','previews');fs.mkdirSync(out,{recursive:true});
const common=['tools/fixture.lua','tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua','tools/fixtures/tv-client.lua','tools/fixtures/tv-controls.lua','tools/fixtures/cctv-render.lua','tools/terminal-preview-fixture.lua','tools/fixtures/surveillance-preview.lua'];
const cctv=['ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','ixhl2rp/plugins/cctv/cl_network.lua','ixhl2rp/plugins/cctv/cl_render.lua','ixhl2rp/plugins/cctv/cl_controls.lua','ixhl2rp/plugins/cctv/cl_terminal.lua','ixhl2rp/plugins/cctv/cl_placement.lua','ixhl2rp/plugins/cctv/cl_surfaces.lua'];
const tv=['helix/gamemode/core/libs/sh_broadcastmedia.lua','ixhl2rp/plugins/tv_screen/sh_state.lua','ixhl2rp/plugins/tv_screen/cl_html.lua','ixhl2rp/plugins/tv_screen/cl_subtitles.lua','ixhl2rp/plugins/tv_screen/cl_display.lua','ixhl2rp/plugins/tv_screen/cl_plugin.lua','ixhl2rp/plugins/tv_screen/cl_controls.lua'];
const setup=`
function string.utf8len(t) return utf8.len(t) end
function string.utf8sub(t,a,b) return t:sub(utf8.offset(t,a),b and ((utf8.offset(t,b+1) or (#t+1))-1) or #t) end
PLUGIN.Request=function() end;PLUGIN.CloseTerminalUI=function() end;PLUGIN.EndPlacement=function() end
`;
const cameras=`
local P,C=PLUGIN,ix.CCTV
for i=1,8 do P.devices[i]={id=i,kind='camera',name=({'Северный коридор','Шлем / Сотрудник охраны','Вход в лабораторный комплекс','Камера аварийного выхода восточного сектора','Медицинское крыло','Транспортный шлюз','Архив','Пост охраны'})[i],on=i~=4,pos=Vector(0,0,64),ang=Angle(),fov=75} end
P.devices[20]={id=20,kind='terminal',name='Пост охраны / Восточное крыло',on=true,pos=Vector(),ang=Angle()}
for i=21,24 do P.devices[i]={id=i,kind='monitor',name='Монитор '..(i-20),on=true,terminal=20,camera=2,pos=Vector(),ang=Angle()} end
`;
const scenarios={
 'cctv-admin':{files:cctv,body:cameras+`P:OpenAdminUI(3);return ixSurveillancePreview(P.window)`},
 'cctv-terminal':{files:cctv,body:cameras+`P.terminalUI={id=20,hover='camera:3'};local root=vgui.Create('DPanel');root:SetSize(C.terminalWidth,C.terminalHeight);root.Paint=function(_,w,h) P:PaintTerminal(P.devices[20],w,h) end;return ixSurveillancePreview(root)`},
 'cctv-mount':{files:cctv,body:cameras+`P.devices[30]={id=30,kind='terminal',name='Пост наблюдения',surface=true,on=true,model='models/test.mdl',config={x=8,y=0,z=0,p=0,yaw=90,r=90,w=32,h=23.2}};P:OpenSurfaceEditor(30);return ixSurveillancePreview(P.window)`},
 'cctv-mount-adjust':{files:cctv,body:cameras+`P.devices[30]={id=30,kind='terminal',name='Пост наблюдения',surface=true,on=true,model='models/test.mdl',config={x=8,y=0,z=0,p=0,yaw=90,r=90,w=32,h=23.2}};P:OpenSurfaceEditor(30);for _,p in ipairs(P.window.children) do if p.class=='DScrollPanel' then p:GetVBar():SetScroll(250) end end;return ixSurveillancePreview(P.window)`},
 'tv-channel':{files:tv,body:`local P=PLUGIN;P.channels={[1]={id=1,name='Общий эфир / инструктаж персонала',source='',sound='',loop=true,volume=.6,playing=false},[2]={id=2,name='Объявления / Восточное крыло',source='',sound='',loop=true,volume=1,playing=false}};P:OpenTVAdmin('channels',1);return ixSurveillancePreview(P.tvWindow)`},
 'tv-audio':{files:tv,body:`local P=PLUGIN;P.channels={[1]={id=1,name='Общий эфир',source='',sound='',loop=true,volume=.6,playing=false}};P:OpenTVAdmin('channels',1);local content=P.tvWindow.children[#P.tvWindow.children];content:GetVBar():SetScroll(500);return ixSurveillancePreview(P.tvWindow)`},
 'tv-mount':{files:tv,body:`local P,T=PLUGIN,ix.TV;P.channels={[1]={id=1,name='Общий эфир'}};P.screens[1]={id=1,name='Телевизор / Комната отдыха',model='models/test.mdl',channel=1,on=true,config=table.Copy(T.defaultConfig)};P:OpenScreenEditor(1);return ixSurveillancePreview(P.tvWindow)`},
 'tv-mount-adjust':{files:tv,body:`local P,T=PLUGIN,ix.TV;P.channels={[1]={id=1,name='Общий эфир'}};P.screens[1]={id=1,name='Телевизор / Комната отдыха',model='models/test.mdl',channel=1,on=true,config=table.Copy(T.defaultConfig)};P:OpenScreenEditor(1);P.tvWindow.children[#P.tvWindow.children]:GetVBar():SetScroll(450);return ixSurveillancePreview(P.tvWindow)`}
};
(async()=>{
 for(const resolution of [[1024,768],[1920,1080]]) for(const [name,scene] of Object.entries(scenarios)){
  const code=[...common,...scene.files].map(p=>'do local function includeFile()\n'+normalize(fs.readFileSync(p,'utf8'))+'\nend;includeFile() end').join('\n')+'\n'+setup+`\nfunction ScrW() return ${resolution[0]} end;function ScrH() return ${resolution[1]} end\n`+scene.body;
  const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
  if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
  const svg=f.to_jsstring(f.lua.lua_tostring(L,-1));const stem=path.join(out,`${name}-${resolution[0]}`);
  fs.writeFileSync(stem+'.svg',svg);await sharp(Buffer.from(svg)).png().toFile(stem+'.png');
  console.log(stem+'.png');
 }
})().catch(e=>{console.error(e);process.exitCode=1});
