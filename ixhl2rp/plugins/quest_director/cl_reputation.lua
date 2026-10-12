local Q, UI = ix.questDirector, ix.questDirector.ui

function UI.ReputationGate(parent, gate)
    UI.Bool(parent, "Требовать репутацию у этого квестодателя", gate, "required")
    UI.Number(parent, "Минимальная репутация", gate, "minimum", -100000, 100000):SetDecimals(0)
end

function Q:EditNPCReputation(sheet, row)
    local body = UI.Tab(sheet, "Репутация")
    local rep = row.reputation
    UI.Bool(body, "Включить личную репутацию у этого NPC", rep, "enabled")
    UI.Label(body, "Шкала отдельная для каждого персонажа и NPC на текущей карте. Выключение сохраняет накопленные значения. Изменения за задания настраиваются в самих заданиях.")
    UI.Number(body, "Минимум шкалы", rep, "minimum", -100000, 99999):SetDecimals(0)
    UI.Number(body, "Максимум шкалы", rep, "maximum", -99999, 100000):SetDecimals(0)
    UI.Number(body, "Начальное значение для персонажа без истории", rep, "initial", -100000, 100000):SetDecimals(0)
    UI.Array(body, "Уровни доверия (первый порог = минимум шкалы)", rep.tiers,
        function() return {name = "Новый уровень", value = 10} end,
        function(form, tier)
            UI.Text(form, "Название уровня", tier, "name")
            UI.Number(form, "Действует начиная с репутации", tier, "value", -100000, 100000):SetDecimals(0)
        end, function(tier) return tier.value .. " · " .. tier.name end, 16)
end

function Q:EditQuestReputation(sheet, row)
    local body = UI.Tab(sheet, "Репутация")
    UI.ReputationGate(body, row.reputation)
    UI.Label(body, "Порог проверяется у каждого участника при приглашении, принятии и старте, независимо от настройки кулдаунов.")
    UI.Number(body, "Изменение за успешную сдачу (может быть отрицательным)", row.reputation, "success", -100000, 100000):SetDecimals(0)
    UI.Number(body, "Изменение за провал / отказ / отмену", row.reputation, "failure", -100000, 100000):SetDecimals(0)
    UI.Choice(body, "Чья репутация меняется", row.reputation, "mode", {each = "Каждого участника", leader = "Только лидера"})
    UI.Label(body, "За успех — оставшемуся составу. За провал — всем участвовавшим, включая вышедших. Репутация меняется при завершении, независимо от получения вещей и денег. Шкала и изменения фиксируются при старте; уже принятые задания сохраняют их.")
end

function Q:ShowReputationAdmin()
    local frame, body = UI.Frame("Репутация персонажа", 640, 700)
    local selection, current = {npc = "", character = 0, value = 0, reason = ""}, nil
    UI.Label(body, "Выберите персонажа онлайн и NPC с включённой репутацией. Каждая правка требует причины и попадает в журнал.")
    local players = body:Add("DComboBox") players:Dock(TOP) players:SetTall(30) players:SetValue("Персонаж онлайн")
    local function refreshPlayers()
        UI.Run(frame, "admin_reputation", {list = true}, function(data)
            players:Clear() selection.character, current = 0, nil
            for _, row in ipairs(data.players) do players:AddChoice(row.name .. " (#" .. row.character .. ")", row.character) end
        end)
    end
    players.OnSelect = function(_, _, _, id) selection.character, current = id, nil end
    UI.Button(body, "Обновить игроков", refreshPlayers)
    UI.Reference(body, "Квестодатель", selection, "npc", "npc")
    local info = UI.Label(body, "Загрузите текущее значение.")
    local amount
    UI.Button(body, "Загрузить репутацию", function()
        UI.Run(frame, "admin_reputation", {character = selection.character, npc = selection.npc}, function(data)
            current = data
            info:SetText(data.name .. ": " .. data.value .. " · " .. data.tier .. " (" .. data.minimum .. "…" .. data.maximum .. ")")
            amount:SetMinMax(data.minimum, data.maximum) amount:SetValue(data.value) selection.value = data.value
        end)
    end)
    amount = UI.Number(body, "Новое значение", selection, "value", -100000, 100000)
    amount:SetDecimals(0)
    UI.Text(body, "Причина изменения", selection, "reason", true)
    UI.Button(body, "Сохранить репутацию", function()
        if not current or current.character ~= selection.character or current.npc ~= selection.npc then frame:Status("Сначала загрузите репутацию выбранного персонажа и NPC.") return end
        UI.Run(frame, "admin_reputation", {set = true, character = current.character, npc = current.npc,
            value = selection.value, expected = current.value, revision = current.revision, reason = selection.reason}, function(data)
            current = data info:SetText(data.name .. ": " .. data.value .. " · " .. data.tier)
            frame:Status("Репутация сохранена. Изменение записано в журнал.")
        end)
    end)
    refreshPlayers()
end
