local Q, UI = ix.questDirector, ix.questDirector.ui
local kinds = {npc = "Квестодатели и диалоги", quest = "Задания", object = "Объекты", pool = "Пулы", runs = "Активные группы", receipts = "Проверка наград", audit = "Журнал изменений"}

function UI.Text(parent, label, row, key, multiline)
    UI.Label(parent, label)
    local input = parent:Add("DTextEntry") input:Dock(TOP) input:DockMargin(0, 0, 0, 9)
    input:SetTall(multiline and 120 or 28) input:SetMultiline(multiline == true)
    input:SetText(tostring(row[key] or ""))
    input.OnChange = function(s) row[key] = s:GetValue() end
    return input
end

function UI.Number(parent, label, row, key, low, high, scale)
    UI.Label(parent, label)
    local input = parent:Add("DNumberWang") input:Dock(TOP) input:DockMargin(0, 0, 0, 8)
    input:SetTall(27) input:SetMinMax(low or 0, high or 1000000)
    input:SetDecimals(2) input:SetValue((row[key] or 0) / (scale or 1))
    input.OnValueChanged = function(_, value) row[key] = (tonumber(value) or 0) * (scale or 1) end
    return input
end

function UI.Bool(parent, label, row, key)
    local input = parent:Add("DCheckBoxLabel") input:Dock(TOP) input:DockMargin(0, 7, 0, 10)
    input:SetTall(26) input:SetText(label) input:SetValue(row[key] == true)
    input.OnChange = function(_, value) row[key] = value end
    return input
end

function UI.Choice(parent, label, row, key, choices)
    UI.Label(parent, label)
    local input = parent:Add("DComboBox") input:Dock(TOP) input:DockMargin(0, 0, 0, 9) input:SetTall(28)
    local ordered = {}
    for id, name in pairs(choices) do ordered[#ordered + 1] = {id = id, name = name} end
    table.sort(ordered, function(a, b) return a.name < b.name end)
    for _, choice in ipairs(ordered) do input:AddChoice(choice.name, choice.id, row[key] == choice.id) end
    input.OnSelect = function(_, _, _, value) row[key] = value end
    return input
end

function UI.Tab(sheet, title)
    local panel = vgui.Create("DScrollPanel", sheet) panel:Dock(FILL) panel:DockMargin(10, 8, 10, 8)
    sheet:AddSheet(title, panel)
    return panel
end

function UI.Fold(parent, title, build)
    local section = parent:Add("DCollapsibleCategory") section:Dock(TOP) section:DockMargin(0, 4, 0, 8)
    section:SetLabel(title) section:SetExpanded(false)
    local content = vgui.Create("DPanel", section) content:DockPadding(10, 8, 10, 8)
    content.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(36, 42, 49)) end
    content.PerformLayout = function(s) s:SizeToChildren(false, true) end
    build(content) section:SetContents(content)
    return section
end

function UI.Array(parent, title, rows, default, edit, describe, maxRows)
    UI.Label(parent, title, true)
    local list = parent:Add("DListView") list:Dock(TOP) list:SetTall(180) list:DockMargin(0, 0, 0, 8)
    list:AddColumn("№"):SetFixedWidth(30) list:AddColumn("Описание")
    local function refresh()
        list:Clear()
        for i, row in ipairs(rows) do local line = list:AddLine(i, describe(row)) line.index = i end
    end
    local function open(index)
        local frame, body = UI.Frame(title, 720, 790)
        local value = table.Copy(index and rows[index] or default())
        local save = UI.Button(frame, "Применить к черновику", function()
            if index then rows[index] = value else rows[#rows + 1] = value end
            refresh() frame:Remove()
        end)
        save:Dock(BOTTOM)
        edit(body, value, frame)
    end
    list.DoDoubleClick = function(_, _, line) open(line.index) end
    UI.Button(parent, "Добавить", function() if #rows < (maxRows or 32) then open() else notification.AddLegacy("Достигнут лимит строк.", NOTIFY_ERROR, 5) end end)
    local function actions(index)
        if not index then return end
        local menu = DermaMenu()
        menu:AddOption("Изменить", function() open(index) end)
        if index > 1 then menu:AddOption("Выше", function()
            rows[index], rows[index - 1] = rows[index - 1], rows[index] refresh()
        end) end
        if index < #rows then menu:AddOption("Ниже", function()
            rows[index], rows[index + 1] = rows[index + 1], rows[index] refresh()
        end) end
        menu:AddOption("Удалить", function()
            UI.Confirm("Удалить строку из черновика?", function() table.remove(rows, index) refresh() end)
        end)
        menu:Open()
    end
    UI.Button(parent, "Действия с выбранной строкой…", function() actions(list:GetSelectedLine()) end)
    list.OnRowRightClick = function(_, _, line) actions(line.index) end
    refresh()
end

function Q:PickReference(kind, callback, projection)
    local frame, body = UI.Frame("Выбрать: " .. (kinds[kind] or kind), 650, 650)
    local search = body:Add("DTextEntry") search:Dock(TOP) search:SetTall(30) search:SetPlaceholderText("Поиск по имени, категории или ключу")
    local page = 1
    local host = body:Add("DPanel") host:Dock(TOP) host:SetTall(430) host.Paint = nil
    local list = host:Add("DListView") list:Dock(FILL) list:AddColumn("Имя") list:AddColumn("Категория") list:AddColumn("Ключ")
    local function load()
        local requestedKind, requestedPage = kind, page
        UI.Run(frame, "admin_list", {kind = kind, page = page, search = search:GetValue()}, function(result)
            if requestedKind ~= kind or requestedPage ~= page then load() return end
            list:Clear()
            for _, row in ipairs(result.rows) do local line = list:AddLine(row.name, row.category, row.id) line.record = row end
            frame:Status("Страница " .. page .. "; записей: " .. result.total)
        end)
    end
    search.OnEnter = function() page = 1 load() end
    UI.Button(body, "Поиск / обновить", function() page = 1 load() end)
    UI.Button(body, "Предыдущая страница", function() page = math.max(1, page - 1) load() end)
    UI.Button(body, "Следующая страница", function() page = page + 1 load() end)
    list.DoDoubleClick = function(_, _, line)
        if projection then
            Q:Request("admin_get", {kind = kind, id = line.record.id}, function(ok, row)
                if ok then callback(row[projection]) frame:Remove() else frame:Status(row) end
            end, frame)
        else callback(line.record.id) frame:Remove() end
    end
    load()
end

function UI.Reference(parent, label, row, key, kind, projection)
    local input = UI.Text(parent, label, row, key)
    UI.Button(parent, "Выбрать из списка", function()
        Q:PickReference(kind, function(id) row[key] = id input:SetText(id) end, projection)
    end)
end

function UI.Catalog(parent, label, row, key, catalog)
    local input = UI.Text(parent, label, row, key)
    UI.Button(parent, "Найти в каталоге", function()
        local frame, body = UI.Frame(label, 600, 650)
        local search = body:Add("DTextEntry") search:Dock(TOP) search:SetTall(30) search:SetPlaceholderText("Начните вводить имя или ключ")
        local list = body:Add("DListView") list:Dock(TOP) list:SetTall(490) list:AddColumn("Имя") list:AddColumn("Ключ")
        local function fill()
            list:Clear()
            local query = search:GetValue():lower()
            local count = 0
            for id, value in SortedPairs(catalog) do
                local name = isstring(value) and value or L(value.name or value.PrintName or id)
                if (name .. " " .. id):lower():find(query, 1, true) then
                    local line = list:AddLine(name, id) line.key = id
                    count = count + 1 if count >= 150 then break end
                end
            end
        end
        search.OnChange = fill
        list.DoDoubleClick = function(_, _, line) row[key] = line.key input:SetText(line.key) frame:Remove() end
        fill()
    end)
end

function UI.Check(parent, check)
    UI.Label(parent, "Проверка действия", true)
    UI.Label(parent, "Порог: навык × вес + характеристика × вес ≥ сложность. Бросок добавляет d20. Сложность 0 без броска отключает проверку.")
    UI.Choice(parent, "Механика", check, "mode", {threshold = "Порог значения", roll = "d20 + значения"})
    local skills, stats = {[""] = "Не учитывать"}, {[""] = "Не учитывать"}
    for id, row in pairs(ix.skills and ix.skills.list or {}) do skills[id] = L(row.name) .. " (" .. id .. ")" end
    for id, row in pairs(ix.specials and ix.specials.list or {}) do stats[id] = L(row.name) .. " (" .. id .. ")" end
    UI.Choice(parent, "Навык", check, "skill", skills)
    UI.Number(parent, "Вес навыка", check, "skillWeight", 0, 100)
    UI.Choice(parent, "Характеристика", check, "stat", stats)
    UI.Number(parent, "Вес характеристики", check, "statWeight", 0, 100)
    UI.Number(parent, "Сложность", check, "difficulty", 0, 10000)
    UI.Number(parent, "Пауза между попытками, секунд", check, "retry", 1, 86400)
end

local function freshID(rows, prefix)
    local used = {} for _, row in ipairs(rows) do used[row.id] = true end
    local i = 1 while used[prefix .. i] do i = i + 1 end
    return prefix .. i
end

function Q:EditQuest(sheet, row)
    local basic = UI.Tab(sheet, "Условия")
    UI.Reference(basic, "Квестодатель", row, "npc", "npc")
    UI.Text(basic, "Описание для игрока", row, "description", true)
    UI.Bool(basic, "Выдавать только через ответ в диалоге", row, "dialogueOnly")
    UI.Bool(basic, "Можно повторять после кулдауна", row, "repeatable")
    UI.Reference(basic, "Предыдущее задание цепочки (пусто — нет)", row, "prerequisite", "quest")
    UI.Reference(basic, "Пул сменяемых заданий (пусто — всегда по расписанию)", row, "pool", "pool")
    local timing = UI.Tab(sheet, "Время и группа")
    UI.Label(timing, "Все длительности ниже — минуты. 0 отключает ограничение. Сроки идут и вне игры.")
    for _, field in ipairs({{"duration", "Время на выполнение"}, {"successCooldown", "Кулдаун после успеха"}, {"failureCooldown", "Кулдаун после провала / отказа"},
        {"nextDelay", "Пауза до следующего задания цепочки"}, {"lifetime", "Сколько минут выдавать после публикации"}}) do
        UI.Number(timing, field[2], row, field[1], 0, 525600, 60)
    end
    UI.Label(timing, "Дата доступности: местное время вашего компьютера, ГГГГ-ММ-ДД ЧЧ:ММ. Пусто — без границы. Кнопка «Опубликовать заново» перезапускает срок выдачи.")
    for _, field in ipairs({{"availableFrom", "Начало выдачи"}, {"availableUntil", "Окончание выдачи"}}) do
        local values = {value = row[field[1]] > 0 and os.date("%Y-%m-%d %H:%M", row[field[1]]) or ""}
        local entry = UI.Text(timing, field[2], values, "value")
        entry.OnChange = function(s)
            local text = s:GetValue()
            local year, month, day, hour, minute = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d)$")
            if text == "" then row[field[1]] = 0 s:SetTextColor(color_black)
            elseif year then
                row[field[1]] = os.time({year = tonumber(year), month = tonumber(month), day = tonumber(day), hour = tonumber(hour), min = tonumber(minute), sec = 0}) or 0
                s:SetTextColor(color_black)
            else s:SetTextColor(Color(180, 40, 40)) end
        end
    end
    UI.Number(timing, "Минимум участников, включая лидера", row, "minMembers", 1, 8)
    UI.Number(timing, "Максимум участников, включая лидера", row, "maxMembers", 1, 8)
    UI.Bool(timing, "Проверять кулдаун успеха у каждого участника группы", row, "lockParticipants")
    UI.Bool(timing, "Минимальный состав должен быть рядом при выполнении и сдаче", row, "requireTogether")
    UI.Label(timing, "У лидера кулдаун проверяется всегда. Участники, вышедшие из группы, также получают запись об участии при её успешном завершении, но не награду.")
    local goals = UI.Tab(sheet, "Цели")
    UI.Bool(goals, "Выполнять цели строго по порядку", row, "ordered")
    UI.Array(goals, "Цели задания", row.objectives, function()
        local id = freshID(row.objectives, "goal_")
        return {id = id, name = "Новая цель", type = "use", target = row.id ~= "" and row.id .. "_" .. id or id, count = 1, item = "", weapon = "", check = Q:CleanCheck()}
    end, function(body, goal)
        UI.Text(body, "Что увидит игрок в списке целей", goal, "name")
        local action = UI.Choice(body, "Что должен сделать игрок", goal, "type", Q.TYPES)
        UI.Number(body, "Сколько раз / предметов / единиц урона", goal, "count", 1, 1000000)
        local details = body:Add("DPanel") details:Dock(TOP) details.Paint = nil
        details.PerformLayout = function(s) s:SizeToChildren(false, true) end
        local function refreshDetails()
            details:Clear()
            if Q:IsObjectGoal(goal) then
                local picked = UI.Label(details, "Связь: " .. goal.target)
                UI.Button(details, "Выбрать существующий объект", function()
                    Q:PickReference("object", function(target)
                        goal.target = target
                        if IsValid(picked) then picked:SetText("Связь: " .. target) end
                    end, "target")
                end)
                UI.Label(details, "Нужен новый объект? Сохраните цель и задание, затем нажмите «Создать связанный объект» в схеме задания. Метка уже подготовлена.")
                if goal.type == "deposit" then
                    UI.Catalog(details, "Какой предмет передать", goal, "item", ix.Item:All())
                elseif goal.type == "damage" then
                    local weaponsByClass = {}
                    for _, weapon in ipairs(weapons.GetList()) do if weapon.ClassName then weaponsByClass[weapon.ClassName] = weapon end end
                    UI.Catalog(details, "Оружие (пусто — любое)", goal, "weapon", weaponsByClass)
                end
            elseif goal.type == "zone" then
                UI.Text(details, "Метка зоны", goal, "target")
                UI.Label(details, "В разделе «Размещения и зоны» создайте сферу с такой же меткой. Центр берётся из точки взгляда, радиус задаётся в единицах Source.")
            else
                UI.Text(details, "Метка ответа NPC", goal, "target")
                UI.Label(details, "В диалоге квестодателя выберите у ответа действие «Выполнить цель» и ту же метку.")
            end
        end
        action.OnSelect = function(_, _, _, value) goal.type = value refreshDetails() end
        refreshDetails()
        UI.Fold(body, "Проверка навыка и бросок (необязательно)", function(parent) UI.Check(parent, goal.check) end)
        UI.Fold(body, "Технические ключи и ручная привязка", function(parent)
            UI.Text(parent, "Уникальный ключ цели", goal, "id")
            local target = UI.Text(parent, "Метка объекта / диалога / имя зоны", goal, "target")
            target.OnChange = function(input) goal.target = input:GetValue() refreshDetails() end
            target.Think = function(input) if not input:HasFocus() and input:GetValue() ~= goal.target then input:SetText(goal.target) end end
        end)
    end, function(goal) return (Q.TYPES[goal.type] or "?") .. " · " .. goal.name .. " · " .. goal.target end)
    local reward = UI.Tab(sheet, "Награда")
    self:EditRewards(reward, row.reward)
    self:EditQuestReputation(sheet, row)
end

function Q:EditNPC(sheet, row)
    local prepareAppearance = self:EditNPCAppearance(sheet, row)
    self:EditNPCPortrait(sheet, row)
    self:EditNPCReputation(sheet, row)
    local dialogue = UI.Tab(sheet, "Диалог")
    UI.Label(dialogue, "Каждая реплика содержит ответы, переходы, проверки и действия. Переход при неудаче позволяет создавать отдельные ветки. Ключи реплик должны быть уникальны.")
    UI.Text(dialogue, "Ключ начальной реплики", row, "start")
    UI.Array(dialogue, "Реплики NPC", row.nodes, function() return {id = freshID(row.nodes, "node_"), text = "Новая реплика", options = {}} end,
        function(body, node)
            UI.Text(body, "Ключ реплики", node, "id")
            UI.Text(body, "Текст NPC", node, "text", true)
            UI.Array(body, "Ответы игрока", node.options, function() return {text = "Продолжить", action = "goto_node", next = "", fail = "", quest = "", target = "", check = Q:CleanCheck()} end,
                function(form, option)
                    UI.Text(form, "Текст ответа", option, "text")
                    UI.Choice(form, "Действие", option, "action", Q.ACTIONS)
                    local destinations = {[""] = "Остаться в этой реплике"}
                    for _, candidate in ipairs(row.nodes) do destinations[candidate.id] = candidate.id .. " · " .. candidate.text:sub(1, 50) end
                    destinations[node.id] = node.id
                    UI.Choice(form, "Следующая реплика при успехе", option, "next", destinations)
                    UI.Choice(form, "Реплика при неудаче", option, "fail", destinations)
                    UI.Reference(form, "Задание для действия", option, "quest", "quest")
                    UI.Text(form, "Метка цели (действие «Выполнить цель»)", option, "target")
                    option.reputation = option.reputation or Q:CleanReputationGate()
                    UI.ReputationGate(form, option.reputation)
                    UI.Check(form, option.check)
                end, function(option) return option.text .. " → " .. (Q.ACTIONS[option.action] or "?") .. " " .. option.next end, 8)
        end, function(node) return node.id .. " · " .. node.text:sub(1, 100) end)
    return prepareAppearance
end

function Q:EditDefinition(kind, source, onSaved)
    local row = table.Copy(source)
    local frame = UI.Frame((row.id == "" and "Создать: " or "Изменить: ") .. kinds[kind], 1020, 850)
    if kind == "npc" then frame:SetSizable(true) frame:SetMinWidth(720) frame:SetMinHeight(580) end
    frame.body:Remove()
    local prepareSave
    local save = UI.Button(frame, "Сохранить на сервере", function()
        if prepareSave then prepareSave() end
        UI.Run(frame, "admin_put", {kind = kind, record = row}, function(saved)
            row.id, row.revision = saved.id, saved.revision
            frame:Status("Сохранено: " .. saved.id .. ". Ревизия " .. saved.revision)
            if onSaved then onSaved(saved) end
        end)
    end)
    save:Dock(BOTTOM)
    local sheet = frame:Add("DPropertySheet") sheet:Dock(FILL)
    local common = UI.Tab(sheet, "Основное")
    UI.Label(common, row.id == "" and "Ключ появится после первого сохранения." or "Ключ: " .. row.id, true)
    UI.Text(common, "Название", row, "name") UI.Text(common, "Категория (квест, персонаж или сюжетная линия)", row, "category")
    UI.Bool(common, "Включено / опубликовано", row, "enabled")
    UI.Label(common, "Снятие публикации прекращает выдачу новых заданий. Уже принятые задания сохраняют свои условия. Неполные записи сохраняйте выключенными.")
    if kind == "quest" then self:EditQuest(sheet, row)
    elseif kind == "npc" then prepareSave = self:EditNPC(sheet, row)
    elseif kind == "pool" then
        UI.Number(common, "Смена заданий каждые N минут", row, "interval", 1, 525600, 60)
        UI.Number(common, "Число одновременно доступных заданий", row, "slots", 1, 32)
        UI.Label(common, "В пул входят задания, у которых выбран его ключ. Ротация идёт по кругу, в стабильном порядке ключей, и переживает рестарт. Уже принятые задания продолжаются после смены пула.")
    elseif kind == "object" then
        UI.Text(common, "Модель объекта / контейнера", row, "model")
        UI.Number(common, "Скин", row, "skin", 0, 128)
        UI.Text(common, "Метка цели — та же, что в конструкторе задания", row, "target")
        UI.Reference(common, "Ограничить одним заданием (пусто — все с этой меткой)", row, "quest", "quest")
        UI.Label(common, "Тип взаимодействия, количество, предмет, оружие и проверка задаются в целях задания. Один шаблон можно разместить несколько раз. Квестовый контейнер принимает предметы через E с подтверждением передачи.")
    end
    return frame
end
