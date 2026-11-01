module.exports = suite => {
 const files=['tools/fixtures/arc9-sd-pose.lua','helix/gamemode/core/libs/sh_arc9poses.lua',
  'helix/gamemode/core/libs/cl_arc9sdpose.lua','ixhl2rp/plugins/arc9_compat.lua'];
 suite('Main activity keeps a weighted idle stable between frames but follows stance/model changes and retries missing clips',
 files.slice(0,2),`
 local selections=0;local count=1625
 function p:GetSequenceCount() return count end
 function p:SelectWeightedSequence(activity)
  selections=selections+1
  if self.missing then return -1 end
  return 40+selections%2 -- Simulate two differently posed idle variants.
 end
 local resolve=ix.anim.ResolveMainSequence
 local idle=resolve(p,100,-1);eq(idle,41)
 for frame=1,120 do eq(resolve(p,100,-1),idle) end
 eq(selections,1) -- No crossfading/resetting to random variants every frame.
 eq(resolve(p,101,-1),40);eq(selections,2) -- Walk.
 eq(resolve(p,100,-1),41);eq(selections,3) -- Return to idle.
 eq(resolve(p,nil,77),77);eq(p.ixMainSequenceChoice,nil) -- Named raised stance.
 resolve(p,100,-1);eq(selections,4)
 p.model='models/sd/citizens/citizen_female_01.mdl'
 resolve(p,100,-1);eq(selections,5)
 count=count+1;resolve(p,100,-1);eq(selections,6)
 p.missing=true;eq(resolve(p,102,33),33);eq(p.ixMainSequenceChoice,nil)
 p.missing=false;eq(resolve(p,102,-1),40);eq(selections,8)
 local other={GetModel=p.GetModel,GetSequenceCount=p.GetSequenceCount,
  SelectWeightedSequence=p.SelectWeightedSequence,model=p.model}
 eq(resolve(other,102,-1),41);eq(selections,9);eq(resolve(p,102,-1),40)
 `);
 suite('SD reference can load clientside without server precaching; failed creation remains throttled and retryable',files,`
 util.IsValidModel=function() return false end
 local R=ix.arc9SDPose
 assert(R.Ready(w,p));eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil);assert(w:ShouldTPIK())
 R.Shutdown();missingModel=true;eq(R.Ready(w,p),false);eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 missingModel=false;eq(R.Ready(w,p),false)
 clock=clock+3;assert(R.Ready(w,p));R.Shutdown()
 `);
 suite('SD missing MP clips can run ARC9 arms only with a validated reference rig; native and RP gates survive',files,`
 local R=ix.arc9SDPose
 eq(ix.anim.CanUseARC9NativePose(p,w),false)
 eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil);assert(w:ShouldTPIK());eq(#donors,1)
 eq(ix.anim.GetARC9NativeActivity(p,w,ACT_MP_STAND_IDLE),nil) -- SD lower-body animation retained
 p.model='models/sd/citizens/female_01.mdl';assert(w:ShouldTPIK());eq(#donors,2);eq(removed,1)
 p.vars.forcedSequence=0;eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 p.vars.forcedSequence=nil;p.vars.sharedPose={};eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true);p.vars.sharedPose=nil
 ix.Downed={Crawling=function() return true end};eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true);ix.Downed=nil
 p.vehicle=true;eq(R.Ready(w,p),false);p.vehicle=false
 p.ground=false;eq(R.Ready(w,p),false);p.ground=true
 p.model='models/sd/missingarm.mdl';p.missingBone='ValveBiped.Bip01_R_Hand';eq(R.Ready(w,p),false)
 p.missingBone=nil;p.model='models/other/npc.mdl';eq(R.Ready(w,p),false)
 p.model='models/player/native.mdl';p.native=true;eq(PLUGIN:ARC9_Hook_BlockTPIK(w),nil);eq(R.Ready(w,p),false)
 p.native=false;p.model='models/sd/unavailable.mdl';missingModel=true
 eq(R.Ready(w,p),false);eq(PLUGIN:ARC9_Hook_BlockTPIK(w),true)
 missingModel=false;clock=clock+3;missingActivity=true;eq(R.Ready(w,p),false)
 R.Shutdown();missingActivity=false;missingDonorBone=true;eq(R.Ready(w,p),false)
 R.Shutdown();missingDonorBone=false;assert(R.Ready(w,p));R.Shutdown()
 `);
 suite('SD root adapter keeps actual chest height, samples each frame once and preserves ARC9 sequence/cycle',files,`
 local R=ix.arc9SDPose;assert(R.Ready(w,p))
 local slot={WMBase=true};local pos,ang,third=w:GetAttachmentPos(slot,true,false,false)
 eq(pos.x,100);eq(pos.y,200);eq(pos.z,64);eq(ang.y,45);eq(ang.p,-10);eq(ang.r,90)
 eq(third,'original third return');eq(w.sequence,17);eq(w.cycle,.65)
 local d=donors[1];eq(d.samples,1);eq(d.seq,400);eq(d.cycle,.5);eq(d.poses.aim_pitch,20);eq(d.poses.aim_yaw,10)
 w:GetAttachmentPos(slot,true,false,false);eq(d.samples,1)
 p.CalcIdeal=ACT_MP_CROUCH_IDLE;p.chest.z=35;frame=frame+1
 pos=w:GetAttachmentPos(slot,true,false,false);eq(pos.z,35);eq(d.seq,403);eq(d.samples,2)
 p.raised=false;w.HoldTypeHolstered='normal';frame=frame+1
 pos=w:GetAttachmentPos(slot,true,false,false);eq(d.seq,103);eq(w.hold,'normal')
 w.TPIKParentToSpine4=false;p.scale=1.2;frame=frame+1
 pos=w:GetAttachmentPos(slot,true,false,false);near(pos.x,109.6);eq(pos.z,35)
 p.yaw=180;frame=frame+1;pos,ang=w:GetAttachmentPos(slot,true,false,false);eq(ang.y,180)
 R.Shutdown();eq(removed,1)
 `);
 suite('SD adapter bypasses first-person, attachments, previews and disabled TPIK; it cleans up owner/model changes',files,`
 local R=ix.arc9SDPose;local original=w.GetAttachmentPos;assert(R.Ready(w,p))
 local wrapper=w.GetAttachmentPos;assert(wrapper~=original);R.Install(w);eq(w.GetAttachmentPos,wrapper)
 local custom=Vector(300,400,500);local angle=Angle(1,2,3);local slot={WMBase=true}
 local pos,ang=w:GetAttachmentPos(slot,true,false,false,custom,angle);eq(pos,custom);eq(ang,angle)
 w:GetAttachmentPos(slot,false,false,false);eq(w.lastCall.custompos,nil)
 w:GetAttachmentPos(slot,true,true,false);eq(w.lastCall.custompos,nil)
 w:GetAttachmentPos({},true,false,false);eq(w.lastCall.custompos,nil)
 w.disabled=true;w:GetAttachmentPos(slot,true,false,false);eq(w.lastCall.custompos,nil)
 w.disabled=false;assert(w:GetAttachmentPos(slot,true,false,false))
 p.model='models/player/native.mdl';w:GetAttachmentPos(slot,true,false,false);eq(w.lastCall.custompos,nil)
 hook.Run('Think');eq(w.GetAttachmentPos,original);eq(removed,1)
 p.model='models/sd/citizens/citizen_male_05_hair3.mdl';assert(R.Ready(w,p));hook.Run('EntityRemoved',p);eq(removed,2)
 R.Shutdown();eq(w.GetAttachmentPos,original)
 `);
 suite('Installed ARC9 root position function accepts the SD anchor while preserving offsets and cache coordinates',
 [...files,'tools/fixtures/arc9-upstream/cl_attachmentpos.lua'],`
 local R=ix.arc9SDPose;local slot={WMBase=true,Pos=Vector(-5,5,-4),Ang=Angle(),Address=0}
 assert(R.Ready(w,p));local pos,ang=w:GetAttachmentPos(slot,true,false,false)
 eq(pos.x,95);eq(pos.y,195);eq(pos.z,60);eq(ang.y,45);eq(w.attachmentHooks,1)
 -- Its cache stores weapon offsets relative to the new anchor, so moving
 -- between frames cannot leave the weapon at an old world position.
 p.chest=Vector(500,600,35);frame=frame+1
 pos=w:GetAttachmentPos(slot,true,false,false);eq(pos.x,495);eq(pos.y,595);eq(pos.z,31)
 eq(w.attachmentHooks,1)
 local preview=Vector(1000,2000,3000)
 pos=w:GetAttachmentPos(slot,true,false,false,preview,Angle());eq(pos.x,995);eq(pos.y,1995);eq(pos.z,2996)
 R.Shutdown()
 `);
};
