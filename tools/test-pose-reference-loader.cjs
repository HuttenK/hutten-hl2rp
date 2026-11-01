const {run,source,native,read,finish}=require('./restored-test-runner.cjs');
const toLua=v=>Array.isArray(v)?'{'+v.map(toLua).join(',')+'}':v&&typeof v==='object'?'{'+Object.entries(v).map(([k,x])=>'['+JSON.stringify(k)+']='+toLua(x)).join(',')+'}':JSON.stringify(v);
const clip=JSON.parse(read('tools/fixtures/pose-salute.json'));
const rigs=[JSON.parse(read('tools/fixtures/pose-salute-rig.json')),...JSON.parse(read('tools/fixtures/pose-starter-rigs.json'))];
const env=`ix.PoseStudio={};function RealTime() return clock end
function FrameNumber() return referenceFrame or math.floor(clock*60) end
function math.Round(v,d) local n=10^(d or 0);return math.floor(v*n+.5)/n end
`+source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','ixhl2rp/plugins/pose_studio/sh_clip.lua','ixhl2rp/plugins/pose_studio/sh_rig.lua','ixhl2rp/plugins/pose_studio/cl_rig.lua'])+'\n'+
native('ixhl2rp/plugins/pose_studio/cl_playback.lua','function S.FreezeBase','function S.Request').replace('function S.FreezeBase','function ix.PoseStudio.FreezeBase')+`
local S=ix.PoseStudio;angle_zero=Angle()
local M=getmetatable(Matrix())
function M:SetAngles(a) local axes={a:Forward(),-a:Right(),a:Up()};for c,v in ipairs(axes) do self:SetField(1,c,v.x);self:SetField(2,c,v.y);self:SetField(3,c,v.z) end end
function M:GetAngles() return Angle(math.deg(math.atan(-self[3][1],math.sqrt(self[1][1]^2+self[2][1]^2))),math.deg(math.atan(self[2][1],self[1][1])),math.deg(math.atan(self[3][2],self[3][3]))) end
function M:GetField(r,c) return self[r][c] end
function same(a,b) for r=1,3 do for c=1,4 do near(a[r][c],b[r][c],.001) end end end
local data=${toLua(rigs)}
local saved=${toLua(clip)}
local all={}
for _,d in ipairs(data) do
 local rig={count=#d.bones,bones={},names={}}
 for n,b in ipairs(d.bones) do local i=n-1;local inverse=Matrix()
  for r=1,3 do for c=1,4 do inverse:SetField(r,c,b.inverse[(r-1)*4+c]) end end
  local bind=inverse:GetInverse();local localBind=b.parent>=0 and rig.bones[b.parent].inverse*bind or bind
  rig.bones[i]={name=b.name,parent=b.parent,bind=bind,inverse=inverse,localBind=localBind};rig.names[b.name]=i
 end
 rig.height=(rig.bones[rig.names['ValveBiped.Bip01_Head1']].bind:GetTranslation()-rig.bones[rig.names['ValveBiped.Bip01_Pelvis']].bind:GetTranslation()):Length()
 all[#all+1]=rig
end
local sourceRig=all[1];local modelRigs={[saved.model]=sourceRig};local available=true
local donor={valid=true,sequence=0,created=clock,reads=0,builds=0,missing={},wrongSequence=false,baseMissing=false}
function donor:GetModel() return saved.model end
function donor:GetSequenceName() return 'idle' end
function donor:LookupSequence(name) return name=='idle' and not self.baseMissing and 1 or -1 end
function donor:LookupBone(name) return sourceRig.names[name] end
function donor:SetPos() end;function donor:SetAngles() end
function donor:ResetSequence(id) if clock>self.created and not self.wrongSequence then self.sequence=id end end
function donor:GetSequence() return self.sequence end
function donor:SetLOD(lod) self.lod=lod end;function donor:SetIK(ik) self.ik=ik end
function donor:SetCycle(c) self.cycle=c end;function donor:SetPlaybackRate(rate) self.rate=rate end
function donor:GetNumPoseParameters() return 0 end;function donor:InvalidateBoneCache() end
function donor:SetupBones() self.builds=self.builds+1 end
function donor:GetBoneMatrix(i)
 self.reads=self.reads+1
 if self.missing[i] then return end
 if self.sequence~=1 then return Matrix() end
 return sourceRig.bones[i].bind
end
ix.sharedPoses={Rig=function(model) return available and modelRigs[model] end,Probe=function() return donor end,BaseSequence=function() return 1 end}
local function target(index)
 local rig=all[index];local model=index==1 and saved.model or 'models/player/target'..index..'.mdl';modelRigs[model]=rig
 return {valid=true,model=model,rig=rig,written={},GetModel=function(self) return self.model end,
 LookupSequence=function(_,name) return name=='idle' and 1 or -1 end,LookupBone=function(_,name) return rig.names[name] end,
 GetSequenceName=function() return 'idle' end,GetBoneCount=function() return rig.count end,
 GetBoneName=function(_,i) return rig.bones[i].name end,GetBoneParent=function(_,i) return rig.bones[i].parent end,
 GetBoneMatrix=function(_,i) return rig.bones[i].bind end,SetBoneMatrix=function(self,i,m) self.written[i]=m end,
 GetPos=function() return vector_origin end,GetAngles=function() return angle_zero end,GetRenderAngles=function() return angle_zero end,
 GetModelScale=function() return 1 end}
end
local function ready(p,state) S.PrepareLayer(p,state);clock=clock+1;return S.PrepareLayer(p,state) end
`;
module.exports={env,toLua};
if(require.main===module){
run('Saved salute waits for a real base sample, then transfers onto nine compiled humanoid rigs without changing native legs',env+`
 local c=assert(S.Validate(saved));eq(c.mask,'upper');local first={clip=c,transforms=c.frames[1].bones}
 eq(S.PrepareLayer(target(1),first),false);eq(donor.builds,0);eq(donor.reads,0);assert(first.referenceLoading)
 clock=clock+1;assert(S.PrepareLayer(target(1),first));eq(donor.sequence,1);eq(donor.lod,0);eq(donor.ik,false)
 eq(donor.builds,1)
 for n=1,#all do
  local p=target(n);local state={clip=c,transforms=c.frames[1].bones};assert(S.PrepareLayer(p,state));S.ApplyLayer(p,state)
  assert(p.written[p.rig.names['ValveBiped.Bip01_R_Hand']]);eq(p.written[p.rig.names['ValveBiped.Bip01_Pelvis']],nil)
  eq(p.written[p.rig.names['ValveBiped.Bip01_L_Foot']],nil);eq(p.written[p.rig.names['ValveBiped.Bip01_R_Foot']],nil)
 end
 eq(donor.builds,1);eq(saved.frames[1].bones['ValveBiped.Bip01_R_Forearm'].a[2],-117.338)
`);
run('A slow creation frame cannot cache initial matrices even when the default sequence ID already matches',env+`
 referenceFrame=10;donor.sequence=1
 donor.GetBoneMatrix=function(self,i)
  self.reads=self.reads+1
  return referenceFrame==10 and Matrix() or sourceRig.bones[i].bind
 end
 eq(S.ToolReference(saved),nil);clock=clock+.1
 eq(S.ToolReference(saved),nil);eq(donor.builds,0);eq(donor.reads,0)
 referenceFrame=11
 local sample=assert(S.ToolReference(saved));eq(donor.builds,1)
 same(sample.locals[sourceRig.bones[0].name],sourceRig.bones[0].localBind)
 eq(S.ToolReference(saved),sample);eq(donor.builds,1)
`);
run('Incomplete source skeleton reports the actual bone and retries successfully without replacing saved rotations',env+`
 local p=target(2);local state={clip=saved};local index=sourceRig.names['ValveBiped.Bip01_R_Forearm']
 donor.missing[index]=true;eq(ready(p,state),false);assert(state.referenceError:find('R_Forearm',1,true));eq(state.reference,nil)
 local reads=donor.reads;S.PrepareLayer(p,state);eq(donor.reads,reads)
 donor.missing[index]=nil;clock=clock+1;assert(S.PrepareLayer(p,state));eq(state.referenceError,nil)
`);
run('Wrong sequence is never cached; a recovered donor uses the original base and cycle',env+`
 local p=target(1);local state={clip=table.Copy(saved)};state.clip.cycle=.4;donor.wrongSequence=true
 eq(ready(p,state),false);eq(donor.reads,0);assert(state.referenceError:find('idle',1,true))
 donor.wrongSequence=false;clock=clock+1;assert(S.PrepareLayer(p,state));near(donor.cycle,.4)
`);
run('Interleaved clips sharing one donor preserve distinct base/cycle samples after warmup and external sequence changes',env+`
 local p=target(2);local a={clip=table.Copy(saved)};local b={clip=table.Copy(saved)}
 b.clip.base='other_idle';b.clip.cycle=.75
 donor.LookupSequence=function(_,name) return name=='idle' and 1 or name=='other_idle' and 2 or -1 end
 donor.GetBoneMatrix=function(self,i)
  self.reads=self.reads+1;local matrix=sourceRig.bones[i].bind*Matrix()
  local shift=Vector(self.sequence*10+self.cycle,0,0);matrix:SetTranslation(matrix:GetTranslation()+shift);return matrix
 end
 eq(S.PrepareLayer(p,a),false);eq(S.PrepareLayer(p,b),false);eq(donor.builds,0)
 clock=clock+1;assert(S.PrepareLayer(p,a));donor.sequence=99;assert(S.PrepareLayer(p,b))
 local root=sourceRig.bones[0].name;local pa=a.reference.locals[root]:GetTranslation();local pb=b.reference.locals[root]:GetTranslation()
 near(pb.x-pa.x,10.75);eq(donor.builds,2)
 donor.sequence=99;assert(S.PrepareLayer(p,a));assert(S.PrepareLayer(p,b));near(a.reference.locals[root]:GetTranslation().x,pa.x);eq(donor.builds,2)
`);
run('Missing model and animation errors survive compatibility validation; retry invalidates all live states',env+`
 local p=target(2);local state={clip=saved};donor.baseMissing=true
 eq(S.PrepareLayer(p,state),false);assert(state.referenceError);eq(donor.builds,0)
 donor.baseMissing=false;clock=clock+1;assert(ready(p,state));local sample=state.reference
 S.RetryReferences();eq(S.PrepareLayer(p,state),false);eq(state.reference,nil)
 clock=clock+1;assert(S.PrepareLayer(p,state));assert(state.reference~=sample)
`);
run('Unrendered optional fingers do not block the salute, while a missing shoulder ancestor cannot become a world-space local',env+`
 local p=target(2);local state={clip=saved}
 for name,i in pairs(sourceRig.names) do if name:find('Finger',1,true) then donor.missing[i]=true end end
 assert(ready(p,state));S.RetryReferences();state={clip=saved}
 donor.missing[sourceRig.names['ValveBiped.Bip01_R_Clavicle']]=true
 eq(ready(p,state),false);assert(state.referenceError);eq(state.reference,nil)
`);

run('Embedded anatomical reference preserves a saved salute across nine rigs after its original model is removed',env+`
 local c=assert(S.Validate(saved));local p=target(2)
 eq(S.CaptureReference(c,p),false);clock=clock+1;assert(S.CaptureReference(c,p))
 eq(c.version,4);assert(#c.reference.bones<=53);eq(c.reference.recovered,false)
 local expected={}
 for n=1,#all do local entity=target(n);local state={clip=saved,transforms=saved.frames[1].bones};assert(S.PrepareLayer(entity,state));S.ApplyLayer(entity,state);expected[n]=entity.written end
 c=assert(S.Validate(table.Copy(c)))
 modelRigs[saved.model]=nil
 ix.sharedPoses.Rig=function(model) return modelRigs[model] end
 ix.sharedPoses.Probe=function() error('embedded clips must not probe a source asset') end
 for n=2,#all do
  local entity=target(n);local state={clip=c,transforms=c.frames[1].bones}
  assert(S.ModelSupports(entity,c));assert(S.PrepareLayer(entity,state));S.ApplyLayer(entity,state)
  for i,matrix in pairs(entity.written) do
   local wanted=expected[n][i];assert(wanted)
   for r=1,3 do for col=1,4 do assert(math.abs(matrix[r][col]-wanted[r][col])<.05,'reference rounding drift') end end
  end
  eq(entity.written[entity.rig.names['ValveBiped.Bip01_L_Foot']],nil)
 end
 eq(c.frames[1].bones['ValveBiped.Bip01_R_Forearm'].a[2],-117.338)
`);
run('Legacy absent-source recovery samples the current compatible model and keeps every authored key unchanged',env+`
 local c=assert(S.Validate(saved));local p=target(2);local rig=p.rig
 donor.valid=false;modelRigs[c.model]=nil
 local substitute=table.Copy(donor);substitute.valid=true;substitute.sequence=1
 substitute.GetModel=function() return p:GetModel() end
 substitute.GetBoneMatrix=function(_,i) return rig.bones[i].bind end
 substitute.LookupBone=function(_,name) return rig.names[name] end
 ix.sharedPoses.Rig=function(model) return modelRigs[model] end
 ix.sharedPoses.Probe=function(model) return model==p:GetModel() and substitute or nil end
 assert(S.ModelSupports(p,c));eq(S.PrepareLayer(p,{clip=c}),false);clock=clock+1
 local state={clip=c,transforms=c.frames[1].bones};assert(S.PrepareLayer(p,state));eq(state.reference.recovered,true)
 S.ApplyLayer(p,state);assert(p.written[rig.names['ValveBiped.Bip01_R_Hand']])
 assert(S.CaptureReference(c,p));eq(c.reference.recovered,true);eq(c.reference.rigModel,p:GetModel())
 eq(c.model,saved.model);eq(c.frames[1].bones['ValveBiped.Bip01_R_Forearm'].a[2],-117.338)
 ix.sharedPoses.Probe=function() error('source asset still required') end
 local other=target(3);assert(S.ModelSupports(other,c));assert(S.PrepareLayer(other,{clip=c}))
`);
run('Reference validation rejects cyclic parents, unknown or duplicate bones, unsafe offsets and metadata mismatches',env+`
 local c=assert(S.Validate(saved));S.CaptureReference(c,target(2));clock=clock+1;assert(S.CaptureReference(c,target(2)))
 local function reject(change) local bad=table.Copy(c);change(bad.reference);eq(S.Validate(bad),nil) end
 reject(function(r) r.bones[1].parent=0 end)
 reject(function(r) r.bones[2].parent=1 end)
 reject(function(r) r.bones[2].name=r.bones[1].name end)
 reject(function(r) r.bones[1].name='unknown' end)
 reject(function(r) r.bones[1].bind.p[1]=math.huge end)
 reject(function(r) r.bones[1].base.a[1]=0/0 end)
 reject(function(r) r.bones[1].base.p[1]=r.bones[1].bind.p[1]+65 end)
 reject(function(r) r.base='changed' end)
 reject(function(r) r.rigModel='models/../invalid.mdl' end)
 reject(function(r) r.bones.extra={} end)
 local bad=table.Copy(c);table.remove(bad.reference.bones);bad.reference.bones[1].parent=-1
 -- Structurally valid but missing core anatomy is rejected by the server gate.
 for _,row in ipairs(bad.reference.bones) do if row.name=='ValveBiped.Bip01_Head1' then row.name='ValveBiped.Bip01_Spine4' end end
 local valid=S.Validate(bad);if valid then eq(S.ModelSupports(target(2),valid),false) end
`);
run('Changing embedded reference identity invalidates live retargeting state and cannot reuse stale sampled matrices',env+`
 local c=assert(S.Validate(saved));S.CaptureReference(c,target(2));clock=clock+1;assert(S.CaptureReference(c,target(2)))
 local p=target(2);local state={clip=c};assert(S.PrepareLayer(p,state));local before=state.reference
 local nextRef=table.Copy(c.reference)
 for _,bone in ipairs(nextRef.bones) do if bone.name=='ValveBiped.Bip01_R_Hand' then bone.base.a[1]=bone.base.a[1]+10 end end
 c.reference=nextRef;assert(S.PrepareLayer(p,state));assert(state.reference~=before)
`);

// Load real editor registration and call its error drawing path, catching stale local-variable mistakes.
run('Editor displays the exact reason and emits one delayed diagnostic per distinct error',`
ix.PoseStudio={};function RealTime() return clock end;surface={CreateFont=function() end};Color=function(...) return {...} end
local views={};vgui={Register=function(name,panel) views[name]=panel end}
`+source(['ixhl2rp/plugins/pose_studio/cl_editor.lua'])+`
local view=views.ixPoseStudioViewport;assert(view)
draw={RoundedBox=function() end,SimpleText=function(text) lastText=text end};ScrW=function() return 1920 end;ScrH=function() return 1080 end
local messages={};print=function(text) messages[#messages+1]=text end
local p={BaseClass={Paint=function() end},showBones=false,PaintRotationGizmo=function() end,rings={},points={},editor={clip={model='models/source.mdl',base='idle'}},
 Entity={GetModel=function() return 'models/target.mdl' end},state={referenceError='Missing arm'},layerReady=false}
view.Paint(p,900,500);clock=clock+3;view.Paint(p,900,500);eq(#messages,1);assert(messages[1]:find('Missing arm',1,true));assert(messages[1]:find('models/target.mdl',1,true))
view.Paint(p,900,500);eq(#messages,1);p.layerReady=true;view.Paint(p,900,500);eq(p.lastReferenceError,nil)
`);
finish();
}
