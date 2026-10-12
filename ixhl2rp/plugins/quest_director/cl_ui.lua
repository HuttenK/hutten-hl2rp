local Q = ix.questDirector
Q.ui = Q.ui or {}
local UI = Q.ui
Q.pending, Q.queue, Q.requestID = {}, {}, 0
local dark, card, accent = Color(22, 26, 31), Color(36, 42, 49), Color(120, 195, 190)
surface.CreateFont("ixQDTitle", {font = "Roboto", size = 24, weight = 600, extended = true})
surface.CreateFont("ixQDBody", {font = "Roboto", size = 18, weight = 400, extended = true})

function Q:Request(action, data, callback, owner)
    if #self.queue >= 20 then if callback then callback(false, "Очередь занята. Подождите.") end return end
    self.queue[#self.queue + 1] = {action = action, data = data or {}, callback = callback, owner = owner}
end

hook.Add("Think", "ixQDRequestQueue", function()
    local now = RealTime()
    for id, request in pairs(Q.pending) do
        if request.timeout < now then
            Q.pending[id] = nil
            if request.callback and (not request.owner or IsValid(request.owner)) then request.callback(false, "Сервер не ответил. Обновите окно.") end
        end
    end
    if (Q.nextRequest or 0) > now or #Q.queue == 0 then return end
    Q.nextRequest = now + 0.22
    local request = table.remove(Q.queue, 1)
    if request.owner and not IsValid(request.owner) then return end
    local payload = util.TableToJSON({action = request.action, data = request.data})
    if not payload or #payload > Q.MAX_PACKET then
        if request.callback then request.callback(false, "Запись слишком велика. Сократите текст.") end
        return
    end
    Q.requestID = (Q.requestID % 65535) + 1
    request.timeout = now + 15
    Q.pending[Q.requestID] = request
    net.Start("ixQDRequest")
    net.WriteUInt(Q.requestID, 16)
    net.WriteUInt(#payload, 16)
    net.WriteData(payload, #payload)
    net.SendToServer()
end)

net.Receive("ixQDReply", function()
    local id, size = net.ReadUInt(16), net.ReadUInt(16)
    if size > Q.MAX_PACKET then return end
    local response = util.JSONToTable(net.ReadData(size))
    local pending = Q.pending[id]
    Q.pending[id] = nil
    if response and pending and pending.callback and (not pending.owner or IsValid(pending.owner)) then pending.callback(response.ok, response.data) end
end)

function UI.Frame(title, width, height)
    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(width or 850, ScrW() - 40), math.min(height or 720, ScrH() - 40))
    frame:Center() frame:SetTitle(title) frame:MakePopup()
    frame:DockPadding(16, 36, 16, 14)
    frame.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, dark) end
    frame.notice = frame:Add("DLabel")
    frame.notice:Dock(BOTTOM) frame.notice:SetTall(46) frame.notice:SetWrap(true)
    frame.notice:SetTextColor(accent) frame.notice:SetText("")
    frame.body = frame:Add("DScrollPanel") frame.body:Dock(FILL)
    function frame:Status(text) self.notice:SetText(isstring(text) and text or "Готово.") end
    return frame, frame.body
end

function UI.Label(parent, text, title)
    local label = parent:Add("DLabel") label:Dock(TOP) label:DockMargin(0, 4, 0, 8)
    label:SetFont(title and "ixQDTitle" or "ixQDBody")
    label:SetTextColor(title and accent or color_white)
    label:SetText(text or "") label:SetWrap(true) label:SetAutoStretchVertical(true)
    label:SetTall(title and 30 or 26)
    return label
end

function UI.Button(parent, text, callback)
    local button = parent:Add("DButton") button:Dock(TOP) button:DockMargin(0, 0, 0, 6)
    button:SetTall(38) button:SetText(text) button:SetFont("ixQDBody") button:SetTextColor(color_white)
    button.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(52, 70, 76) or card) end
    button.DoClick = callback
    return button
end

function UI.Confirm(text, callback)
    Derma_Query(text, "Подтверждение", "Подтвердить", callback, "Отмена")
end

function UI.Run(frame, action, data, callback)
    if frame.busy then return end
    frame.busy = true frame:Status("Обработка…")
    Q:Request(action, data, function(ok, result)
        frame.busy = false
        frame:Status(ok and (istable(result) and result.message or result) or result)
        if ok and callback then callback(result) end
    end, frame)
end

function Q:RememberedName(characterID)
    local owner = LocalPlayer()
    local ours = owner:GetCharacter()
    if ours and ours:GetID() == characterID then return "Вы" end
    -- Do not use Name/GetCharacterName: globally recognized factions can reveal legal names.
    local remembered = owner.recognize and (owner.recognize[characterID] or owner.recognize[tostring(characterID)])
    for _, target in ipairs(player.GetAll()) do
        local character = target:GetCharacter()
        if character and character:GetID() == characterID and target:GetNetVar("hide", 0) == characterID then return "Незнакомец" end
    end
    return isstring(remembered) and remembered ~= "" and remembered or "Незнакомец (запомните через F3)"
end

function Q:ShowJournal(view)
    if IsValid(self.journalPanel) then self.journalPanel:Remove() end
    local frame, body = UI.Frame("Журнал заданий", 670, 680)
    self.journalPanel = frame
    local runs = view.runs or (view.run and {view.run} or {})
    UI.Label(body, "Активные задания: " .. #runs .. " / " .. (view.maxActive or 2), true)
    for _, run in ipairs(runs) do
        UI.Label(body, run.name, true) UI.Label(body, run.description)
        UI.Label(body, "Участников: " .. run.members .. "; минимум: " .. run.minimum)
        if run.deadline > 0 then
            local label = UI.Label(body, "")
            local remaining = run.deadline - view.serverTime
            local opened = RealTime()
            label.Think = function(s) s:SetText("Осталось: " .. string.NiceTime(math.max(0, remaining - (RealTime() - opened)))) end
        end
        for _, goal in ipairs(run.objectives) do UI.Label(body, (goal.open and "→ " or "") .. goal.name .. " — " .. math.Round(goal.progress, 1) .. " / " .. goal.count) end
        if run.complete then UI.Label(body, "Все цели выполнены. Лидер может сдать задание у NPC.") end
        UI.Button(body, run.leader and "Отказаться от задания всей группой" or "Покинуть группу", function()
            UI.Confirm("Подтвердить выход? Для лидера это провал задания всей группы; применяется кулдаун неудачи.", function()
                UI.Run(frame, "abandon", {run = run.id}, function() Q:Request("journal", {}, function(ok, data) if ok then Q:ShowJournal(data) end end) end)
            end)
        end)
    end
    if #runs == 0 then UI.Label(body, "Активных заданий нет.") end
    if #view.receipts > 0 then UI.Label(body, "Награды ждут у квестодателей", true) end
    for _, receipt in ipairs(view.receipts) do UI.Label(body, receipt.name .. (receipt.status == "applying" and " · нужна проверка администрацией" or "")) end
    if #(view.reputation or {}) > 0 then UI.Label(body, "Доверие квестодателей", true) end
    for _, rep in ipairs(view.reputation or {}) do UI.Label(body, rep.name .. ": " .. rep.value .. " · " .. rep.tier) end
    if (view.reputationPages or 1) > 1 then
        UI.Label(body, "Репутация: страница " .. view.reputationPage .. " / " .. view.reputationPages)
        for _, direction in ipairs({-1, 1}) do
            local page = view.reputationPage + direction
            if page >= 1 and page <= view.reputationPages then
                UI.Button(body, direction == 1 and "Следующие квестодатели →" or "← Предыдущие квестодатели", function()
                    UI.Run(frame, "journal", {page = page}, function(data) Q:ShowJournal(data) end)
                end)
            end
        end
    end
    UI.Button(body, "Обновить журнал", function()
        UI.Run(frame, "journal", {page = view.reputationPage}, function(data) Q:ShowJournal(data) end)
    end)
end

function Q:ShowObject(view)
    if IsValid(self.objectPanel) then self.objectPanel:Remove() end
    local frame, body = UI.Frame(view.name, 560, 500)
    self.objectPanel = frame
    UI.Label(body, view.name, true)
    if #view.actions == 0 then UI.Label(body, view.hint or "Для этого объекта нет доступных действий в текущем задании.") end
    for _, action in ipairs(view.actions) do
        UI.Label(body, action.questName and action.questName .. " · " .. action.name or action.name)
        local amount
        if action.type == "deposit" then
            UI.Label(body, "Передача расходует предметы из основного инвентаря и рюкзака. Осталось: " .. action.remaining)
            amount = body:Add("DNumberWang") amount:Dock(TOP) amount:DockMargin(0, 0, 0, 8)
            amount:SetMinMax(1, action.remaining) amount:SetValue(action.remaining)
        end
        UI.Button(body, action.type == "deposit" and "Положить предметы" or "Взаимодействовать", function()
            UI.Run(frame, "interact", {placement = view.placement, run = action.run, objective = action.id, amount = amount and amount:GetValue() or 1}, function() frame:Remove() end)
        end)
    end
end

net.Receive("ixQDPush", function()
    local kind, size = net.ReadString(), net.ReadUInt(16)
    if size > Q.MAX_PACKET then return end
    local response = util.JSONToTable(net.ReadData(size))
    if not response or not response.ok then return end
    local data = response.data
    if kind == "admin" then Q:ShowAdmin()
    elseif kind == "dialogue" then Q:ShowDialogue(data)
    elseif kind == "journal" then Q:ShowJournal(data)
    elseif kind == "object" then Q:ShowObject(data)
    elseif kind == "placement" then Q:ShowPlacement(data)
    elseif kind == "invite" then
        Derma_Query(Q:RememberedName(data.leader) .. " приглашает вас на задание «" .. data.quest .. "». Принятие фиксирует участие и будущий кулдаун.", "Приглашение в группу",
            "Принять", function() Q:Request("accept", {token = data.token, accept = true}, function(_, message) notification.AddLegacy(message, NOTIFY_GENERIC, 7) end) end,
            "Отклонить", function() Q:Request("accept", {token = data.token, accept = false}) end)
    end
end)

concommand.Add("ix_quest_journal", function() Q:Request("journal", {}, function(ok, data) if ok then Q:ShowJournal(data) end end) end)
