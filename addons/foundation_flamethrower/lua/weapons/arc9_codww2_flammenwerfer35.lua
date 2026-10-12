AddCSLuaFile()

SWEP.Base = "arc9_base"

SWEP.Spawnable = true
SWEP.Category = "ARC9 - CoD WWII"
SWEP.SubCategory = "Specials"

SWEP.PrintName = "Flammenwerfer 35"
SWEP.Class = "Flamethrower"

SWEP.Trivia = {
    Manufacturer = "Different State Manufacturers",
    Calibre = "Flammol",
    Mechanism = "Pressurized Incendiary Projector",
    Origin = "Germany",
    Year = "1935"
}

SWEP.Credits = {
    Author = "YouTee",
    Assets = "CoD WWII ported assets",
    SpecialThanks = "Reserve au serveur FrontG"
}

SWEP.Description = [[German Flammenwerfer 35 converted for ARC9.

Fires a short stream of burning fuel that ignites players for up to 100 burn damage.

Addon by YouTee, reserve au serveur FrontG.]]

SWEP.ViewModel = "models/weapons/tfa_codww2/flammenwerfer35/c_flammenwerfer35.mdl"
SWEP.WorldModel = "models/weapons/tfa_codww2/flammenwerfer35/w_flammenwerfer35.mdl"
SWEP.ViewModelFOVBase = 65

SWEP.Slot = 4
SWEP.MirrorVMWM = true
SWEP.NoTPIK = true
SWEP.WorldModelOffset = {
    Pos = Vector(-10, 4, -6),
    TPIKPos = Vector(-10, 4, -6),
    Ang = Angle(-8, 0, 180),
    Scale = 1
}
SWEP.NoTPIKVMPos = true

-------------------------- DAMAGE PROFILE

SWEP.ShootEnt = "arc9_codww2_flamethrower_fx"
SWEP.ShootEntForce = 2200
SWEP.ARC9CODWW2FlameRange = 590.6 -- 15 metres in Source units.

-------------------------- MAGAZINE

SWEP.Ammo = "arc9_napalm"
SWEP.ChamberSize = 0
SWEP.ClipSize = 1000
SWEP.ForceDefaultClip = 1000
SWEP.ForceDefaultAmmo = 0
SWEP.SupplyLimit = 0
-- Unlimited decontamination stream; even saved empty tanks can fire.
SWEP.AmmoPerShot = 0
SWEP.ARC9CODWW2UnlimitedFuel = true

SWEP.ReloadWhileSprint = true
SWEP.ReloadInSights = false
SWEP.BarrelLength = 18
SWEP.DryFireDelay = 0.35

-------------------------- FIREMODES

SWEP.RPM = 900
SWEP.Firemodes = {
    {
        Mode = -1
    }
}

-------------------------- RECOIL

SWEP.Recoil = 0
SWEP.RecoilUp = 0
SWEP.RecoilSide = 0
SWEP.RecoilRandomUp = 0
SWEP.RecoilRandomSide = 0
SWEP.RecoilAutoControl = 0
SWEP.RecoilPatternDrift = 0

-------------------------- SPREAD

SWEP.Spread = 0

-------------------------- HANDLING

SWEP.FreeAimRadius = 0
SWEP.FreeAimRadiusMultSights = 0
SWEP.Sway = 1.35
SWEP.SwayMultSights = 0.8
SWEP.SwayMultMove = 1.4
SWEP.AimDownSightsTime = 0.45
SWEP.SprintToFireTime = 0.55
SWEP.SpeedMult = 0.85

-------------------------- SOUNDS

SWEP.ShootVolume = 115
SWEP.ShootVolumeActual = 1
SWEP.ShootPitch = 100
SWEP.ShootPitchVariation = 0

SWEP.FirstShootSound = nil
SWEP.ShootSound = ""
SWEP.ShootSoundLooping = "ARC9_CODWW2_M2FT.Loop"
SWEP.ShootSoundTail = nil
SWEP.DistantShootSound = nil

SWEP.DryFireSound = "ARC9_CODWW2_M2FT.Dry"
SWEP.DryFireSingleAction = false

SWEP.EnterSightsSound = ""
SWEP.ExitSightsSound = ""

-------------------------- EFFECTS

SWEP.MuzzleParticle = "ww2_flamethrower_long"
SWEP.NoShellEject = true
SWEP.MuzzleEffectQCA = 1
SWEP.ARC9CODWW2MuzzleAttachment = "tag_flash"
SWEP.ARC9CODWW2MuzzleOffset = Vector(0, 0, 0)
SWEP.ARC9CODWW2ShootOffset = Vector(18, 0, -6)
SWEP.ARC9CODWW2FallbackShootOffset = Vector(24, 0, -7)
SWEP.ARC9CODWW2ViewMuzzleOffset = Vector(0, 0, 0)
SWEP.ARC9CODWW2WorldFlameDrop = 0
SWEP.ARC9CODWW2HandMuzzleOffset = Vector(42, 0, -2)
SWEP.ARC9CODWW2FlameParticle = "ww2_flamethrower_long"
SWEP.ARC9CODWW2EffectDelay = 0.06
SWEP.CamQCA = nil
SWEP.AfterShotEffect = nil
SWEP.AfterShotParticle = nil

-------------------------- POSITIONS

SWEP.IronSights = {
    Pos = Vector(-2.86, -3, 1.5),
    Ang = Angle(1.5, 0, 0),
    Magnification = 1,
    ViewModelFOV = 65
}

SWEP.SightMidPoint = {
    Pos = Vector(0, 0, 0),
    Ang = Angle(0, 0, 0)
}

SWEP.ActivePos = Vector(0, -1.75, 0)
SWEP.ActiveAng = Angle(0, 0, 0)

SWEP.MovingPos = Vector(0, -2.5, -0.5)
SWEP.MovingAng = Angle(0, 0, 0)

SWEP.CrouchPos = Vector(-0.5, -1, 0.75)
SWEP.CrouchAng = Angle(0, 0, 0)

SWEP.RestPos = Vector(5, 2, 1)
SWEP.RestAng = Angle(45, -15, 0)

SWEP.HolsterPos = Vector(0, 0, -5)
SWEP.HolsterAng = Angle(0, -15, 25)

SWEP.SprintMidPoint = {
    Pos = Vector(4, 0, -4),
    Ang = Angle(0, 0, 0)
}

SWEP.CustomizeAng = Angle(90, 0, 0)
SWEP.CustomizePos = Vector(20, 36, 4)
SWEP.CustomizeRotateAnchor = Vector(16, -2, -3)
SWEP.CustomizeSnapshotFOV = 90
SWEP.CustomizeSnapshotPos = Vector(0, 8, 4)
SWEP.CustomizeSnapshotAng = Angle(0, 0, 0)
SWEP.CustomizeNoRotate = false

SWEP.PeekPos = Vector(2, 0, -2)
SWEP.PeekAng = Angle(0, 0, 0)
SWEP.HeightOverBore = 1

-------------------------- HoldTypes

SWEP.HoldType = "ar2"
SWEP.HoldTypeSprint = "passive"
SWEP.HoldTypeHolstered = nil
SWEP.HoldTypeSights = "ar2"
SWEP.HoldTypeCustomize = "slam"

SWEP.AnimShoot = ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2
SWEP.AnimReload = ACT_HL2MP_GESTURE_RELOAD_MAGIC
SWEP.NonTPIKAnimReload = ACT_HL2MP_GESTURE_RELOAD_AR2
SWEP.AnimDraw = false
SWEP.AnimMelee = ACT_GMOD_GESTURE_MELEE_SHOVE_2HAND

SWEP.Animations = {
    ["idle"] = { Source = "idle" },
    ["idle_iron"] = { Source = "idle", Time = math.huge },
    ["fire"] = { Source = "fire", Mult = 1.1 },
    ["fire_iron"] = { Source = "fire", Mult = 1.1 },
    ["reload"] = { Source = "reload", MinProgress = 0.75, MagSwapTime = 2.2 },
    ["reload_empty"] = { Source = "reload", MinProgress = 0.75, MagSwapTime = 2.2 },
    ["draw"] = { Source = "idle", Time = 0.15 },
    ["ready"] = { Source = "idle", Time = 0.15 },
    ["holster"] = { Source = "idle", Time = 0.15 },
    ["bash"] = { Source = "melee" },
    ["sprint_in"] = { Source = "sprint_in" },
    ["sprint_loop"] = { Source = "sprint_loop", Mult = 0.75 },
    ["sprint_out"] = { Source = "sprint_out" }
}

-------------------------- MODEL PARTS

SWEP.DefaultElements = {"receiver_default", "barrel_default", "muzzle_default"}

SWEP.AttachmentElements = {
    ["receiver_default"] = {
        Models = {
            {
                Model = "models/weapons/tfa_codww2/flammenwerfer35/c_flammenwerfer35_receiver.mdl",
                Bone = "tag_weapon",
                Pos = Vector(0, 0, 0),
                Ang = Angle(0, 0, 0),
                BoneMerge = true
            }
        }
    },
    ["barrel_default"] = {
        Models = {
            {
                Model = "models/weapons/tfa_codww2/flammenwerfer35/c_flammenwerfer35_barrel.mdl",
                Bone = "tag_weapon",
                Pos = Vector(0, 0, 0),
                Ang = Angle(0, 0, 0),
                BoneMerge = true
            }
        }
    },
    ["muzzle_default"] = {
        Models = {
            {
                Model = "models/weapons/tfa_codww2/flammenwerfer35/c_flammenwerfer35_muzzle.mdl",
                Bone = "tag_weapon",
                Pos = Vector(0, 0, 0),
                Ang = Angle(0, 0, 0),
                BoneMerge = true
            }
        }
    }
}

SWEP.Attachments = {}


function SWEP:GetShootPos()
    if ARC9_CODWW2_FlamethrowerShootPos then
        return ARC9_CODWW2_FlamethrowerShootPos(self)
    end

    local owner = self:GetOwner()
    if not IsValid(owner) then return self:GetPos(), self:GetAngles() end

    local ang = owner:EyeAngles()
    local offset = self.ARC9CODWW2ShootOffset or Vector(18, 0, -6)
    local pos = owner:GetShootPos()
    pos = pos + ang:Forward() * offset.x
    pos = pos + ang:Right() * offset.y
    pos = pos + ang:Up() * offset.z

    return pos, ang
end

function SWEP:GetShootDir()
    local _, ang = self:GetShootPos()

    return ang
end

function SWEP:ARC9CODWW2StripReserve()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsPlayer() then return end

    owner:SetAmmo(0, self:GetValue("Ammo") or self.Ammo)
end

function SWEP:HookP_BlockFire()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- Retain the muzzle obstruction check without timed burst/cooldown limits.
    local shootPos, shootAng = self:GetShootPos()
    local tr = util.TraceLine({
        start = shootPos,
        endpos = shootPos + shootAng:Forward() * 38,
        filter = owner,
        mask = MASK_SHOT
    })

    if tr.HitWorld then return true end
end

function SWEP:Hook_PrimaryAttack()
    self.ARC9CODWW2LastFlameTime = CurTime()
    self:ARC9CODWW2StripReserve()

    if SERVER and ARC9_CODWW2_BroadcastFlamethrowerEffect then
        ARC9_CODWW2_BroadcastFlamethrowerEffect(self)
    end
end

function SWEP:HookP_TranslateSound(soundtab)
    if soundtab and soundtab.sound == "" then
        soundtab.sound = nil
    end

    return soundtab
end

function SWEP:DoEffects()
    if ARC9_CODWW2_FlamethrowerDoEffects then
        ARC9_CODWW2_FlamethrowerDoEffects(self)
    end
end

function SWEP:Hook_Think()
    self:ARC9CODWW2StripReserve()
end

function SWEP:Hook_Deploy()
    self:ARC9CODWW2StripReserve()

    if not self.ARC9CODWW2FuelInitialized then
        self.ARC9CODWW2FuelInitialized = true

        if SERVER and self:Clip1() <= 0 then
            self:SetClip1(self.ClipSize)
        end
    end
end

function SWEP:CanReload()
    return false
end

function SWEP:Hook_BlockTPIK()
    return true
end
