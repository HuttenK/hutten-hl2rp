local Q, UI = ix.questDirector, ix.questDirector.ui
local function lower(value) return (string.utf8lower or string.lower)(value) end

function Q:RewardCatalog()
    local result, categories = {}, {[""] = "Все категории"}
    for id, item in pairs(ix.Item:All()) do
        if not item.isBase and not tostring(item.name):find("Base", 1, true) then
            local name, category = L(item.name or id), L(item.category or "Other")
            categories[category] = category
            result[#result + 1] = {id = id, name = name, category = category, item = item,
                search = lower(name .. " " .. id .. " " .. category)}
        end
    end
    table.sort(result, function(a, b) return a.name == b.name and a.id < b.id or a.name < b.name end)
    return result, categories
end

function Q:RewardCatalogPage(catalog, query, category, page)
    local found = {}
    query = lower(query or "")
    for _, entry in ipairs(catalog) do
        if (category == "" or category == entry.category) and entry.search:find(query, 1, true) then found[#found + 1] = entry end
    end
    local pages = math.max(1, math.ceil(#found / 24))
    page = math.Clamp(page, 1, pages)
    local rows = {}
    for i = (page - 1) * 24 + 1, math.min(page * 24, #found) do rows[#rows + 1] = found[i] end
    return rows, page, pages, #found
end

function Q:RewardItemIcon(parent, id, clicked)
    local item = ix.Item:Get(id)
    local icon = parent:Add("ContentIcon")
    icon:SetContentType("ixItem") icon:SetName(item and L(item.name) or id)
    icon:SetTooltip((item and L(item.name) or id) .. "\n" .. id)
    -- Same cached ModelImage as the Q-menu, without its spawn/give callbacks.
    if item then
        local model = item.GetIconModel and item:GetIconModel() or item.GetModel and item:GetModel() or item.model
        if isstring(model) and model ~= "" then
            local preview = icon:Add("ModelImage")
            preview:SetMouseInputEnabled(false) preview:SetKeyboardInputEnabled(false)
            preview:StretchToParent(12, 8, 12, 24)
            preview:SetModel(model, item.GetSkin and item:GetSkin() or item.skin or 0, "000000000")
            preview:MoveToBefore(icon.Image)
        end
    end
    icon.DoClick = clicked or function() end
    icon.OpenMenu = function() end
    return icon
end

function Q:PickRewardItem(callback)
    local frame = UI.Frame("Выбрать предмет награды", 860, 720)
    frame.body:Remove()
    local catalog, categories = self:RewardCatalog()
    local filters, page = {category = ""}, 1
    local search = frame:Add("DTextEntry") search:Dock(TOP) search:SetTall(30)
    search:SetPlaceholderText("Поиск по названию, категории или ключу") search:DockMargin(0, 0, 0, 8)
    local category = UI.Choice(frame, "Категория", filters, "category", categories)
    local footer = frame:Add("DPanel") footer:Dock(BOTTOM) footer:SetTall(38) footer.Paint = nil
    local previous = UI.Button(footer, "← Назад", function() page = page - 1 frame:Refresh() end)
    previous:Dock(LEFT) previous:SetWide(120)
    local nextPage = UI.Button(footer, "Далее →", function() page = page + 1 frame:Refresh() end)
    nextPage:Dock(RIGHT) nextPage:SetWide(120)
    local count = footer:Add("DLabel") count:Dock(FILL) count:SetContentAlignment(5)
    local scroll = frame:Add("DScrollPanel") scroll:Dock(FILL)
    local grid = scroll:Add("DIconLayout") grid:Dock(TOP) grid:SetSpaceX(8) grid:SetSpaceY(8)
    function frame:Refresh()
        local rows, current, pages, total = Q:RewardCatalogPage(catalog, search:GetValue(), filters.category, page)
        page = current grid:Clear()
        for _, entry in ipairs(rows) do
            Q:RewardItemIcon(grid, entry.id, function() callback(entry.id) self:Remove() end)
        end
        count:SetText("Страница " .. page .. " / " .. pages .. " · найдено: " .. total)
        previous:SetEnabled(page > 1) nextPage:SetEnabled(page < pages)
        self:Status(total > 0 and "Нажмите на иконку, чтобы выбрать предмет." or "Ничего не найдено. Измените поиск или категорию.")
        grid:InvalidateLayout(true) scroll:GetVBar():SetScroll(0)
    end
    search.OnChange = function() page = 1 frame:Refresh() end
    local selected = category.OnSelect
    category.OnSelect = function(...) selected(...) page = 1 frame:Refresh() end
    frame:Refresh()
    return frame
end

local function compactNumber(parent, label, row, key, low, high, decimals)
    local line = parent:Add("DPanel") line:Dock(TOP) line:SetTall(30) line.Paint = nil
    local name = line:Add("DLabel") name:Dock(LEFT) name:SetWide(118) name:SetText(label)
    local value = line:Add("DNumberWang") value:Dock(LEFT) value:SetWide(78)
    value:SetMinMax(low, high) value:SetDecimals(decimals or 0) value:SetValue(row[key])
    value.OnValueChanged = function(_, input) row[key] = math.Clamp(tonumber(input) or low, low, high) end
    return value
end

function Q:EditRewards(parent, reward, solo)
    if not solo then UI.Choice(parent, "Кому выдавать награду", reward, "mode", {each = "Каждому участнику", leader = "Только лидеру"}) end
    UI.Number(parent, "Деньги (0 — без денег)", reward, "money", 0, 1000000):SetDecimals(0)
    UI.Number(parent, "Опыт персонажа (0 — без опыта)", reward, "xp", 0, 1000000):SetDecimals(0)
    UI.Label(parent, "Предметы", true)
    UI.Label(parent, "100% — гарантированно; 0% — не выдавать. Шанс проверяется на всё количество строки отдельно для каждого получателя.")
    local items = parent:Add("DPanel") items:Dock(TOP) items.Paint = nil
    items.PerformLayout = function(s) s:SizeToChildren(false, true) end
    local function renderItems()
        items:Clear()
        for index, item in ipairs(reward.items) do
            item.chance = item.chance or 100
            local card = items:Add("DPanel") card:Dock(TOP) card:SetTall(112) card:DockMargin(0, 0, 0, 8)
            local icon = Q:RewardItemIcon(card, item.item, function()
                Q:PickRewardItem(function(id) if IsValid(items) then item.item = id renderItems() end end)
            end)
            icon:Dock(LEFT) icon:SetWide(112)
            local remove = UI.Button(card, "×", function() table.remove(reward.items, index) renderItems() end)
            remove:Dock(RIGHT) remove:SetWide(32) remove:SetTooltip("Убрать из награды")
            local controls = card:Add("DPanel") controls:Dock(FILL) controls:DockPadding(8, 8, 8, 4) controls.Paint = nil
            local definition = ix.Item:Get(item.item)
            local name = controls:Add("DLabel") name:Dock(TOP) name:SetTall(30)
            name:SetText(definition and L(definition.name) or item.item) name:SetTooltip(name:GetText())
            compactNumber(controls, "Количество", item, "count", 1, 100)
            compactNumber(controls, "Шанс, %", item, "chance", 0, 100, 2)
        end
        items:InvalidateLayout(true)
    end
    UI.Button(parent, "+ Предмет из каталога", function()
        if #reward.items >= 16 then notification.AddLegacy("В награде уже 16 строк предметов.", NOTIFY_ERROR, 5) return end
        Q:PickRewardItem(function(id)
            if not IsValid(items) or #reward.items >= 16 then return end
            reward.items[#reward.items + 1] = {item = id, count = 1, chance = 100} renderItems()
        end)
    end)
    renderItems()
    UI.Label(parent, "Опыт навыков", true)
    local choices, first = {}, nil
    for id, skill in SortedPairs(ix.skills and ix.skills.list or {}) do choices[id] = L(skill.name) first = first or id end
    local skills = parent:Add("DPanel") skills:Dock(TOP) skills.Paint = nil
    skills.PerformLayout = function(s) s:SizeToChildren(false, true) end
    local function renderSkills()
        skills:Clear()
        for index, skill in ipairs(reward.skills) do
            local card = skills:Add("DPanel") card:Dock(TOP) card:SetTall(116) card:DockMargin(0, 0, 0, 8)
            local remove = UI.Button(card, "×", function() table.remove(reward.skills, index) renderSkills() end)
            remove:Dock(RIGHT) remove:SetWide(32) remove:SetTooltip("Убрать навык из награды")
            local controls = card:Add("DPanel") controls:Dock(FILL) controls:DockPadding(8, 0, 8, 4) controls.Paint = nil
            UI.Choice(controls, "Навык", skill, "skill", choices)
            compactNumber(controls, "Опыт навыка", skill, "xp", 1, 100000)
        end
        skills:InvalidateLayout(true)
    end
    UI.Button(parent, "+ Опыт выбранного навыка", function()
        if not first or #reward.skills >= 16 then return end
        reward.skills[#reward.skills + 1] = {skill = first, xp = 100} renderSkills()
    end)
    renderSkills()
end
