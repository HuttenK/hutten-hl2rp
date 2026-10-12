-- Reconstructed server implementation. Recovered files did not include a server runtime.
local PLUGIN, Q = PLUGIN, ix.questDirector
Q.defs = Q.defs or {npc = {}, quest = {}, object = {}, pool = {}}
Q.placements, Q.entities, Q.zones = Q.placements or {}, Q.entities or {}, Q.zones or {}
Q.states, Q.runs, Q.audit = Q.states or {}, Q.runs or {}, Q.audit or {}
Q.groups, Q.invites, Q.sessions, Q.claiming = {}, {}, {}, {}
Q.generation, Q.serial = Q.generation or 0, Q.serial or 0

function Q:NewID(prefix)
    self.serial = self.serial + 1
    return prefix .. "_" .. os.time() .. "_" .. self.serial
end

function Q:State(id)
    id = tostring(id)
    self.states[id] = self.states[id] or {history = {}, receipts = {}, reputation = {}}
    return self.states[id]
end

function Q:Player(id)
    for _, client in ipairs(player.GetAll()) do
        local character = client:GetCharacter()
        if character and tostring(character:GetID()) == tostring(id) then return client end
    end
end

function Q:Log(client, action, detail)
    self.audit[#self.audit + 1] = {time = os.time(), actor = IsValid(client) and client:SteamID() or "server", action = action, detail = tostring(detail or ""):sub(1, 500)}
    while #self.audit > 500 do table.remove(self.audit, 1) end
end

function Q:StorePath()
    return "helix/" .. Schema.folder .. "/" .. game.GetMap() .. "/quest_director_"
end

function Q:Save()
    if self.storageFault then return false end
    local generation = self.generation + 1
    local data = {version = 1, generation = generation, serial = self.serial, defs = self.defs,
        placements = self.placements, zones = self.zones, states = self.states, runs = self.runs, audit = self.audit}
    local encoded = util.TableToJSON(data)
    local base = self:StorePath()
    file.CreateDir("helix/" .. Schema.folder .. "/" .. game.GetMap())
    -- Alternate complete snapshots. A truncated new slot cannot destroy the previous slot.
    local path = base .. (generation % 2) .. ".json"
    if encoded then file.Write(path, encoded) end
    if not encoded or file.Read(path, "DATA") ~= encoded then
        self.storageFault = true
        ErrorNoHalt("[Quest Director] Persistence failed; mutations blocked until restart and repair.\n")
        return false
    end
    self.generation = generation
    return true
end

function Q:Load()
    if self.loaded then return end
    local selected, present = nil, false
    for slot = 0, 1 do
        local raw = file.Read(self:StorePath() .. slot .. ".json", "DATA")
        present = present or raw ~= nil
        local ok, data = pcall(util.JSONToTable, raw or "")
        if ok and istable(data) and data.version == 1 and istable(data.defs) and istable(data.runs)
            and istable(data.states) and istable(data.placements) and isnumber(data.generation)
            and (not selected or data.generation > selected.generation) then selected = data end
    end
    if selected then
        for _, key in ipairs({"defs", "runs", "states", "placements", "zones", "audit", "serial", "generation"}) do
            if selected[key] ~= nil then self[key] = selected[key] end
        end
    elseif present then
        self.storageFault = true
        ErrorNoHalt("[Quest Director] Both saved snapshots are unreadable; refusing to replace them.\n")
    end
    self.loaded = true
end

function Q:SpawnPlacement(entry)
    local row = self.defs[entry.kind] and self.defs[entry.kind][entry.definition]
    if not row then return end
    local entity = self.entities[entry.id]
    if IsValid(entity) then entity:Remove() end
    entity = ents.Create(entry.kind == "npc" and "ix_quest_actor" or "ix_quest_object")
    if not IsValid(entity) then return end
    entity.ixQuestPlacement, entity.ixQuestDefinition = entry.id, entry.definition
    entity:SetModel(row.model)
    entity:SetPos(Vector(unpack(entry.pos))) entity:SetAngles(Angle(unpack(entry.ang)))
    entity:Spawn() entity:Activate() entity:ApplyDefinition(row)
    for key, value in pairs({questPlacement = entry.id, questDefinition = row.id, questCategory = row.category, questLabel = row.name, questEnabled = row.enabled}) do entity:SetNetVar(key, value) end
    self.entities[entry.id] = entity
    return entity
end

function Q:RestorePlacements()
    for _, entry in pairs(self.placements) do self:SpawnPlacement(entry) end
end

function PLUGIN:LoadData()
    Q:Load()
    timer.Simple(0, function() Q:RestorePlacements() end)
end
function PLUGIN:SaveData() if Q.loaded then Q:Save() end end
function PLUGIN:PlayerDisconnected(client)
    Q:FinishHeldPlacements(client)
    Q.sessions[client] = nil
    for id, group in pairs(Q.groups) do if Q:Player(group.leader) == client then Q.groups[id] = nil end end
end
function PLUGIN:PlayerLoadedCharacter(client) Q.sessions[client] = nil end
