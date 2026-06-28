local PLUGIN = PLUGIN

PLUGIN.news = PLUGIN.news or {}

-- ==== Шрифты (стиль ГО) ====
surface.CreateFont("ixNewsTitle",  { font = "Tahoma",   size = 26, weight = 800, antialias = true })
surface.CreateFont("ixNewsHead",   { font = "Tahoma",   size = 20, weight = 700, antialias = true })
surface.CreateFont("ixNewsItem",   { font = "Tahoma",   size = 19, weight = 700, antialias = true })
surface.CreateFont("ixNewsBody",   { font = "Consolas", size = 16, weight = 500, antialias = true })
surface.CreateFont("ixNewsSmall",  { font = "Consolas", size = 13, weight = 500, antialias = true })
surface.CreateFont("ixNewsTiny",   { font = "Consolas", size = 11, weight = 500, antialias = true })

-- «Комбайновские» шрифты (как у citizen terminal; если Blender Pro не установлен — подменится дефолтным)
surface.CreateFont("ixNewsCmbTitle", { font = "Blender Pro Heavy",  extended = true, size = 26, weight = 700, antialias = true })
surface.CreateFont("ixNewsCmbHead",  { font = "Blender Pro Bold",   extended = true, size = 20, weight = 600, antialias = true })
surface.CreateFont("ixNewsCmbItem",  { font = "Blender Pro Medium", extended = true, size = 19, weight = 500, antialias = true })
surface.CreateFont("ixNewsCmbBody",  { font = "Blender Pro Book",   extended = true, size = 17, weight = 500, antialias = true })
surface.CreateFont("ixNewsCmbSmall", { font = "Blender Pro Medium", extended = true, size = 14, weight = 500, antialias = true })
surface.CreateFont("ixNewsCmbTick",  { font = "Blender Pro Bold",   extended = true, size = 15, weight = 600, antialias = true })

-- ==== Палитра ГО ====
PLUGIN.Colors = {
	bg     = Color(8, 12, 15, 255),
	panel  = Color(14, 20, 24, 255),
	row    = Color(18, 26, 31, 255),
	rowH   = Color(26, 42, 50, 255),
	line   = Color(0, 170, 210),
	lineD  = Color(0, 90, 115),
	text   = Color(196, 214, 220),
	dim    = Color(110, 140, 150),
	red    = Color(210, 60, 50),
}

-- ==== Кэш новостей ====
netstream.Hook("gonews.sync", function(news)
	PLUGIN.news = istable(news) and news or {}

	-- обновить открытые окна
	if IsValid(ix.gui.gonewsArticle) and ix.gui.gonewsArticle.Refresh then
		ix.gui.gonewsArticle:Refresh()
	end
	if IsValid(ix.gui.gonewsEditor) and ix.gui.gonewsEditor.RebuildList then
		ix.gui.gonewsEditor:RebuildList()
	end

	-- обновить открытые экраны читалок «вживую»
	for _, ent in ipairs(ents.FindByClass("ix_gonews_terminal")) do
		if IsValid(ent.panel) and ent.panel.Refresh then
			ent.panel:Refresh()
		end
	end
end)

function PLUGIN:GetNews()
	return self.news or {}
end

function PLUGIN:GetNewsByID(id)
	for _, v in ipairs(self.news or {}) do
		if v.id == id then return v end
	end
end

-- ==== Открытие редактора по запросу сервера ====
net.Receive("gonews.openeditor", function()
	if IsValid(ix.gui.gonewsEditor) then
		ix.gui.gonewsEditor:Remove()
	end
	ix.gui.gonewsEditor = vgui.Create("ixGONewsEditor")
end)

-- ==== Хелпер переноса текста по ширине ====
function PLUGIN:WrapText(text, font, maxWidth)
	surface.SetFont(font)
	local lines = {}

	for _, paragraph in ipairs(string.Explode("\n", tostring(text or ""))) do
		if paragraph == "" then
			lines[#lines + 1] = ""
		else
			local line = ""
			for _, word in ipairs(string.Explode(" ", paragraph)) do
				local test = (line == "") and word or (line .. " " .. word)
				if surface.GetTextSize(test) > maxWidth and line != "" then
					lines[#lines + 1] = line
					line = word
				else
					line = test
				end
			end
			if line != "" then lines[#lines + 1] = line end
		end
	end

	return lines
end
