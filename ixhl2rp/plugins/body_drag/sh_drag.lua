local D = ix.BodyDrag
D.RANGE = 100
D.BREAK_DISTANCE = 110
D.TURN_RATE = 220
D.states = D.states or {}

function D.Body(client)
    if not IsValid(client) then return end
    local body = client:GetNW2Entity("ixDraggedBody")
    if IsValid(body) then return body end
end

function D.Patient(entity)
    if not IsValid(entity) then return end
    if entity:IsPlayer() then return entity end
    if entity:GetClass() ~= "prop_ragdoll" then return end
    if IsValid(entity.ixPlayer) then return entity.ixPlayer end
    local patient = entity:GetNW2Entity("ixDragPatient")
    if IsValid(patient) then return patient end
    -- Existing fallovers from before a hot reload have no drag-specific owner.
    for _, client in ipairs(player.GetAll()) do
        if client:GetNetVar("doll") == entity:EntIndex() then return client end
    end
end

function D.PatientBody(patient)
    if not IsValid(patient) then return end
    if SERVER then return IsValid(patient.ixRagdoll) and patient.ixRagdoll or nil end
    local index = patient:GetNetVar("doll")
    local body = index and Entity(index)
    return IsValid(body) and body or nil
end

function D.CanDrag(client)
    return IsValid(client) and client:IsPlayer() and client:Alive() and client:GetCharacter()
        and not client:IsRestricted() and not client:InVehicle()
        and client:GetMoveType() == MOVETYPE_WALK
        and not client:GetNetVar("crit", false) and not client:GetLocalVar("knocked", false)
        and not D.PatientBody(client)
        and not (client.IsProne and client:IsProne())
        and not (ix.PushCart and ix.PushCart:IsPushing(client))
end

function D.CanTarget(client, entity)
    local patient = D.Patient(entity)
    if not D.CanDrag(client) or not IsValid(patient) or patient == client
        or not patient:Alive() or not patient:GetCharacter() then return false end
    local body = D.PatientBody(patient)
    if entity ~= patient and entity ~= body then return false end
    if not body and not patient:GetNetVar("crit", false) then return false end
    if body and IsValid(body:GetNW2Entity("ixBodyDragger")) then return false end
    return not D.Body(client)
end

-- Turn on the horizontal plane rather than lerping a point through the torso.
-- At rest keep the last direction; looking around alone does not swing a body.
function D.TrailYaw(velocity, previous, fallback, delta)
    local desired = velocity:Length2DSqr() > 16 and (-velocity):Angle().y or previous or fallback
    return math.ApproachAngle(previous or desired, desired, D.TURN_RATE * math.Clamp(delta, 0, 0.1))
end

function D.GripTarget(client, yaw)
    local scale = math.Clamp(client:GetModelScale(), 0.5, 2)
    local right = Angle(0, client:EyeAngles().y, 0):Right()
    local trail = Angle(0, yaw, 0):Forward()
    local height = (client:Crouching() and client:GetViewOffsetDucked().z or client:GetViewOffset().z) - 13 * scale
    local shoulder = client:GetPos() + Vector(0, 0, height) - right * (7 * scale)
    local offset = trail * (22 * scale) - right * (9 * scale) - Vector(0, 0, 14 * scale)
    -- Sideways travel must not pull the left hand through the chest/right arm.
    local across = offset:Dot(right)
    if across > -3 * scale then offset = offset - right * (across + 3 * scale) end
    return shoulder + offset, shoulder
end

local reloadHeld, nextReloadUpdate = false, 0
hook.Add("StartCommand", "ixBodyDragReload", function(client, command)
    -- Client command edits reach the server already edited. Send the held-key
    -- intent separately before stripping reload from both weapon simulations.
    if CLIENT then
        local held = D.Body(client) ~= nil and command:KeyDown(IN_RELOAD)
        if held ~= reloadHeld or (held and CurTime() >= nextReloadUpdate) then
            net.Start("ixBodyDragRaise")
            net.WriteBool(held)
            net.SendToServer()
            reloadHeld, nextReloadUpdate = held, CurTime() + 0.25
        end
    end
    if D.Body(client) then
        if SERVER then
            -- Raw input also supports bots and clients without prediction.
            local held = command:KeyDown(IN_RELOAD) or (client.ixDragReloadUntil or 0) > CurTime()
            if held then
                client.ixDragRaiseStart = client.ixDragRaiseStart or CurTime()
                if not client.ixDragRaised and CurTime() - client.ixDragRaiseStart >= ix.config.Get("weaponRaiseTime", 0.5) then
                    client:ToggleWepRaised()
                    client.ixDragRaised = true
                end
            else client.ixDragRaiseStart, client.ixDragRaised = nil, nil end
        end
        command:RemoveKey(IN_RELOAD)
        D.ProtectWeapons(client)
    end
end)

hook.Add("SetupMove", "ixBodyDragPace", function(client, move)
    if not D.Body(client) then return end
    -- Limit pull speed, not aim, attacks or weapon selection.
    local speed = math.min(client:GetWalkSpeed(), 150)
    move:SetMaxClientSpeed(math.min(move:GetMaxClientSpeed(), speed))
    move:SetMaxSpeed(math.min(move:GetMaxSpeed(), speed))
end)

hook.Add("prone.CanEnter", "ixBodyDrag", function(client)
    if D.Body(client) then return false end
end)
