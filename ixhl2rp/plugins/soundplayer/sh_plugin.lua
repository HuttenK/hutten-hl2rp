local PLUGIN = PLUGIN

PLUGIN.name        = "Sound Player"
PLUGIN.author      = "Autonomous Team"
PLUGIN.description = "Allows admins to play sounds for players."

-- ─────────────────────────────────────────────────────────────────────────────
-- ЛОКАЛИЗАЦИЯ
-- ─────────────────────────────────────────────────────────────────────────────

ix.lang.AddTable("en", {
	cmdPlaySoundDesc      = "Play a sound. Usage: /playsound [all|range|me] <path>",
	cmdStopSoundDesc      = "Stop a sound for all players or yourself. Usage: /stopsound [all|me] <path>",
	cmdStopAllSoundsDesc  = "Stop ALL sounds for all players.",
})

ix.lang.AddTable("ru", {
	cmdPlaySoundDesc      = "Проиграть звук. Использование: /playsound [all|range|me] <путь>",
	cmdStopSoundDesc      = "Остановить звук. Использование: /stopsound [all|me] <путь>",
	cmdStopAllSoundsDesc  = "Остановить ВСЕ звуки для всех игроков.",
})

-- ─────────────────────────────────────────────────────────────────────────────
-- КОМАНДЫ (shared scope)
-- ─────────────────────────────────────────────────────────────────────────────

-- /playsound [all|range|me] <путь к звуку>
-- Примеры:
--   /playsound ambient/alarms/klaxon1.wav
--   /playsound all music/hl2_song1.mp3
--   /playsound range ambient/levels/prison/radio_random1.wav
--   /playsound me ui/buttonclickrelease.wav

ix.command.Add("PlaySound", {
	description = "@cmdPlaySoundDesc",
	adminOnly   = true,
	arguments   = ix.type.text,

	OnRun = function(self, client, rawArgs)
		if CLIENT then return end

		local args   = string.Explode(" ", rawArgs)
		local mode   = "all"
		local offset = 1

		if args[1] == "all" or args[1] == "range" or args[1] == "me" then
			mode   = args[1]
			offset = 2
		end

		local path = table.concat(args, " ", offset):Trim()
		if path == "" then
			client:Notify("Usage: /playsound [all|range|me] <path>")
			return
		end

		if mode == "me" then
			netstream.Start(client, "ixSoundPlay", path)

		elseif mode == "range" then
			local senderPos = client:GetPos()
			local receivers = {}

			for _, ply in ipairs(player.GetAll()) do
				if ply:GetPos():DistToSqr(senderPos) <= (1500 * 1500) then
					receivers[#receivers + 1] = ply
				end
			end

			if #receivers > 0 then
				netstream.Start(receivers, "ixSoundPlay", path)
			end

		else -- all
			netstream.Start(nil, "ixSoundPlay", path)
		end

		ix.log.Add(client, "soundPlayed", path, mode)
	end
})

-- /stopsound [all|me] <путь>
ix.command.Add("StopSound", {
	description = "@cmdStopSoundDesc",
	adminOnly   = true,
	arguments   = ix.type.text,

	OnRun = function(self, client, rawArgs)
		if CLIENT then return end

		local args   = string.Explode(" ", rawArgs)
		local mode   = "all"
		local offset = 1

		if args[1] == "all" or args[1] == "me" then
			mode   = args[1]
			offset = 2
		end

		local path = table.concat(args, " ", offset):Trim()
		if path == "" then
			client:Notify("Usage: /stopsound [all|me] <path>")
			return
		end

		local target = mode == "me" and client or nil
		netstream.Start(target, "ixSoundStop", path)
	end
})

-- /stopallsounds
ix.command.Add("StopAllSounds", {
	description = "@cmdStopAllSoundsDesc",
	adminOnly   = true,

	OnRun = function(self, client)
		if CLIENT then return end
		netstream.Start(nil, "ixSoundStopAll")
	end
})

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVER
-- ─────────────────────────────────────────────────────────────────────────────

if SERVER then
	util.AddNetworkString("ixSoundPlay")
	util.AddNetworkString("ixSoundStop")
	util.AddNetworkString("ixSoundStopAll")

	ix.log.AddType("soundPlayed", function(client, path, mode)
		return string.format("%s played sound '%s' (mode: %s)", client:GetName(), path, mode)
	end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CLIENT
-- ─────────────────────────────────────────────────────────────────────────────

if CLIENT then

	netstream.Hook("ixSoundPlay", function(path)
		surface.PlaySound(path)
	end)

	netstream.Hook("ixSoundStop", function(path)
		surface.StopSound(path)
	end)

	netstream.Hook("ixSoundStopAll", function()
		-- Останавливаем все звуки через системную функцию
		RunConsoleCommand("stopsound")
	end)

end
