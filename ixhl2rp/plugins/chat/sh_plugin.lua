local PLUGIN = PLUGIN

PLUGIN.name = "Chat Counter"
PLUGIN.author = "SchwarzKruppzo"
PLUGIN.description = ""

if CLIENT then
	function PLUGIN:LoadFonts(font, genericFont)
		local baseSize = math.max(ScreenScale(7), 17) * ix.option.Get("chatFontScale", 1)

		surface.CreateFont("ixChatCounter", {
			font     = genericFont,
			size     = baseSize,
			extended = true,
			weight   = 300,
			antialias = true,
			italic   = true
		})

		-- ==========================================
		-- ШРИФТЫ ДЛЯ IC, КРИКА И ШЕПОТА
		-- ==========================================

		-- Базовый IC
		surface.CreateFont("ixChatFontNormal", {
			font     = genericFont,
			size     = math.Round(baseSize),
			extended = true,
			weight   = 400,
			antialias = true,
		})

		-- Крик (/y)
		surface.CreateFont("ixChatFontYell", {
			font     = genericFont,
			size     = math.Round(baseSize * 1.3),
			extended = true,
			weight   = 500,
			antialias = true,
		})

		-- Шепот (/w)
		surface.CreateFont("ixChatFontWhisper", {
			font     = genericFont,
			size     = math.Round(baseSize * 0.8),
			extended = true,
			weight   = 400,
			antialias = true,
		})

		-- ==========================================
		-- ШРИФТЫ ДЛЯ ДЕЙСТВИЙ (/me, /it)
		-- ==========================================

		-- Обычные действия (/me, /it) - немного больше базового + курсив
		surface.CreateFont("ixChatFontMe", {
			font     = genericFont,
			size     = math.Round(baseSize * 1.1),
			extended = true,
			weight   = 400,
			antialias = true,
			italic   = true
		})

		-- Тихие действия (/mec, /itc) - маленькие + курсив
		surface.CreateFont("ixChatFontWhisperItalic", {
			font     = genericFont,
			size     = math.Round(baseSize * 0.8),
			extended = true,
			weight   = 400,
			antialias = true,
			italic   = true
		})

		-- Громкие/масштабные действия (/mel, /itl) - большие + курсив
		surface.CreateFont("ixChatFontLargeItalic", {
			font     = genericFont,
			size     = math.Round(baseSize * 1.3),
			extended = true,
			weight   = 500,
			antialias = true,
			italic   = true
		})

		-- ==========================================
		-- ОСТАЛЬНЫЕ ШРИФТЫ (Из твоей прошлой версии)
		-- ==========================================

		surface.CreateFont("ixChatFontLarge", {
			font     = genericFont,
			size     = math.Round(baseSize * 1.1),
			extended = true,
			weight   = 400,
			antialias = true,
		})

		surface.CreateFont("ixChatFontSmall", {
			font     = genericFont,
			size     = math.Round(baseSize * 0.82),
			extended = true,
			weight   = 300,
			antialias = true,
			italic   = true
		})

		surface.CreateFont("ixChatFontTiny", {
			font     = genericFont,
			size     = math.Round(baseSize * 0.72),
			extended = true,
			weight   = 300,
			antialias = true,
			italic   = true
		})
	end

	--- Save the current chatbox position and size to the client's options.
	function PLUGIN:SavePosition()
		local chat = ix.gui.chat
		if !IsValid(chat) then return end

		local x, y = chat:GetPos()
		local w, h = chat:GetSize()
		ix.option.Set("chatPosition", util.TableToJSON({x, y, w, h}))
	end

	--- Save the current tab layout to the client's options.
	function PLUGIN:SaveTabs()
		local chat = ix.gui.chat
		if !IsValid(chat) then return end

		local saved = {}
		for id, tab in pairs(chat.tabs:GetTabs()) do
			saved[id] = tab:GetFilter()
		end
		ix.option.Set("chatTabs", util.TableToJSON(saved))
	end
end