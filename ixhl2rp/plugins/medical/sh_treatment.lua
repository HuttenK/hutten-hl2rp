-- Catalog is loaded in libs/sh_catalog.lua before items.
local M = ix.Medicine

-- Workshop medicine SWEPs use an unrelated health/ammo system. In Helix only
-- inventory-owned ix_med_* animations may administer treatment. Patch registered
-- definitions too, so an older mounted Workshop copy cannot call OJSWounds.
function M.GuardLegacyWeapons()
 if not weapons.GetList then return end
 for _, weapon in ipairs(weapons.GetList()) do
  local className=weapon.ClassName or ""
  if className:sub(1,11)=="weapon_eft_" and not weapon.ixInventoryMedicineOnly then
   weapon.ixInventoryMedicineOnly=true
   weapon.Spawnable=false
   weapon.Deploy=function(self)
    local owner=self:GetOwner()
    if SERVER and IsValid(owner) and owner.Notify then
     owner:Notify("Используйте медикамент из инвентаря или меню H.")
    end
    return false
   end
   weapon.Heal=function() return false end
   weapon.PrimaryAttack=function() end
   weapon.SecondaryAttack=function() end
  end
 end
end
M.GuardLegacyWeapons()
hook.Add("InitPostEntity","ixMedicineLegacySWEPs",M.GuardLegacyWeapons)

function M.PainSuppressed(health, now)
 now = now or os.time()
 for _, diff in health:GetHediffs() do
  if diff.uniqueID == "painkiller" and (diff.severity or 0) > 0 and
   (diff.tended_time or -1) > 0 and (diff.tended_start or 0) + diff.tended_time > now then return true end
 end
 return false
end

function M.HasFracture(health, kind, includeSuppressed)
 if not health or (not includeSuppressed and M.PainSuppressed(health)) then return false end
 for _, diff in health:GetHediffs() do
  local part = health.body.parts[diff.part]
  if diff.isFracture and diff:GetSeverity() > 0 and part and
   ((kind == "leg" and part.movement) or (kind == "arm" and part.canFracture and not part.movement)) then return true end
 end
 return false
end

function M.TwoHanded(weapon)
 if not IsValid(weapon) then return false end
 local item = weapon.ixItem
 if item and item.twoHanded ~= nil then return item.twoHanded end
 if item and item.weaponCategory == "primary" then return true end
 local hold = weapon.HoldType or (weapon.GetHoldType and weapon:GetHoldType())
 return ({ar2=true, smg=true, shotgun=true, crossbow=true, rpg=true, physgun=true, melee2=true})[hold] == true
end

function M.CanUseWeapon(client, weapon)
 local char = client:GetCharacter()
 return not (char and M.HasFracture(char:Health(), "arm") and M.TwoHanded(weapon))
end

hook.Add("PlayerSwitchWeapon", "ixMedicalFracturedArm", function(client, old, weapon)
 if not M.CanUseWeapon(client, weapon) then
  if SERVER and (client.ixFractureNotice or 0) < CurTime() then
   client.ixFractureNotice = CurTime() + 3
   client:Notify("Перелом руки: двуручное оружие недоступно. Нужны лечение или обезболивающее.")
  end
  return true
 end
end)

hook.Add("StartCommand", "ixMedicalTreatmentInput", function(client, command)
 local weapon = client:GetActiveWeapon()
 if client.bUsingMedical or not M.CanUseWeapon(client, weapon) then
  command:RemoveKey(IN_ATTACK)
  command:RemoveKey(IN_ATTACK2)
  if SERVER and not client.bUsingMedical and not M.CanUseWeapon(client, weapon) then
   local hands = client:GetWeapon("ix_hands")
   if IsValid(hands) then command:SelectWeapon(hands) end
  end
 end
end)

if SERVER then
 hook.Add("OnHediffAdded", "ixMedicalFractures", function(health, diff, hitgroup)
  local part = health:GetParts(hitgroup)
  if diff.isInjury and not diff.isFracture and part and part.canFracture and
   health:GetPartHealth(part.id) <= health:GetMaxHealth(part.id) * .2 then
   health:AddHediff("fracture", hitgroup, {severity=5})
  end
 end)
end

-- Use complete, deterministic EFT sequences; no random partial animations.
function M.AnimationPlan(def)
 if def.model == "cat" then return {ACT_VM_RECOIL1, ACT_VM_RECOIL2, ACT_VM_RECOIL3} end
 if def.model == "afak" then return {ACT_VM_RECOIL1, ACT_VM_RECOIL2, ACT_VM_RECOIL2, ACT_VM_RECOIL3} end
 if def.model == "salewa" or def.model == "grizzly" or def.model == "automedkit" then
  return {ACT_VM_MISSRIGHT, ACT_VM_MISSRIGHT2, ACT_VM_MISSRIGHT2, ACT_VM_MISSCENTER2}
 end
 return {ACT_VM_RECOIL1}
end

-- Register isolated animation-only weapons. The original addon SWEPs are not used.
for id, def in pairs(M.Catalog) do
 local weapon = {
  Base="weapon_base", PrintName=def.name, Spawnable=false, AdminOnly=true,
  UseHands=true, IsAlwaysRaised=true, ViewModel=M.Model(def, true), WorldModel=M.Model(def), ViewModelFOV=65,
  DrawAmmo=false, DrawCrosshair=false, Primary={ClipSize=-1, DefaultClip=-1, Automatic=false, Ammo="none"},
  Secondary={ClipSize=-1, DefaultClip=-1, Automatic=false, Ammo="none"},
  MedicalID=id, HoldType="slam"
 }
 function weapon:Initialize() self:SetHoldType("slam") end
 function weapon:PrimaryAttack() end
 function weapon:SecondaryAttack() end
 function weapon:Reload() end
 function weapon:Deploy()
  if SERVER then
   local owner = self:GetOwner()
   local session = IsValid(owner) and owner.ixMedicalSession
   if not session or session.weapon ~= self then return false end
   self.medStep, self.medNext = 0, CurTime() + .15
  end
  return true
 end
 function weapon:Think()
  if not SERVER then return end
  local owner = self:GetOwner()
  local session = IsValid(owner) and owner.ixMedicalSession
  if not session or session.weapon ~= self then return end
  if owner:GetActiveWeapon() ~= self then return end
  if self.medNext and CurTime() >= self.medNext then
   self.medStep = self.medStep + 1
   local activity = session.plan[self.medStep]
   if not activity then M.Finish(owner, true) return end
   local vm = owner:GetViewModel()
   if not IsValid(vm) then M.Finish(owner, false) return end
   local sequence = vm:SelectWeightedSequence(activity)
   if not sequence or sequence < 0 then
    owner:Notify("Модель не содержит нужной медицинской анимации.")
    M.Finish(owner, false) return
   end
   self:SendWeaponAnim(activity)
   vm:SetSkin(def.skin or 0)
   vm:SetPlaybackRate(session.rate)
   self.medNext = CurTime() + math.max(.1, vm:SequenceDuration(sequence) / session.rate)
   if self.medStep == 1 and (def.model == "afak" or def.model == "automedkit" or def.model == "grizzly" or def.model == "alusplint") then
    timer.Simple((def.model == "alusplint" and 1.5 or .5) / session.rate, function()
     if IsValid(self) and IsValid(owner) and owner.ixMedicalSession == session then
      owner:EmitSound(def.model == "alusplint" and "MedsSplint.Middle" or "MedsGrizzly.Open", 55)
     end
    end)
   end
  end
 end
 function weapon:Holster()
  if SERVER and IsValid(self:GetOwner()) then M.Finish(self:GetOwner(), false) end
  return true
 end
 function weapon:PreDrawViewModel(vm) vm:SetSkin(def.skin or 0) end
 if CLIENT then
  local offsets = {
   cat={0,-5,0,-90,180,0}, alusplint={0,-5,0,-90,180,0}, augmentin={0,-5,0,-90,180,0},
   afak={3,-4,3,0,0,-180}, anaglin={4,-3,-2,-90,180,0}, automedkit={3,-5,3,0,0,180},
   grizzly={3,-7,5,0,0,-180}, injector={3,-1,2,-180,0,0}, salewa={4,-4,5,0,-90,-180},
   surgicalkit={4,-1,-1,-90,180,-90}
  }
  function weapon:DrawWorldModel()
   local owner = self:GetOwner()
   if not IsValid(owner) then return end
   local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
   local matrix = bone and owner:GetBoneMatrix(bone)
   if not matrix then return end
   if not IsValid(self.medModel) then
    self.medModel = ClientsideModel(self.WorldModel, RENDERGROUP_OPAQUE)
    if not IsValid(self.medModel) then return end
    self.medModel:SetNoDraw(true)
    self.medModel:SetSkin(def.skin or 0)
   end
   local offset = offsets[def.model]
   local pos, ang = LocalToWorld(Vector(offset[1],offset[2],offset[3]), Angle(offset[4],offset[5],offset[6]), matrix:GetTranslation(), matrix:GetAngles())
   self.medModel:SetPos(pos); self.medModel:SetAngles(ang)
   self.medModel:SetupBones(); self.medModel:DrawModel()
  end
  function weapon:OnRemove() if IsValid(self.medModel) then self.medModel:Remove() end end
 end
 weapons.Register(weapon, "ix_med_"..id)
end
