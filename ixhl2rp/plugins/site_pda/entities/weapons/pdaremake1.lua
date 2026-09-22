if SERVER then AddCSLuaFile() end
SWEP.PrintName="FIELDLINK"
SWEP.Author="Yaxaka / Hutten"
SWEP.Instructions="Hold R: raise/lower. Select through the weapon menu."
SWEP.Category="PDA"
SWEP.DrawAmmo=false
SWEP.DrawCrosshair=false
SWEP.Slot=5
SWEP.Spawnable=true
SWEP.AdminOnly=false
SWEP.UseHands=true
SWEP.ViewModel="models/v_item_pda.mdl"
SWEP.WorldModel="models/v_item_pda.mdl"
SWEP.ViewModelFOV=80
SWEP.SwayScale=0
SWEP.BobScale=0
SWEP.FireWhenLowered=true
SWEP.SlotPos=2
SWEP.Primary={ClipSize=-1,DefaultClip=-1,Automatic=false,Ammo="none"}
SWEP.Secondary={ClipSize=-1,DefaultClip=-1,Automatic=false,Ammo="none"}
function SWEP:SetupDataTables()
 self:NetworkVar("Bool",0,"PDAEquipped")
 self:NetworkVar("Float",0,"PDATransitionAt")
 self:NetworkVar("Float",1,"PDAStartFraction")
end
function SWEP:GetPDAFraction()
 local target=self:GetPDAEquipped() and 1 or 0
 local t=math.Clamp((CurTime()-self:GetPDATransitionAt())/0.36,0,1)
 local eased=t*t*(3-2*t)
 return Lerp(eased,self:GetPDAStartFraction(),target)
end
function SWEP:Initialize()
 self:SetHoldType("slam")
 if SERVER then self:SetPDAEquipped(false); self:SetPDAStartFraction(0); self:SetPDATransitionAt(CurTime()) end
end
function SWEP:CustomEquip(raised)
 if not SERVER or self:GetPDAEquipped()==raised then return end
 self:SetPDAStartFraction(self:GetPDAFraction())
 self:SetPDATransitionAt(CurTime())
 self:SetPDAEquipped(raised)
 self:EmitSound(raised and "Stalker2.PDAEquip" or "Stalker2.PDAUnequip",40,100,0.55)
end
function SWEP:Deploy()
 self.ixIdleReady=nil
 if SERVER then
  local owner=self:GetOwner()
  if IsValid(owner) and owner.GetCharacter and owner:GetCharacter() then self.ixFieldlinkCharacter=owner:GetCharacter():GetID() end
  self:CustomEquip(false)
  if IsValid(owner) and owner.SetWepRaised then owner:SetWepRaised(false,self) end
 end
 return true
end
function SWEP:PrimaryAttack() end
function SWEP:SecondaryAttack()
 self:SetNextSecondaryFire(CurTime()+0.3)
 if SERVER then
  local owner=self:GetOwner()
  if IsValid(owner) and owner.ToggleWepRaised then owner:ToggleWepRaised() else self:CustomEquip(not self:GetPDAEquipped()) end
 end
end
function SWEP:OnRaised() self:CustomEquip(true) end
function SWEP:OnLowered() self:CustomEquip(false) end
function SWEP:Reload() end
function SWEP:Holster()
 if SERVER then self:CustomEquip(false) end
 self.ixIdleReady=nil
 return true
end
function SWEP:Think()
 if SERVER then
  local owner=self:GetOwner()
  if IsValid(owner) and owner:GetActiveWeapon()==self and owner.IsWepRaised then
   local c=owner.GetCharacter and owner:GetCharacter()
   local allowed=c and c:GetData("fieldlinkEnabled",false) and owner.HasItem and owner:HasItem("pda") and owner:GetLocalVar("ragdoll",0)==0
   self:CustomEquip(allowed and owner:IsWepRaised() or false)
  end
  return
 end
 local owner=self:GetOwner()
 if not IsValid(owner) or owner~=LocalPlayer() then return end
 local vm=owner:GetViewModel()
 if IsValid(vm) and not self.ixIdleReady then
  local sequence=vm:LookupSequence("idle")
  if sequence and sequence>=0 then vm:ResetSequence(sequence); vm:SetCycle(0); vm:SetPlaybackRate(1) end
  self.ixIdleReady=true
 end
end
function SWEP:ShouldDrawViewModel() return true end
function SWEP:CalcViewModelView(vm,oldPos,oldAng,pos,ang)
 local owner=self:GetOwner()
 if not IsValid(owner) then return pos,ang end
 local f=self:GetPDAFraction()
 if ix and ix.option and ix.option.Get("disableAnimations",false) then f=self:GetPDAEquipped() and 1 or 0 end
 local eye=owner:EyeAngles()
 local result=owner:EyePos()+eye:Forward()*(4.5+(1-f)*1.5)+eye:Up()*(1-(1-f)*9)
 local angles=Angle(eye.p,eye.y,eye.r)
 angles:RotateAroundAxis(angles:Right(),(1-f)*16)
 return result,angles
end
function SWEP:OnRemove()
 if IsValid(self.FieldlinkWorldModel) then self.FieldlinkWorldModel:Remove() end
end
if CLIENT then
 function SWEP:DrawWorldModel()
  if not IsValid(self.FieldlinkWorldModel) then
   self.FieldlinkWorldModel=ClientsideModel(self.WorldModel,RENDERGROUP_OPAQUE)
   if not IsValid(self.FieldlinkWorldModel) then return end
   self.FieldlinkWorldModel:SetNoDraw(true)
  end
  local model=self.FieldlinkWorldModel
  local owner=self:GetOwner()
  if IsValid(owner) then
   local bone=owner:LookupBone("ValveBiped.Bip01_R_Hand")
   local matrix=bone and owner:GetBoneMatrix(bone)
   if not matrix then return end
   local pos,ang=LocalToWorld(Vector(3,-6,-6),Angle(-50,-10,-165),matrix:GetTranslation(),matrix:GetAngles())
   model:SetPos(pos); model:SetAngles(ang)
  else model:SetPos(self:GetPos()); model:SetAngles(self:GetAngles()) end
  model:SetupBones(); model:DrawModel()
 end
end
