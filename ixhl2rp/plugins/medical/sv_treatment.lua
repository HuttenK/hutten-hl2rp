local M = ix.Medicine
util.AddNetworkString("ixMedicalProgress")

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
 if IsValid(target.ixRagdoll) then return target.ixRagdoll end
 local doll = target:GetNetVar("doll")
 if doll and IsValid(Entity(doll)) then return Entity(doll) end
 return target
end

function M.Reachable(client, target)
 if client == target then return true end
 local entity = M.PatientEntity(target)
 local point = entity:NearestPoint(client:GetShootPos())
 if client:GetShootPos():DistToSqr(point) > 128 * 128 then return false end
 local trace = util.TraceLine({start=client:GetShootPos(), endpos=point, filter=client, mask=MASK_SOLID})
 return not trace.Hit or trace.Entity == entity or trace.Entity == target
end

function M.ResolveTarget(client)
 local trace = util.TraceLine({start=client:GetShootPos(), endpos=client:GetShootPos()+client:GetAimVector()*96, filter=client})
 local ent = trace.Entity
 if IsValid(ent) and ent:IsPlayer() then return ent end
 if IsValid(ent) and IsValid(ent.ixPlayer) then return ent.ixPlayer end
 if IsValid(ent) then
  for _, target in ipairs(player.GetAll()) do if M.PatientEntity(target) == ent then return target end end
 end
end

function M.Injuries(health, def, hitgroup)
 local result = {}
 for _, diff in health:GetHediffs() do
  local part = health.body.parts[diff.part]
  local matches = not hitgroup or hitgroup == 0 or (part and part.hitgroup == hitgroup)
  if matches and diff.isInjury and diff:GetSeverity() > 0 then
   if def.kind == "splint" or def.kind == "surgery" then
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

-- Build a fresh, non-mutating budget at completion; never trust client costs.
function M.VolumePlan(item, health, hitgroup)
 local def=M.Catalog[item.uniqueID]
 local remaining=item:GetUses()
 local plan={cost=0, actions={}}
 local injuries=M.Injuries(health,def,hitgroup)
 if def.kind=="surgery" and injuries[1] then
  injuries=M.Injuries(health,def,health.body.parts[injuries[1].part].hitgroup)
 end
 local function spend(cost) remaining=remaining-cost; plan.cost=plan.cost+cost end
 for _,diff in ipairs(injuries) do
  local action={diff=diff,heal=0}
  if diff.isFracture then
   if def.kind=="surgery" and remaining>=def.fractureCost then
    action.fracture=true; spend(def.fractureCost)
   end
  else
   local bleeding=(diff.bleedRate or 0)>0 and diff.tended_time==-1
   if bleeding and remaining>=def.bleedCost then
    action.bandage=true; spend(def.bleedCost); bleeding=false
   end
   -- A kit cannot evade the dressing cost by healing an untreated bleed.
   if not bleeding then
    action.heal=math.min(diff:GetSeverity(),remaining/def.hpCost)
    spend(action.heal*def.hpCost)
   end
  end
  if action.fracture or action.bandage or action.heal>0 then plan.actions[#plan.actions+1]=action end
 end
 return plan
end

function M.Eligible(item, target, hitgroup)
 local health = target:GetCharacter():Health()
 local def = M.Catalog[item.uniqueID]
 if not def then
  if item.uniqueID == "bloodbag_empty" then
   if target:InCriticalState() or health:GetBleedRate() > 0 then return false, "Нельзя брать кровь при кровотечении или критическом состоянии." end
   for _, diff in health:GetHediffs() do
    if diff.uniqueID == "bleeding" and diff:GetSeverity() > .1 then return false, "Недостаточный запас крови для донорства." end
   end
  elseif item.uniqueID == "bloodbag" or item.uniqueID == "ivbag" then
   for _, diff in health:GetHediffs() do if diff.uniqueID == "bleeding" and diff:GetSeverity() > 0 then return true end end
   return false, "Переливание не требуется."
  end
  return true
 end
 if def.capacity then
  if M.VolumePlan(item,health,hitgroup).cost<=0 then return false, "Нет подходящей травмы или недостаточно запаса средства." end
  return true
 end
 if def.pain then return true end
 if #M.Injuries(health, def, hitgroup) == 0 then return false, "Нет подходящей травмы для этого средства." end
 return true
end

function M.Apply(item, target, medic, hitgroup)
 local health = target:GetCharacter():Health()
 local def = M.Catalog[item.uniqueID]
 if not def then
  local data = item:OnConsume(target, medic ~= target and medic or nil, 1, target:GetCharacter()) or {}
  health:OnUpdateDiffs()
  health:GetBleedRate()
  M.Sync(health)
  return data
 end
 if def.capacity then
  local plan=M.VolumePlan(item,health,hitgroup)
  local healed=0
  for _,action in ipairs(plan.actions) do
   local diff=action.diff
   if action.fracture then health:RemoveHediffByID(diff.id)
   else
    local remaining=math.max(0,diff:GetSeverity()-action.heal)
    healed=healed+action.heal
    if remaining<=0 then health:RemoveHediffByID(diff.id)
    else
     -- Rebase a previously regenerating injury before stopping its timer.
     diff:SetSeverity(remaining)
     if action.bandage or diff.tended_time~=-1 then diff.tended_time=0; diff.tended_start=os.time() end
    end
   end
  end
  health:OnUpdateDiffs(); health:GetBleedRate(); M.Sync(health)
  return {dmg=healed,resourceCost=plan.cost}
 end
 local healed = 0
 local skill = math.Clamp(tonumber(medic:GetCharacter():GetSkillModified("medicine")) or 0, 0, 10)
 local injuries = M.Injuries(health, def, hitgroup)
 if (def.kind == "surgery" or def.kind == "splint") and injuries[1] then
  hitgroup = health.body.parts[injuries[1].part].hitgroup
  injuries = M.Injuries(health, def, hitgroup)
 end
 for index, diff in ipairs(injuries) do
  if index > (def.wounds or 1) then break end
  if diff.isFracture and (def.kind=="splint" or def.kind=="surgery") then
   health:RemoveHediffByID(diff.id)
  elseif def.kind == "bandage" then
   diff:SetSeverity(diff:GetSeverity()); diff.tended_time=0; diff.tended_start=os.time()
  elseif def.wounds then
   local amount = math.min(diff:GetSeverity(), 10 + skill)
   local remaining = diff:GetSeverity() - amount
   healed = healed + amount
   if remaining <= 0 then health:RemoveHediffByID(diff.id)
   else diff:SetSeverity(remaining) health:TendHediff(diff, math.floor(180 / (1 + skill * .05))) end
  end
 end
 if def.pain then
  -- Refresh rather than stack analgesics; expiry is persisted in the existing medical hediff.
  local old = {}
  for _, diff in health:GetHediffs() do if diff.uniqueID == "painkiller" then old[#old+1] = diff.id end end
  for _, id in ipairs(old) do health:RemoveHediffByID(id) end
  health:AddHediff("painkiller", 0, {severity=10, tended_start=os.time(), tended_time=def.pain})
 end
 if def.kind == "stimulant" then
  health:AddHediff("epinephrine", 0, {severity=100, tended_start=os.time(), tended_time=90})
 end
 health:OnUpdateDiffs()
 health:GetBleedRate()
 M.Sync(health)
 return {dmg=healed}
end

function M.ValidSession(client, session)
 local target, item = session.target, session.item
 return IsValid(client) and client:Alive() and client:GetCharacter() == session.character and
  not IsValid(client.ixRagdoll) and not client:InCriticalState() and not client:IsRestricted() and
  IsValid(target) and target:Alive() and target:GetCharacter() == session.patient and
  item.inUse == client and M.Owns(client, item) and item:GetUses() > 0 and M.Reachable(client, target)
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
  session.character:DoAction(session.target == client and "healing" or "healingTarget", data)
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
 if def and not file.Exists(M.Model(def, true), "GAME") then
  item.inUse=nil client:Notify("Не установлены модели EFT Medicine. Лечение не начато.") return false
 end
 client.bUsingMedical, client.ixMedicalSession = true, session
 session.rate = math.Clamp(1 + (tonumber(session.character:GetSkillModified("medicine")) or 0) * .025, 1, 1.25)
 session.started, session.deadline = CurTime(), CurTime() + 120
 if def then
  session.plan = M.AnimationPlan(def)
  local weapon = client:Give("ix_med_"..item.uniqueID, true)
  if not IsValid(weapon) then M.Finish(client, false) return false end
  session.weapon = weapon
  session.selectDeadline = CurTime() + 2
  client:SelectWeapon(weapon:GetClass())
  if client:GetActiveWeapon() == weapon and not weapon.medNext then weapon:Deploy() end
  -- Engine prediction/selection may not call Deploy until the next command.
 else
  session.ends = CurTime() + math.max(3, (item.stats.time or 10) / session.rate)
  if client:IsWepRaised() then client:ToggleWepRaised() end
  client:EmitSound("items/medshot4.wav", 55)
 end
 net.Start("ixMedicalProgress") net.WriteString(item:GetName()) net.WriteFloat(session.ends and session.ends-CurTime() or 0) net.Send(client)
 return false
end

hook.Add("Think", "ixMedicalSessions", function()
 for _, client in ipairs(player.GetAll()) do
  local s = client.ixMedicalSession
  if s then
   local invalid = not M.ValidSession(client, s) or CurTime() > s.deadline or client:KeyDown(IN_RELOAD)
   if s.weapon and (not IsValid(s.weapon) or (CurTime() > s.selectDeadline and client:GetActiveWeapon() ~= s.weapon)) then invalid=true end
   if invalid then M.Finish(client, false)
   elseif s.ends and CurTime() >= s.ends then M.Finish(client, true) end
  end
 end
end)

hook.Add("PlayerDisconnected", "ixMedicalCleanup", function(client)
 local s = client.ixMedicalSession
 if s then s.item.inUse=nil client.ixMedicalSession=nil client.bUsingMedical=false end
end)
