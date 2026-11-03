local vec={};vec.__index=vec
function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},vec) end
function vec.__eq(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
function vec.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
function vec.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
local mat={};mat.__index=mat
function Matrix(source)
 return setmetatable({position=source and source.position or Vector(),scale=source and source.scale or Vector(1,1,1)},mat)
end
function mat:GetTranslation() return self.position end
function mat:SetTranslation(v) self.position=v end
function mat:GetScale() return self.scale end
function mat:SetScale(v) assert(v.x>0 and v.y>0 and v.z>0);self.scale=v end
HITGROUP_HEAD=1;HITGROUP_CHEST=2;HITGROUP_STOMACH=3
HITGROUP_LEFTARM=4;HITGROUP_RIGHTARM=5;HITGROUP_LEFTLEG=6;HITGROUP_RIGHTLEG=7
IN_RELOAD=8192;IN_ATTACK=1;IN_ATTACK2=2048
ix.lang={AddTable=function() end};ix.type={player=1,string=2}
ix.command={Add=function() end};ix.Medicine={activeSessions={}}
timers={};delayed={};reps=1
timer.Create=function(name,_,_,fn) timers[name]=fn end
timer.Simple=function(_,fn) delayed[#delayed+1]=fn end
timer.Remove=function(name) timers[name]=nil end
timer.RepsLeft=function() return reps end
math.Rand=function(a,b) return a end
function L(key) return key end
function EffectData() return {SetOrigin=function() end,SetMagnitude=function() end,SetEntity=function() end} end
util.Effect=function() end
surface={PlaySound=function() end}
ents={FindByClass=function() return {} end}
local names={ [0]='pelvis', [1]='ValveBiped.Bip01_L_UpperArm', [2]='ValveBiped.Bip01_L_Hand', [3]='head',
 [4]='ValveBiped.Bip01_L_Forearm', [5]='finger', [6]='ValveBiped.Bip01_R_Forearm', [7]='ValveBiped.Bip01_R_UpperArm',
 [8]='ValveBiped.Bip01_R_Hand', [9]='ValveBiped.Bip01_L_Calf', [10]='ValveBiped.Bip01_L_Thigh', [11]='foot',
 [12]='ValveBiped.Bip01_R_Calf', [13]='ValveBiped.Bip01_R_Thigh', [14]='footR'}
local parents={[0]=-1,[1]=0,[2]=4,[3]=0,[4]=1,[5]=2,[6]=7,[7]=0,[8]=6,[9]=10,[10]=0,[11]=9,[12]=13,[13]=0,[14]=12}
function person(id)
 local p={valid=true,id=id,model='templar.mdl',names=table.Copy(names),parents=table.Copy(parents),items={},vars={},
  scales={},positions={},matrices={},callbacks={},callbackID=0,boneReads=0,healthUpdates=0,mutations=0}
 p.char={data={},GetData=function(c,k) return c.data[k] end,SetData=function(c,k,v) c.data[k]=v end}
 p.health={body={parts={}},bloodloss=true,GetHediffs=function() return ipairs({}) end,
  OnUpdateDiffs=function() p.healthUpdates=p.healthUpdates+1 end}
 function p.char:Health() return p.health end
 function p:GetCharacter() return self.char end
 function p:GetModel() return self.model end
 function p:GetModelScale() return self.modelScale or 1 end
 function p:Alive() return not self.dead end
 function p:IsPlayer() return not self.ragdoll end
 function p:IsRagdoll() return self.ragdoll or false end
 function p:IsNPC() return false end
 function p:GetItems() return self.items end
 function p:UniqueID() return self.id end
 function p:Name() return self.id end
 function p:GetNetVar(k,default) local v=self.vars[k];if v==nil then return default end;return v end
 function p:SetNetVar(k,v) self.vars[k]=v end
 function p:SetAction(value) self.action=value end
 function p:NotifyLocalized() end;function p:ChatNotifyLocalized() end;function p:EmitSound() end
 function p:KeyDown() return self.reload or false end
 function p:InCriticalState() return self.critical or false end
 function p:IsRestricted() return self.restricted or false end
 function p:GetActiveWeapon() return self.weapon end
 function p:GetPos() return Vector(1000,2000,3000) end
 function p:OBBCenter() return Vector(0,0,30) end
 function p:GetBoneCount() return 15 end
 function p:GetBoneName(i) return self.names[i] or '__INVALIDBONE__' end
 function p:LookupBone(name) self.boneReads=self.boneReads+1;for i,n in pairs(self.names) do if n==name then return i end end end
 function p:GetBoneParent(i) self.boneReads=self.boneReads+1;return self.parents[i] end
 function p:GetManipulateBoneScale(i) return self.scales[i] or Vector(1,1,1) end
 function p:GetManipulateBonePosition(i) return self.positions[i] or Vector() end
 function p:ManipulateBoneScale(i,v) self.scales[i]=v;self.mutations=self.mutations+1 end
 function p:ManipulateBonePosition(i,v) self.positions[i]=v;self.mutations=self.mutations+1 end
 function p:GetBoneMatrix(i) if self.noMatrix==i then return end;return Matrix(self.matrices[i]) end
 function p:SetBoneMatrix(i,m) assert(self:GetBoneName(i)~='__INVALIDBONE__');self.matrices[i]=Matrix(m) end
 function p:AddCallback(_,fn) self.callbackID=self.callbackID+1;self.callbacks[self.callbackID]=fn;return self.callbackID end
 function p:RemoveCallback(_,id) self.callbacks[id]=nil end
 function p:InvalidateBoneCache() self.invalidated=true end
 function p:AddItem(item) if self.full then return false end;self.items[#self.items+1]=item;item.inventory_id=1;return true end
 for i=0,14 do p.matrices[i]=Matrix();p.matrices[i]:SetTranslation(Vector(1000+i,2000+i*2,3000+i*3)) end
 return p
end
surgeon=person('surgeon');patient=person('patient');viewer=person('viewer')
function LocalPlayer() return viewer end
player.GetAll=function() return {surgeon,patient,viewer} end
util.TraceLine=function() return {Entity=patient} end
function surgeon:GetShootPos() return Vector() end;function surgeon:GetAimVector() return Vector(1,0,0) end
ix.Item={instances={},serial=1}
tool={id=1,canAmputate=true,uniqueID='test_tool'};ix.Item.instances[1]=tool;surgeon.items={tool}
function ix.Item:Instance(id) self.serial=self.serial+1;local item={id=self.serial,uniqueID=id};self.instances[item.id]=item;return item end
function ix.Item:Spawn(owner,angle,item) assert(not item.inventory_id);item.spawned=owner;return {},item end
function ix.Item:DropItem() error('New remains have no inventory to drop from') end
net.WriteUInt=function(value) requestID=value end
net.ReadUInt=function() return replyID or requestID end
net.ReadBool=function() return consent~=false end
function released()
 eq(surgeon.ixAmputationBusy,nil);eq(patient.ixAmputationBusy,nil)
 eq(tool.ixAmputationOperation,nil);eq(tool.inUse,nil);eq(timers.ixAmputationcutsurgeon,nil)
end
