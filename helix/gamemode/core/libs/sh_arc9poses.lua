-- ARC9's lower-body/weapon anchor must use the same multiplayer stance that
-- its arm solver expects. Explicit Cellar mappings can also contain these clips.
ix.anim = ix.anim or {}
local cache = {}
local movement = {ACT_MP_STAND_IDLE, ACT_MP_WALK, ACT_MP_RUN, ACT_MP_CROUCH_IDLE, ACT_MP_CROUCHWALK}
local bones = {"Spine4", "R_UpperArm", "R_Forearm", "R_Hand", "L_UpperArm", "L_Forearm", "L_Hand"}
local bases = {normal = ACT_HL2MP_IDLE, passive = ACT_HL2MP_IDLE_PASSIVE}

function ix.anim.ClearARC9PoseCache()
	cache = {}
end

local function GetActivities(client, weapon)
	if client:IsWepRaised() or ix.config.Get("weaponAlwaysRaised") then
		return weapon.ActivityTranslate
	end
	local base = bases[ix.anim.GetWeaponHoldType(client, weapon)]
	if not base then return end
	local activities = {}
	for index, generic in ipairs(movement) do activities[generic] = base + index - 1 end
	return activities
end

-- Request the stance independently of whether the character includes that
-- sequence. The SD client adapter samples it on a native multiplayer rig.
function ix.anim.GetARC9PoseActivity(client, weapon, activity)
	local activities = GetActivities(client, weapon)
	return activities and activities[activity or client.CalcIdeal or ACT_MP_STAND_IDLE]
end

function ix.anim.CanRetargetARC9SDPose(client, weapon)
	if not IsValid(client) or not IsValid(weapon) or not weapon.ARC9 or not weapon.MirrorVMWM then return false end
	if client:InVehicle() or not client:OnGround() then return false end
	if client:GetNetVar("forcedSequence") or client:GetNetVar("sharedPose") then return false end
	local model = string.lower(client:GetModel() or "")
	if model:sub(1, 10) ~= "models/sd/" then return false end
	local count = client:GetSequenceCount()
	if count < 2 then return false end
	local requested = ix.anim.GetARC9PoseActivity(client, weapon)
	if not isnumber(requested) or requested < 0 then return false end
	local key = "sd:" .. model .. ":" .. count
	if cache[key] ~= nil then return cache[key] end
	for _, bone in ipairs(bones) do
		if client:LookupBone("ValveBiped.Bip01_" .. bone) == nil then cache[key] = false return false end
	end
	cache[key] = true
	return true
end

function ix.anim.CanUseARC9NativePose(client, weapon, activity)
	if not IsValid(client) or not IsValid(weapon) or not weapon.ARC9 then return false end
	if client:InVehicle() or not client:OnGround() then return false end
	if client:GetNetVar("forcedSequence") or client:GetNetVar("sharedPose") then return false end
	local activities = GetActivities(client, weapon)
	if not activities then return false end
	activity = activity or client.CalcIdeal or ACT_MP_STAND_IDLE
	local requested = activities[activity]
	if not isnumber(requested) or requested < 0 then return false end
	local model = string.lower(client:GetModel() or "")
	local count = client:GetSequenceCount()
	-- Unmounted/newly networked models must remain eligible for a later retry.
	if model == "" or count < 2 then return false end
	local key = model .. ":" .. count .. ":" .. requested
	if cache[key] ~= nil then return cache[key] end
	for _, bone in ipairs(bones) do
		if client:LookupBone("ValveBiped.Bip01_" .. bone) == nil then
			cache[key] = false
			return false
		end
	end
	-- A missing crouch/run clip must not disable an available native idle pose.
	local sequence = client:SelectWeightedSequence(requested)
	cache[key] = isnumber(sequence) and sequence >= 0
	return cache[key]
end

function ix.anim.CanUseARC9LoweredPose(client, weapon)
	if not IsValid(client) or client:IsWepRaised() or ix.config.Get("weaponAlwaysRaised") then return false end
	return ix.anim.CanUseARC9NativePose(client, weapon)
end

function ix.anim.GetARC9NativeActivity(client, weapon, activity)
	if not ix.anim.CanUseARC9NativePose(client, weapon, activity) then return end
	for _, generic in ipairs(movement) do
		if activity == generic then return GetActivities(client, weapon)[generic] end
	end
end

-- Preserve the lowered-only helper for integrations loaded before this revision.
function ix.anim.GetARC9LoweredActivity(client, weapon, activity)
	if ix.anim.CanUseARC9LoweredPose(client, weapon) then
		return ix.anim.GetARC9NativeActivity(client, weapon, activity)
	end
end

function ix.anim.ARC9NeedsPistolFallback(client, weapon)
	-- EFT exposes its conventional reload activity independently of its rpg
	-- TPIK anchor. Do not classify arbitrary rifles by their ammunition or name.
	return IsValid(weapon) and weapon.ARC9 and weapon.HoldTypeHolstered == "normal" and
		weapon.NonTPIKAnimReload == ACT_HL2MP_GESTURE_RELOAD_REVOLVER and
		(client.ixAnimModelClass or "player") ~= "player" and
		not ix.anim.CanUseARC9NativePose(client, weapon)
end

-- A previous frame's sequence must not mask a new weapon/movement stance.
function ix.anim.ResolveMainSequence(client, activity, override)
 if isnumber(activity) and activity >= 0 then
  -- Weighted selection can return a different idle variant on every call.
  -- CalcMainActivity runs every frame: keep one choice for this stance so
  -- its cycle can advance without repeatedly blending/resetting the feet.
  local model, count = client:GetModel(), client:GetSequenceCount()
  local choice = client.ixMainSequenceChoice
  if choice and choice.model == model and choice.count == count and choice.activity == activity then
   return choice.sequence
  end
  local sequence = client:SelectWeightedSequence(activity)
  if isnumber(sequence) and sequence >= 0 then
   client.ixMainSequenceChoice = {model = model, count = count, activity = activity, sequence = sequence}
   return sequence
  end
 end
 -- Named poses and unavailable activities must not retain the old stance.
 -- Do not cache failures: streamed models can gain their sequences later.
 client.ixMainSequenceChoice = nil
 if isnumber(override) and override >= 0 then return override end
 return nil
end
