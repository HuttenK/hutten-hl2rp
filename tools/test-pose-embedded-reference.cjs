const assert=require('assert');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {env,toLua}=require('./test-pose-reference-loader.cjs');
const {run,read,native,finish}=require('./restored-test-runner.cjs');
const encode=`
local function json(v)
 local kind=type(v)
 if kind=='string' then return string.format('%q',v) end
 if kind=='number' or kind=='boolean' then return tostring(v) end
 assert(kind=='table');local out={}
 if #v>0 then for _,value in ipairs(v) do out[#out+1]=json(value) end;return '['..table.concat(out,',')..']' end
 for key,value in pairs(v) do out[#out+1]=json(key)..':'..json(value) end
 return '{'..table.concat(out,',')..'}'
end
util.TableToJSON=json
`;
// Capture with production code, serialize to real JSON, then create a fresh
// Lua VM from JSON.parse rather than retaining matrices or cached entity state.
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
const code=read('tools/fixture.lua')+'\nunpack=table.unpack\n'+env+encode+`
 local c=assert(S.Validate(saved));S.CaptureReference(c,target(2));clock=clock+1;assert(S.CaptureReference(c,target(2)))
 exported=json(c)
`;
if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
lua.lua_getglobal(L,to_luastring('exported'));const serialized=to_jsstring(lua.lua_tostring(L,-1));lua.lua_close(L);
const snapshot=JSON.parse(serialized);
assert(snapshot.reference.bones.length<=53);assert(Buffer.byteLength(serialized)<48000);
console.log(`PASS Real JSON reference round-trip: ${Buffer.byteLength(serialized)} bytes, ${snapshot.reference.bones.length} anatomical bones`);
const portable=env+encode+`
 local transmitted=${toLua(snapshot)}
 modelRigs[saved.model]=nil
 ix.sharedPoses.Rig=function(model) return modelRigs[model] end
 ix.sharedPoses.Probe=function() error('original model must not be requested') end
`;
run('Fresh-process deserialization needs no source model or donor for server and client compatibility',portable+`
 local c=assert(S.Validate(transmitted))
 for _,realm in ipairs({false,true}) do
  SERVER=realm;CLIENT=not realm
  for n=2,#all do
   local p=target(n);assert(S.ModelSupports(p,c))
   local state={clip=c,transforms=c.frames[1].bones};assert(S.PrepareLayer(p,state));S.ApplyLayer(p,state)
   assert(p.written[p.rig.names['ValveBiped.Bip01_R_Hand']]);eq(p.written[p.rig.names['ValveBiped.Bip01_Pelvis']],nil)
  end
 end
`);
run('Actual SavePose accepts portable references without source assets and rejects oversized frames plus reference',portable+`
 local P=PLUGIN;P.poseStore={nextID=1,clips={}}
 function P:PoseError(_,message) self.error=message end
 function P:PoseCount() return 0 end
 function P:PoseRigCheck(p,clip) return S.ModelSupports(p,clip) end
 function P:SaveData() self.writes=(self.writes or 0)+1 end
 function P:PoseReply(_,value) self.reply=value end
`+native('ixhl2rp/plugins/pose_studio/sv_studio.lua','function P:SavePose','function P:PoseState')+`
 SERVER=true;CLIENT=false
 local p=target(2);p.SteamID64=function() return '123' end;p.GetCharacter=function() return {GetName=function() return 'Example' end} end
 P:SavePose(p,{clip=transmitted});eq(P.error,nil);eq(P.writes,1);eq(P.reply.kind,'saved');eq(P.reply.row.clip.version,4)
 local huge=table.Copy(transmitted);huge.mask='full'
 huge.frames={}
 for i=1,24 do
  local frame={duration=1,bones={}}
  for name in pairs(S.humanoidBones) do frame.bones[name]={a={123.123,124.124,125.125},p={1.111,2.222,3.333}} end
  huge.frames[i]=frame
 end
 assert(#util.TableToJSON(assert(S.Validate(huge)))>48000)
 P:SavePose(p,{clip=huge});assert(P.error:find('48',1,true));eq(P.writes,1)
`);
run('Snapshot metadata mismatch cannot reuse a previously decoded reference; unsupported anatomy remains rejected',portable+`
 local c=assert(S.Validate(transmitted));assert(S.DecodeReference(c))
 c.base='other';eq(S.DecodeReference(c),nil);eq(S.ModelSupports(target(2),c),false)
 c.base=transmitted.base;c.reference=table.Copy(c.reference)
 for _,bone in ipairs(c.reference.bones) do if bone.name=='ValveBiped.Bip01_L_Hand' then bone.parent=0 end end
 assert(S.Validate(c));eq(S.ModelSupports(target(2),c),false)
`);
run('An unavailable legacy sequence recovers on a compatible current base without changing saved authored transforms',env+`
 local p=target(2);local c=table.Copy(saved);c.base='removed_sequence'
 local substitute=table.Copy(donor);substitute.GetModel=function() return p:GetModel() end
 substitute.GetBoneMatrix=function(_,i) return p.rig.bones[i].bind end
 ix.sharedPoses.Probe=function(model) return model==saved.model and donor or model==p:GetModel() and substitute end
 assert(S.ModelSupports(p,c));S.CaptureReference(c,p);clock=clock+1;assert(S.CaptureReference(c,p))
 eq(c.reference.recovered,true);eq(c.base,'removed_sequence');eq(c.frames[1].bones['ValveBiped.Bip01_R_Forearm'].a[2],-117.338)
`);
finish();
