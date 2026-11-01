// Standalone adapter for the existing exported field-equipment suites.
const fs=require('fs'),path=require('path'),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..');
let passed=0;
require('./test-field-equipment.cjs')((name,files,assertions,setup='')=>{
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const source=[fs.readFileSync(path.join(__dirname,'fixture.lua'),'utf8'),setup,...files.map(file=>'do\n'+normalize(fs.readFileSync(path.join(root,file),'utf8'))+'\nend'),assertions].join('\n');
 const status=lauxlib.luaL_dostring(L,to_luastring(source));
 if(status!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
 passed++;console.log('PASS '+name);
});
if(!passed)throw Error('Existing field-equipment module ran no suites');
console.log(passed+' field-equipment regression suites passed.');
