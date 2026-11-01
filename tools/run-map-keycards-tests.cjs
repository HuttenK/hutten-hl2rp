const fs=require('fs'),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
let passed=0;
require('./test-map-keycards.cjs')((name,files,source)=>{
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const status=lauxlib.luaL_dostring(L,to_luastring(fs.readFileSync('tools/fixture.lua','utf8')+'\n'+source));
 if(status!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
 passed++;console.log('PASS '+name);lua.lua_close(L);
});
console.log(passed+' map keycard suites passed (mocked engine APIs).');
