local PLUGIN = PLUGIN

PLUGIN.name        = "GO Alert"
PLUGIN.author      = "Autonomous Team"
PLUGIN.description = "Allows Civil Protection to broadcast a fullscreen alert with sound to all players."

-- ─────────────────────────────────────────────────────────────────────────────
-- НАСТРОЙКА
-- Укажи звуки которые можно использовать в команде
-- ─────────────────────────────────────────────────────────────────────────────

PLUGIN.sounds = {
	["alarm"]    = "ambient/alarms/warningbell1.wav",
	["alert"]    = "ambient/alarms/klaxon1.wav",
	["buzzer"]   = "ambient/alarms/buzzbeep1.wav",
	["radio"]    = "ambient/levels/prison/radio_random1.wav",
	["intercom"] = "ambient/levels/canals/city_intercom1.wav",
}

-- ─────────────────────────────────────────────────────────────────────────────
-- ЛОКАЛИЗАЦИЯ
-- ─────────────────────────────────────────────────────────────────────────────

ix.lang.AddTable("en", {
	cmdGoAlertDesc     = "Broadcast a fullscreen alert. Usage: /goalert [sound] <message>",
	cmdGoAlertClearDesc = "Clear the active alert from all screens.",
	goAlertNoAccess    = "Only Civil Protection can use this command.",
})

ix.lang.AddTable("ru", {
	cmdGoAlertDesc     = "Вывести полноэкранный алерт. Использование: /goalert [звук] <сообщение>",
	cmdGoAlertClearDesc = "Убрать активный алерт с экранов всех игроков.",
	goAlertNoAccess    = "Только гражданская охрана может использовать эту команду.",
})

-- ─────────────────────────────────────────────────────────────────────────────
-- КОМАНДЫ (shared — обязательно вне if SERVER)
-- ─────────────────────────────────────────────────────────────────────────────

-- /goalert [sound] <message>
-- Примеры:
--   /goalert Внимание! Комендантский час введён.
--   /goalert alarm Тревога! Немедленно покиньте зону.
--   /goalert radio Секция 7 закрыта для гражданского доступа.

ix.command.Add("GOAlert", {
	description = "@cmdGoAlertDesc",
	adminOnly   = true,
	arguments   = ix.type.text,

	OnRun = function(self, client, rawArgs)
		if CLIENT then return end

		-- Проверяем что игрок в фракции МПФ/ГО
		local faction = client:GetCharacter() and client:GetCharacter():GetFaction()
		if faction != FACTION_MPF and faction != FACTION_OTA and faction != FACTION_EOW then
			client:NotifyLocalized("goAlertNoAccess")
			return
		end

		local args   = string.Explode(" ", rawArgs)
		local sound  = nil
		local offset = 1

		-- Проверяем первое слово — может быть ключём звука
		if args[1] and PLUGIN.sounds[args[1]:lower()] then
			sound  = PLUGIN.sounds[args[1]:lower()]
			offset = 2
		end

		local message = table.concat(args, " ", offset)
		if message == "" then
			client:Notify("Usage: /goalert [sound] <message>")
			return
		end

		netstream.Start(nil, "ixGOAlert", {
			message = message,
			sound   = sound,
		})
	end
})

ix.command.Add("GOAlertClear", {
	description = "@cmdGoAlertClearDesc",
	adminOnly   = true,

	OnRun = function(self, client)
		if CLIENT then return end

		local faction = client:GetCharacter() and client:GetCharacter():GetFaction()
		if faction != FACTION_MPF and faction != FACTION_OTA and faction != FACTION_EOW then
			client:NotifyLocalized("goAlertNoAccess")
			return
		end

		netstream.Start(nil, "ixGOAlertClear")
	end
})

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVER
-- ─────────────────────────────────────────────────────────────────────────────

if SERVER then
	util.AddNetworkString("ixGOAlert")
	util.AddNetworkString("ixGOAlertClear")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CLIENT
-- ─────────────────────────────────────────────────────────────────────────────

if CLIENT then

	local alert = {
		active   = false,
		message  = "",
		showAt   = 0,     -- CurTime() когда появился
		duration = 6,     -- секунд до начала fade out
		fadeOut  = 1.5,   -- длительность fade out
	}

	-- Шрифты
	local function createFonts()
		surface.CreateFont("ixGOAlertTitle", {
			font      = "Arial",
			size      = math.max(ScreenScale(28), 40),
			weight    = 700,
			antialias = true,
			extended  = true,
		})
		surface.CreateFont("ixGOAlertSub", {
			font      = "Arial",
			size      = math.max(ScreenScale(10), 16),
			weight    = 400,
			antialias = true,
			extended  = true,
		})
	end

	createFonts()

	hook.Add("OnScreenSizeChanged", "ixGOAlertFonts", function()
		createFonts()
	end)

	-- ── Получение алерта ─────────────────────────────────────────────────────

	netstream.Hook("ixGOAlert", function(data)
		alert.active  = true
		alert.message = data.message or ""
		alert.showAt  = CurTime()

		if data.sound and data.sound != "" then
			surface.PlaySound(data.sound)
		end
	end)

	netstream.Hook("ixGOAlertClear", function()
		alert.active = false
	end)

	-- ── Отрисовка ────────────────────────────────────────────────────────────

	hook.Add("HUDPaint", "ixGOAlertDraw", function()
		if not alert.active then return end

		local now     = CurTime()
		local elapsed = now - alert.showAt
		local total   = alert.duration + alert.fadeOut

		-- Автоматически убираем после полного цикла
		if elapsed >= total then
			alert.active = false
			return
		end

		-- Alpha: fade in 0.3s → полный → fade out
		local alpha
		local fadeIn = 0.3
		if elapsed < fadeIn then
			alpha = (elapsed / fadeIn) * 255
		elseif elapsed < alert.duration then
			alpha = 255
		else
			alpha = (1 - (elapsed - alert.duration) / alert.fadeOut) * 255
		end
		alpha = math.Clamp(alpha, 0, 255)

		local sw, sh = ScrW(), ScrH()

		-- Тёмный полупрозрачный фон
		surface.SetDrawColor(0, 0, 0, alpha * 0.75)
		surface.DrawRect(0, 0, sw, sh)

		-- Красная полоса по центру
		local barH  = sh * 0.18
		local barY  = sh * 0.5 - barH * 0.5
		surface.SetDrawColor(180, 15, 15, alpha * 0.92)
		surface.DrawRect(0, barY, sw, barH)

		-- Тонкие линии сверху и снизу полосы (интерфейсный стиль)
		surface.SetDrawColor(220, 40, 40, alpha)
		surface.DrawRect(0, barY,          sw, 2)
		surface.DrawRect(0, barY + barH - 2, sw, 2)

		-- Мигание: быстрые вспышки в первые 2 секунды
		if elapsed < 2 then
			local blink = math.sin(elapsed * 18) > 0.3
			if blink then
				surface.SetDrawColor(220, 20, 20, alpha * 0.15)
				surface.DrawRect(0, barY, sw, barH)
			end
		end

		-- Текст сообщения
		local cx = sw * 0.5
		local cy = sh * 0.5

		-- Тень
		draw.SimpleText(
			alert.message, "ixGOAlertTitle",
			cx + 2, cy + 2,
			Color(0, 0, 0, alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)
		-- Основной текст
		draw.SimpleText(
			alert.message, "ixGOAlertTitle",
			cx, cy,
			Color(255, 255, 255, alpha),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)

		-- Маленькая подпись снизу полосы
		draw.SimpleText(
			"CIVIL PROTECTION — OVERWATCH BROADCAST",
			"ixGOAlertSub",
			cx, barY + barH - 20,
			Color(200, 200, 200, alpha * 0.7),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
		)
	end)

end
