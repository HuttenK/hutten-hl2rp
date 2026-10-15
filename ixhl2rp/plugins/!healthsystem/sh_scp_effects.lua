-- Persistent, networked conditions use the same character health record as wounds.
ix.SCPMedicine = ix.SCPMedicine or {}
local S = ix.SCPMedicine
S.conditions = {
    scp_cardiac = {name="Остановка сердца (SCP-049)", treatment="Адреналин", cures={epinephrine=true}, critical=true},
    scp_neck = {name="Паралич после травмы шеи (SCP-173)", cures={}, incurable=true, critical=true, paralysis=true},
    scp_infection = {name="Инфекция SCP-008", treatment="Сыворотка против SCP-008", cures={scp_008_serum=true}, progression=.04},
    scp_airway = {name="Обструкция дыхательных путей (SCP-1048)", treatment="Хирургический набор CMS", cures={eft_surgery=true}, progression=.15},
    -- Retain the saved ID for 106. Older saves did not record the corrosion's
    -- source; new 035 exposures have their own independently curable condition.
    scp_corrosion = {name="Разъедание тканей (SCP-106)", cures={}, incurable=true, progression=.06, slowItem="eft_etg"},
    scp_corrosion_035 = {name="Разъедание тканей (SCP-035)", treatment="Нейтрализатор коррозии", cures={scp_neutralizer=true}, progression=.06},
    scp_fatigue = {name="Аномальное истощение (SCP-966)", treatment="Стимулятор L1", cures={eft_l1=true}, movement=.6},
    scp_shock = {name="Аномальный нервный шок", treatment="Стимулятор L1", cures={eft_l1=true}, progression=.08}
}

function S.BlocksRecovery(health)
    for _, diff in health:GetHediffs() do
        local def = S.conditions[diff.uniqueID]
        if def and diff:GetSeverity() > 0 and (def.critical or diff:GetSeverity() >= 1) then
            return true, def.treatment, def.incurable, def.name
        end
    end
    return false
end

function S.CareText(def)
    if def.slowItem then return "Неизлечимо. eTG-change замедляет прогрессирование на 50% на 60 секунд." end
    if def.incurable then return "Лечение пока недоступно. Паралич необратим." end
    return "Лечение: " .. def.treatment .. "."
end

function S.ProgressionFactor(health, id, now)
    if id ~= "scp_corrosion" then return 1 end
    now = now or os.time()
    for _, diff in health:GetHediffs() do
        if diff.uniqueID == "scp_corrosion_support" and diff:GetSeverity() > 0 and
            (diff.tended_time or 0) > 0 and now < (diff.tended_start or 0) + diff.tended_time then return .5 end
    end
    return 1
end

function S.IsParalyzed(health)
    for _, diff in health:GetHediffs() do
        local def = S.conditions[diff.uniqueID]
        if def and def.paralysis and diff:GetSeverity() > 0 then return true end
    end
    return false
end

-- Motor control and consciousness are separate: 173 cannot darken the victim's
-- vision or let adrenaline restore movement. Neck paralysis has no cure.
function S.ForcesUnconscious(health)
    for _, diff in health:GetHediffs() do
        local def = S.conditions[diff.uniqueID]
        if def and not def.paralysis and diff:GetSeverity() > 0 and
            (def.critical or diff:GetSeverity() >= 1) then return true end
    end
    return false
end

function S.MovementFactor(health)
    local factor = 1
    for _, diff in health:GetHediffs() do
        local def = S.conditions[diff.uniqueID]
        if def and def.movement and diff:GetSeverity() > 0 then factor = math.min(factor, def.movement) end
    end
    return factor
end

-- Limb 0 is the normal whole-patient item action. In the examination menu,
-- surgical conditions are treated at their actual body part.
function S.TreatmentMatches(health, item, hitgroup)
    local matches = {}
    for _, diff in health:GetHediffs() do
        local def = S.conditions[diff.uniqueID]
        local part = health.body.parts[diff.part]
        local treats = def and ((not def.incurable and def.cures[item.uniqueID]) or
            (def.slowItem == item.uniqueID and diff:GetSeverity() < 1))
        if treats and diff:GetSeverity() > 0 and
            (not hitgroup or hitgroup == 0 or (part and part.hitgroup == hitgroup)) then
            matches[#matches + 1] = diff
        end
    end
    return matches
end

function S.Treat(health, item, hitgroup)
    local matches = S.TreatmentMatches(health, item, hitgroup)
    for _, diff in ipairs(matches) do
        local def = S.conditions[diff.uniqueID]
        if def.slowItem == item.uniqueID then
            local previous = {}
            for _, effect in health:GetHediffs() do
                if effect.uniqueID == "scp_corrosion_support" then previous[#previous + 1] = effect.id end
            end
            for _, id in ipairs(previous) do health:RemoveHediffByID(id) end
            -- Refresh a bounded duration, never stack strength or remove corrosion.
            health:AddHediff("scp_corrosion_support", 0, {severity=1, tended_start=os.time(), tended_time=60})
        else
            health:RemoveHediffByID(diff.id)
        end
    end
    return #matches
end

-- Sort IDs: Helix assigns numeric hediff network IDs in registration order.
local ids = {}
for id in pairs(S.conditions) do ids[#ids + 1] = id end
table.sort(ids)
for _, id in ipairs(ids) do
    local definition = S.conditions[id]
    local template = ix.Hediffs:Get(id) or ix.Hediffs:New(id, "Hediff_Disease")
    template.name, template.max = definition.name, 1
    template.color = Color(230, 85, 105)
    function template:Stage()
        local def = S.conditions[self.uniqueID]
        return self.name .. (def.progression and " · " .. math.Round(self:GetSeverity() * 100) .. "%" or "") ..
            "\n" .. S.CareText(def)
    end
    if SERVER then
        function template:OnTick(health)
            local client = health:GetPlayer()
            if not IsValid(client) or not client:Alive() or client:GetCharacter() ~= health.character then return false end
            if ix.SCPCompat and ix.SCPCompat.Controlled(client) then return false end
            local def = S.conditions[self.uniqueID]
            -- Health ticks every four seconds. Progress pauses while offline;
            -- the saved severity survives reconnects and cannot execute patients.
            if def.progression and self.severity < 1 then
                self:SetSeverity(math.min(1, self.severity + def.progression * S.ProgressionFactor(health, self.uniqueID)))
                health:OnUpdateDiffs()
                if ix.Medicine then ix.Medicine.Sync(health) end
            end
            if S.BlocksRecovery(health) and not client:InCriticalState() then client:SetCriticalState(true) end
            return false -- Synced above through the existing hediff.update codec.
        end
    end
end

local burn = ix.Hediffs:Get("scp_burn") or ix.Hediffs:New("scp_burn", "Hediff_Injury")
burn.name = "Термический ожог"
burn.bleedRate, burn.painPerSeverity = 0, .0125
burn.color = Color(235, 125, 70)

-- Reuse the medical status save/network codec, including its absolute expiry.
local support = ix.Hediffs:Get("scp_corrosion_support") or ix.Hediffs:New("scp_corrosion_support", "Hediff_Medical")
support.name = "eTG-change: замедление коррозии"
support.color = Color(110, 190, 145)
function support:GetPainFactor() return 1 end
function support:Stage()
    return self.name .. " · " .. math.max(0, (self.tended_start or 0) + (self.tended_time or 0) - os.time()) .. " сек"
end
