local Q = ix.questDirector
for _, name in ipairs({"ixQDRequest", "ixQDReply", "ixQDPush"}) do util.AddNetworkString(name) end
local function encode(ok, data)
    local raw = util.TableToJSON({ok = ok == true, data = data})
    if not raw or #raw > Q.MAX_PACKET then raw = util.TableToJSON({ok = false, data = "Ответ слишком большой. Сократите шаблон или откройте другую страницу."}) end
    return raw
end
function Q:Push(client, kind, data)
    if not IsValid(client) then return end
    local raw = encode(true, data)
    net.Start("ixQDPush") net.WriteString(kind) net.WriteUInt(#raw, 16) net.WriteData(raw, #raw) net.Send(client)
end
function Q:OpenAdmin(client) if self.CanEdit(client) then self:Push(client, "admin", {}) end end
function Q:OpenJournal(client) if self:Character(client) then self:Push(client, "journal", self:Journal(client)) end end

function Q:Handle(client, action, data)
    if not self:Character(client) then return false, "Нужен живой персонаж." end
    local admin = action:sub(1, 6) == "admin_"
    if admin and not self.CanEdit(client) then return false, "Только для администрации." end
    if self.storageFault and action ~= "admin_list" and action ~= "admin_get" and action ~= "journal" then return false, "Хранилище заданий заблокировано после ошибки сохранения. Нужна проверка сервера." end
    if action == "journal" then return true, self:Journal(client, data.page)
    elseif action == "dialogue" then return self:Dialogue(client, data.placement, data.page)
    elseif action == "choose" then return self:Choose(client, data)
    elseif action == "group_open" then return self:GroupOpen(client, data.placement, data.quest)
    elseif action == "group_view" then return self:GroupView(client, data.placement, data.group)
    elseif action == "invite" then return self:Invite(client, data)
    elseif action == "accept" then return self:Accept(client, data)
    elseif action == "start" then return self:Start(client, data)
    elseif action == "remove_member" then return self:RemoveMember(client, data)
    elseif action == "interact" then return self:Interact(client, data)
    elseif action == "finish" then return self:Finish(client, data.placement, data.run)
    elseif action == "abandon" then return self:Abandon(client, data.run)
    elseif action == "claim" or action == "claim_status" then return self:Claim(client, data, action == "claim_status")
    elseif action == "admin_list" then return self:AdminList(data)
    elseif action == "admin_get" then
        local row = self.defs[data.kind] and self.defs[data.kind][self.Key(data.id)]
        return row ~= nil, row or "Шаблон не найден."
    elseif action == "admin_put" then return self:Put(client, data.kind, data.record)
    elseif action == "admin_delete" then return self:DeleteDefinition(client, data)
    elseif action == "admin_create_quest" then return self:CreateSimple(client, data)
    elseif action == "admin_overview" then return self:Overview(data.id)
    elseif action == "admin_goal_object" then return self:GoalObject(client, data)
    elseif action == "admin_examples" then return self:EnsureQuickExamples(client)
    elseif action == "admin_reputation" then return self:AdminReputation(client, data)
    elseif action == "admin_receipt" then return self:AdminReceipt(client, data)
    elseif action == "admin_publish" then
        local row = self.defs.quest[self.Key(data.id)]
        if not row or row.revision ~= tonumber(data.revision) then return false, "Задание изменилось." end
        row = table.Copy(row)
        row.enabled, row.availableFrom = true, os.time()
        row.availableUntil = row.lifetime > 0 and os.time() + row.lifetime or 0
        return self:Put(client, "quest", row)
    elseif action == "admin_cancel" then
        local run = self.runs[self.Key(data.id)]
        if not run then return false, "Задание уже завершено." end
        self:Log(client, "cancel", run.id) self:EndRun(run, false)
        return true, "Задание отменено."
    elseif action == "admin_deposit" then
        local run = self.runs[self.Key(data.id)]
        if not run or not run.deposit or (self.depositLive and self.depositLive[run.id]) then return false, "Передача не требует проверки." end
        if data.delivered == true then
            for _, goal in ipairs(run.quest.objectives) do if goal.id == run.deposit.goal then run.progress[goal.id] = math.min(goal.count, (run.progress[goal.id] or 0) + run.deposit.count) end end
        end
        self:Log(client, "resolve deposit", run.id .. " delivered=" .. tostring(data.delivered))
        run.deposit = nil self:Save()
        return true, "Передача проверена."
    elseif action == "admin_place" then return self:Place(client, data.kind, data.definition)
    elseif action == "admin_unplace" then return self:RemovePlacement(client, data.id)
    elseif action == "admin_move" then
        local entry = self.placements[self.Key(data.id)]
        if not entry then return false, "Размещение не найдено." end
        local pos, ang = self:TracePlacement(client)
        if not pos then return false, ang end
        entry.pos, entry.ang = pos, ang
        self:Log(client, "move", entry.id) self:Save() self:SpawnPlacement(entry)
        return true, "Размещение перенесено."
    elseif action == "admin_placements" then
        local rows, all = {}, {}
        for _, entry in pairs(self.placements) do all[#all + 1] = self:PlacementView(entry) end
        table.sort(all, function(a, b) return a.id < b.id end)
        local pages = math.max(1, math.ceil(#all / 40))
        local page = math.floor(self.Number(data.page, 1, 1, pages))
        for i = (page - 1) * 40 + 1, math.min(page * 40, #all) do rows[#rows + 1] = all[i] end
        local zones = {} for _, zone in pairs(self.zones) do zones[#zones + 1] = zone end
        return true, {rows = rows, page = page, pages = pages, zones = zones}
    elseif action == "admin_zone" then
        if data.remove then
            local id = self.Key(data.id)
            if not self.zones[id] then return false, "Зона не найдена." end
            self.zones[id] = nil self:Log(client, "remove zone", id) self:Save()
            return true, "Зона удалена."
        end
        if not isstring(data.target) or #data.target == 0 or #data.target > 100 then return false, "Введите метку цели (1–100 байт)." end
        local n = 0 for _ in pairs(self.zones) do n = n + 1 end
        if n >= 64 then return false, "Достигнут лимит 64 зон." end
        local pos, err = self:TracePlacement(client)
        if not pos then return false, err end
        local id = self:NewID("zone")
        self.zones[id] = {id = id, target = data.target, pos = pos, radius = self.Number(data.radius, 128, 32, 4096)}
        self:Log(client, "create zone", id .. " " .. data.target) self:Save()
        return true, "Зона создана в точке взгляда. Для цели игрок должен войти в неё."
    end
    return false, "Неизвестное действие."
end

net.Receive("ixQDRequest", function(bits, client)
    if not IsValid(client) or bits < 32 or bits > (Q.MAX_PACKET + 4) * 8 then return end
    if (client.ixQDRequestAt or 0) > CurTime() then return end
    client.ixQDRequestAt = CurTime() + 0.15
    local id, size = net.ReadUInt(16), net.ReadUInt(16)
    if size < 2 or size > Q.MAX_PACKET or size * 8 > bits - 32 then return end
    local raw = net.ReadData(size)
    if not isstring(raw) or #raw ~= size then return end
    local parsed, request = pcall(util.JSONToTable, raw)
    if not parsed or not istable(request) or not isstring(request.action) or #request.action > 40 or not istable(request.data) then return end
    -- Network data is never Lua or arbitrary hook input. This is the entire action allowlist.
    local callOK, ok, result = pcall(Q.Handle, Q, client, request.action, request.data)
    if not callOK then
        ErrorNoHalt("[Quest Director] Request failed: " .. tostring(ok) .. "\n")
        ok, result = false, "Действие прервано. Обновите окно; администратору доступен серверный журнал."
    end
    local response = encode(ok, result)
    net.Start("ixQDReply") net.WriteUInt(id, 16) net.WriteUInt(#response, 16) net.WriteData(response, #response) net.Send(client)
end)
