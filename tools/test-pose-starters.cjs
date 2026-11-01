const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
const fixture=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures/pose-starter-source.json'),'utf8'));
const multiRigs=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures/pose-starter-rigs.json'),'utf8'));
const luav=v=>Array.isArray(v)?'{'+v.map(luav).join(',')+'}':v&&typeof v==='object'?'{'+Object.entries(v).map(([k,x])=>'['+JSON.stringify(k)+']='+luav(x)).join(',')+'}':JSON.stringify(v);
const files=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','ixhl2rp/plugins/pose_studio/sh_clip.lua','ixhl2rp/plugins/pose_studio/sh_rig.lua','ixhl2rp/plugins/pose_studio/cl_rig.lua','ixhl2rp/plugins/pose_studio/cl_starter_data.lua','ixhl2rp/plugins/pose_studio/cl_starters.lua'];
const setup=`ix.PoseStudio={}; unpack=table.unpack; sourceFixture=${luav(fixture)}; function RealTime() return 0 end`;
const mathSetup=`
local S=ix.PoseStudio; angle_zero=Angle()
local M=getmetatable(Matrix())
function M:SetAngles(a)
 local columns={a:Forward(),-a:Right(),a:Up()}
 for c,v in ipairs(columns) do self:SetField(1,c,v.x);self:SetField(2,c,v.y);self:SetField(3,c,v.z) end
end
function M:GetAngles()
 return Angle(math.deg(math.atan(-self[3][1],math.sqrt(self[1][1]^2+self[2][1]^2))),math.deg(math.atan(self[2][1],self[1][1])),math.deg(math.atan(self[3][2],self[3][3])))
end
local function fromArray(a)
 local m=Matrix(); for r=1,3 do for c=1,4 do m:SetField(r,c,a[(r-1)*4+c]) end end; return m
end
local rig={names={},bones={},count=#sourceFixture.bones}
for _,b in ipairs(sourceFixture.bones) do
 local bind=fromArray(sourceFixture.samples.ragdoll[tostring(b.id)])
 local world=b.parent>=0 and rig.bones[b.parent].bind*bind or bind
 rig.names[b.name]=b.id; rig.bones[b.id]={name=b.name,parent=b.parent,localBind=bind,bind=world}
end
rig.height=(rig.bones[rig.names['ValveBiped.Bip01_Head1']].bind:GetTranslation()-rig.bones[rig.names['ValveBiped.Bip01_Pelvis']].bind:GetTranslation()):Length()
local function sampled(base)
 local matrices={}
 for _,b in ipairs(sourceFixture.bones) do
  local m=fromArray(sourceFixture.samples[base][tostring(b.id)])
  matrices[b.id]=b.parent>=0 and matrices[b.parent]*m or m
 end
 return matrices
end
`;
module.exports=function(suite){
 suite('Starter matrices: unused helper and culled fingers do not block a pose; missing arm reports its bone',files,mathSetup+`
  local matrices=sampled('ragdoll');local extra=rig.count
  rig.bones[extra]={name='unused_attachment',parent=0,bind=Matrix(),localBind=Matrix()}
  rig.names.unused_attachment=extra;rig.count=extra+1
  local c,err=S.BuildStarterClip(S.starterPoses[1],rig,matrices,'ragdoll','models/player/test.mdl');assert(c,err)
  for name,i in pairs(rig.names) do if name:find('Finger',1,true) then matrices[i]=nil end end
  c,err=S.BuildStarterClip(S.starterPoses[1],rig,matrices,'ragdoll','models/player/test.mdl');assert(c,err)
  assert(c.frames[1].bones['ValveBiped.Bip01_R_Hand'])
  for name in pairs(c.frames[1].bones) do assert(not name:find('Finger',1,true)) end
  matrices[rig.names['ValveBiped.Bip01_R_Forearm']]=nil
  local retry;c,err,retry=S.BuildStarterClip(S.starterPoses[1],rig,matrices,'ragdoll','models/player/test.mdl')
  eq(c,nil);eq(retry,true);assert(err:find('ValveBiped.Bip01_R_Forearm',1,true))
 `,setup);
 suite('Starter poses: all eight presets save and replay on eight actual rigs without SD model or sitting sequences',files,mathSetup+`
  local cases=0
  for _,data in ipairs(actualRigs) do
   local target={count=#data.bones,names={},bones={}}
   local original={}
   for n,b in ipairs(data.bones) do
    local i=n-1; local bind=fromArray(b.inverse):GetInverse()
    local localBind=b.parent>=0 and target.bones[b.parent].bind:GetInverse()*bind or bind
    target.bones[i]={name=b.name,parent=b.parent,bind=bind,localBind=localBind};target.names[b.name]=i;original[i]=bind
   end
   target.height=(original[target.names['ValveBiped.Bip01_Head1']]:GetTranslation()-original[target.names['ValveBiped.Bip01_Pelvis']]:GetTranslation()):Length()
   for _,preset in ipairs(S.starterPoses) do
    local c,err=S.BuildStarterClip(preset,target,original,'idle_all_01','models/player/custom.mdl');assert(c,data.name..': '..tostring(err))
    eq(c.model,'models/player/custom.mdl');eq(c.base,'idle_all_01')
    local world={}
    for i=0,target.count-1 do
     local b=target.bones[i];local pose=b.localBind*Matrix();local t=c.frames[1].bones[b.name]
     if t then local d=Matrix();d:SetAngles(Angle(unpack(t.a)));d:SetTranslation(Vector(unpack(t.p)));pose=pose*d end
     world[i]=b.parent>=0 and world[b.parent]*pose or pose
    end
    local map=assert(S.RigMap(target,S.StarterRig()))
    local source=S.StarterRig();local authored={}
    for i=0,source.count-1 do
     local b=source.bones[i]; local pose=b.localBind*Matrix();local rot=preset.bones[b.name]
     if rot then for r=1,3 do for col=1,3 do pose:SetField(r,col,rot[(r-1)*3+col]) end end end
     authored[i]=b.parent>=0 and authored[b.parent]*pose or pose
    end
    for name,entry in pairs(map) do
     for r=1,3 do for col=1,3 do assert(math.abs(world[entry.target][r][col]-authored[entry.source][r][col])<.0003,'Orientation changed '..data.name..' '..preset.id..' '..name) end end
     if name:find('_Forearm',1,true) or name:find('_Hand',1,true) or name:find('_Calf',1,true) then
      local b=target.bones[entry.target]
      assert(math.abs((world[entry.target]:GetTranslation()-world[b.parent]:GetTranslation()):Length()-b.localBind:GetTranslation():Length())<.003,'Limb length changed')
     end
    end
    cases=cases+1
   end
  end
  eq(cases,64)
  local c=assert(S.BuildStarterClip(S.starterPoses[7],rig,sampled('ragdoll'),'idle','models/player/test.mdl'))
  local p=c.frames[1].bones['ValveBiped.Bip01_Pelvis'].p
  assert(math.max(math.abs(p[1]),math.abs(p[2]),math.abs(p[3]))>12,'Sitting must exceed old root bound')
  p[1]=65;eq(S.Validate(c),nil)
 `,setup+`;actualRigs=${luav(multiRigs)}`);
 suite('Starter poses: eight actual SD animation bases round-trip through v3 Euler deltas',files,mathSetup+`
  eq(#S.starterPoses,8)
  local ids={}
  for _,preset in ipairs(S.starterPoses) do
   assert(not ids[preset.id]); ids[preset.id]=true
   local sample=sampled(preset.base)
   local clip,err=S.BuildStarterClip(preset,rig,sample,preset.base,'models/player/test.mdl'); assert(clip,err)
   eq(clip.version,3); eq(clip.portable,true); eq(#clip.frames,1); eq(#clip.props,0)
   local total=0
   for name,t in pairs(clip.frames[1].bones) do
    total=total+1; assert(S.humanoidBones[name])
    local i=rig.names[name]; local b=rig.bones[i]
    local parent=b.parent>=0 and sample[b.parent] or Matrix()
    local localBase=parent:GetInverse()*sample[i]
    local delta=Matrix();delta:SetAngles(Angle(unpack(t.a)));delta:SetTranslation(Vector(unpack(t.p)))
    local actual=localBase*delta
    for r=1,3 do for c=1,3 do assert(math.abs(actual[r][c]-preset.bones[name][(r-1)*3+c])<.0001,'Rotation mismatch '..preset.id..' '..name) end end
    local author=S.StarterRig(); local desired=b.localBind:GetTranslation(); if b.parent<0 then desired=desired+(Vector(unpack(preset.rootPosition))-author.bones[author.names[name]].localBind:GetTranslation())*(rig.height/author.height) end
    assert((actual:GetTranslation()-desired):Length()<.002,'Translation mismatch '..name)
   end
   assert(total>=50 and total<=S.limit.bones)
   local again=assert(S.Validate(clip)); eq(again.name,preset.name)
   local transforms=S.Sample(again,10000); assert(transforms['ValveBiped.Bip01_Pelvis'])
  end
  eq(S.BuildStarterClip(S.starterPoses[1],rig,{},'ragdoll'),nil)
  local missingParent=sampled('ragdoll'); missingParent[rig.names['ValveBiped.Bip01_R_Forearm']]=nil
  eq(S.BuildStarterClip(S.starterPoses[1],rig,missingParent,'ragdoll'),nil)
 `,setup);
 suite('Starter loader: unavailable sources fail cleanly and temporary models are always removed',files,mathSetup+`
  eq(S.CreateStarterClip('unknown'),nil)
  local compatible=false
  function LocalPlayer() return {valid=true,GetModel=function() return 'models/player/custom.mdl' end,GetSequence=function() return 0 end,GetSequenceName=function() return 'idle' end} end
  ix.sharedPoses={Rig=function() if compatible then return rig end end}
  eq(S.CreateStarterClip('salute'),nil); compatible=true
  local removed=0; local missing=false; local broken=false;local ready=true;local creations=0
  function ClientsideModel(model)
   creations=creations+1
   eq(model,'models/player/custom.mdl')
   return {valid=true,SetNoDraw=function() end,SetPos=function() end,SetAngles=function() end,
    LookupSequence=function() return missing and -1 or 0 end,ResetSequence=function() end,
    SetupBones=function() if broken then error('sample failed') end end,
    GetBoneMatrix=function(_,i) return ready and sampled('ragdoll')[i] or nil end,
    SetLOD=function(_,value) eq(value,0) end,SetIK=function(_,value) eq(value,false) end,
    Remove=function() removed=removed+1 end}
  end
  S.FreezeBase=function() end; ErrorNoHalt=function() end
  local c=assert(S.CreateStarterClip('salute')); eq(c.model,'models/player/custom.mdl'); eq(removed,1)
  missing=true; eq(S.CreateStarterClip('salute'),nil); eq(removed,2)
  missing=false; broken=true; eq(S.CreateStarterClip('salute'),nil); eq(removed,3)
  broken=false;ready=false
  local pending={};timer.Simple=function(delay,fn) pending[#pending+1]=fn end
  local calls=0;local result
  S.CreateStarterClip('salute',function(c,err) calls=calls+1;result=c end)
  eq(calls,0);eq(removed,3);eq(creations,4)
  table.remove(pending,1)();eq(calls,0);eq(removed,3);eq(#pending,1)
  ready=true;table.remove(pending,1)();eq(calls,1);assert(result);eq(removed,4);eq(creations,4)
  ready=false;local lastError
  S.CreateStarterClip('salute',function(c,err) calls=calls+1;eq(c,nil);lastError=err end)
  for i=1,5 do assert(#pending==1);table.remove(pending,1)() end
  eq(calls,2);eq(removed,5);eq(#pending,0);assert(lastError:find('ValveBiped',1,true))
 `,setup);
};
if(require.main===module){
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');const {normalize}=require('./glua.cjs');let passed=0;
 module.exports((name,files,assertions,setup)=>{
  const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
  const code=[fs.readFileSync(path.join(__dirname,'fixture.lua'),'utf8'),setup,...files.map(f=>'do\n'+normalize(fs.readFileSync(path.join(root,f),'utf8'))+'\nend'),assertions].join('\n');
  if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
  passed++;console.log('PASS '+name);
 });console.log(passed+' starter pose suites passed.');
}
