const fs=require('fs'),assert=require('assert'),{DatabaseSync}=require('node:sqlite');
const {lua,lauxlib,lualib,to_luastring:S,to_jsstring:J}=require('fengari');
const {normalize}=require('./glua.cjs');
function suite(name,body,extra=[]){
 const db=new DatabaseSync(':memory:'),L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 let lastError='',queries=0,failAfter=-1;
 function read(i){i=lua.lua_absindex(L,i);switch(lua.lua_type(L,i)){
  case lua.LUA_TNIL:return null;case lua.LUA_TBOOLEAN:return !!lua.lua_toboolean(L,i);case lua.LUA_TNUMBER:return lua.lua_tonumber(L,i);case lua.LUA_TSTRING:return J(lua.lua_tostring(L,i));
  case lua.LUA_TTABLE:{let entries=[];lua.lua_pushnil(L);while(lua.lua_next(L,i)){entries.push([read(-2),read(-1)]);lua.lua_pop(L,1);}
   if(entries.length&&entries.every(([k])=>Number.isInteger(k)&&k>=1&&k<=entries.length)){const a=[];for(const[k,v]of entries)a[k-1]=v;return a;}
   return Object.fromEntries(entries);}
  default:throw Error('Unsupported bridge type');}}
 function push(v){if(v===null||v===undefined)lua.lua_pushnil(L);else if(typeof v==='boolean')lua.lua_pushboolean(L,v);else if(typeof v==='number')lua.lua_pushnumber(L,v);else if(typeof v==='string')lua.lua_pushstring(L,S(v));else{lua.lua_newtable(L);for(const[k,x]of Object.entries(v)){if(Array.isArray(v))lua.lua_pushinteger(L,+k+1);else lua.lua_pushstring(L,S(k));push(x);lua.lua_settable(L,-3);}}}
 function global(n,f){lua.lua_pushjsfunction(L,f);lua.lua_setglobal(L,S(n));}
 global('query',()=>{const q=read(1);queries++;try{
  if(/^(INSERT|DELETE)/.test(q)&&failAfter>=0){if(failAfter--===0){failAfter=-1;throw Error('injected disk failure');}}
  const rows=db.prepare(q).all();push(rows.length?rows.map(r=>Object.fromEntries(Object.entries(r).map(([k,v])=>[k,String(v)]))):null);
 }catch(e){lastError=e.message;push(false);}return 1;});
 global('lastError',()=>{push(lastError);return 1;});global('queryCount',()=>{push(queries);return 1;});global('failWrites',()=>{failAfter=read(1);return 0;});
 global('jsonEncode',()=>{push(JSON.stringify(read(1)));return 1;});global('jsonDecode',()=>{try{push(JSON.parse(read(1)));}catch{push(null);}return 1;});
 const setup=fs.readFileSync('tools/fixture.lua','utf8')+'\n'+fs.readFileSync('tools/geometry-fixture.lua','utf8')+`
 engine={ActiveGamemode=function() return 'ixhl2rp' end}
 function isangle(value) return type(value)=='table' and getmetatable(value)==getmetatable(Angle()) end
 sql={Query=query,LastError=lastError,SQLStr=function(s) return "'"..s:gsub("'","''").."'" end}
 util.TableToJSON=jsonEncode;util.JSONToTable=jsonDecode
 `;
 const source=setup+'\ndo\n'+normalize(fs.readFileSync('ixhl2rp/schema/libs/sv_record_store.lua','utf8'))+'\nend\n'+extra.map(path=>'do\n'+normalize(fs.readFileSync(path,'utf8'))+'\nend\n').join('\n')+body;
 const result=lauxlib.luaL_dostring(L,S(source));const error=result===lua.LUA_OK?null:J(lua.lua_tostring(L,-1));lua.lua_close(L);db.close();assert.equal(error,null,name+': '+error);console.log('PASS '+name);
}
suite('Native SQLite records atomically migrate, skip unchanged writes, update one row and delete without resurrecting legacy state',`
 local R=ix.recordStore;local missing,err=R.Load('test/map');eq(missing,nil);eq(err,nil)
 local records=R.Split({nextID=3,devices={[1]={id=1,name="O'Brien"},[2]={id=2}},empty={}})
 assert(R.Save('test/map',records));local count=queryCount();local ok,writes=R.Save('test/map',records);eq(ok,true);eq(writes,0);eq(queryCount(),count)
 records['devices/number:1'].value.name='Changed';ok,writes=R.Save('test/map',records);eq(writes,1)
 records['devices/number:2']=nil;ok,writes=R.Save('test/map',records);eq(writes,1)
 R.cache={};local saved=assert(R.Join(assert(R.Load('test/map'))));eq(saved.devices[1].name,'Changed');eq(saved.devices[2],nil);eq(saved.nextID,3);assert(saved.empty)
 assert(R.Save('test/map',{}));R.cache={};local empty=assert(R.Load('test/map'));eq(next(empty),nil)
 eq(R.Load('test/othermap'),nil);eq(R.Load('global'),nil)
`);
suite('Native SQLite partial writes rollback, leave cache unchanged, and retry after failure preserves all rows',`
 local R=ix.recordStore;assert(R.Save('rollback',{a={v=1},b={v=2}}))
 failWrites(1);local ok,err=R.Save('rollback',{a={v=3},c={v=4}});eq(ok,false);assert(err)
 R.cache={};local saved=assert(R.Load('rollback'));eq(saved.a.v,1);eq(saved.b.v,2);eq(saved.c,nil)
 assert(R.Save('rollback',{a={v=3},c={v=4}}));R.cache={};saved=assert(R.Load('rollback'));eq(saved.a.v,3);eq(saved.b,nil);eq(saved.c.v,4)
 failWrites(0);eq(R.Save('failed-migration',{a={v=1}}),false);R.cache={};eq(R.Load('failed-migration'),nil)
 sql.Query('BEGIN');eq(R.Save('nested',{a={v=1}}),false);assert(sql.Query('COMMIT')~=false);R.cache={};eq(R.Load('nested'),nil)
`);
suite('Typed records preserve Vector/Angle, numeric and string keys, booleans, apostrophes and empty collections',`
 local R=ix.recordStore;local source={entities={[7]={pos=Vector(1,2,3),ang=Angle(4,5,6),enabled=false,mixed={[5]='number',['5']='string'},list={'a','b'}}},empty={},nextID=8}
 assert(R.Save("typed'map",R.Split(source)));R.cache={};local saved=assert(R.Join(assert(R.Load("typed'map"))))
 local e=saved.entities[7];assert(isvector(e.pos));assert(isangle(e.ang));eq(e.pos.z,3);eq(e.ang.y,5);eq(e.enabled,false);eq(e.mixed[5],'number');eq(e.mixed['5'],'string');eq(e.list[2],'b');eq(next(saved.empty),nil)
 local cycle={};cycle.self=cycle;eq(R.Save('cycle',{v=cycle}),false)
`);
suite('Corrupt markers and JSON fail closed; malformed roots and alias duplicate records cannot overwrite saved data',`
 local R=ix.recordStore;R.Load('corrupt');sql.Query("INSERT INTO ix_runtime_records VALUES ('ixhl2rp:corrupt','@initialized','0')")
 local v,err=R.Load('corrupt');eq(v,nil);assert(err)
 sql.Query("UPDATE ix_runtime_records SET value='1'");sql.Query("INSERT INTO ix_runtime_records VALUES ('ixhl2rp:corrupt','row','invalid json')")
 v,err=R.Load('corrupt');eq(v,nil);assert(err)
 local rows=R.Split({accounts={a={name='A'}}});rows.alias=rows['accounts/string:a'];v,err=R.Join(rows);eq(v,nil);assert(err)
 rows=R.Split({accounts={}});rows.root.values.accounts=1;v,err=R.Join(rows);eq(v,nil);assert(err)
`);
suite('Foundation migrates legacy accounts, restores SQLite on restart, and refuses later saves after a corrupt load',`
 local legacy={accounts={person={name='Alice',notes='old'}},documents={{id=1,title='Handbook'}},tickets={},nextID=2}
 PLUGIN.GetData=function() return table.Copy(legacy) end;PLUGIN.SetData=function() error('legacy file must remain unchanged') end
 PLUGIN:LoadData();eq(PLUGIN.store.accounts.person.name,'Alice');PLUGIN:SaveData()
 PLUGIN.store.accounts.person.notes='new';PLUGIN:SaveData();ix.recordStore.cache={}
 PLUGIN.GetData=function() error('must not consult stale legacy data') end;PLUGIN.store={};PLUGIN:LoadData();eq(PLUGIN.store.accounts.person.notes,'new');eq(PLUGIN.store.documents[1].title,'Handbook')
 assert(ix.recordStore.Save('foundation_network',{root={invalid=true}}));eq(pcall(function() PLUGIN:LoadData() end),false)
 eq(pcall(function() PLUGIN:SaveData() end),false)
`,['ixhl2rp/plugins/foundation_network/sv_network.lua']);
