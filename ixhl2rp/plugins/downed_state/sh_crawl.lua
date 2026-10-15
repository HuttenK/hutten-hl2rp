local D = ix.Downed
D.FallDuration = 5
D.CrawlDuration = 25
D.CrawlSpeed = 17.5
D.CrawlVersion = "2026-10-14-fall"

function D.RescueWindow(p)
    return D.Active(p) and p:GetNetVar("criticalCrawlUntil", 0) > 0
end

function D.Falling(p)
    -- Keep the phase until the server has safely handed off the actual body.
    return D.RescueWindow(p) and p:GetNetVar("criticalFallUntil", 0) > 0
end

function D.CrawlWindow(p)
    return D.RescueWindow(p) and not D.Falling(p)
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
        or D.Falling(p) or p:GetLocalVar("knocked", false) or IsValid(p.ixRagdoll)
        or p:GetLocalVar("ragdoll", 0) ~= 0 then return false end
    if D.CrawlWindow(p) then return true end
    -- Missing assets must never disable the injury state or its movement rules.
    return ix.Amputation and ix.Amputation.HasKind(p:GetCharacter(), "leg") or false
end

function D.RestoreCrawl(p)
    if not p.ixCrawlView then return end
    if p.ixCrawlStandingView then p:SetViewOffset(p.ixCrawlStandingView) end
    p:SetViewOffsetDucked(p.ixCrawlView)
    p:SetCrouchedWalkSpeed(p.ixCrawlSpeed)
    p.ixCrawlView, p.ixCrawlStandingView, p.ixCrawlSpeed = nil, nil, nil
end

function D.CrawlEyeOffset(p)
    return Vector(0, 0, 18 * (p.GetModelScale and p:GetModelScale() or 1))
end

function D.CrawlMove(p, mv)
    if not D.Crawling(p) then D.RestoreCrawl(p) return false end
    if not p.ixCrawlView then
        p.ixCrawlView = p:GetViewOffsetDucked()
        p.ixCrawlSpeed = p:GetCrouchedWalkSpeed()
    end
    p.ixCrawlStandingView = p.ixCrawlStandingView or p:GetViewOffset()
    -- Forced duck commands do not guarantee the local camera has completed its
    -- crouch transition after OBSERVER/ragdoll mode. Both engine eye offsets
    -- must agree with the prone view, including interaction traces.
    local eyeOffset = D.CrawlEyeOffset(p)
    p:SetViewOffset(eyeOffset)
    p:SetViewOffsetDucked(eyeOffset)
    p:SetCrouchedWalkSpeed(1)
    mv:SetButtons(bit.bor(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP + IN_SPEED + IN_ATTACK + IN_ATTACK2)), IN_DUCK))
    mv:SetMaxClientSpeed(D.CrawlSpeed); mv:SetMaxSpeed(D.CrawlSpeed)
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

if SERVER then
    concommand.Add("ix_crawl_status", function(p)
        if not IsValid(p) then return end
        p:PrintMessage(HUD_PRINTCONSOLE, "[Crawl " .. D.CrawlVersion .. "] " .. p:GetModel()
            .. " | idle=" .. tostring(D.CrawlSequence(p, false))
            .. " | moving=" .. tostring(D.CrawlSequence(p, true))
            .. " | active=" .. tostring(D.Crawling(p))
            .. " | falling=" .. tostring(D.Falling(p))
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
        if not character then return end
        local now, duration = os.time(), D.FallDuration + D.CrawlDuration
        -- Both absolute deadlines survive reconnects without granting extra time.
        -- Older saves without a fall deadline resume their existing crawl window.
        local deadline = persisted and character:GetData("criticalCrawlDeadline", 0) or now + duration
        local fallDeadline = persisted and character:GetData("criticalFallDeadline", 0) or now + D.FallDuration
        local remaining = math.Clamp((tonumber(deadline) or 0) - now, 0, duration)
        local fallRemaining = math.Clamp((tonumber(fallDeadline) or 0) - now, 0, math.min(D.FallDuration, remaining))
        if remaining <= 0 then return end
        character:SetData("criticalCrawlDeadline", deadline)
        character:SetData("criticalFallDeadline", fallDeadline)
        p:SetNetVar("criticalCrawlUntil", CurTime() + remaining)
        p:SetNetVar("criticalFallUntil", fallRemaining > 0 and CurTime() + fallRemaining or nil)
        p:SetLocalVar("knocked", false)
        if p:InVehicle() then p:ExitVehicle() end
    end

    function D.EndRescueWindow(p)
        p:SetNetVar("criticalFallUntil", nil)
        p:SetNetVar("criticalCrawlUntil", nil)
        local character = p:GetCharacter()
        if character then
            character:SetData("criticalFallDeadline", 0)
            character:SetData("criticalCrawlDeadline", 0)
        end
        D.RestoreCrawl(p)
        if D.Active(p) then p:SetLocalVar("knocked", true) end
        D.StopFallAnimation(p.ixRagdoll)
    end

    function D.StopFallAnimation(body)
        if not IsValid(body) then return end
        body.BD_AnimationInterrupted = true
        if IsValid(body.AnimModule) then body.AnimModule:Remove() end
    end

    function D.FinishFall(p)
        -- Systemic collapse cannot become conscious crawling while untreated.
        -- Paralysis normally skips this window; also handle existing fall saves.
        if ix.SCPMedicine and ix.SCPMedicine.BlocksRecovery(p:GetCharacter():Health()) then
            D.EndRescueWindow(p)
            p:SetCriticalState(true)
            return
        end
        local body = p.ixRagdoll
        if not IsValid(body) then D.EndRescueWindow(p) return end
        D.StopFallAnimation(body)
        if IsValid(body.ixBodyDragger) or IsValid(body.ixHeldOwner) or body:IsPlayerHolding()
            or IsValid(body:GetNW2Entity("ixPatientCart")) then
            D.EndRescueWindow(p)
            return
        end
        -- Use the settled body's location, never the pre-injury standing point.
        -- Wait for ground/clearance if the casualty is still falling or obstructed.
        local origin = body:GetPos()
        local filter = {p, body, body.AnimModule}
        local ground = util.TraceLine({start = origin + Vector(0, 0, 4), endpos = origin - Vector(0, 0, 96),
            filter = filter, mask = MASK_PLAYERSOLID})
        if ground.StartSolid or not ground.Hit or ground.HitNormal.z < 0.5 then return end
        local position = ground.HitPos + Vector(0, 0, 1)
        local mins, maxs = p:GetHullDuck()
        local clear = util.TraceHull({start = position, endpos = position, mins = mins, maxs = maxs,
            filter = filter, mask = MASK_PLAYERSOLID})
        if clear.StartSolid or clear.Hit then return end

        p:SetNetVar("criticalFallUntil", nil)
        p:GetCharacter():SetData("criticalFallDeadline", 0)
        p:SetLocalVar("knocked", false)
        -- The normal fallover exit restores weapons but also clears critical
        -- health. Guard only this synchronous handoff; medical recovery is normal.
        p.ixCriticalCrawlHandoff = true
        body.ixNoReset = true
        body.ixLastVelocity = vector_origin
        p:SetPos(position)
        p:AddFlags(FL_DUCKING)
        p:SetRagdolled(false)
        p.ixCriticalCrawlHandoff = nil
        p:SetLocalVelocity(vector_origin)
        p:AnimRestartMainSequence()
    end

    function D.CrawlTick(p)
        if not IsValid(p) then return end
        if prone and prone.Exit and p.IsProne and p:IsProne() then
            D.RestoreCrawl(p)
            prone.Exit(p)
        end
        if D.RescueWindow(p) and CurTime() >= p:GetNetVar("criticalCrawlUntil", 0) then
            D.EndRescueWindow(p)
            p:SetCriticalState(true)
        elseif D.Falling(p) and CurTime() >= p:GetNetVar("criticalFallUntil", 0) then
            D.FinishFall(p)
        end
        if D.Crawling(p) then
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
        if D.RescueWindow(p) or D.Crawling(p) then return false end
    end)
end
