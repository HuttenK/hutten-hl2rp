local PLUGIN = PLUGIN

util.AddNetworkString("ixPlayerSit")

net.Receive("ixPlayerSit", function(len, player)
	local pos = net.ReadVector()
	local ang = net.ReadAngle()
	local option = net.ReadUInt(5)
	local faction = player:Team()
	local character = player:GetCharacter()

	if not character or player.ixUntimedSequence or player:GetNetVar("forcedSequence") ~= nil then
		return
	end

	if player:IsPilotScanner() then
		return
	end

	--if faction == FACTION_VORT then return; end
	
	local sequence = PLUGIN:ResolvePose(player, option)
 if not sequence then player:NotifyLocalized("modelNoSeq") return end
 if ang.y ~= ang.y or math.abs(ang.y) == math.huge then return end
 ang = Angle(0, math.NormalizeAngle(ang.y), 0)
 if (!PLUGIN:CanSit(player, pos, option, character)) then
		return
	end

	if (!player.cwNextStance or CurTime() >= player.cwNextStance) then
		if (player:IsProne()) then
			prone.Exit(player)
		end

		player.cwNextStance = CurTime() + 2;

		local sitOffset = PLUGIN:GetPoseOffset(player, option, character)

		local finalPos = pos + ang:Forward() * sitOffset.x + Vector(0, 0, sitOffset.z)
		
		if player:ForceSequence(sequence, nil, 0, nil) == false then return end
  player.latestSitCollision = player:GetCollisionGroup()
  player.latestSitPos = player:GetPos()
		player.latestSitAng = player:GetAngles()
		player.latestCharKey = player:GetCharacter():GetID()

		player:SetPos(finalPos)
		local angles = player:GetAngles()
		angles.y = ang.y
		player:SetAngles(angles)
		player:SetLocalVelocity(vector_origin)
		player:SetVelocity(vector_origin)

		player:SetNetVar("sitHelperPos", player:GetPos())
		player:SetNetVar("actEnterAngle", player:GetAngles())
		player.ixActModel = player:GetModel()
		player.ixActCharacter = character
		player.ixUntimedSequence = true
		player:SetCollisionGroup(COLLISION_GROUP_WORLD)

		

		net.Start("ixActEnter")
			net.WriteBool(true)
		net.Send(player)
	end
end)

function PLUGIN:PlayerLeaveSequence(client)
	if (client:GetNetVar("sitHelperPos")) then
		client.ixUntimedSequence = nil
		client.ixActModel = nil
		client.ixActCharacter = nil

		client:SetNetVar("sitHelperPos", nil)
		client:SetNetVar("actEnterAngle", nil)

		local character = client:GetCharacter()
		if character and client.latestCharKey == character:GetID() and client:Alive() then
			client:SetPos(client.latestSitPos)
			client:SetAngles(client.latestSitAng)
		end

		client.latestSitPos = nil
		client.latestSitAng = nil
		client.latestCharKey = nil
		
		client:SetLocalVelocity(vector_origin)
		client:SetVelocity(vector_origin)
		client:SetCollisionGroup(client.latestSitCollision or COLLISION_GROUP_PLAYER)
		client.latestSitCollision = nil

		net.Start("ixActLeave")
		net.Send(client)
	end
end

PLUGIN["prone.CanEnter"] = function(self, client)
	if (client:GetNetVar("sitHelperPos")) then
		return false
	end
end
