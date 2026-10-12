ENT.Type="anim"
ENT.Base="base_anim"
ENT.PrintName="CCTV Device"
ENT.Category="Foundation"
ENT.Spawnable=false
ENT.AdminOnly=true
ENT.bNoPersist=true
if SERVER then
 function ENT:Initialize()
  local def=ix.CCTV.kinds[self.CCTVKind];if not def then self:Remove();return end
  self:SetModel(self.cctvRestore and self.cctvRestore.model or def.model)
  if self.CCTVKind=="camera" then self:ResetSequence("idle");self:SetCycle(0);self:SetPlaybackRate(0) end
  self:PhysicsInit(SOLID_VPHYSICS);self:SetSolid(SOLID_VPHYSICS)
  self:SetMoveType(MOVETYPE_VPHYSICS);self:SetUseType(SIMPLE_USE)
  local physics=self:GetPhysicsObject();if IsValid(physics) then physics:EnableMotion(false) end
  local plugin=ix.plugin.list.cctv
  if plugin then plugin:RegisterDevice(self,self.CCTVKind) end
 end
 function ENT:Use(p)
  if not IsValid(p) or not p:IsPlayer() or (self.nextCCTVUse or 0)>CurTime() then return end
  self.nextCCTVUse=CurTime()+.5
  local plugin=ix.plugin.list.cctv;if plugin then plugin:UseDevice(p,self) end
 end
 function ENT:OnRemove() local plugin=ix.plugin.list.cctv;if plugin then plugin:RemoveDevice(self) end end
 function ENT:SpawnFunction(p,tr,class)
  if not IsValid(p) or not p:IsAdmin() then return end
  local pos,ang=ix.CCTV.Placement(p,tr,self.CCTVKind);if not pos then return end
  local plugin=ix.plugin.list.cctv;if not plugin or not plugin:HasSpace(self.CCTVKind) then return end
  local ent=ents.Create(class);if not IsValid(ent) then return end
  ent:SetPos(pos);ent:SetAngles(ang);ent:Spawn();ent:Activate();return ent
 end
else
 function ENT:Draw()
  self:DrawModel()
 end
end
