AddCSLuaFile()

SWEP.PrintName   = "Транквилизатор"
SWEP.Author      = ""
SWEP.Category    = "HL2 RP"
SWEP.Spawnable   = true
SWEP.AdminOnly   = true
SWEP.UseHands    = false -- v_-модель арбалета уже с руками
SWEP.DrawAmmo    = false
SWEP.DrawCrosshair = true

SWEP.ViewModel   = "models/weapons/v_crossbow.mdl"
SWEP.WorldModel  = "models/weapons/w_crossbow.mdl"

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.FalloverTime = 120  -- 2 минуты
SWEP.FireDelay    = 2.5
SWEP.Range        = 3000

function SWEP:Initialize()
	self:SetHoldType("crossbow")
end

function SWEP:Deploy()
	self:SendWeaponAnim(ACT_VM_DRAW)
	return true
end

function SWEP:PrimaryAttack()
	self:SetNextPrimaryFire(CurTime() + self.FireDelay)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	local owner = self:GetOwner()
	if (!IsValid(owner)) then return end

	owner:SetAnimation(PLAYER_ATTACK1)
	self:EmitSound("Weapon_Crossbow.Single")

	if (CLIENT) then return end

	local tr = util.TraceLine({
		start  = owner:GetShootPos(),
		endpos = owner:GetShootPos() + owner:GetAimVector() * self.Range,
		filter = owner,
		mask   = MASK_SHOT,
	})

	local hit = tr.Entity

	if (IsValid(hit) and hit:IsPlayer() and hit:Alive()) then
		self:Tranquilize(hit, owner)
	end

	-- Одноразовый: дротик израсходован — уничтожаем сам предмет (снимет оружие через OnRemoved).
	self:ConsumeSelf()
end

-- Расходует предмет-транквилизатор из инвентаря (или само оружие, если оно заспавнено через меню).
function SWEP:ConsumeSelf()
	if (self.ixConsumed) then return end
	self.ixConsumed = true

	local item = self.ixItem
	local owner = self:GetOwner()

	timer.Simple(0.15, function()
		if (IsValid(owner) and owner:IsPlayer()) then
			owner:Notify("Транквилизатор разряжен — дротик израсходован.")
		end

		if (item and item.Remove) then
			item:Remove() -- удаляет предмет и снимает оружие (Item:OnRemoved)
		elseif (IsValid(self)) then
			self:Remove() -- запасной путь для оружия из спавн-меню
		end
	end)
end

function SWEP:Tranquilize(victim, owner)
	-- Эффект и сообщения жертве — в общей функции плагина (см. sh_plugin.lua),
	-- чтобы дротомёт и контактный инъектор действовали одинаково.
	local plugin = ix.plugin.list["transvil"]
	if (!plugin or !plugin.ApplyTranquilizer) then return end

	-- Броня ловит дротик. Инъектор эту проверку не делает — контактный укол
	-- ставят в открытый участок тела.
	if (plugin.IsDartProof and plugin:IsDartProof(victim)) then
		victim:EmitSound("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav")
		victim:Notify("Дротик ударил в броню и отскочил.")

		if (IsValid(owner) and owner:IsPlayer()) then
			owner:Notify("Дротик не пробил броню цели.")
		end

		return
	end

	plugin:ApplyTranquilizer(victim, owner, self.FalloverTime)
end

function SWEP:SecondaryAttack() end
function SWEP:Reload() end
function SWEP:Holster() return true end
function SWEP:ShouldDropOnDie() return false end
