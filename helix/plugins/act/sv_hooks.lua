
local PLUGIN = PLUGIN

util.AddNetworkString("ixActEnter")
util.AddNetworkString("ixActLeave")

function PLUGIN:CanPlayerEnterAct(client, modelClass, variant, act)
	if (!client:Alive() or client:GetLocalVar("ragdoll") or client:WaterLevel() > 0 or !client:IsOnGround() or client:InVehicle()) then
		return false, L("notNow", client)
	end

	-- check if player's model class has an entry in this act table
	modelClass = modelClass or ix.anim.GetModelClass(client:GetModel())
	local data = ix.act.Resolve(client, act, variant)

	if (!data) then
		return false, L("modelNoSeq", client)
	end

	-- some models don't support certain variants
	local sequence = data.sequence[variant]

	if (!sequence) then
		return false, L("modelNoSeq", client)
	end

	return true
end

-- Forced transitions must not start a finish animation on a dead/new model.
function PLUGIN:AbortAct(client)
 if not client:GetNetVar("actEnterAngle") and not client.ixActModel then return end
 client.ixSeqCallback = nil
 client:LeaveSequence()
 self:ExitAct(client)
end

function PLUGIN:PlayerDeath(client) self:AbortAct(client) end
function PLUGIN:PlayerSpawn(client) self:AbortAct(client) end
function PLUGIN:OnCharacterFallover(client) self:AbortAct(client) end
function PLUGIN:PrePlayerLoadedCharacter(client) self:AbortAct(client) end

function PLUGIN:Think()
 if self.nextActCheck and self.nextActCheck > CurTime() then return end
 self.nextActCheck = CurTime() + 0.2
 for _, client in ipairs(player.GetAll()) do
  if client.ixActModel and (client:GetModel() ~= client.ixActModel or
   client:GetCharacter() ~= client.ixActCharacter or not client:Alive() or
   client:InVehicle() or client:GetLocalVar("ragdoll")) then
   self:AbortAct(client)
  end
 end
end

function PLUGIN:PlayerDisconnected(client)
 timer.Remove("ixSeq" .. client:EntIndex())
 client.ixSeqCallback = nil
end
