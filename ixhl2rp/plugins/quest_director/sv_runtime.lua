-- Server-authoritative runtime authored for Foundation's actual character/inventory APIs.
local PLUGIN, Q = PLUGIN, ix.questDirector
local function contains(list, value) for _, id in ipairs(list) do if id == value then return true end end return false end
local function remove(list, value) for i, id in ipairs(list) do if id == value then table.remove(list, i) return end end end
function Q:Character(client)
    if IsValid(client) and client:IsPlayer() and client:Alive() then return client:GetCharacter() end
end
function Q:Near(client, entity, range)
    return self:Character(client) ~= nil and IsValid(entity) and client:GetPos():DistToSqr(entity:GetPos()) <= (range or self.RANGE) ^ 2
end
function Q:Placement(client, id, kind)
    local entry, entity = self.placements[self.Key(id)], self.entities[self.Key(id)]
    if not entry or (kind and entry.kind ~= kind) or not self:Near(client, entity) then return nil, "Подойдите к объекту." end
    local row = self.defs[entry.kind][entry.definition]
    if not row or not row.enabled then return nil, "Объект выключен." end
    local trace = util.TraceLine({start = client:EyePos(), endpos = entity:WorldSpaceCenter(), filter = client})
    if trace.Hit and trace.Entity ~= entity then return nil, "Объект вне прямой видимости." end
    return row, entry, entity
end
function Q:RunsFor(id)
    local out = {}
    for _, run in pairs(self.runs) do if contains(run.members, id) then out[#out + 1] = run end end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
function Q:CanJoin(client, quest, leader)
    local char = self:Character(client)
    if not char then return false, "Нужен живой персонаж." end
    local runs = self:RunsFor(char:GetID())
    if #runs >= self.MAX_ACTIVE then return false, "Достигнут лимит активных заданий." end
    for _, run in ipairs(runs) do if run.quest.id == quest.id then return false, "Это задание уже принято." end end
    return self:Eligibility(self:State(char:GetID()), quest, leader, os.time(), self.defs)
end
function Q:Together(run, client)
    if not run.quest.requireTogether then return true end
    local count = 0
    for _, id in ipairs(run.members) do
        local member = self:Player(id)
        if self:Character(member) and self:Near(member, client, self.GROUP_RANGE) then count = count + 1 end
    end
    return count >= run.quest.minMembers
end
function Q:Check(client, check, key)
    local char = self:Character(client)
    if not char then return false, "Нужен живой персонаж." end
    self.checkRetries = self.checkRetries or {}
    key = char:GetID() .. ":" .. key
    if (self.checkRetries[key] or 0) > CurTime() then return false, "Проверку можно повторить чуть позже." end
    local ok = self:Roll(char, check)
    if not ok then self.checkRetries[key] = CurTime() + check.retry end
    return ok, ok and "Проверка пройдена." or "Проверка навыка не пройдена."
end
function Q:RunView(run, id, npc)
    local view = {id = run.id, quest = run.quest.id, name = run.quest.name, description = run.quest.description,
        deadline = run.deadline, members = #run.members, minimum = run.quest.minMembers, maximum = run.quest.maxMembers,
        leader = run.leader == id, complete = self:Complete(run), objectives = {}, atActor = not npc or npc == run.quest.npc,
        npcName = (self.defs.npc[run.quest.npc] or {}).name or run.quest.npc}
    for index, goal in ipairs(run.quest.objectives) do
        view.objectives[#view.objectives + 1] = {id = goal.id, name = goal.name, count = goal.count, progress = run.progress[goal.id] or 0, open = self:ObjectiveOpen(run, index)}
    end
    return view
end
function Q:Journal(client, page, npc)
    local char = client:GetCharacter()
    local state, runs = self:State(char:GetID()), self:RunsFor(char:GetID())
    local view = {runs = {}, receipts = {}, reputation = {}, maxActive = self.MAX_ACTIVE, serverTime = os.time()}
    for _, run in ipairs(runs) do view.runs[#view.runs + 1] = self:RunView(run, char:GetID(), npc) end
    for _, receipt in pairs(state.receipts) do
        if receipt.status ~= "claimed" and (not npc or receipt.npc == npc) then
            view.receipts[#view.receipts + 1] = {id = receipt.id, name = receipt.name, status = receipt.status}
        end
    end
    local reps = {}
    for _, row in pairs(self.defs.npc) do if row.reputation.enabled then reps[#reps + 1] = self:ReputationView(state, row) end end
    table.sort(reps, function(a, b) return a.npc < b.npc end)
    view.reputationPages = math.max(1, math.ceil(#reps / 30))
    view.reputationPage = math.floor(self.Number(page, 1, 1, view.reputationPages))
    for i = (view.reputationPage - 1) * 30 + 1, math.min(view.reputationPage * 30, #reps) do view.reputation[#view.reputation + 1] = reps[i] end
    return view
end
function Q:Dialogue(client, id, page, keep)
    local npc, placement, entity = self:Placement(client, id, "npc")
    if not npc then return false, placement end
    local cid = client:GetCharacter():GetID()
    local session = self.sessions[client]
    if not session or session.character ~= cid or session.placement ~= id or session.expires < CurTime() or session.revision ~= npc.revision then
        session = {id = self:NewID("talk"), character = cid, placement = id, node = npc.start, revision = npc.revision}
        self.sessions[client] = session
    elseif not keep then
        -- Refresh preserves the current node; reopening after expiry starts at the greeting.
    end
    session.expires = CurTime() + 180
    local node
    for _, row in ipairs(npc.nodes) do if row.id == session.node then node = row break end end
    node = node or {id = "", text = "Здравствуйте. Чем могу помочь?", options = {}}
    local view = self:Journal(client, 1, npc.id)
    for _, key in ipairs({"model", "skin", "bodygroups", "pose", "sequence", "cycle", "animate", "portrait", "name"}) do view[key] = npc[key] end
    view.session, view.character, view.placement, view.node, view.text = session.id, cid, id, node.id, node.text
    view.reputation = self:ReputationView(self:State(cid), npc)
    view.options, view.quests = {}, {}
    for index, option in ipairs(node.options) do
        local ok, reason = self:ReputationAllowed(self:State(cid), npc, option.reputation)
        view.options[#view.options + 1] = {index = index, text = option.text, action = option.action, quest = option.quest, allowed = ok, reason = reason}
    end
    local quests = {}
    for _, quest in pairs(self.defs.quest) do
        if quest.npc == npc.id and not quest.dialogueOnly and self:Available(quest, os.time(), self.defs) then
            local ok, reason = self:CanJoin(client, quest, true)
            quests[#quests + 1] = {id = quest.id, name = quest.name, allowed = ok, reason = reason}
        end
    end
    table.sort(quests, function(a, b) return a.id < b.id end)
    view.pages = math.max(1, math.ceil(#quests / 12))
    view.page = math.floor(self.Number(page, 1, 1, view.pages))
    for i = (view.page - 1) * 12 + 1, math.min(view.page * 12, #quests) do view.quests[#view.quests + 1] = quests[i] end
    if entity.Speak then entity:Speak(node.text) end
    return true, view
end
function Q:Choose(client, data)
    local npc, message = self:Placement(client, data.placement, "npc")
    if not npc then return false, message end
    local session = self.sessions[client]
    if not session or session.character ~= client:GetCharacter():GetID() or session.placement ~= data.placement or session.expires < CurTime() or session.revision ~= npc.revision then return false, "Откройте диалог заново." end
    local node
    for _, row in ipairs(npc.nodes) do if row.id == session.node then node = row end end
    local option = node and node.options[tonumber(data.option)]
    if not option then return false, "Ответ не найден." end
    local ok, reason = self:ReputationAllowed(self:State(session.character), npc, option.reputation)
    if not ok then return false, reason end
    ok, reason = self:Check(client, option.check, "dialogue:" .. npc.id .. ":" .. node.id .. ":" .. data.option)
    if not ok then
        if option.fail ~= "" then session.node = option.fail else return false, reason end
    else
        if option.action == "close" then self.sessions[client] = nil return true, {close = true} end
        if option.action == "quest" then
            local opened, group = self:GroupOpen(client, data.placement, option.quest, true)
            return opened, opened and {group = group} or group
        elseif option.action == "finish" then
            local run = self.runs[self.Key(data.run)]
            if option.quest ~= "" and (not run or run.quest.id ~= option.quest) then return false, "Ответ относится к другому заданию." end
            local finished, err = self:Finish(client, data.placement, data.run)
            if not finished then return false, err end
        elseif option.action == "event" then
            self:Advance(client, "dialogue", option.target, 1, {quest = option.quest, npc = npc.id})
        end
        if option.next ~= "" then session.node = option.next end
    end
    local _, view = self:Dialogue(client, data.placement, 1, true)
    return true, {dialogue = view, message = not ok and reason or nil}
end
function Q:GroupView(client, placement, id)
    local npc, err = self:Placement(client, placement, "npc")
    if not npc then return false, err end
    local group = self.groups[self.Key(id)] or self.runs[self.Key(id)]
    local cid = client:GetCharacter():GetID()
    if not group or not contains(group.members, cid) or group.quest.npc ~= npc.id then return false, "Группа не найдена у этого NPC." end
    local view = {group = group.id, placement = placement, quest = group.quest, active = self.runs[id] ~= nil, members = {}, candidates = {}}
    for _, member in ipairs(group.members) do view.members[#view.members + 1] = {character = member, leader = member == group.leader, online = self:Character(self:Player(member)) ~= nil} end
    if group.leader == cid and #group.members < group.quest.maxMembers then
        for _, other in ipairs(player.GetAll()) do
            local char = self:Character(other)
            if char and not contains(group.participants, char:GetID()) and self:Near(other, client, self.GROUP_RANGE) and self:Near(other, self.entities[placement], self.GROUP_RANGE) then
                view.candidates[#view.candidates + 1] = {character = char:GetID(), entity = other:EntIndex()}
            end
        end
    end
    return true, view
end
function Q:GroupOpen(client, placement, id, fromDialogue)
    local npc, err = self:Placement(client, placement, "npc")
    if not npc then return false, err end
    local quest = self.defs.quest[self.Key(id)]
    if not quest or quest.npc ~= npc.id or (quest.dialogueOnly and not fromDialogue) then return false, "Задание выдаётся через ответ NPC." end
    local ok, reason = self:CanJoin(client, quest, true)
    if not ok then return false, reason end
    local cid = client:GetCharacter():GetID()
    for key, group in pairs(self.groups) do if group.leader == cid then self.groups[key] = nil end end
    local group = {id = self:NewID("group"), leader = cid, members = {cid}, participants = {cid}, quest = table.Copy(quest), placement = placement, expires = os.time() + 600}
    self.groups[group.id] = group
    return self:GroupView(client, placement, group.id)
end
function Q:Invite(client, data)
    local ok, view = self:GroupView(client, data.placement, data.group)
    if not ok then return false, view end
    local group = self.groups[data.group] or self.runs[data.group]
    local cid = client:GetCharacter():GetID()
    if group.leader ~= cid or #group.members >= group.quest.maxMembers or #group.participants >= 8 then return false, "Группа заполнена или вы не лидер." end
    local other = self:Player(tonumber(data.character))
    if not self:Character(other) or other:EntIndex() ~= tonumber(data.entity) or not self:Near(other, client, self.GROUP_RANGE)
        or not self:Near(other, self.entities[data.placement], self.GROUP_RANGE) then return false, "Игрок должен быть рядом." end
    if contains(group.participants, other:GetCharacter():GetID()) then return false, "Персонаж уже участвовал в этой группе." end
    for _, pending in pairs(self.invites) do
        if pending.character == other:GetCharacter():GetID() and pending.leader == cid and pending.expires > CurTime() then return false, "Предыдущее приглашение ещё ожидает ответа." end
    end
    local allowed, reason = self:CanJoin(other, group.quest, false)
    if not allowed then return false, reason end
    local token = self:NewID("invite")
    self.invites[token] = {group = group.id, character = other:GetCharacter():GetID(), leader = cid, expires = CurTime() + 30, placement = data.placement}
    self:Push(other, "invite", {leader = cid, quest = group.quest.name, token = token})
    return true, "Приглашение отправлено на 30 секунд."
end
function Q:Accept(client, data)
    local token = self.Key(data.token)
    local invite = self.invites[token]
    local cid = client:GetCharacter():GetID()
    if not invite or invite.character ~= cid or invite.expires < CurTime() then return false, "Приглашение истекло." end
    self.invites[token] = nil
    if data.accept ~= true then return true, "Приглашение отклонено." end
    local group = self.groups[invite.group] or self.runs[invite.group]
    local leader = group and self:Player(group.leader)
    if not group or not self:Character(leader) or #group.members >= group.quest.maxMembers or #group.participants >= 8
        or contains(group.participants, cid) or not self:Near(client, leader, self.GROUP_RANGE)
        or not self:Near(client, self.entities[invite.placement], self.GROUP_RANGE) then return false, "Состав или расположение группы изменились." end
    local ok, reason = self:CanJoin(client, group.quest, false)
    if not ok then return false, reason end
    group.members[#group.members + 1], group.participants[#group.participants + 1] = cid, cid
    if self.runs[group.id] then self:Save() end
    return true, "Вы вступили в группу."
end
function Q:Start(client, data)
    local ok, view = self:GroupView(client, data.placement, data.group)
    if not ok then return false, view end
    local group = self.groups[data.group]
    if not group or group.leader ~= client:GetCharacter():GetID() or group.expires < os.time() then return false, "Лидер должен заново собрать группу." end
    local live = self.defs.quest[group.quest.id]
    if not live or live.revision ~= group.quest.revision then return false, "Условия задания изменились. Откройте его заново." end
    if #group.members < group.quest.minMembers then return false, "Недостаточно участников." end
    for _, cid in ipairs(group.members) do
        local member = self:Player(cid)
        local allowed, reason = self:CanJoin(member, group.quest, cid == group.leader)
        if not allowed then return false, reason end
        if not self:Near(member, self.entities[data.placement], self.GROUP_RANGE) then return false, "Все участники должны быть рядом с NPC." end
    end
    group.progress, group.started = {}, os.time()
    group.deadline = group.quest.duration > 0 and os.time() + group.quest.duration or 0
    group.reputationPolicy = table.Copy((self.defs.npc[group.quest.npc] or {}).reputation)
    self.groups[group.id], self.runs[group.id] = nil, group
    self:Log(client, "start", group.id)
    if not self:Save() then return false, "Ошибка сохранения. Обратитесь к администрации." end
    return true, "Задание принято. /QuestJournal — журнал."
end
function Q:RemoveMember(client, data)
    local ok, view = self:GroupView(client, data.placement, data.group)
    if not ok then return false, view end
    local group = self.groups[data.group] or self.runs[data.group]
    local cid = tonumber(data.character)
    if group.leader ~= client:GetCharacter():GetID() or cid == group.leader or not contains(group.members, cid) then return false, "Нельзя изменить этого участника." end
    remove(group.members, cid)
    if self.runs[group.id] then self:Save() else remove(group.participants, cid) end
    return true, "Участник исключён."
end
function Q:Advance(client, kind, target, amount, context)
    if self.storageFault or not self:Character(client) then return 0 end
    context = context or {}
    local changed = 0
    for _, run in ipairs(self:RunsFor(client:GetCharacter():GetID())) do
        if (not context.run or run.id == context.run) and (not context.quest or context.quest == "" or run.quest.id == context.quest)
            and (not context.npc or run.quest.npc == context.npc) and not run.deposit and #run.members >= run.quest.minMembers
            and (run.deadline == 0 or run.deadline > os.time()) and self:Together(run, client) then
            -- One event can satisfy at most one objective per run, including ordered identical targets.
            for index, goal in ipairs(run.quest.objectives) do
                if goal.type == kind and goal.target == target and self:ObjectiveOpen(run, index)
                    and (not context.objective or goal.id == context.objective) and (goal.weapon == "" or goal.weapon == context.weapon) then
                    local ok = context.checked or self:Check(client, goal.check, run.id .. ":" .. goal.id)
                    if ok then
                        local delta = math.min(self.Number(amount, 0, 0, 1000000), goal.count - (run.progress[goal.id] or 0))
                        run.progress[goal.id] = (run.progress[goal.id] or 0) + delta
                        changed = changed + delta
                    end
                    break
                end
            end
        end
    end
    -- Bullet callbacks can be frequent; coalesce damage-only progress writes.
    -- Finishing, consuming items and all reward transitions still persist synchronously.
    if changed > 0 then
        if kind == "damage" then self.progressDirty = true else self:Save() end
    end
    return changed
end
function Q:ObjectView(client, placement)
    local object, entry = self:Placement(client, placement, "object")
    if not object then return false, entry end
    local view = {name = object.name, placement = placement, actions = {}}
    for _, run in ipairs(self:RunsFor(client:GetCharacter():GetID())) do
        for index, goal in ipairs(run.quest.objectives) do
            if goal.type ~= "damage" and self:ObjectMatchesGoal(object, run.quest.id, goal) and self:ObjectiveOpen(run, index) then
                view.actions[#view.actions + 1] = {id = goal.id, run = run.id, name = goal.name, questName = run.quest.name, type = goal.type, remaining = goal.count - (run.progress[goal.id] or 0)}
            end
        end
    end
    return true, view
end
function Q:Interact(client, data)
    local object, err = self:Placement(client, data.placement, "object")
    if not object then return false, err end
    local run = self.runs[self.Key(data.run)]
    if not run or run.deposit or #run.members < run.quest.minMembers or not contains(run.members, client:GetCharacter():GetID()) or not self:Together(run, client)
        or (run.deadline > 0 and run.deadline <= os.time()) then return false, "Задание недоступно или группа далеко." end
    local goal, index
    for i, row in ipairs(run.quest.objectives) do if row.id == data.objective then goal, index = row, i break end end
    if not goal or not self:ObjectMatchesGoal(object, run.quest.id, goal) or not self:ObjectiveOpen(run, index)
        or (goal.type ~= "use" and goal.type ~= "deposit") then return false, "Это действие недоступно." end
    local ok, reason = self:Check(client, goal.check, run.id .. ":" .. goal.id)
    if not ok then return false, reason end
    local count = 1
    if goal.type == "deposit" then
        count = math.floor(self.Number(data.amount, 1, 1, math.min(100, goal.count - (run.progress[goal.id] or 0))))
        local items, seen = {}, {}
        local main = client:GetInventory("main")
        if not main then return false, "Инвентарь ещё загружается." end
        local inventories = {main}
        local backpack = client:GetBackpack()
        if backpack then inventories[#inventories + 1] = backpack:GetInventory() end
        for _, inventory in ipairs(inventories) do
            for _, item in pairs(inventory:GetItems()) do
                -- Native Item:New initializes items={} even for an ordinary consumable.
                -- Only a populated embedded item list denotes contents that must not be deleted.
                if item.uniqueID == goal.item and not seen[item.id] and not item.isBag and not item.isContainer and not item.GetInventory
                    and not (istable(item.items) and next(item.items))
                    and not (ix.Inventory.pendingTransfers and ix.Inventory.pendingTransfers['item_' .. item.id])
                    and not (item.GetData and item:GetData("equip", false)) and #items < count then
                    items[#items + 1], seen[item.id] = item, true
                end
            end
        end
        if #items < count then return false, "Не хватает подходящих предметов в основном инвентаре или рюкзаке." end
        -- Persist a recoverable consumption operation before deleting inventory rows.
        -- Remove(true) is the actual delete API in this fork (Remove() only detaches).
        run.deposit = {character = client:GetCharacter():GetID(), goal = goal.id, items = {}, count = count}
        for _, item in ipairs(items) do run.deposit.items[#run.deposit.items + 1] = item.id end
        if not self:Save() then return false, "Не удалось сохранить передачу." end
        self.depositLive = self.depositLive or {}
        local depositStamp = CurTime() + 60
        self.depositLive[run.id] = depositStamp
        for _, item in ipairs(items) do item:Remove(true) end
        client:GetCharacter():Save(function()
            if self.depositLive[run.id] ~= depositStamp then return end
            self.depositLive[run.id] = nil
            if self.runs[run.id] ~= run or self.storageFault then return end
            run.progress[goal.id] = (run.progress[goal.id] or 0) + count
            run.deposit = nil self:Save()
        end)
        return true, "Передача сохранена или сохраняется. Обновите журнал."
    end
    run.progress[goal.id] = (run.progress[goal.id] or 0) + count
    self:Save()
    return true, "Цель обновлена."
end
function Q:MakeReceipt(run, cid)
    local reward, steps = run.quest.reward, {}
    if reward.money > 0 then steps[#steps + 1] = {kind = "money", amount = reward.money} end
    if reward.xp > 0 then steps[#steps + 1] = {kind = "xp", amount = reward.xp} end
    for _, row in ipairs(reward.skills) do steps[#steps + 1] = {kind = "skill", skill = row.skill, amount = row.xp} end
    for _, row in ipairs(reward.items) do
        if math.random(1, 10000) <= (row.chance or 100) * 100 then
            for i = 1, row.count do steps[#steps + 1] = {kind = "item", item = row.item} end
        end
    end
    local receipt = {id = self:NewID("reward"), name = run.quest.name, npc = run.quest.npc, character = cid, status = #steps > 0 and "pending" or "claimed", steps = steps, cursor = 1, created = os.time()}
    self:State(cid).receipts[receipt.id] = receipt
end
function Q:EndRun(run, success)
    if self.storageFault then return false end
    if self.runs[run.id] ~= run then return false end
    local now, quest = os.time(), run.quest
    for _, cid in ipairs(run.participants) do
        local state = self:State(cid)
        local history = state.history[quest.id] or {}
        state.history[quest.id] = history
        if success then
            history.successes = (history.successes or 0) + 1
            history.successUntil, history.nextAt = now + quest.successCooldown, now + quest.nextDelay
        else history.failureUntil = now + quest.failureCooldown end
        local rep, policy = quest.reputation, run.reputationPolicy
        if policy and policy.enabled and (rep.mode ~= "leader" or cid == run.leader) and (not success or contains(run.members, cid)) then
            local old = self.Number(state.reputation[quest.npc], policy.initial, policy.minimum, policy.maximum)
            state.reputation[quest.npc] = math.Clamp(old + (success and rep.success or rep.failure), policy.minimum, policy.maximum)
        end
        if success and contains(run.members, cid) and (quest.reward.mode == "each" or cid == run.leader) then self:MakeReceipt(run, cid) end
        local client = self:Player(cid)
        if IsValid(client) then client:Notify(quest.name .. (success and ": выполнено; награда у NPC." or ": задание завершено без успеха.")) end
    end
    self.runs[run.id] = nil
    self:Log(nil, success and "completed" or "failed", run.id)
    return self:Save()
end
function Q:Finish(client, placement, id)
    local npc, err = self:Placement(client, placement, "npc")
    if not npc then return false, err end
    local run = self.runs[self.Key(id)]
    if not run or run.leader ~= client:GetCharacter():GetID() or run.quest.npc ~= npc.id then return false, "Сдать задание может лидер у своего NPC." end
    if run.deadline > 0 and run.deadline <= os.time() then self:EndRun(run, false) return false, "Время истекло." end
    if not self:Complete(run) or run.deposit or #run.members < run.quest.minMembers or not self:Together(run, client) then return false, "Цели не выполнены или нет необходимого состава рядом." end
    if not self:EndRun(run, true) then return false, "Ошибка сохранения. Нужна проверка администрации." end
    return true, "Задание сдано. Заберите награду."
end
function Q:Abandon(client, id)
    local run = self.runs[self.Key(id)]
    local cid = client:GetCharacter():GetID()
    if not run or not contains(run.members, cid) then return false, "Задание не найдено." end
    if run.leader == cid then self:EndRun(run, false) else remove(run.members, cid) self:Save() end
    return true, "Вы вышли из задания."
end
function Q:Claim(client, data, statusOnly)
    if self.storageFault then return false, "Хранилище заблокировано." end
    local npc, err = self:Placement(client, data.placement, "npc")
    if not npc then return false, err end
    local char = client:GetCharacter()
    local receipt = self:State(char:GetID()).receipts[self.Key(data.receipt)]
    if not receipt or receipt.npc ~= npc.id then return false, "Награда не найдена у этого NPC." end
    if receipt.status == "claimed" then return true, "Награда уже получена." end
    if self.claiming[receipt.id] then return true, {waiting = true} end
    if receipt.status == "applying" then return false, "Предыдущая выдача прервалась. Администратор должен проверить шаг награды." end
    if statusOnly then return true, {more = true} end
    local step = receipt.steps[receipt.cursor]
    if not step then return false, "Награду должен проверить администратор." end
    -- Persist intention before any irreversible effect; never automatically replay an ambiguous step.
    receipt.status = "applying"
    if not self:Save() then return false, "Ошибка сохранения награды." end
    local claim = {expires = CurTime() + 60}
    self.claiming[receipt.id] = claim
    local function fail(message, retry)
        self.claiming[receipt.id] = nil
        if retry then receipt.status = "pending" self:Save() end
        return false, message
    end
    local function finishStep()
        if self.claiming[receipt.id] ~= claim then return end
        if self.storageFault then self.claiming[receipt.id] = nil return end
        receipt.cursor = receipt.cursor + 1
        receipt.pendingItem = nil
        receipt.status = receipt.cursor > #receipt.steps and "claimed" or "pending"
        self.claiming[receipt.id] = nil
        self:Save()
    end
    local function deliver(item)
        if self.claiming[receipt.id] ~= claim then return end
        -- Character switches/disconnects during asynchronous item load never deliver to a different character.
        if not IsValid(client) or client:GetCharacter() ~= char then fail("Персонаж сменился.", true) return end
        if item.inventory_id then fail("Предмет уже находится в инвентаре. Нужна проверка.") return end
        receipt.pendingItem = item.id
        if not self:Save() then fail("Ошибка сохранения.") return end
        local added = client:AddItem(item, "main") -- also tries the equipped backpack in native sv_player.lua.
        if not added then fail("Освободите место в инвентаре.", true) return end
        item.character_id, item.player_id = char:GetID(), client:SteamID64()
        -- CharacterPreSave saves every inventory item, then the character's saved item IDs.
        char:Save(finishStep)
    end
    if step.kind == "item" then
        if receipt.pendingItem then
            local item = ix.Item.instances[receipt.pendingItem]
            if item then deliver(item) else
                local found = false
                ix.Item:LoadInstanceByID(receipt.pendingItem, function(loaded) found = true deliver(loaded) end,
                    function() if not found then fail("Сохранённый предмет не найден. Нужна проверка.") end end)
            end
        else
            local item = ix.Item:Instance(step.item, nil, nil, char:GetID(), client:SteamID64())
            if not item then return fail("Предмет не создан. Проверьте каталог.") end
            deliver(item)
        end
    elseif step.kind == "money" then char:GiveMoney(step.amount) char:Save(finishStep)
    elseif step.kind == "xp" then
        if not char.AddLevelXP then return fail("Система уровней недоступна.") end
        char:AddLevelXP(step.amount) char:Save(finishStep)
    elseif step.kind == "skill" then
        if not char.UpdateSkillProgress or not char:GetSkills()[step.skill] then return fail("Навык недоступен персонажу.") end
        char:UpdateSkillProgress(step.skill, step.amount) char:Save(finishStep)
    else return fail("Неизвестный шаг награды.") end
    if self.claiming[receipt.id] then return true, {waiting = true} end
    if receipt.status == "applying" then return false, "Выдачу должен проверить администратор." end
    if receipt.cursor <= #receipt.steps and receipt.pendingItem then return false, "Освободите место и заберите оставшуюся награду." end
    return true, {more = receipt.status == "pending"}
end
function Q:UsePlacement(client, entity)
    if self.storageFault or not self:Character(client) then return end
    local entry = self:ManagedPlacement(entity)
    if not entry then return end
    if self.CanEdit(client) and client:GetMoveType() == MOVETYPE_NOCLIP then self:Push(client, "placement", self:PlacementView(entry)) return end
    local ok, view
    if entry.kind == "npc" then ok, view = self:Dialogue(client, entry.id) else ok, view = self:ObjectView(client, entry.id) end
    if ok then self:Push(client, entry.kind == "npc" and "dialogue" or "object", view) else client:Notify(view) end
end
function PLUGIN:Think()
    if not Q.loaded or Q.storageFault or (Q.nextTick or 0) > CurTime() then return end
    Q.nextTick = CurTime() + 1
    if Q.progressDirty then Q.progressDirty = nil Q:Save() end
    for id, claim in pairs(Q.claiming) do if claim.expires <= CurTime() then Q.claiming[id] = nil end end
    for id, stamp in pairs(Q.depositLive or {}) do if stamp <= CurTime() then Q.depositLive[id] = nil end end
    for _, run in pairs(Q.runs) do if run.deadline > 0 and run.deadline <= os.time() then Q:EndRun(run, false) end end
    for id, group in pairs(Q.groups) do if group.expires < os.time() then Q.groups[id] = nil end end
    for id, invite in pairs(Q.invites) do if invite.expires < CurTime() then Q.invites[id] = nil end end
    for _, client in ipairs(player.GetAll()) do
        if Q:Character(client) then
            client.ixQDZones = client.ixQDZones or {}
            local cid = client:GetCharacter():GetID()
            if client.ixQDZoneChar ~= cid then client.ixQDZones = {} client.ixQDZoneChar = cid end
            for id, zone in pairs(Q.zones) do
                local inside = client:GetPos():DistToSqr(Vector(unpack(zone.pos))) <= zone.radius ^ 2
                if inside and not client.ixQDZones[id] then Q:Advance(client, "zone", zone.target, 1) end
                client.ixQDZones[id] = inside
            end
        end
    end
end
