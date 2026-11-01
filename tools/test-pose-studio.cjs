const shared='ixhl2rp/plugins/pose_studio/sh_clip.lua';
const server='ixhl2rp/plugins/pose_studio/sv_studio.lua';
const client='ixhl2rp/plugins/pose_studio/cl_playback.lua';
const editor='ixhl2rp/plugins/pose_studio/cl_editor.lua';
const gizmo='ixhl2rp/plugins/pose_studio/cl_gizmo.lua';
const common=`
 ix.PoseStudio={}
 unpack=table.unpack
 function makeClip()
  return {name='Test pose',model='models/player/kleiner.mdl',base='idle',cycle=0,loop=true,smooth=true,
   frames={{duration=1,bones={Hand={a={0,0,0},p={0,0,0}}}}},props={}}
 end
 function count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
 local values={}
 local function serialize(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys={}; for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  local result={}; for _,k in ipairs(keys) do result[#result+1]=serialize(k)..'='..serialize(v[k]) end
  return '{'..table.concat(result,',')..'}'
 end
 util.TableToJSON=function(value) local key=serialize(value); values[key]=table.Copy(value); return key end
 util.JSONToTable=function(text) return values[text] and table.Copy(values[text]) end
 function SysTime() return clock end
 function RealTime() return clock end
`;
const serverFixture=common+`
 MOVETYPE_WALK=2; IN_JUMP=1; IN_ATTACK=2; IN_ATTACK2=4; IN_DUCK=8; IN_USE=16
 saved=nil; packets={}; delayed={}
 function PLUGIN:GetData() return saved end
 function PLUGIN:SetData(v) saved=table.Copy(v) end
 function Vector() return {DistToSqr=function() return 0 end,Length2DSqr=function() return 0 end} end
 timer.Simple=function(t,fn) delayed[#delayed+1]=fn end
 net.Start=function(name) packet={name=name} end
 net.WriteUInt=function(n) packet.size=n end
 net.WriteData=function(bytes) packet.bytes=bytes end
 net.WriteEntity=function(p) packet.entity=p end
 net.Send=function(p) packet.target=p; packets[#packets+1]=packet end
 net.Broadcast=function() packet.broadcast=true; packets[#packets+1]=packet end
 util.IsValidModel=function(model) return model~='models/missing.mdl' end
 function user(id,admin)
  local character={GetName=function() return 'Author '..id end}
  local p={valid=true,id=tostring(id),admin=admin or false,character=character,model='models/player/kleiner.mdl',vars={},items={},alive=true,
   hands={valid=true,GetClass=function() return 'ix_hands' end},notices={}}
  function p:SteamID64() return self.id end
  function p:IsAdmin() return self.admin end
  function p:GetCharacter() return self.character end
  function p:GetModel() return self.model end
  function p:LookupSequence(name) return name=='idle' and 1 or -1 end
  function p:LookupBone(name) return ({Hand=0,Head=1})[name] end
  function p:GetItems() return self.items end
  function p:Alive() return self.alive end
  function p:OnGround() return true end
  function p:InVehicle() return false end
  function p:WaterLevel() return 0 end
  function p:IsFrozen() return false end
  function p:GetMoveType() return MOVETYPE_WALK end
  function p:GetVelocity() return Vector() end
  function p:GetPos() return Vector() end
  function p:GetLocalVar(key,default) if self.vars[key]~=nil then return self.vars[key] end return default end
  p.GetNetVar=p.GetLocalVar
  function p:SetNW2Bool(key,v) self.vars[key]=v end
  function p:GetWeapon() return self.hands end
  function p:GetActiveWeapon() return self.active or self.hands end
  function p:SelectWeapon(class) self.selected=class end
  function p:ForceSequence(name,callback,duration,noFreeze)
   eq(noFreeze,true); eq(duration,0); self.callback=callback; self.vars.forcedSequence=1; return 0
  end
  function p:LeaveSequence()
   self.left=(self.left or 0)+1; self.vars.forcedSequence=nil
   local callback=self.callback; self.callback=nil; if callback then callback() end
  end
  function p:SetCycle(cycle) self.cycle=cycle end
  function p:SetPlaybackRate(rate) self.rate=rate end
  function p:Notify(message) self.notices[#self.notices+1]=message end
  return p
 end
 function reply() return packet.bytes and util.JSONToTable(packet.bytes) end
 function put(p,clip,id,revision) PLUGIN:SavePose(p,{clip=clip or makeClip(),id=id,revision=revision}); return reply() end
 function owned(p) for _,row in pairs(PLUGIN.poseStore.clips) do if row.owner==p.id then return row end end end
`;
module.exports=function(runSuite){
 const suite=(name,files,...rest)=>runSuite(name,files.flatMap(f=>f===shared?[f,'ixhl2rp/plugins/pose_studio/sh_rig.lua']: [f]),...rest);
 suite('Pose Studio schema: finite transforms, bounded frames/props, canonical fields and no traversal', [shared], `
  local S=ix.PoseStudio
  local raw=makeClip(); raw.lua='bad'; raw.frames[1].bones.Hand.eval='bad'
  local c=S.Validate(raw); assert(c); eq(c.lua,nil); eq(c.frames[1].bones.Hand.eval,nil)
  raw.frames[1].bones.Hand.a[1]=5; eq(c.frames[1].bones.Hand.a[1],0)
  for _,path in ipairs({'../evil.mdl','models/../evil.mdl','models/x.lua','https://x/a.mdl','models/x\\\\y.mdl'}) do
   local bad=makeClip(); bad.model=path; eq(S.Validate(bad),nil)
  end
  for _,value in ipairs({math.huge,-math.huge,181}) do local bad=makeClip(); bad.frames[1].bones.Hand.a[1]=value; eq(S.Validate(bad),nil) end
  local bad=makeClip(); bad.frames[1].bones.Hand.p[1]=0/0; eq(S.Validate(bad),nil)
  bad=makeClip(); bad.frames[1].bones.Hand.p[1]=13; eq(S.Validate(bad),nil)
  bad=makeClip(); bad.frames={}; eq(S.Validate(bad),nil)
  bad=makeClip(); bad.frames.extra={duration=1,bones={}}; eq(S.Validate(bad),nil)
  bad=makeClip(); for i=2,25 do bad.frames[i]=table.Copy(bad.frames[1]) end; eq(S.Validate(bad),nil)
  bad=makeClip(); for i=1,97 do bad.frames[1].bones['Bone'..i]=S.Identity() end; eq(S.Validate(bad),nil)
  bad=makeClip(); bad.props={'invalid'}; eq(S.Validate(bad),nil)
  bad=makeClip(); bad.name='\0'; eq(S.Validate(bad),nil)
  bad=makeClip(); bad.frames[1].duration=.01; eq(S.Validate(bad),nil)
 `,common);
 suite('Pose Studio timing: shortest rotations, identity on missing keys, one-shot holds and seamless loop segment', [shared], `
  local S=ix.PoseStudio; local c=makeClip(); c.smooth=false
  c.frames[1].bones.Hand.a[2]=170
  c.frames[2]={duration=2,bones={Hand={a={0,-170,0},p={10,0,0}},Head={a={0,0,0},p={0,4,0}}}}
  local t,index=S.Sample(c,.5); near(t.Hand.a[2],180); near(t.Hand.p[1],5); near(t.Head.p[2],2); eq(index,1)
  t,index=S.Sample(c,2); eq(index,2); near(t.Hand.p[1],5); near(t.Head.p[2],2)
  t=S.Sample(c,3); near(t.Hand.p[1],0)
  c.loop=false; t=S.Sample(c,3); near(t.Hand.p[1],10); near(t.Head.p[2],4)
  c.smooth=true; t=S.Sample(c,.25); near(t.Hand.p[1],1.5625)
  local single=makeClip(); single.loop=false; single.frames[1].bones.Hand.p[1]=7
  t=S.Sample(single,500); near(t.Hand.p[1],7)
 `,common);
 suite('Pose Studio server: every player can create; ownership, review, import and revision conflicts enforced', [shared,server], `
  local p,other,admin=user(1),user(2),user(3,true)
  PLUGIN:OpenStudio(p); eq(packet.name,'ixPoseStudioOpen')
  local result=put(p); eq(result.kind,'saved'); local r=owned(p); eq(r.status,'private')
  PLUGIN:HandlePose(other,{op='load',id=r.id}); eq(reply().kind,'error')
  PLUGIN:HandlePose(other,{op='save',id=r.id,revision=r.revision,clip=makeClip()}); eq(reply().kind,'error'); eq(r.owner,p.id)
  PLUGIN:HandlePose(other,{op='approve',id=r.id}); eq(r.status,'private')
  PLUGIN:HandlePose(p,{op='submit',id=r.id}); eq(r.status,'pending')
  PLUGIN:HandlePose(other,{op='import',id=r.id}); eq(PLUGIN:PoseCount(other.id),0)
  PLUGIN:HandlePose(admin,{op='approve',id=r.id}); eq(r.status,'approved')
  PLUGIN:HandlePose(other,{op='import',id=r.id}); eq(PLUGIN:PoseCount(other.id),1)
  local copy=owned(other); eq(copy.status,'private'); assert(copy.id~=r.id)
  copy.clip.name='mine'; eq(r.clip.name,'Test pose')
  put(p,makeClip(),r.id,r.revision+1); eq(reply().kind,'error'); eq(r.revision,1)
  put(p,makeClip(),r.id,1); local updated=PLUGIN.poseStore.clips[tostring(r.id)]; eq(updated.status,'private'); eq(updated.revision,2)
  PLUGIN:HandlePose(other,{op='delete',id=r.id}); assert(PLUGIN.poseStore.clips[tostring(r.id)])
  PLUGIN:HandlePose(admin,{op='delete',id=r.id}); eq(PLUGIN.poseStore.clips[tostring(r.id)],nil)
 `,serverFixture);
 suite('Pose Studio server: quotas, model/bone checks and live inventory prop authorization', [shared,server], `
  local p,admin=user(1),user(2,true)
  local c=makeClip(); local prop=ix.PoseStudio.Identity(); prop.model='models/props_junk/garbage_mug001a.mdl'; prop.bone='Hand'; prop.scale=1; prop.skin=0; c.props={prop}
  put(p,c); eq(reply().kind,'error')
  PLUGIN:SetPoseProp(p,prop.model,true); eq(PLUGIN.poseStore.props[prop.model],nil)
  p.items={{GetName=function() return 'Cup' end,GetModel=function() return prop.model end}}
  put(p,c); eq(reply().kind,'saved'); local r=owned(p)
  p.items={}; PLUGIN:PlayPose(p,r); eq(PLUGIN.poseActive[p],nil)
  PLUGIN:SetPoseProp(admin,prop.model,true); clock=clock+2; PLUGIN:PlayPose(p,r); assert(PLUGIN.poseActive[p])
  PLUGIN:SetPoseProp(admin,prop.model,false); PLUGIN:Think(); eq(PLUGIN.poseActive[p],nil)
  c=makeClip(); c.model='models/player/alyx.mdl'; put(p,c); eq(reply().kind,'error')
  c=makeClip(); c.frames[1].bones.Unknown=ix.PoseStudio.Identity(); put(p,c); eq(reply().kind,'error')
  c=makeClip(); c.base='missing'; put(p,c); eq(reply().kind,'error')
  for i=2,30 do put(p) end; eq(PLUGIN:PoseCount(p.id),30)
  put(p); eq(reply().kind,'error'); eq(PLUGIN:PoseCount(p.id),30)
 `,serverFixture);
 suite('Pose Studio lifecycle: attack cancellation, damage, sequence ownership, model and character changes', [shared,server], `
  local p=user(1); put(p); local r=owned(p)
  local function play() clock=clock+2; PLUGIN:PlayPose(p,r); assert(PLUGIN.poseActive[p]) end
  play(); eq(p.rate,0); eq(p.selected,'ix_hands')
  local removed={}; local cmd={GetForwardMove=function() return 0 end,GetSideMove=function() return 0 end,GetUpMove=function() return 0 end,
   KeyDown=function(_,key) return key==IN_ATTACK end,RemoveKey=function(_,key) removed[key]=true end}
  PLUGIN:StartCommand(p,cmd); eq(PLUGIN.poseActive[p],nil); eq(p.vars.forcedSequence,nil); eq(p.rate,1); eq(removed[IN_ATTACK],true)
  play(); PLUGIN:EntityTakeDamage(p,{GetDamage=function() return 4 end}); eq(PLUGIN.poseActive[p],nil)
  play(); p.vars.forcedSequence=42; local left=p.left; PLUGIN:Think(); eq(PLUGIN.poseActive[p],nil); eq(p.left,left); eq(p.vars.forcedSequence,42)
  p.vars.forcedSequence=nil; play(); p.model='models/player/alyx.mdl'; PLUGIN:Think(); eq(PLUGIN.poseActive[p],nil)
  p.model=r.clip.model; play(); p.character={}; PLUGIN:Think(); eq(PLUGIN.poseActive[p],nil)
  play(); p.alive=false; PLUGIN:PlayerDeath(p); eq(PLUGIN.poseActive[p],nil)
 `,serverFixture);
 suite('Pose Studio playback: static holds, natural completion, late join sync and death/vehicle blockers', [shared,server], `
  local p=user(1); local c=makeClip(); c.loop=false; put(p,c); local r=owned(p)
  PLUGIN:PlayPose(p,r); clock=clock+40; PLUGIN:Think(); assert(PLUGIN.poseActive[p])
  local late=user(2); PLUGIN:PlayerLoadedCharacter(late); eq(#delayed,1); delayed[1](); eq(#delayed,2); delayed[2]()
  eq(packet.target,late); eq(packet.name,'ixPoseStudioState'); eq(packet.entity,p)
  PLUGIN:StopPose(p); c.frames[2]=table.Copy(c.frames[1]); put(p,c,r.id,1); r=owned(p)
  clock=clock+2; PLUGIN:PlayPose(p,r); clock=clock+3; PLUGIN:Think(); eq(PLUGIN.poseActive[p],nil)
  p.vars.ragdoll=45; clock=clock+2; PLUGIN:PlayPose(p,r); eq(PLUGIN.poseActive[p],nil)
  p.vars.ragdoll=0; p.vars.tied=true; clock=clock+2; PLUGIN:PlayPose(p,r); eq(PLUGIN.poseActive[p],nil)
  p.vars.tied=false; p.InVehicle=function() return true end; clock=clock+2; PLUGIN:PlayPose(p,r); eq(PLUGIN.poseActive[p],nil)
 `,serverFixture);
 suite('Pose Studio persistence and network: malformed packets, throttling, restore and private catalog boundaries', [shared,server], `
  local p,other=user(1),user(2); put(p); local r=owned(p); PLUGIN:SaveData()
  saved.clips.bad={owner=p.id,clip={}}; saved.props['../../bad']=true
  PLUGIN.poseStore={nextID=1,clips={},props={}}; PLUGIN:LoadData(); eq(count(PLUGIN.poseStore.clips),1); eq(PLUGIN.poseStore.nextID,2)
  PLUGIN:PoseCatalog(other,'own',1); eq(#reply().rows,0)
  PLUGIN:PoseCatalog(other,'shared',1); eq(#reply().rows,0)
  PLUGIN:PoseCatalog(other,'review',1); eq(reply().kind,'error')
  local raw=util.TableToJSON({op='save',clip=makeClip()}); local reads=0
  net.ReadUInt=function() reads=reads+1; return #raw end; net.ReadData=function() return raw end
  net.handlers.ixPoseStudioRequest(50001*8,p); eq(reads,0)
  net.handlers.ixPoseStudioRequest(16,p); eq(PLUGIN:PoseCount(p.id),1)
  net.handlers.ixPoseStudioRequest(#raw*8+16,p); eq(PLUGIN:PoseCount(p.id),2)
  p.ixPoseBudget={tokens=0,time=clock}; net.handlers.ixPoseStudioRequest(#raw*8+16,p); eq(PLUGIN:PoseCount(p.id),2)
  clock=clock+1; net.handlers.ixPoseStudioRequest(#raw*8+16,p); eq(PLUGIN:PoseCount(p.id),3)
 `,serverFixture);
 suite('Pose Studio render: parent rotation/translation carries attachments; cleanup never overwrites other bone modifiers',
  ['tools/fixtures/sharedposes.lua',shared,client], `
   local S=ix.PoseStudio
   getmetatable(Matrix()).SetAngles=function(self,a)
    local yaw=math.rad(a.y); self[1][1]=math.cos(yaw); self[1][2]=-math.sin(yaw)
    self[2][1]=math.sin(yaw); self[2][2]=math.cos(yaw)
   end
   local matrices={[0]=Matrix(),[1]=Matrix(),[2]=Matrix()}; matrices[1]:SetTranslation(Vector(10,0,0)); matrices[2]:SetTranslation(Vector(12,0,0))
   local entity={valid=true,GetBoneCount=function() return 3 end,GetBoneMatrix=function(_,i) return matrices[i] end,
    GetBoneParent=function(_,i) return i-1 end,GetBoneName=function(_,i) return ({[0]='Root','Hand','Helper'})[i] end,
    SetBoneMatrix=function(_,i,m) matrices[i]=m end,RemoveCallback=function(_,name,id) eq(name,'BuildBonePositions'); eq(id,5); removed=true end,
    InvalidateBoneCache=function() invalidated=true end}
   S.ApplyBones(entity,{Root={a={0,90,0},p={0,2,0}}})
   near(matrices[1]:GetTranslation().x,0); near(matrices[1]:GetTranslation().y,12)
   near(matrices[2]:GetTranslation().y,14)
   local prop={valid=true,Remove=function(self) self.valid=false end}
   S.Detach(entity,{callback=5,props={prop}}); eq(removed,true); eq(invalidated,true); eq(prop.valid,false)
  `,common+`
   hook.Add=function() end; concommand={Add=function() end}; notification={AddLegacy=function() end}
   function Angle(p,y,r) return {p=p,y=y,r=r} end
  `);
 // Editor methods are exercised independently of the engine renderer.
 const editorFixture=common+`
  CLIENT=true; SERVER=false; registered={}; hooks={}
  surface={CreateFont=function() end}; function Color(...) return {...} end
  vgui={Register=function(name,definition) registered[name]=definition end}
  net.Receive=function(name,fn) net.handlers[name]=fn end
  local p={valid=true,SteamID64=function() return '1' end}; function LocalPlayer() return p end
  function makeEditorClip()
   local clip=makeClip(); clip.frames[1].bones={['ValveBiped.Bip01_R_Hand']=clip.frames[1].bones.Hand}; return clip
  end
  function draft()
   local e=setmetatable({clip=makeEditorClip(),frame=1,undo={},owner='1',viewport={state={props={}}}}, {__index=registered.ixPoseStudio})
   e.RefreshFields=function() end; e.RefreshTimeline=function() end; e.RefreshProps=function() end
   return e
  end
 `;
 require('./test-pose-portability.cjs')(suite,{shared,server,client,editor,gizmo,common,serverFixture,editorFixture});
 suite('Pose Studio editor: independent duplicated frames, reorder, undo and last-frame protection', [shared,gizmo,editor], `
  local e=draft(); e:AddFrame(); eq(#e.clip.frames,2); eq(e.frame,2)
  e.clip.frames[2].bones['ValveBiped.Bip01_R_Hand'].p[1]=4; eq(e.clip.frames[1].bones['ValveBiped.Bip01_R_Hand'].p[1],0)
  e:MoveFrame(2,-1); eq(e.frame,1); eq(e.clip.frames[1].bones['ValveBiped.Bip01_R_Hand'].p[1],4)
  ix.PoseStudio.ClearProps=function() end
  e:Undo(); eq(e.frame,2); eq(e.clip.frames[2].bones['ValveBiped.Bip01_R_Hand'].p[1],4)
  e:DeleteFrame(); eq(#e.clip.frames,1); e:DeleteFrame(); eq(#e.clip.frames,1)
  for i=1,30 do e:AddFrame() end; eq(#e.clip.frames,24)
 `,editorFixture);
 suite('Pose Studio editor: save preserves ownership, blocks duplicate requests and sends revision', [shared,gizmo,editor], `
  local requests={}; ix.PoseStudio.Request=function(data) requests[#requests+1]=data; return true end
  local e=draft(); e.id=12; e.revision=3; e:Save(); eq(#requests,1); eq(requests[1].revision,3); eq(e.saving,true)
  e:Save(); eq(#requests,1); e:Duplicate(); eq(e.id,12)
  e.saving=false; e.owner='2'; e:Save(); eq(#requests,1)
  e.dirty=false; e:Duplicate(); eq(requests[2].op,'import'); eq(requests[2].id,12)
 `,editorFixture);

 suite('Pose Studio viewport: full-screen projections map to drawn joints and clickable local points after resize/move', [shared,gizmo,editor], `
  local V=registered.ixPoseStudioViewport
  local sw,sh=1920,1080; function ScrW() return sw end; function ScrH() return sh end
  local projected={x=533,y=699,visible=true}
  local position={ToScreen=function() return table.Copy(projected) end}
  local entity={valid=true,GetBoneCount=function() return 1 end,GetBoneName=function() return 'ValveBiped.Bip01_R_Hand' end,
   GetBoneParent=function() return -1 end,GetBoneMatrix=function() return {GetTranslation=function() return position end} end}
  local e={clip=makeEditorClip(),SelectBone=function(self,name) self.selectedBone=name end,Checkpoint=function() end}
  local v=setmetatable({w=1265,h=766,left=300,top=112,Entity=entity,editor=e,showBones=true,points={}}, {__index=V})
  function v:GetWide() return self.w end; function v:GetTall() return self.h end
  function v:ScreenToLocal(x,y) return x-self.left,y-self.top end
  function v:MouseCapture(value) self.captured=value end
  v.BaseClass={Paint=function(self)
   local outerW,outerH=sw,sh; sw,sh=self.w,self.h
   if IsValid(self.Entity) then self:PostDrawModel(self.Entity) end
   sw,sh=outerW,outerH
  end}
  draw={RoundedBox=function() end,SimpleText=function() end}
  local rectangles={}; surface.SetDrawColor=function() end
  surface.DrawRect=function(x,y,w,h) rectangles[#rectangles+1]={x=x,y=y,w=w,h=h} end
  local mx,my; gui={MousePos=function() return mx,my end}; MOUSE_LEFT=1; MOUSE_MIDDLE=2
  v:Paint(v.w,v.h)
  near(v.points['ValveBiped.Bip01_R_Hand'].x,351.16927083333); near(v.points['ValveBiped.Bip01_R_Hand'].y,495.77222222222)
  near(rectangles[1].x+2,v.points['ValveBiped.Bip01_R_Hand'].x); near(rectangles[1].y+2,v.points['ValveBiped.Bip01_R_Hand'].y)
  mx,my=v.left+v.points['ValveBiped.Bip01_R_Hand'].x,v.top+v.points['ValveBiped.Bip01_R_Hand'].y; v:OnMousePressed(MOUSE_LEFT)
  eq(e.selectedBone,'ValveBiped.Bip01_R_Hand'); eq(v.drag.kind,'select'); eq(v.captured,true)
  v:OnMouseReleased(); eq(v.drag,nil); eq(v.captured,false)
  -- Reproduce multiple aspect ratios, orbit/zoom projections and panel origins.
  for _,case in ipairs({{2560,1080,1710,700,220,88,.7,.3},{1280,1024,600,650,280,100,.2,.8},{3840,2160,2800,1600,320,200,.5,.5}}) do
   sw,sh,v.w,v.h,v.left,v.top=table.unpack(case,1,6)
   projected.x=sw*case[7]; projected.y=sh*case[8]; e.selectedBone=nil
   rectangles={}; v:Paint(v.w,v.h)
   near(v.points['ValveBiped.Bip01_R_Hand'].x,v.w*case[7]); near(v.points['ValveBiped.Bip01_R_Hand'].y,v.h*case[8])
   mx,my=v.left+v.w*case[7],v.top+v.h*case[8]; v:OnMousePressed(MOUSE_LEFT)
   eq(e.selectedBone,'ValveBiped.Bip01_R_Hand'); eq(v.drag.kind,'select'); v:OnMouseReleased()
  end
  projected.x=sw*1.1; e.selectedBone=nil; v:Paint(v.w,v.h); eq(v.points['ValveBiped.Bip01_R_Hand'].visible,false)
  projected.x=sw*.5; projected.visible=false; v:Paint(v.w,v.h)
  mx,my=v.left+v.w*.5,v.top+v.h*.5; v:OnMousePressed(MOUSE_LEFT); eq(e.selectedBone,nil); eq(v.drag.kind,'orbit')
  v.Entity.valid=false; v:Paint(v.w,v.h); eq(next(v.points),nil)
 `,editorFixture);
 suite('Pose Studio skeleton list: builds before reading, retries a late Workshop skeleton and retains search filtering', [shared,gizmo,editor], `
  local V,P=registered.ixPoseStudioViewport,registered.ixPoseStudio
  local ready=false; local reads=0; local builds=0; local countNow=0
  local names={'ValveBiped.Bip01_R_Hand','ValveBiped.Bip01_Head1','coat_helper','ValveBiped.Anim_Attachment_RH'}
  local entity={valid=true,SetupBones=function() builds=builds+1; if ready then countNow=#names end end,
   GetBoneCount=function() return countNow end,GetBoneName=function(_,i) return names[i+1] end}
  local buttons={}; local query=''; local list={Clear=function() buttons={} end}
  function list:Add()
   local b={SetText=function() end,SetTall=function() end,Dock=function() end,DockMargin=function() end,SetTooltip=function() end}
   buttons[#buttons+1]=b; return b
  end
  local e=setmetatable({valid=true,clip=makeEditorClip(),bones=list,search={GetValue=function() return query end}}, {__index=P})
  local v=setmetatable({valid=true,Entity=entity,editor=e}, {__index=V}); e.viewport=v
  e:FillBones(); eq(builds,1); eq(#buttons,0)
  v:Think(); eq(builds,1)
  ready=true; entity:SetupBones(); v:Think(); eq(#buttons,2)
  local previous=builds; v:Think(); eq(builds,previous)
  query='head'; e:FillBones(); eq(#buttons,1); eq(buttons[1].caption,'Голова')
 `,editorFixture);

 suite('Cellar editor viewport: helpers are hidden, lines skip helpers and stale selections cannot edit or attach', [shared,gizmo,editor], `
  local S=ix.PoseStudio; local e=draft(); e.Message=function(self,text) self.message=text end
  e.selectedBone='coat_helper'; e.clip.frames[1].bones.coat_helper=S.Identity()
  eq(e:CurrentTransform(true),nil); e:SelectBone('ValveBiped.forward'); eq(e.selectedBone,'coat_helper')
  e.propModel='models/cup.mdl'; e:AddProp(); eq(#e.clip.props,0); assert(e.message)
  local points={[0]={x=1},[1]={x=2},[2]={x=3},[3]={x=4}}
  local names={[0]='ValveBiped.Bip01_R_UpperArm','coat_helper','ValveBiped.Bip01_R_Forearm','ValveBiped.Anim_Attachment_RH'}
  local entity={GetBoneCount=function() return 4 end,GetBoneName=function(_,i) return names[i] end,
   GetBoneParent=function(_,i) return i-1 end,GetBoneMatrix=function(_,i) return {GetTranslation=function() return points[i] end} end}
  local lines={}; render={DrawLine=function(a,b) lines[#lines+1]={a,b} end}
  local v=setmetatable({editor=e,showBones=true}, {__index=registered.ixPoseStudioViewport})
  v.ProjectBonePoint=function(_,pos) return pos end
  v:PostDrawModel(entity); eq(count(v.points),2); eq(v.points.coat_helper,nil)
  eq(#lines,1); eq(lines[1][1],points[2]); eq(lines[1][2],points[0])
  eq(e.clip.frames[1].bones.coat_helper.a[1],0)
 `,editorFixture);
 suite('Pose Studio rotation rings: perspective projection, local axes, visible picking and clockwise UI strokes',
  ['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua',shared,gizmo,editor], `
   local S=ix.PoseStudio; local V=registered.ixPoseStudioViewport
   local eye=Vector(90,-80,60); local target=Vector(0,0,0); local camera=(target-eye):Angle()
   local w,h=1265,766; local focal=w/(2*math.tan(math.rad(34/2)))
   function ScrW() return 1920 end; function ScrH() return 1080 end
   function getmetatableVector() return getmetatable(Vector()) end
   getmetatableVector().ToScreen=function(pos)
    local delta=pos-eye; local depth=delta:Dot(camera:Forward())
    return {x=(.5+delta:Dot(camera:Right())*focal/depth/w)*ScrW(),
     y=(.5-delta:Dot(camera:Up())*focal/depth/h)*ScrH(),visible=depth>0}
   end
   local v=setmetatable({rings={}}, {__index=V})
   function v:GetWide() return w end; function v:GetTall() return h end
   function v:GetCamPos() return eye end; function v:GetLookAt() return target end
   local m={GetTranslation=function() return target end,GetAngles=function() return Angle(0,0,0) end}
   v:BuildRotationGizmo(m); eq(#v.rings,3)
   for index,ring in ipairs(v.rings) do
    eq(ring.axis,index); eq(#ring.points,73); eq(ring.edgeOn,false)
    for i=1,72 do
     local p=ring.points[i]
     near(math.AngleDifference(S.RotationRingAngle(ring,p.x,p.y),(i-1)*5),0)
    end
    local point=ring.points[9]
    local hit=S.PickRotationRing(v.rings,point.x,point.y); eq(hit.ring.axis,index)
    local invisible=table.Copy(ring); for _,p in ipairs(invisible.points) do p.visible=false end
    eq(S.PickRotationRing({invisible},point.x,point.y),nil)
   end
   eq(S.PickRotationRing(v.rings,0,0),nil)
   local polygons=0
   surface.SetDrawColor=function() end
   surface.DrawPoly=function(vertices)
    local area=0
    for i=1,4 do local a,b=vertices[i],vertices[i%4+1]; area=area+a.x*b.y-b.x*a.y end
    assert(area>0,'UI stroke winding must be clockwise'); polygons=polygons+1
   end
   draw={NoTexture=function() end,RoundedBox=function() end,SimpleText=function() end}
   function v:CursorPos() return 0,0 end
   v:PaintRotationGizmo(); eq(polygons,3*72*2)
   eye=Vector(100,0,0); camera=(target-eye):Angle(); v.rings={}; v:BuildRotationGizmo(m)
   eq(v.rings[1].edgeOn,false); eq(v.rings[2].edgeOn,true); eq(v.rings[3].edgeOn,true)
  `,editorFixture);
 suite('Pose Studio ring rotation: compound bone axes, full turns, angle wrap and edge-on fallback',
  ['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua',shared,gizmo], `
   local S=ix.PoseStudio; local start={15,35,25}; local angle=Angle(table.unpack(start))
   local basis={angle:Forward(),-angle:Right(),angle:Up()}
   for index=1,3 do
    local result=S.RotateBoneAngle(start,index,90); local turned=Angle(table.unpack(result))
    local nextBasis={turned:Forward(),-turned:Right(),turned:Up()}
    vectorNear(nextBasis[index],basis[index])
    vectorNear(nextBasis[index%3+1],basis[(index+1)%3+1])
    vectorNear(nextBasis[(index+1)%3+1],-basis[index%3+1])
    local reset=Angle(table.unpack(S.RotateBoneAngle(result,index,-90)))
    vectorNear(reset:Forward(),angle:Forward()); vectorNear(reset:Up(),angle:Up())
    local full=Angle(table.unpack(S.RotateBoneAngle(start,index,360)))
    vectorNear(full:Forward(),angle:Forward()); vectorNear(full:Up(),angle:Up())
   end
   local ring={center={x=100,y=100},u={x=55,y=0,z=0},v={x=0,y=55,z=0}}
   local drag={ring=ring,lastAngle=179}
   near(S.RotationDragDelta(drag,100+55*math.cos(math.rad(-179)),100+55*math.sin(math.rad(-179)),0,0),2)
   eq(S.RotationDragDelta(drag,100,100,0,0),0); eq(drag.lastAngle,nil)
   eq(S.RotationDragDelta(drag,155,100,0,0),0)
   drag.ring.edgeOn=true; drag.tx=1; drag.ty=0
   near(S.RotationDragDelta(drag,0,0,55*math.pi/2,17),90)
  `,editorFixture);
 suite('Pose Studio ring interaction: one undo, persistent drag, fine control, translation preserved and capture cleanup',
  ['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua',shared,gizmo,editor], `
   local S=ix.PoseStudio; local e=draft(); e.selectedBone='ValveBiped.Bip01_R_Hand'; e.clip.frames[1].bones['ValveBiped.Bip01_R_Hand'].p={1,2,3}
   local ring={axis=3,center={x=100,y=100},u={x=55,y=0,z=0},v={x=0,y=55,z=0},points={}}
   for step=0,72 do local r=math.rad(step*5); ring.points[#ring.points+1]={x=100+55*math.cos(r),y=100+55*math.sin(r),visible=true} end
   local v=setmetatable({editor=e,rings={ring},points={},showBones=true,distance=145}, {__index=registered.ixPoseStudioViewport})
   local mx,my=455,200; gui={MousePos=function() return mx,my end}; MOUSE_LEFT=1; MOUSE_MIDDLE=2
   local fine=false; input={IsKeyDown=function() return fine end}
   function v:ScreenToLocal(x,y) return x-300,y-100 end
   function v:MouseCapture(value) self.captured=value end
   e.viewport=v
   v:OnMousePressed(MOUSE_LEFT); eq(v.drag.kind,'ring'); eq(#e.undo,1)
   v:OnMouseWheeled(1); eq(v.distance,145)
   mx,my=400,255; v:Think(); near(e.clip.frames[1].bones['ValveBiped.Bip01_R_Hand'].a[2],90)
   near(e.clip.frames[1].bones['ValveBiped.Bip01_R_Hand'].p[1],1); near(e.clip.frames[1].bones['ValveBiped.Bip01_R_Hand'].p[3],3)
   fine=true; mx,my=345,200; v:Think(); near(e.clip.frames[1].bones['ValveBiped.Bip01_R_Hand'].a[2],103.5); eq(#e.undo,1)
   v:OnMouseReleased(); eq(v.drag,nil); eq(v.captured,false)
   mx,my=455,200; v:OnMousePressed(MOUSE_LEFT); e.frame=2
   mx,my=400,255; v:Think(); eq(v.drag,nil); eq(v.captured,false)
   e.frame=1; mx,my=455,200; v:OnMousePressed(MOUSE_LEFT); v:OnMouseCaptureLost(); eq(v.drag,nil)
  `,editorFixture);

 const placementShared='ixhl2rp/plugins/pose_studio/sh_placement.lua';
 const placementServer='ixhl2rp/plugins/pose_studio/sv_placement.lua';
 const vectorFiles=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua'];
 const placementFixture=serverFixture+`
  function isvector(v) return type(v)=='table' and type(v.x)=='number' end
  net.WriteBool=function() end; MOVETYPE_NONE=0; COLLISION_GROUP_WORLD=20; MASK_PLAYERSOLID=1
  function placementPlayer(id)
   local p=user(id or 1); p.position=Vector(); p.angle=Angle(); p.moveType=MOVETYPE_WALK; p.collision=5
   function p:GetPos() return self.position end
   function p:SetPos(v) self.position=v end
   function p:GetAngles() return self.angle end
   function p:SetAngles(v) self.angle=v end
   function p:GetMoveType() return self.moveType end
   function p:SetMoveType(v) self.moveType=v end
   function p:GetCollisionGroup() return self.collision end
   function p:SetCollisionGroup(v) self.collision=v end
   function p:SetNetVar(k,v) self.vars[k]=v end
   function p:SetLocalVelocity() end
   function p:GetHull() return Vector(-16,-16,0),Vector(16,16,72) end
   function p:EyePos() return self.position+Vector(0,0,64) end
   function p:EyeAngles() return self.angle end
   function p:GetForward() return self.angle:Forward() end
   function p:GetRight() return self.angle:Right() end
   function p:OnGround() return self.moveType==MOVETYPE_WALK end
   function p:ForceSequence(name,cb,duration,noFreeze)
    PLUGIN:PlayerEnterSequence(self)
    self.sequenceMove=self.moveType; self.vars.forcedSequence=1; self.callback=cb
    if not noFreeze then self.moveType=MOVETYPE_NONE end
    return duration or 2
   end
   function p:LeaveSequence()
    if self.leaving then return end
    self.leaving=true; local cb=self.callback; self.callback=nil
    PLUGIN:PlayerLeaveSequence(self)
    self.vars.forcedSequence=nil; self.moveType=self.sequenceMove or MOVETYPE_WALK
    self.leaving=nil; if cb then cb() end
   end
   return p
  end
 `;
 const placementMath=`
  SERVER=true; CLIENT=false
  local V=getmetatable(Vector())
  function V:DistToSqr(b) return (self.x-b.x)^2+(self.y-b.y)^2+(self.z-b.z)^2 end
  function V:Length2DSqr() return self.x^2+self.y^2 end
  function V:LengthSqr() return self.x^2+self.y^2+self.z^2 end
  util.IsInWorld=function() return not outside end
  util.TraceLine=function(data) return {Hit=blocked,HitPos=data.endpos} end
  util.TraceHull=function(data)
   if data.start:DistToSqr(data.endpos)<.001 then return {StartSolid=restoreBlocked,AllSolid=restoreBlocked,Hit=restoreBlocked} end
   if data.start.z>data.endpos.z then return {Hit=not noSupport,StartSolid=false,AllSolid=false,HitNormal=Vector(0,0,steep and .2 or 1),HitPos=Vector(data.start.x,data.start.y,0)} end
   return {Hit=ceiling,StartSolid=false,AllSolid=false}
  end
 `;
 suite('Pose placement: untrusted selections, private previews, model and inventory revalidation',
  [...vectorFiles,shared,placementShared,server,placementServer], `
   ${placementMath}
   local S=ix.PoseStudio; local p=placementPlayer(); local other=placementPlayer(2)
   put(p); local mine=owned(p); put(other); local theirs=owned(other)
   PLUGIN:PosePreview(p,{token=1,selection={kind='custom',id=mine.id}})
   eq(reply().kind,'preview'); eq(reply().preview.clip.name,'Test pose'); eq(PLUGIN.poseActive[p],nil)
   PLUGIN:PosePreview(p,{token=2,selection={kind='custom',id=theirs.id}}); assert(reply().error); eq(reply().preview,nil)
   theirs.status='approved'; PLUGIN:PosePreview(p,{token=3,selection={kind='custom',id=theirs.id}}); assert(reply().preview.clip)
   theirs.clip.model='models/player/alyx.mdl'; PLUGIN:PosePreview(p,{token=4,selection={kind='custom',id=theirs.id}}); assert(reply().error)
   eq(S.Selection({kind='custom',id=0/0}),nil); eq(S.Selection({kind='sit',id=25}),nil)
   eq(S.Selection({kind='act',name='Wave',variant=1.5}),nil)
   mine.clip.props={{model='models/prop.mdl',bone='Hand'}}
   PLUGIN:PosePreview(p,{token=5,selection={kind='custom',id=mine.id}}); assert(reply().error)
  `,placementFixture);
 suite('Pose placement: height bounds, support, visibility, finite positions and clear vertical travel',
  [...vectorFiles,shared,placementShared], `
   ${placementMath}
   local p=placementPlayer(); local S=ix.PoseStudio; local pos=Vector(30,0,0)
   local ok,_,final,angle=S.CheckPlacement(p,pos,90,48,Vector(10,0,-19))
   eq(ok,true); near(final.x,30); near(final.y,10); near(final.z,29); near(angle.y,90)
   eq(S.CheckPlacement(p,pos,0,-24,vector_origin),true)
   for _,v in ipairs({-25,49,math.huge,0/0}) do eq(S.CheckPlacement(p,pos,0,v,vector_origin),false) end
   eq(S.CheckPlacement(p,Vector(200,0,0),0,0),false)
   eq(S.CheckPlacement(p,Vector(0/0,0,0),0,0),false)
   blocked=true; eq(S.CheckPlacement(p,pos,0,0),false); blocked=false
   noSupport=true; eq(S.CheckPlacement(p,pos,0,0),false); noSupport=false
   steep=true; eq(S.CheckPlacement(p,pos,0,0),false); steep=false
   ceiling=true; eq(S.CheckPlacement(p,pos,0,48),false); ceiling=false
   outside=true; eq(S.CheckPlacement(p,pos,0,0),false)
  `,placementFixture);
 suite('Pose placement client: preview checks work without server-only IsInWorld; server still rejects outside points',
  [...vectorFiles,shared,placementShared], `
   ${placementMath}
   CLIENT=true; SERVER=false; util.IsInWorld=nil
   local p=placementPlayer(); local S=ix.PoseStudio; local pos=Vector(30,0,0)
   local ok,_,final=S.CheckPlacement(p,pos,0,24,Vector(0,0,-19))
   eq(ok,true); near(final.z,5)
   eq(S.CheckPlacement(p,pos,0,0,vector_origin),true)
   eq(S.CheckPlacement(p,Vector(200,0,0),0,0),false)
   blocked=true; eq(S.CheckPlacement(p,pos,0,0),false); blocked=false
   noSupport=true; eq(S.CheckPlacement(p,pos,0,0),false); noSupport=false
   ceiling=true; eq(S.CheckPlacement(p,pos,0,48),false); ceiling=false
   CLIENT=false; SERVER=true
   local checks=0; util.IsInWorld=function() checks=checks+1; return false end
   eq(S.CheckPlacement(p,pos,0,0),false); eq(checks,1)
  `,placementFixture);
 suite('Pose placement lifecycle: custom pose holds elevated position, exits restore movement and safe position',
  [...vectorFiles,shared,placementShared,server,placementServer], `
   ${placementMath}
   local p=placementPlayer(); put(p); local row=owned(p)
   local request={selection={kind='custom',id=row.id},anchor={30,0,0},yaw=90,height=24}
   PLUGIN:PlacePose(p,request); assert(PLUGIN.posePlaced[p]); assert(PLUGIN.poseActive[p]); eq(p.moveType,MOVETYPE_NONE)
   near(p:GetPos().x,30); near(p:GetPos().z,24); eq(p.collision,COLLISION_GROUP_WORLD)
   eq(PLUGIN:PoseAvailable(p),true); PLUGIN:Think(); assert(PLUGIN.poseActive[p])
   PLUGIN:HandlePose(p,{op='stopAll'}); eq(PLUGIN.posePlaced[p],nil); eq(PLUGIN.poseActive[p],nil)
   eq(p.vars.forcedSequence,nil); eq(p.vars.actEnterAngle,nil); eq(p.moveType,MOVETYPE_WALK); eq(p.collision,5)
   near(p:GetPos():Length(),0)
   clock=clock+2; PLUGIN:PlacePose(p,request); restoreBlocked=true; PLUGIN:StopPlacement(p)
   near(p:GetPos().x,30); eq(p.moveType,MOVETYPE_WALK); eq(p.collision,5)
   restoreBlocked=false; p:SetPos(Vector()); clock=clock+2; PLUGIN:PlacePose(p,request)
   p.alive=false; PLUGIN:PlayerDeath(p); near(p:GetPos().x,30); eq(PLUGIN.posePlaced[p],nil)
  `,placementFixture);
 suite('Pose placement: native and sit selections use the same placement and cancellation lifecycle',
  [...vectorFiles,shared,placementShared,server,placementServer], `
   ${placementMath}
   local p=placementPlayer(); local S=ix.PoseStudio
   ix.command={HasAccess=function() return true end}
   S.NativePreview=function(_,spec) return {sequence='idle',duration=0,offset=Vector(0,0,-12),static=true} end
   PLUGIN:PlacePose(p,{selection={kind='sit',id=23},anchor={30,0,0},yaw=0,height=24})
   assert(PLUGIN.posePlaced[p]); eq(PLUGIN.poseActive[p],nil); near(p:GetPos().z,12)
   PLUGIN:StartCommand(p,{GetForwardMove=function() return 1 end,RemoveKey=function() end})
   eq(PLUGIN.posePlaced[p],nil); eq(p.moveType,MOVETYPE_WALK)
   clock=clock+2
   PLUGIN:PlacePose(p,{selection={kind='act',name='Wave',variant=1},anchor={30,0,0},yaw=0,height=0})
   assert(PLUGIN.posePlaced[p]); p:LeaveSequence(); eq(PLUGIN.posePlaced[p],nil); eq(p.moveType,MOVETYPE_WALK)
   clock=clock+2; ix.command.HasAccess=function() return false end
   PLUGIN:PlacePose(p,{selection={kind='act',name='Wave',variant=1},anchor={30,0,0},yaw=0,height=0})
   eq(PLUGIN.posePlaced[p],nil)
  `,placementFixture);
 suite('Pose Studio camera: free flight moves without mouse delta, zoom, orbit switch and capture cleanup',
  [...vectorFiles,shared,gizmo,editor], `
   local V=registered.ixPoseStudioViewport; local v=setmetatable({focus=Vector(0,0,36),orbit=Angle(8,35,0),distance=145}, {__index=V})
   function v:MouseCapture(value) self.capture=value end
   function v:SetCamPos(value) self.camera=value end; function v:SetLookAt(value) self.look=value end
   function v:Fit() self.focus=Vector(0,0,36); self.distance=145 end
   local pressed={}; KEY_W=1; KEY_S=2; KEY_A=3; KEY_D=4; KEY_Q=5; KEY_E=6; KEY_LSHIFT=7
   input={IsKeyDown=function(key) return pressed[key] end}
   gui={MousePos=function() return 0,0 end}; function RealFrameTime() return .02 end
   local T=getmetatable(Vector()); function T:LengthSqr() return self:Length()^2 end
   v:SetCameraMode('free'); eq(v.cameraMode,'free'); local start=v.freePos
   v.drag={kind='fly',x=0,y=0}; pressed[KEY_W]=true; v:Think()
   near((v.freePos-start):Length(),1.5); local before=v.freePos
   v:OnMouseReleased(); v:OnMouseWheeled(1); near((v.freePos-before):Length(),8)
   v:SetCameraMode('fixed'); eq(v.drag,nil); eq(v.capture,false); eq(v.cameraMode,'fixed')
   local distance=v.distance; v:OnMouseWheeled(1); near(v.distance,distance-8)
  `,editorFixture);

 const previewFixture=common+vectorFiles.map(f=>require('./glua.cjs').normalize(require('fs').readFileSync(require('path').join(__dirname,'..',f),'utf8'))).join('\n')+`
  CLIENT=true; SERVER=false; registered={}; hooks={}; deadlines={}; requests={}; commands={}
  function Color(...) return {...} end; function Material() return {} end
  surface={CreateFont=function() end,PlaySound=function() end}
  vgui={Register=function(name,value) registered[name]=value end}
  hook.Add=function(event,id,fn) hooks[event..':'..id]=fn end; hook.Remove=function() end
  concommand={Add=function(name,fn) commands[name]=fn end}; function CreateClientConVar() end
  timer.Simple=function(_,fn) deadlines[#deadlines+1]=fn end
  current={valid=true,model='models/player/kleiner.mdl',character={}}
  function current:GetModel() return self.model end
  function current:GetCharacter() return self.character end
  function current:Alive() return true end
  function current:EyeAngles() return Angle() end
  function current:InVehicle() return false end
  function current:GetNetVar() return nil end
  function current:GetLocalVar(_,default) return default end
  function current:GetSkin() return 0 end; function current:GetBodyGroups() return {} end
  function current:GetPlayerColor() return Vector(1,1,1) end
  function LocalPlayer() return current end
  function SafeRemoveEntity(e) if e then e.valid=false end end
  created=0; cleared=0
  function ClientsideModel() created=created+1; return {valid=true,SetNoDraw=function() end,SetIK=function() end,SetSkin=function() end} end
  notification={AddLegacy=function(msg) notice=msg end}; ix.gui={}; ix.menu={IsOpen=function() return false end}
  gui={IsGameUIVisible=function() return false end}
  input={IsKeyDown=function(key) return keys[key] end,IsMouseDown=function(key) return mouse[key] end}; keys={}; mouse={}
  KEY_ESCAPE=1; KEY_LSHIFT=2; KEY_RSHIFT=3; KEY_LCONTROL=4; MOUSE_LEFT=5; MOUSE_RIGHT=6; IN_ATTACK=1; IN_ATTACK2=2
 `;
 suite('Animation previews: matching replies only, model changes, timeout and cleanup never affect editor/world',
  [shared,placementShared,'ixhl2rp/plugins/pose_studio/cl_preview.lua'], `
   local S=ix.PoseStudio
   S.Request=function(data) requests[#requests+1]=data end
   local results={}; local id=S.FetchPreview({kind='custom',id=1},function(data,err) results[#results+1]={data,err} end)
   eq(requests[1].op,'preview'); eq(requests[1].token,id)
   S.ReceivePreview({token=id+20,preview={sequence='idle'}}); eq(#results,0)
   S.ReceivePreview({token=id,preview={clip=makeClip()}}); eq(#results,1); eq(results[1][1].clip.name,'Test pose')
   deadlines[1](); eq(#results,1)
   id=S.FetchPreview({kind='sit',id=1},function(data,err) results[#results+1]={data,err} end)
   current.model='models/player/alyx.mdl'; S.ReceivePreview({token=id,preview={sequence='idle'}}); eq(#results,1)
   id=S.FetchPreview({kind='sit',id=1},function(data,err) results[#results+1]={data,err} end)
   deadlines[#deadlines](); eq(#results,2); assert(results[2][2])
   S.Detach=function() cleared=cleared+1 end
   S.ClearPreview({valid=true},{clip={}}); eq(cleared,1)
  `,previewFixture);
 suite('Animation wheel: larger center, hover debounce/cache and stale replies cannot replace current preview',
  [shared,placementShared,'ixhl2rp/plugins/pose_studio/cl_preview.lua','ixhl2rp/plugins/radialmenu.lua'], `
   local S=ix.PoseStudio; function ScrW() return 1920 end; function ScrH() return 1080 end
   local radial=registered.ixCharRadialMenu
   local _,_,normal,inner=radial.Geometry({}); near(normal,310); near(inner,133.3)
   local _,_,radius,large=radial.Geometry({poseToken=1}); near(radius,355); near(large,220.1)
   local model={valid=true,SetVisible=function(self,v) self.visible=v end,SetPaintedManually=function() end,
    ShowPreview=function(self,data) self.shown=data.sequence end}
   local panel={valid=true,Add=function() return model end}
   local waits={}; S.FetchPreview=function(spec,fn) waits[#waits+1]={spec,fn} end
   S.InstallWheelPreview(panel)
   local first,second={preview={kind='sit',id=1}},{preview={kind='sit',id=2}}
   panel:OnOptionHover(first); panel:PreviewThink(); eq(#waits,0)
   clock=clock+.2; panel:PreviewThink(); eq(#waits,1)
   panel:OnOptionHover(second); clock=clock+.5; panel:PreviewThink(); eq(#waits,2)
   waits[1][2]({sequence='first'}); eq(model.shown,nil)
   waits[2][2]({sequence='second'}); eq(model.shown,'second'); eq(model.visible,true)
   panel:OnOptionHover(first); clock=clock+.5; panel:PreviewThink(); eq(#waits,2); eq(model.shown,'first')
   panel:OnOptionsChanged(); eq(panel.previewOption,nil); eq(model.visible,false)
  `,previewFixture);
 suite('Placement ghost: cancel pending replies, height fine control, fire suppression, confirm packet and model cleanup',
  [shared,placementShared,'ixhl2rp/plugins/pose_studio/cl_placement.lua'], `
   local S=ix.PoseStudio; local waiting
   S.FetchPreview=function(_,callback) waiting=callback end
   S.SetPreview=function() return {} end; S.ClearPreview=function() cleared=cleared+1 end
   S.Request=function(data) requests[#requests+1]=data end
   S.PlacementPoint=function() return Vector(30,0,0) end
   S.CheckPlacement=function(_,anchor,yaw,height) return true,nil,anchor+Vector(0,0,height),Angle(0,yaw,0) end
   S.OpenPlacement({kind='sit',id=1}); S.CancelPlacement(); waiting({offset={0,0,0}}); eq(created,0)
   S.OpenPlacement({kind='sit',id=1}); waiting({offset={0,0,0}}); eq(created,1)
   local tick=hooks['Think:ixPosePlacement']; tick(); eq(S.placement.armed,true)
   local removed=0; local cmd={RemoveKey=function() removed=removed+1 end,GetMouseWheel=function() return 1 end}
   keys[KEY_LSHIFT]=true; hooks['CreateMove:ixPosePlacement'](cmd); eq(S.placement.height,2); eq(removed,2)
   keys[KEY_LCONTROL]=true; hooks['CreateMove:ixPosePlacement'](cmd); eq(S.placement.height,2.5)
   for i=1,200 do hooks['CreateMove:ixPosePlacement'](cmd) end; eq(S.placement.height,48)
   keys={}; hooks['CreateMove:ixPosePlacement'](cmd); near(S.placement.yaw,-176)
   local ghost=S.placement.entity
   eq(hooks['PlayerBindPress:ixPosePlacement'](current,'+attack',true),true)
   eq(requests[1].op,'place'); eq(requests[1].height,48); eq(requests[1].selection.kind,'sit')
   eq(S.placement,nil); eq(ghost.valid,false); eq(cleared,1)
   S.OpenPlacement({kind='sit',id=1}); waiting({offset={0,0,0}}); current.model='other'; tick()
   eq(S.placement,nil); eq(cleared,2)
  `,previewFixture);

 const fovFixture=`
  CLIENT=true; SERVER=false; removed={}
  ix.PlayerControls={}; ix.gui={}; ix.type={number=1}; ix.lang={AddTable=function() end}; ix.option={client={},stored={}}
  function ix.option.Add(key,kind,default,data) data.default=default; ix.option.stored[key]=data end
  function ix.option.Get(key,default) if ix.option.client[key]~=nil then return ix.option.client[key] end; return ix.option.stored[key].default or default end
  function ix.option.Set(key,value)
   local previous=ix.option.client[key]; ix.option.client[key]=value; ix.option.stored[key].OnChanged(previous,value)
  end
  desired={value=82,GetFloat=function(self) return self.value end}
  function GetConVar(name) eq(name,'fov_desired'); return desired end
  function RunConsoleCommand() error('FOV must never write a console command') end
  cvars={RemoveChangeCallback=function(name,id) removed.callback=id end}
  hook.Remove=function(event,id) removed.hook=id end
  hook.Add=function() end
  MOVETYPE_NOCLIP=8; IN_ATTACK2=2
  current={valid=true,alive=true,vars={}}
  function LocalPlayer() return current end
  function current:Alive() return self.alive end
  function current:GetCharacter() return {} end
  function current:InVehicle() return self.vehicle end
  function current:GetViewEntity() return self.viewEntity or self end
  function current:GetMoveType() return self.moveType end
  function current:GetLocalVar(k,default) if self.vars[k]~=nil then return self.vars[k] end return default end
  current.GetNetVar=current.GetLocalVar
  function current:GetRagdollEntity() return self.ragdoll end
  function current:GetActiveWeapon() return self.weapon end
  function current:KeyDown() return self.aiming end
 `;
 suite('Player FOV: 75-150, saved preference and blocked cvar is never written',
  ['ixhl2rp/plugins/player_controls/cl_fov.lua'], `
   local spec=ix.option.stored.playerFOV
   eq(spec.min,75); eq(spec.max,150); eq(spec.category,'playerCamera'); eq(spec.default,82)
   eq(removed.callback,'ixPlayerFOV'); eq(removed.hook,'ixPlayerFOV')
   local apply=ix.PlayerControls.ApplyViewFOV
   ix.option.Set('playerFOV',150)
   local original={fov=82,origin='origin',angles='angles',drawviewer=true,znear=5}
   local first=apply(original,current,nil,nil,82)
   eq(first.fov,150); eq(original.fov,82); eq(first.origin,'origin'); eq(first.angles,'angles'); eq(first.znear,5)
   eq(apply(original,current,nil,nil,82).fov,150)
   eq(apply({origin='orbit'},current,nil,nil,82).fov,150)
   desired.value=100; eq(apply({fov=100},current).fov,150)
   ix.option.Set('playerFOV',999); eq(ix.option.Get('playerFOV'),150)
   ix.option.Set('playerFOV',60); eq(ix.option.Get('playerFOV'),75)
   ix.option.Set('playerFOV',0/0); eq(ix.option.Get('playerFOV'),82)
   eq(apply(false,current),false); eq(apply(nil,current),nil)
  `,fovFixture);
 suite('Player FOV: scope zoom, invalid weapon owners and special cameras remain native',
  ['ixhl2rp/plugins/player_controls/cl_fov.lua'], `
   local apply=ix.PlayerControls.ApplyViewFOV
   ix.option.Set('playerFOV',150)
   local w={valid=true,ARC9=true,sight=0,GetSightAmount=function(self) return self.sight end,GetOwner=function() return current end}
   current.weapon=w
   near(apply({fov=82},current).fov,150)
   w.sight=.5; near(apply({fov=60},current).fov,94)
   w.sight=1; near(apply({fov=30},current).fov,30)
   w.ARC9=nil; w.ArcCW=true; w.GetSightDelta=function() return 0 end; near(apply({fov=30},current).fov,30)
   w.GetOwner=function() return nil end; w.GetSightDelta=function() error('invalid owner') end
   near(apply({fov=82},current).fov,150)
   local view={fov=60}; eq(apply(view,current).fov,60)
   current.weapon=nil; current.aiming=true; eq(apply({fov=82},current).fov,82); current.aiming=false
   local native={fov=82}
   for _,field in ipairs({'vehicle','ragdoll','viewEntity'}) do
    current[field]=field=='vehicle' and true or {valid=true}
    eq(apply(native,current),native); current[field]=nil
   end
   current.vars.ragdoll=4; eq(apply(native,current),native); current.vars.ragdoll=0
   current.moveType=MOVETYPE_NOCLIP; eq(apply(native,current),native); current.moveType=nil
   ix.gui.intro={valid=true}; eq(apply(native,current),native); ix.gui.intro=nil
   ix.gui.characterMenu={valid=true,IsVisible=function() return true end}; eq(apply(native,current),native)
  `,fovFixture);
 suite('Weapon FOV: generic viewmodels follow the setting without drift, preserve overrides and restore on switches/special cameras',
  ['ixhl2rp/plugins/player_controls/cl_fov.lua','ixhl2rp/plugins/player_controls/cl_viewmodel_fov.lua'], `
   local K=ix.PlayerControls
   current.GetFOV=function() return 82 end
   local w=setmetatable({valid=true,GetOwner=function() return current end,GetTable=function(self) return self end},{__index={ViewModelFOV=60}})
   current.weapon=w; ix.option.Set('playerFOV',150)
   for i=1,100 do K.UpdateWeaponFOV(current,false); eq(w.ViewModelFOV,128) end
   ix.option.Set('playerFOV',75); K.UpdateWeaponFOV(current); eq(w.ViewModelFOV,53)
   current.aiming=true; K.UpdateWeaponFOV(current); eq(w.ViewModelFOV,53)
   current.aiming=false; K.RestoreWeaponFOV(); eq(rawget(w,'ViewModelFOV'),nil); eq(w.ViewModelFOV,60)
   ix.option.Set('playerFOV',150); K.UpdateWeaponFOV(current)
   w.ViewModelFOV=45; K.UpdateWeaponFOV(current); eq(w.ViewModelFOV,113)
   local other={valid=true,ViewModelFOV=50,GetOwner=function() return current end,GetTable=function(self) return self end}
   current.weapon=other; K.UpdateWeaponFOV(current); eq(w.ViewModelFOV,45); eq(other.ViewModelFOV,118)
   current.alive=false; K.UpdateWeaponFOV(current); eq(other.ViewModelFOV,50); current.alive=true
   K.UpdateWeaponFOV(current); eq(other.ViewModelFOV,118)
   K.ApplyViewFOV({fov=82,drawviewer=true},current); eq(other.ViewModelFOV,50)
   K.ApplyViewFOV({fov=82,drawviewer=false},current); eq(other.ViewModelFOV,118)
   current.weapon=nil; K.UpdateWeaponFOV(current); eq(other.ViewModelFOV,50)
   current.weapon=w; w.GetPDAEquipped=function() return true end; K.UpdateWeaponFOV(current); eq(w.ViewModelFOV,45)
  `,fovFixture);
 suite('Weapon FOV: ARC9/ArcCW keep the preference through ADS, preserve native sight changes and restore inherited methods',
  ['ixhl2rp/plugins/player_controls/cl_fov.lua','ixhl2rp/plugins/player_controls/cl_viewmodel_fov.lua'], `
   local K=ix.PlayerControls; current.GetFOV=function() return 82 end
   local calls=0; local owner=current
   local getter=function(self) calls=calls+1; return self.nativeFOV end
   local w=setmetatable({valid=true,ARC9=true,nativeFOV=70,sight=0,
    GetOwner=function() return owner end,GetTable=function(self) return self end,
    GetSightAmount=function(self) return self.sight end,GetCustomize=function(self) return self.customize end},
    {__index={GetViewModelFOV=getter}})
   current.weapon=w; ix.option.Set('playerFOV',150)
   for i=1,100 do K.UpdateWeaponFOV(current,false); eq(w:GetViewModelFOV(),138) end
   eq(calls,100)
   w.sight=.5; eq(w:GetViewModelFOV(),138)
   w.sight=1; w.nativeFOV=35; eq(w:GetViewModelFOV(),103)
   w.sight=0; w.customize=true; eq(w:GetViewModelFOV(),35); w.customize=false
   w.nativeFOV=140; eq(w:GetViewModelFOV(),150)
   owner={valid=true}; w:GetViewModelFOV(); eq(calls,104); owner=current
   K.RestoreWeaponFOV(); eq(rawget(w,'GetViewModelFOV'),nil); eq(w.GetViewModelFOV,getter)
   w.ARC9=nil; w.ArcCW=true; w.nativeFOV=70; w.GetSightDelta=function(self) return self.sight end
   K.UpdateWeaponFOV(current); w.sight=0; eq(w:GetViewModelFOV(),138); w.sight=1; eq(w:GetViewModelFOV(),138)
   local external=function() return 42 end; w.GetViewModelFOV=external; K.RestoreWeaponFOV(); eq(w.GetViewModelFOV,external)
  `,fovFixture);
 const hookSource=require('fs').readFileSync(require('path').join(__dirname,'../helix/gamemode/core/libs/sh_plugin.lua'),'utf8');
 const hookStart=hookSource.indexOf('hook.ixCall = hook.ixCall or hook.Call');
 const hookEnd=hookSource.indexOf('--- Runs the given hook',hookStart);
 const dispatch=require('./glua.cjs').normalize(hookSource.slice(hookStart,hookEnd));
 suite('FOV pipeline: finalize plugin/schema/base results once and preserve other hooks/multiple returns', [], `
  local a,b=hook.Call('CalcView',{},'player'); eq(a.fov,150); eq(b,'base'); eq(calls,1)
  HOOKS_CACHE.CalcView={p=function(_,p) eq(p,'player'); return {fov=75},'plugin' end}
  a,b=hook.Call('CalcView',{},'player'); eq(a.fov,150); eq(b,'plugin'); eq(calls,2)
  HOOKS_CACHE.CalcView=nil; Schema={CalcView=function() return {fov=90},'schema' end}
  a,b=hook.Call('CalcView',{},'player'); eq(a.fov,150); eq(b,'schema'); eq(calls,3)
  HOOKS_CACHE.Ordinary={p=function() return false,7,8 end}
  a,b=hook.Call('Ordinary',{}); eq(a,false); eq(b,7); eq(calls,3)
  CLIENT=false; a=hook.Call('CalcView',{}); eq(a.fov,90); eq(calls,3)
 `,`
  CLIENT=true; HOOKS_CACHE={}; calls=0
  hook.Call=function() return {fov=82},'base' end
  ix.PlayerControls={ApplyViewFOV=function(v,p) eq(p,'player'); calls=calls+1; return {fov=150} end}
 `+dispatch);

 suite('Animation wheel client: unavailable saves stay visible with reasons and cannot request preview/playback',
  [shared,'ixhl2rp/plugins/pose_studio/cl_radial.lua'], `
   local S=ix.PoseStudio; local played=0; S.OpenPlacement=function() played=played+1 end
   local panel={valid=true,poseToken=42,PageOptions=function() end}; ix.gui.charRadial=panel
   S.ReceiveRadial({token=42,mode='own',page=1,pages=1,model='target',clips={
    {id=1,name='Old pose',available=false,reason='Wrong model'},
    {id=2,name='Portable pose',portable=true,available=true}}})
   eq(panel.fullOptions[1].label,'Old pose'); eq(panel.fullOptions[1].detail,'Wrong model')
   eq(panel.fullOptions[1].disabled,true); eq(panel.fullOptions[1].preview,nil)
   panel.fullOptions[1].callback(); eq(played,0)
   eq(panel.fullOptions[2].preview.id,2); panel.fullOptions[2].callback(); eq(played,1)
  `,common+`ix.gui={}; concommand={Add=function() end}; function LocalPlayer() return {GetModel=function() return 'target' end} end`);
 suite('Animation wheel: private clips stay hidden, incompatible clips explain their status, acts recheck access',
  [shared,server,'ixhl2rp/plugins/pose_studio/sv_radial.lua'], `
   local p,other=user(1),user(2); put(p); local mine=owned(p); put(other); local theirs=owned(other)
   PLUGIN:PoseRadial(p,{mode='own',token=17}); eq(#reply().clips,1); eq(reply().clips[1].id,mine.id)
   PLUGIN:PoseRadial(p,{mode='shared',token=17}); eq(#reply().clips,0)
   theirs.status='approved'; PLUGIN:PoseRadial(p,{mode='shared',token=17}); eq(#reply().clips,1)
   theirs.clip.model='models/player/alyx.mdl'; PLUGIN:PoseRadial(p,{mode='shared',token=17}); eq(#reply().clips,1); eq(reply().clips[1].available,false); assert(reply().clips[1].reason)
   PLUGIN:PoseRadial(p,{mode='root',token=17}); eq(#reply().acts,1); eq(reply().acts[1].variant,1); eq(#reply().sits,1)
   PLUGIN:RunStudioAct(p,{name='Wave',variant=2}); eq(ran,nil)
   PLUGIN:RunStudioAct(p,{name='Danger',variant=1}); eq(ran,nil)
   PLUGIN:RunStudioAct(p,{name='Wave',variant=1}); eq(ran[1],'ActWave'); eq(ran[2][1],'1')
   access=false; ran=nil; PLUGIN:RunStudioAct(p,{name='Wave',variant=1}); eq(ran,nil)
  `,serverFixture+`
   access=true
   ix.act={stored={Wave={player={sequence={'wave','missing'}}}},Resolve=function(_,_,variant) return variant==1 end}
   ix.command={HasAccess=function() return access end,Run=function(_,name,args) ran={name,args} end}
   ix.plugin.list.sithelper={ResolvePose=function(_,_,id) return id==22 end}
  `);
 const controlsFixture=`
  CLIENT=true; SERVER=false; registered={}; hooks={}; commands={}; calls={}; pressed={}; bindings={}
  KEY_J=20; KEY_H=21; KEY_N=22; KEY_TAB=10; KEY_ESCAPE=11; KEY_LAST=100; MOUSE_LEFT=107; MOUSE_5=111
  MOVETYPE_WALK=2; IN_FORWARD=1; IN_BACK=2; IN_MOVELEFT=4; IN_MOVERIGHT=8; IN_JUMP=16; IN_SPEED=32
  function LocalPlayer() return current end
  current={valid=true,Alive=function() return true end,GetCharacter=function() return {} end,GetNetVar=function() return nil end,
   InVehicle=function() return false end,GetNW2Bool=function() return false end,GetLocalVar=function(_,_,default) return default end,
   GetMoveType=function() return MOVETYPE_WALK end,IsFrozen=function() return false end,GetWalkSpeed=function() return 100 end,GetRunSpeed=function() return 200 end}
  gui={IsGameUIVisible=function() return gameUI end}
  vgui={Register=function(name,p) registered[name]=p end,GetKeyboardFocus=function() return focus end,CursorVisible=function() return cursor end}
  input={IsKeyDown=function(key) return pressed[key]==true end,IsMouseDown=function(key) return pressed[key]==true end,
   IsKeyTrapping=function() return trapping end,LookupKeyBinding=function(key) return bindings[key] end}
  ix.lang={AddTable=function() end}; ix.type={number=1}; ix.gui={}; ix.menu={IsOpen=function() return menu end}
  ix.option={client={},stored={}}
  function ix.option.Add(key,kind,default,data) data.default=default; ix.option.stored[key]=data end
  function ix.option.Get(key) if ix.option.client[key]~=nil then return ix.option.client[key] end return ix.option.stored[key].default end
  function ix.option.Set(key,value) local old=ix.option.Get(key); ix.option.client[key]=value; ix.option.stored[key].OnChanged(old,value) end
  hook.Add=function(name,id,fn) hooks[id]=fn end; hook.Remove=function(_,id) hooks[id]=nil end
  concommand={Add=function(name,fn) commands[name]=fn end}
  function RunConsoleCommand(name) calls[#calls+1]=name; if commands[name] then commands[name]() end end
  function GetConVar() return nil end
 `;
 suite('Player controls: rebind/clear persists, conflicts clear one action, held/captured keys never double-trigger',
  ['ixhl2rp/plugins/player_controls/cl_controls.lua'], `
   local K=ix.PlayerControls
   eq(ix.option.Get('quickActionsKey'),KEY_H); eq(ix.option.Get('autoWalkKey'),KEY_N); eq(ix.option.Get('animationMenuKey'),KEY_J)
   for _,spec in ipairs(K.actions) do eq(ix.option.stored[spec.key].category,'playerControls'); eq(ix.option.stored[spec.key].keybind,true) end
   pressed[KEY_H]=true; hooks.ixPlayerControlKeys(); eq(calls[1],'ix_radial'); hooks.ixPlayerControlKeys(); eq(#calls,1)
   pressed[KEY_H]=false; hooks.ixPlayerControlKeys(); ix.option.Set('quickActionsKey',35)
   pressed[KEY_H]=true; hooks.ixPlayerControlKeys(); eq(#calls,1)
   pressed[35]=true; hooks.ixPlayerControlKeys(); eq(calls[2],'ix_radial')
   ix.option.Set('animationMenuKey',35); eq(ix.option.Get('quickActionsKey'),0)
   hooks.ixPlayerControlKeys(); eq(#calls,2)
   pressed[35]=false; hooks.ixPlayerControlKeys(); pressed[35]=true; hooks.ixPlayerControlKeys(); eq(calls[3],'ix_animation_menu')
   ix.option.Set('autoWalkKey',KEY_ESCAPE); eq(ix.option.Get('autoWalkKey'),0)
   ix.option.Set('autoWalkKey',50); pressed[50]=true; trapping=true; hooks.ixPlayerControlKeys(); eq(#calls,3)
   trapping=false; hooks.ixPlayerControlKeys(); eq(#calls,3)
  `,controlsFixture);
 suite('Player controls: typing, settings and death suppress shortcuts; console-owned binds are not polled twice',
  ['ixhl2rp/plugins/player_controls/cl_controls.lua'], `
   focus={valid=true,GetClassName=function() return 'TextEntry' end,GetName=function() return 'TextEntry' end}
   pressed[KEY_J]=true; hooks.ixPlayerControlKeys(); eq(#calls,0)
   focus=nil; pressed[KEY_J]=false; hooks.ixPlayerControlKeys(); pressed[KEY_J]=true; menu=true; hooks.ixPlayerControlKeys(); eq(#calls,0)
   menu=false; pressed[KEY_J]=false; hooks.ixPlayerControlKeys(); pressed[KEY_J]=true; bindings[KEY_J]='+ix_animation_menu'; hooks.ixPlayerControlKeys(); eq(#calls,0)
   cursor=true; eq(ix.PlayerControls.CanUseHotkeys(false),false)
   ix.gui.charRadial={valid=true}; eq(ix.PlayerControls.CanUseHotkeys(true),true); eq(ix.PlayerControls.CanUseHotkeys(false),false)
   current.Alive=function() return false end; eq(ix.PlayerControls.CanUseHotkeys(true),false)
  `,controlsFixture);
 suite('Auto-walk: rebound command generates normal input; manual motion, UI, incapacity and poses cancel it',
  ['ixhl2rp/plugins/player_controls/cl_controls.lua','ixhl2rp/plugins/autowalk.lua'], `
   local function command(forward,sprint)
    return {GetForwardMove=function() return forward or 0 end,GetSideMove=function() return 0 end,GetUpMove=function() return 0 end,
     KeyDown=function(_,key) return sprint and key==IN_SPEED end,SetForwardMove=function(self,value) self.value=value end}
   end
   commands.ix_autowalk(); local c=command(); PLUGIN:CreateMove(c); eq(c.value,100)
   c=command(0,true); PLUGIN:CreateMove(c); eq(c.value,200)
   c=command(5); PLUGIN:CreateMove(c); eq(c.value,nil); c=command(); PLUGIN:CreateMove(c); eq(c.value,nil)
   commands.ix_autowalk(); menu=true; c=command(); PLUGIN:CreateMove(c); eq(c.value,nil)
   menu=false; commands.ix_autowalk(); current.GetNetVar=function() return 2 end; c=command(); PLUGIN:CreateMove(c); eq(c.value,nil)
   current.GetNetVar=function() return nil end; commands.ix_autowalk(); ix.option.Set('autoWalkKey',55); c=command(); PLUGIN:CreateMove(c); eq(c.value,nil)
  `,controlsFixture);
};

if(require.main===module){
 const fs=require('fs'),path=require('path');
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 const {normalize}=require('./glua.cjs');
 let passed=0;
 module.exports((name,files,assertions,setup='')=>{
  const L=lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  const source=[fs.readFileSync(path.join(__dirname,'fixture.lua'),'utf8'),setup,
   ...files.map(f=>'do\n'+normalize(fs.readFileSync(path.join(__dirname,'..',f),'utf8'))+'\nend'),assertions].join('\n');
  if(lauxlib.luaL_dostring(L,to_luastring(source))!==lua.LUA_OK) throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
  passed++; console.log('PASS '+name);
 });
 console.log(passed+' Pose Studio suites passed (mocked GMod APIs).');
}
