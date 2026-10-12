local D = ix.Downed
D.CrawlDuration = 30
D.CrawlVersion = "2026-09-29-hl2"

function D.CrawlWindow(p)
    return D.Active(p) and p:GetNetVar("criticalCrawlUntil", 0) > 0
end

function D.CrawlSequence(p, moving)
    -- Cellar and the stock-HL2 Prone Mod use different sequence families.
    for _, name in ipairs(moving and {"pwalk_all", "prone_walkpassive"}
        or {"pidle_normal", "prone_passive"}) do
        local sequence = p:LookupSequence(name)
        if sequence and sequence >= 0 then return sequence end
    end
end

function D.Crawling(p)
    if not IsValid(p) or not p:Alive() or not p:GetCharacter() or p:InVehicle()
        or p:GetLocalVar("knocked", false) or IsValid(p.ixRagdoll) then return false end
    if D.CrawlWindow(p) then return true end
    -- Missing assets must never disable the injury state or its movement rules.
    return ix.Amputation and ix.Amputation.HasKind(p:GetCharacter(), "leg") or false
end

function D.RestoreCrawl(p)
    if not p.ixCrawlView then return end
    p:SetViewOffsetDucked(p.ixCrawlView)
    p:SetCrouchedWalkSpeed(p.ixCrawlSpeed)
    p.ixCrawlView, p.ixCrawlSpeed = nil, nil
end

function D.CrawlMove(p, mv)
    if not D.Crawling(p) then D.RestoreCrawl(p) return false end
    if not p.ixCrawlView then
        p.ixCrawlView = p:GetViewOffsetDucked()
        p.ixCrawlSpeed = p:GetCrouchedWalkSpeed()
    end
    p:SetViewOffsetDucked(Vector(0, 0, 18))
    p:SetCrouchedWalkSpeed(1)
    mv:SetButtons(bit.bor(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP + IN_SPEED + IN_ATTACK + IN_ATTACK2)), IN_DUCK))
    mv:SetMaxClientSpeed(35); mv:SetMaxSpeed(35)
    return true
end

function D.CrawlCommand(p, cmd)
    if not D.Crawling(p) then return end
    cmd:RemoveKey(IN_JUMP + IN_SPEED + IN_ATTACK + IN_ATTACK2 + IN_RELOAD)
    cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_DUCK))
end

function D.CrawlActivity(p, velocity)
    if not D.Crawling(p) then return end
    local sequence = D.CrawlSequence(p, velocity:Length2DSqr() > 4)
    if sequence then
        p:SetPoseParameter("move_yaw", math.NormalizeAngle(velocity:Angle().y - p:EyeAngles().y))
        return sequence
    end
end

PLUGIN["prone.CanEnter"] = function(_, p)
    if D.Crawling(p) or D.Active(p) or IsValid(p.ixRagdoll) then return false end
end

if SERVER then
    concommand.Add("ix_crawl_status", function(p)
        if not IsValid(p) then return end
        p:PrintMessage(HUD_PRINTCONSOLE, "[Crawl " .. D.CrawlVersion .. "] " .. p:GetModel()
            .. " | idle=" .. tostring(D.CrawlSequence(p, false))
            .. " | moving=" .. tostring(D.CrawlSequence(p, true))
            .. " | active=" .. tostring(D.Crawling(p))
            .. " | critical=" .. tostring(D.Active(p))
            .. " | seconds=" .. tostring(math.max(0, p:GetNetVar("criticalCrawlUntil", 0) - CurTime()))
            .. " | missingLeg=" .. tostring(ix.Amputation and ix.Amputation.HasKind(p:GetCharacter(), "leg"))
            .. " | ragdoll=" .. tostring(IsValid(p.ixRagdoll)))
        if D.CrawlSequence(p, false) == nil or D.CrawlSequence(p, true) == nil then
            p:PrintMessage(HUD_PRINTCONSOLE, "[Crawl] Animation content missing: mount the combined ix_crawl_animation_content addon on server AND clients, then restart both.")
        end
    end)
    function D.BeginCrawl(p, persisted)
        local character = p:GetCharacter()
        if not character or IsValid(p.ixRagdoll) then return end
        -- Persist an absolute deadline; reselecting/reconnecting cannot reset it.
        local deadline = persisted and character:GetData("criticalCrawlDeadline", 0) or os.time() + D.CrawlDuration
        local remaining = math.Clamp((tonumber(deadline) or 0) - os.time(), 0, D.CrawlDuration)
        if remaining <= 0 then return end
        character:SetData("criticalCrawlDeadline", deadline)
        p:SetNetVar("criticalCrawlUntil", CurTime() + remaining)
        p:SetLocalVar("knocked", false)
        if p:InVehicle() then p:ExitVehicle() end
    end

    function D.CrawlTick(p)
        if not IsValid(p) then return end
        if D.CrawlWindow(p) and CurTime() >= p:GetNetVar("criticalCrawlUntil", 0) then
            p:SetNetVar("criticalCrawlUntil", nil)
            p:GetCharacter():SetData("criticalCrawlDeadline", 0)
            D.RestoreCrawl(p)
            p:SetCriticalState(true)
        end
        if D.Crawling(p) then
            -- Leave voluntary prone so its independent movement/animation hooks
            -- cannot compete with the forced casualty state.
            if prone and prone.Exit and p:IsProne() then
                D.RestoreCrawl(p)
                prone.Exit(p)
            end
            p:SetWepRaised(false)
            local weapon = p:GetActiveWeapon()
            if IsValid(weapon) and weapon:GetClass() ~= "ix_hands" and p:HasWeapon("ix_hands") then
                p:SelectWeapon("ix_hands")
            end
        else D.RestoreCrawl(p) end
    end
    timer.Create("ixCriticalCrawl", .1, 0, function()
        for _, p in ipairs(player.GetAll()) do D.CrawlTick(p) end
    end)
    hook.Add("PlayerSwitchWeapon", "ixCrawlHands", function(p, old, new)
        if D.Crawling(p) and IsValid(new) and new:GetClass() ~= "ix_hands" then return true end
    end)
    hook.Add("CanPlayerEnterVehicle", "ixCrawlVehicle", function(p)
        if D.Crawling(p) then return false end
    end)
end
