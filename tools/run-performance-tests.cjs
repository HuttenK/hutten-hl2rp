const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..');
let passed=0,failed=0,standalone=0;
function suite(name,files,assertions,setup='') {
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const source=typeof files==='string' ? fs.readFileSync(path.join(__dirname,'fixture.lua'),'utf8')+'\nunpack=table.unpack\n'+files : [fs.readFileSync(path.join(__dirname,'fixture.lua'),'utf8'),setup,
  ...files.map(f=>`do\n${normalize(fs.readFileSync(path.join(root,f),'utf8'))}\nend`),assertions].join('\n');
 const status=lauxlib.luaL_dostring(L,to_luastring(source));
 if(status!==lua.LUA_OK){failed++;console.error('FAIL '+name+': '+to_jsstring(lua.lua_tostring(L,-1)));}
 else {passed++;console.log('PASS '+name);}
 lua.lua_close(L);
}
const modules=process.argv.slice(2);
for(const name of modules.length?modules:['performance-batch1','arc9-inventory','weapon-persistence','voice','medicine','cart-patients','pda-sync']) {
 try {
  const run=require('./test-'+name+'.cjs');
  if(typeof run==='function') run(suite); else standalone++;
 } catch(error) {failed++;console.error('FAIL module '+name+': '+error.stack);}
}
console.log(`${passed} passed; ${failed} failed; ${standalone} standalone modules completed. Mocked Lua tests do not measure live FPS, tick time or network latency.`);
process.exitCode=failed?1:0;
