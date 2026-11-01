-- Installed ARC9 Weapon Base 2910505837; GetAttachmentPos excerpt, captured 2026-10-11.
SWEP.ModelVersion = 0
local v0, a0 = Vector(0, 0, 0), Angle(0, 0, 0)
local wwWorldToLocal = WorldToLocal
local llLocalToWorld = LocalToWorld

SWEP.AttPosCache = {}

local swepGetProcessedValue = SWEP.GetProcessedValue

function SWEP:GetAttachmentPos(slottbl, wm, idle, nomodeloffset, custompos, customang, dupli)
    dupli = dupli or 0
    idle = idle or false
    local parentmdl = nil
    if custompos then wm = true end

    if wm then
        if slottbl.WMBase then
            parentmdl = self:GetOwner()
            if !IsValid(parentmdl) then parentmdl = self end
            if custompos then parentmdl = nil end
        else
            if custompos then
                parentmdl = self.CModel[1]
                if parentmdl then parentmdl:SetupBones() end
            else
                parentmdl = self.WModel and self.WModel[1]
            end
        end
    else
        parentmdl = self:GetVM()
    end

    if idle then
        parentmdl = ClientsideModel(self.ViewModel)
        parentmdl:SetPos(vector_origin)
        parentmdl:SetAngles(angle_zero)
        parentmdl:SetNoDraw(true)

        local anim = self:TranslateAnimation("idle")
        local ae = self:GetAnimationEntry(anim)
        local seq = parentmdl:LookupSequence(self:RandomChoice(ae.Source))

        parentmdl:ResetSequence(seq)
        parentmdl:SetPoseParameter("sights", 1)

        parentmdl:SetupBones()
        parentmdl:InvalidateBoneCache()

        table.insert(ARC9.CSModelPile, {Model = parentmdl, Weapon = self, Version = self.ModelVersion})
    end

    local bone = slottbl.Bone
    local atttbl = {}

    if slottbl.WMBase then
        bone = (self:ShouldTPIK() and self.TPIKParentToSpine4) and "ValveBiped.Bip01_Spine4" or "ValveBiped.Bip01_R_Hand"
    end

    if slottbl.Installed then
        atttbl = self:GetFinalAttTable(slottbl)
    end

    local icon_offset = slottbl.Icon_Offset or v0

    local offset_pos = slottbl.Pos or v0
    local offset_ang = slottbl.Ang or a0
    local bpos, bang = v0, a0

    if dupli > 0 then
        local dupli_tbl = slottbl.DuplicateModels[dupli]
        if dupli_tbl then
            offset_pos = dupli_tbl.Pos or offset_pos
            offset_ang = dupli_tbl.Ang or offset_ang
            bone = dupli_tbl.Bone or bone
        end
    end

    if parentmdl and bone then
        local boneindex = parentmdl:LookupBone(bone)

        if !boneindex then return v0, a0, v0 end

        if parentmdl == self:GetOwner() then
            parentmdl:SetupBones()
            parentmdl:InvalidateBoneCache()
        end

        local bonemat = parentmdl:GetBoneMatrix(boneindex)
        if bonemat then
            bpos = bonemat:GetTranslation()
            bang = bonemat:GetAngles()
        end

        if !bang or !bpos then
            bang = self:GetAngles()
            bpos = self:GetPos()
        end
    elseif custompos then
        bpos = custompos
        bang = customang or a0
    end

    local cust = self:GetCustomize()
    local possiblecache = self.AttPosCache[slottbl.Address] -- att pos cache
    if !cust and possiblecache then
        -- if (possiblecache[4] or 0) > CurTime() then
            local qpos, qang = llLocalToWorld(possiblecache[1], possiblecache[2], bpos, bang)
            return qpos, qang, possiblecache[3]
        -- end
    end

    if slottbl.OriginalAddress then
        local eles = self:GetAttachmentElements()

        for _, ele in ipairs(eles) do
            local mods = ele.AttPosMods
            if mods then
                local mod_data = mods[slottbl.OriginalAddress]
                if mod_data then
                    offset_pos = mod_data.Pos or offset_pos
                    offset_ang = mod_data.Ang or offset_ang
                    icon_offset = mod_data.Icon_Offset or icon_offset
                end
            end
        end
    end

    if wm then
        offset_pos = offset_pos * (self.WorldModelOffset.Scale or 1)
    end

    local apos, aang = llLocalToWorld(Vector(offset_pos[1], -offset_pos[2], offset_pos[3]), bang, bpos, bang)

    if !nomodeloffset then
        offset_ang = offset_ang + (atttbl.ModelAngleOffset or a0)
    end

    aang:Set(bang)

    local forward = aang:Forward()
    local right = aang:Right()
    local up = aang:Up()

    aang:RotateAroundAxis(forward, offset_ang.r)
    aang:RotateAroundAxis(right, offset_ang.p)
    aang:RotateAroundAxis(up, offset_ang.y)

    if !nomodeloffset and atttbl.ModelOffset then
        local moffset = atttbl.ModelOffset * (slottbl.Scale or 1)
        if wm then
            moffset = moffset * (self.WorldModelOffset.Scale or 1)
        end

        -- apos = apos + forward * moffset.x + right * moffset.y + up * moffset.z
        apos = apos + aang:Forward() * moffset.x + aang:Right() * moffset.y + aang:Up() * moffset.z
    end

    if idle then SafeRemoveEntity(parentmdl) end

    self.AttTempDataTbl = self.AttTempDataTbl or {}
    local data = self.AttTempDataTbl
    data.pos = apos
    data.ang = aang
    data.atttbl = atttbl
    data.slottbl = slottbl

    data = self:RunHook("Hook_GetAttachmentPos", data) or data

    apos = data.pos or apos
    aang = data.ang or aang

    if slottbl.Address and !cust then -- att pos cache
        local ypos, yang = wwWorldToLocal(apos, aang, bpos, bang)
        self.AttPosCache[slottbl.Address] = { ypos, yang, icon_offset } -- , CurTime() + 55}
    end

    return apos, aang, icon_offset
end

