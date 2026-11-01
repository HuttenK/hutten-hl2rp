const {run,source,read,finish}=require('./restored-test-runner.cjs');
const toLua=v=>Array.isArray(v)?'{'+v.map(toLua).join(',')+'}':v&&typeof v==='object'?'{'+Object.entries(v).map(([k,x])=>'['+JSON.stringify(k)+']='+toLua(x)).join(',')+'}':JSON.stringify(v);
const rigs=JSON.parse(read('tools/fixtures/pose-starter-rigs.json'));
const env=`ix.PoseStudio={};ix.util={Include=function() end};function RealTime() return clock end
function Color(...) return {...} end
function math.Round(v,d) local n=10^(d or 0);return math.floor(v*n+.5)/n end
function Lerp(t,a,b) return a+(b-a)*t end
function isvector(v) return type(v)=='table' and getmetatable(v)==getmetatable(Vector()) end
`+source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','ixhl2rp/plugins/pose_studio/sh_clip.lua','ixhl2rp/plugins/pose_studio/sh_rig.lua','ixhl2rp/plugins/action_animations/sh_ik.lua','ixhl2rp/plugins/pose_studio/cl_gizmo.lua','ixhl2rp/plugins/pose_studio/cl_pose_tools.lua','ixhl2rp/plugins/pose_studio/cl_targets.lua','ixhl2rp/plugins/pose_studio/cl_rig.lua'])+`
local S=ix.PoseStudio;angle_zero=Angle();local M=getmetatable(Matrix());local V=getmetatable(Vector())
function V:DistToSqr(b) return (self-b):Dot(self-b) end
function M:GetField(r,c) return self[r][c] end
function M:SetAngles(a) local axes={a:Forward(),-a:Right(),a:Up()};for c,v in ipairs(axes) do self:SetField(1,c,v.x);self:SetField(2,c,v.y);self:SetField(3,c,v.z) end end
function M:GetAngles() return Angle(math.deg(math.atan(-self[3][1],math.sqrt(self[1][1]^2+self[2][1]^2))),math.deg(math.atan(self[2][1],self[1][1])),math.deg(math.atan(self[3][2],self[3][3]))) end
function matrixNear(a,b,e) for r=1,3 do for c=1,4 do assert(math.abs(a:GetField(r,c)-b:GetField(r,c))<(e or .003),'matrix '..r..','..c) end end end
function closeVec(a,b,e) assert((a-b):Length()<(e or .01),tostring((a-b):Length())) end
function delta(t) local m=Matrix();m:SetAngles(Angle(unpack(t.a)));m:SetTranslation(Vector(unpack(t.p)));return m end
function rot(m) local out=m*Matrix();out:SetTranslation(Vector());return out end
local actualRigs=${toLua(rigs)}
function reference(data)
 local rig={count=#data.bones,bones={},names={},height=40};local locals={}
 for n,b in ipairs(data.bones) do
  local i=n-1;local inverse=Matrix();for r=1,3 do for c=1,4 do inverse:SetField(r,c,b.inverse[(r-1)*4+c]) end end
  local bind=inverse:GetInverse();local localBind=b.parent>=0 and rig.bones[b.parent].inverse*bind or bind
  rig.bones[i]={name=b.name,parent=b.parent,bind=bind,inverse=inverse,localBind=localBind};rig.names[b.name]=i
  local baseDelta=Matrix();baseDelta:SetAngles(Angle(5,-12,7));locals[b.name]=localBind*baseDelta
 end
 rig.height=(rig.bones[rig.names['ValveBiped.Bip01_Head1']].bind:GetTranslation()-rig.bones[rig.names['ValveBiped.Bip01_Pelvis']].bind:GetTranslation()):Length()
 ix.sharedPoses={Rig=function() return rig end};return {rig=rig,locals=locals}
end
function clip()
 return {version=3,name='Symmetry',model='models/player/test.mdl',base='idle',cycle=0,portable=true,mask='full',loop=true,smooth=true,
 frames={{duration=1,bones={}},{duration=.5,bones={}}},props={{model='models/props_c17/chair01a.mdl',bone='ValveBiped.Bip01_R_Hand',a={1,2,3},p={1,2,3},scale=1,skin=0}}}
end
local L,R='ValveBiped.Bip01_L_','ValveBiped.Bip01_R_'
`;
const ui=env+`
local registered={};vgui={Register=function(name,p) registered[name]=p end,GetKeyboardFocus=function() end}
surface={CreateFont=function() end};function Color(...) return {...} end
function ScrH() return 1080 end;function ScrW() return 1920 end
input={IsKeyDown=function() return false end};function FrameTime() return .016 end
local currentPlayer={valid=true,GetCharacter=function() return 'character' end,SteamID64=function() return 'owner' end,GetModel=function() return 'models/player/preview.mdl' end}
function LocalPlayer() return currentPlayer end
util.IsValidModel=function() return true end
function util.TableToJSON(t)
 if type(t)~='table' then return tostring(t) end
 local rows={};for k,v in pairs(t) do rows[#rows+1]=tostring(k)..'='..util.TableToJSON(v) end;table.sort(rows);return table.concat(rows,'|')
end
`+source(['ixhl2rp/plugins/pose_studio/cl_editor.lua'])+`
local controls={}
local function control()
 local p={valid=true,editing=true};p.Label=p
 function p:Add(kind) local child=control();child.kind=kind;controls[#controls+1]=child;return child end
 function p:SetText(value) self.text=value end;function p:SetValue(value) self.value=value end
 function p:SetTextColor(value) self.color=value end;function p:IsEditing() return self.editing end
 for _,method in ipairs({'Dock','SetTall','SetFont','DockMargin','SetWide','SetTooltip','AddChoice','SetPlaceholderText','SetMinMax','SetDecimals','SetWrap','SetCursorColor','SetHighlightColor','SetEnabled','Clear'}) do p[method]=function() end end
 return p
end
function editor(ref)
 S.ToolReference=function() return ref end
 local p=setmetatable({valid=true,right=control(),clip=clip(),frame=1,undo={},selectedBone=R..'Hand',symmetry=true,character='character',save={}}, {__index=registered.ixPoseStudio})
 p.viewport={valid=true,state={},Entity={valid=true,GetModel=function() return 'models/player/preview.mdl' end},OnMouseReleased=function() end,LoadClip=function() end}
 p:BuildInspector()
 function p:RefreshFields() self.refreshed=(self.refreshed or 0)+1 end
 function p:FillBones() end;function p:RefreshProps() end;function p:RefreshTimeline() end
 function p:WriteDraft() end
 return p
end
`;
run('Live symmetry reflects authored deltas in sampled base axes on eight real rigs, both directions, with no accumulation',env+`
 local cases=0;local H=Matrix();H:SetField(2,2,-1)
 for _,data in ipairs(actualRigs) do
  local ref=reference(data);local c=clip();local world=S.TargetWorld(ref,{})
  for name in pairs(S.humanoidBones) do
   local opposite=S.MirrorBoneName(name)
   if name~=opposite and ref.rig.names[name] and ref.rig.names[opposite] then
    local bones={[name]={a={12,-25,9},p={.2,-.3,.1}},[opposite]={a={-50,0,0},p={2,0,0}}}
    local out=assert(S.MirrorEditedBones(ref,c,bones,{name}))
    local a,b=rot(world[ref.rig.names[name]]),rot(world[ref.rig.names[opposite]])
    matrixNear(b*delta(out[opposite])*b:GetInverse(),H*a*delta(bones[name])*a:GetInverse()*H)
    local repeated=assert(S.MirrorEditedBones(ref,c,out,{name}));matrixNear(delta(repeated[opposite]),delta(out[opposite]))
    matrixNear(delta(out[name]),delta(bones[name]));eq(bones[opposite].a[1],-50);cases=cases+1
   end
  end
 end
 assert(cases>300)
`);
run('Symmetry skips missing fingers and unpaired centers, respects upper mask, clears partner on reset and rejects atomically while loading',env+`
 local ref=reference(actualRigs[1]);local c=clip();c.mask='upper'
 local bones={[L..'Hand']={a={10,0,0},p={0,0,0}},[R..'Finger1']={a={7,0,0},p={0,0,0}},[R..'Thigh']={a={23,0,0},p={0,0,0}}}
 ref.rig.names[L..'Finger1']=nil
 local out=assert(S.MirrorEditedBones(ref,c,bones,{R..'Finger1',R..'Thigh'}));eq(out[L..'Finger1'],nil);eq(out[L..'Thigh'],nil)
 out=assert(S.MirrorEditedBones(ref,c,bones,{R..'Hand'}));eq(out[L..'Hand'],nil)
 eq(S.MirrorEditedBones(nil,c,bones,{L..'Hand'}),nil);eq(bones[L..'Hand'].a[1],10)
 local head='ValveBiped.Bip01_Head1';bones[head]={a={10,20,30},p={1,2,3}}
 out=assert(S.MirrorEditedBones(nil,c,bones,{head}));eq(out[head].a[2],20)
`);
run('Actual inspector sliders mirror positions and angles as one undo gesture; toggle, reset and props remain independent',ui+`
 local ref=reference(actualRigs[1]);local p=editor(ref);local first=p.clip
 p.fields[2].panel:OnValueChanged(25);clock=clock+1;p.fields[2].panel:OnValueChanged(42)
 eq(#p.undo,1);eq(first.frames[1].bones[R..'Hand'].a[2],42);assert(first.frames[1].bones[L..'Hand'])
 p:Undo();eq(next(p.clip.frames[1].bones),nil);eq(#p.clip.props,1);eq(p.clip.props[1].p[1],1)
 p.fields[4].panel:OnValueChanged(2);assert(p.clip.frames[1].bones[L..'Hand']);eq(#p.undo,1)
 local reset;for _,item in ipairs(controls) do if item.caption=='Сбросить выбранное' then reset=item end end;assert(reset);reset:DoClick()
 eq(p.clip.frames[1].bones[L..'Hand'],nil);eq(p.clip.frames[1].bones[R..'Hand'],nil);eq(#p.undo,2)
 p:Undo();eq(p.clip.frames[1].bones[R..'Hand'].p[1],2);assert(p.clip.frames[1].bones[L..'Hand'])
 p.symmetryButton:DoClick();eq(p.symmetry,false)
 local other=util.TableToJSON(p.clip.frames[1].bones[L..'Hand']);p.fields[1].panel:OnValueChanged(33);eq(util.TableToJSON(p.clip.frames[1].bones[L..'Hand']),other)
 p.symmetry=true;p.selectedProp=1;local before=util.TableToJSON(p.clip.frames)
 p.fields[4].panel:OnValueChanged(7);eq(p.clip.props[1].p[1],7);eq(#p.clip.props,1);eq(util.TableToJSON(p.clip.frames),before)
`);
run('Actual slider gesture ends on native IsEditing false, then a fresh drag starts one new checkpoint',ui+`
 local p=editor(reference(actualRigs[1]));local field=p.fields[1].panel
 field:OnValueChanged(10);field:OnValueChanged(30);eq(#p.undo,1)
 field.editing=false;p:Think();eq(p.editControl,nil)
 field.editing=true;field:OnValueChanged(45);field:OnValueChanged(60);eq(#p.undo,2)
 p:Undo();eq(p.clip.frames[1].bones[R..'Hand'].a[1],30)
`);
run('Actual XYZ ring and movement drag share one checkpoint for both sides and do not re-mirror on Undo',ui+`
 local p=editor(reference(actualRigs[1]));local VIEW=registered.ixPoseStudioViewport
 local view=setmetatable({editor=p,showBones=true,drag={kind='ring',bone=p.selectedBone,frame=1,ring={axis=1,edgeOn=true},tx=1,ty=0,start={0,0,0},total=0}}, {__index=VIEW})
 function view:ScreenToLocal(x,y) return x,y end;function view:MouseCapture() end
 p:Checkpoint(true);view:DragRotation(5,0,5,0);view:DragRotation(10,0,5,0);eq(#p.undo,1)
 assert(p.clip.frames[1].bones[L..'Hand']);p:Undo();eq(next(p.clip.frames[1].bones),nil)
 p.moveMode=true;p.axis=2;view.drag={kind='bone',x=0,y=0};gui={MousePos=function() return 5,-2 end}
 view.Entity=nil;p:Checkpoint(true);view:Think();eq(#p.undo,1);assert(p.clip.frames[1].bones[R..'Hand'].p[2]>0);assert(p.clip.frames[1].bones[L..'Hand'])
 p:Undo();eq(next(p.clip.frames[1].bones),nil)
`);
run('Hand preset native tool commit mirrors only touched fingers and undoes both sides without touching props or other frames',ui+`
 local p=editor(reference(actualRigs[1]));p.clip.frames[2].bones[R..'Hand']={a={14,0,0},p={0,0,0}}
 p:RunPoseTool(function(ref,clip,bones) return S.ApplyHandPreset(ref,clip,bones,'fist',{'R'}) end)
 eq(#p.undo,1);assert(p.clip.frames[1].bones[R..'Finger1']);assert(p.clip.frames[1].bones[L..'Finger1'])
 eq(p.clip.frames[2].bones[R..'Hand'].a[1],14);eq(p.clip.props[1].p[1],1)
 p:Undo();eq(next(p.clip.frames[1].bones),nil)
`);
run('Visible-target IK maps back across eight differing humanoid rigs and reaches the clicked model-space goal',env+`
 local function drawTarget(ref,target,clip,bones)
  local matrices=S.TargetWorld(target,{});local rig=target.rig
  local ent={}
  function ent:GetBoneCount() return rig.count end;function ent:GetBoneMatrix(i) return matrices[i] end
  function ent:GetBoneParent(i) return rig.bones[i].parent end;function ent:GetBoneName(i) return rig.bones[i].name end
  function ent:GetPos() return Vector() end;function ent:GetRenderAngles() return Angle() end;function ent:GetAngles() return Angle() end
  function ent:GetModelScale() return 1 end;function ent:SetBoneMatrix(i,m) matrices[i]=m end
  S.ApplyLayer(ent,{reference=ref,targetRig=rig,rigMap=S.RigMap(rig,ref.rig),rigRatio=rig.height/ref.rig.height,clip=clip,transforms=bones})
  return matrices
 end
 local cases=0
 for index,data in ipairs(actualRigs) do
  local ref=reference(data);local target=reference(actualRigs[index%#actualRigs+1]);local c=clip()
  for _,side in ipairs({'L','R'}) do for _,part in ipairs({'Hand','Foot'}) do
   local name='ValveBiped.Bip01_'..side..'_'..part;local bones={[name]={a={4,-3,8},p={.1,.1,.1}}}
   local matrices=drawTarget(ref,target,c,bones)
   local drag=assert(S.MakeViewportTarget(ref,c,bones,name,target.rig,matrices))
   local goal=drag.root+(drag.goal-drag.root)*.8+Vector(1,1,-1)
   local result,err,reached=S.SolveViewportTarget(drag,goal,25);assert(result,err)
   local actual=drawTarget(ref,target,c,result);closeVec(actual[target.rig.names[name]]:GetTranslation(),reached,.04)
   eq(result[name].p[1],.1);cases=cases+1
  end end
 end
 eq(cases,32)
`);
run('Native target drag mirrors the whole solved chain in current-model preview with a single undo entry',ui+`
 local ref=reference(actualRigs[1]);local p=editor(ref);p.targetMode=true;p.previewTarget=true
 local view=setmetatable({editor=p,Entity=p.viewport.Entity,poseMatrices=S.TargetWorld(ref,{}),poseMatrixClip=p.clip,poseMatrixFrame=1},{__index=registered.ixPoseStudioViewport})
 function view:GetLookAt() return Vector(0,0,40) end;function view:GetCamPos() return Vector(100,0,40) end
 function view:GetFOV() return 34 end;function view:GetWide() return 1000 end;function view:MouseCapture() end
 view:StartTargetDrag(R..'Hand',0,0);assert(view.drag);eq(#p.undo,1)
 view:DragTarget(12,-8)
 for _,part in ipairs({'UpperArm','Forearm','Hand'}) do assert(p.clip.frames[1].bones[R..part]);assert(p.clip.frames[1].bones[L..part]) end
 view:OnMouseWheeled(1);eq(#p.undo,1);p:Undo();eq(next(p.clip.frames[1].bones),nil)
`);
run('Save waits for portable reference capture; draft edits or changed row cancel stale deferred saves',ui+`
 local p=editor(reference(actualRigs[1]));p.owner='owner';local sent=0;local queue={};local attempts=0
 timer.Simple=function(_,fn) queue[#queue+1]=fn end;S.Request=function(data) assert(data.clip.reference);sent=sent+1;return true end
 S.CaptureReference=function(c) attempts=attempts+1;if attempts==1 then return false,'warming',true end;c.reference={fake=true};return true end
 local validate=S.Validate;S.Validate=function(c) local input=table.Copy(c);input.reference=nil;local out=validate(input);if out then out.reference=c.reference end;return out end
 p:Save();eq(sent,0);assert(p.saveReferenceRequest);queue[1]();eq(sent,1);eq(p.saveReferenceRequest,nil)
 p.saving=false;p.clip.reference=nil;attempts=0;queue={};p:Save();p.clip.frames[1].bones[R..'Hand']={a={42,0,0},p={0,0,0}};queue[1]();eq(sent,1);eq(p.saveReferenceRequest,nil)
 attempts=0;queue={};p:Save();p.revision=10;queue[1]();eq(sent,1);eq(p.saveReferenceRequest,nil)
`);
finish();
