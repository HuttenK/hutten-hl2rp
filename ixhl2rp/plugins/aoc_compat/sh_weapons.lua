local A = ix.AOC
local thrown = {aoc_axe_thrown = true, aoc_dagger_thrown = true, aoc_dart_thrown = true,
 aoc_spear_thrown = true, aoc_oilpot = true, aoc_smokepot = true}

local function Managed(weapon)
 if SERVER then return weapon.ixItem ~= nil and weapon.ixInventoryReady == true end
 return weapon:GetNWInt("ixWeaponItem", 0) > 0
end

function A.Prepare(weapon)
 if not IsValid(weapon) or not weapon.AOC_Base then return end
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
  local canAttack, think, take = weapon.CanPrimaryAttack, weapon.Think, weapon.TakePrimaryAmmo
  weapon.CanPrimaryAttack = function(self)
   if Managed(self) and self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0 then return false end
   return canAttack(self)
  end
  weapon.TakePrimaryAmmo = function(self, count)
   local result = take(self, count)
   if SERVER and Managed(self) then ix.weaponInventory.Settle(self:GetOwner()) end
   return result
  end
  weapon.Think = function(self)
   local owner = self:GetOwner()
   if not IsValid(owner) then return end
   -- AoC deletes an empty thrown SWEP. Keep the inventory-owned launcher;
   -- otherwise re-equipping would resurrect it and could restore spent ammo.
   if SERVER and Managed(self) and not self:GetLoaded() and
    owner:GetAmmoCount(self.Primary.Ammo) <= 0 and CurTime() >= self:GetNextPrimaryFire() then
    if self:GetNextDraw() ~= 0 and CurTime() >= self:GetNextDraw() then
     self:SetNoDraw(false)
     self:SendWeaponAnim(ACT_VM_DRAW)
     self:SetNextDraw(0)
    end
    return
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
    self:SetArrowed(false)
   end
   return holster(self, ...)
  end
 end
end
