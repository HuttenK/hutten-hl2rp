// Actual production paint callbacks. Mocked geometry and no-signal state only;
// this does not fabricate game footage or establish native rendering success.
const fs=require('fs'),path=require('path'),f=require('fengari'),{normalize}=require('./glua.cjs');
process.chdir(path.resolve(__dirname,'..'));
const sharp=require('C:/Users/q1236/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out='.runtime/bodycam-terminal-viewer-20261009/previews';fs.mkdirSync(out,{recursive:true});
const common=['tools/fixture.lua','tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua','tools/fixtures/tv-client.lua','tools/fixtures/tv-controls.lua','tools/fixtures/cctv-render.lua','tools/terminal-preview-fixture.lua','tools/fixtures/surveillance-preview.lua'];
const files=['ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','ixhl2rp/plugins/cctv/cl_network.lua','ixhl2rp/plugins/cctv/cl_render.lua','ixhl2rp/plugins/cctv/cl_controls.lua','ixhl2rp/plugins/cctv/cl_terminal.lua'];
const setup=`
 function string.utf8len(t) return utf8.len(t) end
 function string.utf8sub(t,a,b) return t:sub(utf8.offset(t,a),b and ((utf8.offset(t,b+1) or (#t+1))-1) or #t) end
 local P,C=PLUGIN,ix.CCTV
 P.devices[100]={id=100,kind='terminal',name='Пост охраны / Восточное крыло',on=true,pos=Vector(),ang=Angle()}
 local names={'Шлем / Иван Петров','Шлем / Анна Морозова','Шлем / Алексей Смирнов','Шлем / Сотрудник охраны западного сектора','Шлем / Михаил Волков','Шлем / Мария Соколова','Шлем / Начальник смены'}
 for id,name in ipairs(names) do P.devices[id]={id=id,kind='camera',bodycam=true,name=name,on=true,entityIndex=500+id} end
 P.devices[30]={id=30,kind='monitor',name='Монитор 1',on=true,camera=1,terminal=100,pos=Vector(),ang=Angle()}
 local state=P:TerminalState(100);state.page='bodycams';state.bodycam=2
 P.terminalUI={id=100,state=state,hover='bodycam:2'}
`;
const scenes={
 'bodycam-page':``,
 'bodycam-last-page':`state.bodycamPage=2;state.bodycam=7;P.terminalUI.hover='bodycam:7'`,
 'bodycam-empty':`for _,d in pairs(P.devices) do if d.bodycam then d.on=false end end`,
 'bodycam-inactive-terminal':`P.terminalUI=nil`,
 'monitors-page':`state.page='monitors';P.terminalUI.hover='camera:2'`
};
(async()=>{for(const [name,scene] of Object.entries(scenes)){
 const code=[...common,...files].map(p=>'do local function includeFile()\n'+normalize(fs.readFileSync(p,'utf8'))+'\nend;includeFile() end').join('\n')+setup+scene+`
 local root=vgui.Create('DPanel');root:SetSize(C.terminalWidth,C.terminalHeight)
 root.Paint=function(_,w,h) P:PaintTerminal(P.devices[100],w,h) end
 return ixSurveillancePreview(root)`;
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 const svg=f.to_jsstring(f.lua.lua_tostring(L,-1)),stem=path.join(out,name);
 fs.writeFileSync(stem+'.svg',svg);await sharp(Buffer.from(svg)).png().toFile(stem+'.png');console.log(stem+'.png');
}})().catch(error=>{console.error(error);process.exitCode=1});
