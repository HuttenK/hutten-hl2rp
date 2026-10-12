include("shared.lua")
AddCSLuaFile("shared.lua")

function ENT:Initialize()
    self:SetNoDraw(true)
    self:SetSolid(SOLID_NONE)
    self:SetNotSolid(true)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetPlaybackRate(math.Rand(0.5, 1))
    self.LastUpdate = CurTime()
    self.ExpiresAt = CurTime() + 20
    self.CycleEnd = GetConVar("bd_quicker_ragdoll"):GetBool() and math.Rand(0.5, 0.8) or 0.99
    self.BonePairs = {}
    local rag = self.Ragdoll
    if not IsValid(rag) then self:Remove() return end
    -- SetupBones is client-only. This server driver uses the engine's
    -- animated bone positions; AutomaticFrameAdvance is enabled in shared.lua.
    -- Use bone names directly. Physics indices on the donor and target do
    -- not match, and extra bones on Workshop models must simply be skipped.
    for i = 0, rag:GetPhysicsObjectCount() - 1 do
        local physics = rag:GetPhysicsObjectNum(i)
        local bone = rag:TranslatePhysBoneToBone(i)
        local name = bone and bone >= 0 and rag:GetBoneName(bone)
        local donor = name and self:LookupBone(name)
        if IsValid(physics) and donor and donor >= 0 then
            self.BonePairs[#self.BonePairs + 1] = {physics = physics, bone = donor,
                passive = self.AnimGenerate and i > 0 and math.random(1, 2) == 1}
            physics:EnableMotion(true)
            physics:Wake()
            if name == "ValveBiped.Bip01_Pelvis" then
                self.Anchor = {physics = physics, bone = donor}
            end
        end
    end
    -- Unsupported skeletons remain ordinary, visible physical ragdolls.
    if #self.BonePairs == 0 then self:Remove() end
end

-- A prop_ragdoll origin follows its physics root (usually the pelvis), whereas
-- the animation model origin is at the feet. Anchor once, after ResetSequence,
-- instead of adding standing pelvis height to an already elevated origin.
function ENT:AlignPose()
    if self.PoseOffset then return true end
    local anchor = self.Anchor or self.BonePairs[1]
    if not anchor or not IsValid(anchor.physics) then return false end
    local donor = self:GetBonePosition(anchor.bone)
    if not donor or donor == self:GetPos() then return false end
    self.PoseOffset = anchor.physics:GetPos() - donor
    return true
end

function ENT:Think()
    local rag = self.Ragdoll
    if not IsValid(rag) or rag.BD_AnimationInterrupted then self:Remove() return end
    if rag:IsPlayerHolding() then
        rag.BD_AnimationInterrupted = true
        self:Remove()
        return
    end
    if CurTime() >= self.ExpiresAt or self:GetCycle() >= self.CycleEnd then
        if self.FinishFunc then self.FinishFunc() end
        self:Remove()
        return
    end
    local delta = math.Clamp(CurTime() - self.LastUpdate, 0.001, 0.1)
    if not self:AlignPose() then
        self.LastUpdate = CurTime()
        self:NextThink(CurTime())
        return true
    end
    -- Release the last part of the pose progressively so gravity can settle
    -- the real body instead of holding it suspended until abrupt removal.
    local strength = math.Clamp((self.CycleEnd - self:GetCycle()) / 0.2, 0, 1)
    for _, pair in ipairs(self.BonePairs) do
        local physics = pair.physics
        if IsValid(physics) and not pair.passive then
            local pos, ang = self:GetBonePosition(pair.bone)
            if pos and ang then
                pos = pos + self.PoseOffset
                local trace = util.TraceLine({start = physics:GetPos(), endpos = pos,
                    filter = {self, rag}, mask = MASK_SOLID_BRUSHONLY})
                if not trace.Hit then
                    physics:Wake()
                    physics:ComputeShadowControl({secondstoarrive = 0.06, pos = pos, angle = ang,
                        maxangular = 400 * strength, maxangulardamp = 200, maxspeed = 80 * (self.LerpScale or 1) * strength,
                        maxspeeddamp = 45, teleportdistance = 0, deltatime = delta})
                end
            end
        end
    end
    -- Do not pin the donor origin above a traced floor: animation bone heights
    -- already include the authored ground offset. The ragdoll remains physical.
    self.LastUpdate = CurTime()
    self:NextThink(CurTime())
    return true
end

function ENT:OnRemove()
    local rag = self.Ragdoll
    if IsValid(rag) and rag.AnimModule == self then rag.AnimModule = nil end
    -- No physics objects were made intangible or had their contents changed.
    -- Removing this controller immediately hands the body back to physics.
end
