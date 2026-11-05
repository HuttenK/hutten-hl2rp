local A = ix.AOC

-- Replace only AoC's player swing entry point. Its Think/Slice pipeline still
-- owns hit traces, parries and damage; NPCs retain the original addon method.
-- Install inside the trait wrapper, so Strong still scales the attack tables
-- and viewmodel timing before this reads them. No Workshop definitions change.
function A.PrepareStamina(weapon)
 if weapon.ixAOCStaminaPrepared or not weapon.AOC_Melee or not weapon.DoAttack then return end
 weapon.ixAOCStaminaPrepared = true
 local attack = weapon.DoAttack
 weapon.DoAttack = function(self, kind)
  local owner = self:GetOwner()
  if not IsValid(owner) then return end
  if not owner:IsPlayer() or not owner:GetCharacter() then return attack(self, kind) end
  return A.MeleeAttack(self, owner, kind)
 end
end

function A.MeleeAttack(weapon, owner, kind)
 if not weapon:CanPrimaryAttack() then return end
 local data, event, animation
 if kind == AOC_ATTACK_SLASH then
  data, event, animation = weapon.Primary, PLAYERANIMEVENT_ATTACK_PRIMARY, ACT_VM_PRIMARYATTACK
 elseif kind == AOC_ATTACK_OVERHEAD then
  data, event, animation = weapon.Secondary, PLAYERANIMEVENT_ATTACK_SECONDARY, ACT_VM_SECONDARYATTACK
 elseif kind == AOC_ATTACK_STAB then
  data, event, animation = weapon.Tertiary, PLAYERANIMEVENT_ATTACK_GRENADE, ACT_VM_HITCENTER
 end
 if not data then return end
 local cost = math.max(1, tonumber(data.Drain) or 10)
 -- This shared check predicts refusal, but only the server spends Helix stm.
 -- Charge once per swing, never for each trace slice or each target struck.
 if not owner:ProcessMeleeStamina(cost) then
  weapon:EmitPredictedSound("HL2Player.UseDeny")
  local retry = CurTime() + .25
  weapon:SetNextPrimaryFire(retry)
  weapon:SetNextSecondaryFire(retry)
  weapon:SetNextBlock(retry)
  return
 end

 local now = CurTime()
 weapon:EmitSound(data.Sound)
 weapon:SetNextPrimaryFire(now + data.Duration)
 weapon:SetNextBlock(now + data.Duration)
 owner:DoAnimationEvent(event)
 weapon:SendWeaponAnim(animation)
 local duration = weapon:SequenceDuration()
 weapon:SetCurrentAttack(kind)
 weapon:SetSliceTime(now)
 weapon:SetCurrentSlice(1)
 weapon:SetNextHolster(now + data.Duration)
 weapon:SetNextIdle(now + duration)
 -- Do not touch HEV suit power or its recovery timer: Helix owns this cost.
end
