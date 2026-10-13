ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Раненый на тележке"
ENT.Spawnable = false
ENT.bNoPersist = true
ENT.isCartPatient = true

if SERVER then
    function ENT:Initialize()
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetUseType(SIMPLE_USE)
        self:SetPlaybackRate(0)
    end
    function ENT:OnRemove()
        local P = ix.PushCart
        if P then P:PatientDisplayRemoved(self) end
    end
else
    function ENT:Think()
        local low, high = self:GetNW2Vector("ixPatientMins"), self:GetNW2Vector("ixPatientMaxs")
        if low ~= self.patientMins or high ~= self.patientMaxs then
            self.patientMins, self.patientMaxs = low, high
            self:SetCollisionBounds(low,high)
            self:SetRenderBounds(low-Vector(32,32,32),high+Vector(32,32,32))
        end
    end
    function ENT:Draw()
        self:SetCycle(0)
        self:DrawModel()
    end
end
