local Q, UI = ix.questDirector, ix.questDirector.ui
local D = Q.dialogueUI

local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if not istable(a) then return a == b end
    for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

function Q:GroupDisplayView(view)
    local data = table.Copy(view)
    for _, member in ipairs(data.members) do member.displayName = self:RememberedName(member.character) end
    table.sort(data.members, function(a, b)
        if a.leader ~= b.leader then return a.leader end
        return a.character < b.character
    end)
    if data.quest.maxMembers <= 1 or #data.members >= data.quest.maxMembers then data.candidates = {} end
    for _, candidate in ipairs(data.candidates) do candidate.displayName = self:RememberedName(candidate.character) end
    table.sort(data.candidates, function(a, b) return a.character < b.character end)
    return data
end

local function duration(seconds)
    if seconds < 60 then return math.ceil(seconds) .. " сек." end
    if seconds < 3600 then return math.ceil(seconds / 60) .. " мин." end
    return math.Round(seconds / 3600, 1) .. " ч."
end

function Q:GroupDialogue(frame)
    local dialogue = self.dialoguePanel
    if IsValid(dialogue) and dialogue.placement == frame.placement and dialogue.character == frame.character then return dialogue end
end

function Q:ShowGroup(view)
    local existing = self.groupPanel
    local character = LocalPlayer():GetCharacter()
    if not character then return end
    if IsValid(existing) and existing.placement == view.placement and existing.questID == view.quest.id and existing.character == character:GetID() then
        existing:Render(view) return
    end
    if IsValid(existing) then existing:Remove() end
    local frame = vgui.Create("DFrame")
    frame:SetTitle("") frame:ShowCloseButton(false) frame:DockPadding(0, 0, 0, 0)
    frame:SetSize(620, 300) frame.Paint = D.Border
    frame.placement, frame.questID, frame.character = view.placement, view.quest.id, character:GetID()
    frame.groupID = view.group
    frame.actionGeneration, frame.noticeText = 0, ""
    self.groupPanel = frame
    Q:SetupPlayerWindow(frame, "group")

    local header = frame:Add("DPanel")
    header.Paint = function(_, w, h) surface.SetDrawColor(D.style.outline) surface.DrawRect(12, h - 1, w - 24, 1) end
    local title = header:Add("DLabel") title:SetFont(D.fonts.title) title:SetTextColor(D.colors.text)
    title:SetWrap(false) title:SetContentAlignment(4) title:SetMouseInputEnabled(false)
    local close = header:Add("DButton") close:SetText("×") close:SetFont(D.fonts.title) close:SetTextColor(D.colors.text)
    close.Paint = function() end close.DoClick = function() frame:Remove() end
    Q:DragPlayerWindow(frame, header)
    local body = frame:Add("DScrollPanel") D.ScrollStyle(body) frame.body = body
    frame.notice = frame:Add("DLabel") frame.notice:SetFont(D.fonts.small) frame.notice:SetTextColor(D.colors.label)
    frame.notice:SetWrap(false) frame.notice:SetContentAlignment(7)
    local actions = frame:Add("DPanel") actions.Paint = function() end
    local accept = D.Answer(actions, "Принять задание", "finish", function()
        frame:Action("start", {placement = frame.placement}, function(message)
            local dialogue = Q:GroupDialogue(frame)
            frame:Remove()
            notification.AddLegacy(isstring(message) and message or "Задание принято.", NOTIFY_GENERIC, 5)
            if IsValid(dialogue) then
                Q:Request("dialogue", {placement = view.placement}, function(ok, data)
                    if ok then Q:ShowDialogue(data) else dialogue:Status(data) end
                end, dialogue)
            end
        end)
    end)
    frame.accept = accept

    function frame:Status(value)
        self.noticeText = isstring(value) and value or ""
        local wrapped = Q:WrapDialogueText(self.noticeText, D.fonts.small, math.max(1, self:GetWide() - 40))
        self.notice:SetText(wrapped) self.notice:SetTooltip(self.noticeText)
    end

    function frame:Refit()
        self.screenWidth, self.screenHeight = ScrW(), ScrH()
        local owner = Q:GroupDialogue(self)
        local dialogue = not self.qdManualPosition and owner
        local width = owner and owner.qdRightWidth or math.min(680, ScrW() - 32)
        local maxHeight = math.floor(math.min(520, ScrH() * 0.65))
        local x, y = math.floor((ScrW() - width) * 0.5), 24
        local above = false
        if IsValid(dialogue) then
            local dx, dy = dialogue:GetPos()
            x, y = dx + dialogue.qdRightOffset, dy
            above = dy - 26 >= 220
            if above then maxHeight = math.min(maxHeight, dy - 26) end
        end
        local heading, titleHeight = Q:WrapDialogueText(view.quest.name, D.fonts.title, width - 60)
        local headerHeight = math.max(40, titleHeight + 16)
        local actionHeight = self.view and self.view.active and 0 or accept:qdMeasure(width - 16)
        local contentHeight = D.LayoutRows(body, width - 24)
        local footerHeight = 48 + actionHeight + 16
        local height = math.min(maxHeight, headerHeight + contentHeight + footerHeight + 16)
        self:SetSize(width, height)
        -- At the top edge use an overlay in the same text column. Do not push
        -- the dialogue away from the position chosen by the player.
        if above then y = y - height - 10 end
        Q:PositionPlayerWindow(self, x, y)
        header:SetPos(0, 0) header:SetSize(width, headerHeight)
        title:SetPos(12, 0) title:SetSize(width - 60, headerHeight) title:SetText(heading)
        close:SetPos(width - 34, 0) close:SetSize(32, headerHeight)
        body:SetPos(8, headerHeight + 8) body:SetSize(width - 16, math.max(1, height - headerHeight - footerHeight - 16))
        self.notice:SetPos(12, height - footerHeight) self.notice:SetSize(width - 24, 44)
        actions:SetPos(8, height - actionHeight - 8) actions:SetSize(width - 16, actionHeight)
        actions:SetVisible(actionHeight > 0)
        self:Status(self.noticeText)
        body:InvalidateLayout(true)
        self:InvalidateLayout(true)
    end

    function frame:Action(action, data, callback)
        if self.busy then return end
        data.group = self.groupID
        self.actionGeneration = self.actionGeneration + 1
        UI.Run(self, action, data, callback)
    end

    function frame:Render(raw)
        local data = Q:GroupDisplayView(raw)
        if equal(self.view, data) then return false end
        local scroll = body:GetVBar():GetScroll()
        self.view, view, self.groupID = data, data, data.group
        body:Clear() body.qdRows = {}
        D.Text(body, data.quest.description)
        local timing = {data.quest.duration > 0 and "На выполнение: " .. duration(data.quest.duration) or "Без ограничения времени"}
        if data.quest.successCooldown > 0 then timing[#timing + 1] = "После успеха: " .. duration(data.quest.successCooldown) end
        if data.quest.failureCooldown > 0 then timing[#timing + 1] = "После отказа: " .. duration(data.quest.failureCooldown) end
        D.Text(body, table.concat(timing, " · "), false, true)
        local reward = data.quest.reward
        if reward then
            D.Text(body, "Награда" .. (data.quest.maxMembers > 1 and (reward.mode == "each" and " · каждому" or " · лидеру") or ""), true)
            local rewards = {}
            if reward.money > 0 then rewards[#rewards + 1] = "Деньги: " .. reward.money end
            if reward.xp > 0 then rewards[#rewards + 1] = "Опыт: " .. reward.xp end
            for _, item in ipairs(reward.items) do
                local definition = ix.Item:Get(item.item)
                rewards[#rewards + 1] = (definition and L(definition.name) or item.item) .. " × " .. item.count
                    .. ((item.chance or 100) < 100 and " · шанс " .. item.chance .. "%" or "")
            end
            for _, skill in ipairs(reward.skills) do
                local definition = ix.skills and ix.skills.list[skill.skill]
                rewards[#rewards + 1] = (definition and L(definition.name) or skill.skill) .. ": +" .. skill.xp .. " опыта"
            end
            D.Text(body, #rewards > 0 and table.concat(rewards, "\n") or "Без денег, предметов и опыта", false, #rewards == 0)
        end
        local rep = data.quest.reputation
        if rep then
            if rep.required then D.Text(body, "Нужно доверие к NPC: " .. rep.minimum) end
            if rep.success ~= 0 or rep.failure ~= 0 then D.Text(body, "Репутация: успех " .. string.format("%+d", rep.success)
                .. "; провал " .. string.format("%+d", rep.failure) .. (rep.mode == "leader" and " · лидеру" or " · каждому")) end
        end
        if data.quest.maxMembers <= 1 then
            D.Text(body, "Одиночное задание", false, true)
        else
            D.Text(body, "Группа: " .. #data.members .. " / " .. data.quest.maxMembers .. " · минимум " .. data.quest.minMembers, true)
            for _, member in ipairs(data.members) do
                local label = member.displayName .. (member.leader and " · лидер" or "") .. (member.online and "" or " · не в сети")
                if member.leader then D.Text(body, label)
                else D.Answer(body, label .. " — исключить", "close", function()
                    UI.Confirm("Исключить участника? При успехе задания его участие останется в истории кулдауна.", function()
                        frame:Action("remove_member", {placement = frame.placement, character = member.character}, function() frame:Refresh(false) end)
                    end)
                end) end
            end
            if data.quest.requireTogether then D.Text(body, "Участники должны быть рядом при выполнении целей и сдаче.", false, true) end
            if #data.members < data.quest.maxMembers then
                D.Text(body, "Пригласить игрока рядом", true)
                D.Text(body, "Имена из F3. Вступление — с согласия игрока.", false, true)
                for _, candidate in ipairs(data.candidates) do
                    D.Answer(body, candidate.displayName, "quest", function()
                        frame:Action("invite", {placement = frame.placement, entity = candidate.entity, character = candidate.character})
                    end)
                end
                if #data.candidates == 0 then D.Text(body, "Других игроков рядом нет.", false, true) end
            end
            D.Answer(body, "Обновить состав", "quest", function() frame:Refresh(false) end)
        end
        accept.qdText = data.quest.maxMembers <= 1 and "Принять задание" or "Принять задание этим составом"
        self:Refit()
        body:GetCanvas():InvalidateLayout(true) body:GetVBar():SetScroll(scroll)
        return true
    end

    function frame:Refresh(silent)
        if self.busy or self.refreshBusy then return end
        self.refreshBusy = true
        local generation = self.actionGeneration
        Q:Request("group_view", {placement = self.placement, group = self.groupID}, function(ok, data)
            self.refreshBusy = false
            if generation ~= self.actionGeneration then return end
            if ok then
                self:Render(data)
                if self.refreshError or not silent then self:Status("") end
                self.refreshError = nil
            else self.refreshError = true self:Status(data) end
        end, self)
    end
    function frame:OnDragged() self:Refit() end
    function frame:OnDragStart()
        local dialogue = Q:GroupDialogue(self)
        if IsValid(dialogue) then dialogue:Refit() end
    end
    frame.Think = function(s)
        local current = LocalPlayer():GetCharacter()
        if not current or current:GetID() ~= s.character then s:Remove() return end
        Q:ThinkPlayerWindow(s)
        if s.screenWidth ~= ScrW() or s.screenHeight ~= ScrH() then s:Refit() end
        if s.nextRefresh <= RealTime() then s.nextRefresh = RealTime() + 4 s:Refresh(true) end
        accept:SetEnabled(not s.busy)
    end
    frame.OnRemove = function(s)
        if IsValid(s.qdDragHandle) then s.qdDragHandle:MouseCapture(false) end
        if Q.groupPanel == s then Q.groupPanel = nil end
        local dialogue = Q:GroupDialogue(s)
        if IsValid(dialogue) then dialogue:Refit() end
    end
    frame.nextRefresh = RealTime() + 4
    local dialogue = Q:GroupDialogue(frame)
    if IsValid(dialogue) then dialogue:Refit() end
    frame:Render(view)
end
