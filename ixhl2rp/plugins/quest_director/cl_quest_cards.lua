local Q, UI = ix.questDirector, ix.questDirector.ui
local D = Q.dialogueUI

function Q:BuildQuestCards(frame, view, refresh, choose)
    local sidebar = frame:Add("DScrollPanel")
    D.ScrollStyle(sidebar)
    frame.sidebar, frame.questCards = sidebar, {}
    local function card(id)
        local panel = sidebar:Add("DPanel")
        panel:Dock(TOP) panel:DockMargin(0, 0, 8, 10) panel:DockPadding(8, 8, 8, 8)
        panel.Paint = D.Border panel.questID = id
        frame.questCards[#frame.questCards + 1] = panel
        return panel
    end
    local function action(panel, label, kind, callback, reason)
        return D.Answer(panel, label, kind, function()
            if frame.busy then return end
            if reason then frame:Status(reason) return end
            callback()
        end, reason)
    end
    for _, run in ipairs(view.runs or (view.run and {view.run} or {})) do
        local panel = card(run.id)
        D.Text(panel, run.name, true)
        D.Text(panel, run.complete and "Цели выполнены · можно сдать" or "В процессе", false, true)
        if run.atActor == false then D.Text(panel, "Квестодатель: " .. (run.npcName or "QActor"), false, true) end
        for _, goal in ipairs(run.objectives) do
            D.Text(panel, (goal.progress >= goal.count and "✓ " or goal.open and "→ " or "")
                .. goal.name .. " — " .. math.Round(goal.progress, 1) .. " / " .. goal.count)
        end
        if run.deadline and run.deadline > 0 then
            local remaining = math.max(0, run.deadline - (view.serverTime or os.time()))
            D.Text(panel, "Осталось на момент открытия: " .. math.ceil(remaining / 60) .. " мин.", false, true)
        end
        local away = run.atActor == false and "Для этого действия подойдите к «" .. (run.npcName or "QActor") .. "»." or nil
        if (run.maximum or 1) > 1 then
            D.Text(panel, "Группа: " .. run.members .. " / " .. run.maximum .. " · минимум " .. run.minimum, false, true)
            if run.leader then
                action(panel, "Изменить состав группы", "quest", function()
                    UI.Run(frame, "group_view", {placement = view.placement, group = run.id}, function(data) Q:ShowGroup(data) end)
                end, away)
            end
        end
        if run.leader then
            local finishReason = away or (not run.complete and "Сначала выполните все цели задания." or nil)
            local customFinish = false
            for _, option in ipairs(view.options or {}) do
                if option.action == "finish" and (not option.quest or option.quest == "" or option.quest == run.quest) then
                    customFinish = true
                    action(panel, option.text, "finish", function() choose(option, run.id) end,
                        finishReason or (option.allowed == false and option.reason or nil))
                end
            end
            if not customFinish then
                action(panel, "Сдать задание", "finish", function()
                    UI.Run(frame, "finish", {placement = view.placement, run = run.id}, refresh)
                end, finishReason)
            end
        else D.Text(panel, "Задание сдаёт лидер группы.", false, true) end
        local groupQuest = (run.maximum or 1) > 1
        local abandon
        abandon = action(panel, run.leader and "Отказаться от задания" or "Покинуть группу", "close", function()
            if not panel.confirmAbandon then
                panel.confirmAbandon = true
                abandon.qdText = run.leader and (groupQuest and "Подтвердить отказ всей группы" or "Подтвердить отказ") or "Подтвердить выход из группы"
                frame:Status(run.leader and (groupQuest and "Отказ завершит это задание для всей группы с кулдауном неудачи. Нажмите ещё раз для подтверждения."
                    or "Отказ завершит это задание с кулдауном неудачи. Нажмите ещё раз для подтверждения.")
                    or "Вы покинете только эту группу. Повторное нажатие подтвердит выход.")
                frame:Refit()
                return
            end
            UI.Run(frame, "abandon", {run = run.id}, refresh)
        end)
        -- Confirmation stays inside the quest card and never captures chat input.
        local cancel = action(panel, "Продолжить задание", "quest", function()
            panel.confirmAbandon = false
            abandon.qdText = run.leader and "Отказаться от задания" or "Покинуть группу"
            frame:Status("") frame:Refit()
        end)
        local measureCancel = cancel.qdMeasure
        cancel.qdMeasure = function(s, width)
            s:SetVisible(panel.confirmAbandon == true)
            if panel.confirmAbandon then return measureCancel(s, width) end
            s:SetTall(0) return 0
        end
    end
    for _, receipt in ipairs(view.receipts or {}) do
        local panel = card(receipt.id)
        D.Text(panel, receipt.name, true)
        if receipt.status == "applying" then
            D.Text(panel, "Выдача награды ожидает проверки администрацией.")
        else
            D.Text(panel, "Задание сдано · награда готова", false, true)
            action(panel, "Получить награду", "finish", function()
                local started = RealTime()
                local function claim(statusOnly)
                    UI.Run(frame, statusOnly and "claim_status" or "claim", {placement = view.placement, receipt = receipt.id}, function(result)
                        if istable(result) and result.waiting then
                            if RealTime() - started > 30 then frame:Status("Сохранение продолжается. Обновите разговор позднее.") return end
                            timer.Simple(0.5, function() if IsValid(frame) then claim(true) end end)
                        elseif istable(result) and result.more then claim(false) else refresh() end
                    end)
                end
                claim(false)
            end)
        end
    end
    sidebar:SetVisible(#frame.questCards > 0)
end

function Q:LayoutQuestCards(frame, width)
    local height = 0
    for _, card in ipairs(frame.questCards or {}) do
        local content = D.LayoutRows(card, math.max(1, width - 32))
        card:SetSize(width - 16, content + 16)
        height = height + card:GetTall() + 10
    end
    frame.qdCardsHeight = height
end
