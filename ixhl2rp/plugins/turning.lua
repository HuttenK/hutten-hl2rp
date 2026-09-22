PLUGIN.name = "Turning"
PLUGIN.description = "Adds support for playermodels playing turning animations."
PLUGIN.author = "TankNut"

local support = {
	metrocop = true,
	overwatch = true,
	cellarMale = true,
	cellarFemale = true
}

local whitelist = {
	[ACT_MP_STAND_IDLE] = true,
	[ACT_MP_CROUCH_IDLE] = true
}

function PLUGIN:TranslateActivity(client, act)
	-- NPC turn gestures must not twist a body currently using ARC9's MP stance.
	if ix.anim.CanUseARC9NativePose and ix.anim.CanUseARC9NativePose(client, client:GetActiveWeapon()) then return end
	local modelClass = client.ixAnimModelClass or "player"

	if not support[modelClass] or not whitelist[act] then
		return
	end

	client.NextTurn = client.NextTurn or 0

	local diff = math.NormalizeAngle(client:GetRenderAngles().y - client:EyeAngles().y)

	if math.abs(diff) >= 45 and client.NextTurn <= CurTime() then
		local gesture = diff > 0 and ACT_GESTURE_TURN_RIGHT90 or ACT_GESTURE_TURN_LEFT90

		if client:IsWepRaised() and gesture == ACT_GESTURE_TURN_LEFT90 then
			gesture = ACT_GESTURE_TURN_LEFT45
		end

		local sequence = client:SelectWeightedSequence(gesture)
		if sequence < 0 then return end
		client:AnimRestartGesture(GESTURE_SLOT_CUSTOM, gesture, true)
		client.NextTurn = CurTime() + client:SequenceDuration(sequence)
	end
end

local chatTypes = {
	["ic"] = 1,
	["w"] = 2,
	["y"] = 3,
}

local anims = {
	cellarFemale = {
		"g_display_left",
		"g_left_openhand",
		"g_puncuate",
		"g_right_openhand"
	},
	cellarMale = {
		"g_medpuct_mid",
		"g_medurgent_mid",
		"g_look",
		"g_look_small",
		"g_openarms",
		"g_openarms_right",
		"g_puncuate",
		"g_righthandheavy",
		"g_righthandroll",
		"g_plead_01",
		"g_shrug",
		"g_what"
	},
	cellarVort = {
		"g_handclasp",
		"g_palm_both",
		"g_palm_left",
		"g_palm_left",
		"g_palm_mid_right",
		"g_palm_right",
		"g_refer_forward",
		"g_refer_left",
		"g_refer_right"
	}
}



if CLIENT then
	net.Receive("anim.gesture", function()
		local a = net.ReadEntity()

		if !IsValid(a) then
			return
		end

		local b = net.ReadInt(32)

		a:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD, b, 0, true)
	end)

	net.Receive("anim.talk", function()
		local client = net.ReadEntity()

		if !IsValid(client) then
			return
		end
		
		local animID = net.ReadUInt(4)

		local names = anims[client.ixAnimModelClass]
		if names and names[animID] then
			local d = client:LookupSequence(names[animID])
			if d >= 0 then client:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD, d, 0, true) end
		end
	end)
else
	util.AddNetworkString("anim.gesture")
	util.AddNetworkString("anim.talk")

	function PLUGIN:PlayerUse(client, entity)
		if entity:IsDoor() and client:KeyPressed(IN_USE) and (!client.lastDoorAnim or (client.lastDoorAnim and CurTime() >= client.lastDoorAnim)) then
			client:DoCustomAnimEvent(888, 0)
			client.lastDoorAnim = CurTime() + 1
		end
	end

	function PLUGIN:PostPlayerSay(client, chatType, message, anonymous)
		if not chatTypes[chatType] then return end
		local ct = CurTime()

		if !client.nextTalkAnim or (client.nextTalkAnim and ct > client.nextTalkAnim) then
			local typex = anims[client.ixAnimModelClass]

			if typex then
				local animID = math.random(1, #typex)
				local anim = typex[animID]
				local d = client:LookupSequence(anim)
				if d < 0 then client.nextTalkAnim = ct + 5 return end
				local a = client:SequenceDuration(d)

				net.Start("anim.talk")
					net.WriteEntity(client)
					net.WriteUInt(animID, 4)
				net.SendPVS(client:GetShootPos())

				client.nextTalkAnim = ct + a
			else
				client.nextTalkAnim = ct + 5
			end
		end
	end
end

function PLUGIN:DoAnimationEvent(client, event, data)

end
