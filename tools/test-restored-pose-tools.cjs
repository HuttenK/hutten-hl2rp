const {run,source,native,read,finish}=require('./restored-test-runner.cjs');
const rigs=JSON.parse(read('tools/fixtures/pose-starter-rigs.json'));
const toLua=v=>Array.isArray(v)?'{'+v.map(toLua).join(',')+'}':v&&typeof v==='object'?'{'+Object.entries(v).map(([k,x])=>'['+JSON.stringify(k)+']='+toLua(x)).join(',')+'}':JSON.stringify(v);
const env='ix.PoseStudio={};function math.Round(v,d) local scale=10^(d or 0);return math.floor(v*scale+.5)/scale end;function Lerp(t,a,b) return a+(b-a)*t end;function RealTime() return clock end\n'+source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','ixhl2rp/plugins/pose_studio/sh_clip.lua','ixhl2rp/plugins/pose_studio/sh_rig.lua','ixhl2rp/plugins/pose_studio/cl_pose_tools.lua'])+`
 local S=ix.PoseStudio;angle_zero=Angle();local M=getmetatable(Matrix())
 function M:GetField(r,c) return self[r][c] end
 function M:SetAngles(a) local axes={a:Forward(),-a:Right(),a:Up()};for c,v in ipairs(axes) do self:SetField(1,c,v.x);self:SetField(2,c,v.y);self:SetField(3,c,v.z) end end
 function M:GetAngles() return Angle(math.deg(math.atan(-self[3][1],math.sqrt(self[1][1]^2+self[2][1]^2))),math.deg(math.atan(self[2][1],self[1][1])),math.deg(math.atan(self[3][2],self[3][3]))) end
 function matrixNear(a,b,epsilon) for r=1,3 do for c=1,4 do assert(math.abs(a:GetField(r,c)-b:GetField(r,c))<(epsilon or .0002),'matrix '..r..','..c) end end end
 function delta(t) local m=Matrix();m:SetAngles(Angle(unpack(t.a)));m:SetTranslation(Vector(unpack(t.p)));return m end
 local actualRigs=${toLua(rigs)}
 function reference(data)
  local rig={count=#data.bones,bones={},names={},height=40};local locals={}
  for n,b in ipairs(data.bones) do
   local i=n-1;local inverse=Matrix();for r=1,3 do for c=1,4 do inverse:SetField(r,c,b.inverse[(r-1)*4+c]) end end
   local bind=inverse:GetInverse();local localBind=b.parent>=0 and rig.bones[b.parent].inverse*bind or bind
   rig.bones[i]={name=b.name,parent=b.parent,bind=bind,inverse=inverse,localBind=localBind};rig.names[b.name]=i
   local baseDelta=Matrix();baseDelta:SetAngles(Angle(5,-12,7));locals[b.name]=localBind*baseDelta
  end
  ix.sharedPoses={Rig=function() return rig end}
  return {rig=rig,locals=locals}
 end
 function clip()
  return {version=3,name='Test',model='models/player/test.mdl',base='idle',cycle=0,portable=true,mask='full',loop=true,smooth=true,
   frames={{duration=1,bones={}},{duration=.5,bones={}}},props={{model='models/props_c17/chair01a.mdl',bone='ValveBiped.Bip01_R_Hand',a={0,0,0},p={1,2,3},scale=1,skin=0}}}
 end
 `;
function suite(name,test){run(name,env+'\n'+test);}
suite('Matrix mirror round-trips eight actual ValveBiped rigs, including asymmetric axes; hidden keys and source remain intact',`
 local cases=0
 for _,data in ipairs(actualRigs) do
  local ref=reference(data);local c=clip();c.portable=false
  local bones={hidden_attachment={a={7,8,9},p={1,2,3}}}
  for name in pairs(S.humanoidBones) do if ref.rig.names[name]~=nil then bones[name]={a={17,-26,11},p={.2,-.3,.1}} end end
  local mirrored,err=S.MirrorPoseBones(ref,c,bones);assert(mirrored,err)
  local twice;twice,err=S.MirrorPoseBones(ref,c,mirrored);assert(twice,err)
  for name,t in pairs(bones) do matrixNear(delta(twice[name]),delta(t),.002) end
  eq(bones['ValveBiped.Bip01_R_Hand'].a[1],17);eq(mirrored.hidden_attachment.a[1],7)
  local source,target='ValveBiped.Bip01_L_Hand','ValveBiped.Bip01_R_Hand'
  local a,b=ref.rig.bones[ref.rig.names[source]].bind*Matrix(),ref.rig.bones[ref.rig.names[target]].bind*Matrix()
  a:SetTranslation(Vector());b:SetTranslation(Vector());local H=Matrix();H:SetField(2,2,-1)
  matrixNear(b*delta(mirrored[target])*b:GetInverse(),H*a*delta(bones[source])*a:GetInverse()*H,.002)
  c.frames[1].bones=mirrored;assert(S.Validate(c));cases=cases+1
 end
 eq(cases,8)
`);
suite('Mirror selected branch changes only opposite descendants; masks, missing fingers and offset bounds are respected',`
 local ref=reference(actualRigs[1]);local c=clip();local bones={}
 local L,R='ValveBiped.Bip01_L_','ValveBiped.Bip01_R_'
 bones[L..'Hand']={a={15,-22,18},p={0,0,0}};bones[L..'Finger1']={a={1,12,0},p={0,0,0}}
 bones[R..'UpperArm']={a={33,0,0},p={0,0,0}};bones[R..'Thigh']={a={25,0,0},p={0,0,0}}
 local mirrored=assert(S.MirrorPoseBones(ref,c,bones,L..'Hand'));assert(mirrored[R..'Hand']);assert(mirrored[R..'Finger1'])
 eq(mirrored[R..'UpperArm'].a[1],33);eq(mirrored[R..'Thigh'].a[1],25);eq(bones[R..'Hand'],nil)
 c.mask='upper';eq(S.MirrorPoseBones(ref,c,bones,R..'Thigh'),nil)
 ref.rig.names[R..'Finger1']=nil
 local changed,err,count,skipped=S.MirrorPoseBones(ref,c,bones,L..'Hand');assert(changed,err);eq(skipped,1);eq(changed[R..'Finger1'],nil)
 eq(S.ApplyHandPreset(ref,c,bones,'fist',{'invalid'}),nil)
`);
suite('Seven hand presets solve against bent base on eight actual rigs, remain idempotent and preserve finger positions',`
 local cases=0
 for _,data in ipairs(actualRigs) do
  local ref=reference(data);local c=clip()
  for _,preset in ipairs(S.HAND_PRESETS) do
   local bones={['ValveBiped.Bip01_R_Hand']={a={34,12,9},p={0,0,0}}}
   bones['ValveBiped.Bip01_L_Finger1']={a={-30,40,22},p={.25,.5,.75}}
   local result,err=S.ApplyHandPreset(ref,c,bones,preset.id,{'L','R'});assert(result,err)
   local repeated=assert(S.ApplyHandPreset(ref,c,result,preset.id,{'L','R'}))
   for _,side in ipairs({'L','R'}) do for name,angles in pairs(S.GetPresetAngles(preset,side)) do
    local index=ref.rig.names[name]
    if index~=nil then
     local expected=ref.rig.bones[index].localBind*Matrix();local pm=Matrix();pm:SetAngles(Angle(unpack(angles)))
     expected=expected*pm;local actual=ref.locals[name]*delta(result[name])
     expected:SetTranslation(Vector());actual:SetTranslation(Vector());matrixNear(actual,expected,.002)
     matrixNear(delta(repeated[name]),delta(result[name]),.002)
    end
   end end
   eq(result['ValveBiped.Bip01_L_Finger1'].p[1],.25);eq(result['ValveBiped.Bip01_R_Hand'].a[1],34)
   c.frames[1].bones=result;assert(S.Validate(c));cases=cases+1
  end
 end
 eq(cases,56)
 local ref=reference(actualRigs[1]);local c=clip();local removed=0
 for name in pairs(ref.rig.names) do if name:find('L_Finger',1,true) then ref.rig.names[name]=nil;removed=removed+1 end end
 assert(removed>0);eq(S.ApplyHandPreset(ref,c,{},'flat',{'L'}),nil)
 local result,err,count,skipped=S.ApplyHandPreset(ref,c,{},'flat',{'L','R'});assert(result,err);eq(skipped,15)
`);
suite('Hinge guidance measures posed geometry without modifying authored transforms',`
 local prefix='ValveBiped.Bip01_L_';local rig={count=3,bones={},names={}};local locals={}
 for i,name in ipairs({'UpperArm','Forearm','Hand'}) do
  local full=prefix..name;rig.names[full]=i-1;rig.bones[i-1]={name=full,parent=i-2}
  local m=Matrix();m:SetTranslation(i==1 and Vector() or Vector(10,0,0));locals[full]=m
 end
 local ref={rig=rig,locals=locals};local bones={}
 near(S.HingeGuidance(ref,bones,prefix..'Forearm').degrees,0)
 bones[prefix..'Forearm']={a={0,90,0},p={0,0,0}}
 near(S.HingeGuidance(ref,bones,prefix..'Forearm').degrees,90);eq(bones[prefix..'Forearm'].a[2],90)
 bones[prefix..'Forearm'].a[2]=170;assert(S.HingeGuidance(ref,bones,prefix..'Forearm').outside)
 eq(S.HingeGuidance(ref,bones,prefix..'Hand'),nil)
`);
const editor='ixhl2rp/plugins/pose_studio/cl_editor.lua';
run('Pose tool commits one undo checkpoint, preserves other frames/props and cancels stale deferred sampling',env+`
 local PANEL={}
 ${native(editor,'function PANEL:RunPoseTool(operation)','function PANEL:HandPresetMenu()')}
 ${native(editor,'function PANEL:Checkpoint(force)','function PANEL:AddFrame()')}
 local ref=reference(actualRigs[1]);S.ToolReference=function() return ref end
 local c=clip();c.frames[1].bones['ValveBiped.Bip01_L_Hand']={a={12,7,2},p={0,0,0}};c.frames[2].bones.Head={a={8,0,0},p={0,0,0}}
 -- Keep this hidden key only in a model-only clip, as the existing editor permits.
 c.portable=false
 local p=setmetatable({valid=true,clip=c,frame=1,undo={},viewport={state={}},lastUndo=0},{__index=PANEL})
 function p:Dirty() self.dirty=true end;function p:RefreshFields() end;function p:RefreshTimeline() end;function p:RefreshProps() end
 function p:Message(v) self.message=v end;S.ClearProps=function() end
 util.TableToJSON=function(t)
  local rows={};for _,f in ipairs(t.frames) do for k,v in pairs(f.bones) do rows[#rows+1]=k..table.concat(v.a,',') end end;table.sort(rows);return table.concat(rows,'|')
 end
 p:RunPoseTool(function(reference,clip,bones) return S.MirrorPoseBones(reference,clip,bones,'ValveBiped.Bip01_L_Hand') end)
 eq(#p.undo,1);assert(p.dirty);assert(c.frames[1].bones['ValveBiped.Bip01_R_Hand']);eq(c.frames[2].bones.Head.a[1],8);eq(c.props[1].p[1],1)
 p:Undo();eq(p.clip.frames[1].bones['ValveBiped.Bip01_R_Hand'],nil);eq(p.clip.frames[2].bones.Head.a[1],8)
 local queue={};timer.Simple=function(_,fn) queue[#queue+1]=fn end;S.ToolReference=function() return nil end
 p:RunPoseTool(function() error('stale tool must not execute') end);eq(#queue,1)
 p.clip.frames[1].bones['ValveBiped.Bip01_L_Hand'].a[1]=44;queue[1]();eq(#p.undo,0);eq(p.clip.frames[1].bones['ValveBiped.Bip01_L_Hand'].a[1],44)
`);

run('Cross-model preview keeps tools in author reference space and leaves preview entity untouched',env+source(['ixhl2rp/plugins/pose_studio/cl_rig.lua'])+`
 function FrameNumber() return math.floor(clock*60) end
 local author=reference(actualRigs[1]);local target=reference(actualRigs[8]);local looked={};local writes=0
 local matrices={};for i=0,author.rig.count-1 do local bone=author.rig.bones[i];matrices[i]=bone.parent>=0 and matrices[bone.parent]*author.locals[bone.name] or author.locals[bone.name] end
 local donor={valid=true}
 function donor:GetModel() return 'models/player/author.mdl' end
 for _,key in ipairs({'SetPos','SetAngles','ResetSequence','SetLOD','SetupBones'}) do donor[key]=function() end end
 function donor:LookupSequence() return 0 end;function donor:GetBoneMatrix(i) return matrices[i] end
 S.FreezeBase=function() end
 ix.sharedPoses={Rig=function(model) looked[#looked+1]=model;return model=='models/player/author.mdl' and author.rig or target.rig end,
  Probe=function(model) eq(model,'models/player/author.mdl');return donor end}
 local c=clip();c.model='models/player/author.mdl'
 local preview={valid=true,GetModel=function() return 'models/player/preview.mdl' end,SetBoneMatrix=function() writes=writes+1 end}
 eq(S.ToolReference(c),nil);clock=clock+1
 local ref=S.ToolReference(c);eq(ref.rig,author.rig)
 local first=assert(S.ApplyHandPreset(ref,c,{},'fist',{'R'}));local expected=assert(S.ApplyHandPreset(author,c,{},'fist',{'R'}))
 for name,t in pairs(first) do matrixNear(delta(t),delta(expected[name]),.002) end
 local second=S.ToolReference(c);eq(second,ref);eq(writes,0)
 for _,model in ipairs(looked) do eq(model,'models/player/author.mdl') end
 eq(c.model,'models/player/author.mdl');eq(c.frames[1].bones['ValveBiped.Bip01_R_Finger1'],nil)
`);
run('Native inspector sliders update hinge guidance immediately, including base/cycle edits and warning color',env+`
 local registered={};vgui={Register=function(name,value) registered[name]=value end}
 surface={CreateFont=function() end};function Color(...) return {...} end
 function ScrH() return 1080 end
`+source([editor])+`
 local controls={}
 local function control()
  local p={valid=true};p.Label=p
  function p:Add(kind) local child=control();child.kind=kind;controls[#controls+1]=child;return child end
  function p:SetText(value) self.text=value end
  function p:SetTextColor(value) self.color=value end
  for _,method in ipairs({'Dock','SetTall','SetFont','DockMargin','SetWide','SetTooltip','AddChoice','SetPlaceholderText','SetMinMax','SetDecimals','SetWrap','SetCursorColor','SetHighlightColor'}) do p[method]=function() end end
  return p
 end
 local prefix='ValveBiped.Bip01_L_';local ref={rig={count=3,names={},bones={}},locals={}}
 for i,part in ipairs({'UpperArm','Forearm','Hand'}) do
  local name=prefix..part;ref.rig.names[name]=i-1;ref.rig.bones[i-1]={name=name,parent=i-2}
  local pose=Matrix();pose:SetTranslation(i==1 and Vector() or Vector(10,0,0));ref.locals[name]=pose
 end
 local c=clip();c.portable=false
 S.ToolReference=function(clip)
  ref.locals[prefix..'Forearm']:SetAngles(Angle(0,clip.cycle*40+(clip.base=='bent' and 10 or 0),0));return ref
 end
 local p=setmetatable({valid=true,right=control(),clip=c,frame=1,undo={},selectedBone=prefix..'Forearm'}, {__index=registered.ixPoseStudio})
 p:BuildInspector()
 p.fields[2].panel:OnValueChanged(170)
 assert(p.hingeHint.text:find('170.0',1,true),'angle slider left the hinge hint stale')
 eq(p.hingeHint.color[1],236);eq(c.frames[1].bones[prefix..'Forearm'].a[2],170)
 p.fields[2].panel:OnValueChanged(20)
 assert(p.hingeHint.text:find('20.0',1,true));eq(p.hingeHint.color[1],143)
 p.cycle:OnValueChanged(1);assert(p.hingeHint.text:find('60.0',1,true),'base cycle left the hinge hint stale')
 p.base:OnSelect(1,'bent','bent');assert(p.hingeHint.text:find('70.0',1,true),'base sequence left the hinge hint stale')
 p.selectedProp=1;p:Dirty();eq(p.hingeHint.text,'')
 eq(#c.frames,2);eq(c.props[1].p[1],1)
`);
finish();


