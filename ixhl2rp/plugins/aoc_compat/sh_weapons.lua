local A = ix.AOC
local thrown = {aoc_axe_thrown = true, aoc_dagger_thrown = true, aoc_dart_thrown = true,
 aoc_spear_thrown = true, aoc_oilpot = true, aoc_smokepot = true}

local function Managed(weapon)
 if SERVER then return weapon.ixItem ~= nil and weapon.ixInventoryReady == true end
 return weapon:GetNWInt("ixWeaponItem", 0) > 0
end

local function configureSingleThrow(weapon)
 if weapon.ixSingleThrow then return end
 weapon.Primary = table.Copy(weapon.Primary)
 weapon.Primary.Ammo = "none"
 weapon.Primary.DefaultClip = -1
 weapon.DrawAmmo = false
 weapon.ixSingleThrow = true
end

-- AoC's native Think strips a launcher as soon as its reserve is empty.
-- For inventory throws the SWEP itself is the round. Keep the addon's
-- wind-up and individual projectile constructors, and commit on release.
local function thinkSingleThrow(self, owner)
 if not self:GetLoaded() then
  if self:GetNextIdle() > 0 and CurTime() >= self:GetNextIdle() then
   self:SendWeaponAnim(ACT_VM_IDLE)
   self:SetNextIdle(0)
  end
  return
 end
 if owner:KeyDown(IN_ATTACK) or owner:KeyDown(IN_ATTACK2) or CurTime() < self:GetThrowTime() then return end
 local item = self.ixItem
 self:SetLoaded(false)
 self:SetThrowTime(0)
 if SERVER then
  if not owner:Alive() or owner:GetActiveWeapon() ~= self or not ix.WeaponSlots.Owns(owner, item)
   or not ix.WeaponSlots.Equipped(item) or ix.WeaponSlots.Pending(item) then return end
  if not IsValid(self:Throw()) then
   self:SendWeaponAnim(ACT_VM_DRAW)
   self:SetNextPrimaryFire(CurTime() + 0.25)
   owner:AOC_SetNextStamina(-1)
   return
  end
 end
 self:EmitSound(self.ThrowSound)
 self:SendWeaponAnim(ACT_VM_THROW)
 owner:DoAttackEvent()
 self:SetNextPrimaryFire(CurTime() + self:SequenceDuration())
 if SERVER then
  if GetConVarNumber("gmod_suit") ~= 0 then owner:SetSuitPower(math.max(owner:GetSuitPower() - 10, 0)) end
  owner:AOC_SetNextStamina(self:GetNextPrimaryFire())
  item:Remove(true) -- OnRemoved strips this item's SWEP and frees its slot.
 end
end

function A.Prepare(weapon)
 if not IsValid(weapon) or not weapon.AOC_Base then return end
 if thrown[weapon:GetClass()] and Managed(weapon) then configureSingleThrow(weapon) end
 A.PrepareSwing(weapon)
 A.PrepareStamina(weapon)
 if ix.Traits then ix.Traits.PrepareWeapon(weapon) end
 if weapon.ixAOCRevision == A.revision then return end
 weapon.ixAOCRevision = A.revision
 -- Keep name mappings per entity. Upstream TranslateActivity replaces them
 -- with model-dependent activity IDs, which become stale after a model swap.
 weapon.ActivityTranslate = table.Copy(weapon.ActivityTranslate or {})
 local hold = weapon:GetHoldType()
 if not hold or hold == "" then hold = weapon.HoldType end
 if hold and weapon.SetWeaponHoldType then weapon:SetWeaponHoldType(hold) end
 if weapon.ixAOCPrepared then return end
 weapon.ixAOCPrepared = true
 local translate = weapon.TranslateActivity
 if translate then
  weapon.TranslateActivity = function(self, activity)
   local owner = self:GetOwner()
   local entry = self.ActivityTranslate and self.ActivityTranslate[activity]
   if IsValid(owner) and owner:IsPlayer() and isstring(entry) then
    local sequence = A.Sequence(owner, entry)
    return sequence ~= nil and owner:GetSequenceActivity(sequence) or ACT_INVALID
   end
   return translate(self, activity)
  end
 end
 if thrown[weapon:GetClass()] then
  local think = weapon.Think
  weapon.Think = function(self)
   local owner = self:GetOwner()
   if not IsValid(owner) then return end
   if Managed(self) then
    -- The item ID can reach a client after the weapon entity was prepared.
    configureSingleThrow(self)
    return thinkSingleThrow(self, owner)
   end
   return think(self)
  end
 elseif weapon:GetClass() == "aoc_longbow" then
  A.PrepareBow(weapon)
  local holster = weapon.Holster
  weapon.Holster = function(self, ...)
   if SERVER and Managed(self) and not self:GetLoaded() and self:Clip1() > 0 then
    local owner, count = self:GetOwner(), self:Clip1()
    ix.weaponInventory.Settle(owner)
    self:SetClip1(0)
    if not ix.weaponInventory.ReturnAmmo(owner, self.Primary.Ammo, count) then
     self:SetClip1(count)
     return false
    end
    self.ixItem:SetData("ammo", 0)
    self:SetArrowed(false)
   end
   return holster(self, ...)
  end
 end
 -- Both launchers auto-load by moving one round from the engine reserve to
 -- Clip1. Debit its inventory stack immediately, before any transfer or save.
 local class = weapon:GetClass()
 if SERVER and (class == "aoc_crossbow" or class == "aoc_longbow") and weapon.Reload then
  local reload = weapon.Reload
  weapon.Reload = function(self, ...)
   local before = self:Clip1()
   local result = reload(self, ...)
   if Managed(self) and self:Clip1() > before then ix.weaponInventory.Settle(self:GetOwner()) end
   return result
  end
 end
end
