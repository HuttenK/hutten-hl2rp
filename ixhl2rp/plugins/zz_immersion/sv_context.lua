util.AddNetworkString("ixImmersionImpact")
local function Impact(client, damage)
 if not IsValid(client) or not client:IsPlayer() or not client:GetCharacter() or damage:GetDamage() <= 0 then return end
 if (client.ixNextImmersionImpact or 0) > CurTime() then return end
 client.ixNextImmersionImpact = CurTime()+0.08
 local attacker = damage:GetAttacker()
 local directional = IsValid(attacker) and attacker ~= client and not attacker:IsWorld()
 net.Start("ixImmersionImpact")
 net.WriteFloat(math.Clamp(damage:GetDamage()/60,0.08,1))
 net.WriteBool(directional)
 if directional then net.WriteVector(attacker:WorldSpaceCenter()) end
 net.Send(client)
end
hook.Add("CharacterBodyDamaged", "ixImmersionImpact", Impact)
hook.Add("PostEntityTakeDamage", "ixImmersionImpact", function(client, damage, taken)
 if taken then Impact(client, damage) end
end)
