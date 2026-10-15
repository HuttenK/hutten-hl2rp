local C = ix.SCPCompat
C.sessions = C.sessions or {}

local function flags(client, npc)
    local active = IsValid(npc)
    client.IsPossessing = active
    client.CurrentlyPossessedNPC = active and npc or nil
    client:SetNW2Entity("CPTBase_PossessingEntity", active and npc or NULL)
    client:SetNW2Bool("CPTBase_IsPossessing", active)
    client:SetNW2String("CPTBase_PossessedNPCClass", active and npc:GetClass() or "")
    client:SetNW2Entity("CPTBase_PossessedNPC", active and npc or NULL)
    -- Do not enable the obsolete NW1 visual hooks: several read the class
    -- string using GetNWBool and crash as soon as possession is enabled.
end

local function callback(npc, name, client, saved)
    local method = saved or (IsValid(npc) and npc[name])
    if not isfunction(method) then return true end
    local ok, err = xpcall(function() method(npc, client) end, debug.traceback)
    if not ok then ErrorNoHalt("[SCP compatibility] " .. name .. ": " .. tostring(err) .. "\n") end
    return ok
end

function C.Stop(client, restore)
    local state = C.sessions[client]
    if not state then return end
    C.sessions[client] = nil
    local npc = state.npc
    if IsValid(npc) then
        npc:SetPossessor(NULL); npc.Possessor = NULL; npc.IsPossessed = false
        npc:SetNW2Entity("ixSCPCamera", NULL)
        npc:StopMoving(); npc:ClearSchedule()
    end
    -- Retain the callback before removal: 079 must switch off its client effect
    -- even when the entity disappeared before the watchdog saw it.
    callback(npc, "Possess_OnStopPossessing", client, state.onStop)
    if not IsValid(client) then return end
    flags(client)
    client:UnSpectate()
    client:SetNoDraw(state.noDraw); client:SetNotSolid(state.notSolid)
    client:DrawShadow(not state.noDraw)
    client:DrawViewModel(true); client:DrawWorldModel(not state.noDraw)
    if state.god then client:GodEnable() else client:GodDisable() end
    if state.noTarget then client:AddFlags(FL_NOTARGET) else client:RemoveFlags(FL_NOTARGET) end
    if restore ~= false and client:Alive() and client:GetCharacter() == state.character then
        client:SetMoveType(state.move)
        client:SetPos(state.pos); client:SetEyeAngles(state.angles)
        client:SetLocalVelocity(vector_origin)
        if IsValid(state.weapon) and state.weapon:GetOwner() == client then client:SelectWeapon(state.weapon:GetClass()) end
    end
end

function C.Start(npc, client)
    if not IsValid(npc) or not npc.IsCPTBase_NPC or npc.Possessor_CanBePossessed == false
        or not istable(npc.MemoryTable) or npc.IsDead or npc:Health() <= 0
        or not IsValid(client) or not client:IsPlayer() or not client:Alive() or not client:GetCharacter()
        or client:InVehicle() or client:IsFrozen() or client:GetNW2Float("ixSCPStunUntil", 0) > CurTime()
        or client:GetNetVar("crit", false)
        or client:GetLocalVar("ragdoll", 0) ~= 0 or client:GetLocalVar("knocked", false)
        or client:GetNetVar("bedRestAngle") or client:GetNetVar("actEnterAngle")
        or IsValid(client:GetNW2Entity("ixDraggedBody"))
        or (ix.PushCart and ix.PushCart:IsPushing(client)) or client:IsRestricted() or C.sessions[client]
        or IsValid(npc:GetPossessor()) then return false end
    if hook.Run("CanPlayerControlSCP", client, npc) == false
        or hook.Run("CanProperty", client, "Control NPC", npc) == false then return false end
    local state = {npc = npc, character = client:GetCharacter(), pos = client:GetPos(), angles = client:EyeAngles(),
        move = client:GetMoveType(), noDraw = client:GetNoDraw(),
        notSolid = bit.band(client:GetSolidFlags(), FSOLID_NOT_SOLID) ~= 0,
        god = client:HasGodMode(), noTarget = client:IsFlagSet(FL_NOTARGET), weapon = client:GetActiveWeapon(),
        onStop = npc.Possess_OnStopPossessing}
    -- Preserve live weapon entities, ARC9 attachments, ammo and inventory identity.
    -- Spectator input drives the NPC; no human SWEP remains selected or fires.
    if IsValid(state.weapon) and state.weapon.Holster and state.weapon:Holster(NULL) == false then return false end
    C.sessions[client] = state
    npc.IsPossessed = true; npc.Possessor = client; npc:SetPossessor(client)
    npc:SetEnemy(NULL); npc:StopMoving(); npc:ClearSchedule()
    npc:SetPossessorAimPos(npc:GetPos() + client:GetAimVector() * 1024)
    flags(client, npc)
    client:SetActiveWeapon(NULL)
    client:GodEnable(); client:AddFlags(FL_NOTARGET)
    client:Spectate(OBS_MODE_CHASE); client:SpectateEntity(npc)
    client:SetNoDraw(true); client:SetNotSolid(true); client:DrawShadow(false)
    client:DrawViewModel(false); client:DrawWorldModel(false)
    client:SetMoveType(MOVETYPE_OBSERVER)
    client:SetPos(npc:GetPos() + npc:OBBCenter())
    if not callback(npc, "Possess_OnPossessed", client) then C.Stop(client) return false end
    client:ChatPrint("Управление SCP: E — вернуться к персонажу; колёсико — расстояние камеры.")
    return true
end

function C.ControlNPC(npc, enabled, client)
    if enabled then return C.Start(npc, client) end
    local owner = npc:GetPossessor()
    if IsValid(owner) and C.sessions[owner] and C.sessions[owner].npc == npc then C.Stop(owner) end
end

function C.CurrentCamera(npc)
    local camera = npc:GetCurrentCamera()
    if IsValid(camera) then return camera end
    local cameras = {}
    for _, candidate in ipairs(npc.tbl_Cameras or {}) do if IsValid(candidate) then cameras[#cameras + 1] = candidate end end
    npc.tbl_Cameras = cameras
    if #cameras == 0 then return end
    -- Removal recovery must not spend auxiliary power or index a removed camera.
    npc.CurrentCamera = cameras[1]; cameras[1]:SetCameraOwner(npc)
    return cameras[1]
end

function C.ControlMovement(npc)
    local client = npc:GetPossessor()
    local state = C.sessions[client]
    if not state or state.npc ~= npc then return end
    if client:KeyDown(IN_USE) then C.Stop(client) return end
    client:SetPos(npc:GetPos() + npc:OBBCenter())
    if npc:GetClass() == "npc_cpt_scp_079" then
        local camera = C.CurrentCamera(npc)
        if not IsValid(camera) then C.Stop(client) return end
        npc:SetNW2Entity("ixSCPCamera", camera)
        camera:SetPossessorAimPos(npc:GetPossessorAimPos())
        local tr = camera:Possess_EyeTrace()
        camera.CameraHitPosition, camera.CameraHitEntity = tr.HitPos, tr.Entity
        if not callback(npc, "Possess_Think", client) or not callback(npc, "Possess_CustomCommands", client) then C.Stop(client) end
        return
    end
    if npc:GetClass() == "npc_cpt_scp_106" and client:KeyDown(IN_ZOOM) then
        if not callback(npc, "Possess_Zoom", client) then C.Stop(client) return end
    end
    -- The SCP packs still use this legacy movement lock (173 while watched,
    -- 096 before rage, and stationary SCP objects). Redux ignores it.
    if npc.Possessor_CanMove == false then
        npc:StopMoving()
        npc:ControlKeys(client, npc:GetPlayerKeys(client))
        return
    end
    npc:ixCPTOriginalMovement()
end

function C.Tick()
    for client, state in pairs(C.sessions) do
        if not IsValid(client) or not client:Alive() or client:GetCharacter() ~= state.character then C.Stop(client, false)
        elseif not IsValid(state.npc) or state.npc.IsDead or state.npc:Health() <= 0
            or state.npc:GetPossessor() ~= client or client:GetNetVar("crit", false) then C.Stop(client) end
    end
end
timer.Create("ixSCPControlSessions", .1, 0, C.Tick)
hook.Add("PrePlayerLoadedCharacter", "ixSCPControl", function(client) C.Stop(client) end)
hook.Add("PlayerDisconnected", "ixSCPControl", function(client) C.Stop(client, false) end)
hook.Add("PlayerDeath", "ixSCPControl", function(client) C.Stop(client, false) end)
hook.Add("PlayerSpawn", "ixSCPControl", function(client) C.Stop(client, false) end)
hook.Add("PreCleanupMap", "ixSCPControl", function() for client in pairs(C.sessions) do C.Stop(client) end end)

-- Validate the owner and vector before forwarding the addon's existing packet.
function C.ReceiveAim(_, client)
    local position, npc = net.ReadVector(), net.ReadEntity()
    if not IsValid(client) or C.Controlled(client) ~= npc then return end
    if not isvector(position) or position.x ~= position.x or position.y ~= position.y or position.z ~= position.z
        or math.abs(position.x) > 1000000 or math.abs(position.y) > 1000000 or math.abs(position.z) > 1000000 then return end
    if (client.ixSCPAimAt or 0) > CurTime() then return end
    client.ixSCPAimAt = CurTime() + 1 / 66
    npc:SetPossessorAimPos(position)
end
