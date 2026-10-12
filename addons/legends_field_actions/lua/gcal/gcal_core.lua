-- GCAL: GMod Compliant Armature Layer
-- Core Engine

GCAL = GCAL or {}
GCAL.Anims = GCAL.Anims or {}
GCAL.ActiveTracks = GCAL.ActiveTracks or {}
GCAL.ImportedFiles = GCAL.ImportedFiles or {}
GCAL.QueuedAnims = GCAL.QueuedAnims or {}
GCAL.TPIKOptions = GCAL.TPIKOptions or {}
GCAL.CamBoneHandlers = GCAL.CamBoneHandlers or {}
GCAL.CamBoneHandlerOrder = GCAL.CamBoneHandlerOrder or {}

-- Define Groups Early
GCAL.GROUPS = {
    LEFT_ARM = {
        "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand",
        "ValveBiped.Bip01_L_Wrist", "ValveBiped.Bip01_L_Ulna", "ValveBiped.Bip01_L_Finger4",
        "ValveBiped.Bip01_L_Finger41", "ValveBiped.Bip01_L_Finger42", "ValveBiped.Bip01_L_Finger3",
        "ValveBiped.Bip01_L_Finger31", "ValveBiped.Bip01_L_Finger32", "ValveBiped.Bip01_L_Finger2",
        "ValveBiped.Bip01_L_Finger21", "ValveBiped.Bip01_L_Finger22", "ValveBiped.Bip01_L_Finger1",
        "ValveBiped.Bip01_L_Finger11", "ValveBiped.Bip01_L_Finger12", "ValveBiped.Bip01_L_Finger0",
        "ValveBiped.Bip01_L_Finger01", "ValveBiped.Bip01_L_Finger02"
    },
    RIGHT_ARM = {
        "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand",
        "ValveBiped.Bip01_R_Wrist", "ValveBiped.Bip01_R_Ulna", "ValveBiped.Bip01_R_Finger4",
        "ValveBiped.Bip01_R_Finger41", "ValveBiped.Bip01_R_Finger42", "ValveBiped.Bip01_R_Finger3",
        "ValveBiped.Bip01_R_Finger31", "ValveBiped.Bip01_R_Finger32", "ValveBiped.Bip01_R_Finger2",
        "ValveBiped.Bip01_R_Finger21", "ValveBiped.Bip01_R_Finger22", "ValveBiped.Bip01_R_Finger1",
        "ValveBiped.Bip01_R_Finger11", "ValveBiped.Bip01_R_Finger12", "ValveBiped.Bip01_R_Finger0",
        "ValveBiped.Bip01_R_Finger01", "ValveBiped.Bip01_R_Finger02"
    }
}
GCAL.GROUPS.BOTH_ARMS = {}
for _, boneName in ipairs(GCAL.GROUPS.LEFT_ARM) do
    GCAL.GROUPS.BOTH_ARMS[#GCAL.GROUPS.BOTH_ARMS + 1] = boneName
end
for _, boneName in ipairs(GCAL.GROUPS.RIGHT_ARM) do
    GCAL.GROUPS.BOTH_ARMS[#GCAL.GROUPS.BOTH_ARMS + 1] = boneName
end

if CLIENT then
    GCAL.Debug = CreateClientConVar("gcal_debug", "0", true, false, "Enable GCAL debug mode.")
    GCAL.ThirdPerson = CreateClientConVar("gcal_thirdperson", "1", true, false,
        "Render GCAL arm animations on the local player in thirdperson.")
    GCAL.PlaybackSpeed = CreateClientConVar("gcal_playback_speed", "1", true, false,
        "Global GCAL playback speed multiplier.")
    GCAL.MuteSounds = CreateClientConVar("gcal_mute_sounds", "0", true, false, "Mute animation sounds emitted by GCAL.")
    GCAL.SoundPitch = CreateClientConVar("gcal_sound_pitch", "100", true, false,
        "Pitch used for animation sounds emitted by GCAL.")
    GCAL.AnimationOffsetX = CreateClientConVar("gcal_anim_offset_x", "0", true, false,
        "Global GCAL animation forward/back offset.")
    GCAL.AnimationOffsetY = CreateClientConVar("gcal_anim_offset_y", "0", true, false,
        "Global GCAL animation right/left offset.")
    GCAL.AnimationOffsetZ = CreateClientConVar("gcal_anim_offset_z", "0", true, false,
        "Global GCAL animation up/down offset.")
    GCAL.AnimationAngleP = CreateClientConVar("gcal_anim_angle_p", "0", true, false,
        "Global GCAL animation pitch offset.")
    GCAL.AnimationAngleY = CreateClientConVar("gcal_anim_angle_y", "0", true, false, "Global GCAL animation yaw offset.")
    GCAL.AnimationAngleR = CreateClientConVar("gcal_anim_angle_r", "0", true, false, "Global GCAL animation roll offset.")
    GCAL.TPIKOffsetX = CreateClientConVar("gcal_tpik_offset_x", "0", true, false,
        "Global GCAL thirdperson TPIK forward/back offset.")
    GCAL.TPIKOffsetY = CreateClientConVar("gcal_tpik_offset_y", "0", true, false,
        "Global GCAL thirdperson TPIK right/left offset.")
    GCAL.TPIKOffsetZ = CreateClientConVar("gcal_tpik_offset_z", "0", true, false,
        "Global GCAL thirdperson TPIK up/down offset.")
    GCAL.TPIKAngleP = CreateClientConVar("gcal_tpik_angle_p", "0", true, false,
        "Global GCAL thirdperson TPIK pitch offset.")
    GCAL.TPIKAngleY = CreateClientConVar("gcal_tpik_angle_y", "0", true, false,
        "Global GCAL thirdperson TPIK yaw offset.")
    GCAL.TPIKAngleR = CreateClientConVar("gcal_tpik_angle_r", "0", true, false,
        "Global GCAL thirdperson TPIK roll offset.")
    GCAL.TPIKTargetRadiusAdd = CreateClientConVar("gcal_tpik_target_radius_add", "0", true, false,
        "Global GCAL thirdperson TPIK target radius adjustment.")
    GCAL.TPIKPoleSourceAdd = CreateClientConVar("gcal_tpik_pole_source_add", "0", true, false,
        "Global GCAL thirdperson TPIK source pole blend adjustment.")
    GCAL.TPIKPoleNativeAdd = CreateClientConVar("gcal_tpik_pole_native_add", "0", true, false,
        "Global GCAL thirdperson TPIK native pole blend adjustment.")
    GCAL.TPIKSmoothingAdd = CreateClientConVar("gcal_tpik_smoothing_add", "0", true, false,
        "Global GCAL thirdperson TPIK smoothing adjustment.")
    GCAL.CamBone = CreateClientConVar("gcal_cambone", "1", true, false,
        "Enable GCAL camera bone (view angle driving from animation attachments) for all tracks.")
    GCAL.CloneOffsetX = CreateClientConVar("gcal_clone_offset_x", "0", true, false,
        "Global GCAL thirdperson model clone forward/back offset.")
    GCAL.CloneOffsetY = CreateClientConVar("gcal_clone_offset_y", "0", true, false,
        "Global GCAL thirdperson model clone right/left offset.")
    GCAL.CloneOffsetZ = CreateClientConVar("gcal_clone_offset_z", "0", true, false,
        "Global GCAL thirdperson model clone up/down offset.")
    GCAL.InternalThirdPersonEnabled = true
    GCAL.AnimationAdjustments = GCAL.AnimationAdjustments or {}

    function GCAL:IsThirdPersonEnabled()
        return self.InternalThirdPersonEnabled and self.ThirdPerson:GetBool()
    end

    local animationAdjustmentFields = {
        pos_x = true,
        pos_y = true,
        pos_z = true,
        ang_p = true,
        ang_y = true,
        ang_r = true,
        tpik_pos_x = true,
        tpik_pos_y = true,
        tpik_pos_z = true,
        tpik_ang_p = true,
        tpik_ang_y = true,
        tpik_ang_r = true,
        tpik_target_radius_add = true,
        tpik_pole_source_add = true,
        tpik_pole_native_add = true,
        tpik_smoothing_add = true,
        clone_offset_x = true,
        clone_offset_y = true,
        clone_offset_z = true
    }

    function GCAL:AnimationAdjustmentCookieKey(name, field)
        return "gcal_anim_adjust_" .. string.gsub(tostring(name), "[^%w_]", "_") .. "_" .. tostring(field)
    end

    function GCAL:GetAnimationAdjustmentValue(name, field)
        if not animationAdjustmentFields[field] then return 0 end

        name = tostring(name or "")
        local values = self.AnimationAdjustments[name]
        if values and values[field] ~= nil then return tonumber(values[field]) or 0 end

        if cookie and cookie.GetNumber then
            return cookie.GetNumber(self:AnimationAdjustmentCookieKey(name, field), 0)
        end

        return 0
    end

    function GCAL:SetAnimationAdjustmentValue(name, field, value)
        if not animationAdjustmentFields[field] then return end

        name = tostring(name or "")
        self.AnimationAdjustments[name] = self.AnimationAdjustments[name] or {}
        self.AnimationAdjustments[name][field] = tonumber(value) or 0

        if cookie and cookie.Set then
            cookie.Set(self:AnimationAdjustmentCookieKey(name, field), tostring(self.AnimationAdjustments[name][field]))
        end
    end

    function GCAL:ClearAnimationAdjustment(name)
        name = tostring(name or "")
        self.AnimationAdjustments[name] = nil

        for field in pairs(animationAdjustmentFields) do
            if cookie and cookie.Set then
                cookie.Set(self:AnimationAdjustmentCookieKey(name, field), "0")
            end
        end
    end

    function GCAL:GetAnimationAdjustment(name)
        return {
            pos = Vector(
                self.AnimationOffsetX:GetFloat() + self:GetAnimationAdjustmentValue(name, "pos_x"),
                self.AnimationOffsetY:GetFloat() + self:GetAnimationAdjustmentValue(name, "pos_y"),
                self.AnimationOffsetZ:GetFloat() + self:GetAnimationAdjustmentValue(name, "pos_z")
            ),
            ang = Angle(
                self.AnimationAngleP:GetFloat() + self:GetAnimationAdjustmentValue(name, "ang_p"),
                self.AnimationAngleY:GetFloat() + self:GetAnimationAdjustmentValue(name, "ang_y"),
                self.AnimationAngleR:GetFloat() + self:GetAnimationAdjustmentValue(name, "ang_r")
            )
        }
    end

    function GCAL:ApplyAnimationAdjustment(name, pos, ang)
        local adjustment = self:GetAnimationAdjustment(name)
        local offset = adjustment.pos
        local adjustedPos = pos + ang:Forward() * offset.x + ang:Right() * offset.y + ang:Up() * offset.z
        local angleOffset = adjustment.ang

        return adjustedPos, Angle(ang.p + angleOffset.p, ang.y + angleOffset.y, ang.r + angleOffset.r)
    end

    function GCAL:GetTPIKAdjustment(name)
        return {
            pos = Vector(
                self.TPIKOffsetX:GetFloat() + self:GetAnimationAdjustmentValue(name, "tpik_pos_x"),
                self.TPIKOffsetY:GetFloat() + self:GetAnimationAdjustmentValue(name, "tpik_pos_y"),
                self.TPIKOffsetZ:GetFloat() + self:GetAnimationAdjustmentValue(name, "tpik_pos_z")
            ),
            ang = Angle(
                self.TPIKAngleP:GetFloat() + self:GetAnimationAdjustmentValue(name, "tpik_ang_p"),
                self.TPIKAngleY:GetFloat() + self:GetAnimationAdjustmentValue(name, "tpik_ang_y"),
                self.TPIKAngleR:GetFloat() + self:GetAnimationAdjustmentValue(name, "tpik_ang_r")
            ),
            target_radius_add = self.TPIKTargetRadiusAdd:GetFloat() +
                self:GetAnimationAdjustmentValue(name, "tpik_target_radius_add"),
            smoothing_add = self.TPIKSmoothingAdd:GetFloat() +
                self:GetAnimationAdjustmentValue(name, "tpik_smoothing_add")
        }
    end

    function GCAL:GetTPIKOptionAdd(name, option)
        if option == "target_radius" then
            return self.TPIKTargetRadiusAdd:GetFloat() + self:GetAnimationAdjustmentValue(name, "tpik_target_radius_add")
        end
        if option == "smoothing" then
            return self.TPIKSmoothingAdd:GetFloat() + self:GetAnimationAdjustmentValue(name, "tpik_smoothing_add")
        end
        if option == "clone_offset_x" then
            return self.CloneOffsetX:GetFloat() + self:GetAnimationAdjustmentValue(name, "clone_offset_x")
        end
        if option == "clone_offset_y" then
            return self.CloneOffsetY:GetFloat() + self:GetAnimationAdjustmentValue(name, "clone_offset_y")
        end
        if option == "clone_offset_z" then
            return self.CloneOffsetZ:GetFloat() + self:GetAnimationAdjustmentValue(name, "clone_offset_z")
        end

        return 0
    end
end

local function GCAL_NormalizeLegacyCompatName(value)
    value = tostring(value or "")
    value = string.gsub(value, "([a-z0-9])([A-Z])", "%1_%2")
    value = string.lower(value)
    value = string.gsub(value, "^reanim[_%-]?", "")
    value = string.gsub(value, "^anim[_%-]?", "")
    value = string.gsub(value, "^gesture[_%-]?", "")
    value = string.gsub(value, "^cmt[_%-]?", "")
    value = string.gsub(value, "[_%-%s]+anim$", "")
    value = string.gsub(value, "[_%-%s]+gesture$", "")
    value = string.gsub(value, "[_%-%s]+sequence$", "")
    value = string.gsub(value, "[_%-%s]+seq$", "")
    value = string.gsub(value, "[^%w]", "")
    return value
end

local function GCAL_Log(...)
    if not CLIENT or not GCAL.Debug:GetBool() then return end
    MsgC(Color(255, 255, 0), "[GCAL DEBUG] ", Color(255, 255, 255), table.concat({ ... }, " "), "\n")
end

function GCAL:NormalizeHand(hand)
    hand = string.lower(tostring(hand or "left"))

    if hand == "right" or hand == "right_arm" or hand == "r" then
        return "right"
    end

    if hand == "both" or hand == "both_hands" or hand == "bothhands" or hand == "both_arms" or hand == "dual" then
        return "both"
    end

    if hand == "left" or hand == "left_arm" or hand == "l" or hand == "second" or hand == "second_hand" or hand == "secondhand" or hand == "offhand" then
        return "left"
    end

    return "left"
end

function GCAL:GetHandBones(hand)
    hand = self:NormalizeHand(hand)

    if hand == "right" then return self.GROUPS.RIGHT_ARM end
    if hand == "both" then return self.GROUPS.BOTH_ARMS end

    return self.GROUPS.LEFT_ARM
end

function GCAL:GetHandTrack(hand)
    hand = self:NormalizeHand(hand)

    if hand == "right" then return "right_arm" end
    if hand == "both" then return "both_arms" end

    return "left_arm"
end

-- Valid TPIK option keys
local TPIK_VALID_OPTIONS = {
    sequence = "string",
    anim = "string",
    animation = "string",
    model = "bool",
    model_bone = "string",
    model_max_distance = "number",
    hide_materials = "table",
    keep_materials = "table",
    target_radius = "number",
    smoothing = "number",
    offset_x = "number",
    offset_y = "number",
    offset_z = "number",
    model_offset = "table",
    clone_offset_x = "number",
    clone_offset_y = "number",
    clone_offset_z = "number",
    -- New: Advanced blending control
    blend_strength = "number",
    blend_curve = "number",
    blend_per_bone = "table",
    -- New: Bone-specific behavior
    lock_bones = "table",
    ignore_bones = "table",
    scale_bones = "table",
    -- New: Visual effects
    model_skin = "number",
    model_bodygroups = "table",
    model_material = "string",
    render_mode = "string",
    render_fx = "string",
    -- New: Advanced positioning
    offset_relative_to = "string",
    offset_space = "string",
    angular_offset_x = "number",
    angular_offset_y = "number",
    angular_offset_z = "number",
    -- New: Distance-based behavior
    distance_fade = "bool",
    fade_start = "number",
    fade_end = "number",
    -- New: Performance and quality
    update_rate = "number",
    interpolate = "bool",
    force_update = "bool",
    -- Deprecated (IK solver removed, these are ignored)
    pole_source = "number",
    pole_native = "number",
    thirdperson_model = "bool",
    thirdperson_model_bone = "string",
    thirdperson_model_max_distance = "number",
    thirdperson_hide_materials = "table",
    thirdperson_keep_materials = "table",
    thirdperson_target_radius = "number",
    thirdperson_smoothing = "number",
}

local TPIK_DEPRECATED_OPTIONS = {
    pole_source = "IK solver removed, option ignored",
    pole_native = "IK solver removed, option ignored",
}

function GCAL:RegisterTPIKOptions(name, options)
    if not name or not istable(options) then return false end

    local clean = {}
    for key, value in pairs(options) do
        local expected = TPIK_VALID_OPTIONS[key]
        if not expected then
            ErrorNoHaltWithStack("[GCAL] RegisterTPIKOptions: unknown option '" ..
                tostring(key) .. "' for '" .. tostring(name) .. "'\n")
            continue
        end
        if TPIK_DEPRECATED_OPTIONS[key] then
            ErrorNoHaltWithStack("[GCAL] RegisterTPIKOptions: '" ..
                tostring(key) .. "' is deprecated (" .. TPIK_DEPRECATED_OPTIONS[key] .. ")\n")
        end
        if expected == "number" then
            clean[key] = tonumber(value) or 0
        elseif expected == "bool" then
            clean[key] = tobool(value)
        elseif expected == "string" then
            clean[key] = tostring(value)
        else
            clean[key] = value
        end
    end

    self.TPIKOptions[tostring(name)] = clean
    return true
end

function GCAL:GetTPIKOptions(name)
    return self.TPIKOptions and self.TPIKOptions[tostring(name or "")] or nil
end

-- Cambone handler API. Signature: fn(id, track, ply, origin, angles, fov,
-- attachment, camAng, camAngInt, lerpVal, handler) -> origin, angles, fov

local default_properang = Angle(-79.75, 0, -90)
local default_intensity = { 1, 1, 1 }

local function DefaultCamBoneHandler(track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal)
    if not attachment or not attachment.Ang then return origin, angles, fov end
    local intensity = camAngInt or default_intensity
    -- Scale by lerp value so cambone fades in/out with the animation
    local lerpScale = 1 - (lerpVal or 0)
    -- VManip-style: full attachment delta scaled by intensity and lerp
    local camang = attachment.Ang - (camAng or default_properang)
    angles = Angle(
        angles.p + camang.p * (intensity[1] or 1) * lerpScale,
        angles.y + camang.y * (intensity[2] or 1) * lerpScale,
        angles.r + camang.r * (intensity[3] or 1) * lerpScale
    )
    return origin, angles, fov
end

function GCAL:RegisterCamBoneHandler(id, priority, fn)
    if not id or not isfunction(fn) then return false end
    priority = tonumber(priority) or 0
    self.CamBoneHandlers[id] = { id = id, priority = priority, fn = fn }
    -- Rebuild ordered list
    local order = {}
    for _, handler in pairs(self.CamBoneHandlers) do order[#order + 1] = handler end
    table.sort(order, function(a, b) return a.priority < b.priority end)
    self.CamBoneHandlerOrder = order
    return true
end

function GCAL:RemoveCamBoneHandler(id)
    if not id or not self.CamBoneHandlers[id] then return false end
    self.CamBoneHandlers[id] = nil
    local order = {}
    for _, handler in pairs(self.CamBoneHandlers) do order[#order + 1] = handler end
    table.sort(order, function(a, b) return a.priority < b.priority end)
    self.CamBoneHandlerOrder = order
    return true
end

-- Runs all registered cambone handlers in priority order
function GCAL:ComputeCamBoneView(track, ply, origin, angles, fov)
    if not track then return origin, angles, fov end
    local attachment = track.attachment
    if not attachment or not attachment.Ang then return origin, angles, fov end
    local camAng = track.camAng or default_properang
    local camAngInt = track.camAngInt or default_intensity
    local lerpVal = track.lerpVal or 1
    local handlers = self.CamBoneHandlerOrder
    if #handlers == 0 then
        return DefaultCamBoneHandler(track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal)
    end
    for _, handler in ipairs(handlers) do
        origin, angles, fov = handler.fn(handler.id, track, ply, origin, angles, fov, attachment, camAng, camAngInt,
            lerpVal, handler)
    end
    return origin, angles, fov
end

-- Default VManip-compatible cambone handler at priority 0
GCAL:RegisterCamBoneHandler("vmanip", 0,
    function(id, track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal)
        return DefaultCamBoneHandler(track, ply, origin, angles, fov, attachment, camAng, camAngInt, lerpVal)
    end)

function GCAL:PrepareAnimData(data, hand)
    if not data then return data end

    -- Normalize model path to prevent double "models/" prefix
    if data.model then
        local modelPath = tostring(data.model)
        -- Remove "models/" prefix if present, it will be added back when creating ClientsideModel
        if string.StartsWith(modelPath, "models/") then
            data.model = string.sub(modelPath, 8)
        end
    end

    hand = self:NormalizeHand(hand or data.hand or data.arm or data.bone_group or data.bonegroup)
    data.hand = hand
    data.bones = isstring(data.bones) and self:GetHandBones(data.bones) or data.bones or self:GetHandBones(hand)
    data.source_hand = data.source_hand or data.source_arm
    data.source_bones = isstring(data.source_bones) and self:GetHandBones(data.source_bones) or data.source_bones
    data.source_bones = data.source_bones or (data.source_hand and self:GetHandBones(data.source_hand)) or data.bones
    data.group_name = data.track or data.track_id or data.group_name or self:GetHandTrack(hand)
    data.block_code = data.block_code ~= nil and tobool(data.block_code) or false
    -- Per-animation cambone toggle. nil = use global convar.
    if data.cambone ~= nil then
        data.cambone = tobool(data.cambone)
    end

    -- New: Callback support
    data.on_start = data.on_start or data.onstart or data.OnStart
    data.on_finish = data.on_finish or data.onfinish or data.OnFinish
    data.on_interrupt = data.on_interrupt or data.oninterrupt or data.OnInterrupt
    data.on_cycle = data.on_cycle or data.oncycle or data.OnCycle

    -- New: Advanced timing control
    data.ease_in_time = data.ease_in_time or data.easeintime
    data.ease_out_time = data.ease_out_time or data.easeouttime
    data.delay_start = data.delay_start or data.delaystart or 0

    -- New: Conditional playback
    data.play_condition = data.play_condition or data.playcondition or data.condition
    data.can_interrupt = data.can_interrupt ~= nil and tobool(data.can_interrupt) or true

    -- New: Visual effects
    data.viewmodel_fov = data.viewmodel_fov or data.vm_fov or data.fov
    data.viewmodel_offset = data.viewmodel_offset or data.vm_offset
    data.screen_shake = data.screen_shake or data.screenshake

    -- New: Sound enhancements
    data.sound_volume = data.sound_volume or data.soundvolume or 75
    data.sound_level = data.sound_level or data.soundlevel or 75
    data.sound_flags = data.sound_flags or data.soundflags or 0

    -- New: Blend modes
    data.blend_mode = data.blend_mode or data.blendmode or "normal"
    data.blend_weight = data.blend_weight or data.blendweight

    -- New: Model manipulation
    data.model_scale = data.model_scale or data.modelscale
    data.model_skin = data.model_skin or data.modelskin
    data.model_bodygroups = data.model_bodygroups or data.modelbodygroups

    -- New: Advanced flags
    data.disable_pred = data.disable_pred ~= nil and tobool(data.disable_pred) or false
    data.local_only = data.local_only ~= nil and tobool(data.local_only) or false

    return data
end

-- Push live-edited fields from a re-registered anim onto the active track
local function RefreshActiveTrack(track, data)
    if not IsValid(track.model) then return end
    track.data = data
    track.bones = data.bones or GCAL.GROUPS.LEFT_ARM
    track.sourceBones = data.source_bones or data.bones or GCAL.GROUPS.LEFT_ARM
    track.speed = data.speed or 1

    -- Check for legacy matrix lerp based on easing mode
    local easingInName = data.easing_in or "OutQuad"
    local easingOutName = data.easing_out or "OutQuad"
    local legacyMatrixLerp = easingInName == "Legacy" or easingOutName == "Legacy"

    track.thirdperson = GCAL.InternalThirdPersonEnabled and data.thirdperson ~= false
    track.lerpCurve = data.lerp_curve or 1
    track.legacyMatrixLerp = legacyMatrixLerp
    track.lerpSpeedIn = data.lerp_speed_in or 1
    track.lerpSpeedOut = data.lerp_speed_out or 1
    track.easingIn = GCAL.Lerp.Get(easingInName == "Legacy" and "OutQuad" or easingInName)
    track.easingOut = GCAL.Lerp.Get(easingOutName == "Legacy" and "OutQuad" or easingOutName)
    track.lerpPeak = data.lerp_peak or 0.5

    if data.locktoply ~= nil then
        track.lockZ = data.locktoply and EyePos().z or 0
    end
    if data.loop ~= nil then track.loop = data.loop end
    if data.holdtime ~= nil then
        track.holdTimeData = data.holdtime
        if data.holdtime and not track.holdTime then
            track.holdTime = track.startTime + data.holdtime
        end
    end

    -- Update callbacks
    track.canInterrupt = data.can_interrupt ~= false
    track.onStartCallback = data.on_start
    track.onFinishCallback = data.on_finish
    track.onInterruptCallback = data.on_interrupt
    track.onCycleCallback = data.on_cycle

    -- Update visual effects
    track.viewmodelFov = data.viewmodel_fov
    track.viewmodelOffset = data.viewmodel_offset
    track.screenShake = data.screen_shake

    -- Update sound settings
    track.soundVolume = data.sound_volume or 75
    track.soundLevel = data.sound_level or 75
    track.soundFlags = data.sound_flags or 0

    -- Update blend settings
    track.blendMode = data.blend_mode or "normal"
    track.blendWeight = data.blend_weight

    -- Update model settings
    track.modelScale = data.model_scale
    track.modelSkin = data.model_skin
    track.modelBodygroups = data.model_bodygroups

    -- Update TPIK options
    local oldTpikSeqID = track.tpikSeqID
    track.tpikOptions = GetTPIKOptionsForAnim(track.name)
    track.tpikSequenceRequested = GetTPIKSequenceName(track.name)

    -- Re-resolve TPIK sequence and update model if changed
    if track.tpikSequenceRequested then
        track.tpikSeqID, track.tpikSequenceName = ResolveTPIKSequence(track, track.name, data)
        if IsValid(track.tpikModel) and track.tpikSeqID and track.tpikSeqID ~= -1 and oldTpikSeqID ~= track.tpikSeqID then
            track.tpikModel:ResetSequence(track.tpikSeqID)
        end
    end

    -- Also update thirdperson model sequence if TPIK changed
    if IsValid(track.thirdpersonModel) and oldTpikSeqID ~= track.tpikSeqID then
        track.thirdpersonModel:ResetSequence(track.tpikSeqID or track.seqID)
    end

    -- Update other control flags
    track.blockCode = data.block_code or false
    track.blockCodeScope = data.block_code_scope
    track.preventQuit = data.preventquit or false
    track.segmented = data.segmented or false
    track.camboneEnabled = (data.cambone == nil) or tobool(data.cambone)
    track.camAng = data.cam_ang or properang
    track.camAngInt = data.cam_angint or tableintensity

    -- Clear thirdperson cache to force rebuild with new settings
    track.thirdpersonMaterialsConfigured = nil
    track.thirdpersonBoneMatrices = nil
    track.thirdpersonSolveFrame = nil
    track.thirdpersonModelReadyFrame = nil
end

-- Register or re-register an animation. Accepts GCAL:RegisterAnim(name, data) or GCAL:RegisterAnim(self, name, data)
function GCAL:RegisterAnim(arg1, arg2, arg3)
    local name, data
    if isstring(arg1) then
        name, data = arg1, arg2
    else
        name, data = arg2, arg3
    end
    if not name or not data then return end

    self:PrepareAnimData(data)
    data.addon_name = data.addon_name or data.addon or data.source_addon or GCAL.CurrentRegistrationSource or "GCAL"
    GCAL_Log("Registering animation:", name)
    self.Anims[name] = data

    for trackID, track in pairs(self.ActiveTracks or {}) do
        if track.name == name then
            RefreshActiveTrack(track, data)
            break
        end
    end
end

GCAL.RegisterAnim = GCAL.RegisterAnim

function GCAL:RegisterHandAnim(name, hand, data)
    if not name or not data then return end

    data.hand = hand
    return self:RegisterAnim(name, data)
end

function GCAL:RegisterSecondHandAnim(name, data)
    return self:RegisterHandAnim(name, "left", data)
end

function GCAL:RegisterRightHandAnim(name, data)
    return self:RegisterHandAnim(name, "right", data)
end

function GCAL:RegisterBothHandsAnim(name, data)
    return self:RegisterHandAnim(name, "both", data)
end

function GCAL:PlayHand(name, hand, trackID)
    return self:Play(name, trackID or self:GetHandTrack(hand))
end

function GCAL:PlaySecondHand(name, trackID)
    return self:PlayHand(name, "left", trackID)
end

function GCAL:GetAnim(name)
    return self.Anims[name]
end

function GCAL:GetTrack(trackID)
    return self.ActiveTracks[trackID]
end

function GCAL:IsTrackActive(trackID)
    local track = self:GetTrack(trackID)
    return track ~= nil and (not CLIENT or IsValid(track.model))
end

function GCAL:GetCurrentAnim(trackID)
    local track = self:GetTrack(trackID)
    return track and track.name
end

function GCAL:GetLerp(trackID)
    local track = self:GetTrack(trackID)
    return track and track.lerpVal or 0
end

function GCAL:GetCycle(trackID)
    local track = self:GetTrack(trackID)
    return track and track.cycle or 0
end

function GCAL:SetCycle(trackID, cycle)
    local track = self:GetTrack(trackID)
    if not track then return false end

    track.cycle = cycle
    return true
end

function GCAL:IsSegmented(trackID)
    local track = self:GetTrack(trackID)
    return track and track.segmented or false
end

function GCAL:GetCurrentSegment(trackID)
    local track = self:GetTrack(trackID)
    return track and track.curSegment
end

function GCAL:GetSegmentCount(trackID)
    local track = self:GetTrack(trackID)
    return track and track.segmentCount or 0
end

function GCAL:IsPreventQuit(trackID)
    local track = self:GetTrack(trackID)
    return track and track.preventQuit or false
end

function GCAL:IsCodeBlocked(scope)
    for _, track in pairs(self.ActiveTracks or {}) do
        if track.blockCode and (scope == nil or track.blockCodeScope == nil or track.blockCodeScope == scope) then
            return true, track
        end
    end

    return false, nil
end

function GCAL:GetCodeBlockers(scope)
    local blockers = {}

    for trackID, track in pairs(self.ActiveTracks or {}) do
        if track.blockCode and (scope == nil or track.blockCodeScope == nil or track.blockCodeScope == scope) then
            blockers[trackID] = track
        end
    end

    return blockers
end

-- Native equivalents to legacy VManip globals/functions

function GCAL:GetGestureModel(trackID)
    local track = self:GetTrack(trackID)
    return track and track.model or nil
end

function GCAL:GetCamModel(trackID)
    local track = self:GetTrack(trackID)
    return track and track.camModel or nil
end

function GCAL:GetTPIKModel(trackID)
    local track = self:GetTrack(trackID)
    return track and track.tpikModel or nil
end

function GCAL:GetAllGestureModels()
    local out = {}
    for trackID, track in pairs(self.ActiveTracks or {}) do
        if trackID ~= "legs" and IsValid(track.model) then
            out[trackID] = track.model
        end
    end
    return out
end

function GCAL:GetAnimationNames()
    local out = {}
    for name in pairs(self.Anims or {}) do
        out[#out + 1] = name
    end
    return out
end

function GCAL:GetActiveTrackIDs()
    local out = {}
    for trackID in pairs(self.ActiveTracks or {}) do
        out[#out + 1] = trackID
    end
    return out
end

function GCAL:IsLooping(trackID)
    local track = self:GetTrack(trackID)
    return track ~= nil and track.loop == true
end

function GCAL:GetTrackDuration(trackID)
    local track = self:GetTrack(trackID)
    return track and track.duration or nil
end

function GCAL:StopAllTracks()
    for trackID in pairs(self.ActiveTracks or {}) do
        self:StopTrack(trackID)
    end
end

if CLIENT then
    local EyeAngles = EyeAngles
    local EyePos = EyePos

    local curtime = 0
    local scalevec = Vector(1, 1, 1)
    local scaleflipvec = Vector(1, 1, -1)
    local properang = Angle(-79.750, 0, -90)
    local tableintensity = { 1, 1, 1 }
    local angleFlip = Angle(180, 0, 0)
    local angleZero = Angle(0, 0, 0)

    local SyncLegacyVManipFields

    -- Helper function to normalize model paths and prevent double "models/" prefix
    local function NormalizeModelPath(modelPath)
        if not modelPath then return "" end

        modelPath = tostring(modelPath)

        -- Remove any leading "models/" prefix
        if string.StartsWith(modelPath, "models/") then
            modelPath = string.sub(modelPath, 8) -- Remove "models/"
        end

        -- Always return with "models/" prefix
        return "models/" .. modelPath
    end

    local function ResolveSequence(track, animName, anim)
        local candidates = {}
        local seen = {}

        local function AddCandidate(sequenceName, reason)
            sequenceName = tostring(sequenceName or "")
            if sequenceName == "" or seen[sequenceName] then return end

            seen[sequenceName] = true
            candidates[#candidates + 1] = {
                name = sequenceName,
                reason = reason
            }
        end

        AddCandidate(animName, "animation name")
        AddCandidate(anim.sequence, "explicit sequence")

        if anim.legacy then
            local lowerAnimName = string.lower(tostring(animName or ""))
            if lowerAnimName ~= tostring(animName or "") then
                AddCandidate(lowerAnimName, "lowercase animation name")
            end

            local modelBaseName = string.GetFileFromFilename(anim.model or "")
            modelBaseName = string.StripExtension(modelBaseName)

            if string.StartsWith(modelBaseName, "c_vmanip") then
                AddCandidate(string.sub(modelBaseName, 9), "model filename")
            end

            if track.model.GetSequenceList then
                local sequenceList = track.model:GetSequenceList() or {}

                local function NormalizeLegacyName(value)
                    value = string.lower(tostring(value or ""))
                    value = string.gsub(value, "^reanim[_%-]?", "")
                    value = string.gsub(value, "^anim[_%-]?", "")
                    value = string.gsub(value, "^gesture[_%-]?", "")
                    value = string.gsub(value, "[_%-%s]+anim$", "")
                    value = string.gsub(value, "[_%-%s]+gesture$", "")
                    value = string.gsub(value, "[_%-%s]+sequence$", "")
                    value = string.gsub(value, "[_%-%s]+seq$", "")
                    value = string.gsub(value, "[^%w]", "")
                    return value
                end

                local function GetLegacyTokens(value)
                    value = tostring(value or "")
                    value = string.gsub(value, "([a-z0-9])([A-Z])", "%1_%2")
                    value = string.lower(value)

                    local tokens = {}
                    for token in string.gmatch(value, "[%w]+") do
                        if token ~= "" then
                            tokens[#tokens + 1] = token
                        end
                    end

                    return tokens
                end

                local ignoredLegacyTokens = {
                    anim = true,
                    animation = true,
                    gesture = true,
                    sequence = true,
                    seq = true,
                    reanim = true,
                    vmanip = true,
                    vm = true,
                    cmt = true
                }

                local function AddTokenSubsequenceTargets(value, addTarget)
                    local tokens = GetLegacyTokens(value)
                    if #tokens == 0 then return end

                    for startIndex = 1, #tokens do
                        for endIndex = #tokens, startIndex, -1 do
                            local subset = {}
                            for tokenIndex = startIndex, endIndex do
                                local token = tokens[tokenIndex]
                                if not ignoredLegacyTokens[token] then
                                    subset[#subset + 1] = token
                                end
                            end

                            if #subset > 0 then
                                addTarget(table.concat(subset, ""))
                            end
                        end
                    end
                end

                local normalizedTargets = {}
                local function AddNormalizedTarget(value)
                    local normalized = NormalizeLegacyName(value)
                    if normalized ~= "" then
                        normalizedTargets[normalized] = true
                    end
                end

                AddNormalizedTarget(animName)
                AddNormalizedTarget(anim.sequence)
                AddTokenSubsequenceTargets(animName, AddNormalizedTarget)
                AddTokenSubsequenceTargets(anim.sequence, AddNormalizedTarget)

                if string.StartsWith(modelBaseName, "c_vmanip") then
                    AddNormalizedTarget(string.sub(modelBaseName, 9))
                end
                AddTokenSubsequenceTargets(modelBaseName, AddNormalizedTarget)

                local normalizedMatches = {}
                local partialNormalizedMatches = {}
                local seenPartialMatches = {}
                for _, sequenceName in ipairs(sequenceList) do
                    local normalizedSequenceName = NormalizeLegacyName(sequenceName)
                    if normalizedTargets[normalizedSequenceName] then
                        normalizedMatches[#normalizedMatches + 1] = sequenceName
                    else
                        for normalizedTarget in pairs(normalizedTargets) do
                            if #normalizedTarget >= 4 and (
                                    string.find(normalizedSequenceName, normalizedTarget, 1, true) or
                                    string.find(normalizedTarget, normalizedSequenceName, 1, true)
                                ) then
                                if not seenPartialMatches[sequenceName] then
                                    partialNormalizedMatches[#partialNormalizedMatches + 1] = sequenceName
                                    seenPartialMatches[sequenceName] = true
                                end
                                break
                            end
                        end
                    end
                end

                if #normalizedMatches == 1 then
                    AddCandidate(normalizedMatches[1], "normalized legacy match")
                elseif #partialNormalizedMatches == 1 then
                    AddCandidate(partialNormalizedMatches[1], "partial normalized legacy match")
                end

                if #sequenceList == 1 then
                    AddCandidate(sequenceList[1], "only model sequence")
                end
            end
        end

        for _, candidate in ipairs(candidates) do
            local seqID = track.model:LookupSequence(candidate.name)
            if seqID ~= -1 then
                if candidate.name ~= animName then
                    GCAL_Log("Sequence resolver: using '" ..
                        tostring(candidate.name) ..
                        "' from " .. tostring(candidate.reason) .. " for '" .. tostring(animName) .. "'.")
                end
                return seqID, candidate.name
            end
        end

        -- If all candidates failed, log what was attempted for debugging
        GCAL_Log("Sequence resolution failed for '" .. tostring(animName) .. "'")
        GCAL_Log("  Model: " .. tostring(track.model:GetModel()))
        GCAL_Log("  Tried candidates:")
        for _, candidate in ipairs(candidates) do
            GCAL_Log("    - '" .. candidate.name .. "' from " .. candidate.reason)
        end

        -- Try to get the sequence list to help debug
        if track.model.GetSequenceList then
            local sequenceList = track.model:GetSequenceList() or {}
            if #sequenceList > 0 then
                GCAL_Log("  Model has " .. #sequenceList .. " sequences:")
                for i, seqName in ipairs(sequenceList) do
                    GCAL_Log("    [" .. i .. "] " .. seqName)
                    -- Try case-insensitive match as last resort
                    for _, candidate in ipairs(candidates) do
                        if string.lower(seqName) == string.lower(candidate.name) then
                            GCAL_Log("  Found case-insensitive match! Using '" .. seqName .. "'")
                            local seqID = track.model:LookupSequence(seqName)
                            if seqID ~= -1 then
                                return seqID, seqName
                            end
                        end
                    end
                end
            else
                GCAL_Log("  WARNING: GetSequenceList() returned 0 sequences!")
                GCAL_Log("  This usually means the model hasn't finished loading.")
            end
        else
            GCAL_Log("  WARNING: Model does not have GetSequenceList() method!")
        end

        return -1, nil
    end

    local function GetTPIKOptionsForAnim(animName)
        return GCAL.GetTPIKOptions and GCAL:GetTPIKOptions(animName) or nil
    end

    local function GetTPIKSequenceName(animName)
        local options = GetTPIKOptionsForAnim(animName)
        if not options then return nil end

        return options.sequence or options.anim or options.animation
    end

    local function ResolveTPIKSequence(track, animName, anim)
        local sequenceName = GetTPIKSequenceName(animName)
        sequenceName = sequenceName and tostring(sequenceName) or ""
        if sequenceName == "" then return track.seqID, track.sequenceName end

        local tpikAnim = table.Copy(anim)
        tpikAnim.sequence = sequenceName
        return ResolveSequence(track, sequenceName, tpikAnim)
    end

    local function FindLegacySurrogateAnim(name, currentAnim)
        local target = GCAL_NormalizeLegacyCompatName(name)
        if target == "" then return nil end

        local exactMatch
        local partialMatch

        for otherName, otherAnim in pairs(GCAL.Anims or {}) do
            if otherName ~= name and otherAnim and otherAnim.model then
                local normalizedOther = GCAL_NormalizeLegacyCompatName(otherName)
                if normalizedOther ~= "" then
                    if normalizedOther == target then
                        exactMatch = {
                            name = otherName,
                            data = otherAnim
                        }
                        break
                    end

                    if not partialMatch and (
                            (#target >= 4 and string.find(normalizedOther, target, 1, true)) or
                            (#normalizedOther >= 4 and string.find(target, normalizedOther, 1, true))
                        ) then
                        partialMatch = {
                            name = otherName,
                            data = otherAnim
                        }
                    end
                end
            end
        end

        return exactMatch or partialMatch
    end

    -- Build the runtime track table from a registered anim.
    local function CreateTrack(name, anim)
        local easingInName = anim.easing_in or "OutQuad"
        local easingOutName = anim.easing_out or "OutQuad"
        local legacyMatrixLerp = easingInName == "Legacy" or easingOutName == "Legacy"
        local delayStart = tonumber(anim.delay_start) or 0

        return {
            name = name,
            data = anim,
            startTime = CurTime() + delayStart,
            realStartTime = CurTime(),
            delayStart = delayStart,
            cycle = anim.startcycle or 0,
            lerpVal = 1, -- 1 = weapon pose, 0 = full animation
            model = ClientsideModel(NormalizeModelPath(anim.model), RENDERGROUP_BOTH),
            camboneEnabled = (anim.cambone == nil) or tobool(anim.cambone),
            camModel = nil,
            speed = anim.speed or 1,
            lerpSpeedIn = anim.lerp_speed_in or 1,
            lerpSpeedOut = anim.lerp_speed_out or 1,
            easingIn = GCAL.Lerp.Get(easingInName == "Legacy" and "OutQuad" or easingInName),
            easingOut = GCAL.Lerp.Get(easingOutName == "Legacy" and "OutQuad" or easingOutName),
            lerpPeak = anim.lerp_peak or 0.5,
            lerpPeakTime = CurTime() + delayStart + (anim.lerp_peak or 0.5),
            legacyMatrixLerp = legacyMatrixLerp,
            lerpCurve = anim.lerp_curve or 1,
            holdTime = anim.holdtime and (CurTime() + delayStart + anim.holdtime) or nil,
            holdTimeData = anim.holdtime,
            holdQuit = false,
            gestureOnHold = false,
            gesturePastHold = false,
            blockCode = anim.block_code or false,
            blockCodeScope = anim.block_code_scope,
            preventQuit = anim.preventquit or false,
            loop = anim.loop or false,
            segmented = anim.segmented or false,
            segmentFinished = false,
            curSegment = nil,
            lastSegment = false,
            segmentCount = 0,
            camAng = anim.cam_ang or properang,
            camAngInt = anim.cam_angint or tableintensity,
            lockZ = anim.locktoply and EyePos().z or 0,
            attachment = nil,
            bones = anim.bones or GCAL.GROUPS.LEFT_ARM,
            sourceBones = anim.source_bones or anim.bones or GCAL.GROUPS.LEFT_ARM,
            soundsPlayed = {},
            thirdperson = GCAL.InternalThirdPersonEnabled and anim.thirdperson ~= false,
            tpikOptions = GetTPIKOptionsForAnim(name),
            tpikSequenceRequested = GetTPIKSequenceName(name),
            lastLerpVal = 1,
            legacyStarted = false,
            poseOnlyLegacy = false,
            -- New: Callbacks
            canInterrupt = anim.can_interrupt ~= false,
            onStartCallback = anim.on_start,
            onFinishCallback = anim.on_finish,
            onInterruptCallback = anim.on_interrupt,
            onCycleCallback = anim.on_cycle,
            lastCycleTrigger = 0,
            -- New: Visual effects
            viewmodelFov = anim.viewmodel_fov,
            viewmodelOffset = anim.viewmodel_offset,
            screenShake = anim.screen_shake,
            -- New: Sound settings
            soundVolume = anim.sound_volume or 75,
            soundLevel = anim.sound_level or 75,
            soundFlags = anim.sound_flags or 0,
            -- New: Blend settings
            blendMode = anim.blend_mode or "normal",
            blendWeight = anim.blend_weight,
            -- New: Model settings
            modelScale = anim.model_scale,
            modelSkin = anim.model_skin,
            modelBodygroups = anim.model_bodygroups,
        }
    end

    -- Make a ClientsideModel for the source viewmodel and its cambone clone.
    local function SetupSourceModels(track, anim)
        if not IsValid(track.model) then
            GCAL_Log("Failed: Invalid model path: models/" .. tostring(anim.model))
            return false
        end
        track.model:SetNoDraw(true)
        -- Force the model to initialize by setting up bones
        track.model:SetupBones()

        -- Apply model manipulation parameters
        if track.modelScale then
            track.model:SetModelScale(track.modelScale)
        end
        if track.modelSkin then
            track.model:SetSkin(track.modelSkin)
        end
        if track.modelBodygroups then
            for bg, value in pairs(track.modelBodygroups) do
                track.model:SetBodygroup(bg, value)
            end
        end

        if track.camboneEnabled and GCAL.CamBone:GetBool() and not IsValid(track.camModel) then
            track.camModel = ClientsideModel(NormalizeModelPath(anim.model), RENDERGROUP_BOTH)
        end
        if IsValid(track.camModel) then
            track.camModel:SetNoDraw(true)
            -- Place at origin so the attachment is read in the model's local space
            track.camModel:SetPos(vector_origin)
            track.camModel:SetAngles(angle_zero)
            track.camModel:SetupBones()

            -- Apply model manipulation to camModel
            if track.modelScale then
                track.camModel:SetModelScale(track.modelScale)
            end
            if track.modelSkin then
                track.camModel:SetSkin(track.modelSkin)
            end
            if track.modelBodygroups then
                for bg, value in pairs(track.modelBodygroups) do
                    track.camModel:SetBodygroup(bg, value)
                end
            end
        end
        return true
    end

    -- Find a legacy surrogate animation and swap the track's model/camModel to it.
    local function TryLegacySurrogate(track, name, anim, sequenceList)
        local surrogate = FindLegacySurrogateAnim(name, anim)
        if not surrogate then return false end

        local surrogateModel = ClientsideModel(NormalizeModelPath(surrogate.data.model), RENDERGROUP_BOTH)
        local surrogateCamModel = nil
        if track.camboneEnabled and GCAL.CamBone:GetBool() then
            surrogateCamModel = ClientsideModel(NormalizeModelPath(surrogate.data.model), RENDERGROUP_BOTH)
        end

        if IsValid(surrogateModel) then surrogateModel:SetNoDraw(true) end
        if IsValid(surrogateCamModel) then
            surrogateCamModel:SetNoDraw(true)
            surrogateCamModel:SetPos(vector_origin)
            surrogateCamModel:SetAngles(angle_zero)
        end

        local surrogateTrack = { model = surrogateModel, data = surrogate.data }
        local seqID, _ = ResolveSequence(surrogateTrack, surrogate.name, surrogate.data)
        if seqID == -1 then
            if IsValid(surrogateModel) then surrogateModel:Remove() end
            if IsValid(surrogateCamModel) then surrogateCamModel:Remove() end
            return false
        end

        if IsValid(track.model) then track.model:Remove() end
        if IsValid(track.camModel) then track.camModel:Remove() end
        track.model = surrogateModel
        track.camModel = surrogateCamModel
        track.seqID = seqID
        track.sequenceName = surrogate.data.sequence or surrogate.name

        track.model:ResetSequenceInfo()
        track.model:SetPlaybackRate(1)
        track.model:ResetSequence(track.seqID)
        track.duration = math.max(track.model:SequenceDuration(track.seqID), 0.01)
        if IsValid(track.camModel) then
            track.camModel:ResetSequenceInfo()
            track.camModel:SetPlaybackRate(1)
            track.camModel:ResetSequence(track.seqID)
        end
        GCAL_Log("Legacy fallback: using surrogate animation '" .. tostring(surrogate.name) .. "' for '" .. tostring(name) .. "'.")
        return true
    end

    -- Fall back to pose-only mode when a legacy anim has no sequences and no surrogate.
    local function UsePoseOnlyLegacy(track, name, anim)
        track.poseOnlyLegacy = true
        track.duration = math.max(anim.duration or anim.holdtime or anim.lerp_peak or 1, 0.01)
        GCAL_Log("Legacy fallback: using pose-only mode for '" .. tostring(name) .. "' because the model reported zero sequences.")
    end

    -- Resolve the firstperson sequence and prepare the source model.
    local function ResolveFirstPersonSequence(track, name, anim)
        local sequenceList = track.model.GetSequenceList and (track.model:GetSequenceList() or {}) or {}
        track.seqID, track.sequenceName = ResolveSequence(track, name, anim)

        if track.seqID ~= -1 then
            track.model:ResetSequenceInfo()
            track.model:SetPlaybackRate(1)
            track.model:ResetSequence(track.seqID)
            track.duration = math.max(track.model:SequenceDuration(track.seqID), 0.01)
            if IsValid(track.camModel) then
                track.camModel:ResetSequenceInfo()
                track.camModel:SetPlaybackRate(1)
                track.camModel:ResetSequence(track.seqID)
            end
            return
        end

        if anim.legacy and #sequenceList == 0 then
            if TryLegacySurrogate(track, name, anim, sequenceList) then return end
            UsePoseOnlyLegacy(track, name, anim)
            return
        end

        GCAL_Log("Failed: Sequence not found in model!")
        track.model:Remove()
        if IsValid(track.camModel) then track.camModel:Remove() end
        error("GCAL_Play_NoSequence")
    end

    -- Resolve the TPIK sequence and build the thirdperson model + clone.
    local function SetupThirdPerson(track, name, anim)
        track.tpikSeqID, track.tpikSequenceName = ResolveTPIKSequence(track, name, anim)
        if track.tpikSeqID == -1 then
            GCAL_Log("TPIK sequence not found, falling back to firstperson sequence for:", name)
            track.tpikSeqID = track.seqID
            track.tpikSequenceName = track.sequenceName
        end

        if not track.thirdperson then return end

        if track.tpikSeqID ~= track.seqID or track.tpikSequenceRequested then
            track.tpikModel = ClientsideModel(track.model:GetModel(), RENDERGROUP_BOTH)
            if IsValid(track.tpikModel) then
                track.tpikModel:SetNoDraw(true)
                track.tpikModel:ResetSequenceInfo()
                track.tpikModel:SetPlaybackRate(1)
                track.tpikModel:ResetSequence(track.tpikSeqID)
                track.tpikModel:SetCycle(track.cycle)

                -- Apply model manipulation to tpikModel
                if track.modelScale then
                    track.tpikModel:SetModelScale(track.modelScale)
                end
                if track.modelSkin then
                    track.tpikModel:SetSkin(track.modelSkin)
                end
                if track.modelBodygroups then
                    for bg, value in pairs(track.modelBodygroups) do
                        track.tpikModel:SetBodygroup(bg, value)
                    end
                end
            end
        end

        track.thirdpersonModel = ClientsideModel(track.model:GetModel(), RENDERGROUP_BOTH)
        if IsValid(track.thirdpersonModel) then
            track.thirdpersonModel:SetNoDraw(true)
            track.thirdpersonModel:ResetSequenceInfo()
            track.thirdpersonModel:SetPlaybackRate(1)
            track.thirdpersonModel:ResetSequence(track.tpikSeqID or track.seqID)

            -- Apply model manipulation to thirdpersonModel
            if track.modelScale then
                track.thirdpersonModel:SetModelScale(track.modelScale)
            end
            if track.modelSkin then
                track.thirdpersonModel:SetSkin(track.modelSkin)
            end
            if track.modelBodygroups then
                for bg, value in pairs(track.modelBodygroups) do
                    track.thirdpersonModel:SetBodygroup(bg, value)
                end
            end
        end
    end

-- Pre-flight guard for legacy VManip animations
    local function LegacyAnimAllowed(name, trackID, anim)
        if not anim.legacy then return true end

        vmatrixpeakinfo = anim.lerp_peak or 0.5
        VManip_modelname = anim.model
        vmanipholdtime = anim.holdtime or 0

        local ply = LocalPlayer()
        if not IsValid(ply) or ply:InVehicle() or not ply:Alive() then return false end
        if ply:GetViewEntity() ~= ply and not GCAL.ActiveTracks[trackID] then return false end

        local weapon = ply:GetActiveWeapon()
        if not IsValid(weapon) then return false end
        if weapon:GetHoldType() == "duel" then return false end
        if GCAL.ActiveTracks[trackID] then return false end

        local vm = ply:GetViewModel()
        local bypass = hook.Run("VManipPreActCheck", name, vm)
        if bypass or not IsValid(vm) then return true end

        if type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return false end
        local cycle = math.Round(vm:GetCycle(), 2)
        if vm:GetSequenceActivity(vm:GetSequence()) == ACT_VM_RELOAD and (cycle < 0.99 and cycle > 0) then return false end
        return true
    end

    -- Resolve which (name, trackID) the caller asked us to play.
    local function ParsePlayArgs(arg1, arg2)
        if isstring(arg1) then return arg1, arg2 end
        return arg2, nil -- GCAL:Play(self, "name")
    end

    function GCAL:Play(arg1, arg2)
        local name, trackID = ParsePlayArgs(arg1, arg2)
        GCAL_Log("Attempting to play:", name)

        if GCAL.IsAnimEnabled and not GCAL:IsAnimEnabled(name) then
            GCAL_Log("Suppressed: Animation '" .. tostring(name) .. "' is disabled in the GCAL menu.")
            hook.Run("GCALAnimSuppressed", name, trackID)
            return true
        end

        local anim = GCAL.Anims[name]
        if not anim then
            GCAL_Log("Failed: Animation '" .. tostring(name) .. "' not found in registry!")
            return false
        end
        if not anim.model then
            GCAL_Log("Failed: Animation '" .. tostring(name) .. "' has no model set!")
            return false
        end

        trackID = trackID or anim.group_name or "default"

        -- New: Check play condition
        if anim.play_condition and isfunction(anim.play_condition) then
            if not anim.play_condition(name, trackID, anim) then
                GCAL_Log("Suppressed: play_condition returned false for '" .. tostring(name) .. "'")
                return false
            end
        end

        if not LegacyAnimAllowed(name, trackID, anim) then return false end
        if hook.Run("VManipPrePlayAnim", name) == false then return false end

        -- New: Queue system - check if current track can be interrupted
        local existingTrack = GCAL.ActiveTracks[trackID]
        if existingTrack and not existingTrack.canInterrupt then
            -- Cannot interrupt - add to queue instead
            GCAL_Log("Cannot interrupt current animation on track '" .. tostring(trackID) .. "', queueing instead")
            self:QueueAnim(name, trackID)
            return true
        end

        local track = CreateTrack(name, anim)
        if not SetupSourceModels(track, anim) then
            if IsValid(track.camModel) then track.camModel:Remove() end
            return false
        end

        local ok, err = pcall(ResolveFirstPersonSequence, track, name, anim)
        if not ok then
            if err == "GCAL_Play_NoSequence" then return false end
            error(err, 0)
        end

        SetupThirdPerson(track, name, anim)

        -- New: Call interrupt callback on replaced track
        if GCAL.ActiveTracks[trackID] then
            local oldTrack = GCAL.ActiveTracks[trackID]
            if oldTrack.onInterruptCallback and isfunction(oldTrack.onInterruptCallback) then
                pcall(oldTrack.onInterruptCallback, trackID, oldTrack.name, name)
            end
            GCAL:StopTrack(trackID)
        end

        GCAL.ActiveTracks[trackID] = track

        if trackID == "legacy_left_arm" then SyncLegacyVManipFields(track) end
        if track.blockCode then
            hook.Run("GCALCodeBlockStarted", trackID, name, track, track.blockCodeScope)
        end

        -- New: Call start callback
        if track.onStartCallback and isfunction(track.onStartCallback) then
            pcall(track.onStartCallback, trackID, name, track)
        end

        -- Trigger screen shake if configured
        if track.screenShake then
            local shake = track.screenShake
            local ply = LocalPlayer()
            if IsValid(ply) then
                local amplitude = shake.amplitude or 2
                local frequency = shake.frequency or 10
                local duration = shake.duration or 0.5
                local radius = shake.radius or 500
                util.ScreenShake(ply:EyePos(), amplitude, frequency, duration, radius)
            end
        end

        hook.Run("GCALTrackStarted", trackID, name, track)
        GCAL_Log("Started playback successfully! Track:", trackID)
        return true
    end

    function GCAL:StopTrack(trackID)
        local track = GCAL.ActiveTracks[trackID]
        if track then
            GCAL_Log("Stopping track:", trackID)
            if IsValid(track.model) then track.model:Remove() end
            if IsValid(track.camModel) then track.camModel:Remove() end
            if IsValid(track.tpikModel) then track.tpikModel:Remove() end
            if IsValid(track.thirdpersonModel) then track.thirdpersonModel:Remove() end
            if IsValid(track.legModel) then track.legModel:Remove() end
            if trackID == "legacy_left_arm" then
                vmatrixpeakinfo = vmatrixpeakinfo or 0
                VManip_modelname = VManip_modelname or ""
                vmanipholdtime = vmanipholdtime or 0
                SyncLegacyVManipFields(nil)
            end
            GCAL.ActiveTracks[trackID] = nil
            if track.blockCode then
                hook.Run("GCALCodeBlockStopped", trackID, track.name, track, track.blockCodeScope)
            end
            hook.Run("GCALTrackStopped", trackID, track.name, track)
            if trackID == "legacy_left_arm" then
                hook.Run("VManipRemove")
            end
        end
    end

    function GCAL:QuitHolding(trackID, animToStop)
        local track = self:GetTrack(trackID)
        if not track then return false end
        if hook.Run("GCALPreHoldQuit", trackID, track.name, animToStop) == false then return false end

        if (not animToStop and not track.preventQuit) or track.name == animToStop then
            track.holdQuit = true
            if track.segmented then track.lastSegment = true end
            hook.Run("GCALHoldQuit", trackID, track.name, animToStop)
            return true
        end

        return false
    end

    function GCAL:QueueAnim(name, trackID)
        if not self:GetAnim(name) then return false end

        local anim = self:GetAnim(name)
        trackID = trackID or anim.group_name or "default"
        self.QueuedAnims[trackID] = name
        return true
    end

    function GCAL:PlaySegment(trackID, sequence, lastSegment, soundTable)
        local track = self:GetTrack(trackID)
        if not track then return false end
        if not track.segmented or not track.segmentFinished or track.lastSegment then return false end
        if not IsValid(track.model) or track.model:LookupSequence(sequence) == -1 then return false end
        if hook.Run("GCALPrePlaySegment", trackID, track.name, sequence, lastSegment) == false then return false end

        -- Apply speed to all models when resetting sequences
        local speedMultiplier = track.speed * GCAL.PlaybackSpeed:GetFloat()
        track.model:ResetSequence(sequence)
        track.model:SetPlaybackRate(speedMultiplier)
        if IsValid(track.camModel) then
            track.camModel:ResetSequence(sequence)
            track.camModel:SetPlaybackRate(speedMultiplier)
        end
        if IsValid(track.tpikModel) and track.tpikSeqID and track.tpikSeqID ~= -1 then
            track.tpikModel:ResetSequence(track.tpikSeqID)
            track.tpikModel:SetPlaybackRate(speedMultiplier)
        end
        local thirdPersonSequence = track.tpikSequenceRequested and track.tpikSeqID or sequence
        if IsValid(track.thirdpersonModel) then
            track.thirdpersonModel:ResetSequence(thirdPersonSequence)
            track.thirdpersonModel:SetPlaybackRate(speedMultiplier)
        end
        track.curSegment = sequence
        track.cycle = 0
        track.segmentFinished = false
        track.segmentCount = track.segmentCount + 1
        if lastSegment then
            track.lastSegment = true
            track.lerpPeakTime = CurTime() + track.lerpPeak
        end

        if soundTable then
            for soundPath, time in pairs(soundTable) do
                timer.Simple(time, function()
                    if self:GetCurrentAnim(trackID) == track.name and IsValid(LocalPlayer()) and LocalPlayer():Alive() then
                        if not GCAL.MuteSounds:GetBool() then
                            local overridePath = GCAL.GetAnimSoundOverride and GCAL:GetAnimSoundOverride(track.name)
                            LocalPlayer():EmitSound(overridePath or soundPath, 75, GCAL.SoundPitch:GetInt())
                        end
                    end
                end)
            end
        end

        hook.Run("GCALPlaySegment", trackID, track.name, sequence, lastSegment)
        return true
    end

    local function HandleSounds(track)
        if GCAL.MuteSounds:GetBool() then return end
        local overridePath = GCAL.GetAnimSoundOverride and GCAL:GetAnimSoundOverride(track.name)
        local soundCount = track.data.sounds and table.Count(track.data.sounds) or 0
        if soundCount == 0 then
            if overridePath and not track.soundsPlayed.__custom_start then
                local ply = LocalPlayer()
                if IsValid(ply) then
                    local volume = track.soundVolume or 75
                    local pitch = GCAL.SoundPitch:GetInt()
                    local level = track.soundLevel or 75
                    local flags = track.soundFlags or 0
                    ply:EmitSound(overridePath, volume, pitch, 1.0, level, flags)
                end
                track.soundsPlayed.__custom_start = true
            end
            return
        end

        local elapsed = CurTime() - track.startTime
        for soundPath, time in pairs(track.data.sounds) do
            if elapsed >= time and not track.soundsPlayed[soundPath] then
                local ply = LocalPlayer()
                if IsValid(ply) then
                    local volume = track.soundVolume or 75
                    local pitch = GCAL.SoundPitch:GetInt()
                    local level = track.soundLevel or 75
                    local flags = track.soundFlags or 0
                    ply:EmitSound(overridePath or soundPath, volume, pitch, 1.0, level, flags)
                end
                track.soundsPlayed[soundPath] = true
            end
        end
    end

    SyncLegacyVManipFields = function(track)
        if not VManip then return end
        if track then
            VManip.VMGesture = track.model
            VManip.VMCam = track.camModel
            VManip.AssurePos = track.data.assurepos or false
            VManip.LockToPly = track.data.locktoply or false
            VManip.LockZ = track.lockZ or 0
            VManip.Cam_Ang = track.camAng
            VManip.Cam_AngInt = track.camAngInt
            VManip.StartCycle = track.data.startcycle or 0
            VManip.CurGesture = track.name
            VManip.CurGestureData = track.data
            VManip.VMatrixlerp = track.lerpVal or 1
            VManip.Cycle = track.cycle or 0
            VManip.Speed = track.speed or 1
            VManip.Lerp_Peak = track.lerpPeakTime or 0
            VManip.Lerp_Speed_In = track.lerpSpeedIn or 1
            VManip.Lerp_Speed_Out = track.lerpSpeedOut or 1
            VManip.Lerp_Curve = track.lerpCurve or 1
            VManip.Duration = track.duration or 0
            VManip.Loop = track.loop or false
            VManip.HoldTime = track.holdTime
            VManip.HoldTimeData = track.holdTimeData
            VManip.HoldQuit = track.holdQuit or false
            VManip.GestureOnHold = track.gestureOnHold or false
            VManip.GesturePastHold = track.gesturePastHold or false
            VManip.BlockCode = track.blockCode or false
            VManip.BlockCodeScope = track.blockCodeScope
            VManip.PreventQuit = track.preventQuit or false
            VManip.Segmented = track.segmented or false
            VManip.SegmentFinished = track.segmentFinished or false
            VManip.CurSegment = track.curSegment
            VManip.LastSegment = track.lastSegment or false
            VManip.SegmentCount = track.segmentCount or 0
            VManip.Attachment = track.attachment
        else
            VManip.VMGesture = nil
            VManip.VMCam = nil
            VManip.AssurePos = false
            VManip.LockToPly = false
            VManip.LockZ = 0
            VManip.Cam_Ang = properang
            VManip.Cam_AngInt = nil
            VManip.StartCycle = 0
            VManip.CurGesture = nil
            VManip.CurGestureData = nil
            VManip.VMatrixlerp = 1
            VManip.Cycle = 0
            VManip.Speed = nil
            VManip.Lerp_Peak = 0
            VManip.Lerp_Speed_In = nil
            VManip.Lerp_Speed_Out = nil
            VManip.Lerp_Curve = nil
            VManip.Duration = 0
            VManip.Loop = nil
            VManip.HoldTime = nil
            VManip.HoldTimeData = nil
            VManip.HoldQuit = false
            VManip.GestureOnHold = false
            VManip.GesturePastHold = false
            VManip.BlockCode = false
            VManip.BlockCodeScope = nil
            VManip.PreventQuit = false
            VManip.Segmented = false
            VManip.SegmentFinished = false
            VManip.CurSegment = nil
            VManip.LastSegment = false
            VManip.SegmentCount = 0
            VManip.Attachment = nil
        end
    end

    local function UpdateTrack(track, trackID)
        track.data = track.data or {}
        track.startTime = track.startTime or CurTime()
        track.cycle = track.cycle or 0
        track.speed = track.speed or 1
        track.duration = track.duration or 1
        track.lerpPeak = track.lerpPeak or track.data.lerp_peak or 0.5
        track.lerpPeakTime = track.lerpPeakTime or (CurTime() + track.lerpPeak)
        track.lerpSpeedIn = track.lerpSpeedIn or track.data.lerp_speed_in or 1
        track.lerpSpeedOut = track.lerpSpeedOut or track.data.lerp_speed_out or 1
        track.lerpCurve = track.lerpCurve or track.data.lerp_curve or 1
        if track.loop == nil then track.loop = track.data.loop or false end
        if track.segmented == nil then track.segmented = track.data.segmented or false end
        track.segmentCount = track.segmentCount or 0
        track.holdTimeData = track.holdTimeData or track.data.holdtime
        if not track.holdTime and track.holdTimeData then track.holdTime = track.startTime + track.holdTimeData end
        track.easingIn = track.easingIn or GCAL.Lerp.OutQuad
        track.easingOut = track.easingOut or GCAL.Lerp.OutQuad
        track.soundsPlayed = track.soundsPlayed or {}
        track.lastLerpVal = track.lastLerpVal or track.lerpVal or 1

        local dt = FrameTime()
        HandleSounds(track)

        curtime = CurTime()

        -- New: Handle delay_start
        if track.delayStart and track.delayStart > 0 and curtime < track.realStartTime + track.delayStart then
            return false
        end

        -- New: Cycle callback
        if track.onCycleCallback and isfunction(track.onCycleCallback) then
            local cycleTrigger = math.floor(track.cycle * 10)
            if cycleTrigger ~= track.lastCycleTrigger then
                track.lastCycleTrigger = cycleTrigger
                pcall(track.onCycleCallback, trackID, track.name, track, track.cycle)
            end
        end

        if track.loop then
            if track.cycle >= 1 then
                track.lerpPeakTime = curtime + track.lerpPeak
                track.cycle = 0
            end
            if track.holdQuit then track.loop = false end
        end

        if track.holdTime then
            if curtime >= track.holdTime and not track.gestureOnHold and not track.gesturePastHold and not track.holdQuit then
                track.gestureOnHold = true
            elseif track.holdQuit and track.gestureOnHold then
                track.gestureOnHold = false
                track.gesturePastHold = true
                track.lerpPeakTime = curtime + track.lerpPeak - (track.holdTimeData or 0)
            end
        end

        if not track.gestureOnHold then
            track.cycle = track.cycle + dt * track.speed * GCAL.PlaybackSpeed:GetFloat()
        end

        if not track.poseOnlyLegacy then
            local speedMultiplier = track.speed * GCAL.PlaybackSpeed:GetFloat()
            if IsValid(track.model) then
                track.model:SetCycle(track.cycle)
                track.model:InvalidateBoneCache()
            end
            if IsValid(track.camModel) then
                track.camModel:SetCycle(track.cycle)
                track.camModel:InvalidateBoneCache()
            end
            if IsValid(track.tpikModel) then
                track.tpikModel:SetPlaybackRate(speedMultiplier)
                track.tpikModel:SetCycle(track.cycle)
                track.tpikModel:InvalidateBoneCache()
            end
            if IsValid(track.thirdpersonModel) then
                track.thirdpersonModel:SetPlaybackRate(speedMultiplier)
                track.thirdpersonModel:SetCycle(track.cycle)
                track.thirdpersonModel:InvalidateBoneCache()
            end
        end

        if (curtime < track.lerpPeakTime or (track.segmented and not track.lastSegment)) and (not track.gestureOnHold or track.gesturePastHold) then
            track.lerpVal = math.Clamp((track.lerpVal or 1) - (dt * 7) * track.lerpSpeedIn, 0, 1)
        elseif not track.loop and (not track.gestureOnHold or track.gesturePastHold) then
            if not track.segmented or track.lastSegment then
                track.lerpVal = math.Clamp((track.lerpVal or 1) + (dt * 7) * track.lerpSpeedOut, 0, 1)
            end
        end

        if trackID == "legacy_left_arm" then
            if track.lastLerpVal == 1 and track.lerpVal < 1 and not track.legacyStarted then
                track.legacyStarted = true
                hook.Run("VManipPostPlayAnim", track.name)
            end
        end

        if track.cycle >= 1 and not track.loop then
            if track.segmented and not track.segmentFinished then
                track.segmentFinished = true
                hook.Run("GCALSegmentFinish", trackID, track.name, track.curSegment, track.lastSegment,
                    track.segmentCount)
                hook.Run("VManipSegmentFinish", track.name, track.curSegment, track.lastSegment, track.segmentCount)
            elseif track.segmented and track.lastSegment then
                if track.lerpVal >= 1 then
                    -- New: Call finish callback before stopping
                    if track.onFinishCallback and isfunction(track.onFinishCallback) then
                        pcall(track.onFinishCallback, trackID, track.name, track)
                    end
                    GCAL:StopTrack(trackID)
                    return true
                end
            elseif not track.segmented then
                -- New: Call finish callback before stopping
                if track.onFinishCallback and isfunction(track.onFinishCallback) then
                    pcall(track.onFinishCallback, trackID, track.name, track)
                end
                GCAL:StopTrack(trackID)
                return true
            end
        end

        if trackID == "legacy_left_arm" then
            SyncLegacyVManipFields(track)
        end

        track.lastLerpVal = track.lerpVal

        return false
    end

    local flipState = {
        lefty = false,
        flippedNow = false,
        flipmode = false,
        targetRight = false,
        targetBones = nil,
        targetSide =
        "left_arm"
    }
    local function GetLegacyFlipState(weapon)
        local validWeapon = IsValid(weapon)
        local lefty = validWeapon and tobool(weapon.ViewModelFlipDefault) or false
        local flippedNow = validWeapon and tobool(weapon.ViewModelFlip) or false
        local flipmode = validWeapon and lefty ~= flippedNow or false
        flipState.lefty = lefty
        flipState.flippedNow = flippedNow
        flipState.flipmode = flipmode
        flipState.targetRight = flippedNow
        flipState.targetBones = flippedNow and GCAL.GROUPS.RIGHT_ARM or GCAL.GROUPS.LEFT_ARM
        flipState.targetSide = flippedNow and "right_arm" or "left_arm"
        return flipState
    end

    local function TrackUsesLegacyFlip(track)
        return track and track.data and track.data.legacy
    end

    local function GetTrackTargetBones(track, weapon, flip)
        if TrackUsesLegacyFlip(track) then return flip.targetBones end

        return track.bones
    end

    local function GetTrackSourceAngleOffset(track, weapon, flip)
        if TrackUsesLegacyFlip(track) and flip.flipmode then return angleFlip end

        return angleZero
    end

    local function GetTrackModelScale(track, weapon, flip)
        if TrackUsesLegacyFlip(track) and flip.flipmode then return -1 end

        return 1
    end

    local function PlaceTrackModel(track, pos, ang)
        local adjustedPos, adjustedAng = GCAL:ApplyAnimationAdjustment(track.name, pos, ang)
        track.model:SetAngles(adjustedAng)
        track.model:SetPos(adjustedPos)
    end

    local function PlaceTPIKTrackModel(track, pos, ang)
        local sourceModel = IsValid(track.tpikModel) and track.tpikModel or track.model
        if not IsValid(sourceModel) then return end
        sourceModel:SetAngles(ang)
        sourceModel:SetPos(pos)
    end

    local function DrawGShaderFriendlyModel(model, flags)
        if not IsValid(model) then return end

        model:DrawModel(flags)
    end

    local function BoneLocalMatrix(ent, bone, worldMatrix, worldMatrices)
        local parent = ent:GetBoneParent(bone)
        if not parent or parent < 0 then
            return Matrix(worldMatrix:ToTable()), parent
        end

        local parentMatrix = worldMatrices and worldMatrices[parent] or ent:GetBoneMatrix(parent)
        if not parentMatrix then
            return Matrix(worldMatrix:ToTable()), parent
        end

        local parentInverse = Matrix(parentMatrix:ToTable())
        parentInverse:Invert()
        return parentInverse * worldMatrix, parent
    end

    include("gcal/gcal_tpik.lua")
    local tpik = GCAL.InstallTPIK({
        BoneLocalMatrix = BoneLocalMatrix,
        PlaceTrackModel = PlaceTrackModel,
        PlaceTPIKTrackModel = PlaceTPIKTrackModel,
        GetLegacyFlipState = GetLegacyFlipState,
        GetTrackTargetBones = GetTrackTargetBones,
        GetTrackModelScale = GetTrackModelScale
    })
    local ApplyCachedThirdPersonBones = tpik.ApplyCachedThirdPersonBones
    local ApplyThirdPersonBones = tpik.ApplyThirdPersonBones
    GCAL.WeaponBaseStrategies = GCAL.WeaponBaseStrategies or {}

    local function EntityHasAnyBone(ent, bones)
        if not IsValid(ent) or not bones then return false end

        for _, boneName in ipairs(bones) do
            local bone = ent:LookupBone(boneName)
            if bone ~= nil and bone >= 0 then return true end
        end

        return false
    end

    function GCAL:RegisterWeaponBaseStrategy(id, strategy)
        if not id or not strategy or not isfunction(strategy.detect) then return false end

        strategy.id = id
        for k, existing in ipairs(self.WeaponBaseStrategies) do
            if existing.id == id then
                self.WeaponBaseStrategies[k] = strategy
                return true
            end
        end

        self.WeaponBaseStrategies[#self.WeaponBaseStrategies + 1] = strategy
        return true
    end

    function GCAL:GetWeaponBaseStrategy(ply, weapon)
        if not IsValid(weapon) then return nil end

        for _, strategy in ipairs(self.WeaponBaseStrategies or {}) do
            if strategy.detect(ply, weapon) then return strategy end
        end

        return nil
    end

    function GCAL:GetThirdPersonRenderMethod(ply, weapon, strategy)
        strategy = strategy or self:GetWeaponBaseStrategy(ply, weapon)
        if strategy and strategy.thirdPersonMethod then
            local method = strategy.thirdPersonMethod(ply, weapon, strategy)
            if method then return method end
        end

        return "normal"
    end

    function GCAL:FindArmTarget(vm, handsEnt, targetBones)
        if EntityHasAnyBone(vm, targetBones) then return vm end
        if EntityHasAnyBone(handsEnt, targetBones) then return handsEnt end

        return vm
    end

    function GCAL:BuildWeaponRenderContext(ply, weapon, vm, handsEnt)
        local strategy = self:GetWeaponBaseStrategy(ply, weapon)
        local context = {
            strategy = strategy,
            strategy_id = strategy and strategy.id or "normal",
            ply = ply,
            weapon = weapon,
            vm = vm,
            handsEnt = handsEnt
        }

        if strategy and strategy.resolveViewModel then
            local resolved = strategy.resolveViewModel(ply, weapon, vm, handsEnt, context)
            if IsValid(resolved) then context.vm = resolved end
        elseif hook.GetTable and hook.GetTable().VManipVMEntity then
            local resolved = hook.Run("VManipVMEntity", ply, weapon)
            if IsValid(resolved) then
                context.strategy_id = "hook"
                context.vm = resolved
            end
        end

        return context
    end

    function GCAL:ResolveArmTarget(context, targetBones)
        if not context then return nil end

        local strategy = context.strategy
        if strategy and strategy.resolveArmTarget then
            local target = strategy.resolveArmTarget(context.ply, context.weapon, context.vm, context.handsEnt,
                targetBones, context)
            if IsValid(target) then return target end
        end

        return self:FindArmTarget(context.vm, context.handsEnt, targetBones)
    end

    local posparentcache
    local function ApplyLegacyLeftArmVisible(track, vm, handsEnt, ply, weapon, flags, renderContext, skipVMSetup)
        if not IsValid(track.model) or not IsValid(vm) then return end
        if IsValid(weapon) and type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return end

        local flip = GetLegacyFlipState(weapon)
        local flipmode = flip.flipmode
        local flipped = (track.lerpVal <= 0.5 and scaleflipvec or scalevec)
        local sourceAngleOffset = GetTrackSourceAngleOffset(track, weapon, flip)

        if track.data.assurepos then
            if posparentcache ~= weapon then
                posparentcache = weapon
                track.model:SetParent(nil)
                PlaceTrackModel(track, EyePos(), vm:GetAngles() + sourceAngleOffset)
                track.model:SetParent(vm)
            end
        end

        if track.data.locktoply then
            local eyeang = ply:EyeAngles()
            local eyepos = EyePos()
            local vmang = vm:GetAngles()
            local finang = eyeang - vmang
            finang.y = 0
            local newang = eyeang + (finang * 0.25)
            PlaceTrackModel(track, eyepos, newang + sourceAngleOffset)
        elseif not track.data.assurepos then
            local eyeang, eyepos = EyeAngles(), EyePos()
            PlaceTrackModel(track, eyepos, eyeang + sourceAngleOffset)
        end

        if not skipVMSetup then
            vm:SetupBones()
            if IsValid(handsEnt) then
                handsEnt:SetupBones()
            end
        end

        track.model:SetupBones()
        track.model:SetModelScale(GetTrackModelScale(track, weapon, flip))
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CW) end
        DrawGShaderFriendlyModel(track.model, flags)
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CCW) end

        local rigpick = GCAL.GROUPS.LEFT_ARM
        local targetRig = flip.targetBones
        local targetEnt = GCAL:ResolveArmTarget(renderContext, targetRig)
        if not IsValid(targetEnt) then return end
        targetEnt:SetupBones()

        local boneCount = 0
        local lerpVal = track.lerpVal
        local lerpCurve = track.lerpCurve or 1
        local legacyLerp = GCAL.Lerp.Legacy

        for k, boneName in ipairs(rigpick) do
            local sourceBoneName = boneName == "ValveBiped.Bip01_L_Ulna" and "ValveBiped.Bip01_L_Forearm" or boneName
            local sourceBone = track.model:LookupBone(sourceBoneName)
            if sourceBone == nil or sourceBone < 0 then continue end

            local gestureMatrix = track.model:GetBoneMatrix(sourceBone)
            local targetBone = targetEnt:LookupBone(targetRig[k] or boneName)

            if targetBone ~= nil and targetBone >= 0 and gestureMatrix ~= nil then
                local targetBoneMatrix = targetEnt:GetBoneMatrix(targetBone)
                if targetBoneMatrix then
                    local targetTable = targetBoneMatrix:ToTable()
                    local gestureTable = gestureMatrix:ToTable()

                    for i, row in pairs(gestureTable) do
                        for j, value in pairs(row) do
                            gestureTable[i][j] = legacyLerp(lerpVal, value, targetTable[i][j], lerpCurve)
                        end
                    end

                    local m = Matrix(gestureTable)
                    m:SetScale(flip.targetRight and flipped or scalevec)
                    targetEnt:SetBoneMatrix(targetBone, m)
                    boneCount = boneCount + 1
                end
            end
        end

        if IsValid(handsEnt) and handsEnt ~= targetEnt then
            handsEnt:InvalidateBoneCache()
        end
        track.debugTargetEntity = tostring(targetEnt)
        track.debugBoneCount = boneCount
    end

    local function ApplyBones(track, vm, handsEnt, ply, weapon, thirdperson, suppressSourceDraw, flags, renderContext,
                              skipVMSetup)
        if not IsValid(vm) or not track.bones then return end

        if IsValid(weapon) and type(weapon.GetStatus) == "function" and weapon:GetStatus() == 5 then return end

        if thirdperson then
            ApplyThirdPersonBones(track, vm, weapon, renderContext and renderContext.thirdpersonBaseMatrices)
            return
        end

        if not skipVMSetup then
            vm:SetupBones()
            if IsValid(handsEnt) and handsEnt ~= vm then
                handsEnt:SetupBones()
            end
        end

        local flip = GetLegacyFlipState(weapon)
        local useLegacyFlip = TrackUsesLegacyFlip(track)
        local flipmode = useLegacyFlip and flip.flipmode or false
        local sourceAngleOffset = GetTrackSourceAngleOffset(track, weapon, flip)
        local eyeang, eyepos = EyeAngles(), EyePos()
        local targetBones = GetTrackTargetBones(track, weapon, flip)
        local targetEnt = GCAL:ResolveArmTarget(renderContext, targetBones)
        if not IsValid(targetEnt) then return end
        if not skipVMSetup then
            targetEnt:SetupBones()
        end

        if track.data.legacy then
            PlaceTrackModel(track, eyepos, eyeang + sourceAngleOffset)
        elseif track.data.locktoply or track.data.assurepos then
            PlaceTrackModel(track, eyepos, eyeang + sourceAngleOffset)
        else
            PlaceTrackModel(track, vm:GetPos(), vm:GetAngles() + sourceAngleOffset)
        end

        track.model:SetModelScale(GetTrackModelScale(track, weapon, flip))
        track.model:SetupBones()
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CW) end
        if not thirdperson and not suppressSourceDraw then
            DrawGShaderFriendlyModel(track.model, flags)
        end
        if flipmode then render.CullMode(MATERIAL_CULLMODE_CCW) end

        local boneCount = 0
        local curve = track.lerpCurve or track.data.lerp_curve or 1
        local lerpVal = track.lerpVal
        local matrixLerp = track.legacyMatrixLerp and GCAL.Lerp.Legacy or Lerp
        local scaleVec = useLegacyFlip and flip.targetRight and lerpVal <= 0.5 and scaleflipvec or scalevec

        for k, boneName in ipairs(track.bones) do
            local sourceBoneName = track.sourceBones and track.sourceBones[k] or boneName
            sourceBoneName = sourceBoneName == "ValveBiped.Bip01_L_Ulna" and "ValveBiped.Bip01_L_Forearm" or
                sourceBoneName
            local modelBone = track.model:LookupBone(sourceBoneName)
            if not modelBone or modelBone < 0 then continue end

            local modelMatrix = track.model:GetBoneMatrix(modelBone)
            if modelMatrix then
                local targetBoneName = targetBones[k] or boneName
                local targetBone = targetEnt:LookupBone(targetBoneName)
                if not targetBone or targetBone < 0 then continue end

                local targetMatrix = targetEnt:GetBoneMatrix(targetBone)
                if not targetMatrix then continue end

                local mTable = modelMatrix:ToTable()
                local targetTable = targetMatrix:ToTable()

                for i = 1, 4 do
                    local mi, ti = mTable[i], targetTable[i]
                    for j = 1, 4 do
                        mi[j] = matrixLerp(lerpVal, mi[j], ti[j], curve)
                    end
                end

                local m = Matrix(mTable)
                m:SetScale(scaleVec)
                targetEnt:SetBoneMatrix(targetBone, m)
                boneCount = boneCount + 1
            end
        end

        if IsValid(handsEnt) and handsEnt ~= targetEnt then
            handsEnt:InvalidateBoneCache()
        end
        track.debugTargetEntity = tostring(targetEnt)
        track.debugBoneCount = boneCount
    end

    local function ProcessQueuedTracks()
        if not next(GCAL.QueuedAnims) then return end
        for queuedTrackID, queuedName in pairs(GCAL.QueuedAnims) do
            if not GCAL.ActiveTracks[queuedTrackID] and GCAL:Play(queuedName, queuedTrackID) then
                GCAL.QueuedAnims[queuedTrackID] = nil
            end
        end
    end

    local lastTrackUpdateFrame = -1
    local function UpdateTracksForFrame()
        local frame = FrameNumber()
        if lastTrackUpdateFrame == frame then return false end
        lastTrackUpdateFrame = frame

        ProcessQueuedTracks()

        for id, track in pairs(GCAL.ActiveTracks) do
            UpdateTrack(track, id)
        end

        if next(GCAL.ActiveTracks) == nil and VManip and VManip.QueuedAnim and VManip:PlayAnim(VManip.QueuedAnim) then
            VManip.QueuedAnim = nil
        end

        return true
    end

    local renderTracksBusy = false
    local function RenderTracks(hands, vm, ply, weapon, flags, fromHandsHook)
        if renderTracksBusy then return end
        if not IsValid(vm) then return end

        renderTracksBusy = true
        local handsEnt = IsValid(hands) and hands or (IsValid(ply) and ply:GetHands() or nil)
        if IsValid(handsEnt) then
            handsEnt:SetupBones()
        end

        UpdateTracksForFrame()

        if next(GCAL.ActiveTracks) == nil then
            renderTracksBusy = false
            return
        end

        local renderContext = GCAL:BuildWeaponRenderContext(ply, weapon, vm, handsEnt)
        vm = renderContext.vm

        if IsValid(vm) then vm:SetupBones() end
        if IsValid(handsEnt) and handsEnt ~= vm then handsEnt:SetupBones() end
        local skipVMSetup = true

        for id, track in pairs(GCAL.ActiveTracks) do
            if id == "legacy_left_arm" and IsValid(ply) and not ply:Alive() then
                GCAL:StopTrack(id)
                continue
            end

            if id == "legs" then
                continue
            end

            if id == "legacy_left_arm" then
                ApplyLegacyLeftArmVisible(track, vm, handsEnt, ply, weapon, flags, renderContext, skipVMSetup)
            else
                ApplyBones(track, vm, handsEnt, ply, weapon, false, false, flags, renderContext, skipVMSetup)
            end
        end

        renderTracksBusy = false
    end

    local function RenderThirdPersonTracks(ply, methodOverride, forcedWeapon)
        if IsValid(ply) and ply.ixGCALBuildingPose then return end
        if not GCAL:IsThirdPersonEnabled() then return end
        if ply ~= LocalPlayer() or not IsValid(ply) or not ply:Alive() then return end
        local viewEntity = ply.GetViewEntity and ply:GetViewEntity() or ply
        if not ply:ShouldDrawLocalPlayer() and viewEntity == ply then return end
        if next(GCAL.ActiveTracks) == nil then return end

        local weapon = IsValid(forcedWeapon) and forcedWeapon or ply:GetActiveWeapon()
        local strategy = GCAL:GetWeaponBaseStrategy(ply, weapon)
        local method = methodOverride or GCAL:GetThirdPersonRenderMethod(ply, weapon, strategy)
        local hostedByWeaponTPIK = method == "arc9_tpik"
        if hostedByWeaponTPIK and not methodOverride then return end

        UpdateTracksForFrame()
        if next(GCAL.ActiveTracks) == nil then return end

        local needsSolve = false
        for id, track in pairs(GCAL.ActiveTracks) do
            if id ~= "legs"
                and track.thirdperson
                and track.thirdpersonSolveFrame ~= FrameNumber()
            then
                needsSolve = true
                break
            end
        end

        local renderContext
        if needsSolve then
            if not hostedByWeaponTPIK then
                ply.ixGCALReadingBase = true
                ply:InvalidateBoneCache()
                ply:SetupBones()
                ply.ixGCALReadingBase = nil
            end

            local baseMatrices = {}
            for bone = 0, ply:GetBoneCount() - 1 do
                local matrix = ply:GetBoneMatrix(bone)
                if matrix then
                    baseMatrices[bone] = Matrix(matrix:ToTable())
                end
            end
            renderContext = {
                thirdpersonBaseMatrices = baseMatrices
            }
        end

        for id, track in pairs(GCAL.ActiveTracks) do
            if id == "legs" or not track.thirdperson then continue end

            if track.thirdpersonSolveFrame == FrameNumber() then
                ApplyCachedThirdPersonBones(track, ply)
            elseif renderContext then
                ApplyBones(track, ply, nil, ply, weapon, true, false, nil, renderContext)
            end

            track.debugThirdPersonHost = method
        end
    end

    hook.Add("PreDrawPlayerHands", "GCAL_RenderHands", function(hands, vm, ply, weapon, flags)
        RenderTracks(hands, vm, ply, weapon, flags, true)
    end)

    hook.Add("PostDrawViewModel", "VManip", function(vm, ply, weapon, flags)
        if not IsValid(weapon) or not weapon:IsScripted() or weapon.UseHands then return end
        RenderTracks(nil, vm, ply, weapon, flags, false)
    end)

    hook.Add("PostDrawViewModel", "GCAL_RenderVM", function(vm, ply, weapon, flags)
        if not IsValid(weapon) or not weapon:IsScripted() or weapon.UseHands then return end
        RenderTracks(nil, vm, ply, weapon, flags, false)
    end)

    hook.Add("PrePlayerDraw", "GCAL_RenderThirdPerson", function(ply)
        RenderThirdPersonTracks(ply)
    end)

    hook.Add("ARC9_TPIK_PostSolve", "GCAL_RenderARC9ThirdPerson", function(weapon, ply)
        local strategy = GCAL:GetWeaponBaseStrategy(ply, weapon)
        if not strategy then return end
        if GCAL:GetThirdPersonRenderMethod(ply, weapon, strategy) ~= "arc9_tpik" then return end

        RenderThirdPersonTracks(ply, "arc9_tpik", weapon)
    end)

    hook.Add("PostPlayerDraw", "GCAL_RenderThirdPersonModels", function(ply)
        if ply ~= LocalPlayer() or not GCAL:IsThirdPersonEnabled() then return end

        for _, track in pairs(GCAL.ActiveTracks) do
            local model = track.thirdpersonModel
            local readyFrame = track.thirdpersonModelReadyFrame or -1
            local readyTime = track.thirdpersonModelReadyTime or 0
            if track.thirdperson
                and (readyFrame >= FrameNumber() - 1 or RealTime() - readyTime <= 0.1)
                and IsValid(model)
            then
                track.debugThirdPersonModelDrawFrame = FrameNumber()
                model:DrawModel()
            end
        end
    end)

    hook.Add("PreDrawViewModels", "GCAL_RenderLegs", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() or ply:ShouldDrawLocalPlayer() then return end
        local track = GCAL.ActiveTracks["legs"]
        if not track or not GCAL.Legs then return end
        GCAL.Legs:Update(ply)
        if IsValid(track.model) then
            track.model:SetupBones()
            track.model:DrawModel()
        end
    end)

    hook.Add("HUDPaint", "GCAL_DebugHUD", function()
        if not GCAL.Debug:GetBool() then return end
        local x, y = 50, 50
        draw.SimpleText("--- GCAL DEBUG HUD ---", "DermaDefault", x, y, Color(255, 255, 0))
        y = y + 20
        draw.SimpleText("Active Tracks: " .. table.Count(GCAL.ActiveTracks), "DermaDefault", x, y, Color(255, 255, 255))
        y = y + 20
        for id, track in pairs(GCAL.ActiveTracks) do
            draw.SimpleText("Track: " .. id, "DermaDefault", x + 10, y, Color(0, 255, 0))
            y = y + 15
            draw.SimpleText(" - Anim: " .. tostring(track.name), "DermaDefault", x + 20, y, Color(200, 255, 200))
            y = y + 15
            draw.SimpleText(" - Cycle: " .. math.Round(track.cycle, 3), "DermaDefault", x + 20, y, Color(200, 255, 200))
            y = y + 15
            draw.SimpleText(" - Lerp: " .. math.Round(track.lerpVal, 3), "DermaDefault", x + 20, y, Color(200, 255, 200))
            y = y + 15
            draw.SimpleText(" - Bones: " .. (track.debugBoneCount or 0), "DermaDefault", x + 20, y, Color(200, 255, 200))
            y = y + 20
        end
    end)

    concommand.Add("gcal_list_anims", function()
        local names = {}

        for name in pairs(GCAL.Anims or {}) do
            names[#names + 1] = tostring(name)
        end

        table.sort(names)
        MsgC(Color(93, 210, 180), "[GCAL] Registered animations (" .. #names .. "):\n")

        for _, name in ipairs(names) do
            local anim = GCAL.Anims[name] or {}
            MsgC(Color(236, 242, 255), " - " .. name .. " [" .. tostring(anim.group_name or "default") .. "]\n")
        end
    end)

    local function GCAL_AnimAutocomplete(command, args)
        local needle = string.lower(string.Trim(args or ""))
        local matches = {}

        for name in pairs(GCAL.Anims or {}) do
            name = tostring(name)
            if needle == "" or string.StartsWith(string.lower(name), needle) then
                matches[#matches + 1] = command .. " " .. name
            end
        end

        table.sort(matches)
        return matches
    end

    concommand.Add("gcal_play", function(_, _, args)
        local name = args[1]
        local trackID = args[2]

        if not name or name == "" then
            MsgC(Color(255, 176, 93), "[GCAL] Usage: gcal_play <animation> [track]\n")
            return
        end

        if not GCAL.Anims[name] then
            MsgC(Color(255, 106, 106), "[GCAL] Unknown animation: " .. tostring(name) .. "\n")
            return
        end

        if GCAL.IsAnimEnabled and not GCAL:IsAnimEnabled(name) then
            MsgC(Color(255, 176, 93), "[GCAL] Animation is disabled: " .. tostring(name) .. "\n")
            return
        end

        if GCAL:Play(name, trackID) then
            MsgC(Color(93, 210, 180),
                "[GCAL] Playing " .. tostring(name) .. (trackID and (" on " .. tostring(trackID)) or "") .. "\n")
        else
            MsgC(Color(255, 106, 106), "[GCAL] Could not play " .. tostring(name) .. "\n")
        end
    end, GCAL_AnimAutocomplete, "Play a registered GCAL animation. Usage: gcal_play <animation> [track]")

    concommand.Add("gcal_debug_sequences", function(_, _, args)
            local name = args[1]
            if not name or name == "" then
                MsgC(Color(255, 176, 93), "[GCAL] Usage: gcal_debug_sequences <animation>\n")
                return
            end

            local anim = GCAL.Anims[name]
            if not anim then
                MsgC(Color(255, 106, 106), "[GCAL] Unknown animation: " .. tostring(name) .. "\n")
                return
            end

            if not anim.model then
                MsgC(Color(255, 106, 106), "[GCAL] Animation has no model: " .. tostring(name) .. "\n")
                return
            end

            local normalizedPath = NormalizeModelPath(anim.model)
            MsgC(Color(93, 210, 180), "[GCAL] Sequence debug for " .. tostring(name) .. "\n")
            MsgC(Color(236, 242, 255), " - model (original): " .. tostring(anim.model) .. "\n")
            MsgC(Color(236, 242, 255), " - model (normalized): " .. normalizedPath .. "\n")
            MsgC(Color(236, 242, 255), " - explicit sequence: " .. tostring(anim.sequence or "<none>") .. "\n")

            local model = ClientsideModel(normalizedPath, RENDERGROUP_BOTH)
            if not IsValid(model) then
                MsgC(Color(255, 106, 106), "[GCAL] Could not create model: " .. normalizedPath .. "\n")
                MsgC(Color(255, 176, 93), "   ! Check that the file exists at: garrysmod/" .. normalizedPath .. "\n")
                return
            end

            model:SetNoDraw(true)
            model:SetupBones()

            local sequenceList = model.GetSequenceList and (model:GetSequenceList() or {}) or {}
            MsgC(Color(236, 242, 255), " - sequences (" .. tostring(#sequenceList) .. "):\n")

            if #sequenceList == 0 then
                MsgC(Color(255, 176, 93),
                    "   ! Model loaded with zero sequences!\n")
                MsgC(Color(255, 176, 93),
                    "   ! This usually means:\n")
                MsgC(Color(255, 176, 93),
                    "     - The model is a prop/ragdoll without animations\n")
                MsgC(Color(255, 176, 93),
                    "     - The model failed to load completely\n")
                MsgC(Color(255, 176, 93),
                    "     - The .mdl file is missing associated .vvd/.vtx files\n")
            else
                for _, sequenceName in ipairs(sequenceList) do
                    MsgC(Color(236, 242, 255), "   * " .. tostring(sequenceName) .. "\n")
                end

                -- Check if the registered sequence exists
                local targetSeq = anim.sequence or name
                local seqID = model:LookupSequence(targetSeq)

                if seqID ~= -1 then
                    MsgC(Color(93, 210, 180), " ✓ Sequence '" .. targetSeq .. "' found! (ID: " .. seqID .. ")\n")
                    local duration = model:SequenceDuration(seqID)
                    MsgC(Color(236, 242, 255), "   - Duration: " .. duration .. " seconds\n")
                else
                    MsgC(Color(255, 106, 106), " ✗ Sequence '" .. targetSeq .. "' NOT FOUND!\n")

                    -- Try case-insensitive match
                    local lowerTarget = string.lower(targetSeq)
                    for _, seqName in ipairs(sequenceList) do
                        if string.lower(seqName) == lowerTarget then
                            MsgC(Color(255, 176, 93), "   ! Found case-insensitive match: '" .. seqName .. "'\n")
                            MsgC(Color(255, 176, 93), "   ! Update your animation to use the correct case\n")
                        end
                    end
                end
            end

            model:Remove()
        end, GCAL_AnimAutocomplete,
        "Print the runtime model sequence list for a registered animation. Usage: gcal_debug_sequences <animation>")

    concommand.Add("gcal_test_sequence", function(_, _, args)
        if #args < 2 then
            MsgC(Color(255, 176, 93), "[GCAL] Usage: gcal_test_sequence <model_path> <sequence_name>\n")
            MsgC(Color(236, 242, 255), "Example: gcal_test_sequence c_vmanip.mdl swimforward\n")
            MsgC(Color(236, 242, 255), "         gcal_test_sequence models/c_vmanip.mdl swimforward\n")
            return
        end

        local modelPath = args[1]
        local sequenceName = args[2]

        local normalizedPath = NormalizeModelPath(modelPath)

        MsgC(Color(93, 210, 180), "[GCAL] Testing model/sequence combination\n")
        MsgC(Color(236, 242, 255), " - Input model: " .. modelPath .. "\n")
        MsgC(Color(236, 242, 255), " - Normalized: " .. normalizedPath .. "\n")
        MsgC(Color(236, 242, 255), " - Sequence: " .. sequenceName .. "\n")

        local testModel = ClientsideModel(normalizedPath, RENDERGROUP_BOTH)

        if not IsValid(testModel) then
            MsgC(Color(255, 106, 106), "[GCAL] ✗ Model failed to load!\n")
            MsgC(Color(255, 176, 93), "   Check that the file exists at: garrysmod/" .. normalizedPath .. "\n")
            return
        end

        MsgC(Color(93, 210, 180), "[GCAL] ✓ Model loaded successfully\n")

        testModel:SetNoDraw(true)
        testModel:SetupBones()

        local sequenceList = testModel.GetSequenceList and testModel:GetSequenceList() or {}
        MsgC(Color(236, 242, 255), " - Model has " .. #sequenceList .. " sequences\n")

        if #sequenceList == 0 then
            MsgC(Color(255, 176, 93), "   ! WARNING: Model has zero sequences!\n")
            MsgC(Color(255, 176, 93), "   ! This model may be a prop/ragdoll without animations\n")
            testModel:Remove()
            return
        end

        MsgC(Color(236, 242, 255), " - Available sequences:\n")
        for i, seqName in ipairs(sequenceList) do
            MsgC(Color(236, 242, 255), "   [" .. i .. "] " .. seqName .. "\n")
        end

        local seqID = testModel:LookupSequence(sequenceName)

        if seqID == -1 then
            MsgC(Color(255, 106, 106), "[GCAL] ✗ Sequence '" .. sequenceName .. "' NOT FOUND!\n")

            -- Try case-insensitive match
            local lowerSeq = string.lower(sequenceName)
            MsgC(Color(255, 176, 93), "   Attempting case-insensitive matches...\n")
            local foundMatch = false
            for i, seqName in ipairs(sequenceList) do
                if string.lower(seqName) == lowerSeq then
                    MsgC(Color(93, 210, 180), "   ✓ Found case-insensitive match: '" .. seqName .. "'\n")
                    foundMatch = true
                end
            end

            if not foundMatch then
                MsgC(Color(255, 176, 93), "   ! No case-insensitive matches found\n")
                MsgC(Color(255, 176, 93), "   ! Try one of the sequences listed above\n")
            end
        else
            MsgC(Color(93, 210, 180), "[GCAL] ✓ Sequence found! (ID: " .. seqID .. ")\n")
            local duration = testModel:SequenceDuration(seqID)
            MsgC(Color(236, 242, 255), "   - Duration: " .. duration .. " seconds\n")
        end

        testModel:Remove()
    end, nil, "Test a model and sequence combination directly. Usage: gcal_test_sequence <model_path> <sequence_name>")

    concommand.Add("gcal_debug_track", function(_, _, args)
        local trackID = args[1] or "legacy_left_arm"
        local track = GCAL.ActiveTracks[trackID]

        if not track then
            MsgC(Color(255, 176, 93), "[GCAL] No active track: " .. tostring(trackID) .. "\n")
            return
        end

        MsgC(Color(93, 210, 180), "[GCAL] Track debug for " .. tostring(trackID) .. "\n")
        MsgC(Color(236, 242, 255), " - anim: " .. tostring(track.name) .. "\n")
        MsgC(Color(236, 242, 255), " - model: " .. tostring(track.data and track.data.model or "<none>") .. "\n")
        MsgC(Color(236, 242, 255), " - sequence: " .. tostring(track.sequenceName or "<none>") .. "\n")
        MsgC(Color(236, 242, 255), " - seqID: " .. tostring(track.seqID) .. "\n")
        MsgC(Color(236, 242, 255), " - cycle: " .. tostring(math.Round(track.cycle or 0, 4)) .. "\n")
        MsgC(Color(236, 242, 255), " - lerp: " .. tostring(math.Round(track.lerpVal or 0, 4)) .. "\n")
        MsgC(Color(236, 242, 255), " - blockCode: " .. tostring(track.blockCode or false) .. "\n")
        MsgC(Color(236, 242, 255), " - blockCodeScope: " .. tostring(track.blockCodeScope or "<global>") .. "\n")
        MsgC(Color(236, 242, 255), " - poseOnlyLegacy: " .. tostring(track.poseOnlyLegacy or false) .. "\n")
        MsgC(Color(236, 242, 255), " - thirdperson: " .. tostring(track.thirdperson or false) .. "\n")
        MsgC(Color(236, 242, 255),
            " - thirdperson root bone: " .. tostring(track.debugThirdPersonRootBone or "<not cached>") .. "\n")
        MsgC(Color(236, 242, 255),
            " - thirdperson mode: " .. tostring(track.debugThirdPersonMode or "<not evaluated>") .. "\n")
        MsgC(Color(236, 242, 255), " - thirdperson host: " .. tostring(track.debugThirdPersonHost or "gcal") .. "\n")
        MsgC(Color(236, 242, 255),
            " - thirdperson model: " .. tostring(track.debugThirdPersonModel or "<not rendered>") .. "\n")
        MsgC(Color(236, 242, 255), " - thirdperson model valid: " .. tostring(IsValid(track.thirdpersonModel)) .. "\n")
        MsgC(Color(236, 242, 255),
            " - thirdperson model visible materials: " .. tostring(track.thirdpersonModelHasVisibleMaterials) .. "\n")
        MsgC(Color(236, 242, 255),
            " - thirdperson model ready frame: " .. tostring(track.thirdpersonModelReadyFrame or "<none>") .. "\n")
        MsgC(Color(236, 242, 255),
            " - thirdperson model draw frame: " .. tostring(track.debugThirdPersonModelDrawFrame or "<none>") .. "\n")
        MsgC(Color(236, 242, 255),
            " - thirdperson model distance: " .. tostring(track.debugThirdPersonModelDistance or "<none>") .. "\n")
        MsgC(Color(236, 242, 255), " - last arm target entity: " .. tostring(track.debugTargetEntity or "<none>") .. "\n")
        MsgC(Color(236, 242, 255), " - debugBoneCount: " .. tostring(track.debugBoneCount or 0) .. "\n")

        local ply = LocalPlayer()
        local weapon = IsValid(ply) and ply:GetActiveWeapon() or nil
        local vm = IsValid(ply) and ply:GetViewModel() or nil
        local handsEnt = IsValid(ply) and ply:GetHands() or nil
        local renderContext = GCAL:BuildWeaponRenderContext(ply, weapon, vm, handsEnt)
        vm = renderContext.vm

        if not IsValid(vm) then
            MsgC(Color(255, 176, 93), " - no valid viewmodel entity\n")
            return
        end

        MsgC(Color(236, 242, 255), " - weapon strategy: " .. tostring(renderContext.strategy_id) .. "\n")

        local flip = GetLegacyFlipState(weapon)
        if IsValid(weapon) then
            MsgC(Color(236, 242, 255), " - weapon class: " .. tostring(weapon:GetClass()) .. "\n")
            MsgC(Color(236, 242, 255), " - ViewModelFlipDefault: " .. tostring(flip.lefty) .. "\n")
            MsgC(Color(236, 242, 255), " - ViewModelFlip: " .. tostring(flip.flippedNow) .. "\n")
            MsgC(Color(236, 242, 255), " - flipmode: " .. tostring(flip.flipmode) .. "\n")
            MsgC(Color(236, 242, 255), " - legacy target side: " .. tostring(flip.targetSide) .. "\n")
        end

        vm:SetupBones()
        if IsValid(handsEnt) then handsEnt:SetupBones() end
        if IsValid(track.model) then track.model:SetupBones() end

        local targetBones = track.bones or {}
        if track.data and track.data.legacy then
            targetBones = flip.targetBones
        end

        local targetEnt = GCAL:ResolveArmTarget(renderContext, targetBones)
        if not IsValid(targetEnt) then
            MsgC(Color(255, 176, 93), " - no valid arm target entity\n")
            return
        end

        MsgC(Color(236, 242, 255), " - arm target entity: " .. tostring(targetEnt) .. "\n")

        local matched = 0
        local samples = 0
        for k, boneName in ipairs(track.bones or {}) do
            local targetBoneName = boneName
            if track.data and track.data.legacy then
                targetBoneName = flip.targetBones[k] or boneName
            end
            local targetBone = targetEnt:LookupBone(targetBoneName)
            local sourceBoneName = track.sourceBones and track.sourceBones[k] or boneName
            sourceBoneName = sourceBoneName == "ValveBiped.Bip01_L_Ulna" and "ValveBiped.Bip01_L_Forearm" or
                sourceBoneName
            local modelBone = IsValid(track.model) and track.model:LookupBone(sourceBoneName) or nil
            if targetBone ~= nil and targetBone >= 0 and modelBone ~= nil and modelBone >= 0 then
                matched = matched + 1
                MsgC(Color(236, 242, 255),
                    "   * " .. tostring(targetBoneName) .. " <- " .. tostring(sourceBoneName) .. "\n")

                if samples < 3 then
                    local targetMatrix = targetEnt:GetBoneMatrix(targetBone)
                    local sourceMatrix = track.model:GetBoneMatrix(modelBone)
                    if targetMatrix and sourceMatrix then
                        local targetPos = targetMatrix:GetTranslation()
                        local sourcePos = sourceMatrix:GetTranslation()
                        local delta = sourcePos - targetPos
                        MsgC(
                            Color(200, 220, 255),
                            "     source-target delta: " ..
                            string.format("%.3f, %.3f, %.3f", delta.x, delta.y, delta.z) .. "\n"
                        )
                        samples = samples + 1
                    end
                end
            end
        end

        MsgC(Color(236, 242, 255), " - matched bones: " .. tostring(matched) .. "\n")
    end, nil, "Debug an active GCAL track. Usage: gcal_debug_track [track]")

    concommand.Add("gcal_stop", function(_, _, args)
        local trackID = args[1]

        if trackID and trackID ~= "" then
            GCAL:StopTrack(trackID)
            MsgC(Color(93, 210, 180), "[GCAL] Stopped track " .. tostring(trackID) .. "\n")
            return
        end

        local stopped = 0
        for activeTrackID in pairs(GCAL.ActiveTracks or {}) do
            GCAL:StopTrack(activeTrackID)
            stopped = stopped + 1
        end

        MsgC(Color(93, 210, 180), "[GCAL] Stopped " .. tostring(stopped) .. " active track(s)\n")
    end, nil, "Stop one GCAL track, or every active track when no track is provided. Usage: gcal_stop [track]")

    hook.Add("NeedsDepthPass", "GCAL_VManipCamAttachment", function()
        if not GCAL.CamBone:GetBool() then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        for trackID, track in pairs(GCAL.ActiveTracks) do
            if trackID == "legs" then continue end
            if not IsValid(track.camModel) then continue end

            if trackID == "legacy_left_arm" and not ply:Alive() then
                GCAL:StopTrack(trackID)
                continue
            end

            track.camModel:SetupBones()
            local attachments = track.camModel:GetAttachments()
            if #attachments > 0 then
                track.attachment = track.camModel:GetAttachment(attachments[1].id)
            end
        end
    end)

    hook.Add("CalcView", "GCAL_VManipCam", function(ply, origin, angles, fov, self)
        if self == true then return end
        if not GCAL.CamBone:GetBool() then return end
        if ply:GetViewEntity() ~= ply or ply:ShouldDrawLocalPlayer() then return end

        -- Skip if no attachment to avoid suppressing other CalcView hooks
        local hasAttachment = false
        for trackID, track in pairs(GCAL.ActiveTracks) do
            if trackID == "legs" then continue end
            if track.attachment then
                hasAttachment = true; break
            end
        end
        if not hasAttachment then return end

        -- Compose with other mods' CalcView, then layer cambone on top
        local composed = hook.Run("CalcView", ply, origin, angles, fov, true) or {}
        local baseOrigin = composed.origin or origin
        local baseAngles = composed.angles or angles
        local baseFov = composed.fov or fov

        local newOrigin, newAngles, newFov = baseOrigin, baseAngles, baseFov
        for trackID, track in pairs(GCAL.ActiveTracks) do
            if trackID == "legs" then continue end
            if not track.attachment then continue end
            newOrigin, newAngles, newFov = GCAL:ComputeCamBoneView(track, ply, newOrigin, newAngles, newFov)
        end

        -- Apply viewmodel_fov adjustments
        for trackID, track in pairs(GCAL.ActiveTracks) do
            if trackID == "legs" then continue end
            if track.viewmodelFov and track.lerpVal then
                -- Scale FOV adjustment by inverse lerp (1 - lerpVal means full animation visibility)
                local fovScale = 1 - track.lerpVal
                newFov = newFov + (track.viewmodelFov * fovScale)
            end
        end

        return {
            origin = newOrigin,
            angles = newAngles,
            fov = newFov
        }
    end)

    hook.Add("StartCommand", "GCAL_VManipPreventReload", function(ply, ucmd)
        if VManip and VManip:IsActive() and not ply:ShouldDrawLocalPlayer() then
            ucmd:RemoveKey(IN_RELOAD)
        end
    end)

    hook.Add("TFA_PreReload", "GCAL_VManipPreventTFAReload", function()
        if VManip and VManip:IsActive() then return "no" end
    end)

    net.Receive("VManip_SimplePlay", function()
        local anim = net.ReadString()
        VManip:PlayAnim(anim)
    end)

    net.Receive("GCAL_Play", function()
        local anim = net.ReadString()
        local trackID = net.ReadString()
        if trackID == "" then trackID = nil end
        GCAL:Play(anim, trackID)
    end)

    net.Receive("GCAL_Stop", function()
        local trackID = net.ReadString()
        if trackID == "" then trackID = "default" end
        GCAL:StopTrack(trackID)
    end)

    net.Receive("VManip_StopHold", function()
        local anim = net.ReadString()
        if anim == "" then
            VManip:QuitHolding()
        else
            VManip:QuitHolding(anim)
        end
    end)
end

if SERVER then
    function GCAL:Play(arg1, arg2, recipients)
        local name, trackID
        if isstring(arg1) then
            name, trackID = arg1, arg2
        else
            name, trackID = arg2, nil
        end

        if not name then return false end

        net.Start("GCAL_Play")
        net.WriteString(name)
        net.WriteString(trackID or "")
        if recipients then
            net.Send(recipients)
        else
            net.Broadcast()
        end

        return true
    end

    function GCAL:StopTrack(trackID, recipients)
        net.Start("GCAL_Stop")
        net.WriteString(trackID or "")
        if recipients then
            net.Send(recipients)
        else
            net.Broadcast()
        end
    end
end
