util.AddNetworkString("BD.DeathCam")
RunConsoleCommand("ai_serverragdolls", 1)

local bdtab = {
    ["exp"] = {
        "deathrunning_09",
        "deathrunning_10",
        "deathrunning_11a",
        "deathrunning_11e",
        "deathrunning_11b",
        "deathrunning_11c",
        "DeathExplosion_01",
        "DeathExplosion_02",
        "DeathExplosion_03",
        "DeathExplosion_04",
        "DeathExplosion_05",
        "DeathExplosion_06",
        "DeathExplosion_07",
        "DeathExplosion_08",
    },
    ["club"] = {
        "club1",
        "club2",
        "club3",
        "club4",
        "bd_death_slasher_front",
        "bd_death_slasher_left",
        "bd_death_slasher_right",
        "bd_death_slasher_back",
    },
    ["moving"] = {
        "deathrunning_01",
        "deathrunning_03",
        "deathrunning_04",
        "deathrunning_05",
        "deathrunning_06",
        "deathrunning_07",
        "deathrunning_08",
        "deathrunning_11d",
        "deathrunning_11f",
        "deathrunning_11g",
        "deathrunning_12",
        "deathrunning_13",
        "deathrunning_14",
        "deathrunning_15",
        "deathrunning_16",
    },
    ["dying"] = {
        "death_01",
        "death_02a",
        "death_02c",
        "death_03",
        "death_05",
        "death_06",
        "death_07",
        "death_08",
        "death_08b",
        "death_09",
        "death_10ab",
        "death_10b",
        "death_10c",
        "death_11_01a",
        "death_11_01b",
        "death_11_02a",
        "death_11_02b",
        "death_11_02c",
        "death_11_02d",
        "death_11_03a",
        "death_11_03b",
        "death_11_03c",
        "dying1",
        "dying2",
        "dying3",
        "dying4",
        "dying5",
        "dying6",
        "dying7",
        "bd_death_leg_01",
        "bd_death_leg_02",
        "bd_death_leg_03",
        "bd_death_leg_04",
        "bd_death_leg_05",
        "bd_death_leg_06",
        "bd_death_leg_07",
        "bd_death_leg_08",
        "bd_death_legs_01",
    },
    ["bd_torso"] = {
        "bd_death_torso_long_01",
        "bd_death_torso_long_02",
        "bd_death_torso_long_03",
        "bd_death_torso_short_01",
        "bd_death_torso_short_02",
        "bd_death_torso_short_03",
        "bd_death_torso_short_04",
        "bd_death_torso_short_05",
        "bd_death_torso_short_06",
        "bd_death_torso_short_07",
        "bd_death_torso_short_08",
        "bd_death_torso_short_09",
        "bd_death_torso_short_10",
        "bd_death_torso_short_11",
        "bd_death_torso_short_12",
        "bd_death_torso_short_13",
        "bd_death_torso_short_14",
        "bd_death_torso_short_15",
        "bd_death_torso_short_16",
        "bd_death_torso_short_17",
        "bd_death_torso_short_18",
        "bd_death_torso_short_19",
        "bd_death_torso_short_20",
        "bd_death_torso_short_21",
        "bd_death_stomach_multi_01",
        "bd_death_stomach_single_01",
        "bd_death_stomach_single_02",
        "bd_death_stomach_short_01",
        "bd_death_stomach_short_02",
        "cod_1_torso_1",
        "cod_1_torso_2",
        "cod_1_torso_3",
        "cod_1_torso_4",
        "cod_1_torso_5",
        "cod_1_torso_6",
        "cod_1_torso_7",
    },
    ["bd_head"] = {
        "bd_death_head_01",
        "bd_death_head_02",
        "bd_death_head_03",
        "bd_death_head_04",
        "bd_death_head_05",
        "bd_death_head_07",
        "bd_death_head_08",
        "bd_death_head_multi_01",
        "bd_death_head_multi_02",
        "bd_death_head_multi_03",
        "bd_death_head_single_01",
        "bd_death_head_single_02",
        "bd_death_head_single_03",
        "bd_death_head_short_01",
        "bd_death_head_short_02",
        "bd_death_head_short_03",
    },
    ["bd_neck"] = {
        "bd_death_neck_short_01",
        "bd_death_neck_short_02",
        "bd_death_neck_short_03",
        "bd_death_neck_short_04",
    },
    ["bd_larm"] = {
        "bd_death_leftarm_multi_01",
        "bd_death_leftarm_multi_02",
        "bd_death_leftarm_multi_03",
        "bd_death_leftarm_multi_04",
        "bd_death_leftarm_single_01",
        "bd_death_leftarm_single_02",
        "bd_death_leftarm_single_03",
        "bd_death_leftarm_short_01",
        "bd_death_leftarm_short_02",
        "bd_death_leftarm_short_03",
    },
    ["bd_rarm"] = {
        "bd_death_rightarm_01",
        "bd_death_rightarm_02",
        "bd_death_rightarm_multi_01",
        "bd_death_rightarm_multi_02",
        "bd_death_rightarm_single_01",
        "bd_death_rightarm_single_02",
        "bd_death_rightarm_single_03",
        "bd_death_rightarm_single_04",  
    },
    ["bd_lleg"] = {
        "bd_death_leftleg_long_01",
        "bd_death_leftleg_long_02",
        "bd_death_leftleg_short_01",
        "bd_death_leftleg_short_02",
        "bd_death_leftleg_short_03",
        "bd_death_leftleg_short_04",
        "bd_death_leftleg_short_05",
        "bd_death_leftleg_short_06",
        "bd_death_leftleg_short_07",
        "bd_death_leftleg_short_08",
    },
    ["bd_rleg"] = {
        "bd_death_rightleg_multi_01",
        "bd_death_rightleg_multi_02",
        "bd_death_rightleg_multi_03",
        "bd_death_rightleg_short_01",
        "bd_death_rightleg_short_02",
        "bd_death_rightleg_single_01",
        "bd_death_rightleg_single_02",
        "bd_death_rightleg_single_03",
        "bd_death_rightleg_single_04",
        "bd_death_rightleg_single_05",
    },
}

local EnableNPCs = CreateConVar("bd_enable_npcs", 1,  FCVAR_ARCHIVE, "", 0, 1)
local EnablePlayers = CreateConVar("bd_enable_players", 1,  FCVAR_ARCHIVE, "", 0, 1)
local LifeScale = CreateConVar("bd_life_scale", 1,  FCVAR_ARCHIVE, "", 0)
local CrawlChance = CreateConVar("bd_crawl_chance", 10,  FCVAR_ARCHIVE, "", 0, 100)
local AnimChance = CreateConVar("bd_anim_chance", 100,  FCVAR_ARCHIVE, "", 1, 100)
local ClubAsDefault = CreateConVar("bd_club_as_default", 0,  FCVAR_ARCHIVE, "", 0, 1)
local OtherAsDefault = CreateConVar("bd_other_as_default", 0,  FCVAR_ARCHIVE, "", 0, 1)
-- Legacy setting retained for old configs; real bodies always ignore players.
CreateConVar("bd_nocollision", 1, FCVAR_ARCHIVE, "Player collisions are always disabled; bodies remain physgun traceable.", 0, 1)
local RemoveTime = CreateConVar("bd_remove_time", 120,  FCVAR_ARCHIVE, "", 0)
local FaceExp = CreateConVar("bd_face_expression", 1,  FCVAR_ARCHIVE, "", 0, 1)
local DebugType = CreateConVar("bd_debug_force_type", "none",  FCVAR_ARCHIVE)
local AnimClub = CreateConVar("bd_enableanim_club", 1,  FCVAR_ARCHIVE, "", 0, 1)
local AnimFire = CreateConVar("bd_enableanim_fire", 1,  FCVAR_ARCHIVE, "", 0, 1)
local AnimExplode = CreateConVar("bd_enableanim_explode", 1,  FCVAR_ARCHIVE, "", 0, 1)
local AnimBullet = CreateConVar("bd_enableanim_bullet", 1,  FCVAR_ARCHIVE, "", 0, 1)
local AnimMoving = CreateConVar("bd_enableanim_moving", 1,  FCVAR_ARCHIVE, "", 0, 1)
local AnimHeadshot = CreateConVar("bd_enableanim_headshot", 1,  FCVAR_ARCHIVE, "", 0, 1)
local AnimGenerate = CreateConVar("bd_generative_anims", 0,  FCVAR_ARCHIVE, "", 0, 1)
local QuickerRagdoll = CreateConVar("bd_quicker_ragdoll", 0,  FCVAR_ARCHIVE, "", 0, 1)

local function choose_bd_anims(type, data)
    data = data or {}
    local anim = "dying1"
    local model = "models/brutal_deaths/model_anim.mdl"
    if DebugType:GetString() != "none" then
        type = DebugType:GetString()
    end
    if type == "fire" then
        anim = "bd_death_fire1"
    elseif type == "explosion" then
        anim = table.Random(bdtab["exp"])
    elseif type == "club" then
        anim = table.Random(bdtab["club"])
    elseif type == "crawling" then
        anim = "crawling"..math.random(6,7)
    elseif type == "moving" then
        anim = table.Random(bdtab["moving"])
    else
        anim = table.Random(bdtab["dying"])
        -------------------------------------
        if data[1] == 1 then
            if data[2] then
                anim = table.Random(bdtab["bd_neck"]) 
            else
                anim = table.Random(bdtab["bd_head"]) 
            end
        elseif data[1] == 2 or data[1] == 3 then
            anim = table.Random(bdtab["bd_torso"])
        elseif data[1] == 4 then
            anim = table.Random(bdtab["bd_larm"]) 
        elseif data[1] == 5 then
            anim = table.Random(bdtab["bd_rarm"]) 
        elseif data[1] == 6 then
            anim = table.Random(bdtab["bd_lleg"]) 
        elseif data[1] == 7 then
            anim = table.Random(bdtab["bd_rleg"]) 
        end
    end
    return anim, model
end

local function setExpression(rag)
    if not FaceExp:GetBool() then return end
    rag:SetFlexScale(math.Rand(-1, 1))
    for i = 0, rag:GetFlexNum() - 1 do rag:SetFlexWeight(i, math.Rand(0, 1)) end
end

local function startAnimation(rag, kind, data, position, angles, scale)
    if not IsValid(rag) or rag.BD_AnimationInterrupted or rag:IsPlayerHolding() then return end
    if IsValid(rag.AnimModule) then rag.AnimModule:Remove() end
    local sequence, model = choose_bd_anims(kind, data)
    local driver = ents.Create("hari_ragdoll_animation")
    if not IsValid(driver) then return end
    -- Model and ragdoll must be assigned before Initialize builds its bone map.
    driver:SetModel(model)
    driver:SetModelScale(rag:GetModelScale(), 0)
    driver:SetPos(position)
    driver:SetAngles(angles)
    driver.Ragdoll = rag
    driver.AnimGenerate = AnimGenerate:GetBool()
    driver.LerpScale = scale or 1
    driver:Spawn()
    if not IsValid(driver) then return end
    local id, duration = driver:LookupSequence(sequence)
    if not id or id < 0 or not duration or duration <= 0 then
        driver:Remove()
        return
    end
    driver:ResetSequence(id)
    driver:SetCycle(0)
    driver.AnimString = sequence
    driver.ExpiresAt = CurTime() + duration / math.max(driver:GetPlaybackRate(), 0.1) + 0.5
    driver.FinishFunc = function() if IsValid(rag) then setExpression(rag) end end
    rag.AnimModule = driver
    rag.IsDeathRagdoll = true
    rag:CallOnRemove("bd_anim_cleanup", function(body)
        if IsValid(body.AnimModule) then body.AnimModule:Remove() end
    end)
    if BDRagdolls then BDRagdolls.Configure(rag) end
    return driver, duration / math.max(driver:GetPlaybackRate(), 0.1)
end

local function make_death_anim(ent, rag, kind, fallUntil)
    if not IsValid(ent) or not IsValid(rag) then return end
    if not fallUntil and not AnimHeadshot:GetBool() and ent.LastDamageHitgroup == HITGROUP_HEAD then return end
    local driver, duration = startAnimation(rag, kind,
        {ent.LastDamageHitgroup, ent.LastDamageIsNeck}, ent:GetPos(), Angle(0, ent:GetAngles().y, 0))
    if not IsValid(driver) then return end
    if fallUntil then
        -- Finish long donor sequences within the conscious fall phase, leaving
        -- a short settling interval before the real player starts crawling.
        local window = math.max(0.1, fallUntil - CurTime() - 0.35)
        local rate = driver:GetPlaybackRate()
        driver:SetPlaybackRate(math.max(rate, duration * rate / window))
        driver.ExpiresAt = math.min(driver.ExpiresAt, fallUntil)
        return -- No secondary NPC/corpse crawl or ignition on a living casualty.
    end
    rag.NPCClass = ent.GetNPCClass and ent:GetNPCClass() or ent.Classify and ent:Classify() or CLASS_BULLSEYE
    rag.RagHealth = ent:GetMaxHealth() * LifeScale:GetFloat()
    rag.MaxRagHealth = rag.RagHealth
    setExpression(rag)
    if kind == "fire" then rag:Ignite(30) end
    if kind == "bullet" or kind == "slash" then
        timer.Simple(duration + math.Rand(2, 8), function()
            if not IsValid(rag) or rag.BD_AnimationInterrupted or rag:IsPlayerHolding() or
                IsValid(rag.AnimModule) or (rag.RagHealth or 0) <= 0 then return end
            if math.random(1, 100) > CrawlChance:GetFloat() then return end
            local trace = util.TraceLine({start = rag:GetPos() + Vector(0, 0, 8),
                endpos = rag:GetPos() - Vector(0, 0, 50), filter = rag, mask = MASK_SOLID_BRUSHONLY})
            if not trace.Hit then return end
            startAnimation(rag, "crawling", nil, trace.HitPos + Vector(0, 0, 2),
                Angle(0, math.random(0, 359), 0), 0.5)
        end)
    end
end

hook.Add("ScaleNPCDamage", "DeathAnimsBrutal", function(ent,hit, dmg)
	ent.LastDamageHitgroup = hit
    if ent:LookupBone("ValveBiped.Bip01_Head1") then
        ent.LastDamageIsNeck = dmg:GetDamagePosition().z < ent:GetBonePosition(ent:LookupBone("ValveBiped.Bip01_Head1")).z
    end
end)

hook.Add("ScalePlayerDamage", "DeathAnimsBrutal", function(ent,hit, dmg)
	ent.LastDamageHitgroup = hit
    if ent:LookupBone("ValveBiped.Bip01_Head1") then
        ent.LastDamageIsNeck = dmg:GetDamagePosition().z < ent:GetBonePosition(ent:LookupBone("ValveBiped.Bip01_Head1")).z
    end
end)

hook.Add("EntityTakeDamage", "DeathAnimsBrutal", function(ent, dmg)
    if ent.IsDeathRagdoll then
        ent.RagHealth = (ent.RagHealth or 0) - dmg:GetDamage()
        if ent.RagHealth <= 0 and IsValid(ent.AnimModule) then
            ent.AnimModule:Remove()
        end
    end
    if ent:IsNPC() or ent:IsPlayer() then
        ent.DeathAnimType = nil
        if dmg:GetDamageType() == DMG_BURN or ent:IsOnFire() then
            ent.DeathAnimType = "fire"
        elseif (dmg:GetDamageType() == 0 and !OtherAsDefault:GetBool()) or isfunction(ent.IsDowned) and ent:IsDowned() then
            ent.DeathAnimType = nil
        elseif dmg:IsExplosionDamage() or dmg:GetDamageType() == DMG_BLAST then
            ent.DeathAnimType = "explosion"
        elseif ent:IsOnGround() and (ent:IsPlayer() and ent:GetVelocity():Length() > ent:GetWalkSpeed() or ent:IsNPC() and ent:GetIdealMoveSpeed() > 150) then
            ent.DeathAnimType = "moving"
        elseif dmg:IsBulletDamage() then
            ent.DeathAnimType = "bullet"
        elseif (dmg:GetDamageType() == DMG_CLUB or dmg:GetDamageType() == DMG_CRUSH) and !ClubAsDefault:GetBool() then
            ent.DeathAnimType = "club"
        elseif dmg:GetDamageType() == DMG_SLASH or (dmg:GetDamageType() == DMG_CLUB or dmg:GetDamageType() == DMG_CRUSH) and ClubAsDefault:GetBool() then
            ent.DeathAnimType = "slash"
        elseif OtherAsDefault:GetBool() then
            ent.DeathAnimType = "bullet"
        end

        if !AnimClub:GetBool() and ent.DeathAnimType == "club" then
            ent.DeathAnimType = nil
        elseif !AnimFire:GetBool() and ent.DeathAnimType == "fire" then
            ent.DeathAnimType = nil
        elseif !AnimExplode:GetBool() and ent.DeathAnimType == "explosion" then
            ent.DeathAnimType = nil
        elseif !AnimBullet:GetBool() and ent.DeathAnimType == "bullet" then
            ent.DeathAnimType = nil
        elseif !AnimMoving:GetBool() and ent.DeathAnimType == "moving" then
            ent.DeathAnimType = nil
        end
    end
end)

-- Helix owns its server corpses. Enabling the engine path as well creates
-- an additional body independently of persistent_corpses.
local function isHelix()
    return ix and ix.plugin and ix.char
end

hook.Add("PlayerSpawn", "DeathAnimsBrutal", function(ply)
    ply:SetShouldServerRagdoll(not isHelix() and EnablePlayers:GetBool())
    ply.DeathAnimType = nil
    ply.LastDamageHitgroup = nil
    ply.LastDamageIsNeck = nil
end)

hook.Add("PostPlayerDeath", "DeathAnimsBrutal", function(ply)
    if not isHelix() then return end
    local rag = ply:GetRagdollEntity()
    -- Only the engine's redundant body; never delete Helix's chosen corpse.
    if IsValid(rag) and rag ~= ply.ixDeathCorpse and rag ~= ply.ixRagdoll then rag:Remove() end
end)

hook.Add("CreateEntityRagdoll", "DeathAnimsBrutal", function(ent, rag)
    if not IsValid(ent) or not IsValid(rag) then return end
    if ent:IsPlayer() then
        if isHelix() or not EnablePlayers:GetBool() then return end
        net.Start("BD.DeathCam")
        net.WriteInt(rag:EntIndex(), 32)
        net.Send(ent)
    elseif ent:IsNPC() and not EnableNPCs:GetBool() then return end
    if BDRagdolls then BDRagdolls.Configure(rag) end
    if ent.DeathAnimType and math.random(1, 100) <= AnimChance:GetFloat() then
        make_death_anim(ent, rag, ent.DeathAnimType)
        if RemoveTime:GetFloat() > 0 then SafeRemoveEntityDelayed(rag, RemoveTime:GetFloat()) end
    end
end)

hook.Add("OnPlayerCorpseCreated", "BD_HelixCorpse", function(client, rag)
    if not EnablePlayers:GetBool() or not IsValid(client) or not IsValid(rag) then return end
    if rag.BD_CorpseHandled then return end
    rag.BD_CorpseHandled = true
    -- Preserve a collapse already in progress instead of snapping it upright.
    if rag.IsDeathRagdoll or rag.BD_AnimationInterrupted then return end
    if math.random(1, 100) <= AnimChance:GetFloat() then make_death_anim(client, rag, client.DeathAnimType) end
end)

hook.Add("OnCharacterFallover", "BD_HelixFallover", function(client, rag, state)
    if not state or not EnablePlayers:GetBool() then return end
    local downed = ix and ix.Downed
    local critical = downed and downed.Active and downed.Active(client)
    local falling = critical and downed.Falling and downed.Falling(client)
    -- At the end of the rescue window the character is already on the floor.
    -- Replaying a standing collapse there would pull the body upright again.
    if critical and not falling then return end
    local fallUntil = falling and client:GetNetVar("criticalFallUntil") or nil
    timer.Simple(0, function()
        if not IsValid(client) or not client:Alive() or not IsValid(rag) or
            client.ixRagdoll ~= rag or client.ixNoDeathAnim or rag.IsDeathRagdoll then return end
        if fallUntil and (not downed.Falling(client) or client:GetNetVar("criticalFallUntil") ~= fallUntil) then return end
        if fallUntil or math.random(1, 100) <= AnimChance:GetFloat() then
            make_death_anim(client, rag, nil, fallUntil)
        end
    end)
end)
