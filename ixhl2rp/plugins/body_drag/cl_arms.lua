local D = ix.BodyDrag
-- Remove the previous build callbacks before refreshing this file in-game.
if D.CleanupArms then D.CleanupArms(true) end
D.armRevision = 2
local rigs, callbacks = {}, {}
local grips = setmetatable({}, {__mode = "k"})
local active = setmetatable({}, {__mode = "k"})
local applying = setmetatable({}, {__mode = "k"})
local prefix = "ValveBiped.Bip01_L_"

local function Subtree(entity, root)
    local result = {}
    for bone = 0, entity:GetBoneCount() - 1 do
        local parent, guard = bone, 0
        while parent and parent >= 0 and guard < 256 do
            if parent == root then result[#result + 1] = bone break end
            parent = entity:GetBoneParent(parent)
            guard = guard + 1
        end
    end
    return result
end

local function Rig(entity)
    local key = entity:GetModel() .. ":" .. entity:GetBoneCount()
    if rigs[key] ~= nil then return rigs[key] or nil end
    local upper, lower, hand = entity:LookupBone(prefix .. "UpperArm"),
        entity:LookupBone(prefix .. "Forearm"), entity:LookupBone(prefix .. "Hand")
    if not upper or not lower or not hand then rigs[key] = false return end
    local rig = {upper = upper, lower = lower, hand = hand,
        upperTree = Subtree(entity, upper), lowerTree = Subtree(entity, lower), handTree = Subtree(entity, hand)}
    rigs[key] = rig
    return rig
end

function D.SolveArm(shoulder, elbow, wrist, target, pole)
    local a, b = shoulder:Distance(elbow), elbow:Distance(wrist)
    local offset = target - shoulder
    if a < 0.01 or b < 0.01 or offset:LengthSqr() < 0.0001 then return elbow, wrist end
    local direction = offset:GetNormalized()
    local reach = math.Clamp(offset:Length(), math.abs(a - b) + 0.01, (a + b) * 0.995)
    local cosine = math.Clamp((a * a + reach * reach - b * b) / (2 * a * reach), -1, 1)
    local bend = pole - direction * pole:Dot(direction)
    if bend:LengthSqr() < 0.0001 then bend = direction:Cross(Vector(1, 0, 0)) end
    if bend:LengthSqr() < 0.0001 then bend = direction:Cross(Vector(0, 1, 0)) end
    return shoulder + direction * (a * cosine) + bend:GetNormalized() * (a * math.sqrt(1 - cosine * cosine)),
        shoulder + direction * reach
end

local function Rotation(from, to, pivot)
    if from:LengthSqr() < 0.0001 or to:LengthSqr() < 0.0001 then return Matrix() end
    local a, b = from:GetNormalized(), to:GetNormalized()
    local axis, cosine = a:Cross(b), math.Clamp(a:Dot(b), -1, 1)
    if axis:LengthSqr() < 0.0001 then
        if cosine > 0 then return Matrix() end
        axis = a:Cross(Vector(0, 0, 1))
        if axis:LengthSqr() < 0.0001 then axis = a:Cross(Vector(0, 1, 0)) end
    end
    axis:Normalize()
    local x, y, z = axis.x, axis.y, axis.z
    local s, t = math.sqrt(math.max(0, 1 - cosine * cosine)), 1 - cosine
    local rows = {{t*x*x+cosine, t*x*y-s*z, t*x*z+s*y},
        {t*x*y+s*z, t*y*y+cosine, t*y*z-s*x}, {t*x*z-s*y, t*y*z+s*x, t*z*z+cosine}}
    local px, py, pz = pivot.x, pivot.y, pivot.z
    return Matrix({
        {rows[1][1],rows[1][2],rows[1][3],px-rows[1][1]*px-rows[1][2]*py-rows[1][3]*pz},
        {rows[2][1],rows[2][2],rows[2][3],py-rows[2][1]*px-rows[2][2]*py-rows[2][3]*pz},
        {rows[3][1],rows[3][2],rows[3][3],pz-rows[3][1]*px-rows[3][2]*py-rows[3][3]*pz},
        {0,0,0,1}})
end

local function Transform(entity, bones, matrix)
    for _, bone in ipairs(bones) do
        local old = entity:GetBoneMatrix(bone)
        if old and entity:GetBoneName(bone) ~= "__INVALIDBONE__" then entity:SetBoneMatrix(bone, matrix * old) end
    end
end

function D.CacheGrip(body)
    if not IsValid(body) then return end
    local frame = FrameNumber()
    local cached = grips[body]
    if cached and cached.frame == frame then return cached.point end
    cached = {frame = frame}; grips[body] = cached
    local bone = body:GetNW2Int("ixDragBone", -1)
    if bone < 0 then return end
    -- Sample once before rendering, never from a bone-build callback. ARC9 and
    -- secondary camera passes may rebuild the carrier's bones many times.
    body:SetupBones()
    local matrix = body:GetBoneMatrix(bone)
    if matrix then
        cached.point = LocalToWorld(body:GetNW2Vector("ixDragOffset"), angle_zero,
            matrix:GetTranslation(), matrix:GetAngles())
    end
    return cached.point
end

function D.RenderGrip(body)
    local cached = grips[body]
    return cached and cached.point
end

function D.ApplyArm(entity, owner, viewmodel)
    local body = D.Body(owner)
    if not body or not IsValid(entity) then return end
    local rig, point = Rig(entity), D.RenderGrip(body)
    if not rig or not point then return end
    local upper, lower, hand = entity:GetBoneMatrix(rig.upper), entity:GetBoneMatrix(rig.lower), entity:GetBoneMatrix(rig.hand)
    if not upper or not lower or not hand then return end
    local shoulder, elbow, wrist = upper:GetTranslation(), lower:GetTranslation(), hand:GetTranslation()
    if shoulder:DistToSqr(owner:GetPos()) > 256 * 256 then return end
    -- Reject corrupt/missing engine poses instead of turning them into giant
    -- triangles. A human arm cannot acquire hundreds of units of bone length.
    local scale = math.Clamp(owner:GetModelScale(), 0.5, 2)
    local upperLength, lowerLength = shoulder:Distance(elbow), elbow:Distance(wrist)
    if upperLength < 1 or lowerLength < 1 or upperLength > 32 * scale or lowerLength > 32 * scale then return end
    local right = Angle(0, owner:EyeAngles().y, 0):Right()
    if viewmodel then
        -- Viewmodels use a different FOV. Map the same world grip to that camera
        -- before solving, so aiming does not leave a spare hand on the rifle.
        local weapon = owner:GetActiveWeapon()
        local vmfov = IsValid(weapon) and weapon.ViewModelFOV or 54
        if IsValid(weapon) and isfunction(weapon.GetViewModelFOV) then vmfov = weapon:GetViewModelFOV() end
        local ratio = math.tan(math.rad(math.Clamp(tonumber(vmfov) or 54, 20, 120) / 2))
            / math.tan(math.rad(math.Clamp(owner:GetFOV(), 20, 120) / 2))
        local camera, angles = EyePos(), EyeAngles()
        local delta = point - camera
        point = camera + angles:Forward() * delta:Dot(angles:Forward())
            + angles:Right() * (delta:Dot(angles:Right()) * ratio)
            + angles:Up() * (delta:Dot(angles:Up()) * ratio)
    end
    local newElbow, newWrist = D.SolveArm(shoulder, elbow, wrist, point, -right - Vector(0, 0, 1))
    local first = Rotation(elbow - shoulder, newElbow - shoulder, shoulder)
    Transform(entity, rig.upperTree, first)
    local movedHand = entity:GetBoneMatrix(rig.hand)
    local movedElbow = entity:GetBoneMatrix(rig.lower)
    if not movedHand or not movedElbow then return end
    local pivot = movedElbow:GetTranslation()
    Transform(entity, rig.lowerTree, Rotation(movedHand:GetTranslation() - pivot, newWrist - newElbow, pivot))
end

function D.WatchArm(entity, owner, viewmodel)
    if not IsValid(entity) then return end
    local state = callbacks[entity]
    if state then state.owner, state.viewmodel = owner, viewmodel return end
    state = {owner = owner, viewmodel = viewmodel}
    state.id = entity:AddCallback("BuildBonePositions", function(model)
        if not IsValid(state.owner) or applying[model] then return end
        -- ARC9's helper repair samples this callback's output as its base pose.
        -- Its third-person arm must be changed only after that repair completes.
        local weapon = state.owner:GetActiveWeapon()
        if not state.viewmodel and IsValid(weapon) and weapon.ARC9 and ix.arc9Helpers then return end
        applying[model] = true
        D.ApplyArm(model, state.owner, state.viewmodel)
        applying[model] = nil
    end)
    callbacks[entity] = state
    entity:InvalidateBoneCache()
end

function D.WatchARC9(weapon)
    if ix.arc9Helpers then ix.arc9Helpers.Install(weapon) end
end

hook.Add("ixARC9PostArmPose", "ixBodyDragArms", function(_, owner)
    if D.Body(owner) and not applying[owner] then
        applying[owner] = true
        D.ApplyArm(owner, owner, false)
        applying[owner] = nil
    end
end)

function D.CleanupArms(all)
    for entity, state in pairs(callbacks) do
        if all or not IsValid(entity) or not D.Body(state.owner)
            or (state.viewmodel and entity ~= state.owner:GetViewModel() and entity ~= state.owner:GetHands()) then
            if IsValid(entity) then
                entity:RemoveCallback("BuildBonePositions", state.id)
                entity:InvalidateBoneCache()
            end
            callbacks[entity] = nil
        end
    end
end

hook.Add("Think", "ixBodyDragArms", function()
    for _, owner in ipairs(player.GetAll()) do
        if D.Body(owner) then
            active[owner] = true
            D.WatchArm(owner, owner, false)
            D.WatchARC9(owner:GetActiveWeapon())
            if owner == LocalPlayer() then
                D.WatchArm(owner:GetViewModel(), owner, true)
                D.WatchArm(owner:GetHands(), owner, true)
            end
        else active[owner] = nil end
    end
    D.CleanupArms(false)
end)
hook.Add("PreRender", "ixBodyDragGrip", function()
    for owner in pairs(active) do
        local body = D.Body(owner)
        if body then D.CacheGrip(body) else active[owner] = nil end
    end
end)
hook.Add("PreDrawViewModel", "ixBodyDragArms", function(vm, owner)
    if D.Body(owner) then D.WatchArm(vm, owner, true) end
end)
hook.Add("PreDrawPlayerHands", "ixBodyDragArms", function(hands, vm, owner)
    if D.Body(owner) then D.WatchArm(hands, owner, true) end
end)
function D.Shutdown()
    D.CleanupArms(true)
    D.ReleaseWeapons(nil, true)
end
hook.Add("ShutDown", "ixBodyDragArms", D.Shutdown)
