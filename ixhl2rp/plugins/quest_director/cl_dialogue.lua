local Q, UI = ix.questDirector, ix.questDirector.ui
-- The same palette, type roles and corner treatment as the economy screens
-- and the existing NPC dialogue. Quest Director also works without that plugin.
local theme = ix.EconomyUI
local colors = theme and theme.colors or {
    window = Color(15, 21, 28, 235), row = Color(16, 22, 29, 190),
    rowActive = Color(150, 158, 166, 46), text = Color(214, 224, 232),
    label = Color(110, 128, 140), micro = Color(70, 84, 94)
}
local style = theme and theme:GetStyle(1) or {
    outline = Color(150, 158, 166, 48), outline2 = Color(150, 158, 166, 16),
    corners = Color(214, 224, 232), hover = Color(110, 128, 140)
}
local fonts = {title = theme and "economy.title" or "ixQDTitle",
    body = theme and "economy.section" or "ixQDBody", small = theme and "economy.value" or "ixQDBody"}

local function border(panel, w, h)
    if ix.util and ix.util.DrawBlur then ix.util.DrawBlur(panel, 2) end
    surface.SetDrawColor(colors.window) surface.DrawRect(0, 0, w, h)
    if theme then theme:DrawCorners(0, 0, w, h, 8, style)
    else
        surface.SetDrawColor(style.outline) surface.DrawOutlinedRect(0, 0, w, h)
        surface.SetDrawColor(style.outline2) surface.DrawOutlinedRect(2, 2, w - 4, h - 4)
        surface.SetDrawColor(style.corners)
        for _, corner in ipairs({{0, 0, 1, 1}, {w - 1, 0, -1, 1}, {0, h - 1, 1, -1}, {w - 1, h - 1, -1, -1}}) do
            surface.DrawLine(corner[1], corner[2], corner[1] + corner[3] * 8, corner[2])
            surface.DrawLine(corner[1], corner[2], corner[1], corner[2] + corner[4] * 8)
        end
    end
end

-- Measure and render the SAME line breaks. Reserving scrollbar space avoids
-- a width/height feedback loop when the window reaches its maximum height.
-- Split oversized words by UTF-8 character, not by byte; preserve blank lines.
function Q:WrapDialogueText(value, font, width)
    surface.SetFont(font)
    local _, lineHeight = surface.GetTextSize("Ag")
    local lines = {}
    width = math.max(1, width)
    value = tostring(value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for paragraph in (value .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in paragraph:gmatch("%S+") do
            local candidate = line == "" and word or line .. " " .. word
            if surface.GetTextSize(candidate) <= width then line = candidate
            else
                if line ~= "" then lines[#lines + 1] = line line = "" end
                if surface.GetTextSize(word) <= width then line = word
                else
                    for character in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                        if line ~= "" and surface.GetTextSize(line .. character) > width then lines[#lines + 1] = line line = "" end
                        line = line .. character
                    end
                end
            end
        end
        lines[#lines + 1] = line
    end
    return table.concat(lines, "\n"), #lines * math.max(1, lineHeight)
end

local function rememberRow(parent, row, value, font)
    parent.qdRows = parent.qdRows or {}
    parent.qdRows[#parent.qdRows + 1] = row
    row.qdText, row.qdFont = value or "", font
    row:Dock(TOP)
    return row
end

local function text(parent, value, title, small)
    local font = title and fonts.title or small and fonts.small or fonts.body
    local label = rememberRow(parent, parent:Add("DLabel"), value, font)
    label:SetFont(font) label:SetTextColor(small and colors.label or colors.text)
    label:SetWrap(false) label:SetContentAlignment(7) label:SetTextInset(12, 7)
    label.qdMeasure = function(s, width)
        local wrapped, height = Q:WrapDialogueText(s.qdText, font, width - 24)
        s:SetText(wrapped) s:SetSize(width, height + 14)
        return s:GetTall()
    end
    return label
end

local function icon(action, x, y, color)
    surface.SetDrawColor(color)
    if action == "close" then
        surface.DrawOutlinedRect(x, y, 7, 13)
        surface.DrawLine(x + 5, y + 6, x + 14, y + 6)
        surface.DrawLine(x + 10, y + 2, x + 14, y + 6) surface.DrawLine(x + 10, y + 10, x + 14, y + 6)
    elseif action == "finish" or action == "event" then
        surface.DrawLine(x, y + 7, x + 5, y + 12) surface.DrawLine(x + 5, y + 12, x + 14, y + 2)
    else
        surface.DrawOutlinedRect(x, y, 14, 11)
        surface.DrawLine(x + 3, y + 4, x + 11, y + 4) surface.DrawLine(x + 3, y + 7, x + 9, y + 7)
        if action ~= "quest" then surface.DrawLine(x + 3, y + 10, x + 3, y + 14) surface.DrawLine(x + 3, y + 14, x + 7, y + 10) end
    end
end

local function answer(parent, value, action, clicked, reason)
    local button = rememberRow(parent, parent:Add("DButton"), value, fonts.body)
    button:SetText("")
    local label = button:Add("DLabel") label:SetPos(36, 7) label:SetFont(fonts.body)
    label:SetWrap(false) label:SetContentAlignment(7) label:SetMouseInputEnabled(false)
    button.qdMeasure = function(s, width)
        local wrapped, height = Q:WrapDialogueText(s.qdText, fonts.body, width - 48)
        label:SetText(wrapped) label:SetSize(width - 48, height)
        s:SetSize(width, math.max(32, height + 14))
        return s:GetTall()
    end
    button.Paint = function(s, w, h)
        local selected = s:IsHovered() and not reason
        if theme then s.qdHover = theme:DrawHover(w, h, selected, s.qdHover, style.hover, 40)
        elseif selected then surface.SetDrawColor(colors.rowActive) surface.DrawRect(0, 0, w, h) end
        local color = reason and colors.label or selected and color_white or colors.text
        label:SetTextColor(color) icon(action, 12, 10, color)
    end
    button.DoClick = clicked
    if reason then button:SetTooltip(reason) end
    return button
end

local function layoutRows(parent, width)
    local height = 0
    for _, row in ipairs(parent.qdRows or {}) do height = height + row:qdMeasure(width) end
    return height
end

local function scrollStyle(panel)
    local bar = panel:GetVBar()
    bar:SetWide(6)
    bar.Paint = function(_, w, h) surface.SetDrawColor(colors.row) surface.DrawRect(0, 0, w, h) end
    bar.btnUp.Paint = function() end bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(colors.micro) surface.DrawRect(0, 0, w, h) end
end

Q.dialogueUI = {Border = border, Text = text, Answer = answer, LayoutRows = layoutRows,
    ScrollStyle = scrollStyle, fonts = fonts, colors = colors, style = style}

function Q:AddDialogueHistory(history, speaker, value)
    history.entries[#history.entries + 1] = {speaker = speaker, text = value}
    while #history.entries > 60 do table.remove(history.entries, 1) end
end

function Q:ShowDialogue(view)
    local history, bodyScroll, cardsScroll, position
    if IsValid(self.dialoguePanel) then
        local old = self.dialoguePanel
        if old.session == view.session and old.character == view.character then history = old.history end
        old.qdRebuilding = old.placement == view.placement and old.character == view.character
        if old.qdRebuilding then
            bodyScroll = IsValid(old.body) and old.body:GetVBar():GetScroll() or 0
            cardsScroll = IsValid(old.sidebar) and old.sidebar:GetVBar():GetScroll() or 0
            local x, y = old:GetPos()
            position = {x = x, y = y, manual = old.qdManualPosition}
        end
        old:Remove()
    end
    history = history or {entries = {}, expanded = false}
    if history.lastNode ~= view.node or history.lastText ~= view.text then
        self:AddDialogueHistory(history, view.name, view.text)
        history.lastNode, history.lastText = view.node, view.text
    end
    local frame = vgui.Create("DFrame")
    frame:SetSize(720, 180)
    frame:SetTitle("") frame:ShowCloseButton(false) frame:DockPadding(0, 0, 0, 0)
    Q:SetupPlayerWindow(frame, "dialogue")
    if position then
        frame:SetPos(position.x, position.y)
        frame.qdManualPosition, frame.qdPositioned = position.manual, true
    end
    frame.Paint = function() end
    frame.history, frame.session, frame.character, frame.placement = history, view.session, view.character, view.placement
    self.dialoguePanel = frame
    frame.OnKeyCodePressed = function(s, key) if key == KEY_ESCAPE then s:Remove() end end
    frame.Think = function(s)
        local character = LocalPlayer():GetCharacter()
        if not character or character:GetID() ~= s.character then s:Remove() return end
        Q:ThinkPlayerWindow(s)
        if s.screenWidth ~= ScrW() or s.screenHeight ~= ScrH() then s:Refit() end
    end
    frame.OnRemove = function(s)
        if IsValid(s.qdDragHandle) then s.qdDragHandle:MouseCapture(false) end
        if not s.qdRebuilding then
            if Q.dialoguePanel == s then Q.dialoguePanel = nil end
            local group = Q.groupPanel
            if IsValid(group) and group.placement == s.placement then group:Remove() end
        end
    end
    frame.OnDragged = function(s)
        local group = Q.groupPanel
        if IsValid(group) and group.placement == s.placement and not group.qdManualPosition then group:Refit() end
    end

    local portraitColumn = frame:Add("DPanel") portraitColumn.Paint = border
    local portrait = portraitColumn:Add("DModelPanel")
    self:SetupPortrait(portrait, function() return view end)
    local bio = portraitColumn:Add("DScrollPanel") scrollStyle(bio)
    if view.reputation then
        local rep = view.reputation
        text(bio, rep.tier)
        text(bio, "Доверие: " .. rep.value .. " / " .. rep.maximum, false, true)
        local bar = rememberRow(bio, bio:Add("DPanel"), "", fonts.small)
        bar.qdMeasure = function(s, w) s:SetSize(w, 5) return 5 end
        bar.Paint = function(_, w, h)
            surface.SetDrawColor(colors.micro) surface.DrawRect(12, 0, w - 24, h)
            surface.SetDrawColor(style.corners) surface.DrawRect(12, 0, (w - 24) * math.Clamp((rep.value - rep.minimum) / math.max(1, rep.maximum - rep.minimum), 0, 1), h)
        end
        if rep.nextValue then text(bio, "До «" .. rep.nextTier .. "»: " .. (rep.nextValue - rep.value), false, true) end
    end

    local right = frame:Add("DPanel") right.Paint = border
    local header = right:Add("DPanel")
    Q:DragPlayerWindow(frame, header)
    header.Paint = function(_, w, h) surface.SetDrawColor(style.outline) surface.DrawRect(10, h - 1, w - 20, 1) end
    local close = header:Add("DButton") close:SetText("×") close:SetFont(fonts.title) close:SetTextColor(colors.text)
    close.Paint = function() end close.DoClick = function() frame:Remove() end
    local toggle = header:Add("DButton") toggle:SetFont(fonts.small) toggle:SetTextColor(colors.label) toggle.Paint = function() end
    local name = header:Add("DLabel") name:SetFont(fonts.title) name:SetTextColor(colors.text) name:SetWrap(false) name:SetContentAlignment(4) name:SetMouseInputEnabled(false)
    frame.notice = right:Add("DLabel") frame.notice:SetFont(fonts.small) frame.notice:SetWrap(false) frame.notice:SetContentAlignment(7)
    frame.notice:SetTextColor(colors.text) frame.notice:SetText("") frame.noticeText = ""
    function frame:Status(value)
        self.noticeText = isstring(value) and value or ""
        local wrapped = Q:WrapDialogueText(self.noticeText, fonts.small, math.max(1, (self.qdRightWidth or 400) - 40))
        self.notice:SetText(wrapped) self.notice:SetTooltip(self.noticeText)
    end
    local log = right:Add("DScrollPanel") scrollStyle(log)
    log.Paint = function(_, w, h) surface.SetDrawColor(colors.row) surface.DrawRect(0, 0, w, h) end
    local body = right:Add("DScrollPanel") scrollStyle(body) frame.body = body

    function frame:Refit()
        self.screenWidth, self.screenHeight = ScrW(), ScrH()
        -- Reserve the same grid before accepting the first quest. Adding cards
        -- must not recenter the window or change the dialogue column's offset.
        local gap, pad = 10, 8
        local width = math.min(1760, ScrW() - 32)
        local column = math.Clamp(math.floor(width * 0.18), 120, 300)
        local cardsWidth = math.floor((width - column - gap * 2) * 0.47)
        local portraitImageHeight = math.floor(column * 1.15)
        local rightWidth = width - column - gap - (cardsWidth > 0 and cardsWidth + gap or 0)
        local textWidth = rightWidth - pad * 2 - 8
        local bodyHeight = layoutRows(body, textWidth)
        local logHeight = history.expanded and math.min(layoutRows(log, textWidth), math.min(160, ScrH() * 0.22)) or 0
        local bioHeight = layoutRows(bio, column - 8)
        -- Leave room for the acceptance panel from the outset, not only while
        -- it is open. Hidden columns stay transparent; short dialogue stays compact.
        local maxHeight = math.floor(math.min(640, ScrH() * 0.72, ScrH() - 58 - math.min(280, ScrH() * 0.42)))
        local group = Q.groupPanel
        local attached = IsValid(group) and group.placement == self.placement and group.character == self.character and not group.qdManualPosition
        local portraitHeight = math.min(maxHeight, portraitImageHeight + 4 + bioHeight)
        local toggleWidth = rightWidth < 460 and 32 or 154
        local titleWidth = rightWidth - toggleWidth - 56
        local heading, headingHeight = Q:WrapDialogueText(view.name, fonts.title, titleWidth)
        local headerHeight = math.max(40, headingHeight + 16)
        local noticeText = Q:WrapDialogueText(self.noticeText, fonts.small, textWidth - 8)
        -- A fixed notice slot prevents network status messages from moving the window.
        local noticeHeight = 44
        local rightHeight = math.min(maxHeight, headerHeight + logHeight + bodyHeight + noticeHeight + pad * 2)
        if #(self.questCards or {}) > 0 then rightHeight = maxHeight end
        local height = maxHeight
        self:SetSize(width, height)
        self.qdMinimumY = 16
        Q:PositionPlayerWindow(self, math.floor((ScrW() - width) * 0.5), math.max(16, ScrH() - height - 32), self.qdMinimumY)
        self.qdPositioned = true
        portraitColumn:SetPos(0, 0) portraitColumn:SetSize(column, portraitHeight)
        portrait:SetPos(2, 2) portrait:SetSize(column - 4, portraitImageHeight)
        bio:SetPos(4, portraitImageHeight + 2) bio:SetSize(column - 8, math.max(0, portraitHeight - portraitImageHeight - 4)) bio:SetVisible(bioHeight > 0)
        right:SetPos(column + gap, 0) right:SetSize(rightWidth, rightHeight)
        header:SetPos(0, 0) header:SetSize(rightWidth, headerHeight)
        name:SetPos(12, 0) name:SetSize(titleWidth, headerHeight) name:SetText(heading)
        close:SetPos(rightWidth - 34, 0) close:SetSize(32, headerHeight)
        toggle:SetPos(rightWidth - toggleWidth - 36, 0) toggle:SetSize(toggleWidth, headerHeight)
        toggle:SetText(toggleWidth == 32 and "≡" or (history.expanded and "Скрыть историю" or "Посмотреть историю"))
        toggle:SetTooltip(history.expanded and "Скрыть историю" or "Посмотреть историю")
        log:SetPos(pad, headerHeight + pad) log:SetSize(rightWidth - pad * 2, logHeight) log:SetVisible(history.expanded)
        body:SetPos(pad, headerHeight + pad + logHeight)
        body:SetSize(rightWidth - pad * 2, math.max(1, rightHeight - headerHeight - logHeight - noticeHeight - pad * 2))
        self.notice:SetPos(pad + 4, rightHeight - noticeHeight - pad)
        self.notice:SetSize(textWidth, noticeHeight) self.notice:SetText(noticeText) self.notice:SetVisible(noticeHeight > 0)
        self.notice:SetTooltip(self.noticeText)
        if IsValid(self.sidebar) then
            self.qdCardsOffset, self.qdCardsWidth = column + rightWidth + gap * 2, cardsWidth
            self.sidebar:SetPos(self.qdCardsOffset, 0) self.sidebar:SetSize(cardsWidth, height)
            if cardsWidth > 0 then Q:LayoutQuestCards(self, cardsWidth) end
        end
        self.qdBodyHeight, self.qdBodyViewport = bodyHeight, body:GetTall()
        self.qdRightHeight, self.qdPortraitHeight = rightHeight, portraitHeight
        self.qdRightWidth, self.qdRightOffset = rightWidth, column + gap
        self:InvalidateLayout(true)
        if attached and group.Refit then
            group:Refit()
        end
    end
    local function showHistory()
        toggle:SetText(history.expanded and "Скрыть историю" or "Посмотреть историю")
        log:Clear() log.qdRows = {}
        if history.expanded then
            for _, entry in ipairs(history.entries) do text(log, entry.speaker .. ": " .. entry.text) end
        end
        frame:Refit()
        if history.expanded then
            timer.Simple(0, function() if IsValid(log) then log:InvalidateLayout(true) log:GetVBar():SetScroll(log:GetCanvas():GetTall()) end end)
        end
    end
    toggle.DoClick = function() history.expanded = not history.expanded showHistory() end
    text(body, view.text)
    local separator = rememberRow(body, body:Add("DPanel"), "", fonts.body)
    separator.qdMeasure = function(s, w) s:SetSize(w, 1) return 1 end
    separator.Paint = function(_, w, h) surface.SetDrawColor(style.outline) surface.DrawRect(12, 0, w - 24, h) end

    local function refresh()
        UI.Run(frame, "dialogue", {placement = view.placement}, function(data) Q:ShowDialogue(data) end)
    end
    local function choose(option, runID)
        if option.allowed == false then frame:Status(option.reason) return end
        UI.Run(frame, "choose", {placement = view.placement, option = option.index, run = runID}, function(result)
            Q:AddDialogueHistory(history, "Вы", option.text)
            history.lastNode = nil
            if result.group then Q:ShowGroup(result.group) showHistory()
            elseif result.close then frame:Remove()
            elseif result.dialogue then
                Q:ShowDialogue(result.dialogue)
                if result.message then Q.dialoguePanel:Status(result.message) end
            end
        end)
    end
    local hasExit = false
    for _, option in ipairs(view.options) do
        if option.action == "close" and option.allowed ~= false then hasExit = true end
        if option.action ~= "finish" then
            answer(body, option.text, option.action, function() choose(option) end, option.allowed == false and option.reason or nil)
        end
    end
    if #view.quests > 0 then text(body, "Доступные задания", true) end
    for _, quest in ipairs(view.quests) do
        answer(body, quest.name .. (quest.allowed and "" or " · недоступно"), "quest", function()
            if not quest.allowed then frame:Status(quest.reason) return end
            UI.Run(frame, "group_open", {placement = view.placement, quest = quest.id}, function(data) Q:ShowGroup(data) end)
        end, not quest.allowed and quest.reason or nil)
    end
    if (view.pages or 1) > 1 then
        text(body, "Задания: " .. view.page .. " / " .. view.pages)
        for _, direction in ipairs({-1, 1}) do
            local page = view.page + direction
            if page >= 1 and page <= view.pages then
                answer(body, direction == 1 and "Следующие задания →" or "← Предыдущие задания", "quest", function()
                    UI.Run(frame, "dialogue", {placement = view.placement, page = page}, function(data) Q:ShowDialogue(data) end)
                end)
            end
        end
    end
    Q:BuildQuestCards(frame, view, refresh, choose)
    if #(view.runs or {}) > 0 then text(body, "Активные задания: " .. #view.runs .. " / " .. (view.maxActive or 2), false, true) end
    answer(body, "Обновить задания", "quest", refresh)
    if not hasExit then answer(body, "Мне пора идти.", "close", function() frame:Remove() end) end
    showHistory()
    body:GetCanvas():InvalidateLayout(true) frame.sidebar:GetCanvas():InvalidateLayout(true)
    body:GetVBar():SetScroll(bodyScroll or 0) frame.sidebar:GetVBar():SetScroll(cardsScroll or 0)
end
