local PLUGIN = PLUGIN

util.AddNetworkString("ixSkillRoll")
util.AddNetworkString("ixStatRoll")
util.AddNetworkString("ixLevelUp")

local messagesDepleted = {
	"Вы чувствуете усталость...",
	"Кажется, ваш ум измучен...",
	"Необходимо задуматься об отдыхе...",
	"Вам стоит посетить бар и выпить что-нибудь крепкое, чтобы восстановить силы."
}

local messagesRestored = {
	"Вы почувствовали прилив энергии, как будто выпили эликсира жизни.",
	"Ваши мысли становятся легкими, как парус, наполненный ветром.",
	"Мудрость возвращается к вам.",
	"Кажется, вы готовы к новым вызовам."
}

function PLUGIN:OnSkillMemoryDepleted(character)
	local client = character:GetPlayer()
	local ct = CurTime()

	if !character.skillMemoryDepletedNotify or (ct >= character.skillMemoryDepletedNotify) then
		client:ChatNotify("*** "..messagesDepleted[math.random(#messagesDepleted)])

		character.skillMemoryDepletedNotify = ct + 3600
	end 
end

function PLUGIN:OnSkillMemoryRestored(character)
	local client = character:GetPlayer()
	local ct = CurTime()

	if !character.skillMemoryRestoredNotify or (ct >= character.skillMemoryRestoredNotify) then
		client:ChatNotify("*** "..messagesRestored[math.random(#messagesRestored)])

		character.skillMemoryRestoredNotify = ct + 3600
	end 
end

net.Receive("ixLevelUp", function(len, ply)
	if len > 4096 or not IsValid(ply) then return end
	local character = ply:GetCharacter()
	if not character then return end
	local points = character:GetSkillPoints()

	if points == 0 then
		return
	end

	local spendPoints = net.ReadInt(10)
	local specials = net.ReadTable()
	if not istable(specials) or spendPoints == 0 then return end
	if (points > 0) ~= (spendPoints > 0) or math.abs(spendPoints) > math.abs(points) then return end
	-- Validate a copy: rejected requests cannot mutate live character data.
	local sum = 0
	local charSpecials = table.Copy(character:GetSpecials())

	for k, v in pairs(specials) do
		if not ix.specials.list[k] or not isnumber(v) or v ~= v or math.abs(v) == math.huge then return end
		if v ~= math.floor(v) or (v ~= 0 and (v > 0) ~= (points > 0)) then return end
		local cost = character:GetPrimaryStat(k) and 1 or 4
		if v % cost ~= 0 then return end
		local value = (charSpecials[k] or 0) + v
		if value < 0 then return end
		sum = sum + v
		charSpecials[k] = value
	end

	if sum ~= spendPoints then
		return
	end

	character:SetSkillPoints(points - spendPoints)
	character:SetSpecials(charSpecials)
	ix.specials.Setup(ply)
	ply.recalculateSpeed = true
	hook.Run("CharacterAllocatedSpecials", ply, character, specials)
end)

do
	local charMeta = ix.meta.character

	function charMeta:SkillRoll(skillID)
		local client = self:GetPlayer()
		local skillValue = self:GetSkillModified(skillID)
		local success = false
		local value = math.random(0, 10)

		if value == 1 then
			success = true
		elseif value == 10 then
			success = false
		elseif value <= skillValue then
			success = true
		end

		ix.chat.Send(client, "skillroll", tostring(value), nil, nil, {
			check = skillValue,
			skill = skillID,
			success = success,
		})

		ix.log.Add(client, "skillroll", skillID, success, value, skillValue)
	end

	function charMeta:StatRoll(attributeID)
		local client = self:GetPlayer()
		local boost = self:GetSpecialBoosts()
		local statValue = self:GetSpecial(attributeID, 0)
		local success = false
		local value = math.random(1, 10)

		for _, bValue in pairs(boost[attributeID] or {}) do
			statValue = statValue + bValue
		end

		if value == 1 then
			success = true
		elseif value == 10 then
			success = false
		elseif value <= statValue then
			success = true
		end

		ix.chat.Send(client, "statroll", tostring(value), nil, nil, {
			check = statValue,
			stat = attributeID,
			success = success,
		})

		ix.log.Add(client, "statroll", attributeID, success, value, statValue)
	end
end

net.Receive("ixSkillRoll", function(len, ply)
	local skillID = net.ReadString()
	local character = ply:GetCharacter()

	if !ply.isSkillRoll then
		return
	end

	if !character then 
		return
	end

	if !ix.skills.list[skillID] then
		return ply:NotifyLocalized("skillNotFound")
	end

	character:SkillRoll(skillID)

	ply.isSkillRoll = false
end)

net.Receive("ixStatRoll", function(len, ply)
	local statID = net.ReadString()
	local character = ply:GetCharacter()

	if !ply.isStatRoll then
		return
	end

	if !character then 
		return
	end

	if !ix.specials.list[statID] then
		return ply:NotifyLocalized("attributeNotFound")
	end

	character:StatRoll(statID)

	ply.isStatRoll = false
end)

ix.log.AddType("skillroll", function(client, ...)
	local arg = {...}
	return string.format("%s (%s %s) has rolled %s out of 100 (%s).", client:Name(), arg[1], arg[4], arg[3], arg[2] and "SUCCESS" or "FAIL")
end)

ix.log.AddType("statroll", function(client, ...)
	local arg = {...}
	return string.format("%s (%s %s) has rolled %s out of 10 (%s).", client:Name(), arg[1], arg[4], arg[3], arg[2] and "SUCCESS" or "FAIL")
end)


-- Athletics Skill Related code
local function CalcAthleticsSpeed(athletics)
	return 1 + (athletics * 0.1) * 0.25
end

local function CalcAthleticsFatigue(athletics)
	return (athletics * 0.1) * 0.5
end

function PLUGIN:ModifyCharacterRunSpeed(client, character, runSpeed)
	return runSpeed * CalcAthleticsSpeed(character:GetSkillModified("athletics"))
end

local walkSpeed
local function CalcAthleticsTrain(client)
	local character = client:GetCharacter()

	if (!character or client:GetMoveType() == MOVETYPE_NOCLIP or IsValid(client.ixRagdoll)) then
		return
	end

	walkSpeed = ix.config.Get("walkSpeed")
	local xp = 0

	if (client:KeyDown(IN_SPEED) and client:GetVelocity():LengthSqr() >= (walkSpeed * walkSpeed)) then
		xp = 1
	elseif client:GetVelocity():LengthSqr() >= (walkSpeed * walkSpeed) then
		xp = 0.25
	end

	if xp > 0 then
		character:DoAction("athleticsRun", xp)
	end
end

function PLUGIN:PostPlayerLoadout(client)
	ix.specials.Setup(client)

	local character = client:GetCharacter()

	if character then
		client.recalculateSpeed = true

		//client:SetRunSpeed(ix.config.Get("runSpeed") * CalcAthleticsSpeed(character:GetSkillModified("athletics")))
		//client:SetJumpPower(160 * (1 + math.min(math.Remap(character:GetSkillModified("acrobatics"), 0, 10, 0, 0.75), 0.75)))

		local uniqueID = "ixAthletics" .. client:SteamID()
		timer.Create(uniqueID, 1, 0, function()
			if (!IsValid(client)) then
				timer.Remove(uniqueID)
				return
			end

			CalcAthleticsTrain(client)
		end)
	end
end
