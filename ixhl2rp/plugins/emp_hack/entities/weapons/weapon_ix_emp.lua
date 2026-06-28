AddCSLuaFile()

SWEP.PrintName   = "ЭМИ-инструмент"
SWEP.Author      = ""
SWEP.Category    = "HL2 RP"
SWEP.Spawnable   = true
SWEP.AdminOnly   = true
SWEP.UseHands    = true
SWEP.DrawAmmo    = false
SWEP.DrawCrosshair = true

SWEP.ViewModel   = "models/weapons/v_emptool.mdl"
SWEP.WorldModel  = "models/weapons/w_emptool.mdl"

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Range     = 450
SWEP.FireDelay = 0.8
SWEP.Cooldown  = 30 -- секунд между успешными взломами

function SWEP:Initialize()
	self:SetHoldType("slam")
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW)
	return true
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.FireDelay)

	local owner = self:GetOwner()
	if (!IsValid(owner)) then return end

	-- 30-секундный кулдаун между успешными взломами.
	if (self.ixNextHack and CurTime() < self.ixNextHack) then
		if (SERVER) then
			owner:EmitSound("items/suitchargeno1.wav")
			owner:Notify("Устройство перезаряжается: " .. math.ceil(self.ixNextHack - CurTime()) .. " сек.")
		end

		return
	end

	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	if (CLIENT) then return end

	local plugin = ix.plugin.list["emp_hack"]
	if (!plugin) then return end

	local target = plugin:FindHackable(owner, self.Range)

	if (!IsValid(target)) then
		owner:EmitSound("items/suitchargeno1.wav")
		return
	end

	owner:EmitSound("ambient/energy/newspark0" .. math.random(1, 8) .. ".wav", 80)
	plugin:HackTarget(target, owner)

	-- Кулдаун запускается только при удачном взломе (промах не блокирует на 30 с).
	self.ixNextHack = CurTime() + self.Cooldown
end

function SWEP:SecondaryAttack()
	self:PrimaryAttack()
end

function SWEP:Reload() end
function SWEP:Think() end
function SWEP:Holster() return true end
function SWEP:ShouldDropOnDie() return false end
