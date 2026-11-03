local M = ix.Medicine
util.AddNetworkString("ixMedicalProgress")
M.activeSessions = M.activeSessions or {}
-- Recover existing sessions on Lua refresh; steady-state Think only visits
-- active treatments, while retaining their original per-tick validation.
for _, client in ipairs(player.GetAll()) do
 if client.ixMedicalSession then M.activeSessions[client]=client.ixMedicalSession end
end

-- Health:Sync has an unfinished generic char-var codec in this schema.
-- Use the injury protocol already consumed by the limb HUD instead.
function M.Sync(health)
 for _, diff in health:GetHediffs() do
  net.Start("hediff.update")
  net.WriteUInt(health:GetCharacter():GetID(), 32)
  net.WriteUInt(diff.id, 16)
  diff:Send()
  net.Send(health:GetPlayer())
 end
end

function M.Owns(client, item)
 for _, owned in pairs(client:GetItems()) do if owned == item then return true end end
 return false
end

function M.PatientEntity(target)
 local display = ix.PushCart and ix.PushCart.PatientDisplay and ix.PushCart:PatientDisplay(target)
 if display then return display end
 if IsValid(target.ixRagdoll) then return target.ixRagdoll end
 local doll = target:GetNetVar("doll")
 if doll and IsValid(Entity(doll)) then return Entity(doll) end
 return target
end

function M.Reachable(client, target)
 if client == target then return true end
 if ix.PushCart and ix.PushCart.PatientCart and ix.PushCart:PatientCart(target) then
  return ix.PushCart:PatientReachable(client,target,128)
 end
 local entity = M.PatientEntity(target)
 local point = entity:NearestPoint(client:GetShootPos())
 if client:GetShootPos():DistToSqr(point) > 128 * 128 then return false end
 local trace = util.TraceLine({start=client:GetShootPos(), endpos=point, filter=client, mask=MASK_SOLID})
 return not trace.Hit or trace.Entity == entity or trace.Entity == target
end

function M.ResolveTarget(client)
 local trace = util.TraceLine({start=client:GetShootPos(), endpos=client:GetShootPos()+client:GetAimVector()*96, filter=client})
 local ent = (ix.PushCart and ix.PushCart.TracePatient and ix.PushCart:TracePatient(client,96)) or trace.Entity
 if IsValid(ent) and ent:IsPlayer() then return ent end
 if IsValid(ent) and IsValid(ent.ixPlayer) then return ent.ixPlayer end
 if IsValid(ent) then
  for _, target in ipairs(player.GetAll()) do if M.PatientEntity(target) == ent then return target end end
 end
end

function M.Injuries(health, def, hitgroup)
 local result = {}
 local missing = ix.Amputation and ix.Amputation.GetLimb(health.character)
 for _, diff in health:GetHediffs() do
  local part = health.body.parts[diff.part]
  local matches = not hitgroup or hitgroup == 0 or (part and part.hitgroup == hitgroup)
  if matches and diff.isInjury and diff:GetSeverity() > 0 then
   -- Stump wounds must remain treatable so pain/bleeding cannot trap an
   -- amputee in critical state. Healing never clears the amputation flag.
   if missing and part and missing.hitgroup == part.hitgroup and def.kind == "splint" then continue end
   if def.kind == "splint" then
    if diff.isFracture then result[#result+1] = diff end
   elseif not diff.isFracture and (def.kind ~= "bandage" or ((diff.bleedRate or 0) > 0 and diff.tended_time == -1)) then
    result[#result+1] = diff
   end
  end
 end
 table.sort(result, function(a,b)
  if a.isFracture ~= b.isFracture then return a.isFracture == true end
  return a:GetSeverity() > b:GetSeverity()
 end)
 return result
end

function M.Eligible(item, target, hitgroup)
 local health = target:GetCharacter():Health()
 local def = M.Catalog[item.uniqueID]
 if not def then return false, "Неизвестное лечебное средство." end
 if def.kind == "blood" then
  for _, diff in health:GetHediffs() do
   if diff.uniqueID == "bleeding" and diff:GetSeverity() > 0 then return true end
  end
  return false, "Запас крови уже полон."
 end
 if #M.Injuries(health, def, hitgroup) == 0 then return false, "Нет подходящей травмы для этого средства." end
 return true
end

function M.Apply(item, target, medic, hitgroup)
 local health = target:GetCharacter():Health()
 local def = M.Catalog[item.uniqueID]
 if not def then return {} end
 local healed = 0
 if def.kind == "blood" then
  local losses = {}
  for _, diff in health:GetHediffs() do
   if diff.uniqueID == "bleeding" then losses[#losses + 1] = diff end
  end
  for _, diff in ipairs(losses) do
   local before = math.Clamp(diff:GetSeverity(), 0, 1)
   local remaining = math.max(0, before - def.blood)
   healed = math.max(healed, before - remaining)
   -- Keep a zero-severity tracker while wounds still bleed, otherwise further
   -- blood loss would stop until another hit creates the tracker again.
   if remaining <= 0 and health:GetBleedRate() < 0.1 then health:RemoveHediffByID(diff.id)
   else diff:SetSeverity(remaining) end
  end
  health.bloodloss = nil
  for _, diff in health:GetHediffs() do
   if diff.uniqueID == "bleeding" then health.bloodloss = true break end
  end
  health:OnUpdateDiffs(); M.Sync(health)
  return {blood=healed}
 end
 local budget = def.healing or 0
 -- Volume is spent on actual healing, including a partial final dose.
 if def.capacity then budget = math.min(budget, item:GetUses()) end
 local injuries = M.Injuries(health, def, hitgroup)
 if def.kind == "splint" and injuries[1] then
  hitgroup = health.body.parts[injuries[1].part].hitgroup
  injuries = M.Injuries(health, def, hitgroup)
 end
 for _, diff in ipairs(injuries) do
  if diff.isFracture and def.kind == "splint" then
   health:RemoveHediffByID(diff.id)
  elseif def.kind == "bandage" then
   diff:SetSeverity(diff:GetSeverity())
   health:TendHediff(diff, 0) -- Also transmit the dressed state to the limb HUD.
  elseif def.kind == "restore" and budget > 0 then
   local amount = math.min(diff:GetSeverity(), budget)
   local remaining = diff:GetSeverity() - amount
   healed, budget = healed + amount, budget - amount
   if remaining <= 0 then health:RemoveHediffByID(diff.id)
   else
    -- Convert an old timed dressing to its current severity before changing
    -- it, so repeated doses cannot multiply away injuries or restart bleeding.
    local dressed = diff.tended_time ~= -1
    diff:SetSeverity(remaining)
    if dressed then health:TendHediff(diff, 0) end
   end
  end
 end
 health:OnUpdateDiffs()
 health:GetBleedRate()
 M.Sync(health)
 return {dmg=healed, resourceCost=def.capacity and healed or nil}
end

function M.ValidSession(client, session)
 local target, item = session.target, session.item
 return IsValid(client) and client:Alive() and client:GetCharacter() == session.character and
  not IsValid(client.ixRagdoll) and not client:InCriticalState() and not client:IsRestricted() and
  IsValid(target) and target:Alive() and target:GetCharacter() == session.patient and
  not client.ixAmputationBusy and not target.ixAmputationBusy and
  item.inUse == client and M.Owns(client, item) and item:GetUses() > 0 and M.Reachable(client, target)
end

function M.AnnounceTreatment(client,session)
 if session.emoteStarted or client.ixMedicalSession~=session or not M.ValidSession(client,session) then return end
 session.emoteStarted=true
 hook.Run("MedicalTreatmentStarted",client,session)
end

function M.Finish(client, success)
 local session = client.ixMedicalSession
 if not session or session.finishing then return end
 session.finishing = true
 success = success and M.ValidSession(client, session) and M.Eligible(session.item, session.target, session.hitgroup)
 if session.weapon and client:GetActiveWeapon() ~= session.weapon then success=false end
 local item = session.item
 if success then
  local data = M.Apply(item, session.target, client, session.hitgroup)

  local uses = item:GetUses()
  local cost = data.resourceCost or 1
  if uses <= cost + 0.000001 then
   local junk, id = item.junk, item.uniqueID
   item:Remove(true)
   if junk then
    local replacement = ix.Item:Instance(junk, {class=id})
    if replacement and not client:AddItem(replacement) then ix.Item:Spawn(client, nil, replacement) end
   end
  else
   if item.SetResource then item:SetResource(uses-cost)
   elseif M.Catalog[item.uniqueID] and M.Catalog[item.uniqueID].capacity then item:SetData("volume",uses-cost)
   else item:SetData("uses", uses-cost) end
  end
  client:Notify("Лечение завершено.")
 else
  client:Notify("Лечение прервано. Средство не израсходовано.")
 end
 item.inUse = nil
 client.ixMedicalSession, client.bUsingMedical = nil, false
 M.activeSessions[client] = nil
 client.ixMedicalCleanup = true
 client:SetAction()
 net.Start("ixMedicalProgress") net.WriteString("") net.WriteFloat(0) net.Send(client)
 -- Do not recursively remove a weapon while its Holster is running.
 timer.Simple(0, function()
  if not IsValid(client) then return end
  client.ixMedicalCleanup = nil
  local active = client:GetActiveWeapon()
  local restore = success or active == session.weapon or not IsValid(active)
  if IsValid(session.weapon) then session.weapon:Remove() end
  if restore and client:GetCharacter() == session.character then
   if IsValid(session.previous) and M.CanUseWeapon(client, session.previous) then client:SelectWeapon(session.previous:GetClass())
   elseif IsValid(client:GetWeapon("ix_hands")) then client:SelectWeapon("ix_hands") end
  end
 end)
end

function M.Begin(item, target, hitgroup)
 local client = item.player
 if not IsValid(client) or not client:GetCharacter() or client.bUsingMedical or client.ixMedicalCleanup or item.inUse or not M.Owns(client, item) then return false end
 if not IsValid(target) or not target:IsPlayer() or not target:GetCharacter() then
  client:Notify("Для лечения другого человека подойдите и посмотрите на него.") return false
 end
 hitgroup = tonumber(hitgroup) or 0
 if hitgroup ~= math.floor(hitgroup) or hitgroup < 0 or hitgroup > 7 then return false end
 local session = {item=item, target=target, hitgroup=hitgroup, character=client:GetCharacter(), patient=target:GetCharacter(), previous=client:GetActiveWeapon()}
 item.inUse = client
 if not M.ValidSession(client, session) then item.inUse=nil return false end
 local eligible, reason = M.Eligible(item, target, hitgroup)
 if not eligible then item.inUse=nil client:Notify(reason) return false end
 local def = M.Catalog[item.uniqueID]
 client.bUsingMedical, client.ixMedicalSession = true, session
 M.activeSessions[client] = session
 session.rate = 1
 session.started, session.deadline = CurTime(), CurTime() + 120
 session.ends = CurTime() + math.max(3, item.stats.time or 10)
 if client:IsWepRaised() then client:ToggleWepRaised() end
 M.AnnounceTreatment(client, session)
 net.Start("ixMedicalProgress") net.WriteString(item:GetName()) net.WriteFloat(session.ends and session.ends-CurTime() or 0) net.Send(client)
 return false
end

hook.Add("Think", "ixMedicalSessions", function()
 for client, tracked in pairs(M.activeSessions) do
  if not IsValid(client) then
   if tracked.item.inUse==client then tracked.item.inUse=nil end
   M.activeSessions[client]=nil
   continue
  end
  local s = client.ixMedicalSession
  if s then
   if ix.performance then ix.performance.Count("medical_session_checks") end
   local invalid = not M.ValidSession(client, s) or CurTime() > s.deadline or client:KeyDown(IN_RELOAD)
   if s.weapon and (not IsValid(s.weapon) or (CurTime() > s.selectDeadline and client:GetActiveWeapon() ~= s.weapon)) then invalid=true end
   if invalid then M.Finish(client, false)
   elseif s.ends and CurTime() >= s.ends then M.Finish(client, true) end
  else M.activeSessions[client]=nil end
 end
end)

hook.Add("PlayerDisconnected", "ixMedicalCleanup", function(client)
 M.activeSessions[client]=nil
 local s = client.ixMedicalSession
 if s then s.item.inUse=nil client.ixMedicalSession=nil client.bUsingMedical=false end
end)
