ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "QActor"
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true

if SERVER then
    function ENT:Initialize()
        ix.questDirector:InitializePlacementPhysics(self)
    end

    function ENT:ApplyDefinition(row)
        self:SetSkin(row.skin)
        for id, value in pairs(row.bodygroups) do self:SetBodygroup(tonumber(id), value) end
        timer.Simple(0, function()
            if not IsValid(self) then return end
            local sequence = self:LookupSequence(row.sequence)
            if sequence < 0 then sequence = self:SelectWeightedSequence(ACT_IDLE) end
            if sequence >= 0 then self:ResetSequence(sequence) end
            self:SetCycle(row.cycle)
            self:SetPlaybackRate(row.animate and 1 or 0)
            for name, value in pairs(row.pose) do self:SetPoseParameter(name, value) end
        end)
    end

    function ENT:Speak(text)
        local Q = ix.questDirector
        local row = Q.defs.npc[self.ixQuestDefinition]
        if not row or not row.talk or (self.ixNextSpeech or 0) > CurTime() then return end
        self.ixNextSpeech = CurTime() + 1
        local sequence = row.talkSequence == "auto" and self:SelectWeightedSequence(ACT_GMOD_GESTURE_ITEM_GIVE) or self:LookupSequence(row.talkSequence)
        if row.talkSequence == "auto" and sequence < 0 then
            for _, name in ipairs({"gesture_item_give", "gesture_hello", "gesture_disagree", "gesture_wave"}) do
                sequence = self:LookupSequence(name)
                if sequence >= 0 then break end
            end
        end
        if sequence >= 0 then
            self:RemoveAllGestures()
            local layer = self:AddGestureSequence(sequence, true)
            if layer and layer >= 0 then
                self:SetLayerLooping(layer, true)
                self:SetLayerAutokill(layer, false)
                self:SetLayerBlendIn(layer, 0.2)
                self:SetLayerBlendOut(layer, 0.2)
                local stamp = self.ixNextSpeech
                timer.Simple(math.Clamp((utf8.len(text) or #text) / 14, 2, 15), function()
                    if IsValid(self) and self.ixNextSpeech == stamp then self:RemoveAllGestures() end
                end)
            end
        end
    end

    function ENT:Use(client)
        if not IsValid(client) or not client:IsPlayer() or (client.ixQDUse or 0) > CurTime() then return end
        client.ixQDUse = CurTime() + 0.5
        ix.questDirector:UsePlacement(client, self)
    end

    function ENT:OnTakeDamage() return 0 end
else
    ENT.PopulateEntityInfo = true
    function ENT:OnPopulateEntityInfo(tooltip)
        local title = tooltip:AddRow("name")
        title:SetText(self:GetNetVar("questLabel", self.PrintName)) title:SizeToContents()
        local hint = tooltip:AddRow("questHint")
        hint:SetText(ix.questDirector.CanEdit(LocalPlayer()) and LocalPlayer():GetMoveType() == MOVETYPE_NOCLIP
            and "E — настройки и удаление размещения" or (self:GetNetVar("questEnabled", false)
            and "E — взаимодействовать" or "Квестовый объект выключен"))
        hint:SizeToContents()
    end
    function ENT:Draw() self:DrawModel() end
end
