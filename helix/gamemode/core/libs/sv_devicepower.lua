-- One saved operating state for all temporary power inhibitors.
ix.DevicePower = ix.DevicePower or {}
local P = ix.DevicePower
P.states = P.states or setmetatable({}, {__mode = "k"})

function P.IsBlackedOut(ent)
    if ix.Facility and ix.Facility.EntityBackup(ent) then return false end
    local blackout = ix.plugin.list.blackout
    return blackout and not blackout.unloading and blackout.IsPosBlackedOut
        and blackout:IsPosBlackedOut(ent:GetPos()) or false
end

function P.IsDisabled(ent)
    return P.IsBlackedOut(ent) or (ent.ixHackedUntil or 0) > CurTime()
end

function P.Refresh(ent)
    if not IsValid(ent) then return end
    local class = ent:GetClass()
    if class ~= "ix_forcefield" and class ~= "ent_cmb_forcefield" then return end
    local disabled = P.IsDisabled(ent)
    local state = P.states[ent]
    if disabled and not state then
        state = {on = ent.on, mode = class == "ent_cmb_forcefield" and ent:GetMode() or ent:GetDTInt(0)}
        P.states[ent] = state
    end
    if not state then return end
    local broken = ent.GetBroken and ent:GetBroken()
    P.applying = true
    if class == "ix_forcefield" then
        ent.on = not disabled and state.on or false
        ent:SetSkin(ent.on and 0 or 1)
        if IsValid(ent.post) then ent.post:SetSkin(ent.on and 0 or 1) end
        ent:SetCollisionGroup(ent.on and COLLISION_GROUP_NONE or COLLISION_GROUP_WORLD)
        ent:SetDTInt(0, disabled and 3 or state.mode)
    elseif not broken then
        local target = disabled and 3 or state.mode
        if ent:GetMode() ~= target then ent:SetForcefield(target) end
    end
    P.applying = false
    if not disabled then P.states[ent] = nil end
end

function P.RefreshAll()
    for _, class in ipairs({"ix_forcefield", "ent_cmb_forcefield"}) do
        for _, ent in ipairs(ents.FindByClass(class)) do P.Refresh(ent) end
    end
end

-- Expiry, newly spawned fields and moved devices are reconciled as well.
timer.Create("ixDevicePower", 0.25, 0, P.RefreshAll)
