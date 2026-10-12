local PLUGIN = PLUGIN

local function Scale(value)
	return math.max(1, math.Round(value * math.Clamp(ScrH() / 1080, 0.75, 1.6)))
end

local function Fonts()
	surface.CreateFont("ixTVSubtitle", {font="Roboto", size=Scale(23), weight=500, extended=true, antialias=true})
	surface.CreateFont("ixTVSubtitleLabel", {font="Consolas", size=Scale(12), weight=500, extended=true, antialias=true})
end
Fonts()
hook.Add("OnScreenSizeChanged", "ix_tv_subtitle_fonts", Fonts)

function PLUGIN:ClearTVPlayback()
	self.tvPlayback = nil
	self.tvSubtitleNearby = false
end

function PLUGIN:SetTVPlayback(panel, time, active)
	if panel ~= self.htmlPanel or not IsValid(panel) or not isnumber(time) or time ~= time
		or time < 0 or time == math.huge then return end
	self.tvPlayback = {time=time, active=active == true, received=RealTime()}
end

function PLUGIN:GetTVSubtitle()
	local playback = self.tvPlayback
	if not self.tvSubtitleNearby or not IsValid(self.htmlPanel) or not playback or not playback.active
		or RealTime() - playback.received > 0.5 then return "" end
	local lines = {}
	for _, cue in ipairs(self.tvSubtitleCues or {}) do
		if cue.start > playback.time then break end
		if playback.time < cue.finish then lines[#lines + 1] = cue.text end
	end
	return table.concat(lines, "\n")
end

-- Preserve explicit line breaks and UTF-8 characters, even in long unbroken words.
function PLUGIN:WrapTVSubtitle(text, width)
	local lines = {}
	surface.SetFont("ixTVSubtitle")
	for paragraph in (text .. "\n"):gmatch("(.-)\n") do
		local line = ""
		for word in paragraph:gmatch("%S+") do
			local joined = line == "" and word or (line .. " " .. word)
			if surface.GetTextSize(joined) <= width then line = joined
			else
				if line ~= "" then lines[#lines + 1] = line; line = "" end
				for character in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
					if line ~= "" and surface.GetTextSize(line .. character) > width then
						lines[#lines + 1] = line; line = ""
					end
					line = line .. character
				end
			end
		end
		lines[#lines + 1] = line
	end
	return lines
end

local alpha, shown, wrapped, lastWidth, lastHeight = 0, "", {}, 0, 0
local function WithAlpha(color, opacity)
	return Color(color.r, color.g, color.b, opacity)
end
hook.Add("HUDPaint", "ix_tv_subtitle_hud", function()
	local client = LocalPlayer()
	local hidden = not IsValid(client) or not client:GetCharacter()
		or (IsValid(ix.gui.characterMenu) and ix.gui.characterMenu:IsVisible())
		or (IsValid(ix.gui.menu) and ix.gui.menu:IsVisible())
		or hook.Run("HUDShouldDraw", "ixTVSubtitles") == false
	if hidden then alpha = 0; return end
	local text = PLUGIN:GetTVSubtitle()
	local reducedMotion = ix.option.Get("disableAnimations", false)
	alpha = reducedMotion and (text ~= "" and 1 or 0)
		or math.Approach(alpha, text ~= "" and 1 or 0, FrameTime() * 8)
	if alpha <= 0 then return end
	local width = math.min(Scale(860), ScrW() * 0.76)
	local padding = Scale(25)
	if (text ~= "" and text ~= shown) or lastWidth ~= width or lastHeight ~= ScrH() then
		if text ~= "" then shown = text end
		wrapped = PLUGIN:WrapTVSubtitle(shown, width - padding * 2)
		lastWidth, lastHeight = width, ScrH()
	end
	local lineHeight = Scale(30)
	local maxLines = math.max(2, math.floor(ScrH() * 0.35 / lineHeight))
	local count = math.min(#wrapped, maxLines)
	local height = Scale(48) + count * lineHeight
	local x = (ScrW() - width) / 2
	local y = ScrH() * 0.89 - height + (reducedMotion and 0 or Scale(5) * (1 - alpha))
	local theme = ix.InterfaceOS
	local accent = theme and theme.accent or Color(255,53,76)
	local ink = theme and theme.ink or Color(240,221,223)
	local muted = theme and theme.muted or Color(174,139,147)
	local panel = Color(27,9,16,210 * alpha)
	if theme then theme.Plate(x,y,width,height,panel)
	else surface.SetDrawColor(panel); surface.DrawRect(x,y,width,height) end
	surface.SetDrawColor(WithAlpha(accent, 210 * alpha))
	surface.DrawRect(x, y + Scale(12), Scale(3), height - Scale(24))
	surface.DrawRect(x + padding, y, Scale(38), 1)
	surface.DrawRect(x + width - padding - Scale(38), y + height - 1, Scale(38), 1)
	draw.SimpleText("SCiPNET / ТЕЛЕЭФИР", "ixTVSubtitleLabel", x + padding, y + Scale(12), WithAlpha(muted, 230 * alpha))
	for i = 1, count do
		local line = wrapped[i]
		if i == count and #wrapped > count then line = line .. "…" end
		draw.SimpleText(line, "ixTVSubtitle", x + width / 2, y + Scale(34) + (i - 1) * lineHeight,
			WithAlpha(ink, 255 * alpha), TEXT_ALIGN_CENTER)
	end
end)
