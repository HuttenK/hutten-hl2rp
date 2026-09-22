-- Reuse the mounted addon's viewmodel without activating its separate SWEP
-- protection/filter state or altering the player's inventory and weapon selection.
local M = ix.GasMask
if M.CancelAnimation then M.CancelAnimation() end
local motion
local modelPath = "models/weapons/black_ops_1/c_gasmask.mdl"

function M.CancelAnimation()
    if motion then
        if IsValid(motion.hands) then motion.hands:Remove() end
        if IsValid(motion.model) then motion.model:Remove() end
    end
    motion = nil
end

function M.RequestAnimation(wearing, item, soundPath)
    M.CancelAnimation()
    -- A respirator has no matching mask animation in the supplied addon.
    if not item or not M.Profile(item).visor or not file.Exists(modelPath, "GAME") then return false end
    motion = {wearing = wearing, queued = RealTime(), sound = soundPath}
    return true
end

local function start(client)
    local function unavailable()
        if file.Exists("sound/" .. motion.sound, "GAME") then surface.PlaySound(motion.sound) end
        M.CancelAnimation()
    end
    local model = ClientsideModel(modelPath, RENDERGROUP_VIEWMODEL)
    if not IsValid(model) then unavailable() return end
    motion.model = model
    model:SetNoDraw(true)
    local sequence = model:SelectWeightedSequence(motion.wearing and ACT_VM_DRAW or ACT_VM_HOLSTER)
    if not sequence or sequence < 0 then unavailable() return end
    motion.sequence = sequence
    motion.duration = math.Clamp(model:SequenceDuration(sequence), 0.25, 8)
    motion.created = FrameNumber()
    motion.weapon = client:GetActiveWeapon()
    local source = client:GetHands()
    local handsPath = IsValid(source) and source:GetModel() or "models/weapons/c_arms_citizen.mdl"
    local hands = ClientsideModel(handsPath, RENDERGROUP_VIEWMODEL)
    if IsValid(hands) then
        motion.hands = hands
        hands:SetNoDraw(true)
        hands:SetParent(model)
        hands:AddEffects(EF_BONEMERGE)
        if IsValid(source) then
            hands:SetSkin(source:GetSkin())
            for _, group in ipairs(source:GetBodyGroups()) do hands:SetBodygroup(group.id, source:GetBodygroup(group.id)) end
        end
    end
end

function M.UpdateAnimation(client, visible)
    if not motion then return end
    if not IsValid(client) or not client:Alive() or client:GetLocalVar("ragdoll", 0) ~= 0 or
        client:GetNWBool("GasMaskIsOn") or client:GetNWBool("BA2_GasmaskOn") then M.CancelAnimation() return end
    if not motion.model then
        -- Inventory obscures first person: begin when the player closes it.
        if visible then start(client) end
        return
    end
    if not IsValid(motion.model) or not visible or client:GetActiveWeapon() ~= motion.weapon then
        M.CancelAnimation(); return
    end
    if not motion.started then
        -- ResetSequence after creation, not during the SetModel frame.
        if FrameNumber() == motion.created then return end
        motion.model:ResetSequence(motion.sequence)
        motion.model:SetPlaybackRate(0)
        motion.started = RealTime()
        if file.Exists("sound/" .. motion.sound, "GAME") then surface.PlaySound(motion.sound) end
    end
    motion.fraction = math.Clamp((RealTime() - motion.started) / motion.duration, 0, 1)
    motion.model:SetCycle(motion.fraction)
    if motion.fraction >= 1 then M.CancelAnimation() end
end

function M.AnimationVisor(worn)
    if not motion then return worn end
    local fraction = motion.fraction or 0
    if motion.wearing then return fraction >= 0.65 end
    return fraction < 0.25
end

function M.AnimationActive()
    return motion and motion.started and IsValid(motion.model) and M.Visible(LocalPlayer()) or false
end

hook.Add("PreDrawViewModel", "ixGasMaskHands", function()
    if M.AnimationActive() then return true end
end)
hook.Add("PreDrawPlayerHands", "ixGasMaskHands", function()
    if M.AnimationActive() then return true end
end)
hook.Add("CreateMove", "ixGasMaskHands", function(command)
    if M.AnimationActive() then
        command:RemoveKey(IN_ATTACK); command:RemoveKey(IN_ATTACK2); command:RemoveKey(IN_RELOAD)
    end
end)
hook.Add("PostDrawEffects", "ixGasMaskHands", function()
    if not M.AnimationActive() then return end
    local model, hands = motion.model, motion.hands
    local origin, angles = EyePos(), EyeAngles()
    cam.Start3D(origin, angles, 62, 0, 0, ScrW(), ScrH(), 0.1, 4096)
    cam.IgnoreZ(true)
    local ok, err = xpcall(function()
        model:SetPos(origin); model:SetAngles(angles); model:SetupBones(); model:DrawModel()
        if IsValid(hands) then hands:SetupBones(); hands:DrawModel() end
    end, debug.traceback)
    cam.IgnoreZ(false)
    cam.End3D()
    if not ok then M.CancelAnimation(); ErrorNoHalt("[Gas mask animation] " .. tostring(err) .. "\n") end
end)
hook.Add("ShutDown", "ixGasMaskHands", M.CancelAnimation)
