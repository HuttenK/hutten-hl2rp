local T=ix.Traits
-- These classes require strength, not merely two hands. Shields/paired knives
-- still occupy two inventory slots but must not inherit this restriction.
T.heavyWeapons={aoc_longbow=true,aoc_flamberge=true,aoc_longsword=true,
 aoc_halberd=true,aoc_halberd_evil=true,aoc_doubleaxe=true,aoc_warhammer=true}
function T.CanUseWeapon(character,class)
 return not (T.Has(character,"weak") and T.heavyWeapons[class])
end
function T.AttackRate(weapon)
 local owner=weapon:GetOwner()
 if not weapon.AOC_Melee or weapon.AOC_Hands or not IsValid(owner) or not owner:IsPlayer() then return 1 end
 return T.Modifier(owner:GetCharacter(),"attackSpeed")
end
function T.PrepareWeapon(weapon)
 if weapon.ixTraitsPrepared or not weapon.AOC_Melee or not weapon.DoAttack then return end
 weapon.ixTraitsPrepared=true
 local attack,send,sequenceDuration,canAttack=weapon.DoAttack,weapon.SendWeaponAnim,weapon.SequenceDuration,weapon.CanPrimaryAttack
 local original={Primary=table.Copy(weapon.Primary or {}),Secondary=table.Copy(weapon.Secondary or {}),Tertiary=table.Copy(weapon.Tertiary or {})}
 -- Per-instance copies: Workshop definitions and other players stay unchanged.
 weapon.DoAttack=function(self,kind)
  local owner=self:GetOwner()
  if IsValid(owner) and owner:IsPlayer() and not T.CanUseWeapon(owner:GetCharacter(),self:GetClass()) then return end
  if not self:CanPrimaryAttack() then return end
  local rate=T.AttackRate(self)
  if self.ixTraitAttackRate~=rate then
   for name,base in pairs(original) do
    local data=table.Copy(base)
    if data.Duration then data.Duration=data.Duration/rate end
    for _,slice in ipairs(data) do if slice.Time then slice.Time=slice.Time/rate end end
    self[name]=data
   end
   self.ixTraitAttackRate=rate
  end
  -- Only attack animation lengths are shortened; idle/block/draw reset to 1.
  self.ixTraitSendingAttack=true
  local result=attack(self,kind)
  self.ixTraitSendingAttack=nil
  return result
 end
 weapon.SendWeaponAnim=function(self,...)
  local result=send(self,...)
  local owner=self:GetOwner()
  local vm=IsValid(owner) and owner:IsPlayer() and owner:GetViewModel()
  if IsValid(vm) then vm:SetPlaybackRate(self.ixTraitSendingAttack and (self.ixTraitAttackRate or 1) or 1) end
  return result
 end
 weapon.SequenceDuration=function(self,...)
  local duration=sequenceDuration(self,...)
  return self.ixTraitSendingAttack and duration/(self.ixTraitAttackRate or 1) or duration
 end
 if canAttack then
  weapon.CanPrimaryAttack=function(self,...)
   local owner=self:GetOwner()
   if IsValid(owner) and owner:IsPlayer() and not T.CanUseWeapon(owner:GetCharacter(),self:GetClass()) then return false end
   return canAttack(self,...)
  end
 end
end
