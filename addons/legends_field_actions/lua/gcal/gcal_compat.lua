-- GCAL: GMod Compliant Armature Layer
-- Legacy Compatibility Shim

VManip = VManip or {}
VMLegs = VMLegs or {}
vmatrixpeakinfo = vmatrixpeakinfo or 0
VManip_modelname = VManip_modelname or ""
vmanipholdtime = vmanipholdtime or 0
VManip.VMatrixlerp = VManip.VMatrixlerp or 1
VManip.Cycle = VManip.Cycle or 0
VManip.Lerp_Peak = VManip.Lerp_Peak or 0
VManip.Lerp_Speed_In = VManip.Lerp_Speed_In or 1
VManip.Lerp_Speed_Out = VManip.Lerp_Speed_Out or 1
VManip.Lerp_Curve = VManip.Lerp_Curve or 1

-- MW Base expects VManip to be callable
setmetatable(VManip, {
    __call = function(t) return true end
})

-- Unify Registries (Ensures animations are visible everywhere)
GCAL.Anims = GCAL.Anims or {}
VManip.Anims = GCAL.Anims
VMLegs.Anims = GCAL.Anims
VManip.ActiveTracks = GCAL.ActiveTracks

-- DynaBase support
GCAL.DynaBase = GCAL.DynaBase or {}
GCAL.DynaBase.Sources = GCAL.DynaBase.Sources or {}
GCAL.DynaBase.Registered = GCAL.DynaBase.Registered or {}

local function GCAL_DynaBaseAvailable()
    return wOS ~= nil and wOS.DynaBase ~= nil and WOS_DYNABASE ~= nil
end

function GCAL:IsDynaBaseAvailable()
    return GCAL_DynaBaseAvailable()
end

local function GCAL_DynaBaseType(data)
    if data.type then return data.type end
    if data.Type then return data.Type end
    if GCAL_DynaBaseAvailable() and WOS_DYNABASE.REANIMATION then return WOS_DYNABASE.REANIMATION end

    return nil
end

local function GCAL_DynaBaseModelForGender(source, gender)
    if source.models and source.models[gender] then return source.models[gender] end
    if source.Models and source.Models[gender] then return source.Models[gender] end

    if GCAL_DynaBaseAvailable() then
        if gender == WOS_DYNABASE.FEMALE then return source.female or source.Female or source.shared or source.Shared end
        if gender == WOS_DYNABASE.MALE then return source.male or source.Male or source.shared or source.Shared end
        if gender == WOS_DYNABASE.ZOMBIE then return source.zombie or source.Zombie or source.shared or source.Shared end
    end

    return source.shared or source.Shared or source.male or source.Male or source.female or source.Female or source.zombie or source.Zombie
end

local function GCAL_DynaBaseInclude(model)
    if not model or model == "" or not IncludeModel then return false end

    IncludeModel(model)
    return true
end

function GCAL:RegisterDynaBaseSource(data)
    if not data then return false end

    local name = data.name or data.Name
    if not name or name == "" then return false end

    data.Name = name
    data.name = name
    GCAL.DynaBase.Sources[name] = data

    return true
end

function GCAL:RegisterDynaBaseMount(name, models)
    if not name or not models then return false end

    return self:RegisterDynaBaseSource({
        name = name,
        male = models.male or models.Male,
        female = models.female or models.Female,
        zombie = models.zombie or models.Zombie,
        shared = models.shared or models.Shared,
        models = models.models or models.Models
    })
end

local function GCAL_DynaBaseRegisterSources()
    if not GCAL_DynaBaseAvailable() then return end

    for name, source in pairs(GCAL.DynaBase.Sources) do
        if GCAL.DynaBase.Registered[name] then continue end

        local registerData = {
            Name = source.Name or source.name,
            Type = GCAL_DynaBaseType(source),
            Male = source.Male or source.male or source.Shared or source.shared,
            Female = source.Female or source.female or source.Shared or source.shared,
            Zombie = source.Zombie or source.zombie or source.Shared or source.shared
        }

        wOS.DynaBase:RegisterSource(registerData)
        GCAL.DynaBase.Registered[name] = true
    end
end

local function GCAL_DynaBasePreLoad(gender)
    if not GCAL_DynaBaseAvailable() then return end

    for _, source in pairs(GCAL.DynaBase.Sources) do
        local model = GCAL_DynaBaseModelForGender(source, gender)

        if istable(model) then
            for _, modelPath in ipairs(model) do
                GCAL_DynaBaseInclude(modelPath)
            end
        else
            GCAL_DynaBaseInclude(model)
        end
    end
end

hook.Add("InitLoadAnimations", "GCAL_DynaBase_RegisterSources", GCAL_DynaBaseRegisterSources)
hook.Add("PreLoadAnimations", "GCAL_DynaBase_PreLoad", GCAL_DynaBasePreLoad)

hook.Add("InitPostEntity", "GCAL_DynaBase_LateRegister", function()
    timer.Simple(0.25, GCAL_DynaBaseRegisterSources)
end)

-- Robust Legacy Translation Layer
function VManip:RegisterAnim(arg1, arg2, arg3)
    local name, data
    if isstring(arg1) then
        name, data = arg1, arg2
    else
        name, data = arg2, arg3
    end

    if not name or not data then return end

    if CLIENT and GCAL.Debug:GetBool() then
        print("[GCAL DEBUG] Legacy VManip registration request for:", name)
    end

    local xData = {
        model = data.model,
        sequence = data.sequence,
        lerp_peak = data.lerp_peak or 0.5,
        lerp_speed_in = data.lerp_speed_in or 1,
        lerp_speed_out = data.lerp_speed_out or 1,
        lerp_curve = data.lerp_curve or 1,
        speed = data.speed or 1,
        startcycle = data.startcycle or 0,
        loop = data.loop or false,
        holdtime = data.holdtime,
        sounds = data.sounds or {},
        group_name = "legacy_left_arm",
        bones = GCAL.GROUPS.LEFT_ARM,
        easing_in = "Legacy",
        easing_out = "Legacy",
        preventquit = data.preventquit,
        block_code = data.block_code,
        block_code_scope = data.block_code_scope,
        locktoply = data.locktoply,
        assurepos = data.assurepos,
        cam_ang = data.cam_ang,
        cam_angint = data.cam_angint,
        segmented = data.segmented,
        legacy = true,
        addon_name = data.addon_name or data.addon or GCAL.CurrentRegistrationSource or "Legacy VManip"
    }
    
    GCAL:RegisterAnim(name, xData)
end

function VManip:PlayAnim(name)
    local res = GCAL:Play(name, "legacy_left_arm")
    return res and true or false
end

function VManip:IsActive()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track ~= nil and IsValid(track.model) and (track.lerpVal or 1) < 1
end

function VManip:IsValid()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track ~= nil and IsValid(track.model)
end

function VManip:Remove()
    if self:IsActive() then
        hook.Run("VManipPreRemove", self:GetCurrentAnim())
    end

    GCAL:StopTrack("legacy_left_arm")
end

function VManip:GetCurrentAnim()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track and track.name
end

function VManip:GetVMGesture()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track and track.model
end

function VManip:GetLerp()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track and track.lerpVal or 0
end

function VManip:GetCycle()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track and track.cycle or 0
end

function VManip:SetCycle(newcycle)
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    if track then track.cycle = newcycle end
end

function VManip:IsSegmented()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track and track.segmented or false
end

function VManip:GetCurrentSegment()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track and track.curSegment
end

function VManip:GetSegmentCount()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track and track.segmentCount or 0
end

function VManip:IsPreventQuit()
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    return track and track.preventQuit or false
end

function VManip:QuitHolding(animtostop)
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    if track then
        if hook.Run("VManipPreHoldQuit", track.name, animtostop) == false then return end
        if (not animtostop and not track.preventQuit) or track.name == animtostop then
            track.holdQuit = true
            VManip.HoldQuit = true
            if track.segmented then track.lastSegment = true end
            hook.Run("VManipHoldQuit", track.name, animtostop)
        end
        if VManip.QueuedAnim == animtostop then VManip.QueuedAnim = nil end
    end
end

function VManip:QueueAnim(animtoqueue)
    if self:GetAnim(animtoqueue) then
        VManip.QueuedAnim = animtoqueue
    end
end

function VManip:PlaySegment(sequence, lastsegment, soundtable)
    local track = GCAL.ActiveTracks["legacy_left_arm"]
    if track then
        if not track.segmented or not track.segmentFinished or track.lastSegment then return false end
        if not IsValid(track.model) or track.model:LookupSequence(sequence) == -1 then return false end
        if hook.Run("VManipPrePlaySegment", track.name, sequence, lastsegment) == false then return false end

        track.model:ResetSequence(sequence)
        if IsValid(track.camModel) then track.camModel:ResetSequence(sequence) end
        if IsValid(track.thirdpersonModel) then track.thirdpersonModel:ResetSequence(sequence) end
        track.curSegment = sequence
        track.cycle = 0
        track.segmentFinished = false
        track.segmentCount = track.segmentCount + 1
        if lastsegment then
            track.lastSegment = true
            track.lerpPeakTime = CurTime() + track.lerpPeak
        end

        if soundtable then
            for soundPath, time in pairs(soundtable) do
                timer.Simple(time, function()
                    if VManip:GetCurrentAnim() == track.name and IsValid(LocalPlayer()) and LocalPlayer():Alive() then
                        if not GCAL.MuteSounds:GetBool() then
                            local overridePath = GCAL.GetAnimSoundOverride and GCAL:GetAnimSoundOverride(track.name)
                            LocalPlayer():EmitSound(overridePath or soundPath, 75, GCAL.SoundPitch:GetInt())
                        end
                    end
                end)
            end
        end

        hook.Run("VManipPlaySegment", track.name, sequence, lastsegment)
        return true
    end
    return false
end

function VManip:GetAnim(name)
    return GCAL.Anims[name]
end

function VManip:Reset()
    self:Remove()
    VManip.QueuedAnim = nil
end

-- VMLegs shim
function VMLegs:RegisterAnim(arg1, arg2, arg3)
    local name, data
    if isstring(arg1) then
        name, data = arg1, arg2
    else
        name, data = arg2, arg3
    end

    if not name or not data then return end

    if CLIENT and GCAL.Debug:GetBool() then
        print("[GCAL DEBUG] Legacy VMLegs registration request for:", name)
    end

    GCAL:RegisterAnim("legs_" .. name, {
        model = data.model,
        speed = data.speed or 1,
        group_name = "legs",
        forwardboost = data.forwardboost or 0,
        upwardboost = data.upwardboost or 0,
        sequence = name
    })
end

function VMLegs:PlayAnim(name)
    return GCAL:Play("legs_" .. name, "legs")
end

function VMLegs:IsActive()
    local track = GCAL.ActiveTracks["legs"]
    return track ~= nil and IsValid(track.model)
end

function VMLegs:GetAnim(name)
    return GCAL.Anims["legs_" .. tostring(name)]
end

function VMLegs:GetCurrentAnim()
    local track = GCAL.ActiveTracks["legs"]
    if not track or not track.name then return nil end

    if string.StartsWith(track.name, "legs_") then
        return string.sub(track.name, 6)
    end

    return track.name
end

function VMLegs:Remove()
    GCAL:StopTrack("legs")
end

GCAL.ImportedFiles = GCAL.ImportedFiles or {}

local importedFileSet = {}

-- Auto-Import Legacy Animations from other addons
local function GCAL_ImportLegacy()
    local path = "vmanip/anims/"
    local files = file.Find(path .. "*.lua", "LUA")

    for _, v in ipairs(files) do
        local fullPath = path .. v
        if not importedFileSet[fullPath] then
            importedFileSet[fullPath] = true
            table.insert(GCAL.ImportedFiles, fullPath)
            if SERVER then
                AddCSLuaFile(fullPath)
            end
            local previousSource = GCAL.CurrentRegistrationSource
            GCAL.CurrentRegistrationSource = string.StripExtension(v)
            include(fullPath)
            GCAL.CurrentRegistrationSource = previousSource
        end
    end
    
    if CLIENT then
        MsgC(Color(0, 255, 0), "[GCAL] Loaded legacy animations from " .. #files .. " files! :3\n")
    end
end

-- Run early to catch registrations
GCAL_ImportLegacy()

-- Run again later just in case
hook.Add("InitPostEntity", "GCAL_ImportLegacy_Late", function()
    timer.Simple(0.1, GCAL_ImportLegacy)
end)

if CLIENT then
    concommand.Add("gcal_list_files", function()
        local files = GCAL.ImportedFiles or {}
        MsgC(Color(93, 210, 180), "[GCAL] Imported legacy files (" .. #files .. "):\n")

        for _, path in ipairs(files) do
            MsgC(Color(236, 242, 255), " - " .. tostring(path) .. "\n")
        end
    end)

    concommand.Add("gcal_dynabase_status", function()
        local count = table.Count(GCAL.DynaBase.Sources or {})
        MsgC(Color(93, 210, 180), "[GCAL] DynaBase available: " .. tostring(GCAL:IsDynaBaseAvailable()) .. "\n")
        MsgC(Color(93, 210, 180), "[GCAL] Queued DynaBase sources: " .. count .. "\n")

        for name in pairs(GCAL.DynaBase.Sources or {}) do
            MsgC(Color(236, 242, 255), " - " .. tostring(name) .. "\n")
        end
    end)
end

-- Weapon Base Compatibility Hooks
if CLIENT then
    local function GCAL_VManipFallback(_, matrix)
        return matrix or Matrix()
    end

    for _, metaName in ipairs({"Entity", "Weapon", "Player"}) do
        local meta = FindMetaTable(metaName)
        if meta and not meta.VManip then
            meta.VManip = GCAL_VManipFallback
        end
    end

    local function OwnerViewModel(ply, weapon)
        local owner = IsValid(weapon) and weapon.GetOwner and weapon:GetOwner() or ply
        if IsValid(owner) and owner.GetViewModel then return owner:GetViewModel() end
        if IsValid(ply) and ply.GetViewModel then return ply:GetViewModel() end
    end

    GCAL:RegisterWeaponBaseStrategy("tfa", {
        detect = function(_, weapon)
            return IsValid(weapon) and weapon.IsTFAWeapon
        end,
        resolveViewModel = OwnerViewModel,
        resolveLegsViewModel = OwnerViewModel
    })

    GCAL:RegisterWeaponBaseStrategy("arccw", {
        detect = function(_, weapon)
            return IsValid(weapon) and weapon.ArcCW
        end,
        resolveViewModel = OwnerViewModel,
        resolveLegsViewModel = OwnerViewModel,
        preActCheck = function(ply, weapon, name, vm)
            if weapon:ShouldDrawCrosshair() or (IsValid(vm) and vm:GetCycle() > 0.99) then return true end
        end,
        prePlayAnim = function(_, weapon)
            if weapon:GetNWBool("reloading") then return false end
        end
    })

    GCAL:RegisterWeaponBaseStrategy("arc9", {
        detect = function(_, weapon)
            return IsValid(weapon)
                and (
                    weapon.ARC9
                    or weapon.ARC9Weapon
                    or weapon.Base == "arc9_base"
                    or (isfunction(weapon.DoTPIK) and isfunction(weapon.GetWM))
                )
        end,
        resolveViewModel = OwnerViewModel,
        resolveLegsViewModel = OwnerViewModel,
        thirdPersonMethod = function(_, weapon)
            local arc9TPIK = GetConVar("arc9_tpik")
            local noTPIK = weapon.NoTPIK or (ARC9 and ARC9.NoTPIK)
            if not noTPIK and weapon.GetProcessedValue then
                local ok, processedNoTPIK = pcall(weapon.GetProcessedValue, weapon, "NoTPIK", true)
                if ok then noTPIK = processedNoTPIK end
            end

            local canUseARC9TPIK = ARC9
                and ARC9.TPIK
                and ARC9.TPIK.NativeExtensionPoints
                and isfunction(ARC9.TPIK.GetIKTargets)
                and (not arc9TPIK or arc9TPIK:GetBool())

            if canUseARC9TPIK and not noTPIK then return "arc9_tpik" end
            -- Fall back to GCAL's own TPIK (normal method)
            return "normal"
        end,
        prePlayAnim = function(_, weapon)
            if weapon.GetReloading and weapon:GetReloading() then return false end
        end
    })

    GCAL:RegisterWeaponBaseStrategy("mwbase", {
        detect = function(_, weapon)
            return IsValid(weapon) and IsValid(weapon.m_ViewModel)
        end,
        resolveViewModel = function(_, weapon)
            return weapon.m_ViewModel
        end,
        resolveLegsViewModel = function(_, weapon)
            return weapon.m_ViewModel
        end,
        prePlayAnim = function(_, weapon)
            if weapon.GetIsReloading and weapon:GetIsReloading() then return false end
        end
    })

    hook.Add("VManipPreActCheck", "GCAL_Compat_StrategyActCheck", function(name, vm)
        local ply = LocalPlayer()
        local weapon = IsValid(ply) and ply:GetActiveWeapon() or nil
        local strategy = GCAL:GetWeaponBaseStrategy(ply, weapon)
        if strategy and strategy.preActCheck then
            return strategy.preActCheck(ply, weapon, name, vm, strategy)
        end
    end)

    hook.Add("VManipPrePlayAnim", "GCAL_Compat_StrategyPrePlay", function(name)
        local ply = LocalPlayer()
        local weapon = IsValid(ply) and ply:GetActiveWeapon() or nil
        local strategy = GCAL:GetWeaponBaseStrategy(ply, weapon)
        if strategy and strategy.prePlayAnim then
            return strategy.prePlayAnim(ply, weapon, name, strategy)
        end
    end)

    hook.Add("VManipVMEntity", "GCAL_Compat_StrategyVMEntity", function(ply, weapon)
        local strategy = GCAL:GetWeaponBaseStrategy(ply, weapon)
        if not strategy or not strategy.resolveViewModel then return end

        local vm = IsValid(ply) and ply.GetViewModel and ply:GetViewModel() or nil
        return strategy.resolveViewModel(ply, weapon, vm, nil, strategy)
    end)

    hook.Add("VManipLegsVMEntity", "GCAL_Compat_StrategyLegsVMEntity", function(ply, weapon)
        local strategy = GCAL:GetWeaponBaseStrategy(ply, weapon)
        if not strategy then return end

        local resolver = strategy.resolveLegsViewModel or strategy.resolveViewModel
        if resolver then
            local vm = IsValid(ply) and ply.GetViewModel and ply:GetViewModel() or nil
            return resolver(ply, weapon, vm, nil, strategy)
        end
    end)
end
