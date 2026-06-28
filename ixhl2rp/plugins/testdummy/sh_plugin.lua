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

if (!SERVER) then return end

-- Доводим только что подключившегося бота до состояния манекена.
function PLUGIN:SetupDummy(bot, admin)
	bot.ixIsDummy = true

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
		char:SetName("Манекен #" .. bot:EntIndex())
	end
end

-- Сбросить манекен в исходное «здоровое стоячее» состояние.
function PLUGIN:ResetDummy(bot)
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
end

ix.command.Add("DummyAdd", {
	description = "Создать неподвижного бота-манекена там, куда вы смотрите.",
	adminOnly = true,
	OnRun = function(self, client)
		-- Запоминаем уже существующих ботов, чтобы найти именно нового.
		local existing = {}

		for _, v in ipairs(player.GetAll()) do
			if (v:IsBot()) then
				existing[v] = true
			end
		end

		game.ConsoleCommand("bot\n")

		-- Бот подключается асинхронно; ждём, потом донастраиваем.
		timer.Simple(0.6, function()
			local bot

			for _, v in ipairs(player.GetAll()) do
				if (v:IsBot() and !existing[v]) then
					bot = v
					break
				end
			end

			if (!IsValid(bot)) then
				if (IsValid(client)) then
					client:Notify("Не удалось создать бота. Проверьте, что есть свободный слот (maxplayers) и команда bot доступна.")
				end

				return
			end

			PLUGIN:SetupDummy(bot, client)

			if (IsValid(client)) then
				client:Notify("Манекен создан.")
			end
		end)
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
