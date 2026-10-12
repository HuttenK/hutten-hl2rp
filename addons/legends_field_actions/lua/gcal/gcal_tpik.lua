if not CLIENT then return end

GCAL = GCAL or {}

-- Two-segment arm reach, preserving the player model's limb lengths.
function GCAL.SolveArmReach(root, target, pole, upperLength, foreLength)
    if upperLength < .001 or foreLength < .001 then return end
    local delta = target - root
    local direction = delta:GetNormalized()
    if delta:LengthSqr() < .000001 then direction = Vector(1, 0, 0) end
    local distance = math.Clamp(delta:Length(), math.abs(upperLength - foreLength) + .001, upperLength + foreLength - .001)
    local along = (upperLength * upperLength - foreLength * foreLength + distance * distance) / (2 * distance)
    local height = math.sqrt(math.max(0, upperLength * upperLength - along * along))
    local bend = pole - direction * pole:Dot(direction)
    if bend:LengthSqr() < .000001 then
        local axis = math.abs(direction.z) < .9 and Vector(0, 0, 1) or Vector(0, 1, 0)
        bend = axis - direction * axis:Dot(direction)
    end
    return root + direction * along + bend:GetNormalized() * height, root + direction * distance
end

-- Simple TPIK: direct bone copy (ARC9-style)

function GCAL.InstallTPIK(deps)
    deps = deps or {}
    local PlaceTPIKTrackModel = deps.PlaceTPIKTrackModel or deps.PlaceTrackModel
    local GetLegacyFlipState = deps.GetLegacyFlipState
    local GetTrackTargetBones = deps.GetTrackTargetBones
    local GetTrackModelScale = deps.GetTrackModelScale

    -- Bone lookup cache (keyed by entity, invalidated on model change)
    local boneIndexCache = setmetatable({}, { __mode = "k" })
    local childBoneCache = setmetatable({}, { __mode = "k" })

    local function GetBone(ent, name)
        if not IsValid(ent) or not name then return nil end
        local model = ent:GetModel() or ""
        local cache = boneIndexCache[ent]
        if not cache or cache.model ~= model then
            cache = { model = model, bones = {} }
            boneIndexCache[ent] = cache
        end
        local cached = cache.bones[name]
        if cached ~= nil then return cached ~= false and cached or nil end
        local idx = ent:LookupBone(name)
        cache.bones[name] = idx or false
        return idx
    end

    local function GetChildren(ent, bone)
        if not IsValid(ent) or not bone or bone < 0 then return {} end
        local model = ent:GetModel() or ""
        local cache = childBoneCache[ent]
        if not cache or cache.model ~= model then
            cache = { model = model, children = {} }
            childBoneCache[ent] = cache
        end
        local children = cache.children[bone]
        if not children then
            children = ent:GetChildBones(bone) or {}
            cache.children[bone] = children
        end
        return children
    end

    local function GetSourceModel(track)
        if track and IsValid(track.tpikModel) then return track.tpikModel end
        return track and track.model or nil
    end

    local function GetOptions(track)
        if track and istable(track.tpikOptions) then return track.tpikOptions end
        if track and GCAL.GetTPIKOptions then return GCAL:GetTPIKOptions(track.name) end
        return nil
    end

    local function Opt(track, key, ...)
        local options = GetOptions(track)
        if options and options[key] ~= nil then return options[key] end
        local data = track and track.data or nil
        for i = 1, select("#", ...) do
            local fallback = select(i, ...)
            if data and data[fallback] ~= nil then return data[fallback] end
        end
        return nil
    end

    local function OptAdd(track, key)
        if not GCAL.GetTPIKOptionAdd then return 0 end
        return GCAL:GetTPIKOptionAdd(track.name, key) or 0
    end

    -- Hidden material for the third-person model clone
    local hiddenMat = CreateMaterial("gcal_tpik_hidden", "UnlitGeneric", {
        ["$basetexture"] = "color/white",
        ["$translucent"] = "1",
        ["$alpha"] = "0",
        ["$vertexalpha"] = "1"
    })
    local hiddenMatName = hiddenMat:GetName()
    local armTokens = {
        "c_arm", "/arms", "_arms", "arm_", "forearm",
        "/hands", "_hands", "hand_", "glove", "sleeve", "player_shared"
    }

    local function ConfigureCloneMaterials(track)
        local model = track.thirdpersonModel
        if not IsValid(model) or track.thirdpersonMaterialsConfigured then return end
        track.thirdpersonMaterialsConfigured = true

        local extraHide = Opt(track, "hide_materials", "thirdperson_hide_materials")
        if isstring(extraHide) then extraHide = { extraHide } end
        local keep = Opt(track, "keep_materials", "thirdperson_keep_materials")
        if isstring(keep) then keep = { keep } end

        local visible = 0
        local autoHidden = {}
        local materials = model:GetMaterials() or {}

        for index, name in ipairs(materials) do
            local lower = string.lower(name)
            local hide = false
            local byAuto = false
            for _, token in ipairs(armTokens) do
                if string.find(lower, token, 1, true) then hide = true; byAuto = true; break end
            end
            for _, token in ipairs(extraHide or {}) do
                if string.find(lower, string.lower(tostring(token)), 1, true) then hide = true; byAuto = false; break end
            end
            for _, token in ipairs(keep or {}) do
                if string.find(lower, string.lower(tostring(token)), 1, true) then hide = false; byAuto = false; break end
            end
            if hide then
                model:SetSubMaterial(index - 1, hiddenMatName)
                if byAuto then autoHidden[#autoHidden + 1] = index - 1 end
            else
                visible = visible + 1
            end
        end

        -- If everything got hidden, restore auto-hidden ones
        if #materials > 0 and visible == 0 and #autoHidden > 0 then
            for _, idx in ipairs(autoHidden) do model:SetSubMaterial(idx) end
            visible = #autoHidden
            track.debugThirdPersonModel = "visible: material fallback"
        end
        track.thirdpersonModelHasVisibleMaterials = #materials == 0 or visible > 0
    end

    -- Third-person model clone: visual copy of the source viewmodel for props
    local function PrepareClone(track, handPos)
        local model = track.thirdpersonModel
        local source = GetSourceModel(track)
        if not IsValid(model) or Opt(track, "model", "thirdperson_model") == false then return end
        if not IsValid(source) then return end

        track.thirdpersonModelReadyFrame = nil
        track.debugThirdPersonModelDistance = nil

        ConfigureCloneMaterials(track)
        if not track.thirdpersonModelHasVisibleMaterials then return end

        local maxDist = tonumber(Opt(track, "model_max_distance", "thirdperson_model_max_distance")) or 32
        local explicitBoneName = Opt(track, "model_bone", "thirdperson_model_bone")
        local explicitBone = isstring(explicitBoneName) and GetBone(source, explicitBoneName) or nil

        local boneDist, hitboxDist
        local function Consider(bone, pos, isHitbox)
            if not handPos or not pos then return end
            if explicitBone ~= nil and bone ~= explicitBone then return end
            local d = pos:Distance(handPos)
            if isHitbox then
                hitboxDist = hitboxDist and math.min(hitboxDist, d) or d
            else
                boneDist = boneDist and math.min(boneDist, d) or d
            end
        end

        model:SetPos(source:GetPos())
        model:SetAngles(source:GetAngles())
        model:SetModelScale(1)
        model:SetSkin(source:GetSkin())
        for _, bg in ipairs(source:GetBodyGroups() or {}) do
            model:SetBodygroup(bg.id, source:GetBodygroup(bg.id))
        end
        model:SetCycle(track.cycle or 0)
        model:SetupBones()

        -- Clone offsets: whole-clone shift + per-bone tweaks
        local cloneOffsetX = (Opt(track, "clone_offset_x", "thirdperson_clone_offset_x") or 0) + (GCAL.CloneOffsetX and GCAL.CloneOffsetX:GetFloat() or 0) + OptAdd(track, "clone_offset_x")
        local cloneOffsetY = (Opt(track, "clone_offset_y", "thirdperson_clone_offset_y") or 0) + (GCAL.CloneOffsetY and GCAL.CloneOffsetY:GetFloat() or 0) + OptAdd(track, "clone_offset_y")
        local cloneOffsetZ = (Opt(track, "clone_offset_z", "thirdperson_clone_offset_z") or 0) + (GCAL.CloneOffsetZ and GCAL.CloneOffsetZ:GetFloat() or 0) + OptAdd(track, "clone_offset_z")
        local cloneOffsets = Opt(track, "model_offset")

        local copies = {}
        for bone = 0, model:GetBoneCount() - 1 do
            local src = source:GetBoneMatrix(bone) or model:GetBoneMatrix(bone)
            if src then
                copies[bone] = Matrix(src:ToTable())
                local m = copies[bone]
                local pos = m:GetTranslation()
                if cloneOffsetX ~= 0 or cloneOffsetY ~= 0 or cloneOffsetZ ~= 0 then
                    pos = pos + Vector(cloneOffsetX, cloneOffsetY, cloneOffsetZ)
                    m:SetTranslation(pos)
                end
                if cloneOffsets then
                    local boneName = model:GetBoneName(bone)
                    local boneOffset = cloneOffsets[boneName]
                    if boneOffset then
                        pos = pos + boneOffset
                        m:SetTranslation(pos)
                    end
                end
                model:SetBoneMatrix(bone, m)
                model:SetBonePosition(bone, pos, m:GetAngles())
                Consider(bone, pos, false)
            end
        end

        if model.GetHitBoxCount and model.GetHitBoxBone and model.GetHitBoxBounds then
            for hb = 0, (model:GetHitBoxCount(0) or 0) - 1 do
                local bone = model:GetHitBoxBone(hb, 0)
                local mat = bone and copies[bone]
                if mat then
                    local mins, maxs = model:GetHitBoxBounds(hb, 0)
                    if mins and maxs then Consider(bone, mat * ((mins + maxs) * 0.5), true) end
                end
            end
        end

        if handPos and maxDist > 0 then
            local dist = (hitboxDist or boneDist) and math.min(hitboxDist or math.huge, boneDist or math.huge)
            if not dist then dist = source:GetPos():Distance(handPos) end
            if dist and dist > maxDist then
                track.debugThirdPersonModel = "hidden: too far"
                track.debugThirdPersonModelDistance = dist
                return
            end
            track.debugThirdPersonModelDistance = dist
        end

        track.thirdpersonModelReadyFrame = FrameNumber()
        track.thirdpersonModelReadyTime = RealTime()
        track.debugThirdPersonModel = model:GetModel()
    end

    -- Player bones must be written while the engine is building this model's
    -- skeleton. A readable matrix alone does not make an unused bone writable.
    local function ApplyCached(track, ply)
        local matrices = track.thirdpersonBoneMatrices
        if not matrices or not IsValid(ply) then return false end
        if not ply.ixGCALBoneCallback then
            ply.ixGCALBoneCallback = ply:AddCallback("BuildBonePositions", function(ent, count)
                local state = ent.ixGCALBoneState
                if ent.ixGCALReadingBase or not state or state.frame ~= FrameNumber()
                    or state.model ~= ent:GetModel() then return end
                for bone, matrix in pairs(state.matrices) do
                    local name = bone >= 0 and bone < count and ent:GetBoneName(bone)
                    if name and name ~= "__INVALIDBONE__"
                        and ent:BoneHasFlag(bone, BONE_USED_BY_ANYTHING)
                        and ent:GetBoneMatrix(bone) then
                        ent:SetBoneMatrix(bone, matrix)
                    end
                end
            end)
        end
        ply.ixGCALBoneState = {matrices = matrices, frame = FrameNumber(), model = ply:GetModel()}
        if not ply.ixGCALBuildingPose then
            ply.ixGCALBuildingPose = true
            ply:InvalidateBoneCache()
            ply:SetupBones()
            ply.ixGCALBuildingPose = nil
        end
        return true
    end

    local function AimSegment(matrix, from, to, position)
        local a, b = from:GetNormalized(), to:GetNormalized()
        local angle = matrix:GetAngles()
        local axis = a:Cross(b)
        local dot = math.Clamp(a:Dot(b), -1, 1)
        if axis:LengthSqr() > .000001 then
            angle:RotateAroundAxis(axis:GetNormalized(), math.deg(math.acos(dot)))
        elseif dot < 0 then
            angle:RotateAroundAxis(angle:Up(), 180)
        end
        local result = Matrix(matrix:ToTable())
        result:SetTranslation(position); result:SetAngles(angle)
        return result
    end

    local function EyeWearPose(track, ply, source, targetBones, baseMatrices)
        local mapped, pose = {}, {}
        for k, name in ipairs(targetBones) do
            local src = GetBone(source, track.sourceBones and track.sourceBones[k] or track.bones[k])
            local dst = GetBone(ply, name)
            if src and dst then mapped[name] = {src = src, dst = dst} end
        end
        for _, side in ipairs({"L", "R"}) do
            local prefix = "ValveBiped.Bip01_" .. side .. "_"
            local u, f, h = mapped[prefix .. "UpperArm"], mapped[prefix .. "Forearm"], mapped[prefix .. "Hand"]
            if not u or not f or not h then continue end
            local su, sf, sh = source:GetBoneMatrix(u.src), source:GetBoneMatrix(f.src), source:GetBoneMatrix(h.src)
            local bu, bf, bh = baseMatrices[u.dst], baseMatrices[f.dst], baseMatrices[h.dst]
            if not su or not sf or not sh or not bu or not bf or not bh then continue end
            local root = bu:GetTranslation()
            local elbow, hand = GCAL.SolveArmReach(root, sh:GetTranslation(), sf:GetTranslation() - su:GetTranslation(),
                root:Distance(bf:GetTranslation()), bf:GetTranslation():Distance(bh:GetTranslation()))
            if not elbow then continue end
            pose[u.dst] = AimSegment(su, sf:GetTranslation() - su:GetTranslation(), elbow - root, root)
            pose[f.dst] = AimSegment(sf, sh:GetTranslation() - sf:GetTranslation(), hand - elbow, elbow)
            pose[h.dst] = Matrix(sh:ToTable()); pose[h.dst]:SetTranslation(hand)
            local invHand = Matrix(sh:ToTable()); invHand:Invert()
            local invFore = Matrix(sf:ToTable()); invFore:Invert()
            for name, entry in pairs(mapped) do
                if string.find(name, prefix, 1, true) and not pose[entry.dst] then
                    local matrix = source:GetBoneMatrix(entry.src)
                    if matrix then
                        local finger = string.find(name, "Finger", 1, true)
                        pose[entry.dst] = (finger and pose[h.dst] or pose[f.dst]) * (finger and invHand or invFore) * matrix
                    end
                end
            end
        end
        return pose
    end

    -- Main TPIK solve
    local function ApplyThirdPersonBones(track, ply, weapon, baseMatrices)
        local source = GetSourceModel(track)
        if not IsValid(source) or not baseMatrices then return end

        -- Reuse cached solve if already done this frame
        if track.thirdpersonSolveFrame == FrameNumber() then
            ApplyCached(track, ply)
            return
        end

        local flip = GetLegacyFlipState(weapon)
        local targetBones = GetTrackTargetBones(track, weapon, flip)
        local renderAngles = ply.GetRenderAngles and ply:GetRenderAngles() or ply:GetAngles()

        -- A pickup follows the view pitch; body render angles normally have
        -- zero pitch and turn a downward first-person reach into a raised arm.
        local sourceAngles = renderAngles
        if track.name == "ix_field_pickup" then
            sourceAngles = Angle(math.Clamp(ply:EyeAngles().p, -65, 75), renderAngles.y, renderAngles.r)
        end
        local eyeWear = string.sub(track.name or "", 1, 4) == "nvg_"
        local sourcePosition = ply:EyePos()
        if eyeWear then
            local eyes = ply:LookupAttachment("eyes")
            local attachment = eyes and eyes > 0 and ply:GetAttachment(eyes)
            if attachment then sourcePosition, sourceAngles = attachment.Pos, attachment.Ang
            else sourceAngles = ply:EyeAngles() end
        end
        PlaceTPIKTrackModel(track, sourcePosition, sourceAngles)
        source:InvalidateBoneCache()
        source:SetModelScale(GetTrackModelScale(track, weapon, flip))
        source:SetupBones()

        -- New: Check for distance fade
        local options = GetOptions(track)
        local distanceFade = options and options.distance_fade
        if distanceFade then
            local fadeStart = tonumber(options.fade_start) or 100
            local fadeEnd = tonumber(options.fade_end) or 300
            local camPos = LocalPlayer():GetPos()
            local plyPos = ply:GetPos()
            local dist = camPos:Distance(plyPos)

            if dist > fadeEnd then
                return -- Too far, don't render
            elseif dist > fadeStart then
                -- Fade blend strength based on distance
                local fadeAlpha = 1 - math.Clamp((dist - fadeStart) / (fadeEnd - fadeStart), 0, 1)
                track.distanceFadeAlpha = fadeAlpha
            else
                track.distanceFadeAlpha = 1
            end
        else
            track.distanceFadeAlpha = 1
        end

        -- Blend factor: 0 = full animation, 1 = full rest pose
        local baseLerpCurve = track.lerpCurve or (track.data and track.data.lerp_curve) or 1
        local blendCurve = tonumber(Opt(track, "blend_curve")) or baseLerpCurve
        local blend = math.Clamp(
            (track.legacyMatrixLerp and GCAL.Lerp.Legacy or Lerp)(
                track.lerpVal or 1, 0, 1,
                blendCurve
            ),
            0, 1
        )

        -- New: Apply blend strength modifier
        local blendStrength = tonumber(Opt(track, "blend_strength")) or 1
        blend = blend * blendStrength * (track.distanceFadeAlpha or 1)

        -- Spine position for clamping
        local spineIdx = GetBone(ply, "ValveBiped.Bip01_Spine4")
        local spinePos = nil
        if spineIdx then
            local m = baseMatrices[spineIdx]
            if m then spinePos = m:GetTranslation() end
        end

-- Offset viewmodel bones (camera space) to player body space via shoulder
        local shoulderOffsets = {}
        for _, side in ipairs({ "L", "R" }) do
            local name = "ValveBiped.Bip01_" .. side .. "_UpperArm"
            local srcIdx = GetBone(source, name)
            local tgtIdx = GetBone(ply, name)
            if srcIdx and srcIdx >= 0 and tgtIdx and tgtIdx >= 0 then
                local srcM = source:GetBoneMatrix(srcIdx)
                local tgtM = baseMatrices[tgtIdx]
                if srcM and tgtM then
                    shoulderOffsets[side] = tgtM:GetTranslation() - srcM:GetTranslation()
                end
            end
        end

        -- Options
        local clampRadius = tonumber(Opt(track, "target_radius", "thirdperson_target_radius")) or 38
        clampRadius = clampRadius + OptAdd(track, "target_radius")
        local smoothing = tonumber(Opt(track, "smoothing", "thirdperson_smoothing")) or 18
        smoothing = math.Clamp(smoothing + OptAdd(track, "smoothing"), 0, 60)

        -- Per-animation offsets from RegisterTPIKOptions
        local animOffsetX = tonumber(Opt(track, "offset_x")) or 0
        local animOffsetY = tonumber(Opt(track, "offset_y")) or 0
        local animOffsetZ = tonumber(Opt(track, "offset_z")) or 0

        -- Global adjustments from convars + per-animation cookies
        local tpikAdjustPos = Vector(0, 0, 0)
        local tpikAdjustAng = Angle(0, 0, 0)
        if GCAL.GetTPIKAdjustment then
            local adj = GCAL:GetTPIKAdjustment(track.name)
            if adj then
                tpikAdjustPos = adj.pos or tpikAdjustPos
                tpikAdjustAng = adj.ang or tpikAdjustAng
            end
        end
        local tpikForward = renderAngles:Forward()
        local tpikRight = renderAngles:Right()
        local tpikUp = renderAngles:Up()
        local totalOffsetX = tpikAdjustPos.x + animOffsetX
        local totalOffsetY = tpikAdjustPos.y + animOffsetY
        local totalOffsetZ = tpikAdjustPos.z + animOffsetZ
        local tpikPosDelta = tpikForward * totalOffsetX + tpikRight * totalOffsetY + tpikUp * totalOffsetZ

        -- New: Get bone-specific options
        local lockBones = Opt(track, "lock_bones") or {}
        local ignoreBones = Opt(track, "ignore_bones") or {}
        local scaleBones = Opt(track, "scale_bones") or {}
        local blendPerBone = Opt(track, "blend_per_bone") or {}

        local eyeWearPose = eyeWear and EyeWearPose(track, ply, source, targetBones, baseMatrices) or {}
        local finalMatrices = {}
        local carried = {}
        local boneCount = 0

        -- Copy each mapped bone from source to player
        for k, boneName in ipairs(track.bones) do
            local srcBoneName = track.sourceBones and track.sourceBones[k] or boneName
            local tgtBoneName = targetBones[k] or boneName
            local tgtBone = GetBone(ply, tgtBoneName)
            if not tgtBone or tgtBone < 0 then continue end

            -- New: Check ignore list
            local shouldIgnore = false
            for _, ignoreName in ipairs(ignoreBones) do
                if string.find(tgtBoneName, ignoreName, 1, true) then
                    shouldIgnore = true
                    break
                end
            end
            if shouldIgnore then continue end

            local srcBone = GetBone(source, srcBoneName)
            local isHelper = string.EndsWith(tgtBoneName, "_Wrist") or string.EndsWith(tgtBoneName, "_Ulna")
            if not srcBone or srcBone < 0 then continue end

            local retargeted = eyeWearPose[tgtBone]
            local srcMatrix = retargeted or source:GetBoneMatrix(srcBone)
            local tgtMatrix = baseMatrices[tgtBone]
            if not srcMatrix or not tgtMatrix then continue end

            -- New: Check if bone is locked (uses rest pose only)
            local isLocked = false
            for _, lockName in ipairs(lockBones) do
                if string.find(tgtBoneName, lockName, 1, true) then
                    isLocked = true
                    break
                end
            end

            if isLocked then
                finalMatrices[tgtBone] = Matrix(tgtMatrix:ToTable())
                boneCount = boneCount + 1
                continue
            end

            -- Offset, clamp, then apply user adjustment
            local side = string.find(tgtBoneName, "Bip01_R_", 1, true) and "R" or "L"
            local offset = not retargeted and shoulderOffsets[side] or Vector(0, 0, 0)
            local pos = srcMatrix:GetTranslation() + offset
            if spinePos and not retargeted then
                pos = Vector(
                    math.Clamp(pos.x, spinePos.x - clampRadius, spinePos.x + clampRadius),
                    math.Clamp(pos.y, spinePos.y - clampRadius, spinePos.y + clampRadius),
                    math.Clamp(pos.z, spinePos.z - clampRadius, spinePos.z + clampRadius)
                )
            end
            pos = pos + tpikPosDelta
            local ang = Angle(
                srcMatrix:GetAngles().p + tpikAdjustAng.p,
                srcMatrix:GetAngles().y + tpikAdjustAng.y,
                srcMatrix:GetAngles().r + tpikAdjustAng.r
            )

            -- New: Apply bone-specific scale
            local boneScale = 1
            for scaleName, scale in pairs(scaleBones) do
                if string.find(tgtBoneName, scaleName, 1, true) then
                    boneScale = tonumber(scale) or 1
                    break
                end
            end
            if boneScale ~= 1 then
                local boneBase = tgtMatrix:GetTranslation()
                pos = boneBase + (pos - boneBase) * boneScale
            end

            -- Optional per-bone smoothing
            if smoothing > 0 and not retargeted then
                track.thirdpersonTPIKSmoothing = track.thirdpersonTPIKSmoothing or {}
                local cache = track.thirdpersonTPIKSmoothing
                local entry = cache[tgtBone]
                if not entry then
                    entry = { pos = Vector(pos.x, pos.y, pos.z), ang = Angle(ang.p, ang.y, ang.r) }
                    cache[tgtBone] = entry
                else
                    local a = math.Clamp(1 - math.exp(-smoothing * RealFrameTime()), 0, 1)
                    entry.pos.x = entry.pos.x + (pos.x - entry.pos.x) * a
                    entry.pos.y = entry.pos.y + (pos.y - entry.pos.y) * a
                    entry.pos.z = entry.pos.z + (pos.z - entry.pos.z) * a
                    entry.ang.p = entry.ang.p + math.AngleDifference(ang.p, entry.ang.p) * a
                    entry.ang.y = entry.ang.y + math.AngleDifference(ang.y, entry.ang.y) * a
                    entry.ang.r = entry.ang.r + math.AngleDifference(ang.r, entry.ang.r) * a
                    pos = entry.pos
                    ang = entry.ang
                end
            end

            -- New: Apply per-bone blend override
            local finalBlend = blend
            for blendBoneName, boneBlend in pairs(blendPerBone) do
                if string.find(tgtBoneName, blendBoneName, 1, true) then
                    finalBlend = tonumber(boneBlend) or blend
                    break
                end
            end

            -- Blend between animation pose and rest pose
            local blendedPos = LerpVector(finalBlend, pos, tgtMatrix:GetTranslation())
            local blendedAng = LerpAngle(finalBlend, ang, tgtMatrix:GetAngles())

            local final = Matrix()
            final:SetTranslation(blendedPos)
            final:SetAngles(blendedAng)
            finalMatrices[tgtBone] = final
            boneCount = boneCount + 1
        end

        -- Carry unmapped children of arm bones
        local function CarryChildren(parentBone)
            if carried[parentBone] then return end
            carried[parentBone] = true
            for _, childBone in ipairs(GetChildren(ply, parentBone)) do
                if not finalMatrices[childBone] then
                    local baseParent = baseMatrices[parentBone]
                    local baseChild = baseMatrices[childBone]
                    local solvedParent = finalMatrices[parentBone]
                    if baseParent and baseChild and solvedParent then
                        local inv = Matrix(baseParent:ToTable())
                        inv:Invert()
                        finalMatrices[childBone] = solvedParent * inv * baseChild
                    end
                end
                if finalMatrices[childBone] then CarryChildren(childBone) end
            end
        end

        for _, side in ipairs({ "L", "R" }) do
            local upper = GetBone(ply, "ValveBiped.Bip01_" .. side .. "_UpperArm")
            if upper and upper >= 0 and finalMatrices[upper] then CarryChildren(upper) end
        end

        -- Apply and cache
        track.thirdpersonBoneMatrices = finalMatrices
        track.thirdpersonSolveFrame = FrameNumber()
        ApplyCached(track, ply)

        track.debugTargetEntity = tostring(ply)
        track.debugBoneCount = boneCount
        track.debugThirdPersonMode = eyeWear and "eye-anchored arm reach" or "direct"
        track.debugThirdPersonPole = "none"
        track.debugThirdPersonRootBone = track.bones[1] or nil

        -- Find hand position for the clone model
        local handPos = nil
        for _, side in ipairs({ "L", "R" }) do
            local handBone = GetBone(ply, "ValveBiped.Bip01_" .. side .. "_Hand")
            if handBone and finalMatrices[handBone] then
                handPos = finalMatrices[handBone]:GetTranslation()
                break
            end
        end
        PrepareClone(track, handPos)
    end

    return {
        ApplyCachedThirdPersonBones = ApplyCached,
        ApplyThirdPersonBones = ApplyThirdPersonBones
    }
end