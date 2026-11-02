const fs=require('fs'),path=require('path'),assert=require('assert'),{crc32}=require('zlib');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..'),L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
function run(src){if(lauxlib.luaL_dostring(L,to_luastring(src))!==lua.LUA_OK)throw new Error(to_jsstring(lua.lua_tostring(L,-1)));}
run('ix={AOC={}}; function isstring(x) return type(x)=="string" end; file={Exists=function() return false end};util={}');
lua.lua_getglobal(L,to_luastring('util'));
lua.lua_pushjsfunction(L,state=>{lua.lua_pushstring(state,to_luastring(String(crc32(Buffer.from(lua.lua_tolstring(state,1))))));return 1;});
lua.lua_setfield(L,-2,to_luastring('CRC'));lua.lua_pop(L,1);
run(normalize(fs.readFileSync(path.join(root,'ixhl2rp/plugins/aoc_compat/sh_content.lua'),'utf8')));
function input(bytes){lua.lua_pushlstring(L,new Uint8Array(bytes),bytes.length);lua.lua_setglobal(L,to_luastring('input'));}
function output(){if(!lua.lua_gettop(L))return null;const result=lua.lua_type(L,-1)===lua.LUA_TNIL?null:Buffer.from(lua.lua_tolstring(L,-1));lua.lua_pop(L,1);return result;}
const cstr=(b,o)=>b.toString('utf8',o,b.indexOf(0,o));
function includes(b){return Array.from({length:b.readUInt32LE(336)},(_,i)=>{const o=b.readUInt32LE(340)+i*8;return [cstr(b,o+b.readUInt32LE(o)),cstr(b,o+b.readUInt32LE(o+4))];});}
run('entries={}');let count=0;
for(const name of ['m_anm','f_anm','z_anm','humans/male_postures','humans/female_postures','police_ss','combine_soldier_anims']){
 const model='models/'+name+'.mdl',file=path.join(root,'addons/ix_crawl_animation_content',model),original=fs.readFileSync(file);
 input(original);run('result=ix.AOC.BridgeModel(input);return result');const result=output();assert(result,model);
 assert.equal(result.readUInt32LE(76),result.length);
 const originalIncludes=includes(original),nextIncludes=includes(result);
 assert.deepEqual(nextIncludes.slice(0,-1),originalIncludes);
 assert.deepEqual(nextIncludes.at(-1),['ix_aoc','models/player/aoc_male_anims.mdl']);
 const prefix=Buffer.from(result.subarray(0,original.length));
 for(const o of [76,336,340])prefix.writeUInt32LE(original.readUInt32LE(o),o);
 assert(prefix.equals(original),'Original animation/bone/ANI bytes changed: '+model);
 run(`entries[#entries+1]={name=${JSON.stringify(model)},bytes=result}`);
 input(result);run('return ix.AOC.BridgeModel(input)');assert.equal(output(),null,'Repeated bridge must be idempotent');
 const foreign=Buffer.from(original);for(const [_,inc]of originalIncludes){const o=foreign.indexOf(Buffer.from(inc));if(o>=0)foreign.write(inc.replace('ix_cellar','xy_cellar'),o);}
 input(foreign);run('return ix.AOC.BridgeModel(input)');assert.equal(output(),null,'Unknown addon must not be changed');
 count++;
}
for(const invalid of [Buffer.from(''),Buffer.alloc(500),Buffer.from('IDST')]){input(invalid);run('return ix.AOC.BridgeModel(input)');assert.equal(output(),null);}
run('return ix.AOC.BridgeArchive(entries)');const archive=output();
assert.equal(archive.toString('ascii',0,4),'GMAD');assert.equal(archive[4],3);
let o=21;const readstr=()=>{const value=cstr(archive,o);o+=Buffer.byteLength(value)+1;return value;};
assert.equal(readstr(),'');readstr();JSON.parse(readstr());readstr();o+=4;
const entries=[];while(archive.readUInt32LE(o)){o+=4;const name=readstr(),length=Number(archive.readBigUInt64LE(o)),crc=archive.readUInt32LE(o+8);o+=12;entries.push({name,length,crc});}o+=4;
assert.equal(entries.length,count);
for(const entry of entries){const b=archive.subarray(o,o+entry.length);assert.equal(crc32(b),entry.crc);assert.equal(b.readUInt32LE(76),b.length);o+=entry.length;}
assert.equal(o+4,archive.length);assert.equal(crc32(archive.subarray(0,o)),archive.readUInt32LE(o));
fs.mkdirSync(path.join(root,'.runtime'),{recursive:true});fs.writeFileSync(path.join(root,'.runtime/aoc-cache-test.gma'),archive);
console.log('PASS AoC additive cache: 7 real MDLs, unchanged bone/ANI/animation payloads, preserved includes, idempotency, GMA index/CRCs. Engine mounting remains a live check.');
