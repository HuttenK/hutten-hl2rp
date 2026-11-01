-- Exercise the actual renderer on extracted compiled skeletons, without GMod.
-- Desired joint rotations are explicit, not derived from each mesh's rest pose.
function AuditPoseTransfer(rigs)
 local S=ix.PoseStudio
 local M=getmetatable(Matrix())
 function M:SetAngles(a)
  local angle=Angle(a.p or 0,a.y or 0,a.r or 0)
  local columns={angle:Forward(),-angle:Right(),angle:Up()}
  for c,v in ipairs(columns) do self:SetField(1,c,v.x); self:SetField(2,c,v.y); self:SetField(3,c,v.z) end
 end
 local maximum,limbError,cases=0,0,0
 for _,source in ipairs(rigs) do for _,target in ipairs(rigs) do
  local map=assert(S.RigMap(target,source))
  for phase=0,1 do
   local locals,expected={},{}
   for i=0,source.count-1 do
    local bone=source.bones[i]; local pose=bone.localBind*Matrix()
    if bone.name:find('_UpperArm',1,true) then pose:SetAngles(Angle(15+phase*10,-55,80))
    elseif bone.name:find('_Forearm',1,true) then pose:SetAngles(Angle(5,-110+phase*30,0))
    elseif bone.name:find('_Hand',1,true) then pose:SetAngles(Angle(-5,10,-80)) end
    locals[bone.name]=pose
    expected[i]=bone.parent>=0 and expected[bone.parent]*pose or pose
   end
   local original,written={},{}
   for i=0,target.count-1 do original[i]=target.bones[i].bind end
   local entity={GetBoneCount=function() return target.count end,
    GetBoneMatrix=function(_,i) return original[i] end,
    GetBoneParent=function(_,i) return target.bones[i].parent end,
    GetBoneName=function(_,i) return target.bones[i].name end,
    GetPos=function() return vector_origin end,GetAngles=function() return Angle() end,
    GetRenderAngles=function() return Angle() end,GetModelScale=function() return 1 end,
    SetBoneMatrix=function(_,i,m) written[i]=m end}
   S.ApplyLayer(entity,{clip={portable=true,mask='full'},reference={rig=source,locals=locals},targetRig=target,
    rigMap=map,rigRatio=target.height/source.height,transforms={}})
   for name,entry in pairs(map) do
    local actual=assert(written[entry.target]); local desired=expected[entry.source]
    for r=1,3 do for c=1,3 do
     local error=math.abs(actual[r][c]-desired[r][c]); maximum=math.max(maximum,error)
     assert(error<.0005,'Joint orientation changed: '..name..' error='..error)
    end end
    if source==target then
     assert((actual:GetTranslation()-desired:GetTranslation()):Length()<.001,'Author pose changed: '..name)
    end
    if name:find('_Forearm',1,true) or name:find('_Hand',1,true) then
     local bone=target.bones[entry.target]
     local parent=written[bone.parent] or original[bone.parent]
     local length=(actual:GetTranslation()-parent:GetTranslation()):Length()
     local error=math.abs(length-bone.localBind:GetTranslation():Length()); limbError=math.max(limbError,error)
     assert(error<.001,'Target arm length changed: '..name..' error='..error)
    end
   end
   cases=cases+1
  end
 end end
 print(string.format('Motion audit: %d directed model pairs, %d posed cases; max rotation matrix error %.9f, max limb length error %.9f.',#rigs*#rigs,cases,maximum,limbError))
 print('Synthetic joint rotations on real compiled skeletons; not a live animation/mesh rendering test.')
end
