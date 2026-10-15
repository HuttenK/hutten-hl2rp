local C = ix.SCPCompat
C.stuns = C.stuns or {}

local function updateStun(client, entries)
    local untilTime = 0
    for i = #entries, 1, -1 do
        if entries[i] <= CurTime() then table.remove(entries, i) else untilTime = math.max(untilTime, entries[i]) end
    end
    if IsValid(client) then client:SetNW2Float("ixSCPStunUntil", untilTime) end
    C.stuns[client] = #entries > 0 and entries or nil
end

function C.Freeze(client, value)
    if not IsValid(client) then return end
    local entries = C.stuns[client] or {}
    if value == true then entries[#entries + 1] = CurTime() + 5 -- Safety expiry if an addon loses its release timer.
    elseif isnumber(value) and value > 0 and value < math.huge then entries[#entries + 1] = CurTime() + math.min(value, 30)
    elseif value == false then table.remove(entries, 1) end
    updateStun(client, entries)
end
timer.Create("ixSCPStuns", .1, 0, function()
    for client, entries in pairs(C.stuns) do
        if IsValid(client) and client:Alive() then updateStun(client, entries) else C.stuns[client] = nil end
    end
end)
local function clearStun(client)
    C.stuns[client] = nil
    if IsValid(client) then client:SetNW2Float("ixSCPStunUntil", 0) end
end
hook.Add("PlayerSpawn", "ixSCPStun", clearStun)
hook.Add("PlayerDeath", "ixSCPStun", clearStun)
hook.Add("PrePlayerLoadedCharacter", "ixSCPStun", clearStun)
hook.Add("PlayerDisconnected", "ixSCPStun", clearStun)

function C.Hit939(npc, entities)
    for _, target in ipairs(entities) do
        if IsValid(target) then
            target:EmitSound(npc:SelectFromTable(npc.tbl_Sounds.Crunch), 90, 100)
            if target:IsPlayer() then
                target:SetDSP(32, false)
                target:CPT_Freeze(true)
                timer.Simple(.6, function() if IsValid(target) then target:CPT_Freeze(false) end end)
                local eyes = target:GetAttachment(target:LookupAttachment("eyes"))
                CPT_ParticleEffect("blood_impact_red_01", eyes and eyes.Pos or target:EyePos(), AngleRand())
            end
        end
    end
    npc:EmitSound(npc:SelectFromTable(npc.tbl_Sounds.Strike), 90, 100)
end

function C.PatchEntity(npc)
    if not IsValid(npc) or not npc.IsCPTBase_NPC then return end
    if ix.SCPMedicine and ix.SCPMedicine.Patch then ix.SCPMedicine.Patch(npc) end
    if npc.ControlNPC ~= C.ControlNPC then npc.ControlNPC = C.ControlNPC end
    if npc.ControlMovement ~= C.ControlMovement and isfunction(npc.ControlMovement) then
        -- AutoRefresh creates a new wrapper function. Never save the previous
        -- wrapper as the original or it recurses on the next control tick.
        if not npc.ixCPTOriginalMovement then npc.ixCPTOriginalMovement = npc.ControlMovement end
        npc.ControlMovement = C.ControlMovement
    end
    if not npc.ixCPTOriginalRelationship and isfunction(npc.GetRelationship) then
        npc.ixCPTOriginalRelationship = npc.GetRelationship
        npc.GetRelationship = function(self, target)
            if not self.MemoryTable then return D_NU end
            return self:ixCPTOriginalRelationship(target)
        end
    end
    if not npc.ixCPTOriginalAim and isfunction(npc.Possess_AimTarget) then
        npc.ixCPTOriginalAim = npc.Possess_AimTarget
        npc.Possess_AimTarget = function(self)
            if self.IsPossessed then return self:GetPossessorAimPos() or self:GetPos() + self:GetForward() * 1024 end
            return self:ixCPTOriginalAim()
        end
    end
    if not npc.ixCPTOriginalTrace and isfunction(npc.Possess_EyeTrace) then
        npc.ixCPTOriginalTrace = npc.Possess_EyeTrace
        npc.Possess_EyeTrace = function(self)
            local owner = self.GetCameraOwner and self:GetCameraOwner()
            local controller = IsValid(owner) and owner:GetPossessor() or self:GetPossessor()
            local aim = IsValid(owner) and owner:GetPossessorAimPos() or self:GetPossessorAimPos()
            return util.TraceLine({start = self:GetPos() + self:OBBCenter(),
                endpos = aim or self:GetPos() + self:GetForward() * 1024, filter = {self, owner, controller}})
        end
    end
    if npc:GetClass():match("^npc_cpt_scp_939_[abc]$") then npc.OnHitEntity = C.Hit939 end
    if npc:GetClass() == "npc_cpt_scp_079" and not npc.ixCPTOriginalToggle then
        npc.ixCPTOriginalToggle = npc.ToggleCamera
        npc.ToggleCamera = function(self, index)
            local cameras = {}
            for _, camera in ipairs(self.tbl_Cameras or {}) do if IsValid(camera) then cameras[#cameras + 1] = camera end end
            self.tbl_Cameras = cameras
            if #cameras == 0 then return end
            self:SetCurrentCamera(cameras[((tonumber(index) or 1) - 1) % #cameras + 1])
        end
    end
end

function C.Install()
    if not CPTBase then return end
    if ix.SCPMedicine and ix.SCPMedicine.Install then ix.SCPMedicine.Install() end
    local playerMeta = FindMetaTable("Player")
    if not playerMeta.CPT_Freeze then playerMeta.CPT_Freeze = C.Freeze end
    if playerMeta.CPT_CreateRagdolledPlayer and not C.originalKnockdown then
        C.originalKnockdown = playerMeta.CPT_CreateRagdolledPlayer
        playerMeta.CPT_CreateRagdolledPlayer = function(client, velocity, caller)
            if not client:GetCharacter() then return C.originalKnockdown(client, velocity, caller) end
            if not client:Alive() or client:GetNetVar("crit", false) or IsValid(client.ixRagdoll) or C.Controlled(client) then return end
            -- Use the schema's single body and weapon restore path. CPT's old
            -- knockdown creates another body and kills/respawns on getting up.
            client:SetRagdolled(true, 3, 3)
        end
    end
    util.AddNetworkString("CPTBase_Possessor_HitPos")
    net.Receive("CPTBase_Possessor_HitPos", C.ReceiveAim)
    for _, npc in ipairs(ents.GetAll()) do C.PatchEntity(npc) end
end

function PLUGIN:OnEntityCreated(entity)
    C.PatchEntity(entity)
    timer.Simple(0, function() C.PatchEntity(entity) end)
end
hook.Add("InitPostEntity", "ixSCPCompatibility", C.Install)
hook.Add("OnReloaded", "ixSCPCompatibility", C.Install)
timer.Simple(0, C.Install)

concommand.Add("ix_scp_compat_status", function(client)
    if IsValid(client) and not client:IsAdmin() then return end
    local count = 0
    for _ in pairs(C.sessions) do count = count + 1 end
    local message = "[SCP compatibility " .. C.version .. "] CPTBase=" .. tostring(CPTBase ~= nil)
        .. " | player stun=" .. tostring(FindMetaTable("Player").CPT_Freeze ~= nil)
        .. " | animation file=" .. tostring(file.Exists("weapons/weapon_cpt_base/sh_anim.lua", "LUA"))
        .. " | controllers=" .. count
    if IsValid(client) then client:PrintMessage(HUD_PRINTCONSOLE, message) else print(message) end
end)
