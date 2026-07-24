function Schema:InitializedChatClasses()
	
	-- 1. IC
	ix.chat.Register("ic", {
		font = "ixChatFontNormal",
		format = " \"%s\"",
		indicator = "chatTalking",
		GetColor = function(self, speaker, text)
			if (speaker:GetEyeTraceNoCursor().Entity == LocalPlayer()) then
				return ix.config.Get("chatListenColor")
			end
			return ix.config.Get("chatColor")
		end,
		CanHear = ix.config.Get("chatRange", 280),
		OnChatAdd = function(self, speaker, text, anonymous, info)
			local icon, langPrefix
			local isValidLang = ix.languages:FindByID(info.lang or "")
			if info.lang and isValidLang then icon, langPrefix, text = ix.languages.OnChatAdd(speaker, text, info.lang) end

			local color = self:GetColor(speaker, text, info)
			local name = anonymous and L"someone" or hook.Run("GetCharacterName", speaker, "ic") or (IsValid(speaker) and speaker:Name() or "Console")
			local bToYou = speaker:GetEyeTraceNoCursor().Entity == LocalPlayer()

			chat.AddText(icon or "", color, ix.util.GetMaterial("cellar/chat/ic.png") or "", name, L("chat.ic.says") or " говорит: ", langPrefix or "", bToYou and (L("chat.toYou") or "") or "", color_white, string.format(self.format, text))
		end
	})

	-- 2. Крик (/y, /yell)
	ix.chat.Register("y", {
		font = "ixChatFontYell", 
		format = " \"%s\"",
		indicator = "chatYelling",
		prefix = {"/Y", "/Yell"},
		GetColor = function(self, speaker, text) return Color(255, 50, 50) end, -- Ярко-красный
		CanHear = ix.config.Get("chatRange", 280) * 2,
		OnChatAdd = function(self, speaker, text, anonymous, info)
			local icon, langPrefix
			local isValidLang = ix.languages:FindByID(info.lang or "")
			if info.lang and isValidLang then 
				icon, langPrefix, text = ix.languages.OnChatAdd(speaker, text, info.lang) 
			end

			local color = self:GetColor(speaker, text, info)
			local name = anonymous and L"someone" or hook.Run("GetCharacterName", speaker, "y") or (IsValid(speaker) and speaker:Name() or "Console")
			
			local prefixText = " кричит: "
			if langPrefix and langPrefix != "" then
				prefixText = prefixText .. langPrefix
			end

			if icon then
				chat.AddText(icon, color, name, prefixText, color_white, string.format(self.format, text))
			else
				chat.AddText(color, name, prefixText, color_white, string.format(self.format, text))
			end
		end
	})

	-- 3. Шепот (/w, /whisper)
	ix.chat.Register("w", {
		font = "ixChatFontWhisper",
		format = " \"%s\"",
		indicator = "chatWhispering",
		prefix = {"/W", "/Whisper"},
		GetColor = function(self, speaker, text) return Color(160, 160, 160) end, -- Серый
		CanHear = ix.config.Get("chatRange", 280) * 0.25,
		OnChatAdd = function(self, speaker, text, anonymous, info)
			local icon, langPrefix
			local isValidLang = ix.languages:FindByID(info.lang or "")
			if info.lang and isValidLang then 
				icon, langPrefix, text = ix.languages.OnChatAdd(speaker, text, info.lang) 
			end

			local color = self:GetColor(speaker, text, info)
			local name = anonymous and L"someone" or hook.Run("GetCharacterName", speaker, "w") or (IsValid(speaker) and speaker:Name() or "Console")
			
			local prefixText = " шепчет: "
			if langPrefix and langPrefix != "" then
				prefixText = prefixText .. langPrefix
			end

			if icon then
				chat.AddText(icon, color, name, prefixText, color_white, string.format(self.format, text))
			else
				chat.AddText(color, name, prefixText, color_white, string.format(self.format, text))
			end
		end
	})

	-- ==========================================
	-- КОМАНДЫ ДЕЙСТВИЙ (/me, /mec, /mel)
	-- ==========================================
	local function OnChatAddMe(self, speaker, text, anonymous, info)
		local color = self:GetColor(speaker, text, info)
		local name = anonymous and L"someone" or hook.Run("GetCharacterName", speaker, self.uniqueID) or (IsValid(speaker) and speaker:Name() or "Console")
		chat.AddText(color, "** " .. name .. " ", text)
	end

	ix.chat.Register("me", {
		font = "ixChatFontMe",
		format = "%s", indicator = "chatPerforming", prefix = {"/Me", "/Action"},
		GetColor = function(self, speaker, text) return Color(255, 200, 50) end,
		CanHear = ix.config.Get("chatRange", 280),
		OnChatAdd = OnChatAddMe
	})

	ix.chat.Register("mec", {
		font = "ixChatFontWhisperItalic",
		format = "%s", indicator = "chatPerforming", prefix = {"/MeC"},
		GetColor = function(self, speaker, text) return Color(255, 200, 50) end,
		CanHear = ix.config.Get("chatRange", 280) * 0.25,
		OnChatAdd = OnChatAddMe
	})

	ix.chat.Register("mel", {
		font = "ixChatFontLargeItalic",
		format = "%s", indicator = "chatPerforming", prefix = {"/MeL"},
		GetColor = function(self, speaker, text) return Color(255, 200, 50) end,
		CanHear = ix.config.Get("chatRange", 280) * 2,
		OnChatAdd = OnChatAddMe
	})

	-- ==========================================
	-- КОМАНДЫ ОКРУЖЕНИЯ (/it, /itc, /itl)
	-- ==========================================
	local function OnChatAddIt(self, speaker, text, anonymous, info)
		local color = self:GetColor(speaker, text, info)
		chat.AddText(color, "** ", text)
	end

	ix.chat.Register("it", {
		font = "ixChatFontMe",
		format = "%s", indicator = "chatPerforming", prefix = {"/It"},
		GetColor = function(self, speaker, text) return Color(150, 255, 150) end,
		CanHear = ix.config.Get("chatRange", 280),
		OnChatAdd = OnChatAddIt
	})

	ix.chat.Register("itc", {
		font = "ixChatFontWhisperItalic",
		format = "%s", indicator = "chatPerforming", prefix = {"/ItC"},
		GetColor = function(self, speaker, text) return Color(150, 255, 150) end,
		CanHear = ix.config.Get("chatRange", 280) * 0.25,
		OnChatAdd = OnChatAddIt
	})

	ix.chat.Register("itl", {
		font = "ixChatFontLargeItalic",
		format = "%s", indicator = "chatPerforming", prefix = {"/ItL"},
		GetColor = function(self, speaker, text) return Color(150, 255, 150) end,
		CanHear = ix.config.Get("chatRange", 280) * 2,
		OnChatAdd = OnChatAddIt
	})


	-- Локальный ивент (/localevent) — как глобальный /event, но слышно только рядом
	ix.chat.Register("localevent", {
		CanHear = ix.config.Get("chatRange", 280) * 2,
		OnChatAdd = function(self, speaker, text)
			chat.AddText(Color(255, 150, 0), text)
		end,
		indicator = "chatPerforming"
	})

	-- Dispatch broadcast
	ix.chat.Register("dispatch", {
		color = Color(200, 75, 75),
		format = "chat.dispatch.format",
		CanSay = function(class, speaker, text)
			if (!speaker:IsDispatch() and !speaker:IsAdmin()) then
				speaker:NotifyLocalized("notAllowed")
				return false
			end
		end,
		OnChatAdd = function(class, speaker, text)
			chat.AddText(class.color, ix.util.GetMaterial("cellar/chat/dispatch.png"), L(class.format, text))
		end
	})

	-- Dispatch radio (слышат только Combine)
	ix.chat.Register("dispatch_radio", {
		color = Color(200, 0, 0),
		format = "chat.dispatch_radio.format",
		bReceiveVoices = true,
		CanSay = function(class, speaker, text)
			if (!speaker:IsDispatch() and !speaker:IsAdmin()) then
				speaker:NotifyLocalized("notAllowed")
				return false
			end
		end,
		CanHear = function(class, speaker, listener)
			return listener:IsCombine()
		end,
		OnChatAdd = function(class, speaker, text)
			chat.AddText(class.color, L(class.format, text))
			surface.PlaySound("npc/overwatch/radiovoice/on3.wav")
		end
	})

end