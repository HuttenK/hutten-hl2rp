ix.questDirector = ix.questDirector or {}
local Q = ix.questDirector
-- This fork silently discards unregistered SetNetVar keys. Register in the same
-- order on both realms, without allocating new IDs during Lua refresh.
if ix.Net and ix.Net.AddEntityVar then
    for _, key in ipairs({"questPlacement", "questDefinition", "questCategory", "questLabel", "questEnabled"}) do
        if not ix.Net.vars[3][key] then
            ix.Net:AddEntityVar(key, nil, key == "questEnabled" and ix.Net.Type.Bool or ix.Net.Type.String)
        end
    end
end
Q.VERSION = 1
Q.RANGE = 192
Q.GROUP_RANGE = 384
Q.MAX_ACTIVE = 2
Q.MAX_PACKET = 60000
Q.MAX_DEFINITION = 44000
Q.LIMITS = {npc = 128, quest = 512, pool = 64, object = 512}
Q.BLOCKED_GROUP = "Вы не можете взяться за выполнение задания. Один/несколько игроков недавно выполнили задачу"
Q.TYPES = {use = "Взаимодействие (E)", deposit = "Положить предметы в объект", damage = "Нанести урон объекту", zone = "Посетить зону", dialogue = "Действие в диалоге"}
Q.ACTIONS = {goto_node = "Перейти к реплике", quest = "Открыть задание / группу", event = "Выполнить цель", finish = "Сдать задание", close = "Завершить разговор"}

function Q:IsObjectGoal(goal)
    return goal.type == "use" or goal.type == "deposit" or goal.type == "damage"
end

function Q:ObjectMatchesGoal(object, questID, goal)
    return self:IsObjectGoal(goal) and goal.target ~= "" and object.target == goal.target
        and (object.quest == "" or object.quest == questID)
end

function Q.CanEdit(client)
    -- Live role check also protects direct callbacks after demotion.
    return IsValid(client) and (client:IsAdmin() or client:IsSuperAdmin())
end

function Q.Number(value, default, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then value = default end
    return math.Clamp(value, low, high)
end

function Q.Key(value)
    return isstring(value) and #value <= 64 and value:match("^[%w_%-%.]*$") and value or ""
end

local function str(value, max, default)
    return isstring(value) and #value <= max and value or (default or "")
end
local function num(value, default, low, high) return Q.Number(value, default, low, high) end
local function list(value, limit)
    if not istable(value) then return {} end
    local count = 0
    for k in pairs(value) do
        count = count + 1
        if not isnumber(k) or k % 1 ~= 0 or k < 1 or k > limit then return nil end
    end
    if count ~= #value or count > limit then return nil end
    return value
end
local function model(value, fallback)
    value = str(value, 200, fallback):lower()
    return value:match("^models/[%w_/%-%. ]+%.mdl$") and not value:find("..", 1, true) and value or fallback
end

function Q:CleanCheck(raw)
    raw = istable(raw) and raw or {}
    return {mode = raw.mode == "roll" and "roll" or "threshold", skill = self.Key(raw.skill), stat = self.Key(raw.stat),
        skillWeight = num(raw.skillWeight, 1, 0, 100), statWeight = num(raw.statWeight, 1, 0, 100),
        difficulty = num(raw.difficulty, 0, 0, 10000), retry = num(raw.retry, 30, 1, 86400)}
end

function Q:CleanReputationGate(raw)
    raw = istable(raw) and raw or {}
    return {required = raw.required == true, minimum = math.floor(num(raw.minimum, 0, -100000, 100000))}
end

function Q:CleanPortrait(raw)
    raw = istable(raw) and raw or {}
    return {head = raw.head ~= false, x = num(raw.x, 0, -512, 512), y = num(raw.y, 0, -512, 512),
        z = num(raw.z, 0, -512, 512), distance = num(raw.distance, 52, 8, 1024),
        yaw = num(raw.yaw, 0, -180, 180), pitch = num(raw.pitch, 0, -80, 80), fov = num(raw.fov, 28, 10, 80)}
end

function Q:CleanReputation(raw)
    raw = istable(raw) and raw or {}
    local out = {enabled = raw.enabled == true, minimum = math.floor(num(raw.minimum, -100, -100000, 100000)),
        maximum = math.floor(num(raw.maximum, 100, -100000, 100000)), tiers = {}}
    if out.maximum <= out.minimum then return nil, "Максимум репутации должен быть больше минимума." end
    out.initial = math.floor(num(raw.initial, 0, out.minimum, out.maximum))
    local rows = list(raw.tiers, 16)
    if not rows then return nil, "Не больше 16 уровней репутации." end
    if #rows == 0 then rows = {{name = "Репутация", value = out.minimum}} end
    local seen = {}
    for _, tier in ipairs(rows) do
        if not istable(tier) then return nil, "Некорректный уровень репутации." end
        local value = math.floor(num(tier.value, out.minimum, out.minimum, out.maximum))
        if seen[value] then return nil, "Пороги уровней репутации должны различаться." end
        seen[value] = true
        out.tiers[#out.tiers + 1] = {value = value, name = str(tier.name, 100, "Репутация")}
    end
    table.sort(out.tiers, function(a, b) return a.value < b.value end)
    if out.tiers[1].value ~= out.minimum then return nil, "Первый уровень репутации должен начинаться с минимума шкалы." end
    return out
end

function Q:ReputationValue(state, npc, policy)
    policy = policy or npc.reputation
    local stored = (state.reputation or {})[npc.id]
    return math.floor(self.Number(stored, policy.initial, policy.minimum, policy.maximum))
end

function Q:ReputationView(state, npc)
    local policy = npc.reputation
    if not policy or not policy.enabled then return nil end
    local value = self:ReputationValue(state, npc)
    local tier, nextTier = policy.tiers[1], nil
    for _, row in ipairs(policy.tiers) do
        if value >= row.value then tier = row else nextTier = row break end
    end
    return {npc = npc.id, name = npc.name, value = value, minimum = policy.minimum, maximum = policy.maximum,
        tier = tier and tier.name or "Репутация", nextValue = nextTier and nextTier.value, nextTier = nextTier and nextTier.name}
end

function Q:ReputationAllowed(state, npc, gate)
    if not gate or not gate.required then return true end
    if not npc or not npc.reputation or not npc.reputation.enabled then return false, "Квестодатель пока не использует репутацию." end
    local value = self:ReputationValue(state, npc)
    if value < gate.minimum then return false, "Недостаточно доверия: нужно " .. gate.minimum .. ", у вас " .. value .. "." end
    return true
end

function Q:Clean(kind, raw)
    if not self.LIMITS[kind] or not istable(raw) then return nil, "Неизвестный тип записи." end
    if isstring(raw.name) and #raw.name > 160 then return nil, "Слишком длинное название (максимум 160 байт UTF-8)." end
    if isstring(raw.category) and #raw.category > 100 then return nil, "Слишком длинная категория (максимум 100 байт UTF-8)." end
    if (kind == "npc" or kind == "object") and raw.model ~= nil and not model(raw.model) then return nil, "Некорректный путь .mdl-модели." end
    local out = {id = self.Key(raw.id), name = str(raw.name, 160, "Новая запись"), category = str(raw.category, 100),
        enabled = raw.enabled == true, revision = math.floor(num(raw.revision, 0, 0, 2147483647))}
    if kind == "quest" then
        if isstring(raw.description) and #raw.description > 4000 then return nil, "Слишком длинное описание (максимум 4000 байт UTF-8)." end
        out.npc = self.Key(raw.npc)
        out.description = str(raw.description, 4000)
        out.pool = self.Key(raw.pool)
        out.prerequisite = self.Key(raw.prerequisite)
        out.repeatable = raw.repeatable ~= false
        out.dialogueOnly = raw.dialogueOnly == true
        out.ordered = raw.ordered ~= false
        out.lockParticipants = raw.lockParticipants ~= false
        out.requireTogether = raw.requireTogether == true
        out.reputation = self:CleanReputationGate(raw.reputation)
        local reputation = istable(raw.reputation) and raw.reputation or {}
        out.reputation.success = math.floor(num(reputation.success, 0, -100000, 100000))
        out.reputation.failure = math.floor(num(reputation.failure, 0, -100000, 100000))
        out.reputation.mode = reputation.mode == "leader" and "leader" or "each"
        out.minMembers = math.floor(num(raw.minMembers, 1, 1, 8))
        out.maxMembers = math.floor(num(raw.maxMembers, 1, out.minMembers, 8))
        for _, key in ipairs({"duration", "successCooldown", "failureCooldown", "nextDelay", "lifetime"}) do
            out[key] = math.floor(num(raw[key], 0, 0, 31536000))
        end
        out.availableFrom = math.floor(num(raw.availableFrom, 0, 0, 4102444800))
        out.availableUntil = math.floor(num(raw.availableUntil, 0, 0, 4102444800))
        out.objectives = {}
        local rows = list(raw.objectives, 32)
        if not rows then return nil, "Не больше 32 целей." end
        local seen = {}
        for i, row in ipairs(rows) do
            if not istable(row) then return nil, "Повреждённая цель." end
            local id = self.Key(row.id)
            if id == "" or seen[id] then return nil, "У каждой цели нужен уникальный ключ." end
            if not self.TYPES[row.type] then return nil, "Неизвестный тип цели." end
            seen[id] = true
            out.objectives[i] = {id = id, name = str(row.name, 200, id), type = row.type, target = str(row.target, 100),
                count = math.floor(num(row.count, 1, 1, 1000000)), item = self.Key(row.item), weapon = self.Key(row.weapon),
                check = self:CleanCheck(row.check)}
        end
        local reward = istable(raw.reward) and raw.reward or {}
        out.reward = {money = math.floor(num(reward.money, 0, 0, 1000000)), xp = math.floor(num(reward.xp, 0, 0, 1000000)),
            mode = reward.mode == "leader" and "leader" or "each", items = {}, skills = {}}
        local items, skills = list(reward.items, 16), list(reward.skills, 16)
        if not items or not skills then return nil, "Не больше 16 строк предметов и навыков в награде." end
        for i, row in ipairs(items) do
            if not istable(row) then return nil, "Некорректная награда." end
            out.reward.items[i] = {item = self.Key(row.item), count = math.floor(num(row.count, 1, 1, 100)),
                chance = math.floor(num(row.chance, 100, 0, 100) * 100 + 0.5) / 100}
        end
        for i, row in ipairs(skills) do
            if not istable(row) then return nil, "Некорректная награда." end
            out.reward.skills[i] = {skill = self.Key(row.skill), xp = math.floor(num(row.xp, 1, 1, 100000))}
        end
    elseif kind == "npc" then
        local reputation, err = self:CleanReputation(raw.reputation)
        if not reputation then return nil, err end
        out.reputation = reputation
        out.portrait = self:CleanPortrait(raw.portrait)
        out.model = model(raw.model, "models/Humans/Group01/male_07.mdl")
        out.skin = math.floor(num(raw.skin, 0, 0, 128))
        out.sequence = str(raw.sequence, 100, "idle_all_01")
        out.cycle = num(raw.cycle, 0, 0, 1)
        out.animate = raw.animate ~= false
        out.talk = raw.talk ~= false
        out.talkSequence = str(raw.talkSequence, 100, "auto")
        out.bodygroups, out.pose = {}, {}
        for k, v in pairs(istable(raw.bodygroups) and raw.bodygroups or {}) do
            local index = tonumber(k)
            if index and index >= 0 and index <= 64 then out.bodygroups[tostring(math.floor(index))] = math.floor(num(v, 0, 0, 128)) end
        end
        local n = 0
        for k, v in pairs(istable(raw.pose) and raw.pose or {}) do
            if n >= 32 then break end
            if self.Key(k) ~= "" then out.pose[k] = num(v, 0, -360, 360) n = n + 1 end
        end
        out.start = self.Key(raw.start)
        out.nodes = {}
        local nodes = list(raw.nodes, 32)
        if not nodes then return nil, "Не больше 32 реплик." end
        local seen = {}
        for i, row in ipairs(nodes) do
            if not istable(row) then return nil, "Некорректная реплика." end
            if isstring(row.text) and #row.text > 2400 then return nil, "Слишком длинная реплика (максимум 2400 байт UTF-8)." end
            local id, options = self.Key(row.id), list(row.options, 8)
            if id == "" or seen[id] or not options then return nil, "Ключи реплик должны быть уникальны; до 8 ответов на реплику." end
            seen[id] = true
            local node = {id = id, text = str(row.text, 2400), options = {}}
            for j, option in ipairs(options) do
                if not istable(option) or not self.ACTIONS[option.action] then return nil, "Некорректное действие ответа." end
                if isstring(option.text) and #option.text > 240 then return nil, "Слишком длинный ответ (максимум 240 байт UTF-8)." end
                node.options[j] = {text = str(option.text, 240, "Продолжить"), action = option.action,
                    next = self.Key(option.next), fail = self.Key(option.fail), quest = self.Key(option.quest),
                    target = str(option.target, 100), check = self:CleanCheck(option.check)}
                node.options[j].reputation = self:CleanReputationGate(option.reputation)
            end
            out.nodes[i] = node
        end
        if #out.nodes > 0 and not seen[out.start] then return nil, "Начальная реплика не найдена." end
        for _, node in ipairs(out.nodes) do
            for _, option in ipairs(node.options) do
                if (option.next ~= "" and not seen[option.next]) or (option.fail ~= "" and not seen[option.fail]) then
                    return nil, "Переход ведёт к отсутствующей реплике."
                end
            end
        end
    elseif kind == "pool" then
        out.interval = math.floor(num(raw.interval, 3600, 60, 31536000))
        out.slots = math.floor(num(raw.slots, 1, 1, 32))
        out.epoch = math.floor(num(raw.epoch, 0, 0, 4102444800))
    elseif kind == "object" then
        out.model = model(raw.model, "models/props_junk/wood_crate001a.mdl")
        out.target = str(raw.target, 100)
        out.quest = self.Key(raw.quest)
        out.skin = math.floor(num(raw.skin, 0, 0, 128))
    end
    return out
end

function Q:Available(quest, now, definitions)
    if not quest.enabled then return false end
    if quest.availableFrom > now or (quest.availableUntil > 0 and now >= quest.availableUntil) then return false end
    if quest.pool == "" then return true end
    local pool = definitions.pool[quest.pool]
    if not pool or not pool.enabled then return false end
    if not self.availabilityCache or self.availabilityCache.time ~= now or self.availabilityCache.definitions ~= definitions then
        self.availabilityCache = {time = now, definitions = definitions, pools = {}}
    end
    local ids = self.availabilityCache.pools[pool.id]
    if not ids then
        ids = {}
        for id, candidate in pairs(definitions.quest) do
            if candidate.pool == pool.id and candidate.enabled and candidate.availableFrom <= now
                and (candidate.availableUntil == 0 or candidate.availableUntil > now) then ids[#ids + 1] = id end
        end
        table.sort(ids)
        self.availabilityCache.pools[pool.id] = ids
    end
    if #ids == 0 then return false end
    local first = math.floor(math.max(0, now - pool.epoch) / pool.interval) * pool.slots
    for offset = 0, math.min(#ids, pool.slots) - 1 do
        if ids[(first + offset) % #ids + 1] == quest.id then return true end
    end
    return false
end

function Q:Eligibility(state, quest, leader, now, definitions, activeRun)
    local allowed, reason = self:ReputationAllowed(state, definitions.npc[quest.npc], quest.reputation)
    if not allowed then return false, reason end
    local pending = 0
    for _, receipt in pairs(state.receipts or {}) do
        if receipt.status == "pending" or receipt.status == "applying" then pending = pending + 1 end
    end
    if pending >= 64 then return false, "Сначала заберите накопленные награды у квестодателей (лимит 64)." end
    local history = state.history[quest.id] or {}
    if (not quest.repeatable and (history.successes or 0) > 0)
        or ((leader or quest.lockParticipants) and (history.successUntil or 0) > now) then return false, self.BLOCKED_GROUP end
    if (history.failureUntil or 0) > now then return false, "Ещё не закончился кулдаун повторной попытки." end
    if quest.prerequisite ~= "" then
        local previous = state.history[quest.prerequisite]
        if not previous or (previous.successes or 0) == 0 then return false, "Предыдущее задание цепочки ещё не выполнено." end
        if (previous.nextAt or 0) > now then return false, "Следующее задание цепочки пока недоступно." end
    end
    if not activeRun and not self:Available(quest, now, definitions) then return false, "Задание сейчас не выдаётся." end
    return true
end

function Q:ObjectiveOpen(run, index)
    if (run.progress[run.quest.objectives[index].id] or 0) >= run.quest.objectives[index].count then return false end
    if run.quest.ordered then
        for i = 1, index - 1 do
            local goal = run.quest.objectives[i]
            if (run.progress[goal.id] or 0) < goal.count then return false end
        end
    end
    return true
end

function Q:Complete(run)
    for _, goal in ipairs(run.quest.objectives) do
        if (run.progress[goal.id] or 0) < goal.count then return false end
    end
    return #run.quest.objectives > 0
end

function Q:Roll(character, check, random)
    local skill = check.skill ~= "" and character.GetSkillModified and character:GetSkillModified(check.skill) or 0
    local stat = check.stat ~= "" and character.GetSpecial and character:GetSpecial(check.stat, 0) or 0
    local dice = check.mode == "roll" and (random or math.random)(1, 20) or 0
    local score = dice + skill * check.skillWeight + stat * check.statWeight
    return score >= check.difficulty, score, dice
end
