local PLUGIN = PLUGIN

util.AddNetworkString("ixPlayerSit")
util.AddNetworkString("ixSitCapabilities")
-- Client Workshop content can expose donor poses absent on a dedicated server.
-- Authorize the preview choices using the same resolver as the final sit request.
net.Receive("ixSitCapabilities", function(len, player)
 if len~=16 or not player:GetCharacter() then return end
 local token=net.ReadUInt(16)
 if player.ixNextSitCapabilities and player.ixNextSitCapabilities>CurTime() then return end
 player.ixNextSitCapabilities=CurTime()+.25
 local choices={}
 for option=1,24 do
  if PLUGIN:ResolvePose(player,option) then choices[#choices+1]=option end
 end
 net.Start("ixSitCapabilities")
 net.WriteUInt(token,16)
 net.WriteString(player:GetModel())
 net.WriteUInt(#choices,5)
 for _,option in ipairs(choices) do net.WriteUInt(option,5) end
 net.Send(player)
end)


net.Receive("ixPlayerSit", function(len, player)
	local pos = net.ReadVector()
	local ang = net.ReadAngle()
	local option = net.ReadUInt(5)
 local _, remaining = net.BytesLeft()
 local height = remaining and remaining >= 32 and net.ReadFloat() or 0
 if not isnumber(height) or height~=height or height < -24 or height > 48 then return end
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

	if ix.PoseStudio and ix.PoseStudio.CheckPlacement then
  if not ix.PoseStudio.CheckPlacement(player,pos,ang.y,height,PLUGIN:GetPoseOffset(player,option,character)) then return end
 end
 if (!player.cwNextStance or CurTime() >= player.cwNextStance) then
		if (player:IsProne()) then
			prone.Exit(player)
		end

		player.cwNextStance = CurTime() + 2;

		local sitOffset = PLUGIN:GetPoseOffset(player, option, character)

		local finalPos = pos + ang:Forward() * sitOffset.x + Vector(0, 0, sitOffset.z + height)
		
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
