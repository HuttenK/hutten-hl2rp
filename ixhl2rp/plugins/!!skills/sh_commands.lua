ix.command.Add("CharSetSkill", {
	description = "@cmdCharSetSkill",
	privilege = "Manage Character Skills",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.string,
		ix.type.number
	},
	OnRun = function(self, client, target, skillName, targetValue)
		for k, v in pairs(ix.skills.list) do
			if k == skillName or L(v.name, client) == skillName then
				local value = math.Clamp(targetValue, 0, v:GetMaximum(target))

				target:SetSkill(k, value)
				return "@skillSet", target:GetName(), L(v.name, client), value
			end
		end

		for k, v in pairs(ix.skills.list) do
			if (ix.util.StringMatches(L(v.name, client), skillName) or ix.util.StringMatches(k, skillName)) then
				local value = math.Clamp(targetValue, 0, v:GetMaximum(target))

				target:SetSkill(k, value)
				return "@skillSet", target:GetName(), L(v.name, client), value
			end
		end


		return "@skillNotFound"
	end
})

ix.command.Add("lvl", {
	description = "@cmdLvlDesc",
	OnRun = function(self, client)
		local points = client:GetCharacter():GetSkillPoints()

		if points and points != 0 then
			net.Start("ixLevelUp")
			net.Send(client)
		end
	end
})

ix.command.Add("lvlreset", {
	description = "@cmdLvlResetDesc",
	OnRun = function(self, client)
		local char = client:GetCharacter()

		if !char then
			return
		end

		local cost = 1000

		if !char:HasMoney(cost) then
			return client:NotifyLocalized("skillsResetNoMoney", cost)
		end

		local levelSystem = ix.plugin.list["!!levelsystem"]

		if !levelSystem then
			return client:NotifyLocalized("skillsResetDisabled")
		end

		-- Возвращаем ВСЕ очки, полученные персонажем за жизнь. Первый уровень
		-- включён намеренно: его очки (см. sh_data.levelpoints.lua, [1] = 30)
		-- выдаются при создании персонажа, поэтому полный сброс обязан вернуть
		-- и их. Код повышения уровня пропускает i == 1 ровно по обратной причине.
		local points = 0
		for i = 1, char:GetLevel() do
			points = points + levelSystem:GetPointsAtLevel(i)
		end

		char:TakeMoney(cost)

		for k, _ in pairs(ix.specials.list) do
			char:SetSpecial(k, 0)
		end

		char:SetSkillPoints(points)
		char:SetData("levelup", true)

		client:NotifyLocalized("skillsResetDone", points)

		net.Start("ixLevelUp")
		net.Send(client)
	end
})

ix.command.Add("CharAddSkill", {
	description = "@cmdCharAddSkill",
	privilege = "Manage Character Skills",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.string,
		ix.type.number
	},
	OnRun = function(self, client, target, skillName, level)
		local skills = target:GetSkills()

		for k, v in pairs(ix.skills.list) do
			if k == skillName or L(v.name, client) == skillName then
				local value = (skills[k][1] or 0) + math.abs(math.floor(level))

				target:SetSkill(k, value)
				return "@skillAdd", target:GetName(), L(v.name, client), value
			end
		end

		for k, v in pairs(ix.skills.list) do
			if (ix.util.StringMatches(L(v.name, client), skillName) or ix.util.StringMatches(k, skillName)) then
				local value = (skills[k][1] or 0) + math.abs(math.floor(level))

				target:SetSkill(k, value)
				return "@skillAdd", target:GetName(), L(v.name, client), value
			end
		end

		return "@skillNotFound"
	end
})

ix.command.Add("CharAddSkillXP", {
	description = "@cmdCharAddSkillXP",
	privilege = "Manage Character Skills",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.string,
		ix.type.number
	},
	OnRun = function(self, client, target, skillName, xp)
		for k, v in pairs(ix.skills.list) do
			if k == skillName or L(v.name, client) == skillName then
				target:UpdateSkillProgress(k, xp)

				return "@skillAddXP", target:GetName(), L(v.name, client), xp
			end
		end

		for k, v in pairs(ix.skills.list) do
			if (ix.util.StringMatches(L(v.name, client), skillName) or ix.util.StringMatches(k, skillName)) then
				target:UpdateSkillProgress(k, xp)

				return "@skillAddXP", target:GetName(), L(v.name, client), xp
			end
		end

		return "@skillNotFound"
	end
})

ix.command.Add("CharSetAttribute", {
	description = "@cmdCharSetAttribute",
	privilege = "Manage Character Attributes",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.string,
		ix.type.number
	},
	OnRun = function(self, client, target, attributeName, level)
		for k, v in pairs(ix.specials.list) do
			if (ix.util.StringMatches(L(v.name, client), attributeName) or ix.util.StringMatches(k, attributeName)) then
				target:SetSpecial(k, math.abs(level))
				return "@attributeSet", target:GetName(), L(v.name, client), math.abs(level)
			end
		end

		return "@attributeNotFound"
	end
})

ix.command.Add("CharAddAttribute", {
	description = "@cmdCharAddAttribute",
	privilege = "Manage Character Attributes",
	adminOnly = true,
	arguments = {
		ix.type.character,
		ix.type.string,
		ix.type.number
	},
	OnRun = function(self, client, target, attributeName, level)
		for k, v in pairs(ix.specials.list) do
			if (ix.util.StringMatches(L(v.name, client), attributeName) or ix.util.StringMatches(k, attributeName)) then
				target:UpdateSpecial(k, math.abs(level))
				return "@attributeUpdate", target:GetName(), L(v.name, client), math.abs(level)
			end
		end

		return "@attributeNotFound"
	end
})

ix.command.Add("RollSkill", {
	description = "@cmdRollSkill",
	arguments = {
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, skillName)
		if skillName then
			for k, v in pairs(ix.skills.list) do
				if (ix.util.StringMatches(L(v.name, client), skillName) or ix.util.StringMatches(k, skillName)) then
					client:GetCharacter():SkillRoll(k)
					return
				end
			end

			return "@skillNotFound"
		else
			client.isSkillRoll = true

			net.Start("ixSkillRoll")
			net.Send(client)
		end
	end
})

ix.command.Add("RollStat", {
	description = "@cmdRollStat",
	arguments = {
		bit.bor(ix.type.string, ix.type.optional)
	},
	OnRun = function(self, client, statName)
		if statName then
			for k, v in pairs(ix.specials.list) do
				if (ix.util.StringMatches(L(v.name, client), statName) or ix.util.StringMatches(k, statName)) then
					client:GetCharacter():StatRoll(k)
					return
				end
			end

			return "@attributeNotFound"
		else
			client.isStatRoll = true

			net.Start("ixStatRoll")
			net.Send(client)
		end
	end
})