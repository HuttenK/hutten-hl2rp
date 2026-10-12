local Q, UI = ix.questDirector, ix.questDirector.ui

local function slider(parent, title, value, low, high, decimals, changed)
    local holder = parent:Add("DPanel") holder:Dock(TOP) holder:SetTall(56) holder.Paint = nil
    local label = holder:Add("DLabel") label:Dock(TOP) label:SetTall(22)
    label:SetText(title) label:SetTextColor(color_white) label:SetTooltip(title)
    local input = holder:Add("DNumSlider") input:Dock(TOP) input:SetTall(28)
    input:SetText("") input:SetMinMax(low, high) input:SetDecimals(decimals)
    input.PerformLayout = function(s) s.Label:SetWide(0) end
    input:SetValue(math.Clamp(value or 0, low, high))
    input:SetEnabled(high > low)
    input.OnValueChanged = function(s, number)
        local value = math.Clamp(math.Round(tonumber(number) or low, decimals), low, high)
        if math.abs(s:GetValue() - value) > 0.00001 then s:SetValue(value) end
        changed(value)
    end
    return input, holder
end

-- A fixed-height searchable list: even models with thousands of sequences do
-- not stretch the editor or allocate thousands of rows on each keystroke.
local function animationPicker(parent, row, key, changed, automatic)
    local current = UI.Label(parent, "") current:SetTall(42)
    local search = parent:Add("DTextEntry") search:Dock(TOP) search:SetTall(29)
    search:DockMargin(0, 0, 0, 5) search:SetPlaceholderText("Поиск анимации: idle, sit, walk…")
    local count = parent:Add("DLabel") count:Dock(TOP) count:SetTall(23) count:SetTextColor(color_white)
    local list = parent:Add("DListView") list:Dock(FILL) list:SetMultiSelect(false)
    list:AddColumn("Анимация — нажмите для выбора")
    local names, rebuilding = {}, false
    local function updateCurrent()
        current:SetText("Выбрано: " .. (row[key] == "auto" and "Автоматический жест модели" or row[key] ~= "" and row[key] or "Нет анимаций"))
    end
    local function fill()
        search.refreshAt = nil
        rebuilding = true
        list:Clear()
        local query = string.Trim(search:GetValue()):lower()
        local total, shown = 0, 0
        for _, name in ipairs(names) do
            local title = name == "auto" and "Автоматический жест модели" or name
            if (title .. " " .. name):lower():find(query, 1, true) then
                total = total + 1
                if shown < 250 then
                    local line = list:AddLine(title) line.sequence = name line:SetTooltip(name)
                    if name == row[key] then list:SelectItem(line) end
                    shown = shown + 1
                end
            end
        end
        count:SetText(total > shown and ("Показано " .. shown .. " из " .. total .. ". Уточните поиск.") or ("Найдено: " .. total))
        rebuilding = false
        updateCurrent()
    end
    search.OnChange = function(s) s.refreshAt = RealTime() + 0.12 end
    search.OnEnter = fill
    search.Think = function(s) if s.refreshAt and s.refreshAt <= RealTime() then fill() end end
    list.OnRowSelected = function(_, _, line)
        if rebuilding then return end
        row[key] = line.sequence
        updateCurrent()
        changed(line.sequence)
    end
    return function(sequences)
        names = table.Copy(sequences)
        table.sort(names)
        if automatic then table.insert(names, 1, "auto") end
        fill()
    end
end

local function resetBounds(preview)
    preview.fitMinimum, preview.fitMaximum = nil, nil
end

local function fitModel(preview, entity)
    local minimum, maximum = entity:GetRenderBounds()
    -- Grow the bounds during playback so breathing and gestures do not make
    -- the camera pump in and out. A new pose/model starts a fresh fit.
    local low, high = preview.fitMinimum or minimum, preview.fitMaximum or maximum
    minimum = Vector(math.min(low.x, minimum.x), math.min(low.y, minimum.y), math.min(low.z, minimum.z))
    maximum = Vector(math.max(high.x, maximum.x), math.max(high.y, maximum.y), math.max(high.z, maximum.z))
    preview.fitMinimum, preview.fitMaximum = minimum, maximum
    local centre = entity:LocalToWorld((minimum + maximum) * 0.5)
    local radius = math.max((maximum - minimum):Length() * 0.5, 1)
    local horizontal = math.rad(38) * 0.5
    local aspect = math.max(preview:GetWide(), 1) / math.max(preview:GetTall(), 1)
    local vertical = math.atan(math.tan(horizontal) / aspect)
    -- Fit a bounding sphere against BOTH view angles. DModelPanel's FOV is
    -- horizontal: using only model height clips a wide/short viewport.
    local distance = radius * 1.12 / math.sin(math.min(horizontal, vertical)) / preview.zoom
    preview:SetFOV(38) preview:SetLookAng(nil)
    preview:SetLookAt(centre) preview:SetCamPos(centre + Vector(distance, 0, 0))
    preview.FarZ = math.max(4096, distance + radius * 2 + 100)
end

function Q:EditNPCAppearance(sheet, row)
    local look = vgui.Create("DPanel", sheet)
    look:DockPadding(10, 8, 10, 8) look.Paint = nil
    sheet:AddSheet("Внешность и поза", look)
    local header = look:Add("DPanel") header:Dock(TOP) header:SetTall(106) header.Paint = nil
    local modelInput = UI.Text(header, "Путь модели — обновляется автоматически", row, "model")
    local status = header:Add("DLabel") status:Dock(TOP) status:SetTall(30) status:SetWrap(true)
    local body = look:Add("DPanel") body:Dock(FILL) body.Paint = nil
    local viewport = body:Add("DPanel") viewport:Dock(LEFT) viewport:DockMargin(0, 0, 10, 0)
    viewport:SetWide(370) viewport.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(27, 33, 39)) end
    local hint = viewport:Add("DLabel") hint:Dock(BOTTOM) hint:SetTall(38) hint:SetWrap(true)
    hint:DockMargin(8, 0, 8, 0) hint:SetTextColor(color_white)
    hint:SetText("Зажмите ЛКМ — поворот. Колесо — масштаб.")
    local preview
    local reset = UI.Button(viewport, "Показать целиком", function()
        preview.yaw, preview.zoom = 15, 1 resetBounds(preview)
    end)
    reset:Dock(BOTTOM) reset:SetTall(30) reset:DockMargin(8, 4, 8, 4)
    preview = viewport:Add("DModelPanel") preview:Dock(FILL)
    preview.yaw, preview.zoom = 15, 1
    preview:SetCursor("sizewe")
    preview.OnMousePressed = function(s, button)
        if button ~= MOUSE_LEFT then return end
        s.dragX = gui.MouseX() s:MouseCapture(true)
    end
    preview.OnMouseReleased = function(s, button)
        if button ~= MOUSE_LEFT then return end
        s.dragX = nil s:MouseCapture(false)
    end
    preview.OnCursorMoved = function(s)
        if not s.dragX then return end
        local x = gui.MouseX() s.yaw = (s.yaw + (x - s.dragX) * 0.6) % 360 s.dragX = x
    end
    preview.OnMouseWheeled = function(s, delta)
        s.zoom = math.Clamp(s.zoom * (1.12 ^ delta), 0.4, 2.5)
        return true
    end
    body.PerformLayout = function(s, w)
        local width = math.max(180, math.floor(w * 0.4))
        if viewport:GetWide() ~= width then viewport:SetWide(width) end
    end
    local settings = body:Add("DPropertySheet") settings:Dock(FILL) settings:SetFadeTime(0)
    local function tab(title, scroll)
        local panel = vgui.Create(scroll and "DScrollPanel" or "DPanel", settings)
        panel:DockPadding(8, 8, 8, 8) panel.Paint = nil
        settings:AddSheet(title, panel)
        return panel
    end
    local appearance = tab("Внешность", true)
    local pose = tab("Поза")
    local gestures = tab("Жесты")
    local parameters = tab("Параметры", true)
    local play = UI.Bool(pose, "Проигрывать выбранную анимацию", row, "animate")
    local cycle = slider(pose, "Кадр остановленной позы", row.cycle, 0, 1, 2, function(value)
        row.cycle = value resetBounds(preview)
    end)
    cycle:SetEnabled(not row.animate)
    play.OnChange = function(_, value) row.animate = value cycle:SetEnabled(not value) end
    local updatePoses = animationPicker(pose, row, "sequence", function(name)
        local entity = preview:GetEntity()
        if IsValid(entity) then entity:ResetSequence(name) entity:SetCycle(row.cycle) end
        preview.gestureUntil = nil resetBounds(preview)
    end)
    UI.Bool(gestures, "Жестикуляция при репликах NPC", row, "talk")
    local function playGesture()
        local entity = preview:GetEntity()
        if not IsValid(entity) then return end
        local sequence = row.talkSequence == "auto" and entity:SelectWeightedSequence(ACT_GMOD_GESTURE_ITEM_GIVE) or entity:LookupSequence(row.talkSequence)
        if row.talkSequence == "auto" and sequence < 0 then
            for _, name in ipairs({"gesture_item_give", "gesture_hello", "gesture_disagree", "gesture_wave"}) do
                sequence = entity:LookupSequence(name)
                if sequence >= 0 then break end
            end
        end
        if sequence < 0 then status:SetText("У модели нет автоматического жеста. Выберите анимацию из списка.") return end
        entity:ResetSequence(sequence) entity:SetCycle(0)
        preview.gestureUntil = RealTime() + math.max(1, entity:SequenceDuration(sequence))
        resetBounds(preview)
    end
    UI.Button(gestures, "Проиграть жест в предпросмотре", playGesture):SetTall(30)
    local updateGestures = animationPicker(gestures, row, "talkSequence", playGesture, true)

    local function message(text, bad)
        status:SetText(text) status:SetTextColor(bad and Color(255, 170, 145) or Color(190, 220, 205))
        preview:SetAlpha(bad and 110 or 255)
    end
    local function modelPath()
        return string.Trim(modelInput:GetValue()):gsub("\\", "/"):lower()
    end
    local function setup(force)
        modelInput.previewAt = nil
        local model = modelPath()
        row.model = model
        if not model:match("^models/.+%.mdl$") or model:find("..", 1, true) then
            message("Нужен путь models/… .mdl. Предпросмотр пока не обновлён.", true) return
        end
        -- Client util.IsValidModel can reject models that have not been loaded
        -- yet. Check mounted content before asking DModelPanel to load it.
        if not file.Exists(model, "GAME") then
            message("Модель не найдена в файлах игры. Предпросмотр пока не обновлён.", true) return
        end
        if not force and preview.loadedModel == model and IsValid(preview:GetEntity()) then
            message("Модель загружена. Изменения видны сразу; сохранение — кнопкой внизу.") return
        end
        preview:SetModel(model)
        local entity = preview:GetEntity()
        if not IsValid(entity) then message("Не удалось загрузить модель. Проверьте путь и установленный контент.", true) return end
        preview.loadedModel, preview.zoom, preview.gestureUntil = model, 1, nil
        resetBounds(preview)
        local names, known = entity:GetSequenceList() or {}, {}
        for _, name in ipairs(names) do known[name] = true end
        if not known[row.sequence] then
            local idle = entity:LookupSequence("idle_all_01")
            if idle < 0 then idle = entity:SelectWeightedSequence(ACT_IDLE) end
            row.sequence = entity:GetSequenceName(math.max(idle, 0)) or names[1] or ""
        end
        if row.talkSequence ~= "auto" and not known[row.talkSequence] then row.talkSequence = "auto" end
        entity:ResetSequence(row.sequence) entity:SetCycle(row.cycle)
        appearance:Clear() parameters:Clear()
        row.skin = math.Clamp(row.skin, 0, math.max(0, entity:SkinCount() - 1))
        entity:SetSkin(row.skin)
        slider(appearance, "Скин", row.skin, 0, math.max(0, entity:SkinCount() - 1), 0, function(value)
            row.skin = value entity:SetSkin(value)
        end)
        local groupSearch = appearance:Add("DTextEntry") groupSearch:Dock(TOP) groupSearch:SetTall(28)
        groupSearch:DockMargin(0, 4, 0, 8) groupSearch:SetPlaceholderText("Поиск бодигруппы")
        local groupRows, groups = {}, {}
        for _, group in ipairs(entity:GetBodyGroups()) do
            if group.num > 1 then
                local id = tostring(group.id)
                groups[id] = math.Clamp(row.bodygroups[id] or 0, 0, group.num - 1)
                entity:SetBodygroup(group.id, groups[id])
                local _, holder = slider(appearance, group.name .. " (0–" .. (group.num - 1) .. ")", groups[id], 0, group.num - 1, 0, function(value)
                    row.bodygroups[id] = value entity:SetBodygroup(group.id, value) resetBounds(preview)
                end)
                groupRows[#groupRows + 1] = {name = group.name:lower(), panel = holder}
            end
        end
        row.bodygroups = groups
        groupSearch.OnChange = function(s)
            local query = string.Trim(s:GetValue()):lower()
            for _, group in ipairs(groupRows) do group.panel:SetVisible(group.name:find(query, 1, true) ~= nil) end
            appearance:InvalidateLayout(true)
        end
        if #groupRows == 0 then UI.Label(appearance, "У этой модели нет изменяемых бодигрупп.") end
        local values = {}
        for i = 0, entity:GetNumPoseParameters() - 1 do
            local name = entity:GetPoseParameterName(i)
            local low, high = entity:GetPoseParameterRange(i)
            values[name] = math.Clamp(row.pose[name] or 0, low, high)
            entity:SetPoseParameter(name, values[name])
            slider(parameters, name, values[name], low, high, 2, function(value)
                row.pose[name] = value entity:SetPoseParameter(name, value) resetBounds(preview)
            end)
        end
        row.pose = values
        if entity:GetNumPoseParameters() == 0 then UI.Label(parameters, "У этой модели нет дополнительных параметров позы.") end
        updatePoses(names) updateGestures(names)
        message("Модель загружена. Изменения видны сразу; сохранение — кнопкой внизу.")
    end
    modelInput.OnChange = function(s)
        row.model = modelPath() s.previewAt = RealTime() + 0.35
        message("Обновление предпросмотра…")
    end
    modelInput.OnEnter = function() setup(true) end
    modelInput.Think = function(s) if s.previewAt and s.previewAt <= RealTime() then setup() end end
    preview.LayoutEntity = function(s, entity)
        entity:SetAngles(Angle(0, s.yaw, 0))
        if (s.gestureUntil or 0) > RealTime() then s:RunAnimation()
        else
            if s.gestureUntil then s.gestureUntil = nil resetBounds(s) end
            local sequence = entity:LookupSequence(row.sequence)
            if sequence >= 0 and entity:GetSequence() ~= sequence then entity:ResetSequence(sequence) end
            if row.animate then s:RunAnimation() else entity:SetCycle(row.cycle) end
        end
        fitModel(s, entity)
    end
    setup()
    return setup
end
