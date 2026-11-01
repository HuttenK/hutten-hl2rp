local P = ix.PushCart

local function ClearTrace(trace)
    return not trace.Hit and not trace.StartSolid and not trace.AllSolid
end

function P:PatientExit(state, actor, carrierOverlap)
    local cart, patient = state.cart, state.patient
    if not IsValid(patient) then return end
    local position = IsValid(cart) and cart:GetPos() or state.position
    local angles = IsValid(cart) and cart:GetAngles() or state.angles
    local yaw = Angle(0, angles.y, 0)
    local mins, maxs = patient:GetHull()
    local filter = {patient, state.body, state.display}
    local pathFilter = {patient, state.body, state.display, cart}
    if IsValid(actor) then
        pathFilter[#pathFilter + 1] = actor
        -- A drag handoff immediately disables carrier/body collision. Ordinary
        -- unloading must instead find floor room clear of the actor's feet.
        if carrierOverlap then filter[#filter + 1] = actor end
    end
    -- Sweep away from the deck before looking for a floor: never unload through
    -- a thin wall simply because a free point exists on its far side.
    local offsets = {Vector(0,68,0), Vector(0,-68,0), Vector(-100,0,0), Vector(100,0,0),
        Vector(-75,68,0), Vector(-75,-68,0), Vector(75,68,0), Vector(75,-68,0)}
    local function WorldOffset(offset) return yaw:Forward()*offset.x + yaw:Right()*offset.y end
    if IsValid(actor) then
        table.sort(offsets,function(a,b)
            return (position+WorldOffset(a)):DistToSqr(actor:GetPos()) < (position+WorldOffset(b)):DistToSqr(actor:GetPos())
        end)
    end
    local facing = Angle(0, angles.y + (state.footprintYaw or 0), 0)
    local f, r = facing:Forward(), facing:Right()
    local halfLength, halfWidth = state.halfLength or 55, state.halfWidth or 26
    local extent = Vector(math.abs(f.x)*halfLength+math.abs(r.x)*halfWidth,
        math.abs(f.y)*halfLength+math.abs(r.y)*halfWidth,0)
    for _, offset in ipairs(offsets) do
        local start = position + Vector(0,0,12)
        local candidate = start + yaw:Forward() * offset.x + yaw:Right() * offset.y
        local path = util.TraceHull({start=start, endpos=candidate, mins=Vector(-14,-14,0),
            maxs=Vector(14,14,25), filter=pathFilter, mask=MASK_PLAYERSOLID})
        if ClearTrace(path) then
            local floor = util.TraceHull({start=candidate, endpos=candidate-Vector(0,0,100),
                mins=Vector(-14,-14,0), maxs=Vector(14,14,8), filter=filter, mask=MASK_PLAYERSOLID})
            if floor.Hit and not floor.StartSolid and floor.HitNormal.z >= 0.7 then
                local point = floor.HitPos + Vector(0,0,2)
                local standing = util.TraceHull({start=point, endpos=point, mins=mins, maxs=maxs,
                    filter=filter, mask=MASK_PLAYERSOLID})
                -- The lying body needs more floor room than the standing hull.
                local ground = util.TraceHull({start=point, endpos=point, mins=-extent,
                    maxs=extent+Vector(0,0,math.max(state.height or 25,25)), filter=filter, mask=MASK_PLAYERSOLID})
                if ClearTrace(standing) and ClearTrace(ground) then return point end
            end
        end
    end
end

function P:CanLoadPatient(client, cart)
    local D = ix.BodyDrag
    local body = D and D.Body(client)
    local patient = body and D.Patient(body)
    if not IsValid(cart) or not cart.ixIsPushCart or not self:CanOperate(client)
        or self:InteractionTarget(client) ~= cart or not self:Near(client, cart)
        or not body or not IsValid(patient) or not patient:Alive() or not patient:GetCharacter()
        or D.PatientBody(patient) ~= body or not D.states[client] or D.states[client].body ~= body then
        return false, "Сначала возьмите лежащего персонажа и подойдите к тележке."
    end
    if self:HasContents(cart) or self:GetPatient(cart) or self:CargoBusy(cart) or self:PatientCart(patient) then
        return false, "Для раненого нужна полностью пустая тележка."
    end
    if IsValid(cart:GetPusher()) or cart:GetVelocity():LengthSqr() > 25 or cart:GetUp().z < 0.97 then
        return false, "Остановите тележку и поставьте её ровно."
    end
    if body.ixWakingUp or (body.ixFinish and body.ixFinish <= CurTime()) then
        return false, "Персонаж уже встаёт."
    end
    return true, body, patient
end

-- Prepare the pose before changing either the drag or cart ownership. The
-- caller owns the temporary display until preparation succeeds.
function P:PreparePatient(client, cart, body, patient, display)
    display:SetNoDraw(true)
    display:SetModel(body:GetModel())
    local sequence, low, high, sequenceName = self:PatientSequence(display, cart.PatientSeated)
    if not sequence then return nil, "Эта модель не поддерживает нужную позу пациента." end
    local scale = body:GetModelScale()
    low, high = low * scale, high * scale
    local size = high-low
    if math.max(size.x,size.y)>110 or math.min(size.x,size.y)>52 or size.z>(cart.PatientSeated and 65 or 40) then
        return nil, "Эта модель слишком велика для этого транспорта."
    end
    display:SetModelScale(scale,0)
    display:SetSkin(body:GetSkin()); display:SetColor(body:GetColor()); display:SetMaterial(body:GetMaterial())
    for _, group in ipairs(body:GetBodyGroups()) do display:SetBodygroup(group.id,body:GetBodygroup(group.id)) end
    for index in ipairs(body:GetMaterials()) do display:SetSubMaterial(index-1,body:GetSubMaterial(index-1)) end
    if ix.SDHair and ix.SDHair.Copy then ix.SDHair.Copy(patient,display) end
    -- Sample the patient's own skeleton once at the cart origin. Server-side
    -- GetBoneMatrix builds it; SetupBones/InvalidateBoneCache are client-only.
    local origin = cart:GetPos()
    display:SetPos(origin); display:SetAngles(angle_zero); display:Spawn()
    display:ResetSequence(sequence); display:SetCycle(0); display:SetPlaybackRate(0)
    display:SetNW2String("ixPatientSequence",sequenceName or "")
    local heading = Angle(0, (cart.PatientYaw or 0) + (not cart.PatientSeated and size.y>size.x and 90 or 0), 0)
    local center = (low+high)*0.5
    local localPos = Vector((cart.BedMinX+cart.BedMaxX)*0.5, 0, cart.BedZ+1-low.z)
        -heading:Forward()*center.x+heading:Right()*center.y
    if cart.PatientSeated then
        local pelvis = display:LookupBone("ValveBiped.Bip01_Pelvis")
        local matrix = pelvis and display:GetBoneMatrix(pelvis)
        if not matrix then return nil, "У модели нет позы таза для сидения." end
        local point = matrix:GetTranslation()-origin
        -- Seat the pelvis above the cushion, preserving the patient's height.
        localPos = cart.PatientSeat+Vector(0,0,4*scale)-heading:Forward()*point.x+heading:Right()*point.y-Vector(0,0,point.z)
        localPos.z = math.max(localPos.z, .5-low.z)
    end
    local position, angles = LocalToWorld(localPos,heading,cart:GetPos(),cart:GetAngles())
    local bodyCenter = LocalToWorld(center,angle_zero,position,angles)
    local worldAngles = angles
    local forward,right,up = worldAngles:Forward(),worldAngles:Right(),worldAngles:Up()
    local x=(math.abs(forward.x)*size.x+math.abs(right.x)*size.y+math.abs(up.x)*size.z)*.5
    local y=(math.abs(forward.y)*size.x+math.abs(right.y)*size.y+math.abs(up.y)*size.z)*.5
    local z=(math.abs(forward.z)*size.x+math.abs(right.z)*size.y+math.abs(up.z)*size.z)*.5
    local state={cart=cart,body=body,patient=patient,display=display,character=patient:GetCharacter(),
        position=cart:GetPos(),angles=cart:GetAngles(),bones={},noDraw=body:GetNoDraw(),notSolid=not body:IsSolid(),
        model=body:GetModel(),halfLength=math.max(size.x,size.y)*.5+2,halfWidth=math.min(size.x,size.y)*.5+2,
        height=size.z,top=localPos.z+high.z,low=low,high=high,heading=heading,footprintYaw=cart.PatientYaw or 0}
    state.safeExit=self:PatientExit(state,client)
    if not state.safeExit then return nil,"Рядом нет свободного места для безопасной выгрузки." end
    local clear=util.TraceHull({start=bodyCenter,endpos=bodyCenter,
        mins=Vector(-x,-y,-z),maxs=Vector(x,y,z),
        filter={client,cart,body,patient,display},mask=MASK_SOLID})
    if not ClearTrace(clear) then return nil,"Место для пациента занято." end
    for index=0,body:GetPhysicsObjectCount()-1 do
        local physics=body:GetPhysicsObjectNum(index)
        local bone=body:TranslatePhysBoneToBone(index)
        local name=bone and body:GetBoneName(bone)
        local target=name and display:LookupBone(name)
        local matrix=target and display:GetBoneMatrix(target)
        if IsValid(physics) and not matrix then return nil,"Не удалось получить позу костей этой модели." end
        if IsValid(physics) and matrix then
            state.bones[#state.bones+1]={index=index,physics=physics,position=matrix:GetTranslation()-origin,
                angles=matrix:GetAngles(),motion=physics:IsMotionEnabled(),collisions=physics:IsCollisionEnabled()}
        end
    end
    if #state.bones==0 then return nil,"У тела нет доступных физических костей." end
    display:SetPos(position); display:SetAngles(angles)
    return state,localPos
end

function P:LoadPatient(client, cart)
    local allowed, body, patient = self:CanLoadPatient(client, cart)
    if not allowed then return false, body end
    local display = ents.Create("ix_cart_patient")
    if not IsValid(display) then return false, "Не удалось подготовить место для раненого." end
    local ok, state, localPos = xpcall(function()
        return self:PreparePatient(client, cart, body, patient, display)
    end, debug.traceback)
    if not ok or not state then
        if IsValid(display) then display:Remove() end
        if not ok then ErrorNoHalt("[PushCart] Patient preparation failed: " .. tostring(state) .. "\n") end
        return false, ok and localPos or "Не удалось подготовить позу этой модели."
    end
    ix.BodyDrag.Stop(client)
    self.patientStates[cart] = state
    local low, high, heading = state.low, state.high, state.heading
    display.ixPlayer = patient
    display:SetNW2Entity("ixCartPatient",patient)
    display:SetNW2Entity("ixPatientCart",cart)
    display:SetNW2Vector("ixPatientMins",low)
    display:SetNW2Vector("ixPatientMaxs",high)
    display:SetCollisionBounds(low,high)
    display:SetParent(cart); display:SetLocalPos(localPos); display:SetLocalAngles(heading)
    cart:SetNW2Entity("ixCartPatient",patient)
    cart:SetNW2Entity("ixCartPatientDisplay",display)
    patient:SetNW2Entity("ixPatientCart",cart)
    body:SetNW2Entity("ixPatientCart",cart)
    body:SetNoDraw(true); body:SetNotSolid(true)
    for _, bone in ipairs(state.bones) do
        bone.physics:EnableMotion(false); bone.physics:EnableCollisions(false)
        bone.physics:SetVelocity(vector_origin)
    end
    self:SyncPatient(state)
    display:SetNoDraw(false)
    cart:UpdateLoad(); cart:LayoutCrates()
    client:Notify(cart.PatientSeated and "Персонаж усажен в коляску." or "Персонаж уложен на тележку.")
    return true
end

function P:SyncPatient(state)
    local cart, body, display = state.cart, state.body, state.display
    state.position, state.angles = cart:GetPos(), cart:GetAngles()
    local position, angles = LocalToWorld(display:GetLocalPos(),display:GetLocalAngles(),state.position,state.angles)
    if state.syncedPosition==position and state.syncedAngles==angles then return end
    state.syncedPosition, state.syncedAngles = position, angles
    body:SetPos(position)
    state.patient:SetPos(position)
    for _, bone in ipairs(state.bones) do
        if IsValid(bone.physics) then
            local point, angle = LocalToWorld(bone.position,bone.angles,position,angles)
            bone.physics:SetPos(point); bone.physics:SetAngles(angle)
        end
    end
end

function P:ReleasePatient(cart, position, removingBody)
    local state = self.patientStates[cart]
    if not state then return end
    self.patientStates[cart] = nil -- Retire ownership before deleting the display.
    local body, patient, display = state.body, state.patient, state.display
    if IsValid(cart) then state.position, state.angles = cart:GetPos(), cart:GetAngles() end
    position = position or self:PatientExit(state) or state.safeExit
    if IsValid(cart) then
        if IsValid(cart:GetPusher()) then cart:StopPush() end
        cart:SetNW2Entity("ixCartPatient",NULL); cart:SetNW2Entity("ixCartPatientDisplay",NULL)
        cart:UpdateLoad(); cart:LayoutCrates()
    end
    if IsValid(patient) then patient:SetNW2Entity("ixPatientCart",NULL) end
    if IsValid(body) and not removingBody then
        local heading = Angle(0,state.angles.y,0)
        heading.y = heading.y + state.heading.y
        local center = (state.low+state.high)*0.5
        local anchor = position + Vector(0,0,2-state.low.z) - heading:Forward()*center.x + heading:Right()*center.y
        body:SetNW2Entity("ixPatientCart",NULL)
        body:SetPos(anchor); body:SetNoDraw(state.noDraw); body:SetNotSolid(state.notSolid)
        for _, bone in ipairs(state.bones) do
            if IsValid(bone.physics) then
                local point, angle = LocalToWorld(bone.position,bone.angles,anchor,heading)
                bone.physics:SetPos(point); bone.physics:SetAngles(angle)
                bone.physics:SetVelocity(vector_origin)
                bone.physics:EnableCollisions(bone.collisions)
                bone.physics:EnableMotion(bone.motion); bone.physics:Wake()
            end
        end
        if IsValid(patient) then patient:SetPos(position) end
    end
    if IsValid(display) then display:Remove() end
    return position, body
end

function P:UnloadPatient(client, cart, take)
    local state = self.patientStates[cart]
    if not state or not self:CanOperate(client) or not self:Near(client,cart) or IsValid(cart:GetPusher())
        or cart:GetVelocity():LengthSqr()>25
        or (ix.BodyDrag and ix.BodyDrag.Body(client)) or IsValid(client:GetLocalVar("holdingObject")) then return false end
    if take and (not ix.BodyDrag or not ix.BodyDrag.CanDrag(client)) then return false end
    if take then
        for _, weapon in ipairs(client:GetWeapons()) do
            if ix.BodyDrag.IsReloading(weapon) then return false, "Сначала завершите перезарядку." end
        end
    end
    local position = self:PatientExit(state,client,take)
    if not position then return false, "Нет свободного места рядом с тележкой." end
    -- Choose a real physics grip within reach before committing an unload.
    local index, point
    if take then
        local heading = Angle(0,cart:GetAngles().y+state.heading.y,0)
        local center = (state.low+state.high)*0.5
        local anchor = position + Vector(0,0,2-state.low.z) - heading:Forward()*center.x + heading:Right()*center.y
        for _, bone in ipairs(state.bones) do
            local candidate = LocalToWorld(bone.position,bone.angles,anchor,heading)
            if candidate:DistToSqr(client:GetShootPos()) <= ix.BodyDrag.RANGE^2 then
                index, point = bone.index, candidate
                local line=util.TraceLine({start=client:GetShootPos(),endpos=candidate,filter={client,state.body,cart,state.display},mask=MASK_SOLID})
                if ClearTrace(line) then break end
                index,point=nil,nil
            end
        end
        if not index then return false, "Подойдите ближе к свободной стороне тележки." end
    end
    local _, body = self:ReleasePatient(cart,position)
    if take then
        local ok = ix.BodyDrag.Start(client,body,{Entity=body,PhysicsBone=index,HitPos=point})
        if not ok then return true, "Персонаж снят с тележки. Возьмите его за тело." end
    end
    return true
end

function P:PatientDisplayRemoved(display)
    for cart,state in pairs(self.patientStates) do
        if state.display == display then self:ReleasePatient(cart) return end
    end
end

hook.Add("Think","ixCartPatients",function()
    if (P.nextPatientUpdate or 0)>CurTime() then return end
    P.nextPatientUpdate=CurTime()+0.1
    for cart,state in pairs(P.patientStates) do
        local patient=state.patient
        if not IsValid(cart) or not IsValid(patient) or not patient:Alive() or patient:GetCharacter()~=state.character
            or not IsValid(state.body) or patient.ixRagdoll~=state.body or not IsValid(state.display)
            or state.body:GetModel()~=state.model then
            P:ReleasePatient(cart)
        else
            P:SyncPatient(state)
            if (state.nextExitCheck or 0)<=CurTime() then
                state.nextExitCheck=CurTime()+1
                state.safeExit=P:PatientExit(state) or state.safeExit
            end
        end
    end
end)

-- Called inside Helix's original removal callback, before it restores walking,
-- position and weapons. Handles medical revival and timed fallovers equally.
hook.Add("GetRagdollRecoveryPosition","ixCartPatientRecovery",function(patient,body)
    local cart=P:PatientCart(patient)
    local state=cart and P.patientStates[cart]
    if state and state.body==body then
        return P:ReleasePatient(cart,nil,true)
    end
end)

local function ReleasePlayer(patient)
    local cart=P:PatientCart(patient)
    if cart then P:ReleasePatient(cart) end
end
hook.Add("PlayerDeath","ixCartPatientRelease",ReleasePlayer)
hook.Add("PlayerDisconnected","ixCartPatientRelease",ReleasePlayer)
hook.Add("PrePlayerLoadedCharacter","ixCartPatientRelease",ReleasePlayer)
hook.Add("PreCleanupMap","ixCartPatientRelease",function()
    for cart in pairs(P.patientStates) do P:ReleasePatient(cart) end
end)
hook.Add("ShutDown","ixCartPatientRelease",function()
    for cart in pairs(P.patientStates) do P:ReleasePatient(cart) end
end)
hook.Add("PhysgunPickup","ixCartPatientRelease",function(_,entity)
    if P:PatientCart(entity) or (entity.ixIsPushCart and P:GetPatient(entity)) then return false end
end)
hook.Add("CanPlayerHoldObject","ixCartPatientRelease",function(_,entity)
    if P:PatientCart(entity) then return false end
end)

-- Also retire displays left unowned by an older, interrupted load when this
-- file is refreshed. Active patients keep their existing display and body.
function P:CleanupPatientDisplays()
    for _, display in ipairs(ents.FindByClass("ix_cart_patient")) do
        local state = self.patientStates[display:GetNW2Entity("ixPatientCart")]
        if not state or state.display ~= display then display:Remove() end
    end
end
timer.Simple(0, function() P:CleanupPatientDisplays() end)
