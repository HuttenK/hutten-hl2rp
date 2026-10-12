GCAL = GCAL or {}
GCAL.Legs = GCAL.Legs or {}
VMLegs = VMLegs or {}

local playermodelbonesupper = {
    "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Clavicle",
    "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Neck1",
    "ValveBiped.Bip01_Head1", "ValveBiped.Bip01_L_Finger4", "ValveBiped.Bip01_L_Finger41",
    "ValveBiped.Bip01_L_Finger42", "ValveBiped.Bip01_L_Finger3", "ValveBiped.Bip01_L_Finger31",
    "ValveBiped.Bip01_L_Finger32", "ValveBiped.Bip01_L_Finger2", "ValveBiped.Bip01_L_Finger21",
    "ValveBiped.Bip01_L_Finger22", "ValveBiped.Bip01_L_Finger1", "ValveBiped.Bip01_L_Finger11",
    "ValveBiped.Bip01_L_Finger12", "ValveBiped.Bip01_L_Finger0", "ValveBiped.Bip01_L_Finger01",
    "ValveBiped.Bip01_L_Finger02", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_UpperArm",
    "ValveBiped.Bip01_R_Clavicle", "ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Finger4",
    "ValveBiped.Bip01_R_Finger41", "ValveBiped.Bip01_R_Finger42", "ValveBiped.Bip01_R_Finger3",
    "ValveBiped.Bip01_R_Finger31", "ValveBiped.Bip01_R_Finger32", "ValveBiped.Bip01_R_Finger2",
    "ValveBiped.Bip01_R_Finger21", "ValveBiped.Bip01_R_Finger22", "ValveBiped.Bip01_R_Finger1",
    "ValveBiped.Bip01_R_Finger11", "ValveBiped.Bip01_R_Finger12", "ValveBiped.Bip01_R_Finger0",
    "ValveBiped.Bip01_R_Finger01"
}

if CLIENT then
    local function GetMainEyePos()
        return EyePos()
    end

    local function GetMainEyeAngles()
        return EyeAngles()
    end

    function GCAL.Legs:Update(ply)
        local track = GCAL.ActiveTracks["legs"]
        if not track then return end
        
        local eyeAng = GetMainEyeAngles()
        local eyePos = GetMainEyePos()
        local velocity = ply:GetVelocity()
        
        -- Accurate leg positioning (Eye-relative)
        local legAng = Angle(0, eyeAng.y, 0)
        local forwardBoost = track.data.forwardboost or 4
        local upwardBoost = track.data.upwardboost or 0
        
        -- Procedural movement sway
        local moveSpeed = velocity:Length()
        local sway = Vector(0, 0, 0)
        if moveSpeed > 10 then
            local t = CurTime() * 10
            sway.z = math.sin(t) * 0.5
            sway.x = math.cos(t * 0.5) * 0.5
        end
        
        -- Calculate final position (assuming model origin is at feet/ground)
        -- We usually want to offset by a standard player height if the model is full body
        -- But VManip legs models are usually just legs starting from hips
        local eyeVec = EyeVector()
        local finalPos = eyePos
            + (legAng:Forward() * forwardBoost)
            + Vector(0, 0, upwardBoost)
            + ((eyeVec * Vector(1, 1, 0)):GetNormalized() * eyeVec.z * 16)
            + sway
            
        track.model:SetPos(finalPos)
        track.model:SetAngles(legAng)
        
        -- Update the internal player model for the legs
        if IsValid(track.legModel) then
            track.legModel:SetParent(track.model)
            track.legModel:AddEffects(EF_BONEMERGE)
        end
    end
end

-- Hook up VMLegs:PlayAnim in compat or here
function VMLegs:PlayAnim(name)
    local animName = "legs_" .. name
    local res = GCAL:Play(animName, "legs")
    if not res or not CLIENT then return res end

    local track = GCAL.ActiveTracks["legs"]
    local ply = LocalPlayer()
    if not track or not IsValid(ply) or not IsValid(track.model) then return res end

    track.legModel = ClientsideModel(string.Replace(ply:GetModel(), "models/models/", "models/"), RENDERGROUP_TRANSLUCENT)
    if not IsValid(track.legModel) then return res end

    track.legModel:SetPos(ply:GetPos())
    track.legModel:SetAngles(ply:GetAngles())

    local hands = ply:GetHands()
    if IsValid(hands) then
        track.legModel.GetPlayerColor = hands.GetPlayerColor
    end

    track.legModel:SetParent(track.model)
    track.legModel:AddEffects(EF_BONEMERGE)
    if track.legModel.SnatchModelInstance then track.legModel:SnatchModelInstance(ply) end
    track.legModel:SetSkin(ply:GetSkin())

    for i = 0, track.legModel:GetNumBodyGroups() do
        track.legModel:SetBodygroup(i, ply:GetBodygroup(i))
    end

    for _, boneName in pairs(playermodelbonesupper) do
        local bone = track.legModel:LookupBone(boneName)
        if bone ~= nil then
            track.legModel:ManipulateBoneScale(bone, Vector(0, 0, 0))
        end
    end

    return res
end
