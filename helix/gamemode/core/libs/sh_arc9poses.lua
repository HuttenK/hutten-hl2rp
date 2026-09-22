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
