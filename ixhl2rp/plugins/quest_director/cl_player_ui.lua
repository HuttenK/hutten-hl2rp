local Q = ix.questDirector
Q.playerWindowPositions = Q.playerWindowPositions or {}

function Q:ChatIsActive()
    return self.playerChatActive == true or (ix.gui and IsValid(ix.gui.chat) and ix.gui.chat:GetActive()) == true
end

function Q:SetupPlayerWindow(frame, key)
    frame.qdWindowKey = key
    frame:SetDraggable(false) -- Custom headers drive dragging, independent of DFrame:Think.
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false) -- Keep ordinary messagemode binds working.
    frame:SetMouseInputEnabled(not self:ChatIsActive())
    local saved = self.playerWindowPositions[key]
    if saved then frame.qdManualPosition = true frame:SetPos(saved.x, saved.y) end
    if self:ChatIsActive() and ix.gui and IsValid(ix.gui.chat) then
        ix.gui.chat:MoveToFront()
        if IsValid(ix.gui.chat.entry) then ix.gui.chat.entry:RequestFocus() end
    end
end

function Q:PositionPlayerWindow(frame, defaultX, defaultY, minimumY)
    local x, y = defaultX, defaultY
    if frame.qdManualPosition or frame.qdPositioned then x, y = frame:GetPos() end
    local maxX, maxY = math.max(16, ScrW() - frame:GetWide() - 16), math.max(16, ScrH() - frame:GetTall() - 16)
    x = math.Clamp(x, 16, maxX)
    y = math.Clamp(y, math.min(minimumY or 16, maxY), maxY)
    frame:SetPos(x, y)
end

function Q:DragPlayerWindow(frame, handle)
    handle:SetMouseInputEnabled(true) handle:SetCursor("sizeall")
    handle:SetTooltip("Перетащите заголовок мышью. Чат доступен обычной клавишей.")
    handle.OnMousePressed = function(s, button)
        if button ~= MOUSE_LEFT or Q:ChatIsActive() then return end
        local x, y = frame:GetPos()
        frame.qdDragOffset = {gui.MouseX() - x, gui.MouseY() - y}
        frame.qdManualPosition = true
        s:MouseCapture(true)
        if frame.OnDragStart then frame:OnDragStart() end
    end
    handle.OnMouseReleased = function(s, button)
        if button ~= MOUSE_LEFT then return end
        frame.qdDragOffset = nil s:MouseCapture(false)
    end
    frame.qdDragHandle = handle
end

function Q:ThinkPlayerWindow(frame)
    if not frame.qdDragOffset or self:ChatIsActive() then return end
    local x = gui.MouseX() - frame.qdDragOffset[1]
    local y = gui.MouseY() - frame.qdDragOffset[2]
    frame:SetPos(x, y)
    self:PositionPlayerWindow(frame, x, y, frame.qdMinimumY)
    x, y = frame:GetPos()
    self.playerWindowPositions[frame.qdWindowKey] = {x = x, y = y}
    if frame.OnDragged then frame:OnDragged() end
end

local function windows(callback)
    for _, key in ipairs({"dialoguePanel", "groupPanel"}) do
        local frame = Q[key]
        if IsValid(frame) then callback(frame) end
    end
end

hook.Add("StartChat", "ixQDPlayerChat", function()
    Q.playerChatActive = true
    windows(function(frame)
        frame.qdDragOffset = nil
        if IsValid(frame.qdDragHandle) then frame.qdDragHandle:MouseCapture(false) end
        frame:SetMouseInputEnabled(false) frame:SetKeyboardInputEnabled(false)
    end)
end)

hook.Add("FinishChat", "ixQDPlayerChat", function()
    Q.playerChatActive = false
    -- Helix clears screen-clicker state before FinishChat. Restore mouse access
    -- without MakePopup/RequestFocus, which would steal the next chat entry.
    timer.Simple(0, function()
        if Q:ChatIsActive() then return end
        windows(function(frame) frame:SetMouseInputEnabled(true) frame:SetKeyboardInputEnabled(false) end)
    end)
end)

hook.Add("OnPauseMenuShow", "ixQDPlayerWindows", function()
    if Q:ChatIsActive() then return end
    local frame = IsValid(Q.groupPanel) and Q.groupPanel or Q.dialoguePanel
    if IsValid(frame) then frame:Remove() return false end
end)
