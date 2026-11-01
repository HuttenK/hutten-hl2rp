-- Temporary listen-server capture. Run BEFORE drawing the weapon:
-- lua_openscript ix_height_damage_diagnostic.lua
-- Observes for 60 seconds; never changes health, height, damage or equipment.
if CLIENT then print("[Height audit] Use lua_openscript, without _cl.") return end
if ix.HeightDamageAudit then ix.HeightDamageAudit.Stop("restarted") end
local client
-- Player(1) is not necessarily the host on a multiplayer server.
for _, human in ipairs(player.GetHumans()) do
 if game.SinglePlayer() or human:IsListenServerHost() then client = human break end
end
if not IsValid(client) or not client:IsPlayer() or not client:IsAdmin() or not client:GetCharacter() then
 print("[Height audit] Load an admin character on a local/listen server first.") return
end

local A = {events = {}, started = CurTime(), enabled = true, dropped = 0}
ix.HeightDamageAudit = A
local character = client:GetCharacter()
local PLAYER = FindMetaTable("Player")
local oldCall, oldCritical = hook.Call, PLAYER.SetCriticalState
local folder = "ix_height_audit"
file.CreateDir(folder)
local path = folder .. "/" .. os.date("%Y%m%d-%H%M%S") .. ".json"

local function entityInfo(entity)
 if not IsValid(entity) then return {valid = false} end
 return {id = entity:EntIndex(), class = entity:GetClass(), model = entity:GetModel(), pos = entity:GetPos()}
end
local function snapshot()
 if not IsValid(client) or client:GetCharacter() ~= character then return {subjectGone = true} end
 local health = character:Health()
 local mins, maxs = client:GetHull()
 local duckMins, duckMaxs = client:GetHullDuck()
 local conditions = {}
 for _, diff in ipairs(health.hediffs or {}) do
  conditions[#conditions + 1] = {type = diff.uniqueID, part = diff.part, severity = diff.severity, tended = diff.tended_time}
 end
 return {height = ix.CharacterHeight.SavedHeight(client), scale = client:GetModelScale(), model = client:GetModel(),
  pos = client:GetPos(), velocity = client:GetVelocity(), hull = {mins, maxs}, duckHull = {duckMins, duckMaxs},
  health = client:Health(), critical = client:GetNetVar("crit", false), alive = client:Alive(),
  weapon = entityInfo(client:GetActiveWeapon()), raised = client:IsWepRaised(),
  head = health:GetPartHealth(2), torso = health:GetPartHealth(3), consciousness = health:GetConsciousness(),
  conditions = conditions}
end
local function record(kind, data)
 if not A.enabled then return end
 if #A.events >= 256 then table.remove(A.events, 1); A.dropped = A.dropped + 1 end
 A.events[#A.events + 1] = {time = CurTime() - A.started, kind = kind, data = data}
end
local function observe(fn, ...)
 local ok, err = pcall(fn, ...)
 if not ok then record("diagnostic_error", tostring(err)) end
end
local function damageInfo(damage)
 return {amount = damage:GetDamage(), type = damage:GetDamageType(), attacker = entityInfo(damage:GetAttacker()),
  inflictor = entityInfo(damage:GetInflictor()), pos = damage:GetDamagePosition(), force = damage:GetDamageForce()}
end
local function belongs(entity)
 return entity == client or (IsValid(entity) and entity.ixPlayer == client)
end

local function inspectHook(name, ...)
 local first, second, third = ...
 if name == "ShutDown" then A.Stop("shutdown")
 elseif (name == "EntityTakeDamage" or name == "CharacterBodyDamaged") and belongs(first) then
  record(name, {target = entityInfo(first), damage = damageInfo(second), state = snapshot()})
 elseif name == "PlayerSwitchWeapon" and first == client then
  record(name, {old = entityInfo(second), selected = entityInfo(third), state = snapshot()})
 elseif name == "ixCharacterHeightChanged" and first == client then
  record(name, snapshot())
 elseif name == "OnHediffAdded" and first.character == character then
  record(name, {type = second.uniqueID, part = second.part, severity = second.severity, state = snapshot()})
 end
end
-- Helix plugins run before ordinary hook.Add listeners and may return early.
-- Observe at entry, forwarding every argument/return without changing dispatch.
local watched = {EntityTakeDamage = true, CharacterBodyDamaged = true, PlayerSwitchWeapon = true,
 ixCharacterHeightChanged = true, OnHediffAdded = true, ShutDown = true}
local function call(name, gm, ...)
 if A.enabled and watched[name] then observe(inspectHook, name, ...) end
 return oldCall(name, gm, ...)
end
local function critical(self, state, ...)
 if A.enabled and self == client and state and not self:GetNetVar("crit") then
  observe(function() record("enter_critical", {trace = debug.traceback("", 2), state = snapshot()}) end)
 end
 return oldCritical(self, state, ...)
end

function A.Stop(reason)
 if not A.enabled then return end
 observe(function() record("end", {reason = reason, state = snapshot()}) end)
 A.enabled = false
 timer.Remove("ixHeightDamageAudit")
 if hook.Call == call then hook.Call = oldCall end
 if PLAYER.SetCriticalState == critical then PLAYER.SetCriticalState = oldCritical end
 if ix.HeightDamageAudit == A then ix.HeightDamageAudit = nil end
 file.Write(path, util.TableToJSON({character = character:GetID(), events = A.events, dropped = A.dropped}, true))
 print("[Height audit] Saved data/" .. path)
end
hook.Call, PLAYER.SetCriticalState = call, critical
observe(function() record("start", snapshot()) end)
timer.Create("ixHeightDamageAudit", 1, 60, function()
 observe(function() record("sample", snapshot()) end)
 if not IsValid(client) or client:GetCharacter() ~= character then A.Stop("character_left")
 elseif timer.RepsLeft("ixHeightDamageAudit") == 0 or CurTime() - A.started >= 60 then A.Stop("complete") end
end)
print("[Height audit] Recording for 60 seconds. Select the AK normally; the report saves automatically.")
