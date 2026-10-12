AddCSLuaFile()

ENT.PrintName = "Night Vision Goggles"
ENT.Spawnable = false
ENT.Category = "Arctic's Night Vision"
ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.DisableDuplicator = true
ENT.Gives = ""
ENT.Skin = 0
ENT.Model = ""

function ENT:Initialize()
    self:SetModel(self.Model)

    if SERVER then
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:PhysWake()
        self:SetSkin(self.Skin)

        self:SetTrigger(true) -- Enables Touch() to be called even when not colliding
        self:UseTriggerBounds(true, 16)

        timer.Simple(0, function()
            if !IsValid(self) then return end

            self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        end)

        self.SpawnTime = CurTime()
    end
end

function ENT:Use(activator, ent, usetype, val)
    if ix and ix.field then return end
    if !IsValid(ent) then return end
    if !ent:IsPlayer() or self.PickedUp then return end
    if ent == self:GetOwner() and self.SpawnTime > (CurTime() - 1) then return end

    ArcticNVGs_SetPlayerGoggles(ent, self.Gives)

    self:Remove()
    self.PickedUp = true
    self:EmitSound("items/ammo_pickup.wav")
end

function ENT:DrawTranslucent()
    self:Draw()
end

function ENT:Draw()
    self:DrawModel()
end