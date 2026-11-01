const {run,source,native,read,finish}=require('./restored-test-runner.cjs');
const toLua=v=>Array.isArray(v)?'{'+v.map(toLua).join(',')+'}':v&&typeof v==='object'?'{'+Object.entries(v).map(([k,x])=>'['+JSON.stringify(k)+']='+toLua(x)).join(',')+'}':JSON.stringify(v);
const rigs=JSON.parse(read('tools/fixtures/pose-starter-rigs.json'));
const geometry=`ix.PoseStudio={};ix.util={Include=function() end};function RealTime() return clock end
function math.Round(v,d) local k=10^(d or 0);return math.floor(v*k+.5)/k end
function isvector(v) return type(v)=='table' and getmetatable(v)==getmetatable(Vector()) end
`+source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','ixhl2rp/plugins/pose_studio/sh_clip.lua','ixhl2rp/plugins/pose_studio/sh_rig.lua','ixhl2rp/plugins/action_animations/sh_ik.lua','ixhl2rp/plugins/pose_studio/cl_targets.lua'])+`
local S,K=ix.PoseStudio,ix.LimbIK;local V=getmetatable(Vector());local M=getmetatable(Matrix())
function V:DistToSqr(b) return (self-b):Dot(self-b) end
function M:GetField(r,c) return self[r][c] end
function M:SetAngles(a) local axes={a:Forward(),-a:Right(),a:Up()};for c,v in ipairs(axes) do self:SetField(1,c,v.x);self:SetField(2,c,v.y);self:SetField(3,c,v.z) end end
function M:GetAngles() return Angle(math.deg(math.atan(-self[3][1],math.sqrt(self[1][1]^2+self[2][1]^2))),math.deg(math.atan(self[2][1],self[1][1])),math.deg(math.atan(self[3][2],self[3][3]))) end
local actualRigs=${toLua(rigs)}
function closeVec(a,b,e) assert((a-b):Length()<(e or .002),tostring((a-b):Length())) end
function reference(data)
 local rig={count=#data.bones,bones={},names={},height=40};local locals={}
 for n,b in ipairs(data.bones) do
  local i=n-1;local inverse=Matrix();for r=1,3 do for c=1,4 do inverse:SetField(r,c,b.inverse[(r-1)*4+c]) end end
  local bind=inverse:GetInverse();local localBind=b.parent>=0 and rig.bones[b.parent].inverse*bind or bind
  rig.bones[i]={name=b.name,parent=b.parent,bind=bind,inverse=inverse,localBind=localBind};rig.names[b.name]=i
  local baseDelta=Matrix();baseDelta:SetAngles(Angle(4,-7,5));locals[b.name]=localBind*baseDelta
 end
 ix.sharedPoses={Rig=function() return rig end};return {rig=rig,locals=locals}
end
function clip()
 return {version=3,name='Target',model='models/player/test.mdl',base='idle',cycle=0,portable=true,mask='full',loop=true,smooth=true,
 frames={{duration=1,bones={}},{duration=.5,bones={}}},props={}}
end
`;
run('Two-bone targets handle reach limits, zero-distance goals, collinear poles and 180-degree turns without stretching',geometry+`
 local root,joint,tip=Vector(),Vector(10,0,0),Vector(20,0,0)
 for _,target in ipairs({Vector(12,7,0),Vector(100,0,0),Vector(),Vector(-18,0,0)}) do
  local elbow,wrist=K.Solve(root,joint,tip,target,Vector(1,0,0));assert(elbow and wrist)
  near((elbow-root):Length(),10);near((wrist-elbow):Length(),10);assert(wrist.x==wrist.x)
 end
 local rotated=K.Rotation(Vector(1,0,0),Vector(-1,0,0),Vector())
 local tipMatrix=Matrix();tipMatrix:SetTranslation(Vector(10,0,0));closeVec((rotated*tipMatrix):GetTranslation(),Vector(-10,0,0))
 eq(K.Solve(root,root,tip,Vector(1,2,3),Vector(0,1,0)),nil)
`);
run('All four targets bake into v3 rotations on eight actual humanoid rigs, preserve segment lengths/offsets and the other limbs',geometry+`
 local tested=0
 for _,data in ipairs(actualRigs) do
  local ref=reference(data);local c=clip()
  for _,side in ipairs({'L','R'}) do for _,part in ipairs({'Hand','Foot'}) do
   local name='ValveBiped.Bip01_'..side..'_'..part;local bones={}
   bones[name]={a={12,3,-9},p={.12,-.08,.06}}
   local target=assert(S.MakeTarget(ref,c,bones,name));local original=target.matrices
   local root=original[target.chain[1]]:GetTranslation();local tip=original[target.chain[3]]:GetTranslation()
   local goal=root+(tip-root)*.75+Vector(1,-2,3)
   for _,bend in ipairs({0,70,-135}) do
    local baked,err,reached=S.SolveTarget(target,goal,bend);assert(baked,err)
    local posed=S.TargetWorld(ref,baked);closeVec(posed[target.chain[3]]:GetTranslation(),reached,.01)
    for i=1,2 do local a,b=target.chain[i],target.chain[i+1]
     assert(math.abs((posed[b]:GetTranslation()-posed[a]:GetTranslation()):Length()-(original[b]:GetTranslation()-original[a]:GetTranslation()):Length())<.002)
    end
    for i,m in pairs(original) do if not K.Descendant(target.parents,i,target.chain[1]) then
     for r=1,3 do for col=1,4 do near(posed[i]:GetField(r,col),m:GetField(r,col)) end end
    end end
    eq(baked[name].p[1],.12);eq(bones[name].a[1],12)
    c.frames[1].bones=baked;assert(S.Validate(c));tested=tested+1
   end
  end end
 end
 eq(tested,96)
`);
run('Target editing respects upper masks, missing joints, model-only hidden keys and authored helper chains',geometry+`
 local ref=reference(actualRigs[1]);local c=clip();c.mask='upper'
 eq(S.MakeTarget(ref,c,{},'ValveBiped.Bip01_R_Foot'),nil)
 eq(S.MakeTarget(ref,c,{},'ValveBiped.Bip01_R_Forearm'),nil)
 local hand='ValveBiped.Bip01_R_Hand';assert(S.MakeTarget(ref,c,{},hand))
 ref.rig.names['ValveBiped.Bip01_R_Forearm']=nil;eq(S.MakeTarget(ref,c,{},hand),nil)
 ref=reference(actualRigs[1]);c.mask='full';c.portable=false
 local hidden=next(ref.locals);local bones={hidden_attachment={a={2,3,4},p={1,0,0}}}
 local t=assert(S.MakeTarget(ref,c,bones,hand));local result=assert(S.SolveTarget(t,t.goal+Vector(2,0,1),30))
 eq(result.hidden_attachment.a[1],2);eq(bones[hand],nil)
`);
const editor='ixhl2rp/plugins/pose_studio/cl_editor.lua';
run('Native target drag owns one undo entry, supports bend/fine adjustment and current-model preview; rejects stale frames',geometry+`
 local VIEW={};local KEY_LSHIFT=1;input={IsKeyDown=function() return false end}
 ${native(editor,'function VIEW:StartTargetDrag(name,x,y)','function VIEW:DragRotation(x,y,dx,dy)')}
 ${native(editor,'function VIEW:OnMouseWheeled(delta)','function VIEW:StartTargetDrag(name,x,y)')}
 local ref=reference(actualRigs[1]);S.ToolReference=function() return ref end
 local c=clip();local hand='ValveBiped.Bip01_R_Hand'
 local e={clip=c,frame=1,selectedBone=hand,targetMode=true,undo=0}
 function e:Checkpoint() self.undo=self.undo+1 end;function e:Dirty() self.dirty=true end
 function e:CommitBoneEdit(bones,names,checkpoint) eq(checkpoint,false);eq(#names,3);self.clip.frames[self.frame].bones=bones;self:Dirty();return true end
 function e:RefreshFields() end;function e:Message(v) self.message=v end
 local view=setmetatable({editor=e,Entity={GetModel=function() return c.model end},poseMatrices=S.TargetWorld(ref,c.frames[1].bones),poseMatrixClip=c,poseMatrixFrame=1},{__index=VIEW})
 function view:GetLookAt() return Vector(0,0,40) end;function view:GetCamPos() return Vector(100,0,40) end
 function view:GetFOV() return 34 end;function view:GetWide() return 1000 end
 function view:OnMouseReleased() self.drag=nil end
 view:StartTargetDrag(hand,100,100);eq(e.undo,1);eq(view.drag.kind,'target')
 view:DragTarget(20,-10);assert(e.dirty);assert(c.frames[1].bones[hand]);eq(next(c.frames[2].bones),nil)
 view:OnMouseWheeled(1);eq(view.drag.bend,10);eq(e.undo,1)
 input.IsKeyDown=function() return true end;view:OnMouseWheeled(-1);eq(view.drag.bend,8)
 e.frame=2;view:DragTarget(10,10);eq(view.drag,nil)
 e.frame=1;e.previewTarget=true;view:StartTargetDrag(hand,0,0);eq(e.undo,2);assert(view.drag)
 e.frame=2;view:StartTargetDrag(hand,0,0);eq(e.undo,2);assert(e.message)
`);
const shared=source(['ixhl2rp/plugins/action_animations/sh_plugin.lua']);
const serverEnv=geometry+`
 CLIENT=false;SERVER=true;NULL={};MOVETYPE_WALK=2;MOVETYPE_OBSERVER=10
 local hooks,timers={},{};hook.Add=function(name,id,fn) hooks[name..':'..id]=fn end
 hook.Remove=function(name,id) hooks[name..':'..id]=nil end
 timer.Create=function(name,_,_,fn) timers[name]=fn end;timer.Remove=function(name) timers[name]=nil end
 ix.Item={instances={}};ix.Medicine={ValidSession=function(_,s) return s.valid~=false end}
 function user()
  local p={valid=true,nw={},locals={},netvars={},character={},inventories=true,weapon={valid=true,GetClass=function() return 'ix_hands' end}}
  function p:IsPlayer() return true end;function p:Alive() return not self.dead end;function p:GetCharacter() return self.character end
  function p:InVehicle() return self.vehicle end;function p:IsRestricted() return self.restricted end
  function p:GetNetVar(k,d) if self.netvars[k]==nil then return d end;return self.netvars[k] end
  function p:GetLocalVar(k,d) if self.locals[k]==nil then return d end;return self.locals[k] end
  function p:GetNW2Bool(k,d) if self.nw[k]==nil then return d end;return self.nw[k] end
  function p:GetNW2String(k,d) return self.nw[k] or d end;function p:GetNW2Entity(k) return self.nw[k] or NULL end
  function p:SetNW2String(k,v) self.nw[k]=v end;function p:SetNW2Entity(k,v) self.nw[k]=v end;function p:SetNW2Float(k,v) self.nw[k]=v end
  function p:GetMoveType() return self.move or MOVETYPE_WALK end;function p:GetNoDraw() return self.noDraw end
  function p:IsWepRaised() return self.raised end;function p:GetActiveWeapon() return self.weapon end
  function p:GetFirstAtSlot() return self.radioID end;function p:IsProne() return self.prone end
  return p
 end
`+shared+'\n'+source(['ixhl2rp/plugins/action_animations/sv_actions.lua'])+`\nlocal A=ix.ActionAnimations;`;
run('Numeric ragdoll state never reaches engine IsValid and automatic actions resume after recovery in both realms',serverEnv+`
 local valid=IsValid
 function IsValid(object)
  if isnumber(object) then error('attempt to index local object (a number value)') end
  return valid(object)
 end
 eq(pcall(IsValid,123),false)
 for _,server in ipairs({true,false}) do
  SERVER=server;CLIENT=not server
  local p=user()
  for _,state in ipairs({{},{value=0},{value=-1},{value=123},{value={valid=true}},{value={valid=false}}, {value=false}}) do
   p.locals.ragdoll=state.value
   local blocked=state.value==123 or (type(state.value)=='table' and state.value.valid==true)
   eq(A.Conflict(p),blocked);eq(A.BlockAutomatic(p),blocked)
  end
  p.locals.ragdoll=123;assert(A.BlockAutomatic(p))
  p.locals.ragdoll=0;eq(A.BlockAutomatic(p),false)
  p.locals.ragdoll=nil;eq(A.BlockAutomatic(p),false)
  p.ixRagdoll={valid=true};eq(A.BlockAutomatic(p),true)
  p.ixRagdoll.valid=false;eq(A.BlockAutomatic(p),false)
 end
`);
run('Accepted medical, maintenance and carried cargo animate; failed, cancelled and stale sessions never do',serverEnv+`
 local p=user();eq(A.Select(p),'')
 p.ixMedicalSession={character=p.character,target=p};eq(A.Select(p),'')
 p.ixMedicalSession.emoteStarted=true;eq(A.Select(p),'medical')
 p.ixMedicalSession.finishing=true;eq(A.Select(p),'');p.ixMedicalSession=nil
 local crate={valid=true,ixHeldOwner=p,GetClass=function() return 'ix_cargo_crate' end};p.locals.holdingObject=crate
 local mode,target=A.Select(p);eq(mode,'carry');eq(target,crate)
 crate.ixHeldOwner={};eq(A.Select(p),'');crate.ixHeldOwner=p;p.raised=true;eq(A.Select(p),'');p.raised=false
 p.locals.holdingObject=nil
 local facility={work={},WorkValid=function(_,p,w) return w.valid end};ix.plugin.list.facility_utilities=facility
 facility.work[p]={entity=crate,valid=false};eq(A.Select(p),'');facility.work[p].valid=true;eq(A.Select(p),'operate')
 facility.work[p]=nil;eq(A.Select(p),'')
 ix.water={Source=function() return 'sink' end,Near=function() return true end,actions={[p]={entity=crate,anchor=Vector(),source='sink',character=p.character,kind='drink',started=clock,finish=clock+2}}};eq(A.Select(p),'waterdrink')
 ix.water.actions[p].character={};eq(A.Select(p),'');ix.water.actions={}
 ix.plugin.list.decontamination={actions={[p]={entity=crate,character=p.character,kind='shower',finish=clock+8}}}
 eq(A.Select(p),'wash');clock=clock+9;eq(A.Select(p),'')
`);
run('Radio gestures require accepted transmission, expire, honor permission loss and publish only equipped radio models',serverEnv+`
 local p=user();local sent=hooks['AdjustRadioTransmitEavesdroppers:ixActionRadioSent']
 sent({player=p,bShouldSend=false});eq(A.Select(p),'')
 sent({player=p,bShouldSend=true,voice=true});eq(A.Select(p),'')
 sent({player=p,bShouldSend=true});eq(A.Select(p),'radio');clock=clock+3;eq(A.Select(p),'')
 p.ixRadioVoice={character=p.character,expires=clock+2,channel='main'}
 ix.voice={Transmission=function() return {data={channelID='main'}} end};eq(A.Select(p),'radio')
 ix.voice.Transmission=function() return nil end;eq(A.Select(p),'')
 p.radioID=1;ix.Item.instances[1]={IsOn=function() return true end,model='models/radio.mdl'}
 A.Publish(p,'radio');eq(p.nw.ixContextActionProp,'models/radio.mdl')
 ix.Item.instances[1].IsOn=function() return false end;A.Publish(p,'radio');eq(p.nw.ixContextActionProp,'')
 A.Publish(p,'');eq(p.nw.ixContextAction,'');eq(p:GetNW2Entity('ixContextActionTarget'),NULL)
`);
run('Pose Studio, sleep, cart, prone, numeric ragdoll and weapon conflicts suppress actions and automatic gestures; unloading owns cleanup',serverEnv+`
 local p=user();p.ixActionRadio={character=p.character,finish=clock+5}
 for _,spec in ipairs({{'netvars','forcedSequence',5},{'netvars','bedRestAngle',Angle()},{'nw','ixPoseStudioPlaying',true},
  {'nw','ixPushCart',{valid=true}},{'locals','ragdoll',123},{'netvars','crit',true}}) do
  p[spec[1]][spec[2]]=spec[3];eq(A.Select(p),'');assert(A.BlockAutomatic(p));p[spec[1]][spec[2]]=nil
 end
 p.prone=true;eq(A.Select(p),'');p.prone=false;p.ixUntimedSequence=true;eq(A.Select(p),'');p.ixUntimedSequence=nil
 eq(A.Select(p),'radio');assert(A.BlockAutomatic(p));p.weapon.GetClass=function() return 'arc9_test' end;eq(A.Select(p),'')
 allPlayers={p};A.Publish(p,'radio');PLUGIN:OnUnload();eq(A.Select(p),'');eq(p.nw.ixContextAction,'');eq(p.ixActionRadio,nil)
 eq(timers.ixContextActionSessions,nil);eq(next(hooks),nil)
`);
run('Actual client overlay modifies arm subtrees only on eight rigs, keeps pelvis/legs unchanged and never mutates original matrices',serverEnv+`
 CLIENT=true;SERVER=false;A.enabled=true;RENDERGROUP_OPAQUE=0
`+source(['ixhl2rp/plugins/action_animations/cl_actions.lua'])+`
 for _,data in ipairs(actualRigs) do
  local ref=reference(data);local p=user();local c=clip();local matrices,parents=S.TargetWorld(ref,{})
  local written={};p.model='models/player/test.mdl'
  function p:GetModel() return self.model end;function p:GetBoneCount() return ref.rig.count end
  function p:GetBoneParent(i) return parents[i] end;function p:LookupBone(name) return ref.rig.names[name] end
  function p:GetBoneMatrix(i) return matrices[i] end;function p:SetBoneMatrix(i,m) written[i]=m end
  function p:GetRenderAngles() return Angle() end;function p:GetNW2Float(k,d) return self.nw[k] or d end
  local target={valid=true,WorldSpaceCenter=function() return Vector(20,0,35) end,
   NearestPoint=function(_,v) return v end,OBBMaxs=function() return Vector(10,10,10) end,OBBMins=function() return Vector(-10,-10,-10) end}
  function target:LocalToWorld(v) return Vector(20,0,35)+v end
  for _,kind in ipairs({'medical','carry','operate','radio','drink','waterdrink','waterfill','wash','bodycam'}) do
   written={};local state={model=p.model,kind=kind,weight=1,target=target,source='sink',anchor=Vector()};A.Build(p,state);assert(next(written))
   for index,m in pairs(written) do
    assert(K.Descendant(parents,index,ref.rig.names['ValveBiped.Bip01_L_UpperArm']) or K.Descendant(parents,index,ref.rig.names['ValveBiped.Bip01_R_UpperArm']))
    assert(m:GetTranslation().x==m:GetTranslation().x)
   end
   eq(written[ref.rig.names['ValveBiped.Bip01_Pelvis']],nil);eq(written[ref.rig.names['ValveBiped.Bip01_L_Thigh']],nil)
   local fresh=S.TargetWorld(ref,{});for index,m in pairs(matrices) do closeVec(m:GetTranslation(),fresh[index]:GetTranslation()) end
  end
 end
`);
run('Client callbacks fade out on completion, clear immediately on pose/dormancy/model changes, and remove props on unload',serverEnv+`
 CLIENT=true;SERVER=false;A.enabled=true;RENDERGROUP_OPAQUE=0
 function math.Approach(a,b,c) return a<b and math.min(a+c,b) or math.max(a-c,b) end
 function FrameTime() return .05 end
`+source(['ixhl2rp/plugins/action_animations/cl_actions.lua'])+`
 local p=user();allPlayers={p};LocalPlayer=function() return p end;p.model='models/player/test.mdl'
 local adds,removes,invalidates=0,0,0
 function p:IsDormant() return self.dormant end;function p:GetPos() return Vector() end;function p:GetModel() return self.model end
 function p:AddCallback(name,fn) adds=adds+1;return adds end
 function p:RemoveCallback(name,id) removes=removes+1 end;function p:InvalidateBoneCache() invalidates=invalidates+1 end
 p.nw.ixContextAction='medical';local think=hooks['Think:ixContextActionActors']
 for i=1,4 do think() end;eq(adds,1);eq(A.actors[p].weight,1)
 p.nw.ixContextAction='';think();assert(A.actors[p] and A.actors[p].weight<1)
 for i=1,4 do think() end;eq(A.actors[p],nil);eq(removes,1)
 p.nw.ixContextAction='medical';think();p.nw.ixPoseStudioPlaying=true;think();eq(A.actors[p],nil);eq(removes,2)
 p.nw.ixPoseStudioPlaying=false;think();p.model='models/player/another.mdl';think();eq(removes,3);eq(adds,4)
 p.dormant=true;think();eq(A.actors[p],nil);eq(removes,4);p.dormant=false;think()
 local prop={valid=true,Remove=function(self) self.valid=false end};A.actors[p].prop=prop
 PLUGIN:OnUnload();eq(prop.valid,false);eq(A.actors[p],nil);eq(removes,5)
 eq(hooks['Think:ixContextActionActors'],nil);eq(hooks['PostPlayerDraw:ixContextActionRadioProp'],nil)
 assert(invalidates>0)
`);
run('Turning keeps IC/W/Y and ARC9 guards while denying talk/turn during owned actions and external poses',serverEnv+`
 local turning={};PLUGIN=turning;SERVER=true;CLIENT=false
 ACT_MP_STAND_IDLE=1;ACT_MP_CROUCH_IDLE=2;ACT_GESTURE_TURN_RIGHT90=3;ACT_GESTURE_TURN_LEFT90=4;ACT_GESTURE_TURN_LEFT45=5
 ix.anim={CanUseARC9NativePose=function() return false end}
`+source(['ixhl2rp/plugins/turning.lua'])+`
 local p=user();p.ixAnimModelClass='cellarMale';p.events=0
 function p:GetRenderAngles() return Angle(0,90,0) end;function p:EyeAngles() return Angle() end
 function p:SelectWeightedSequence() return 0 end;function p:SequenceDuration() return 1 end
 function p:AnimRestartGesture() self.events=self.events+1 end;function p:LookupSequence() return 0 end
 function p:GetShootPos() return Vector() end
 local sent=0;net.Start=function() sent=sent+1 end;net.WriteEntity=function() end;net.WriteUInt=function() end;net.SendPVS=function() end
 turning:PostPlayerSay(p,'me','text');eq(sent,0)
 turning:PostPlayerSay(p,'ic','text');eq(sent,1)
 p.nextTalkAnim=0;p.nw.ixContextAction='operate';turning:PostPlayerSay(p,'ic','text');eq(sent,1)
 turning:TranslateActivity(p,ACT_MP_STAND_IDLE);eq(p.events,0)
 p.nw.ixContextAction='';turning:TranslateActivity(p,ACT_MP_STAND_IDLE);eq(p.events,1)
 p.NextTurn=0;ix.anim.CanUseARC9NativePose=function() return true end;turning:TranslateActivity(p,ACT_MP_STAND_IDLE);eq(p.events,1)
`);
finish();
