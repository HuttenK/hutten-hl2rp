local A = ix.AOC
A.attackCries = {
 "medieval/combat/scream_1.wav",
 "medieval/combat/scream_2.wav",
 "medieval/combat/scream_3.wav",
 "medieval/combat/scream_4.wav"
}

if SERVER then
 for _,path in ipairs(A.attackCries) do resource.AddFile("sound/" .. path) end
end

function A.PlayAttackCry(owner)
 -- Server chooses once, including the attacker in the audible recipients.
 -- No client prediction copy: first person and nearby listeners hear one cry.
 if not SERVER then return end
 local path = A.attackCries[math.random(1, #A.attackCries)]
 local listeners = RecipientFilter()
 listeners:AddPAS(owner:GetPos())
 listeners:AddPlayer(owner)
 -- One voice channel per character prevents rapid swings stacking screams.
 owner:EmitSound(path, 80, 100, .85, CHAN_VOICE, 0, 0, listeners)
end
