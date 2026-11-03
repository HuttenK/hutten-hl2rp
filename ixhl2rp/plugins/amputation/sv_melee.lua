local A = ix.Amputation

function A.IsMeleeHit(target, damage)
 if !IsValid(target) or !target:IsPlayer() or !target:Alive() or !target:GetCharacter() then return false end
 if damage:GetDamage() <= 0 or damage:GetAttacker() == target then return false end
 local weapon = damage:GetInflictor()
 if !IsValid(weapon) or !weapon:IsWeapon() or weapon.IsFists or weapon.AOC_Hands then return false end
 if weapon:GetClass() == "ix_hands" then return false end
 if !damage:IsDamageType(DMG_SLASH) and !damage:IsDamageType(DMG_CLUB) then return false end
 -- Never infer melee from the attacker's selected weapon: arrows, fire and
 -- thrown props have their own inflictor and must not borrow its eligibility.
 local item = weapon.ixItem
 return weapon.AOC_Melee == true or weapon.IsMelee == true or
  (item and (item.weaponCategory == "melee" or item.isMelee == true)) or false
end

hook.Add("ScalePlayerDamage", "ixAmputationTrace", function(target, hitgroup, damage)
 target.ixAmputationTrace = nil
 if !A.byHitgroup[hitgroup] or !A.IsMeleeHit(target, damage) then return end
 target.ixAmputationTrace = {hitgroup = hitgroup, time = CurTime(),
  weapon = damage:GetInflictor(), position = damage:GetDamagePosition()}
end)

function A.TryMeleeHit(target, damage, hitgroup)
 local trace = target.ixAmputationTrace
 target.ixAmputationTrace = nil -- Consume once, including a failed roll.
 if !trace or trace.time != CurTime() or trace.hitgroup != hitgroup or
  trace.weapon != damage:GetInflictor() or trace.position != damage:GetDamagePosition() then return false end
 if !A.IsMeleeHit(target, damage) or A.Get(target:GetCharacter()) then return false end
 local key = A.byHitgroup[hitgroup]
 if !key or math.random(1, 100) > A.meleeChance then return false end
 if !A.Amputate(target, key) then return false end
 A.GiveRemains(target, key, true)
 return true
end

-- The health pipeline calls this only after it has accepted the hit. Running
-- once here avoids extra rolls for armor bruises, fractures and other wounds.
hook.Add("CharacterBodyDamaged", "ixAmputationMelee", function(target, damage, hitgroup)
 A.TryMeleeHit(target, damage, hitgroup)
end)
