const fs=require('fs');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
let passed=0;
function suite(name,files,code,setup=''){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const source=[fs.readFileSync('tools/fixture.lua','utf8'),setup,...files.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend'),code].join('\n');
 const status=lauxlib.luaL_dostring(L,to_luastring(source));
 if(status!==lua.LUA_OK){
  fs.mkdirSync('.runtime/cart-bugfix',{recursive:true});fs.writeFileSync('.runtime/cart-bugfix/failed.lua',source);
  throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
 }
 console.log('PASS '+name);passed++;
}
require('./test-cart-arms.cjs')(suite);
console.log(passed+' cart arm suites passed (mocked engine APIs).');

