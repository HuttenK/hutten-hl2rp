local Q, UI = ix.questDirector, ix.questDirector.ui
local kinds = {quest = "Задания", npc = "Квестодатели", object = "Объекты", pool = "Пулы заданий",
    runs = "Активные группы", receipts = "Проверка наград", audit = "Журнал изменений"}

function Q:EditByID(kind, id, saved)
    self:Request("admin_get", {kind = kind, id = id}, function(ok, row)
        if not ok then notification.AddLegacy(row, NOTIFY_ERROR, 6) return end
        Q:EditDefinition(kind, row, function(result)
            Q:LoadPalette(true)
            if saved then saved(result) end
        end)
    end)
end

function Q:OpenQuestMap(id, kind, definition)
    -- Kept as a compatibility entry point for the recovered workbench.
    -- Placement uses ordinary world traces and the admin physgun; no map addon.
    self:ShowPlacements(kind, definition, id)
end

function Q:ShowPlacement(entry)
    if IsValid(self.placementPanel) then self.placementPanel:Remove() end
    local frame, body = UI.Frame("Размещение: " .. entry.label, 600, 510)
    self.placementPanel = frame
    UI.Label(body, entry.label, true)
    UI.Label(body, (entry.kind == "npc" and "Квестодатель" or "Квестовый объект") .. " · " .. (entry.enabled and "включён" or "выключен"))
    UI.Label(body, "Вы в ноуклипе: E открывает управление. Для прохождения задания выйдите из ноуклипа.")
    UI.Button(body, "Изменить настройки", function() Q:EditByID(entry.kind, entry.definition) end)
    UI.Button(body, entry.enabled and "Выключить шаблон" or "Включить шаблон", function()
        UI.Run(frame, "admin_get", {kind = entry.kind, id = entry.definition}, function(row)
            row.enabled = not row.enabled
            UI.Run(frame, "admin_put", {kind = entry.kind, record = row}, function()
                Q:LoadPalette(true) Q:LoadPlacements(true) frame:Remove()
            end)
        end)
    end)
    UI.Button(body, "Открыть размещения", function()
        Q:OpenQuestMap(nil) frame:Remove()
    end)
    UI.Button(body, "Перенести сюда, в точку взгляда", function()
        UI.Run(frame, "admin_move", {id = entry.id}, function() Q:LoadPlacements(true) frame:Remove() end)
    end)
    UI.Button(body, "Удалить с карты", function()
        UI.Confirm("Удалить «" .. entry.label .. "» с карты? Шаблон и задания сохранятся.", function()
            UI.Run(frame, "admin_unplace", {id = entry.id}, function() Q:LoadPlacements(true) frame:Remove() end)
        end)
    end)
end

function Q:NewSimpleQuest(onCreated)
    local frame, body = UI.Frame("Новый квест · три шага", 760, 770)
    local row = {name = "", npc = "", npcName = "Квестодатель", npcModel = "models/Humans/Group01/male_07.mdl",
        category = "Мои квесты", objectName = "Квестовый ящик", objectModel = "models/props_junk/wood_crate001a.mdl",
        goalName = "Осмотреть ящик", description = "Осмотри ящик и вернись к квестодателю.",
        reward = {money = 0, xp = 0, mode = "each", items = {}, skills = {}}}
    UI.Label(body, "1. Кто выдаёт задание?", true)
    local chosen = UI.Label(body, "Будет создан новый NPC: Квестодатель")
    UI.Button(body, "Выбрать существующего NPC", function()
        Q:PickReference("npc", function(id)
            row.npc = id
            Q:Request("admin_get", {kind = "npc", id = id}, function(ok, npc)
                if ok and IsValid(chosen) then chosen:SetText("Квестодатель: " .. npc.name) end
            end)
        end)
    end)
    UI.Button(body, "Создать нового NPC вместе с квестом", function() row.npc = "" chosen:SetText("Будет создан новый NPC с именем ниже") end)
    UI.Text(body, "Имя нового NPC", row, "npcName")
    UI.Label(body, "2. Что нужно сделать?", true)
    UI.Text(body, "Название задания", row, "name")
    UI.Text(body, "Описание для игрока", row, "description", true)
    UI.Text(body, "Название цели, например «Осмотреть тайник»", row, "goalName")
    UI.Text(body, "Название объекта на карте", row, "objectName")
    UI.Label(body, "Первое действие — E на объекте. Связи создаются автоматически. Другие действия и дополнительные цели доступны после создания.")
    UI.Label(body, "3. Что получит игрок?", true)
    self:EditRewards(body, row.reward, true)
    UI.Label(body, "После создания останется поставить NPC и объект на карту. Все настройки доступны и после создания.")
    local create = UI.Button(frame, "Создать квест и открыть схему", function()
        UI.Run(frame, "admin_create_quest", row, function(id)
            Q:LoadPalette(true) frame:Remove()
            if onCreated then onCreated() end
            Q:ShowQuestWorkbench(id)
        end)
    end)
    create:Dock(BOTTOM)
end

function Q:ShowQuestWorkbench(id)
    if IsValid(self.workbench) then self.workbench:Remove() end
    local frame, body = UI.Frame("Схема задания", 940, 860)
    self.workbench = frame
    local function load()
        UI.Run(frame, "admin_overview", {id = id}, function(view)
            body:Clear()
            UI.Label(body, view.name, true)
            UI.Label(body, view.description)
            UI.Label(body, "Квестодатель → " .. (view.ordered and "цели по порядку" or "цели в любом порядке") .. " → возврат к NPC → награда")
            UI.Label(body, "1. Квестодатель", true)
            if view.npc then
                local npc = view.npc
                UI.Label(body, npc.name .. " · на карте: " .. npc.placed .. (npc.enabled and " · включён" or " · выключен"))
                UI.Button(body, "Поставить квестодателя", function() Q:OpenQuestMap(id, "npc", npc.id) end)
                UI.Button(body, "Внешность и диалог NPC", function() Q:EditByID("npc", npc.id, load) end)
            else UI.Label(body, "NPC не выбран. Откройте настройки задания.") end
            UI.Label(body, "2. Цели и объекты", true)
            if #view.goals == 0 then UI.Label(body, "Добавьте первую цель в настройках задания.") end
            for index, goal in ipairs(view.goals) do
                UI.Label(body, (goal.ready and "✓ " or "○ ") .. index .. ". " .. goal.name, true)
                UI.Label(body, (Q.TYPES[goal.type] or goal.type) .. " · нужно: " .. goal.count .. "\n" .. goal.hint)
                for _, object in ipairs(goal.objects) do
                    UI.Button(body, "Поставить: " .. object.name .. " (на карте: " .. object.placed .. ")", function()
                        Q:OpenQuestMap(id, "object", object.id)
                    end)
                    UI.Button(body, "Настроить объект: " .. object.name .. (object.enabled and "" or " · выключен"), function()
                        Q:EditByID("object", object.id, load)
                    end)
                end
                if (goal.objectCount or 0) > #goal.objects then
                    UI.Label(body, "Ещё объектов: " .. (goal.objectCount - #goal.objects) .. ". Найдите их в списке объектов.")
                end
                if Q:IsObjectGoal(goal) and #goal.objects == 0 then
                    UI.Button(body, "Создать связанный объект для этой цели", function()
                        UI.Run(frame, "admin_goal_object", {id = id, revision = view.revision, goal = goal.id}, function()
                            Q:LoadPalette(true) load()
                        end)
                    end)
                end
            end
            UI.Button(body, "Изменить цели, награды и условия", function() Q:EditByID("quest", id, load) end)
            UI.Label(body, "3. Проверка перед игрой", true)
            for _, issue in ipairs(view.issues) do UI.Label(body, "• " .. issue) end
            local ready = #view.goals > 0
            for _, goal in ipairs(view.goals) do if not goal.ready then ready = false end end
            if #view.issues == 0 and ready then UI.Label(body, "Всё необходимое размещено и включено. Выйдите из ноуклипа, нажмите E на NPC и примите задание.") end
            if not ready then UI.Label(body, "Завершите пункты с пустым кружком выше.") end
            UI.Button(body, view.enabled and "Выключить выдачу задания" or "Включить выдачу задания", function()
                UI.Run(frame, "admin_get", {kind = "quest", id = id}, function(row)
                    row.enabled = not row.enabled
                    UI.Run(frame, "admin_put", {kind = "quest", record = row}, load)
                end)
            end)
            UI.Button(body, "Открыть размещения и зоны", function() Q:OpenQuestMap(id) end)
            frame:Status("Разместите NPC и объекты в точке взгляда. Положение после движения физганом сохраняется при отпускании.")
        end)
    end
    local refresh = UI.Button(frame, "Обновить проверку размещений", load) refresh:Dock(BOTTOM)
    load()
end

function Q:ShowAdmin()
    if IsValid(self.adminPanel) then self.adminPanel:Remove() end
    local frame = UI.Frame("Квесты · конструктор", 1100, 780)
    self.adminPanel = frame frame.body:Remove()
    local nav = frame:Add("DScrollPanel") nav:Dock(LEFT) nav:SetWide(math.min(220, ScrW() * 0.24)) nav:DockMargin(0, 0, 12, 0)
    local content = frame:Add("DPanel") content:Dock(FILL) content.Paint = nil
    local kind, page, total, searchVersion = "quest", 1, 0, 0
    local title = UI.Label(content, "Задания", true)
    local help = UI.Label(content, "Откройте задание: схема покажет NPC, цели и недостающие объекты.")
    local search = content:Add("DTextEntry") search:Dock(TOP) search:SetTall(30) search:SetPlaceholderText("Поиск по названию или категории")
    local bar = content:Add("DPanel") bar:Dock(TOP) bar:SetTall(46) bar.Paint = nil
    local footer = content:Add("DPanel") footer:Dock(BOTTOM) footer:SetTall(40) footer.Paint = nil
    local list = content:Add("DListView") list:Dock(FILL)
    list:AddColumn("Название") list:AddColumn("Категория") list:AddColumn("Состояние")
    local function load()
        local requestedKind, requestedPage, query = kind, page, search:GetValue()
        searchVersion = searchVersion + 1 local version = searchVersion
        Q:Request("admin_list", {kind = kind, page = page, search = query}, function(ok, result)
            if not IsValid(frame) or version ~= searchVersion or requestedKind ~= kind or requestedPage ~= page or query ~= search:GetValue() then return end
            if not ok then frame:Status(result) return end
            total = result.total or #result.rows list:Clear()
            title:SetText(kinds[kind])
            for _, row in ipairs(result.rows) do
                local name = row.name or ((row.action or "") .. " · " .. os.date("%d.%m %H:%M", row.time))
                local line = list:AddLine(name, row.category or row.actor or "", row.status or "") line.record = row
            end
            frame:Status("Страница " .. page .. " / " .. math.max(1, math.ceil(total / 40)) .. " · записей: " .. total)
        end, frame)
    end
    local function selected()
        local index = list:GetSelectedLine() local line = index and list:GetLine(index)
        return line and line.record
    end
    local function open(row)
        if kind == "quest" then Q:ShowQuestWorkbench(row.id)
        elseif Q.LIMITS[kind] then Q:EditByID(kind, row.id, load) end
    end
    local function more(record)
        local row, selectedKind = record or selected(), kind
        if not row then frame:Status("Сначала выберите строку.") return end
        local menu = DermaMenu()
        if Q.LIMITS[kind] then
            menu:AddOption("Настройки", function() Q:EditByID(selectedKind, row.id, load) end)
            menu:AddOption("Сделать копию", function()
                UI.Run(frame, "admin_get", {kind = selectedKind, id = row.id}, function(copy)
                    copy.id, copy.revision, copy.enabled, copy.name = "", 0, false, copy.name .. " — копия"
                    Q:EditDefinition(selectedKind, copy, load)
                end)
            end)
            menu:AddOption(row.enabled and "Выключить" or "Включить", function()
                UI.Run(frame, "admin_get", {kind = selectedKind, id = row.id}, function(value)
                    value.enabled = not value.enabled
                    UI.Run(frame, "admin_put", {kind = selectedKind, record = value}, function() Q:LoadPalette(true) load() end)
                end)
            end)
            if kind == "quest" then menu:AddOption("Опубликовать заново (обновить срок)", function()
                UI.Run(frame, "admin_publish", {id = row.id, revision = row.revision}, load)
            end) end
        end
        if Q.LIMITS[kind] or kind == "runs" then menu:AddOption(kind == "runs" and "Отменить задание группы" or "Удалить шаблон", function()
            UI.Confirm("Удалить «" .. row.name .. "»? Для группы это провал. Используемые шаблоны защищены от удаления.", function()
                UI.Run(frame, selectedKind == "runs" and "admin_cancel" or "admin_delete", {kind = selectedKind, id = row.id, revision = row.revision}, load)
            end)
        end) end
        if kind == "receipts" then
            for _, delivered in ipairs({true, false}) do menu:AddOption(delivered and "Подтвердить выданный шаг" or "Разрешить повтор шага", function()
                UI.Confirm("Сначала проверьте инвентарь, баланс и логи. Неверное решение может потерять или удвоить награду.", function()
                    UI.Run(frame, "admin_receipt", {receipt = row.id, delivered = delivered, cursor = row.cursor}, load)
                end)
            end) end
        end
        if kind == "runs" and row.status == "Передача требует проверки" then
            for _, delivered in ipairs({true, false}) do menu:AddOption(delivered and "Передача: предметы изъяты, зачесть" or "Передача: предметы не изъяты, повторить", function()
                UI.Confirm("Сначала проверьте серверные данные и инвентарь участника. Неверное решение может потерять предметы или зачесть их повторно.", function()
                    UI.Run(frame, "admin_deposit", {id = row.id, delivered = delivered}, load)
                end)
            end) end
        end
        menu:Open()
    end
    local function button(parent, text, callback, width)
        local b = UI.Button(parent, text, callback) b:Dock(LEFT) b:SetWide(width) b:DockMargin(0, 4, 6, 4) return b
    end
    local create = button(bar, "Создать квест", function()
        if kind == "quest" then Q:NewSimpleQuest(load)
        elseif Q.LIMITS[kind] then
            Q:EditDefinition(kind, Q:Clean(kind, {name = "Новая запись", start = "start", nodes = {{id = "start", text = "Здравствуйте.", options = {}}}}), load)
        end
    end, 155)
    local openButton = button(bar, "Открыть", function() local row = selected() if row then open(row) end end, 110)
    local moreButton = button(bar, "Действия…", function() more() end, 120)
    button(footer, "←", function() if page > 1 then page = page - 1 load() end end, 42)
    button(footer, "→", function() if page * 40 < total then page = page + 1 load() end end, 42)
    button(footer, "Обновить", load, 110)
    list.DoDoubleClick = function(_, _, line) open(line.record) end
    list.OnRowRightClick = function(_, _, line) more(line.record) end
    local function select(key, query)
        kind, page = key, 1 search:SetText(query or "")
        create:SetVisible(Q.LIMITS[kind] ~= nil) create:SetText(kind == "quest" and "Создать квест" or "Создать")
        openButton:SetVisible(Q.LIMITS[kind] ~= nil) moreButton:SetVisible(kind ~= "audit")
        help:SetText(kind == "quest" and "Откройте задание: схема покажет NPC, цели и недостающие объекты." or "Откройте запись. Дополнительные операции находятся в меню «Действия».")
        load()
    end
    UI.Button(nav, "Тестовые примеры", function()
        UI.Run(frame, "admin_examples", {}, function(message)
            select("quest", "qd_test_v2_") Q:LoadPalette(true)
            notification.AddLegacy(message, NOTIFY_GENERIC, 10)
        end)
    end)
    UI.Label(nav, "Готовы к запуску: поставьте NPC и объекты. Начните с «1. Осмотреть ящик».")
    for _, key in ipairs({"quest", "npc", "object"}) do UI.Button(nav, kinds[key], function() select(key) end) end
    UI.Button(nav, "Размещения и зоны", function() Q:OpenQuestMap(nil) end)
    UI.Button(nav, "Дополнительно…", function()
        local menu = DermaMenu()
        for _, key in ipairs({"pool", "runs", "receipts", "audit"}) do menu:AddOption(kinds[key], function() select(key) end) end
        menu:AddOption("Репутация персонажа", function() Q:ShowReputationAdmin() end)
        menu:Open()
    end)
    search.OnEnter = function() page = 1 load() end
    search.OnChange = function() search.nextSearch = RealTime() + 0.35 end
    search.Think = function(s) if s.nextSearch and s.nextSearch <= RealTime() then s.nextSearch = nil page = 1 load() end end
    load()
end
