local S = ix.SCPMedicine
if not S then return end

-- Damage caps prevent Sandbox's 500-1000 damage executions from obliterating
-- several medical body parts. These are gameplay values, not Source health.
S.profiles = {
    bite = {class="slash", cap=50, amputate=true},
    cardiac = {condition="scp_cardiac", hitgroup=HITGROUP_CHEST, cap=0},
    neck = {condition="scp_neck", hitgroup=HITGROUP_HEAD, cap=0},
    maul = {class="slash", cap=90, spread=true},
    crush = {class="club", cap=70, spread=true, fracture=true},
    corrosion = {class="acid", cap=25, condition="scp_corrosion"},
    corrosion035 = {class="acid", cap=25, condition="scp_corrosion_035"},
    infection = {class="slash", cap=25, condition="scp_infection"},
    burn = {class="burn", cap=30},
    fatigue = {class="slash", cap=20, condition="scp_fatigue"},
    airway = {condition="scp_airway", hitgroup=HITGROUP_HEAD, cap=0},
    shock = {condition="scp_shock", hitgroup=HITGROUP_HEAD, cap=0},
    slash = {class="slash", cap=40},
    blunt = {class="club", cap=45}
}
local groups = {[939]="bite", [173]="neck", [096]="maul", [682]="crush", [106]="corrosion",
    [008]="infection", [457]="burn", [966]="fatigue", [1048]="airway", [895]="shock", [303]="shock",
    [035]="corrosion035", [087]="shock", [178]="slash", [372]="slash", [513]="slash", [575]="slash",
    [860]="slash", [1499]="blunt", [553]="slash"}

function S.Profile(entity)
    if not IsValid(entity) then return end
    local name = entity:GetClass()
    if name == "obj_cpt_scp_flame" then return S.profiles.burn end
    if name == "obj_cpt_scp_poisongas" then return S.profiles.corrosion035 end
    local suffix = name:match("^npc_cpt_scp_(.+)$") or name:match("^npc_cpt_scpunity_(.+)$") or name:match("^npc_cpt_scpiso_(.+)$")
    if not suffix then return end
    if suffix == "049" then return S.profiles.cardiac end
    if suffix:match("^049[_%-]2") then return S.profiles.slash end
    local number = tonumber(suffix:match("^(%d+)"))
    return S.profiles[groups[number]]
end

function S.Patient(entity)
    return IsValid(entity) and entity:IsPlayer() and entity:GetCharacter() and entity
end

function S.CanAffect(patient)
    return S.Patient(patient) and patient:Alive() and not patient:InCriticalState() and
        not patient:HasGodMode() and not (ix.SCPCompat and ix.SCPCompat.Controlled(patient))
end

function S.AddCondition(patient, id, hitgroup)
    local health = patient:GetCharacter():Health()
    for _, diff in health:GetHediffs() do if diff.uniqueID == id then return false end end
    local def = S.conditions[id]
    health:AddHediff(id, hitgroup or HITGROUP_CHEST, {severity=def.progression and .1 or 1})
    if id == "scp_neck" then
        patient:ChatPrint("SCP-173 ударил вас в шею, но не смог свернуть её до конца. Вы парализованы, но остаётесь в сознании и всё видите.")
    end
    patient:Notify(def.name .. ". " .. S.CareText(def))
    return true
end

function S.UpdatePatient(patient)
    local health = patient:GetCharacter():Health()
    health:OnUpdateDiffs()
    if health:GetBleedRate() > 0 and not health.bloodloss then
        health:AddHediff("bleeding", 0)
        health.bloodloss = true
    end
    if S.BlocksRecovery(health) or health:GetPartHealth(2) <= 0 or health:GetPartHealth(3) <= 0 or health:GetConsciousness() <= .3 then
        if not patient:InCriticalState() then patient:SetCriticalState(true) end
    end
end

function S.Expose(patient, id, hitgroup)
    if not S.CanAffect(patient) then return false end
    if patient.SCP_Has714 == true and (id == "scp_infection" or id == "scp_cardiac" or id == "scp_airway") then return false end
    local added = S.AddCondition(patient, id, hitgroup)
    if added then S.UpdatePatient(patient) end
    return added
end

local bodyHits = {HITGROUP_CHEST, HITGROUP_CHEST, HITGROUP_STOMACH, HITGROUP_LEFTARM,
    HITGROUP_RIGHTARM, HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG}
function S.HitGroup(patient, source, profile)
    if profile.hitgroup then return profile.hitgroup end
    -- CPT melee does a sphere query, so LastHitGroup contains a stale bullet hit.
    -- For a possessor, use the server trace of the existing validated aim point.
    if IsValid(source) and source.IsPossessed and source.GetPossessorAimPos then
        local aim = source:GetPossessorAimPos()
        if isvector(aim) then
            local tr = util.TraceLine({start=source:GetPos()+source:OBBCenter(), endpos=aim,
                filter={source, source:GetPossessor()}, mask=MASK_SHOT})
            if (tr.Entity == patient or (IsValid(tr.Entity) and tr.Entity.ixPlayer == patient)) and
                tr.HitGroup and tr.HitGroup >= HITGROUP_HEAD and tr.HitGroup <= HITGROUP_RIGHTLEG then return tr.HitGroup end
        end
    end
    return bodyHits[math.random(#bodyHits)]
end

function S.Damage(patient, damage, applyWound)
    if not S.Patient(patient) then return false end
    local source, inflictor = damage:GetAttacker(), damage:GetInflictor()
    local profile = S.Profile(inflictor) or S.Profile(source)
    if not profile then return false end
    local amount = damage:GetDamage()
    if not S.CanAffect(patient) or amount <= 0 then
        damage:SetDamage(0); damage:SetDamageForce(vector_origin)
        return true
    end
    if patient.SCP_Has714 == true and (profile == S.profiles.cardiac or profile == S.profiles.infection or profile == S.profiles.airway) then
        damage:SetDamage(0)
        return true
    end
    local health = patient:GetCharacter():Health()
    local hitgroup = S.HitGroup(patient, source, profile)
    local part = health:GetParts(hitgroup)
    local before = health:GetPartHealth(part.id)
    amount = math.min(amount, profile.cap)
    if profile.class and amount > 0 then
        applyWound(health, hitgroup, {attacker=source, weapon={}, amount=profile.spread and amount*.5 or amount, class=profile.class})
        if profile.spread then
            local other = hitgroup == HITGROUP_CHEST and HITGROUP_STOMACH or HITGROUP_CHEST
            applyWound(health, other, {attacker=source, weapon={}, amount=amount*.5, class=profile.class})
        end
    end
    local wounded = health:GetPartHealth(part.id) < before
    if profile.condition and (not profile.class or wounded) then
        S.AddCondition(patient, profile.condition, profile.hitgroup or HITGROUP_CHEST)
    end
    if profile.fracture and wounded and part.canFracture then health:AddHediff("fracture", hitgroup, {severity=5}) end
    -- A near-destroyed bitten limb may be severed; full armour absorption cannot
    -- amputate it. Respect the existing one-missing-limb character system.
    if profile.amputate and wounded and ix.Amputation and ix.Amputation.byHitgroup[hitgroup] and
        health:GetPartHealth(part.id) <= health:GetMaxHealth(part.id)*.2 and
        ix.Amputation.Amputate(patient, ix.Amputation.byHitgroup[hitgroup]) then
        health:AddHediff("cut", hitgroup, {severity=15}) -- Treatable stump bleeding; no limb regrowth from a kit.
    end
    if wounded then
        local effect = EffectData()
        effect:SetOrigin(damage:GetDamagePosition()); effect:SetEntity(patient)
        util.Effect("BloodImpact", effect)
    end
    S.UpdatePatient(patient)
    hook.Run("CharacterBodyDamaged", patient, damage)
    damage:SetDamage(0) -- All injury is already in the character health record.
    damage:SetDamageForce(vector_origin)
    return true
end

-- Suppress the addon's separate player infection/death timers. NPC victims keep
-- the native behaviour; Helix victims were already processed by Damage above.
function S.FilterVictims(self, victims, ...)
    local native = {}
    for _, victim in ipairs(victims or {}) do if not S.Patient(victim) then native[#native+1] = victim end end
    return self:ixSCPMedicalHit(native, ...)
end

function S.Infect(self, victim, ...)
    if S.Patient(victim) then return S.Expose(victim, "scp_infection", HITGROUP_CHEST) end
    return self:ixSCPMedicalInfect(victim, ...)
end

function S.Grab106(self, event, argument, ...)
    if event == "grab" then
        local victim = argument == "pull" and self:GetEnemy() or self.GrabbedVictim
        if S.Patient(victim) then
            if argument == "pull" and victim:GetPos():DistToSqr(self:GetPos()) <= 50*50 then
                self.GrabbedVictim = victim
                -- Do not move the human below the floor before medical knockdown.
                S.Expose(victim, "scp_corrosion", HITGROUP_CHEST)
                if S.CanAffect(victim) then victim:SetCriticalState(true) end
            end
            if argument == "kill" then self.GrabbedVictim = NULL end
            return true
        end
        -- Native code dereferences GrabbedVictim without an IsValid guard.
        if argument == "kill" and not IsValid(victim) then return true end
    end
    return self:ixSCPMedicalEvents(event, argument, ...)
end

function S.Retaliate303(self, dmg, info, hitbox)
    local victim = dmg:GetAttacker()
    if S.Patient(victim) then
        if math.random(1,5) == 1 then S.Expose(victim, "scp_shock", HITGROUP_HEAD) end
        return
    end
    return self:ixSCPMedicalPain(dmg, info, hitbox)
end

local function wrap(npc, method, saved, replacement)
    if npc[method] == replacement then return end
    if not npc[saved] and isfunction(npc[method]) then npc[saved] = npc[method] end
    if npc[saved] then npc[method] = replacement end
end
function S.Patch(npc)
    local name = npc:GetClass()
    if name == "npc_cpt_scp_008_1" or name == "npc_cpt_scp_1048" or name == "npc_cpt_scp_049" or
        name == "npc_cpt_scp_106" or name == "npc_cpt_scpunity_106" then
        wrap(npc, "OnHitEntity", "ixSCPMedicalHit", S.FilterVictims)
    end
    if name == "npc_cpt_scp_008" then wrap(npc, "Infect", "ixSCPMedicalInfect", S.Infect) end
    if name == "npc_cpt_scp_106" then wrap(npc, "HandleEvents", "ixSCPMedicalEvents", S.Grab106) end
    if name == "npc_cpt_scpiso_303" then wrap(npc, "OnTakePain", "ixSCPMedicalPain", S.Retaliate303) end
end

function S.Install()
    -- Poison projectiles otherwise create anonymous repeating damage timers.
    -- Replace that effect only for Helix patients of these SCPs.
    if util.AddAttackEffect and not S.originalAttackEffect then
        S.originalAttackEffect = util.AddAttackEffect
        util.AddAttackEffect = function(attacker, victim, amount, effect, ...)
            local profile = S.Profile(attacker)
            if S.Patient(victim) and profile and profile.class == "acid" and effect == DMG_POI then
                return S.Expose(victim, profile.condition, HITGROUP_CHEST)
            end
            return S.originalAttackEffect(attacker, victim, amount, effect, ...)
        end
    end
end
