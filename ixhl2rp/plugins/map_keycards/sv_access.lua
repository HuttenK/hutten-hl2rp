local P = PLUGIN
local profiles = include("sv_tsade.lua")
P.rules = {}
P.groups = {}
P.byEntity = {}
P.testPlayers = setmetatable({}, {__mode = "k"})
P.grants = setmetatable({}, {__mode = "k"})
P.notices = setmetatable({}, {__mode = "k"})
local departments = { [""] = true, security = true, military = true, science = true }
local controlInputs = {use=true, press=true, pressin=true, pressout=true, toggle=true}
local doorInputs = {use=true, open=true, openawayfrom=true, toggle=true, unlock=true, setposition=true}

local function entityKey(class, model, name)
    return class .. "|" .. (model or "") .. "|" .. (name or "")
end

function P:MapFingerprint()
    local f = file.Open("maps/" .. game.GetMap() .. ".bsp", "rb", "GAME")
    if not f then return end
    if f:Read(4) ~= "VBSP" or f:ReadLong() ~= 20 then f:Close(); return end
    local offset, length = f:ReadLong(), f:ReadLong()
    if not offset or not length or offset < 1036 or length < 1 or length > 16 * 1024 * 1024 or offset + length > f:Size() then
        f:Close(); return
    end
    f:Seek(offset)
    local raw = f:Read(length)
    f:Close()
    return raw and #raw == length and util.CRC(raw) or nil
end

function P:ValidRule(rule)
    return istable(rule) and isnumber(rule.level) and rule.level >= 0 and rule.level <= 4
        and rule.level % 1 == 0 and isstring(rule.department) and departments[rule.department] == true
end

-- Resolve compiled brush/model identity, not transient EntIndex or guessed Hammer-ID offsets.
function P:BuildBindings(profile, entities)
    self.groups = {}; self.byEntity = {}; self.grants = setmetatable({}, {__mode="k"})
    local candidates = {}
    for _, e in ipairs(entities) do
        if IsValid(e) and e:MapCreationID() >= 0 then
            local key = entityKey(e:GetClass(), e:GetModel(), e:GetName())
            candidates[key] = candidates[key] or {}
            candidates[key][#candidates[key]+1] = e
        end
    end
    for _, def in ipairs(profile.groups) do
        local g = {id=def.id, name=def.name, kind=def.kind, members={}, controls={}, complete=true, definition=def}
        self.groups[g.id] = g
        for _, member in ipairs(def.members) do
            local list = candidates[entityKey(member.class, member.model, member.name)] or {}
            local found
            if #list == 1 then found = list[1]
            elseif #list > 1 then
                local pos = Vector(unpack(member.origin))
                for _, e in ipairs(list) do
                    if e:GetPos():DistToSqr(pos) < 1 then
                        if found then found = nil; break end
                        found = e
                    end
                end
            end
            if found and not self.byEntity[found] then
                g.members[#g.members+1] = found
                self.byEntity[found] = g
                if member.control then g.controls[found] = true end
            else g.complete = false end
        end
    end
end

function P:LoadData()
    self.ready = false; self.problem = nil; self.profile = nil
    self.rules = {}; self.groups = {}; self.byEntity = {}
    local profile = profiles and profiles[game.GetMap()]
    if not profile then self.problem = "Для этой карты нет проверенной схемы дверей."; return end
    if self:MapFingerprint() ~= profile.crc then
        self.problem = "Версия карты изменилась. Сначала обновите схему дверей; старые правила не переназначены."
        ErrorNoHalt("[Map Keycards] " .. self.problem .. "\n")
        return
    end
    self.profile = profile
    self:BuildBindings(profile, ents.GetAll())
    local saved = ix.data.Get("map_keycard_access_v1", {})
    if istable(saved) and saved.crc == profile.crc and istable(saved.rules) then
        for key, rule in pairs(saved.rules) do
            local id = tostring(key)
            if self.groups[id] and self:ValidRule(rule) then
                self.rules[id] = {level=rule.level, department=rule.department}
            end
        end
    end
    self.ready = true
end

function P:SaveData()
    if not self.ready or not self.profile then return end
    ix.data.Set("map_keycard_access_v1", {crc=self.profile.crc, rules=self.rules})
end

function P:PostCleanupMap()
    timer.Simple(0, function()
        if ix.plugin.list.map_keycards == self then self:LoadData() end
    end)
end

function P:InitializedPlugins()
    -- Also supports enabling/reloading this plugin after the initial map load.
    timer.Simple(0, function()
        if ix.plugin.list.map_keycards == self then self:LoadData() end
    end)
end

function P:FindGroup(e)
    if not self.ready then return end
    for _ = 1, 8 do
        if not IsValid(e) then return end
        local g = self.byEntity[e]
        if g then return g end
        e = e:GetParent()
    end
end

function P:CardAllowed(p, rule)
    local F = ix.Facility
    if not F or not F.Active(p) then return false end
    if p:IsAdmin() and not self.testPlayers[p] then return true end
    if rule.level == 0 and rule.department == "" then return true end
    local card = p.GetIDCard and p:GetIDCard()
    if not card or not ix.Fieldlink or not ix.Fieldlink.CardIdentity(card) then return false end
    return (card.clearanceLevel or 0) >= rule.level
        and (rule.department == "" or card.department == rule.department)
end

function P:Powered(e)
    local f = ix.plugin.list.facility_utilities
    local b = ix.plugin.list.blackout
    local override = b and b.ElectronicsOverride and b:ElectronicsOverride(e:GetPos())
    if override ~= nil then return not override end
    if f and f.loaded then
        if f:EntityIsolated(e) then return false end
        return ix.Facility.EntityBackup(e) or f:DirectGrid(e)
    end
    return not b or not b:IsElectronicsOffAt(e:GetPos(), e)
end

function P:GroupAllowed(p, g, source, skipLockdown)
    local rule = g and self.rules[g.id]
    if not rule then return true end
    if not g.complete then return false, "Не найдены все части двери. Обратитесь к администратору." end
    for _, e in ipairs(g.members) do
        if not IsValid(e) then return false, "Часть механизма отсутствует." end
    end
    if not self:CardAllowed(p, rule) then
        return false, "Доступ запрещён. Требуется карта L" .. rule.level .. (rule.department ~= "" and " / " .. rule.department or "") .. "."
    end
    local f = ix.plugin.list.facility_utilities
    for _, d in pairs(f and f.store and f.store.doors or {}) do
        if self.byEntity[d.entity] == g then
            local circuit = f.store.circuits[d.circuit]
            if d.fault or (not skipLockdown and circuit and circuit.lockdown) then return false, "Дверь неисправна или заблокирована сектором." end
        end
    end
    -- Manual doors without electrical controls retain their mechanical operation.
    if next(g.controls) then
        local e = g.controls[source] and source or nil
        if not e then
            local point = IsValid(source) and source:GetPos() or p:GetPos()
            local distance = math.huge
            for control in pairs(g.controls) do
                local d = control:GetPos():DistToSqr(point)
                if d < distance then e = control; distance = d end
            end
        end
        if not self:Powered(e) then return false, "Нет питания у управления дверью." end
    end
    return true
end

function P:NotifyDenied(p, reason)
    if not IsValid(p) or not p:IsPlayer() or (self.notices[p] or 0) > CurTime() then return end
    self.notices[p] = CurTime() + 1
    p:Notify(reason or "Доступ запрещён.")
end

function P:CheckPlayer(p, g, source)
    local allowed, reason = self:GroupAllowed(p, g, source)
    if not allowed then self:NotifyDenied(p, reason) end
    return allowed
end

function P:Grant(p, g)
    self.grants[p] = self.grants[p] or {}
    -- The original multi-stage sequence may finish after the player swaps cards.
    self.grants[p][g.id] = {untilTime=CurTime()+30, character=p:GetCharacter()}
end

function P:PlayerUse(p, e)
    local g = self:FindGroup(e)
    if not g or not self.rules[g.id] then return end
    if not self:CheckPlayer(p, g, e) then return false end
    self:Grant(p, g)
    -- No true return: other plugins and the engine still enforce locks/cooldowns.
end

function P:AcceptInput(e, input, activator, caller)
    local g = self:FindGroup(e)
    if not g or not self.rules[g.id] then return end
    local command = string.lower(input)
    local control = g.controls[e]
    if not (control and controlInputs[command] or not control and doorInputs[command]) then return end
    if not IsValid(activator) or not activator:IsPlayer() then
        if IsValid(caller) and caller:IsPlayer() then activator = caller else return end
    end
    if not control and IsValid(caller) and not caller:IsPlayer() and caller:MapCreationID() >= 0 then
        local sourceGroup = self:FindGroup(caller)
        -- Preserve map-authored master overrides, relays and automatic sequences.
        -- Their initiating controls can have their own, separate clearance rules.
        if sourceGroup ~= g then return end
        local grant = self.grants[activator] and self.grants[activator][g.id]
        if grant and grant.untilTime >= CurTime() and grant.character == activator:GetCharacter() then return end
    end
    if not self:CheckPlayer(activator, g, caller) then return true end
    self:Grant(activator, g)
end

function P:AdminCommand(p, action, level, department)
    if not IsValid(p) or not p:IsPlayer() or not p:IsAdmin() then return "Только для администрации." end
    if action == "test" then
        self.testPlayers[p] = level == true or nil
        self.grants[p] = nil
        return level and "Проверка вашей карты включена (обход администратора отключён)." or "Проверка вашей карты выключена (обход администратора включён)."
    end
    if not self.ready then return self.problem or "Дождитесь загрузки карты." end
    local tr = p:GetEyeTrace()
    if not tr.Hit or not IsValid(tr.Entity) or p:GetShootPos():DistToSqr(tr.HitPos) > 256^2 then
        return "Посмотрите на дверь или её кнопку рядом (до 256 единиц)."
    end
    local g = self:FindGroup(tr.Entity)
    if not g then return "Эта поверхность не связана с известной дверью/кнопкой. Наведитесь на саму кнопку." end
    if action == "info" then
        local rule = self.rules[g.id]
        return g.name .. " [" .. g.kind .. "] / " .. #g.members .. " частей / "
            .. (g.complete and "готово" or "неполная группа") .. " / "
            .. (rule and "L" .. rule.level .. (rule.department ~= "" and " / " .. rule.department or "") or "без правила")
    end
    if action == "remove" then
        self.rules[g.id] = nil
    elseif action == "set" then
        local rule = {level=level, department=string.lower(string.Trim(department or ""))}
        if not self:ValidRule(rule) then return "Уровень: целое число 0–4. Отдел: security, military, science или пусто." end
        if not g.complete then return "Не все части механизма найдены. Правило не сохранено." end
        self.rules[g.id] = rule
    else return "Неизвестное действие." end
    self.grants = setmetatable({}, {__mode="k"})
    self:SaveData()
    local f = ix.plugin.list.facility_utilities
    if f then f:Audit(p, "MapDoorAccess " .. action, g.name) end
    return action == "remove" and "Правило удалено: " .. g.name
        or "Сохранено: " .. g.name .. " / L" .. level .. ". Все связанные кнопки используют это правило."
end

function P:PlayerDisconnected(p)
    self.testPlayers[p] = nil; self.grants[p] = nil; self.notices[p] = nil
end

function P:PlayerLoadedCharacter(p)
    self.grants[p] = nil
end

function P:OnUnload()
    self:SaveData(); self.ready = false; self.byEntity = {}; self.groups = {}
end
