const fs=require('fs'),path=require('path');const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');const {normalize}=require('./glua.cjs');const root=path.resolve(__dirname,'..');const motion=process.argv.includes("--motion");const portable=motion||process.argv.includes("--portable");const paths=process.argv.slice(2).filter(x=>!x.startsWith("--"));if(!paths.length)throw Error('Pass extracted MDL paths; this does not launch GMod.');
function quote(s){return JSON.stringify(s);}
let defs=[];for(const p of paths){const b=fs.readFileSync(p),n=b.readInt32LE(156),offset=b.readInt32LE(160),ints={4:b.readInt32LE(4),156:n,160:offset},floats={},names={};for(let i=0;i<n;i++){const o=offset+i*216,np=o+b.readInt32LE(o);ints[o]=b.readInt32LE(o);ints[o+4]=b.readInt32LE(o+4);names[np]=b.toString('utf8',np,b.indexOf(0,np));for(let j=0;j<12;j++)floats[o+96+j*4]=b.readFloatLE(o+96+j*4);}const table=o=>'{'+Object.entries(o).map(([k,v])=>'['+k+']='+ (typeof v==='string'?quote(v):v)).join(',')+'}';defs.push('files['+quote(p.toLowerCase())+']={size='+b.length+',ints='+table(ints)+',floats='+table(floats)+',names='+table(names)+'}');}
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);const src=[fs.readFileSync(path.join(root,'tools/fixture.lua'),'utf8'),fs.readFileSync(path.join(root,'tools/fixtures/sharedposes.lua'),'utf8'),'files={}',...defs,`
file={Open=function(name)
 local data=files[name]; if not data then return end
 return {pos=0,Size=function() return data.size end,Seek=function(self,p) self.pos=p end,Close=function() end,
 ReadLong=function(self) local v=data.ints[self.pos]; self.pos=self.pos+4; return v end,
 ReadFloat=function(self) local v=data.floats[self.pos]; self.pos=self.pos+4; return v end,
 Read=function(self,n)
  local p=self.pos; self.pos=p+n; if p==0 and n==4 then return 'IDST' end
  for start,value in pairs(data.names) do if p>=start and p<=start+#value then return p==start+#value and string.char(0) or value:sub(p-start+1,p-start+n) end end
  error('Unexpected read at '..p)
 end}
end}
`,normalize(fs.readFileSync(path.join(root,'helix/plugins/act/sh_sharedposes.lua'),'utf8')),
 'ix.PoseStudio={}',normalize(fs.readFileSync(path.join(root,'ixhl2rp/plugins/pose_studio/sh_clip.lua'),'utf8')),
 normalize(fs.readFileSync(path.join(root,'ixhl2rp/plugins/pose_studio/sh_rig.lua'),'utf8')),
 ...(motion?['tools/fixtures/pose-gizmo.lua','ixhl2rp/plugins/pose_studio/cl_rig.lua','tools/fixtures/pose-transfer-audit.lua'].map(f=>normalize(fs.readFileSync(path.join(root,f),'utf8'))):[]),
 'auditMotion='+String(motion),
 'auditPortable='+String(portable),`
local all={}
for model in pairs(files) do
 local rig=assert(ix.sharedPoses.Rig(model),'Rig parser rejected '..model)
 print(model..' | bones='..rig.count..' | torso='..rig.height)
 all[#all+1]=rig
end
for _,a in ipairs(all) do for _,b in ipairs(all) do assert(auditPortable and ix.PoseStudio.RigMap(a,b) or not auditPortable and ix.sharedPoses.Compatible(a,b),'Incompatible skeletons') end end
if auditMotion then AuditPoseTransfer(all) end
print('All '..#all..' compiled skeletons pass '..(#all*#all)..' directed compatibility pairs ('..(auditPortable and 'portable' or 'static')..').')
`].join('\n');
const status=lauxlib.luaL_dostring(L,to_luastring(src));if(status!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
