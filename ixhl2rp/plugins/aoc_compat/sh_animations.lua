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

function A.MainActivity(client, activity)
 local weapon = client:GetActiveWeapon()
 if not IsValid(weapon) or not weapon.AOC_Base or Blocked(client) or
  client:GetMoveType() == MOVETYPE_NOCLIP then return end
 A.Prepare(weapon)
 local entry = weapon.ActivityTranslate and weapon.ActivityTranslate[activity]
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
