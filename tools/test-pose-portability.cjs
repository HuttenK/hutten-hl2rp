module.exports=function(suite,F){
 const {shared,server,client,editor,gizmo,common,serverFixture,editorFixture}=F;
 const renderer='ixhl2rp/plugins/pose_studio/cl_rig.lua';
 const matrices='tools/fixtures/sharedposes.lua';
 const sharedRig='helix/plugins/act/sh_sharedposes.lua';
 const rigs=`
  function FrameNumber() return math.floor(clock*60) end
  local R=ix.sharedPoses
  prefix='ValveBiped.Bip01_'
  function makeRig(height,extra)
   local rig={height=height or 30,bones={},names={},count=0}
   local function bone(name,parent)
    local i=rig.count; rig.count=i+1; name=prefix..name
    rig.names[name]=i; rig.bones[i]={name=name,parent=parent and rig.names[prefix..parent] or -1,localBind=Matrix()}
   end
   bone('Pelvis'); bone('Spine','Pelvis'); bone('Spine1','Spine'); bone('Spine2','Spine1'); bone('Neck1','Spine2'); bone('Head1','Neck1')
   for _,side in ipairs({'L_','R_'}) do
    bone(side..'Clavicle','Spine2')
    if extra then bone(side..'twist_driver',side..'Clavicle') end
    bone(side..'UpperArm',extra and side..'twist_driver' or side..'Clavicle'); bone(side..'Forearm',side..'UpperArm'); bone(side..'Hand',side..'Forearm')
    bone(side..'Finger0',side..'Hand'); bone(side..'Thigh','Pelvis'); bone(side..'Calf',side..'Thigh'); bone(side..'Foot',side..'Calf')
   end
   return rig
  end
  sourceRig=makeRig(30); targetRig=makeRig(36)
  local sourceModel='models/player/kleiner.mdl'
  R.Rig=function(model) return model==sourceModel and sourceRig or model=='models/player/alyx.mdl' and targetRig end
  donor={valid=true,GetModel=function() return sourceModel end,LookupSequence=function(_,name) return name=='idle' and 1 or -1 end}
  function donor:LookupBone(name) return sourceRig.names[name] end
  R.Probe=function(model) return model==sourceModel and donor end
  R.BaseSequence=function() return 2 end
  function portableClip(mask)
   local c=makeClip(); c.portable=true; c.mask=mask or 'full'; c.frames[1].bones={[prefix..'L_Hand']={a={0,0,0},p={0,0,0}}}; return c
  end
  function targetPlayer(p)
   p.model='models/player/alyx.mdl'
   p.LookupBone=function(_,name) return targetRig.names[name] end
   p.LookupSequence=function(_,name) return name=='target_idle' and 2 or -1 end
   p.GetSequenceName=function(_,id) return id==2 and 'target_idle' or 'unknown' end
   return p
  end
 `;
 suite('Portable clips: legacy defaults, bone masks and malformed modes are validated', [shared], `
  local S=ix.PoseStudio
  local legacy=S.Validate(makeClip()); eq(legacy.version,3); eq(legacy.portable,false); eq(legacy.mask,'full')
  local c=makeClip(); c.mask='legs'; eq(S.Validate(c),nil)
  c=makeClip(); c.portable='true'; eq(S.Validate(c),nil)
  c=makeClip(); c.portable=true; eq(S.Validate(c),nil)
  c.frames[1].bones={['ValveBiped.Bip01_L_Hand']=S.Identity()}; assert(S.Validate(c))
  c.mask='upper'; assert(S.Validate(c))
  c.frames[1].bones['ValveBiped.Bip01_Pelvis']=S.Identity(); eq(S.Validate(c),nil)
  c.frames[1].bones['ValveBiped.Bip01_Pelvis']=nil
  local prop=S.Identity(); prop.model='models/props_junk/garbage_mug001a.mdl'; prop.bone='ValveBiped.Bip01_L_Foot'; prop.scale=1; prop.skin=0
  c.props={prop}; eq(S.Validate(c),nil); prop.bone='ValveBiped.Bip01_L_Hand'; assert(S.Validate(c))
 `,common);
 suite('Cellar editor bones: all modes exclude helpers, retain legacy keys and respect source bones and upper masks', [matrices,sharedRig,shared], rigs+`
  local S=ix.PoseStudio; eq(count(S.humanoidBones),53)
  local c=portableClip(); sourceRig=makeRig(30,true)
  for _,portable in ipairs({false,true}) do
   c.portable=portable
   eq(S.EditableBone(c,prefix..'L_Hand'),true); eq(S.EditableBone(c,prefix..'L_Finger0'),true)
   eq(S.EditableBone(c,prefix..'L_Thigh'),true)
   for _,name in ipairs({prefix..'L_twist_driver','ValveBiped.forward','ValveBiped.Anim_Attachment_RH','coat_helper'}) do
    eq(S.EditableBone(c,name),false)
   end
   c.mask='upper'; eq(S.EditableBone(c,prefix..'L_Thigh'),false); eq(S.EditableBone(c,prefix..'L_Hand'),true); c.mask='full'
  end
  eq(S.EditableBone(c,prefix..'L_Finger42'),false)
  c.portable=false; c.frames[1].bones.coat_helper=S.Identity(); c.frames[1].bones.coat_helper.a[1]=32
  local saved=assert(S.Validate(c)); eq(saved.frames[1].bones.coat_helper.a[1],32)
  eq(S.EditableBone(saved,'coat_helper'),false)
 `,common);
 suite('Portable rigs: missing optional fingers degrade gracefully; attachment anchors and body anatomy remain enforced', [matrices,sharedRig,shared], rigs+`
  local S=ix.PoseStudio; local c=portableClip(); local p=targetPlayer({valid=true,GetModel=function(self) return self.model end})
  assert(S.ModelSupports(p,c)); eq(S.TargetBase(p,c),'target_idle')
  c.portable=false; eq(S.ModelSupports(p,c),false); c.portable=true
  c.base='missing'; eq(S.ModelSupports(p,c),true); c.base='idle'
  c.frames[1].bones[prefix..'L_Finger0']=S.Identity()
  targetRig=makeRig(36); local finger=targetRig.names[prefix..'L_Finger0']; targetRig.names[prefix..'L_Finger0']=nil
  eq(S.ModelSupports(p,c),true)
  local prop=S.Identity(); prop.model='models/cup.mdl'; prop.bone=prefix..'L_Finger0'; prop.scale=1; prop.skin=0
  c.props={prop}; eq(S.ModelSupports(p,c),false); c.props={}
  targetRig=makeRig(36); targetRig.bones[targetRig.names[prefix..'L_Hand']].parent=0; eq(S.ModelSupports(p,c),false)
  targetRig=makeRig(36)
  targetRig.height=80; eq(S.ModelSupports(p,c),false); targetRig.height=36
  assert(S.ModelSupports(p,c)); donor.valid=false; eq(S.ModelSupports(p,c),true)
 `,common);
 suite('Upper-body server: locomotion stays native; attack, external acts and model changes stop playback', [matrices,sharedRig,shared,server], rigs+`
  local p=targetPlayer(user(1)); local c=portableClip('upper')
  put(p,c); eq(reply().kind,'saved'); local r=owned(p)
  p.ForceSequence=function() error('upper body must not force a sequence') end
  p.SetCycle=function() error('upper body must not freeze the cycle') end
  p.SetPlaybackRate=function() error('upper body must not change the playback rate') end
  p.OnGround=function() return false end
  p.GetVelocity=function() return {Length2DSqr=function() return 5000 end} end
  p.GetPos=function() return {DistToSqr=function() return 10000 end} end
  local function play() clock=clock+2; PLUGIN:PlayPose(p,r); assert(PLUGIN.poseActive[p]); eq(p.vars.ixPoseStudioUpperBody,true) end
  play(); local removed={}; local key=IN_DUCK
  local cmd={GetForwardMove=function() return 100 end,GetSideMove=function() return 80 end,GetUpMove=function() return 1 end,
   KeyDown=function(_,k) return k==key end,RemoveKey=function(_,k) removed[k]=true end}
  PLUGIN:StartCommand(p,cmd); assert(PLUGIN.poseActive[p]); key=IN_JUMP; PLUGIN:StartCommand(p,cmd); PLUGIN:Think(); assert(PLUGIN.poseActive[p])
  key=IN_ATTACK; PLUGIN:StartCommand(p,cmd); eq(PLUGIN.poseActive[p],nil); eq(p.vars.ixPoseStudioUpperBody,false); eq(p.left,nil); eq(removed[IN_ATTACK],true)
  play(); p.vars.forcedSequence=42; PLUGIN:Think(); eq(PLUGIN.poseActive[p],nil); eq(p.vars.forcedSequence,42); eq(p.left,nil)
  p.vars.forcedSequence=nil; play(); p.model='models/other.mdl'; PLUGIN:Think(); eq(PLUGIN.poseActive[p],nil)
  p.model='models/player/alyx.mdl'; play(); p.active={valid=true,GetClass=function() return 'weapon_pistol' end}; PLUGIN:Think(); eq(PLUGIN.poseActive[p],nil)
  p.active=nil; play(); PLUGIN:PlayerDeath(p); eq(PLUGIN.poseActive[p],nil)
 `,serverFixture);
 suite('Portable access: import, radial, preview and placement retain server authorization',
  [matrices,sharedRig,shared,server,'ixhl2rp/plugins/pose_studio/sh_placement.lua','ixhl2rp/plugins/pose_studio/sv_placement.lua','ixhl2rp/plugins/pose_studio/sv_radial.lua'], rigs+`
  local p=targetPlayer(user(1)); put(p,portableClip('upper')); local r=owned(p)
  local q=targetPlayer(user(2))
  q.GetVelocity=function() return {Length2DSqr=function() return 0 end} end
  PLUGIN:PoseRadial(q,{token=1,mode='shared'}); eq(#reply().clips,0)
  eq(PLUGIN:ResolvePoseSelection(q,{kind='custom',id=r.id}),nil)
  r.status='approved'; PLUGIN:PoseRadial(q,{token=2,mode='shared'}); eq(#reply().clips,1); eq(reply().clips[1].mask,'upper')
  assert(PLUGIN:ResolvePoseSelection(q,{kind='custom',id=r.id}))
  PLUGIN:HandlePose(q,{op='import',id=r.id}); eq(reply().kind,'saved'); eq(owned(q).clip.model,r.clip.model)
  PLUGIN:PlacePose(q,{selection={kind='custom',id=r.id}}); eq(reply().kind,'error'); eq(PLUGIN.posePlaced[q],nil)
  targetRig.height=80; PLUGIN:PoseRadial(q,{token=3,mode='shared'}); eq(#reply().clips,1); eq(reply().clips[1].available,false); assert(reply().clips[1].reason)
  eq(PLUGIN:ResolvePoseSelection(q,{kind='custom',id=r.id}),nil)
 `,serverFixture);
 suite('Legacy saves: safe portable migration preserves keys/approval/ownership, backs up originals, rejects stale saves and runs once',
  [matrices,sharedRig,shared,server,'ixhl2rp/plugins/pose_studio/sv_radial.lua'], rigs+`
  local S=ix.PoseStudio; local p=targetPlayer(user(1))
  local old=portableClip(); old.portable=false; old.version=2
  local special=table.Copy(old); special.frames[1].bones.CustomHelper=S.Identity()
  local deliberate=table.Copy(old); deliberate.version=3
  saved={nextID=4,props={},clips={
   ['1']={id=1,clip=old,owner=p.id,author='Original author',status='approved',revision=6},
   ['2']={id=2,clip=special,owner=p.id,status='private',revision=2},
   ['3']={id=3,clip=deliberate,owner=p.id,status='private',revision=4}}}
  local before=table.Copy(saved);local writes=0
  PLUGIN.SetData=function() writes=writes+1 end
  PLUGIN:LoadData();eq(writes,0); local store=PLUGIN.poseStore; local r=store.clips['1']
  eq(r.clip.portable,true); eq(r.clip.version,3); eq(r.revision,7); eq(r.status,'approved'); eq(r.owner,p.id); eq(r.author,'Original author')
  eq(util.TableToJSON(r.clip.frames),util.TableToJSON(S.Validate(old).frames)); eq(r.clip.model,old.model); eq(r.clip.base,old.base)
  eq(util.TableToJSON(store.portabilityBackups['1']),util.TableToJSON(before.clips['1']))
  eq(store.clips['2'].clip.portable,false); assert(store.clips['2'].clip.frames[1].bones.CustomHelper)
  eq(store.clips['3'].clip.portable,false); eq(store.clips['3'].revision,4)
  PLUGIN:PoseRadial(p,{token=5,mode='own'}); local visible={}; for _,c in ipairs(reply().clips) do visible[c.id]=c end
  eq(visible[1].available,true); eq(visible[3].available,false); assert(visible[3].reason)
  PLUGIN:SavePose(p,{id=1,revision=6,clip=old}); eq(reply().kind,'error'); eq(store.clips['1'].clip.portable,true)
  PLUGIN:LoadData();eq(writes,0); eq(PLUGIN.poseStore.clips['1'].revision,7); eq(count(PLUGIN.poseStore.portabilityBackups),1)
  eq(util.TableToJSON(PLUGIN.poseStore.portabilityBackups['1']),util.TableToJSON(before.clips['1']))
  donor.valid=false; local unmounted,changed=S.MigrateLegacyClip(old); eq(unmounted.portable,true); eq(changed,true); eq(unmounted.version,3)
  donor.valid=true; local retried,converted=S.MigrateLegacyClip(unmounted); eq(converted,false); eq(retried.portable,true)
 `,serverFixture);
 suite('Portable retargeting: different reference elbow angles cannot bias the finished pose; target lengths and offsets survive', [matrices,shared], `
  local S=ix.PoseStudio
  local source={localBind=rotation(30)}; source.localBind:SetTranslation(Vector(10,0,0))
  local target={localBind=rotation(-20)}; target.localBind:SetTranslation(Vector(16,0,0))
  local pose=source.localBind*rotation(45); pose:SetTranslation(Vector(12,2,0))
  local result=S.RetargetLocal(target,source,pose,1.5)
  near(result[1][1],math.cos(math.rad(75))); near(result[2][1],math.sin(math.rad(75)))
  near(result:GetTranslation().x,19); near(result:GetTranslation().y,3)
  local identity=S.RetargetLocal(target,source,source.localBind,1.5)
  near(identity:GetTranslation().x,16); near(identity[1][1],source.localBind[1][1])
  -- Same-model playback is unchanged, and transfers round-trip without drift.
  local same=S.RetargetLocal(source,source,pose,1)
  for row=1,4 do for col=1,4 do near(same[row][col],pose[row][col]) end end
  local back=S.RetargetLocal(source,target,result,1/1.5)
  for row=1,4 do for col=1,4 do near(back[row][col],pose[row][col]) end end
  near(pose:GetTranslation().x,12); near(source.localBind:GetTranslation().x,10); near(target.localBind:GetTranslation().x,16)
 `,common);
 suite('Upper-body matrices: pelvis/legs untouched, hand helpers inherit motion, full mode includes legs', [matrices,shared,renderer], `
  local S=ix.PoseStudio; local prefix='ValveBiped.Bip01_'
  local names={[0]=prefix..'Pelvis',prefix..'Spine',prefix..'L_Hand','coat_helper',prefix..'L_Thigh'}
  local parents={[0]=-1,0,1,2,0}
  local original={}; local source={count=5,bones={},names={},height=30}; local target={count=5,bones={},names={},height=30}; local locals={}
  for i=0,4 do
   original[i]=Matrix(); original[i]:SetTranslation(Vector(10+i,0,0))
   source.names[names[i]]=i; target.names[names[i]]=i
   source.bones[i]={name=names[i],parent=parents[i],localBind=Matrix()}; target.bones[i]={name=names[i],parent=parents[i],localBind=Matrix()}
   locals[names[i]]=Matrix(); locals[names[i]]:SetTranslation(Vector(2,0,0))
  end
  local written={}; local entity={GetBoneCount=function() return 5 end,GetBoneMatrix=function(_,i) return original[i] end,
   GetBoneParent=function(_,i) return parents[i] end,GetBoneName=function(_,i) return names[i] end,
   GetPos=function() return vector_origin end,GetAngles=function() return {} end,GetRenderAngles=function() return {} end,GetModelScale=function() return 1 end,
   SetBoneMatrix=function(_,i,m) written[i]=m end}
  local state={clip={portable=true,mask='upper'},reference={rig=source,locals=locals},targetRig=target,rigRatio=1,transforms={}}
  state.rigMap={}
  for i=0,4 do if i~=3 then state.rigMap[names[i]]={source=i,target=i,sourceAncestor=parents[i],ancestor=parents[i],sourceBind=source.bones[i],targetBind=target.bones[i]} end end
  S.ApplyLayer(entity,state); eq(written[0],nil); eq(written[4],nil)
  near(written[1]:GetTranslation().x,12); near(written[2]:GetTranslation().x,14); near(written[3]:GetTranslation().x,15)
  near(original[0]:GetTranslation().x,10); near(original[4]:GetTranslation().x,14)
  written={}; state.clip.mask='full'; S.ApplyLayer(entity,state); assert(written[0]); assert(written[4]); near(written[4]:GetTranslation().x,4)
 `,common);
 suite('Humanoid mapping: extra source helpers collapse into shared ancestors without model-name rules', [matrices,sharedRig,shared,renderer], rigs+`
  local S=ix.PoseStudio
  sourceRig=makeRig(30,true); targetRig=makeRig(30)
  local clavicle,helper,arm=sourceRig.names[prefix..'L_Clavicle'],sourceRig.names[prefix..'L_twist_driver'],sourceRig.names[prefix..'L_UpperArm']
  local targetArm=targetRig.names[prefix..'L_UpperArm']
  sourceRig.bones[clavicle].localBind:SetTranslation(Vector(2,0,0))
  sourceRig.bones[helper].localBind=rotation(30); sourceRig.bones[helper].localBind:SetTranslation(Vector(5,0,0))
  sourceRig.bones[arm].localBind=rotation(20); sourceRig.bones[arm].localBind:SetTranslation(Vector(10,0,0))
  targetRig.bones[targetRig.names[prefix..'L_Clavicle']].localBind:SetTranslation(Vector(2,0,0))
  targetRig.bones[targetArm].localBind:SetTranslation(Vector(20,0,0))
  local map=assert(S.RigMap(targetRig,sourceRig)); eq(map[prefix..'L_UpperArm'].sourceAncestor,clavicle)
  near(map[prefix..'L_UpperArm'].sourceBind.localBind:GetTranslation().x,5+10*math.cos(math.rad(30)))
  local locals={}; for i=0,sourceRig.count-1 do locals[sourceRig.bones[i].name]=sourceRig.bones[i].localBind end
  local motion=rotation(45); motion:SetTranslation(Vector(5,3,0)); locals[prefix..'L_twist_driver']=motion
  local original={}; for i=0,targetRig.count-1 do original[i]=Matrix() end
  local written={}; local entity={GetBoneCount=function() return targetRig.count end,GetBoneMatrix=function(_,i) return original[i] end,
   GetBoneParent=function(_,i) return targetRig.bones[i].parent end,GetBoneName=function(_,i) return targetRig.bones[i].name end,
   GetPos=function() return vector_origin end,GetAngles=function() return {} end,GetRenderAngles=function() return {} end,GetModelScale=function() return 1 end,
   SetBoneMatrix=function(_,i,m) written[i]=m end}
  S.ApplyLayer(entity,{clip={portable=true,mask='full'},reference={rig=sourceRig,locals=locals},targetRig=targetRig,rigMap=map,rigRatio=1,transforms={}})
  near(written[targetArm]:GetTranslation().x,22+10*(math.cos(math.rad(45))-math.cos(math.rad(30))))
  near(written[targetArm]:GetTranslation().y,3+10*(math.sin(math.rad(45))-math.sin(math.rad(30))))
  near(written[targetArm][1][1],math.cos(math.rad(65))); near(written[targetArm][2][1],math.sin(math.rad(65)))
  assert(S.RigMap(sourceRig,targetRig))
 `,common);
 suite('Pose reference sampling: cache keys follow source cycle/model, preview legs animate independently', [matrices,sharedRig,shared,renderer], rigs+`
  local S=ix.PoseStudio; local clip=portableClip('upper'); local state={clip=clip}
  local p=targetPlayer({valid=true,GetModel=function(self) return self.model end})
  local sampled=0
  donor.SetPos=function() end; donor.SetAngles=function() end; donor.ResetSequence=function() end
  donor.SetupBones=function() sampled=sampled+1 end; donor.GetBoneMatrix=function() return Matrix() end
  S.FreezeBase=function(entity,c) entity.cycle=c.cycle end
  eq(S.PrepareLayer(p,state),false); clock=clock+1
  assert(S.PrepareLayer(p,state)); eq(sampled,1); near(state.rigRatio,1.2)
  assert(S.PrepareLayer(p,state)); eq(sampled,1)
  clip.cycle=.25; assert(S.PrepareLayer(p,state)); eq(sampled,2)
  local other={clip=table.Copy(clip)}; assert(S.PrepareLayer(p,other)); eq(sampled,2)
  clip.base='missing'; eq(S.PrepareLayer(p,state),false); eq(state.reference,nil)
  clip.base='idle'; assert(S.PrepareLayer(p,state)); eq(sampled,2)
  p.LookupSequence=function(_,name) return ({target_idle=2,walk_all=3})[name] or -1 end
  p.SetSequence=function(self,id) self.sequence=id end
  p.SequenceDuration=function() return 2 end; p.SetCycle=function(self,c) self.cycle=c end; p.SetPoseParameter=function(self,k,v) self[k]=v end
  assert(S.PreviewBase(p,clip,state,1,'walk')); eq(p.sequence,3); near(p.cycle,.5); eq(p.move_x,1)
  clip.mask='full'; assert(S.PreviewBase(p,clip,state,1,'walk')); eq(p.sequence,2); near(p.cycle,.25)
  clip.model=p.model; clip.portable=false; clip.base='target_idle'; assert(S.PrepareLayer(p,state)); eq(state.reference,nil)
 `,common);
 suite('Upper-body client: synchronized target model and cleanup never freeze native walking', [shared,client], `
  local S=ix.PoseStudio; local p={valid=true,model='models/player/alyx.mdl'}
  p.GetModel=function(self) return self.model end; p.Alive=function() return true end; p.IsDormant=function() return false end
  p.InvalidateBoneCache=function() end; p.AddCallback=function() return 7 end; p.RemoveCallback=function() p.detached=true end
  p.SetPlaybackRate=function() error('upper layer must not change native playback') end
  S.PrepareLayer=function() return true end; S.FreezeBase=function() error('upper layer must not freeze native base') end
  local clip=makeClip(); clip.portable=true; clip.mask='upper'; clip.frames[1].bones={['ValveBiped.Bip01_L_Hand']=S.Identity()}
  local data={clip=clip,token='12:1',started=clock,model=p.model}
  net.ReadEntity=function() return p end; net.ReadUInt=function() return 100 end; net.ReadData=function() return util.TableToJSON(data) end
  net.handlers.ixPoseStudioState(); assert(S.playing[p]); eq(S.playing[p].model,p.model)
  hooks.ixPoseStudioPlayback(); hooks.ixPoseStudioFreeze(p); assert(S.playing[p].transforms)
  data={}; net.handlers.ixPoseStudioState(); eq(S.playing[p],nil); eq(p.detached,true)
 `,common+`
  hooks={}; hook.Add=function(_,name,callback) hooks[name]=callback end; concommand={Add=function() end}
 `);
 suite('Shared gestures: registered timed acts/transitions can use donors; arbitrary sequences remain excluded', [matrices,sharedRig,shared,'helix/plugins/act/sh_resolver.lua'], rigs+`
  local R=ix.sharedPoses
  ix.act.stored.Wave={human={sequence={'wave'},start={'wave_in'},finish={'wave_out'}}}
  ix.act.stored.Sit={human={untimed=true,sequence={'sit_hold'}}}
  eq(R.Allowed('wave'),true); eq(R.Allowed('wave_in'),true); eq(R.Allowed('wave_out'),true)
  eq(R.Allowed('arbitrary_unregistered'),false); eq(R.Animated('wave'),true); eq(R.Animated('sit_hold'),false)
  donor.LookupSequence=function(_,name) return name=='wave' and 3 or -1 end; donor.SequenceDuration=function() return 2.4 end
  local p=targetPlayer({valid=true,GetModel=function(self) return self.model end,GetSequenceCount=function() return 5 end})
  local pose=assert(R.Resolve(p,'wave')); eq(pose.animated,true); near(pose.duration,2.4); eq(pose.model,'models/player/kleiner.mdl')
  local name,id,borrowed=ix.act.Sequence(p,{'wave'}); eq(name,'wave'); eq(id,2); assert(borrowed)
  p.LookupSequence=function(_,name) return name=='wave' and 4 or 2 end
  name,id,borrowed=ix.act.Sequence(p,{'wave'}); eq(id,4); eq(borrowed,nil)
 `,common);
 suite('Shared gesture playback: synchronized donor cycle, one callback per entity, cleanup and preview restarts', [matrices,shared,client,renderer], `
  local S=ix.PoseStudio; local callbacks,removed=0,0
  local p={valid=true,GetModel=function() return 'models/player/alyx.mdl' end,
   SetPlaybackRate=function(self,value) self.rate=value end,
   AddCallback=function() callbacks=callbacks+1; return callbacks end,
   RemoveCallback=function() removed=removed+1 end,InvalidateBoneCache=function() end}
  S.PrepareLayer=function() return true end; S.FreezeBase=function() end
  local pose={model='models/player/kleiner.mdl',sequence='wave',started=clock,duration=2,animated=true}
  assert(S.ApplySharedAct(p,pose)); eq(callbacks,1); near(S.sharedActors[p].clip.cycle,0)
  clock=clock+1; assert(S.ApplySharedAct(p,pose)); eq(callbacks,1); near(S.sharedActors[p].clip.cycle,.5)
  clock=clock+5; assert(S.ApplySharedAct(p,pose)); near(S.sharedActors[p].clip.cycle,1)
  pose.started=clock; assert(S.ApplySharedAct(p,pose)); eq(callbacks,2); eq(removed,1); near(S.sharedActors[p].clip.cycle,0)
  pose.animated=false; clock=clock+1; assert(S.ApplySharedAct(p,pose)); near(S.sharedActors[p].clip.cycle,0)
  S.ClearSharedAct(p); eq(p.rate,1); eq(removed,2); eq(S.sharedActors[p],nil); S.ClearSharedAct(p); eq(removed,2)
 `,common+`concommand={Add=function() end}`);
 suite('New editor clips default to portable for generic humanoids and retain native mode for unsupported rigs', [matrices,sharedRig,shared,gizmo,editor], rigs+`
  local p=LocalPlayer(); local model='models/player/alyx.mdl'
  p.GetModel=function() return model end; p.GetSequence=function() return 0 end
  p.GetSequenceName=function() return 'idle' end; p.LookupSequence=function() return 0 end
  local e=draft(); e.SetClip=function(self,clip) self.clip=clip end
  e:NewClip(true); eq(e.clip.portable,true); eq(e.clip.mask,'full'); eq(e.clip.model,model)
  model='models/nonhumanoid.mdl'; e:NewClip(true); eq(e.clip.portable,false)
 `,editorFixture);
 suite('Editor scope: destructive filtering is confirmed, reversible and target preview does not alter saved author model', [shared,gizmo,editor], `
  util.IsValidModel=function() return true end
  local S=ix.PoseStudio; local e=draft(); e.valid=true; local hand='ValveBiped.Bip01_L_Hand'; local leg='ValveBiped.Bip01_L_Thigh'
  e.clip.frames[1].bones={[hand]=S.Identity(),[leg]=S.Identity()}; e.clip.portable=false; e.clip.mask='full'
  e.FillBones=function() end; e.viewport.valid=true; e.viewport.OnMouseReleased=function() end; e.viewport.LoadClip=function(_,c) e.rendered=c end
  S.ReferenceEntity=function() return {valid=true} end; S.ModelSupports=function() return true end
  local confirm; Derma_Query=function(_,_,_,callback) confirm=callback end
  e:ChangeScope(true,'upper'); eq(e.clip.mask,'full'); assert(confirm); confirm()
  eq(e.clip.mask,'upper'); eq(e.clip.frames[1].bones[leg],nil); assert(e.clip.frames[1].bones[hand]); eq(#e.undo,1)
  e:Undo(); eq(e.clip.mask,'full'); eq(e.clip.portable,false); assert(e.clip.frames[1].bones[leg])
  e:ChangeScope(true,'full'); eq(e.clip.portable,true); local original=e.clip.model; e.dirty=false
  eq(e.previewTarget,true);e:TogglePreviewModel(); eq(e.previewTarget,false); eq(e.clip.model,original); eq(e.dirty,false)
  e:TogglePreviewModel(); eq(e.previewTarget,true)
 `,editorFixture);
};
