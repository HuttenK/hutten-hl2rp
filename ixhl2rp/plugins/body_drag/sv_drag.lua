local D = ix.BodyDrag
util.AddNetworkString("ixBodyDragAction")
util.AddNetworkString("ixBodyDragRaise")

function D.Stop(client)
    local state = D.states[client]
    D.states[client] = nil
    if IsValid(client) then
        client:SetNW2Entity("ixDraggedBody", NULL)
        client.ixDragRaiseStart, client.ixDragRaised = nil, nil
        client.ixDragReloadUntil = nil
    end
    D.ReleaseWeapons(client)
    if not state then return end
    local body = state.body
    if IsValid(body) then
        body.ixBodyDragger = nil
        body:SetNW2Entity("ixBodyDragger", NULL)
        body:SetCustomCollisionCheck(state.customCollision)
        body:CollisionRulesChanged()
        body:RemoveCallOnRemove("ixBodyDrag")
        for i = 0, body:GetPhysicsObjectCount() - 1 do
            local physics = body:GetPhysicsObjectNum(i)
            if IsValid(physics) then physics:Wake() end
        end
    end
end

function D.DropPatient(patient)
    for client, state in pairs(D.states) do
        if state.patient == patient or client == patient then D.Stop(client) end
    end
end

function D.Start(client, entity, handoff)
    if not D.CanTarget(client, entity) then return false end
    -- Optional server-only cart handoff. Network requests still obtain their
    -- own trace; proximity and obstruction are rechecked for the new grip.
    if handoff then
        if handoff.Entity ~= entity or not handoff.HitPos then return false end
        local line = util.TraceLine({start=client:GetShootPos(),endpos=handoff.HitPos,filter={client,entity},mask=MASK_SOLID})
        if line.Hit or line.StartSolid then return false end
    end
    local trace = handoff or util.TraceLine({start = client:GetShootPos(),
        endpos = client:GetShootPos() + client:GetAimVector() * D.RANGE, filter = client, mask = MASK_SOLID})
    local patient = D.Patient(entity)
    if trace.Entity ~= entity and trace.Entity ~= D.PatientBody(patient) then return false end
    for _, weapon in ipairs(client:GetWeapons()) do
        if D.IsReloading(weapon) then return false, "Сначала завершите перезарядку." end
    end
    local body = D.PatientBody(patient)
    if not body then
        -- End only the crawl window. Critical health/deadline remain intact.
        patient:SetNetVar("criticalCrawlUntil", nil)
        patient:GetCharacter():SetData("criticalCrawlDeadline", 0)
        if ix.Downed and ix.Downed.RestoreCrawl then ix.Downed.RestoreCrawl(patient) end
        patient:SetRagdolled(true)
        patient:SetLocalVar("knocked", true)
        body = D.PatientBody(patient)
        if not IsValid(body) then return false end
        body.ixGrace = nil
    end
    if IsValid(body.ixHeldOwner) or (body.IsPlayerHolding and body:IsPlayerHolding()) then return false end
    local index = trace.Entity == body and trace.PhysicsBone or 0
    local physics = body:GetPhysicsObjectNum(index)
    if not IsValid(physics) then return false end
    local bone = body:TranslatePhysBoneToBone(index)
    if not bone or bone < 0 then return false end
    local point = trace.Entity == body and trace.HitPos or physics:GetPos()
    if point:DistToSqr(client:GetShootPos()) > D.RANGE * D.RANGE then return false end
    local localPoint = physics:WorldToLocal(point)
    -- Grabbing during the initial fall cancels its automatic crawl handoff.
    -- The patient must stay in the rescuer's hand (or on a cart afterwards).
    if ix.Downed and ix.Downed.EndRescueWindow and ix.Downed.Active(patient) then
        ix.Downed.EndRescueWindow(patient)
    end
    local state = {body = body, patient = patient, character = client:GetCharacter(),
        physics = physics, offset = localPoint, index = index, lastPosition = client:GetPos(),
        yaw = (point - client:GetPos()):Angle().y,
        customCollision = body:GetCustomCollisionCheck()}
    D.states[client] = state
    body.ixBodyDragger = client
    body:SetNW2Entity("ixDragPatient", patient)
    body:SetNW2Int("ixDragBone", bone)
    local matrix = body:GetBoneMatrix(bone)
    local renderOffset = matrix and WorldToLocal(point, angle_zero, matrix:GetTranslation(), matrix:GetAngles()) or localPoint
    body:SetNW2Vector("ixDragOffset", renderOffset)
    body:SetNW2Entity("ixBodyDragger", client)
    client:SetNW2Entity("ixDraggedBody", body)
    body:SetCustomCollisionCheck(true)
    body:CollisionRulesChanged()
    body:CallOnRemove("ixBodyDrag", function() D.Stop(client) end)
    physics:Wake()
    D.ProtectWeapons(client)
    return true
end

function D.Step(client, state, delta)
    local body, patient, physics = state.body, state.patient, state.physics
    if not D.CanDrag(client) or client:GetCharacter() ~= state.character or not IsValid(body)
        or not IsValid(patient) or not patient:Alive() or D.PatientBody(patient) ~= body
        or not IsValid(physics) or body.ixBodyDragger ~= client then D.Stop(client) return end
    local point = physics:LocalToWorld(state.offset)
    if client:GetPos():DistToSqr(state.lastPosition) > 128 * 128
        or point:DistToSqr(client:GetPos()) > D.BREAK_DISTANCE * D.BREAK_DISTANCE then D.Stop(client) return end
    state.lastPosition = client:GetPos()
    state.yaw = D.TrailYaw(client:GetVelocity(), state.yaw, client:EyeAngles().y + 180, delta)
    local target, shoulder = D.GripTarget(client, state.yaw)
    local collision = util.TraceHull({start = shoulder, endpos = target,
        mins = Vector(-3, -3, -3), maxs = Vector(3, 3, 3), filter = {client, patient, body}, mask = MASK_SOLID})
    if collision.StartSolid then D.Stop(client) return end
    if collision.Hit then target = collision.HitPos + collision.HitNormal * 4 end
    local obstruction = util.TraceLine({start = target, endpos = point,
        filter = {client, patient, body}, mask = MASK_SOLID})
    if obstruction.Hit or target:DistToSqr(point) > 65 * 65 then
        state.stuckAt = state.stuckAt or CurTime()
        if CurTime() - state.stuckAt > 0.6 then D.Stop(client) return end
    else state.stuckAt = nil end
    -- Pull one physics bone only. The rest remains a colliding articulated body.
    -- Zero teleport distance forbids the controller from snapping through walls.
    physics:Wake()
    physics:ComputeShadowControl({pos = target - (point - physics:GetPos()), angle = physics:GetAngles(),
        secondstoarrive = 0.12, delta = delta, maxangular = 0, maxangulardamp = 0,
        maxspeed = 220, maxspeeddamp = 350, dampfactor = 0.8, teleportdistance = 0})
end

hook.Add("Think", "ixBodyDragPhysics", function()
    for client, state in pairs(D.states) do D.Step(client, state, engine.TickInterval()) end
end)
hook.Add("ShouldCollide", "ixBodyDragCarrier", function(a, b)
    if a.ixBodyDragger == b or b.ixBodyDragger == a then return false end
end)
hook.Add("PhysgunPickup", "ixBodyDragBusy", function(_, body)
    if IsValid(body.ixBodyDragger) then return false end
end)
hook.Add("CanPlayerEnterVehicle", "ixBodyDragRelease", function(client) D.Stop(client) end)
hook.Add("PlayerDeath", "ixBodyDragRelease", D.DropPatient)
hook.Add("PlayerDisconnected", "ixBodyDragRelease", D.DropPatient)
hook.Add("PlayerLoadedCharacter", "ixBodyDragRelease", D.DropPatient)
hook.Add("OnCharacterFallover", "ixBodyDragRelease", function(client, body, state)
    D.DropPatient(client)
    if state and IsValid(body) then body:SetNW2Entity("ixDragPatient", client) end
end)
hook.Add("PlayerUse", "ixBodyDragBusy", function(client, entity)
    if entity == D.Body(client) or D.CanTarget(client, entity) then return false end
end)

net.Receive("ixBodyDragRaise", function(_, client)
    local held = net.ReadBool()
    if not D.states[client] or not D.Body(client) or not D.CanDrag(client) then return end
    -- Use server time, toggle only once per hold, and expire interrupted input.
    if not held or (client.ixDragReloadUntil or 0) <= CurTime() then
        client.ixDragRaiseStart, client.ixDragRaised = nil, nil
    end
    client.ixDragReloadUntil = held and (CurTime() + 1) or nil
end)

net.Receive("ixBodyDragAction", function(_, client)
    if (client.ixDragNextRequest or 0) > CurTime() then return end
    client.ixDragNextRequest = CurTime() + 0.2
    if net.ReadBool() then D.Stop(client) return end
    local _, reason = D.Start(client, net.ReadEntity())
    if reason then client:Notify(reason) end
end)

function D.Shutdown()
    for client in pairs(D.states) do D.Stop(client) end
    D.ReleaseWeapons()
end
hook.Add("PreCleanupMap", "ixBodyDragRelease", D.Shutdown)
hook.Add("ShutDown", "ixBodyDragRelease", D.Shutdown)
