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
function includes(b){return Array.from({length:b.readUInt32LE(336)},(_,i)=>{const o=b.readUInt32LE(340)+i*8;return [cstr(b,o+b.readInt32LE(o)),cstr(b,o+b.readInt32LE(o+4))];});}
run('entries={};originals={};bridged={}');let count=0;
function check(model,original){
 input(original);run(`result=ix.AOC.BridgeModel(input,${JSON.stringify(model)});return result`);const result=output();assert(result,model);
 assert.equal(result.readUInt32LE(76),result.length);
 const originalIncludes=includes(original),nextIncludes=includes(result);
 assert.deepEqual(nextIncludes.slice(0,-1),originalIncludes);
 assert.deepEqual(nextIncludes.at(-1),['ix_aoc','models/player/aoc_male_anims.mdl']);
 const prefix=Buffer.from(result.subarray(0,original.length));
 for(const o of [76,336,340])prefix.writeUInt32LE(original.readUInt32LE(o),o);
 assert(prefix.equals(original),'Original animation/bone/ANI bytes changed: '+model);
 run(`entries[#entries+1]={name=${JSON.stringify(model)},bytes=result}`);
 run(`originals[${JSON.stringify(model)}]=input;bridged[${JSON.stringify(model)}]=result`);
 input(result);run(`return ix.AOC.BridgeModel(input,${JSON.stringify(model)})`);assert.equal(output(),null,'Repeated bridge must be idempotent');
 count++;
 return result;
}
for(const name of ['m_anm','f_anm','z_anm','humans/male_postures','humans/female_postures','police_ss','combine_soldier_anims']){
 const model='models/'+name+'.mdl',file=path.join(root,'addons/ix_crawl_animation_content',model),original=fs.readFileSync(file);
 check(model,original);
 const originalIncludes=includes(original);
 const foreign=Buffer.from(original);for(const [_,inc]of originalIncludes){const o=foreign.indexOf(Buffer.from(inc));if(o>=0)foreign.write(inc.replace('ix_cellar','xy_cellar'),o);}
 input(foreign);run('return ix.AOC.BridgeModel(input)');assert.equal(output(),null,'Unknown addon must not be changed');
}
// SD includes public Cellar libraries directly; no ix_cellar marker or m_anm
// is required. Optional directory tests the installed original libraries too.
for(const family of ['male','female','police','combine']){
 const model=`models/cellar/${family}_anims.mdl`;
 let original;
 if(process.argv[2]) original=fs.readFileSync(path.join(process.argv[2],model));
 else {
  original=fs.readFileSync(path.join(root,'addons/ix_crawl_animation_content/models/ix_cellar/cellar',family+'_anims.mdl'));
  original.fill(0,12,76);original.write(`cellar\\${family}_anims.mdl`,12);
  for(let i=0;i<original.readUInt32LE(336);i++){
   const base=original.readUInt32LE(340)+i*8,o=base+original.readInt32LE(base+4),s=cstr(original,o);
   original.fill(0,o,o+Buffer.byteLength(s)+1);original.write(s.replace('models/ix_cellar/','models/'),o);
  }
 }
 assert(!includes(original).some(e=>e[1].startsWith('models/ix_cellar/')));
 input(original);run('return ix.AOC.BridgeModel(input,"models/unrelated.mdl")');assert.equal(output(),null);
 const mesh=Buffer.from(original);mesh.writeUInt32LE(1,232);input(mesh);
 run(`return ix.AOC.BridgeModel(input,${JSON.stringify(model)})`);assert.equal(output(),null,'Never bridge a mesh');
 check(model,original);
 // A legitimate include table can point backwards to its name/label strings.
 const start=original.length,table=Buffer.alloc(original.readUInt32LE(336)*8);
 for(let i=0;i<table.length;i+=8) for(const field of [0,4]){
  const base=original.readUInt32LE(340)+i;
  table.writeInt32LE(base+original.readInt32LE(base+field)-(start+i),i+field);
 }
 const backwards=Buffer.concat([original,table]);backwards.writeUInt32LE(backwards.length,76);backwards.writeUInt32LE(start,340);
 input(backwards);run(`return ix.AOC.BridgeModel(input,${JSON.stringify(model)})`);
 const bridged=output();assert(bridged);assert.deepEqual(includes(bridged).slice(0,-1),includes(original));
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
// Reproduce the reported configuration: SD -> cellar/male_anims directly,
// no legacy m_anm files. Test the startup selection and mount precedence too.
run(`
 local mounted, writes, mounts = false, 0, 0
 file.Exists=function() return true end
 file.Read=function(name,realm)
  if realm=="DATA" or not name:find("^models/cellar/") then return nil end
  return mounted and bridged[name] or originals[name]
 end
 file.CreateDir=function() end
 file.Write=function(name,bytes) writes=writes+1;assert(name:find("bridge_v2_",1,true));assert(bytes:sub(1,4)=="GMAD") end
 game={MountGMA=function() mounts=mounts+1;mounted=true;return true end}
 ix.AOC.MountBridge()
 assert(ix.AOC.contentMounted and #ix.AOC.contentPaths==4)
 assert(writes==1 and mounts==1)
 ix.AOC.MountBridge();assert(writes==1 and mounts==1)
 ix.AOC.contentMounted=nil;mounted=false
 game.MountGMA=function() return true end -- Reported success but wrong search precedence.
 local warning;function ErrorNoHalt(message) warning=message end
 ix.AOC.MountBridge();assert(not ix.AOC.contentMounted)
 assert(warning:find("overrides the compatibility cache",1,true))
`);
fs.mkdirSync(path.join(root,'.runtime'),{recursive:true});fs.writeFileSync(path.join(root,'.runtime/aoc-cache-test.gma'),archive);
console.log('PASS AoC additive cache: 7 legacy roots + 4 direct Cellar libraries, signed offsets, unchanged payloads, mesh rejection, idempotency, GMA index/CRCs. Engine mounting remains a live check.');
