local PLUGIN = PLUGIN
PLUGIN.disableTime = 30
PLUGIN.affected = PLUGIN.affected or setmetatable({}, {__mode = "k"})
local handlers = {}
PLUGIN.handlers = handlers

handlers.ix_combinelock = function(ent)
    if not ent:GetLocked() then return false, "Замок уже открыт." end
    ent:SetLocked(false)
    PLUGIN.affected[ent] = {expires = CurTime() + PLUGIN.disableTime, revision = ent.ixLockRevision or 0}
    return true, "Замок временно разблокирован."
end

local function field(ent)
    if ix.DevicePower.IsDisabled(ent) or (ent.GetBroken and ent:GetBroken()) then
        return false, "Поле уже отключено."
    end
    if ent:GetClass() == "ix_forcefield" and not ent.on then return false, "Поле уже отключено." end
    if ent:GetClass() == "ent_cmb_forcefield" and ent:GetMode() == 3 then return false, "Поле уже отключено." end
    ent.ixHackedUntil = CurTime() + PLUGIN.disableTime
    PLUGIN.affected[ent] = {expires = ent.ixHackedUntil}
    ix.DevicePower.Refresh(ent)
    return true, "Поле перегружено на 30 секунд."
end
handlers.ix_forcefield = field
handlers.ent_cmb_forcefield = field

handlers.ix_contrabandscanner = function(ent)
    if ix.DevicePower.IsDisabled(ent) then return false, "Сканер уже отключён." end
    ent.ixHackedUntil = CurTime() + PLUGIN.disableTime
    PLUGIN.affected[ent] = {expires = ent.ixHackedUntil}
    ent:SetAlarming(false)
    ent:SetDisabled(true)
    return true, "Сканер отключён на 30 секунд."
end

handlers.combine_mine = function(ent)
    ent:Fire("Disarm", "", 0)
    ent:Fire("Disable", "", 0)
    ent:Remove()
    return true, "Мина обезврежена."
end

-- Resolve on demand so reload order cannot lose fusebox support.
handlers.ix_blackout_fusebox = function(ent, client)
    local blackout = ix.plugin.list.blackout
    if not blackout or blackout.unloading then return false end
    return blackout:TryBreakEMP(client, ent)
end

function PLUGIN:IsHackable(ent)
    if not IsValid(ent) then return false end
    if handlers[ent:GetClass()] then return true end
    return ent.IsDoor and ent:IsDoor() and IsValid(ent.ixLock) or false
end

function PLUGIN:HackTarget(ent, client)
    if not IsValid(ent) or not IsValid(client) or not client:Alive() or not client:GetCharacter() then return false end
    if ent.IsDoor and ent:IsDoor() and IsValid(ent.ixLock) then ent = ent.ixLock end
    local handler = handlers[ent:GetClass()]
    if not handler then return false end
    local origin = ent:WorldSpaceCenter()
    local success, message = handler(ent, client)
    if message then client:Notify(message) end
    if not success then return false end
    local fx = EffectData()
    fx:SetOrigin(origin)
    fx:SetNormal(VectorRand():GetNormalized())
    fx:SetMagnitude(8); fx:SetScale(1); fx:SetRadius(16)
    util.Effect("cball_bounce", fx)
    return true
end

function PLUGIN:FindHackable(client, range)
    local tr = client:GetEyeTrace()
    local origin = client:GetShootPos()
    if self:IsHackable(tr.Entity) and tr.HitPos:Distance(origin) <= range then return tr.Entity end
    local aim = client:GetAimVector()
    local best, score
    for class in pairs(handlers) do
        for _, ent in ipairs(ents.FindByClass(class)) do
            local point = ent.GetEmpAimPos and ent:GetEmpAimPos() or ent:WorldSpaceCenter()
            local delta = point - origin
            local dot = aim:Dot(delta:GetNormalized())
            if delta:Length() <= range and dot >= 0.95 and (not score or dot > score) then
                local sight = util.TraceLine({start = origin, endpos = point, filter = client, mask = MASK_SOLID})
                if not sight.Hit or sight.Entity == ent then best, score = ent, dot end
            end
        end
    end
    return best
end

function PLUGIN:Restore(ent, state)
    if not IsValid(ent) then return end
    if state.revision ~= nil then
        if (ent.ixLockRevision or 0) == state.revision and not ent:GetLocked() then ent:SetLocked(true) end
    else
        ent.ixHackedUntil = nil
        ix.DevicePower.Refresh(ent)
    end
end

timer.Create("ixEMPExpiry", 0.2, 0, function()
    for ent, state in pairs(PLUGIN.affected) do
        if not IsValid(ent) or CurTime() >= state.expires then
            PLUGIN:Restore(ent, state)
            PLUGIN.affected[ent] = nil
        end
    end
end)

function PLUGIN:OnUnload()
    timer.Remove("ixEMPExpiry")
    for ent, state in pairs(self.affected) do self:Restore(ent, state) end
    self.affected = {}
end
