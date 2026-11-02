local A = ix.AOC

function A.Sequence(client, entry)
 if entry == nil then return end
 local model, count = client:GetModel(), client:GetSequenceCount()
 local cache = client.ixAOCSequences
 if not cache or cache.model ~= model or cache.count ~= count or cache.revision ~= A.revision then
  cache = {model = model, count = count, revision = A.revision, entries = {}}
  client.ixAOCSequences = cache
 end
 local sequence = cache.entries[entry]
 if sequence == nil then
  if isstring(entry) then sequence = client:LookupSequence(entry)
  elseif isnumber(entry) and entry >= 0 then sequence = client:SelectWeightedSequence(entry) end
  sequence = isnumber(sequence) and sequence >= 0 and sequence or -1
  cache.entries[entry] = sequence
 end
 if sequence >= 0 then return sequence end
end

local function Blocked(client)
 return client:InVehicle() or client:GetNetVar("forcedSequence") ~= nil or
  (ix.Downed and ix.Downed.Active and ix.Downed.Active(client)) or
  (client.IsProne and client:IsProne())
end

function A.WalkSequences(client, entry)
 -- AoC maps WALK and RUN to the same running sequence. Its *_mod clips
 -- contain the authored upper-body hold with zero weights on all leg bones.
 if not isstring(entry) or not entry:find("^wos_aoc_run_") then return end
 local upper = A.Sequence(client, entry .. "_mod")
 if upper == nil then return end
 local walk = A.Sequence(client, "walk_all") or A.Sequence(client, ACT_HL2MP_WALK) or A.Sequence(client, ACT_WALK)
 if walk ~= nil then return walk, upper end
end

local walkSlot = GESTURE_SLOT_GRENADE -- AoC attacks/blocks use ATTACK_AND_RELOAD; draw uses CUSTOM.
local actionSlots = {GESTURE_SLOT_ATTACK_AND_RELOAD, GESTURE_SLOT_CUSTOM}
function A.ClearWalkLayer(client)
 local sequence = client.ixAOCWalkLayer
 if sequence == nil then return end
 if client:IsValidLayer(walkSlot) and client:GetLayerSequence(walkSlot) == sequence then
  client:AnimResetGestureSlot(walkSlot)
 end
 client.ixAOCWalkLayer = nil
end

function A.UpdateWalkLayer(client)
 local weapon, base = client.ixAOCWalkWeapon, client.ixAOCWalkBase
 if base == nil or not client:Alive() or Blocked(client) or client:GetMoveType() == MOVETYPE_NOCLIP or
  not IsValid(weapon) or client:GetActiveWeapon() ~= weapon or client:GetSequence() ~= base or
  client:GetModel() ~= client.ixAOCWalkModel or client.ixAOCWalkRevision ~= A.revision or
  (client.ixAOCWalkActionWeapon == weapon and (client.ixAOCWalkActionUntil or 0) > CurTime()) then
  A.ClearWalkLayer(client)
  return
 end
 -- Do not let the resting grip cover a swing, block, draw or another gesture.
 for _, slot in ipairs(actionSlots) do
  if client:IsValidLayer(slot) and client:GetLayerWeight(slot) > 0 then
   A.ClearWalkLayer(client)
   return
  end
 end
 local upper = client.ixAOCWalkUpper
 if client.ixAOCWalkLayer ~= upper or client.ixAOCWalkLayerModel ~= client:GetModel() or
  client.ixAOCWalkLayerRevision ~= A.revision then A.ClearWalkLayer(client) end
 local active = client:IsValidLayer(walkSlot) and client:GetLayerWeight(walkSlot) > 0
 if active and client.ixAOCWalkLayer == nil then return end -- Do not steal another addon's active slot.
 -- The authored "upper-body" running clip also has full pelvis weight.
 -- Even phase-locked to walk_all it makes the whole body bounce. Use a
 -- stationary grip pose; locomotion still comes from the walking leg bones.
 local cycle = 0
 if not active then
  client:AddVCDSequenceToGestureSlot(walkSlot, upper, cycle, false)
  client.ixAOCWalkLayer = upper
  client.ixAOCWalkLayerModel = client:GetModel()
  client.ixAOCWalkLayerRevision = A.revision
 elseif client:GetLayerSequence(walkSlot) ~= upper then
  client.ixAOCWalkLayer = nil
  return
 end
 -- Neither time nor the walking phase should advance the running pelvis.
 client:SetLayerPlaybackRate(walkSlot, 0)
 client:SetLayerCycle(walkSlot, cycle)
 client:AnimSetGestureWeight(walkSlot, 1)
end

function A.MainActivity(client, activity)
 client.ixAOCWalkBase = nil
 local weapon = client:GetActiveWeapon()
 if not IsValid(weapon) or not weapon.AOC_Base or Blocked(client) or
  client:GetMoveType() == MOVETYPE_NOCLIP then return end
 A.Prepare(weapon)
 local entry = weapon.ActivityTranslate and weapon.ActivityTranslate[activity]
 if activity == ACT_MP_WALK then
  local walk, upper = A.WalkSequences(client, entry)
  if walk ~= nil then
   client.ixAOCWalkBase, client.ixAOCWalkUpper = walk, upper
   client.ixAOCWalkWeapon, client.ixAOCWalkModel = weapon, client:GetModel()
   client.ixAOCWalkRevision = A.revision
   return nil, walk
  end
 end
 local sequence = A.Sequence(client, entry)
 if sequence ~= nil then
  -- A named override must win over ACT_MP_* even for NPC-style SD models.
  return isnumber(entry) and entry or nil, sequence
 end
end

local function Play(client, weapon, activity, slot, looping)
 local entry = weapon.ActivityTranslate and weapon.ActivityTranslate[activity]
 local sequence = A.Sequence(client, entry)
 if sequence == nil then return end
 A.ClearWalkLayer(client)
 client.ixAOCWalkActionWeapon = weapon
 client.ixAOCWalkActionUntil = CurTime() + client:SequenceDuration(sequence)
 client:AddVCDSequenceToGestureSlot(slot or GESTURE_SLOT_ATTACK_AND_RELOAD, sequence, 0, not looping)
 return client:SequenceDuration(sequence)
end

function A.AnimationEvent(client, event, data)
 local weapon = client:GetActiveWeapon()
 if not IsValid(weapon) or not weapon.AOC_Base then return end
 if Blocked(client) then return ACT_INVALID end
 A.Prepare(weapon)
 local custom = event == PLAYERANIMEVENT_CUSTOM_GESTURE
 local action = custom and data or event
 local crouch = client:Crouching()
 local activity
 if action == PLAYERANIMEVENT_ATTACK_PRIMARY then
  activity = crouch and ACT_MP_ATTACK_CROUCH_PRIMARYFIRE or ACT_MP_ATTACK_STAND_PRIMARYFIRE
 elseif action == PLAYERANIMEVENT_ATTACK_SECONDARY then
  activity = crouch and ACT_MP_ATTACK_CROUCH_SECONDARYFIRE or ACT_MP_ATTACK_STAND_SECONDARYFIRE
 elseif action == PLAYERANIMEVENT_ATTACK_GRENADE then
  activity = crouch and ACT_MP_ATTACK_CROUCH_GRENADE or ACT_MP_ATTACK_STAND_GRENADE
 elseif action == PLAYERANIMEVENT_RELOAD then
  activity = crouch and ACT_MP_RELOAD_CROUCH or ACT_MP_RELOAD_STAND
 elseif custom and action == PLAYERANIMEVENT_AOC_DEFLECT then
  activity = ACT_AOC_GESTURE_DEFLECT
 elseif custom and action == PLAYERANIMEVENT_AOC_DRAW then
  if CLIENT then Play(client, weapon, ACT_AOC_DRAW, GESTURE_SLOT_CUSTOM) end
  return ACT_INVALID
 elseif custom and (action == PLAYERANIMEVENT_AOC_BLOCK_UP or action == PLAYERANIMEVENT_AOC_BLOCK_UP_BLOCK or
  action == PLAYERANIMEVENT_AOC_BLOCK_IDLE or action == PLAYERANIMEVENT_AOC_BLOCK_DOWN) then
  if CLIENT then
   local key = tostring(client) .. ".AOC_Block"
   timer.Remove(key)
   local up = action == PLAYERANIMEVENT_AOC_BLOCK_UP or action == PLAYERANIMEVENT_AOC_BLOCK_UP_BLOCK
   local idle = action == PLAYERANIMEVENT_AOC_BLOCK_IDLE
   activity = idle and ACT_AOC_BLOCK_IDLE or action == PLAYERANIMEVENT_AOC_BLOCK_DOWN and ACT_AOC_BLOCK_DOWN or
    action == PLAYERANIMEVENT_AOC_BLOCK_UP_BLOCK and ACT_AOC_BLOCK_UP_BLOCK or ACT_AOC_BLOCK_UP
   client:AnimResetGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD)
   local duration = Play(client, weapon, activity, nil, idle)
   if up then
    local model = client:GetModel()
    timer.Create(key, math.max(duration or 0.01, 0.01), 1, function()
     if IsValid(client) and IsValid(weapon) and client:GetActiveWeapon() == weapon and
      client:GetModel() == model and not Blocked(client) and weapon.GetBlock and weapon:GetBlock() then
      Play(client, weapon, ACT_AOC_BLOCK_IDLE, nil, true)
     end
    end)
   end
  end
  return ACT_INVALID
 else
  return -- Jump/cancel/other engine events retain their normal handling.
 end
 if CLIENT and activity then Play(client, weapon, activity) end
 -- Helix plugins run before the addon hook: no second gesture or numeric
 -- activity conversion of the shared AoC name table on SD/Cellar models.
 return ACT_INVALID
end
