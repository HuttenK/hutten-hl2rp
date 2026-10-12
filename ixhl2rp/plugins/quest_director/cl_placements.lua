-- Independent placement panel replaces the unavailable source MapEdit extension.
local PLUGIN, Q = PLUGIN, ix.questDirector
local UI = Q.ui
function Q:LoadPalette() end -- Recovered editors invalidate their old map palette after saves.
function Q:LoadPlacements()
    if IsValid(self.placementsPanel) and self.placementsPanel.Refresh then self.placementsPanel:Refresh() end
end
function Q:ShowPlacements(kind, definition, quest)
    if IsValid(self.placementsPanel) then self.placementsPanel:Remove() end
    local frame, body = UI.Frame("Размещения NPC, объектов и зон", 800, 770)
    self.placementsPanel = frame
    local selection = {kind = kind or "npc", definition = definition or "", target = "", radius = 128}
    UI.Label(body, "Наведитесь на нужную поверхность перед открытием окна. Подтверждение ставит объект в текущую точку взгляда. Администратор может передвинуть его физганом; отпускание сохраняет позицию.")
    local selected = UI.Label(body, selection.definition == "" and "Выберите шаблон" or selection.kind .. ": " .. selection.definition, true)
    for _, option in ipairs({{"npc", "Выбрать NPC"}, {"object", "Выбрать объект"}}) do
        UI.Button(body, option[2], function()
            Q:PickReference(option[1], function(id) selection.kind, selection.definition = option[1], id selected:SetText(option[2] .. ": " .. id) end)
        end)
    end
    UI.Button(body, "Разместить выбранный шаблон в точке взгляда", function()
        UI.Run(frame, "admin_place", selection, function() frame:Refresh() end)
    end)
    UI.Label(body, "Зона посещения", true)
    UI.Text(body, "Метка — такая же, как в цели задания", selection, "target")
    UI.Number(body, "Радиус зоны", selection, "radius", 32, 4096)
    UI.Button(body, "Создать зону в точке взгляда", function() UI.Run(frame, "admin_zone", selection, function() frame:Refresh() end) end)
    UI.Label(body, "Сохранённые размещения", true)
    local listing = body:Add("DPanel") listing:Dock(TOP) listing.Paint = nil
    listing.PerformLayout = function(s) s:SizeToChildren(false, true) end
    frame.page = 1
    function frame:Refresh()
        UI.Run(self, "admin_placements", {page = self.page}, function(data)
            listing:Clear() self.page = data.page
            UI.Label(listing, "Страница " .. data.page .. " / " .. data.pages)
            for _, entry in ipairs(data.rows) do
                UI.Button(listing, entry.label .. " · " .. (entry.enabled and "включено" or "выключено"), function() Q:ShowPlacement(entry) end)
            end
            for _, direction in ipairs({-1, 1}) do
                if data.page + direction >= 1 and data.page + direction <= data.pages then
                    UI.Button(listing, direction == 1 and "Следующая страница" or "Предыдущая страница", function() self.page = data.page + direction self:Refresh() end)
                end
            end
            if #data.zones > 0 then UI.Label(listing, "Зоны", true) end
            for _, zone in ipairs(data.zones) do
                UI.Button(listing, zone.target .. " · радиус " .. math.Round(zone.radius) .. " · удалить", function()
                    UI.Confirm("Удалить зону «" .. zone.target .. "»?", function() UI.Run(frame, "admin_zone", {remove = true, id = zone.id}, function() frame:Refresh() end) end)
                end)
            end
        end)
    end
    UI.Button(body, "Обновить список", function() frame:Refresh() end)
    frame:Refresh()
end

-- Standard Helix menu hook; journal remains available without a PDA item.
function PLUGIN:CreateMenuButtons(tabs)
    tabs["ЗАДАНИЯ"] = function(container)
        UI.Label(container, "Личные и групповые задания", true)
        UI.Label(container, "Квесты выдаются персонажами на карте. Здесь можно открыть цели, сроки и ожидающие награды.")
        UI.Button(container, "Открыть журнал", function()
            Q:Request("journal", {}, function(ok, view) if ok then Q:ShowJournal(view) else notification.AddLegacy(view, NOTIFY_ERROR, 5) end end)
        end)
        if Q.CanEdit(LocalPlayer()) then UI.Button(container, "Конструктор NPC и заданий", function() RunConsoleCommand("say", "/QuestAdmin") end) end
    end
end
