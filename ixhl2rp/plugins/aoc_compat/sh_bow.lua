local A = ix.AOC

-- Native drawn Think gates firing on HEV power. Use Helix for that state;
-- outside it the addon's Think owns nocking, reload, idle and worldmodel.
local function shoot(weapon, owner)
 local arrow
 if SERVER then
  arrow = ents.Create("aoc_firedarrow")
  if not IsValid(arrow) then weapon:SecondaryAttack(); return end
 end
 owner:ViewPunch(Angle(-3, 0, 0))
 weapon:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
 local duration = weapon:SequenceDuration()
 weapon:EmitSound("AOC_longbow.Single")
 if weapon:Ammo1() <= 0 then weapon:SetNextIdle(CurTime() + duration) end
 weapon:SetNextPrimaryFire(CurTime() + duration)
 owner:DoAttackEvent()
 weapon:TakePrimaryAmmo(1)
 weapon:SetLoaded(false)
 weapon:SetShootTime(0)
 owner:DelayStaminaRecovery()

 if SERVER then
  owner:AOC_SetNextStamina(CurTime() + duration)
  local aim = owner:GetAimVector() + vector_up * 0.05
  arrow:SetPos(owner:GetShootPos() + aim * 32)
  arrow:SetAngles(aim:Angle())
  arrow:SetOwner(owner)
  arrow:Spawn()
  arrow:SetPhysicsAttacker(owner)
  local phys = arrow:GetPhysicsObject()
  if IsValid(phys) then phys:SetVelocityInstantaneous(aim * 2000) end
  arrow:EmitSound("Arrow.Fly")
 end
end

function A.PrepareBow(weapon)
 if weapon.ixBowDrain or not weapon.Think or not weapon.PrimaryAttack or not weapon.SecondaryAttack then return end
 weapon.ixBowDrain = tonumber(weapon.StaminaDrain) or 15
 local primary, cancel, think = weapon.PrimaryAttack, weapon.SecondaryAttack, weapon.Think
 weapon.PrimaryAttack = function(self, ...)
  local owner = self:GetOwner()
  if self:Clip1() > 0 and IsValid(owner) and owner:IsPlayer() and owner:GetCharacter()
   and owner:GetLocalVar("stm", 0) <= 0 then return end
  return primary(self, ...)
 end
 weapon.SecondaryAttack = function(self, ...)
  local drawn = self:GetLoaded()
  local result = cancel(self, ...)
  local owner = self:GetOwner()
  if drawn and not self:GetLoaded() and IsValid(owner) and owner:IsPlayer() and owner:GetCharacter() then
   owner:DelayStaminaRecovery()
  end
  return result
 end
 weapon.Think = function(self, ...)
  local owner = self:GetOwner()
  if not IsValid(owner) then return end
  if self:GetLoaded() and owner:IsPlayer() and owner:GetCharacter() then
   if owner:GetLocalVar("stm", 0) <= 0 then
    self:SecondaryAttack() -- native let-down keeps the nocked arrow
   elseif not owner:KeyDown(IN_ATTACK) and CurTime() >= self:GetShootTime() then
    shoot(self, owner)
   else
    return
   end
  end
  return think(self, ...)
 end
end
