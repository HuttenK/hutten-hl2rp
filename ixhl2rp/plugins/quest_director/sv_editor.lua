local Q = ix.questDirector
local function count(rows) local n = 0 for _ in pairs(rows) do n = n + 1 end return n end
function Q:ValidateDefinition(kind, row)
    if kind == "quest" then
        if row.npc == "" or not self.defs.npc[row.npc] then return false, "Выберите существующего квестодателя." end
        if #row.objectives == 0 then return false, "Добавьте хотя бы одну цель." end
        if row.pool ~= "" and not self.defs.pool[row.pool] then return false, "Пул не найден." end
        if row.prerequisite ~= "" and (row.prerequisite == row.id or not self.defs.quest[row.prerequisite]) then return false, "Неверное предыдущее задание." end
        local prior, seen = row.prerequisite, {[row.id] = true}
        while prior ~= "" do
            if seen[prior] then return false, "В цепочке заданий образовался цикл." end
            seen[prior] = true
            prior = self.defs.quest[prior] and self.defs.quest[prior].prerequisite or ""
        end
        if row.availableUntil > 0 and row.availableUntil <= row.availableFrom then return false, "Окончание выдачи должно быть позже начала." end
        for _, goal in ipairs(row.objectives) do
            if goal.target == "" then return false, "У каждой цели должна быть метка." end
            if goal.type == "deposit" and not ix.Item:Get(goal.item) then return false, "Предмет для передачи не найден." end
            if goal.check.skill ~= "" and not (ix.skills and ix.skills.list[goal.check.skill]) then return false, "Навык цели не найден." end
            if goal.check.stat ~= "" and not (ix.specials and ix.specials.list[goal.check.stat]) then return false, "Характеристика цели не найдена." end
        end
        for _, item in ipairs(row.reward.items) do if not ix.Item:Get(item.item) then return false, "Предмет награды не найден: " .. item.item end end
        for _, skill in ipairs(row.reward.skills) do if not (ix.skills and ix.skills.list[skill.skill]) then return false, "Навык награды не найден: " .. skill.skill end end
    elseif kind == "npc" then
        if not util.IsValidModel(row.model) then return false, "Модель отсутствует на сервере." end
        for _, node in ipairs(row.nodes) do
            for _, option in ipairs(node.options) do
                if option.action == "quest" and not self.defs.quest[option.quest] then return false, "Задание ответа не найдено." end
                if option.check.skill ~= "" and not (ix.skills and ix.skills.list[option.check.skill]) then return false, "Навык ответа не найден." end
                if option.check.stat ~= "" and not (ix.specials and ix.specials.list[option.check.stat]) then return false, "Характеристика ответа не найдена." end
            end
        end
    elseif kind == "object" then
        if not util.IsValidModel(row.model) then return false, "Модель отсутствует на сервере." end
        if row.target == "" then return false, "Объекту нужна метка цели." end
        if row.quest ~= "" and not self.defs.quest[row.quest] then return false, "Связанное задание не найдено." end
    end
    return true
end
function Q:Put(client, kind, raw)
    if self.storageFault then return false, "Хранилище заблокировано." end
    if not self.CanEdit(client) then return false, "Только для администрации." end
    local row, reason = self:Clean(kind, raw)
    if not row then return false, reason end
    local encoded = util.TableToJSON(row)
    if not encoded or #encoded > self.MAX_DEFINITION then return false, "Слишком большой шаблон." end
    local old = self.defs[kind][row.id]
    if row.id ~= "" and not old then return false, "Запись удалена. Для новой записи очистите ключ." end
    if old and row.revision ~= old.revision then return false, "Запись уже изменена другим редактором. Откройте заново." end
    if not old and count(self.defs[kind]) >= self.LIMITS[kind] then return false, "Достигнут лимит шаблонов." end
    if kind == "quest" and row.enabled and (not old or not old.enabled) and row.lifetime > 0 and row.availableUntil == 0 then
        row.availableUntil = math.max(os.time(), row.availableFrom) + row.lifetime
    end
    if row.enabled then local ok, err = self:ValidateDefinition(kind, row) if not ok then return false, err end end
    if row.id == "" then row.id = self:NewID(kind) end
    row.revision = (old and old.revision or 0) + 1
    self.defs[kind][row.id], self.availabilityCache = row, nil
    self:Log(client, "save " .. kind, row.id .. " revision " .. row.revision)
    if not self:Save() then return false, "Ошибка сохранения." end
    for _, entry in pairs(self.placements) do if entry.kind == kind and entry.definition == row.id then self:SpawnPlacement(entry) end end
    return true, row
end
function Q:DeleteDefinition(client, data)
    if self.storageFault then return false, "Хранилище заблокировано." end
    if not self.CanEdit(client) then return false, "Только для администрации." end
    local kind, id = data.kind, self.Key(data.id)
    local row = self.defs[kind] and self.defs[kind][id]
    if not row or row.revision ~= tonumber(data.revision) then return false, "Запись изменилась. Обновите список." end
    for _, entry in pairs(self.placements) do if entry.kind == kind and entry.definition == id then return false, "Сначала удалите размещения шаблона." end end
    for _, run in pairs(self.runs) do
        if (kind == "quest" and run.quest.id == id) or (kind == "npc" and run.quest.npc == id) then return false, "Шаблон используется активным заданием." end
        for _, goal in ipairs(run.quest.objectives) do if kind == "object" and self:ObjectMatchesGoal(row, run.quest.id, goal) then return false, "Объект нужен активному заданию." end end
    end
    for _, state in pairs(self.states) do
        for _, receipt in pairs(state.receipts) do if kind == "npc" and receipt.npc == id and receipt.status ~= "claimed" then return false, "У NPC остались невыданные награды." end end
    end
    for _, quest in pairs(self.defs.quest) do
        if (kind == "npc" and quest.npc == id) or (kind == "pool" and quest.pool == id) or (kind == "quest" and quest.prerequisite == id) then return false, "Шаблон используется другим заданием." end
    end
    if kind == "quest" then
        for _, npc in pairs(self.defs.npc) do for _, node in ipairs(npc.nodes) do for _, option in ipairs(node.options) do if option.quest == id then return false, "Задание используется ответом NPC." end end end end
        for _, object in pairs(self.defs.object) do if object.quest == id then return false, "Задание связано с объектом." end end
    end
    self.defs[kind][id], self.availabilityCache = nil, nil
    self:Log(client, "delete " .. kind, id) self:Save()
    return true, "Шаблон удалён."
end
function Q:PlacementView(entry)
    local row = self.defs[entry.kind][entry.definition]
    return {id = entry.id, kind = entry.kind, definition = entry.definition, label = row.name, enabled = row.enabled, pos = entry.pos}
end
function Q:TracePlacement(client)
    local trace = client:GetEyeTrace()
    if not trace.Hit or trace.HitSky or not util.IsInWorld(trace.HitPos) or client:EyePos():DistToSqr(trace.HitPos) > 4096 ^ 2 then return nil, "Наведитесь на поверхность в пределах 4096 единиц." end
    local pos = trace.HitPos + trace.HitNormal * 4
    local angle = Angle(0, client:EyeAngles().y + 180, 0)
    return {pos.x, pos.y, pos.z}, {angle.p, angle.y, angle.r}
end
function Q:Place(client, kind, id)
    if self.storageFault then return false, "Хранилище заблокировано." end
    if not self.CanEdit(client) then return false, "Только для администрации." end
    local row = (kind == "npc" or kind == "object") and self.defs[kind][self.Key(id)]
    if not row then return false, "Шаблон не найден." end
    if count(self.placements) >= 512 then return false, "Достигнут лимит 512 размещений." end
    local pos, ang = self:TracePlacement(client)
    if not pos then return false, ang end
    local entry = {id = self:NewID("place"), kind = kind, definition = row.id, pos = pos, ang = ang}
    self.placements[entry.id] = entry
    self:Log(client, "place", entry.id) self:Save()
    self:SpawnPlacement(entry)
    return true, self:PlacementView(entry)
end
function Q:RemovePlacement(client, id)
    if not self.CanEdit(client) or self.storageFault then return false, "Только для администрации; проверьте сохранение." end
    if not self.placements[self.Key(id)] then return false, "Размещение не найдено." end
    self.placements[id] = nil
    self:Log(client, "unplace", id)
    if not self:Save() then return false, "Ошибка сохранения." end
    if IsValid(self.entities[id]) then self.entities[id]:Remove() end
    self.entities[id] = nil
    return true, "Размещение удалено."
end
function Q:Overview(id)
    local quest = self.defs.quest[self.Key(id)]
    if not quest then return false, "Задание не найдено." end
    local view = {id = id, name = quest.name, description = quest.description, enabled = quest.enabled, revision = quest.revision, ordered = quest.ordered, goals = {}, issues = {}}
    local function placed(kind, definition)
        local n = 0 for _, entry in pairs(Q.placements) do if entry.kind == kind and entry.definition == definition then n = n + 1 end end return n
    end
    local npc = self.defs.npc[quest.npc]
    if npc then view.npc = {id = npc.id, name = npc.name, enabled = npc.enabled, placed = placed("npc", npc.id)} end
    if not npc or not npc.enabled or placed("npc", quest.npc) == 0 then view.issues[#view.issues + 1] = "Разместите и включите квестодателя." end
    if not quest.enabled then view.issues[#view.issues + 1] = "Выдача задания выключена." end
    for _, goal in ipairs(quest.objectives) do
        local row = {id = goal.id, type = goal.type, name = goal.name, count = goal.count, ready = false, objects = {}, hint = "Метка: " .. goal.target}
        if self:IsObjectGoal(goal) then
            for _, object in pairs(self.defs.object) do
                if self:ObjectMatchesGoal(object, quest.id, goal) then
                    local n = placed("object", object.id)
                    row.objectCount = (row.objectCount or 0) + 1
                    if #row.objects < 8 then row.objects[#row.objects + 1] = {id = object.id, name = object.name, enabled = object.enabled, placed = n} end
                    row.ready = row.ready or (object.enabled and n > 0)
                end
            end
        elseif goal.type == "zone" then
            for _, zone in pairs(self.zones) do if zone.target == goal.target then row.ready = true end end
            row.hint = row.hint .. ". Создайте сферическую зону в разделе размещений."
        elseif goal.type == "dialogue" and npc then
            for _, node in ipairs(npc.nodes) do for _, option in ipairs(node.options) do
                if option.action == "event" and option.target == goal.target and (option.quest == "" or option.quest == quest.id) then row.ready = true end
            end end
        end
        view.goals[#view.goals + 1] = row
    end
    return true, view
end
function Q:GoalObject(client, data)
    local quest = self.defs.quest[self.Key(data.id)]
    if not quest or quest.revision ~= tonumber(data.revision) then return false, "Задание изменилось." end
    for _, goal in ipairs(quest.objectives) do
        if goal.id == data.goal and self:IsObjectGoal(goal) then
            return self:Put(client, "object", {name = goal.name, target = goal.target, quest = quest.id, category = quest.category, enabled = true, model = "models/props_junk/wood_crate001a.mdl"})
        end
    end
    return false, "Объектная цель не найдена."
end
function Q:CreateSimple(client, data)
    if self.storageFault then return false, "Хранилище заблокировано." end
    if not self.CanEdit(client) then return false, "Только для администрации." end
    -- Validate all prospective templates before changing any store; create as one snapshot.
    if count(self.defs.quest) >= self.LIMITS.quest or count(self.defs.object) >= self.LIMITS.object or (self.Key(data.npc) == "" and count(self.defs.npc) >= self.LIMITS.npc) then return false, "Достигнут лимит шаблонов." end
    local npc = self.defs.npc[self.Key(data.npc)]
    local newNPC = not npc
    local reason
    if newNPC then
        npc, reason = self:Clean("npc", {name = data.npcName or "Квестодатель", model = data.npcModel or "models/Humans/Group01/male_07.mdl", category = data.category,
            enabled = true, start = "start", nodes = {{id = "start", text = "Есть работа. Выберите задание, а после выполнения возвращайтесь ко мне.", options = {{text = "До встречи.", action = "close"}}}}})
        if not npc then return false, reason end
        npc.id, npc.revision = self:NewID("npc"), 1
        if not util.IsValidModel(npc.model) then return false, "Модель NPC не найдена." end
    end
    local questID = self:NewID("quest")
    local target = questID .. "_inspect"
    local quest
    quest, reason = self:Clean("quest", {name = data.name, description = data.description, category = data.category, npc = npc.id, enabled = true,
        objectives = {{id = "inspect", name = data.goalName or "Осмотреть ящик", type = "use", target = target, count = 1}}, reward = data.reward})
    if not quest then return false, reason end
    quest.id, quest.revision = questID, 1
    local object
    object, reason = self:Clean("object", {name = data.objectName or "Квестовый ящик", model = data.objectModel or "models/props_junk/wood_crate001a.mdl", target = target, quest = questID, category = quest.category, enabled = true})
    if not object then return false, reason end
    if not util.IsValidModel(object.model) then return false, "Модель объекта не найдена." end
    for _, item in ipairs(quest.reward.items) do if not ix.Item:Get(item.item) then return false, "Предмет награды не найден." end end
    for _, skill in ipairs(quest.reward.skills) do if not (ix.skills and ix.skills.list[skill.skill]) then return false, "Навык награды не найден." end end
    object.id, object.revision = self:NewID("object"), 1
    if newNPC then self.defs.npc[npc.id] = npc end
    self.defs.quest[quest.id], self.defs.object[object.id] = quest, object
    self.availabilityCache = nil
    self:Log(client, "create simple quest", quest.id)
    if not self:Save() then return false, "Ошибка сохранения." end
    return true, quest.id
end
function Q:EnsureQuickExamples(client)
    if not self.CanEdit(client) then return false, "Только для администрации." end
    for _, quest in pairs(self.defs.quest) do if quest.category == "qd_test_v2_" then return true, "Пример уже существует. Найдите категорию qd_test_v2_." end end
    local ok, result = self:CreateSimple(client, {name = "1. Осмотреть ящик", category = "qd_test_v2_", npcName = "Координатор испытаний",
        description = "Примите задание, осмотрите ящик клавишей E и вернитесь к координатору. Пример не выдаёт материальных наград.", goalName = "Осмотреть тестовый ящик"})
    return ok, ok and "Пример создан. Разместите NPC и ящик через схему задания." or result
end
function Q:AdminReputation(client, data)
    if not self.CanEdit(client) or self.storageFault then return false, "Изменения недоступны." end
    if data.list then
        local view = {players = {}}
        for _, other in ipairs(player.GetAll()) do local char = other:GetCharacter() if char then view.players[#view.players + 1] = {character = char:GetID(), name = char:GetName()} end end
        return true, view
    end
    local other, npc = self:Player(tonumber(data.character)), self.defs.npc[self.Key(data.npc)]
    if not IsValid(other) or not npc or not npc.reputation.enabled then return false, "Нужны персонаж онлайн и NPC с репутацией." end
    local state = self:State(other:GetCharacter():GetID())
    local value = self:ReputationValue(state, npc)
    if data.set then
        if npc.revision ~= tonumber(data.revision) or value ~= tonumber(data.expected) then return false, "Репутация изменилась. Загрузите заново." end
        if not isstring(data.reason) or #string.Trim(data.reason) < 3 or #data.reason > 400 then return false, "Укажите причину (3–400 байт)." end
        state.reputation[npc.id] = math.floor(self.Number(data.value, value, npc.reputation.minimum, npc.reputation.maximum))
        self:Log(client, "reputation", data.character .. " " .. npc.id .. " " .. value .. " -> " .. state.reputation[npc.id] .. " " .. data.reason)
        self:Save()
    end
    local view = self:ReputationView(state, npc)
    view.character, view.revision = other:GetCharacter():GetID(), npc.revision
    return true, view
end
function Q:AdminList(data)
    local rows, kind = {}, data.kind
    local search = isstring(data.search) and data.search:sub(1, 160):lower() or ""
    if self.defs[kind] then
        for _, row in pairs(self.defs[kind]) do rows[#rows + 1] = {id = row.id, name = row.name, category = row.category, enabled = row.enabled, revision = row.revision, status = row.enabled and "включено" or "выключено"} end
    elseif kind == "runs" then for _, run in pairs(self.runs) do rows[#rows + 1] = {id = run.id, name = run.quest.name, category = "Лидер #" .. run.leader, status = run.deposit and "Передача требует проверки" or "В процессе"} end
    elseif kind == "receipts" then for cid, state in pairs(self.states) do for _, receipt in pairs(state.receipts) do
        if receipt.status ~= "claimed" then rows[#rows + 1] = {id = receipt.id, name = receipt.name, category = "Персонаж #" .. cid, status = receipt.status .. " · шаг " .. receipt.cursor, cursor = receipt.cursor} end
    end end
    elseif kind == "audit" then rows = table.Copy(self.audit)
    else return false, "Неизвестный список." end
    local filtered = {}
    for _, row in ipairs(rows) do if search == "" or ((row.name or row.action or "") .. " " .. (row.category or "") .. " " .. (row.id or "")):lower():find(search, 1, true) then filtered[#filtered + 1] = row end end
    table.sort(filtered, function(a, b) return tostring(a.id or a.time) < tostring(b.id or b.time) end)
    local page = math.floor(self.Number(data.page, 1, 1, math.max(1, math.ceil(#filtered / 40))))
    local result = {rows = {}, total = #filtered}
    for i = (page - 1) * 40 + 1, math.min(page * 40, #filtered) do result.rows[#result.rows + 1] = filtered[i] end
    return true, result
end
function Q:AdminReceipt(client, data)
    if not self.CanEdit(client) or self.storageFault then return false, "Изменения недоступны." end
    for _, state in pairs(self.states) do
        local receipt = state.receipts[self.Key(data.receipt)]
        if receipt then
            if receipt.status ~= "applying" or self.claiming[receipt.id] or receipt.cursor ~= tonumber(data.cursor) then return false, "Шаг изменился или ещё сохраняется. Обновите список." end
            if data.delivered == true then receipt.cursor = receipt.cursor + 1 receipt.pendingItem = nil end
            receipt.status = receipt.cursor > #receipt.steps and "claimed" or "pending"
            self:Log(client, "resolve receipt", receipt.id .. " delivered=" .. tostring(data.delivered)) self:Save()
            return true, "Решение записано."
        end
    end
    return false, "Награда не найдена."
end
