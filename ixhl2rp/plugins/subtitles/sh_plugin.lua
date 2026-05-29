local PLUGIN = PLUGIN

PLUGIN.name        = "Cinematic Subtitles"
PLUGIN.author      = "Autonomous Team"
PLUGIN.description = "Allows admins to display cinematic subtitles to nearby or all players."

ix.lang.AddTable("en", {
	cmdSubtitleDesc      = "Cinematic subtitle. Usage: /subtitle [all|range] <seconds> [sc:R,G,B] [tc:R,G,B] <Speaker_Name> <text>",
	cmdSubtitleClearDesc = "Clear all active subtitles from everyone's screen.",
})

ix.lang.AddTable("ru", {
	cmdSubtitleDesc      = "Кинематографический субтитр. Использование: /subtitle [all|range] <секунды> [sc:R,G,B] [tc:R,G,B] <Имя_спикера> <текст>",
	cmdSubtitleClearDesc = "Убрать все активные субтитры с экранов игроков.",
})

-- ─────────────────────────────────────────────
-- COMMANDS  (shared scope — required for chat visibility)
-- ─────────────────────────────────────────────

-- /subtitle [all|range] <duration> [sc:R,G,B] [tc:R,G,B] <Speaker_Name> <text>
-- sc = speaker color, tc = text color. Both optional, default to white/grey.
-- Examples:
--   /subtitle all 6 PA_System Attention citizens. Report to sector 7.
--   /subtitle range 4 sc:255,200,50 Old_Man They took everything from us.
--   /subtitle 5 sc:200,100,100 tc:255,255,255 Guard Move along.

local colorAliases = {
	red    = "255,60,60",
	blue   = "80,140,255",
	yellow = "255,220,50",
	black  = "20,20,20",
	white  = "255,255,255",
	green  = "80,210,100",
	orange = "255,150,30",
}

local function parseColor(str)
	str = colorAliases[str:lower()] or str
	local r, g, b = str:match("^(%d+),(%d+),(%d+)$")
	if r then
		return Color(tonumber(r), tonumber(g), tonumber(b))
	end
end

ix.command.Add("Subtitle", {
	description = "@cmdSubtitleDesc",
	adminOnly   = true,
	arguments   = ix.type.text,

	OnRun = function(self, client, rawArgs)
		if CLIENT then return end

		local args   = string.Explode(" ", rawArgs)
		local mode   = "range"
		local offset = 1

		if args[1] == "all" or args[1] == "range" then
			mode   = args[1]
			offset = 2
		end

		local duration = tonumber(args[offset])
		if not duration then
			client:Notify("Usage: /subtitle [all|range] <seconds> [sc:R,G,B] [tc:R,G,B] <Speaker_Name> <text>")
			return
		end
		duration = math.Clamp(duration, 1, 30)
		offset   = offset + 1

		-- Optional color args: sc:R,G,B and tc:R,G,B in any order
		local speakerColor, textColor
		while args[offset] do
			local prefix, value = args[offset]:match("^(sc):(.+)$")
			if prefix then
				speakerColor = parseColor(value)
				offset = offset + 1
			else
				prefix, value = args[offset]:match("^(tc):(.+)$")
				if prefix then
					textColor = parseColor(value)
					offset    = offset + 1
				else
					break
				end
			end
		end

		local rest           = table.concat(args, " ", offset)
		local speaker, text  = rest:match("^(%S+)%s+(.+)$")

		if not speaker or not text then
			speaker = ""
			text    = rest
		end

		speaker = speaker:gsub("_", " ")

		local payload = {
			speaker      = speaker,
			text         = text,
			duration     = duration,
			speakerColor = speakerColor and {speakerColor.r, speakerColor.g, speakerColor.b} or nil,
			textColor    = textColor    and {textColor.r,    textColor.g,    textColor.b}    or nil,
		}

		if mode == "all" then
			netstream.Start(nil, "ixSubtitleShow", payload)
		else
			local senderPos = client:GetPos()
			local receivers = {}

			for _, ply in ipairs(player.GetAll()) do
				if ply:GetPos():DistToSqr(senderPos) <= (1500 * 1500) then
					receivers[#receivers + 1] = ply
				end
			end

			if #receivers > 0 then
				netstream.Start(receivers, "ixSubtitleShow", payload)
			end
		end
	end
})

ix.command.Add("SubtitleClear", {
	description = "@cmdSubtitleClearDesc",
	adminOnly   = true,

	OnRun = function(self, client)
		if CLIENT then return end
		netstream.Start(nil, "ixSubtitleClear")
	end
})

-- ─────────────────────────────────────────────
-- SERVER
-- ─────────────────────────────────────────────

if SERVER then
	util.AddNetworkString("ixSubtitleShow")
	util.AddNetworkString("ixSubtitleClear")
end

-- ─────────────────────────────────────────────
-- CLIENT
-- ─────────────────────────────────────────────

if CLIENT then

	local subtitle = {
		speaker      = "",
		text         = "",
		expireAt     = 0,
		fadeIn       = 0,
		fadeOut      = 0,
		speakerColor = Color(200, 200, 200),
		textColor    = Color(255, 255, 255),
	}

	local FADE_TIME = 0.4
	local FONT_MAIN = "ixMediumFont"
	local FONT_SPKR = "ixGenericFont"

	netstream.Hook("ixSubtitleShow", function(payload)
		local now         = CurTime()
		subtitle.speaker  = payload.speaker or ""
		subtitle.text     = payload.text    or ""
		subtitle.fadeIn   = now
		subtitle.expireAt = now + payload.duration
		subtitle.fadeOut  = now + payload.duration - FADE_TIME

		-- Unpack colors from array (Color objects don't survive netstream serialization)
		local sc = payload.speakerColor
		local tc = payload.textColor
		subtitle.speakerColor = sc and Color(sc[1], sc[2], sc[3]) or Color(200, 200, 200)
		subtitle.textColor    = tc and Color(tc[1], tc[2], tc[3]) or Color(255, 255, 255)
	end)

	netstream.Hook("ixSubtitleClear", function()
		subtitle.expireAt = 0
	end)

	hook.Add("HUDPaint", "ixCinematicSubtitles", function()
		local now = CurTime()
		if now > subtitle.expireAt then return end

		local fadeInProg  = math.Clamp((now - subtitle.fadeIn)  / FADE_TIME, 0, 1)
		local fadeOutProg = math.Clamp((now - subtitle.fadeOut) / FADE_TIME, 0, 1)
		local alpha       = 255 * math.min(fadeInProg, 1 - fadeOutProg)
		if alpha <= 0 then return end

		local sw, sh  = ScrW(), ScrH()
		local centerX = sw * 0.5
		local bottomY = sh * 0.82

		surface.SetFont(FONT_MAIN)
		local textW, textH = surface.GetTextSize(subtitle.text)

		local speakerH = 0
		if subtitle.speaker != "" then
			surface.SetFont(FONT_SPKR)
			local _, h = surface.GetTextSize(subtitle.speaker)
			speakerH = h + 4
		end

		local padX = 24
		local padY = 12
		local boxW = textW + padX * 2
		local boxH = textH + speakerH + padY * 2
		local boxX = centerX - boxW * 0.5
		local boxY = bottomY - boxH

		draw.RoundedBox(6, boxX, boxY, boxW, boxH, Color(0, 0, 0, alpha * 0.6))

		surface.SetDrawColor(200, 200, 200, alpha * 0.8)
		surface.DrawRect(boxX, boxY + padY, 2, boxH - padY * 2)

		local textY = boxY + padY

		if subtitle.speaker != "" then
			local sc = subtitle.speakerColor
			draw.SimpleText(subtitle.speaker, FONT_SPKR, centerX, textY, Color(sc.r, sc.g, sc.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			textY = textY + speakerH
		end

		local tc = subtitle.textColor
		draw.SimpleText(subtitle.text, FONT_MAIN, centerX, textY, Color(tc.r, tc.g, tc.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end)

end
