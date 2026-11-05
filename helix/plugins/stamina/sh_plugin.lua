PLUGIN.name = "Stamina"
PLUGIN.author = "Chessnut"
PLUGIN.description = "Adds a stamina system to limit running."

ix.config.Add("punchStamina", 10, "How much stamina punches use up.", nil, {
	data = {min = 0, max = 100},
	category = "characters"
})

ix.Net:AddPlayerVar("stm", true, nil, ix.Net.Type.Float)
ix.Net:AddPlayerVar("brth", false, nil, ix.Net.Type.Bool)
ix.Net:AddPlayerVar("stmRegenAt", true, nil, ix.Net.Type.Float)

local restDelay = 5
local playerMeta = FindMetaTable("Player")

function playerMeta:DelayStaminaRecovery(actionDuration)
	local deadline = CurTime() + math.max(0, actionDuration or 0) + restDelay
	self.ixStaminaRegenAt = math.max(self.ixStaminaRegenAt or 0, deadline)
	if SERVER and self.ixStaminaRegenAt > self:GetLocalVar("stmRegenAt", 0) then
		self:SetLocalVar("stmRegenAt", self.ixStaminaRegenAt)
	end
end

function PLUGIN:StartCommand(client, command)
	if not client:GetCharacter() or client:GetMoveType() == MOVETYPE_NOCLIP then return end
	-- Commands catch quick crouch taps between the 0.25-second stamina ticks.
	-- Held sprint while moving remains exertion even after exhaustion stops it.
	local active = command:KeyDown(IN_DUCK) or client:Crouching() or
		(command:KeyDown(IN_SPEED) and client:GetVelocity():Length2DSqr() > 0)
	if active then
		client.ixStaminaExerting = true
		client.ixStaminaRegenAt = math.max(client.ixStaminaRegenAt or 0, CurTime() + restDelay)
	elseif client.ixStaminaExerting then
		client.ixStaminaExerting = nil
		-- Publish once when movement ends, not every tick during a long sprint.
		client:DelayStaminaRecovery()
	end
end

do
	local CHAR = ix.meta.character

	function CHAR:GetMaxStamina()
		local maxStamina = hook.Run("CharacterMaxStamina", self) or 100

		return maxStamina
	end
end

local function CalcStaminaChange(client)
	local character = client:GetCharacter()

	if (!character or client:GetMoveType() == MOVETYPE_NOCLIP) then
		return 0
	end
	
	local offset = 0

	if (!client:GetNetVar("brth", false) and client:KeyDown(IN_SPEED) and client:GetSprintMove() and client:GetVelocity():LengthSqr() > 0) then
		-- characters could have attribute values greater than max if the config was changed
		offset = -1
		offset = hook.Run("AdjustStaminaOffsetRunning", client, offset) or -1
	else
		-- Five points per 0.25 s: an unmodified 100-point pool refills in 5 s.
		-- Keep both regeneration hooks so traits/injuries can still adjust it.
		offset = hook.Run("AdjustStaminaRegeneration", client, offset) or 5
	end

	offset = hook.Run("AdjustStaminaOffset", client, offset) or offset
	local regenAt = math.max(client.ixStaminaRegenAt or 0, client:GetLocalVar("stmRegenAt", 0))
	if offset > 0 and CurTime() < regenAt then offset = 0 end

	if (CLIENT) then
		return offset -- for the client we need to return the estimated stamina change
	else
		local maxStamina = character:GetMaxStamina()
		local current = client:GetLocalVar("stm", 0)
		local value = math.Clamp(current + offset, 0, maxStamina)

		if (current != value) then
			client:SetLocalVar("stm", value)

			if (value == 0 and !client:GetNetVar("brth", false)) then
				client:SetNetVar("brth", true)

				hook.Run("PlayerStaminaLost", client)
			elseif (value >= (maxStamina * 0.5) and client:GetNetVar("brth", false)) then
				client:SetNetVar("brth", nil)

				hook.Run("PlayerStaminaGained", client)
			end
		end
	end
end


if (SERVER) then
	function PLUGIN:PostPlayerLoadout(client)
		local uniqueID = "ixStam" .. client:SteamID()

		timer.Create(uniqueID, 0.25, 0, function()
			if (!IsValid(client)) then
				timer.Remove(uniqueID)
				return
			end

			CalcStaminaChange(client)
		end)
	end

	function PLUGIN:CharacterPreSave(character)
		local client = character:GetPlayer()

		if (IsValid(client)) then
			character:SetData("stamina", client:GetLocalVar("stm", 0))
		end
	end

	function PLUGIN:PlayerLoadedCharacter(client, character)
		client.ixStaminaRegenAt = nil
		client.ixStaminaExerting = nil
		client:SetLocalVar("stmRegenAt", 0)
		timer.Simple(0.25, function()
			if not IsValid(client) or client:GetCharacter() ~= character then return end
			client:SetLocalVar("stm", character:GetData("stamina", character:GetMaxStamina()))
		end)
	end

	function playerMeta:RestoreStamina(amount)
		local current = self:GetLocalVar("stm", 0)
		local maxStamina = self:GetCharacter():GetMaxStamina()
		local value = math.Clamp(current + amount, 0, maxStamina)

		self:SetLocalVar("stm", value)

		if (value >= (maxStamina * 0.5) and self:GetNetVar("brth", false)) then
			self:SetNetVar("brth", nil)

			hook.Run("PlayerStaminaGained", self)
		end
	end

	function playerMeta:ConsumeStamina(amount)
		if amount > 0 then self:DelayStaminaRecovery() end
		local current = self:GetLocalVar("stm", 0)
		local value = math.Clamp(current - amount, 0, self:GetCharacter():GetMaxStamina())

		self:SetLocalVar("stm", value)

		if (value == 0 and !self:GetNetVar("brth", false)) then
			self:SetNetVar("brth", true)

			hook.Run("PlayerStaminaLost", self)
		end
	end
else
	PLUGIN.predictedStamina = 100

	function PLUGIN:Think()
		local offset = CalcStaminaChange(LocalPlayer())
		-- the server check it every 0.25 sec, here we check it every [FrameTime()] seconds
		offset = math.Remap(FrameTime(), 0, 0.25, 0, offset)

		if (offset != 0) then
			self.predictedStamina = math.Clamp(self.predictedStamina + offset, 0, LocalPlayer():GetCharacter():GetMaxStamina())
		end
	end

	function PLUGIN:OnLocalVarSet(key, var)
		if key == "stmRegenAt" then
			if (var or 0) <= 0 then
				local client = LocalPlayer()
				if IsValid(client) then
					client.ixStaminaRegenAt = nil
					client.ixStaminaExerting = nil
				end
			end
			return
		end
		if (key != "stm") then return end
		if (math.abs(self.predictedStamina - var) > 5) then
			self.predictedStamina = var
		end
	end
end
