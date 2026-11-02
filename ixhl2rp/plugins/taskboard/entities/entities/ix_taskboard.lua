ENT.Type = "anim"
ENT.PrintName = "Доска объявлений"
ENT.Category = "Medieval RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.bNoPersist = true
if SERVER then
 function ENT:Initialize()
  self:SetModel("models/props_c17/Frame002a.mdl")
  self:SetModelScale(2,0)
  self:PhysicsInit(SOLID_VPHYSICS)
  self:SetSolid(SOLID_VPHYSICS)
  self:SetUseType(SIMPLE_USE)
  local phys=self:GetPhysicsObject()
  if IsValid(phys) then phys:EnableMotion(false) end
 end
 function ENT:Use(client)
  if not IsValid(client) or not client:IsPlayer() or not client:Alive() or not client:GetCharacter() then return end
  if client:GetShootPos():DistToSqr(self:NearestPoint(client:GetShootPos()))>140^2 then return end
  if (client.ixBoardOpenAt or 0)>CurTime() then return end
  client.ixBoardOpenAt=CurTime()+.5
  netstream.Start(client,"taskboard.open",self)
 end
 function ENT:OnRemove()
  timer.Simple(0,function() local p=ix.plugin.list.taskboard; if p then p:SaveData() end end)
 end
else
 function ENT:Draw() self:DrawModel() end
end
