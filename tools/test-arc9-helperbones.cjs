module.exports = function(suite) {
suite('ARC9 helper repair follows weighted arm descendants without drift or touching fingers and unrelated models',
 ['ixhl2rp/plugins/arc9_helperbones.lua'], `
 local H=ix.arc9Helpers
 local p={valid=true,model='models/che_pm.mdl',names={
 [0]='ValveBiped.Bip01_L_UpperArm',[1]='ValveBiped.Bip01_L_Forearm',
 [2]='ValveBiped.Bip01_L_Shoulder',[3]='custom_sleeve',
 [4]='ValveBiped.Bip01_L_Finger0',[5]='ValveBiped.Anim_Attachment_LH',
 [6]='ValveBiped.Bip01_Spine',[7]='unused_helper',
 [8]='ValveBiped.Bip01_L_Hand',[9]='ValveBiped.Bip01_L_Finger20',
 [10]='custom_finger_helper'},
 parents={[0]=6,[1]=0,[2]=0,[3]=2,[4]=1,[5]=1,[6]=-1,[7]=0,[8]=1,[9]=8,[10]=4}, mats={}, writes=0}
 function p:IsPlayer() return true end
 function p:GetModel() return self.model end
 function p:GetBoneCount() return 11 end
 function p:GetBoneName(b) return self.names[b] end
 function p:GetBoneParent(b) return self.parents[b] end
 function p:BoneHasFlag(b) return b~=7 end
 function p:SetupBones() end
 function p:GetBoneMatrix(b) return self.mats[b] end
 function p:SetBoneMatrix(b,m) self.writes=self.writes+1; self.mats[b]=m end
 p.mats={[0]=M(10),[1]=M(15),[2]=M(12),[3]=M(13),[4]=M(16),[5]=M(17),[6]=M(0),[8]=M(18),[9]=M(19),[10]=M(17)}
 local entries=H.GetEntries(p); eq(#entries,4); eq(entries[1].bone,2); eq(entries[2].bone,3)
 local w={valid=true,ARC9=true,owner=p,calls=0}
 function w:GetOwner() return self.owner end
 function w:DoTPIK(depth)
  self.calls=self.calls+1; self.depth=depth
  self.owner.mats[0]=M(20)
  self.owner.mats[8]=M(28); self.owner.mats[4]=M(26)
  -- Simulate a version which already handles the first helper.
  self.owner.mats[2]=M(22)
  return 'original result'
 end
 H.Install(w); local wrapper=w.DoTPIK; H.Install(w); eq(w.DoTPIK,wrapper)
 eq(w:DoTPIK(true),'original result'); eq(w.depth,true)
 eq(p.mats[2].v,22); eq(p.mats[3].v,23); eq(p.mats[4].v,26); eq(p.mats[9].v,29); eq(p.mats[10].v,27); eq(p.mats[5].v,17)
 w:DoTPIK(false); eq(p.mats[2].v,22); eq(p.mats[3].v,23) -- no accumulated delta
 local writes=p.writes; enabled=false; w:DoTPIK(false); eq(p.writes,writes)
 enabled=true; p.model='other.mdl'; p.names[2]='ValveBiped.Bip01_R_Hand'; p.names[3]='ValveBiped.Bip01_R_Finger0'
 p.names[9]='ValveBiped.Bip01_R_Finger21'; p.names[10]='ValveBiped.Bip01_R_Finger22'
 eq(#H.GetEntries(p),0); w:DoTPIK(false); eq(p.writes,writes)
 local other={valid=true,ARC9=false,DoTPIK=function() end}; local fn=other.DoTPIK
 H.Install(other); eq(other.DoTPIK,fn)
 `, `
 SERVER=false; CLIENT=true; enabled=true; BONE_USED_BY_VERTEX_LOD0=1024
 CreateClientConVar=function() return {GetBool=function() return enabled end} end
 hook.Add=function() end
 local mt={}; mt.__index=mt
 mt.__mul=function(a,b) return M(a.v+b.v) end
 function mt:GetInverse() return M(-self.v) end
 function M(v) return setmetatable({v=v},mt) end
 `);
};
