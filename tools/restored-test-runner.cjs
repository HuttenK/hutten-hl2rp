const fs=require('fs'),path=require('path'),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari'),{normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..');
exports.read=f=>fs.readFileSync(path.join(root,f),'utf8').replace(/\r\n/g,'\n');
exports.source=files=>files.map(f=>'do local function source()\n'+normalize(exports.read(f))+'\nend;source() end').join('\n');
exports.native=(file,start,end)=>{const s=exports.read(file),a=s.indexOf(start),b=s.indexOf(end,a+start.length);if(a<0||b<0)throw Error('Native boundary missing '+start);return normalize(s.slice(a,b));};
let total=0;
exports.run=(name,source)=>{const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);const code=exports.read('tools/fixture.lua')+'\nunpack=table.unpack\n'+source;const result=lauxlib.luaL_dostring(L,to_luastring(code));if(result!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));lua.lua_close(L);console.log('PASS '+name);total++;};
exports.finish=()=>console.log('Passed '+total+' restored-system suites. Engine rendering and live networking require an in-game check.');
exports.base=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','tools/fixtures/facility.lua'];


