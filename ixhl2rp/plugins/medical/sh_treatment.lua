-- Catalog is loaded in libs/sh_catalog.lua before items.
local M = ix.Medicine

function M.HasFracture(health, kind, includeSuppressed)
 if not health then return false end
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
   client:Notify("Перелом руки: двуручное оружие недоступно. Нужно лечение.")
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
