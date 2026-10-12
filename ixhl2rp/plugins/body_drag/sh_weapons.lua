local D = ix.BodyDrag
local guarded = {}
local methods = {"Reload", "CanReload"}

function D.IsReloading(weapon)
    if not IsValid(weapon) then return false end
    if weapon.GetReloading and weapon:GetReloading() then return true end
    return weapon.GetInternalVariable and weapon:GetInternalVariable("m_bInReload") == true
end

function D.GuardWeapon(weapon)
    if not IsValid(weapon) then return end
    local entry = guarded[weapon]
    if not entry then entry = {}; guarded[weapon] = entry end
    for _, name in ipairs(methods) do
        local original = weapon[name]
        if isfunction(original) and (not entry[name] or original ~= entry[name].wrapper) then
            local patch = {original = original}
            patch.wrapper = function(self, ...)
                if D.Body(self:GetOwner()) then return false end
                return original(self, ...)
            end
            entry[name] = patch
            weapon[name] = patch.wrapper
        end
    end
    -- Native HL2 weapons reload in C++; they have no Lua Reload to intercept.
    -- Their empty-magazine idle auto-reload requires the attack timer to expire.
    if not weapon:IsScripted() then
        for _, mode in ipairs({"Primary", "Secondary"}) do
            local clip = mode == "Primary" and weapon:Clip1() or weapon:Clip2()
            if clip == 0 then
                local getter, setter = "GetNext" .. mode .. "Fire", "SetNext" .. mode .. "Fire"
                if not entry[mode] then entry[mode] = {original = weapon[getter](weapon)} end
                local stamp = CurTime() + 0.2
                if weapon[getter](weapon) < stamp then
                    weapon[setter](weapon, stamp)
                    entry[mode].written = stamp
                end
            end
        end
    end
end

function D.ProtectWeapons(client)
    for _, weapon in ipairs(client:GetWeapons()) do D.GuardWeapon(weapon) end
end

local function Restore(weapon, entry)
    if not IsValid(weapon) then return end
    for _, name in ipairs(methods) do
        local patch = entry[name]
        if patch and weapon[name] == patch.wrapper then weapon[name] = patch.original end
    end
    for _, mode in ipairs({"Primary", "Secondary"}) do
        local patch = entry[mode]
        local getter, setter = "GetNext" .. mode .. "Fire", "SetNext" .. mode .. "Fire"
        if patch and weapon[getter](weapon) == patch.written then
            weapon[setter](weapon, patch.original)
        end
    end
end

function D.ReleaseWeapons(client, all)
    for weapon, entry in pairs(guarded) do
        if all or not IsValid(weapon) or not D.Body(weapon:GetOwner()) or weapon:GetOwner() == client then
            Restore(weapon, entry)
            guarded[weapon] = nil
        end
    end
end

hook.Add("Think", "ixBodyDragWeaponCleanup", function() D.ReleaseWeapons() end)
hook.Add("WeaponEquip", "ixBodyDragWeapon", function(weapon, client)
    if D.Body(client) then D.GuardWeapon(weapon) end
end)
