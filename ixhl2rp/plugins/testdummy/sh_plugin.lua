PLUGIN.name = "Тестовый манекен"
PLUGIN.author = ""
PLUGIN.description = "Админ-инструмент: создаёт неподвижного бота-манекена (настоящего игрока с персонажем) для проверки механик — транквилизатора, ран, ЭМИ, оружия и т.д."

-- Глобальный PLUGIN существует только во время загрузки файла. Таймеры и колбэки
-- команд выполняются позже, когда глобаль уже nil, поэтому захватываем ссылку локально.
local PLUGIN = PLUGIN

-- Манекен — это обычный бот. Helix автоматически выдаёт ему персонажа, модель и
-- лимбы системы здоровья (ядро: PlayerInitialSpawn -> ix.char.New + limbobject),
-- поэтому он ведёт себя как живой игрок: IsPlayer() == true, есть GetCharacter(),
-- работает SetRagdolled, раны и весь !healthsystem. Мы лишь обездвиживаем его и
-- ставим туда, куда смотрит админ.

-- Каждый тик обнуляем ввод манекена: он стоит на месте и ничего не делает.
-- Это per-bot (в отличие от глобального bot_zombie), не мешает обычным ботам.
hook.Add("StartCommand", "ixDummyFreeze", function(client, cmd)
	if (!client.ixIsDummy) then return end

	cmd:ClearMovement()
	cmd:ClearButtons()
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetUpMove(0)

	if (client.ixDummyAngles) then
		cmd:SetViewAngles(client.ixDummyAngles)
	end
end)

-- Command definitions must also reach the client (chat/help/autocomplete).
-- Only their implementation belongs to the server.
if SERVER then

local comparisonHeights = {155, 180, 190}

-- Доводим только что подключившегося бота до состояния манекена.
function PLUGIN:SetupDummy(bot, admin, selectedHeight)
	bot.ixIsDummy = true
	bot.ixDummyCreator = admin
	selectedHeight = selectedHeight or 180

	if (IsValid(admin)) then
		local tr = admin:GetEyeTraceNoCursor()
		local pos = tr.HitPos + tr.HitNormal * 4

		-- Развернуть лицом к админу.
		local ang = (admin:GetPos() - pos):Angle()
		bot.ixDummyAngles = Angle(0, ang.y, 0)

		bot:SetPos(pos)
		bot:SetEyeAngles(bot.ixDummyAngles)
	end

	bot:SetMoveType(MOVETYPE_WALK)

	local char = bot:GetCharacter()

	if (char) then
		char:SetName("Манекен #" .. bot:EntIndex() .. " — " .. selectedHeight .. " см")
		if IsValid(admin) then
			char:SetModel(admin:GetModel())
			bot:SetModel(admin:GetModel())
			bot:SetSkin(admin:GetSkin())
			for _, group in ipairs(admin:GetBodyGroups()) do bot:SetBodygroup(group.id, admin:GetBodygroup(group.id)) end
		end
		-- Store the value on the character, so the normal height timer, revive
		-- and ragdoll creation all use the same dimensions as a real player.
		local genetic = char.Genetic and char:Genetic()
		if genetic then
			genetic.height = selectedHeight
			genetic.cachedSave, genetic.cachedDesc = nil, nil
			genetic:Sync()
		end
		if ix.CharacterHeight and genetic then
			ix.CharacterHeight.Apply(bot, true)
		else
			bot:SetModelScale(selectedHeight / 180, 0)
		end
	end
end

-- Сбросить манекен в исходное «здоровое стоячее» состояние.
function PLUGIN:ResetDummy(bot)
	if ix.BodyDrag then ix.BodyDrag.DropPatient(bot) end
	if bot.SetAction then bot:SetAction() end
	bot.ixRegainConscious = nil
	bot.ixDownedEnding = nil
	bot.ixGiveUpRequest = nil
	-- Поднять, если лежит после транквилизатора/нокдауна.
	if (IsValid(bot.ixRagdoll)) then
		bot.ixRagdoll:Remove() -- CallOnRemove("fixer") возвращает игрока в норму
	end

	if (!bot:Alive()) then
		bot:Spawn()
	end

	local char = bot:GetCharacter()

	if (char and char.Health) then
		char:Health():Reset()
	end

	bot:SetHealth(bot:GetMaxHealth())
	bot:SetCriticalState(false)
	bot:SetLocalVar("knocked", false)
	bot:SetLocalVar("blur", nil)
end

function PLUGIN:CreateDummy(client, selectedHeight)
	local automatic = selectedHeight == nil
	if not automatic then
		selectedHeight = tonumber(selectedHeight)
		if not selectedHeight or selectedHeight ~= selectedHeight or selectedHeight < 155 or selectedHeight > 190
			or selectedHeight ~= math.floor(selectedHeight) then return "Укажите целый рост от 155 до 190 см." end
	end
	if game.SinglePlayer() or game.MaxPlayers() < 2 then
		return "Манекен — настоящий игрок-бот. Запустите локальную игру на 2 или больше игроков; приглашать кого-либо не нужно."
	end
	if #player.GetAll() >= game.MaxPlayers() then return "Нет свободного места для манекена (слота игрока)." end
	local bot = player.CreateNextBot("IX Dummy")
	if not IsValid(bot) then return "Не удалось создать манекен: нет свободного слота игрока." end
	if automatic then
		local index = client.ixDummyHeightIndex or 1
		selectedHeight = comparisonHeights[index]
		-- Reserve immediately: several pending character loads must not all
		-- receive the same height. Explicit heights leave this cycle untouched.
		client.ixDummyHeightIndex = index % #comparisonHeights + 1
	end
	bot.ixIsDummy, bot.ixDummyCreator = true, client
	local tries = 0
	local function Ready()
		if not IsValid(bot) then return end
		if not IsValid(client) then bot:Kick("Создатель отключился") return end
		if not bot:GetCharacter() then
			tries = tries + 1
			if tries < 30 then timer.Simple(0.1, Ready) return end
			bot:Kick("Персонаж манекена не загрузился")
			client:Notify("Не удалось загрузить IX-персонажа манекена.")
			return
		end
		PLUGIN:SetupDummy(bot, client, selectedHeight)
		client:Notify("Манекен создан: " .. selectedHeight .. " см. /dummyfallover — уложить; /dummyrevive — поднять.")
	end
	timer.Simple(0, Ready)
end

function PLUGIN:GetDummies(client)
	local entity = client:GetEyeTraceNoCursor().Entity
	local aimed = IsValid(entity) and (entity.ixPlayer or entity)
	if IsValid(aimed) and aimed:IsPlayer() and aimed:IsBot() and aimed.ixIsDummy then return {aimed} end
	local result = {}
	for _, bot in ipairs(player.GetAll()) do
		if bot:IsBot() and bot.ixIsDummy then result[#result + 1] = bot end
	end
	return result
end
end -- SERVER

ix.command.Add("DummyCreate", {
	alias = "DummyAdd",
	description = "Создать манекен в прицеле. Рост 155–190 см; без числа — по очереди 155, 180 и 190 см.",
	adminOnly = true,
	arguments = {bit.bor(ix.type.number, ix.type.optional)},
	OnRun = function(self, client, height)
		return PLUGIN:CreateDummy(client, height)
	end
})

ix.command.Add("DummyRevive", {
	description = "Вылечить и поднять манекен в прицеле (без цели — всех манекенов).",
	adminOnly = true,
	OnRun = function(_, client)
		local targets = PLUGIN:GetDummies(client)
		for _, bot in ipairs(targets) do PLUGIN:ResetDummy(bot) end
		return "Поднято манекенов: " .. #targets
	end
})

ix.command.Add("DummyFallover", {
	description = "Уложить манекен для проверки перетаскивания; /dummyrevive поднимает его.",
	adminOnly = true,
	OnRun = function(_, client)
		local targets = PLUGIN:GetDummies(client)
		for _, bot in ipairs(targets) do
			if bot:Alive() and not IsValid(bot.ixRagdoll) then bot:SetRagdolled(true, nil, 0) end
		end
		return "Уложено манекенов: " .. #targets
	end
})

ix.command.Add("DummyDown", {
	description = "Перевести манекен в критическое состояние для проверки защиты от урона.",
	adminOnly = true,
	OnRun = function(_, client)
		local targets = PLUGIN:GetDummies(client)
		for _, bot in ipairs(targets) do if bot:Alive() then bot:SetCriticalState(true) end end
		return "В критическом состоянии: " .. #targets
	end
})

ix.command.Add("DummyBring", {
	description = "Переместить всех манекенов туда, куда вы смотрите.",
	adminOnly = true,
	OnRun = function(self, client)
		local tr = client:GetEyeTraceNoCursor()
		local pos = tr.HitPos + tr.HitNormal * 4
		local count = 0

		for _, v in ipairs(player.GetAll()) do
			if (v:IsBot() and v.ixIsDummy) then
				PLUGIN:ResetDummy(v)
				if (IsValid(v.ixRagdoll)) then
					v.ixRagdoll:Remove()
				end

				v:SetPos(pos)

				local ang = (client:GetPos() - pos):Angle()
				v.ixDummyAngles = Angle(0, ang.y, 0)
				v:SetEyeAngles(v.ixDummyAngles)

				count = count + 1
			end
		end

		return "Перемещено манекенов: " .. count
	end
})

ix.command.Add("DummyHeal", {
	description = "Полностью вылечить и поднять всех манекенов (сброс для следующего теста).",
	adminOnly = true,
	OnRun = function(self, client)
		local count = 0

		for _, v in ipairs(player.GetAll()) do
			if (v:IsBot() and v.ixIsDummy) then
				PLUGIN:ResetDummy(v)
				count = count + 1
			end
		end

		return "Сброшено манекенов: " .. count
	end
})

ix.command.Add("DummyRemove", {
	description = "Удалить всех ботов-манекенов.",
	adminOnly = true,
	OnRun = function(self, client)
		local count = 0

		for _, v in ipairs(player.GetAll()) do
			if (v:IsBot() and v.ixIsDummy) then
				v:Kick("Манекен удалён")
				count = count + 1
			end
		end

		return "Удалено манекенов: " .. count
	end
})
