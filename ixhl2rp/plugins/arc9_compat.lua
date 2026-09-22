local PLUGIN = PLUGIN
PLUGIN.name = "ARC9 Animation Compatibility"
PLUGIN.author = "Legends"
PLUGIN.description = "Coordinates Helix roleplay poses with ARC9 arm positioning."

if SERVER then
	-- ARC9's supported replicated switch hides its gameplay ammo panel and
	-- associated hints for every client, while leaving customization usable.
	local function HideWeaponHUD()
		local setting = GetConVar("arc9_hud_force_disable")
		if setting then setting:SetBool(true) end
	end
	function PLUGIN:InitPostEntity() HideWeaponHUD() end
	timer.Simple(0, HideWeaponHUD)
end

local function GetOwner(weapon)
	if not IsValid(weapon) or not weapon.ARC9 then return end
	local owner = weapon:GetOwner()
	if not IsValid(owner) or not owner:IsPlayer() or not owner.GetCharacter or not owner:GetCharacter() then return end
	return owner
end

if CLIENT then
	concommand.Add("ix_arc9_pose_info", function()
		local client = LocalPlayer()
		if not IsValid(client) or not client.GetCharacter or not client:GetCharacter() then return end
		local weapon = client:GetActiveWeapon()
		if not IsValid(weapon) or not weapon.ARC9 then print("[ARC9/Helix] Select an ARC9 weapon first.") return end
		print("[ARC9/Helix] Model:", client:GetModel(), "class:", client.ixAnimModelClass)
		print("Weapon:", weapon:GetClass(), "raised:", client:IsWepRaised(), "hold:", weapon:GetHoldType())
		print("Activity:", client.CalcIdeal, "sequence:", client:GetSequenceName(client:GetSequence()))
		print("Native pose:", ix.anim.CanUseARC9NativePose(client, weapon), "TPIK:", weapon:ShouldTPIK())
		for _, activity in ipairs({ACT_HL2MP_IDLE_PASSIVE, ACT_HL2MP_WALK_PASSIVE, ACT_HL2MP_RUN_PASSIVE, ACT_HL2MP_IDLE_CROUCH_PASSIVE, ACT_HL2MP_WALK_CROUCH_PASSIVE}) do
			local sequence = client:SelectWeightedSequence(activity)
			print("Passive activity:", activity, "sequence:", sequence, sequence >= 0 and client:GetSequenceName(sequence) or "MISSING")
		end
	end)
end

function PLUGIN:SyncHoldType(weapon, owner)
	if not owner:IsWepRaised() and not ix.config.Get("weaponAlwaysRaised") then
		local desired = ix.anim.GetWeaponHoldType(owner, weapon)
		weapon.ixHelixLoweredHold = true
		if weapon:GetHoldType() ~= desired then weapon:SetHoldType(desired) end
	elseif weapon.ixHelixLoweredHold then
		weapon.ixHelixLoweredHold = nil
		-- Recompute from ARC9's current ADS/sprint/safety state, not a stale snapshot.
		weapon:SetShouldHoldType()
	end
end

function PLUGIN:ARC9_Hook_Think(weapon)
	local owner = GetOwner(weapon)
	if owner then self:SyncHoldType(weapon, owner) end
end

-- Also synchronize at render time for remote players. ARC9 reads GetHoldType
-- immediately afterwards to choose its lowered offsets and left-hand support.
-- Never return false: preserve blocks supplied by weapons or attachments.
function PLUGIN:ARC9_Hook_BlockTPIK(weapon)
	local owner = GetOwner(weapon)
	if not owner then return end
	self:SyncHoldType(weapon, owner)
	if owner:GetNetVar("forcedSequence") or owner:GetNetVar("sharedPose") then return true end
	if ix.anim.ARC9NeedsPistolFallback and ix.anim.ARC9NeedsPistolFallback(owner, weapon) then return true end
	if not owner:IsWepRaised() and not ix.config.Get("weaponAlwaysRaised") then
		-- The same capability check drives GM:TranslateActivity. Hybrid Cellar
		-- models may qualify; a player label alone does not prove compatibility.
		if not ix.anim.CanUseARC9LoweredPose or not ix.anim.CanUseARC9LoweredPose(owner, weapon) then return true end
	end
end
