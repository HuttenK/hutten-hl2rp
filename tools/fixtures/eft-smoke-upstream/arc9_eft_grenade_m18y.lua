AddCSLuaFile()
ENT.Type 				= "anim"
ENT.Base 				= "arc9_eft_grenade_base"
ENT.Spawnable 			= false

if CLIENT then killicon.Add("arc9_eft_grenade_m18", "vgui/killicons/arc9_eft_m18", Color(255, 255, 255)) end

ENT.PrintName  = "M18 smoke grenade"
ENT.Model = "models/weapons/arc9/darsu_eft/w_m18.mdl"
ENT.ModelTrue = "models/weapons/arc9/darsu_eft/w_m18.mdl"
ENT.SWEP = "arc9_eft_m18y"
ENT.StartTime = 1
ENT.LifeTime = 266
ENT.EmitTime = 90

ENT.dmg = 0
ENT.dmgradiusminM = 0
ENT.dmgradiusmaxM = 0
ENT.shakeradiusM = 0
ENT.contusionLength = 0

ENT.shrapnelcount = 0
ENT.shrapneldmg = 0

ENT.ExplodeOnImpact = false

local path = "weapons/darsu_eft/grenades/"
ENT.BounceSounds = { path .. "grenade_smoke_impact1.ogg", path .. "grenade_smoke_impact2.ogg", path .. "grenade_smoke_impact3.ogg" }

ENT.closeSound = path .. "grenade_smoke_start.ogg"
ENT.loopSound = path .. "grenade_smoke_loop.ogg"
ENT.loopendSound = path .. "grenade_smoke_end.ogg"

ENT.nextloopsound = 999999999999

function ENT:Think()
    if SERVER and self.SpawnTime + self.LifeTime < CurTime() then 
        SafeRemoveEntity(self) 
    end
    
    if SERVER and self.nextloopsound < CurTime() then 
        if (self.SpawnTime + self.EmitTime - CurTime()) > 0 then
            self:EmitSound(self.loopSound, 60, 100, 1, nil, nil, 0)
            self.nextloopsound = CurTime() + 1.15
        else
            self:EmitSound(self.loopendSound, 60, 100, 1, nil, nil, 0)
            self.nextloopsound = 9999999999
        end
    end

    if self.Defused then return end

    if CLIENT and !self.LightPlayed then
        self.LightPlayed = true
        ParticleEffectAttach("port_smoke_heavy", PATTACH_ABSORIGIN_FOLLOW, self, 1) -- flash
    end

    if self.StartTime > 0 and self.SpawnTime + self.StartTime < CurTime() then
        self:StartSmoke()
        return
    end

end

PrecacheParticleSystem( "smoke_exhaust_01" )

function ENT:StartSmoke()
    self.Defused = true

    if CLIENT then
        table.insert(ARC9EFT.Smokeslist, self)

        ParticleEffectAttach( "smoke_exhaust_01", PATTACH_ABSORIGIN_FOLLOW, self, 1 )
        timer.Simple(self.EmitTime, function()
            if IsValid(self) then self:StopParticles() end
        end)
    else
        self:EmitSound(self.closeSound, 60, 100, 1, nil, nil, 0)
        self.nextloopsound = CurTime() + 0.9

        local fear = ents.Create("ai_sound")
        fear:SetKeyValue("soundtype", 8)
        fear:SetKeyValue("volume", 256)
        fear:SetKeyValue("duration", 80)
        fear:SetOwner(self.Owner)
        fear:SetPos(self:GetPos())
        fear:Fire("EmitAISound" , "", 0.82)
        fear:Fire("kill", "", 6)

        local exp = ents.Create("env_smoketrail")
        exp:SetKeyValue("startsize", "11100")
        exp:SetKeyValue("endsize", "100000")
        exp:SetKeyValue("spawnradius", "128")
        exp:SetKeyValue("opacity", "1")
        exp:SetKeyValue("lifetime", "" .. self.EmitTime)
        exp:SetKeyValue("spawnrate", "4")
        exp:SetKeyValue("emittime", "" .. self.EmitTime)
        exp:SetKeyValue("maxspeed", "1")
        exp:SetKeyValue("maxdirectedspeed", "5")
        exp:SetKeyValue("startcolor", "130 130 0")
        exp:SetKeyValue("endcolor", "255 255 30")
        exp:SetPos(self:GetPos())
        exp:SetParent(self)
        exp:Spawn()
        exp:Fire("kill", "", self.EmitTime + 1)
    end
end

if CLIENT then
    function ENT:Initialize()
        self.SpawnTime = CurTime()

        -- ParticleEffectAttach("port_smoke_heavy", PATTACH_ABSORIGIN_FOLLOW, self, 1) -- flash
    end
end