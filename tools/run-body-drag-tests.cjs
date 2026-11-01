const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
let passed=0;
function suite(name,files,code,setup=''){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const source=[fs.readFileSync('tools/fixture.lua','utf8'),setup,...files.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend'),code].join('\n');
 const status=lauxlib.luaL_dostring(L,to_luastring(source));
 if(status!==lua.LUA_OK){fs.writeFileSync('.runtime/body-drag/failed.lua',source);throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));}
 console.log('PASS '+name);passed++;
}
require('./test-body-drag.cjs')(suite);
require('./test-body-drag-render.cjs')(suite);
require('./test-downed.cjs')(suite);
console.log(passed+' focused suites passed');
