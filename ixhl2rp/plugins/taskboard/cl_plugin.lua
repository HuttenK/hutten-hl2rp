local PLUGIN = PLUGIN

PLUGIN.tasks   = PLUGIN.tasks or {}
PLUGIN.details = PLUGIN.details or {} -- [taskID] = текст деталей (для принятых лично нами)

-- ==== Шрифты ====
surface.CreateFont("ixTaskTitle", { font = "Tahoma",   size = 24, weight = 800, antialias = true })
surface.CreateFont("ixTaskHead",  { font = "Tahoma",   size = 20, weight = 700, antialias = true })
surface.CreateFont("ixTaskItem",  { font = "Tahoma",   size = 18, weight = 700, antialias = true })
surface.CreateFont("ixTaskBody",  { font = "Consolas", size = 16, weight = 500, antialias = true })
surface.CreateFont("ixTaskSmall", { font = "Consolas", size = 13, weight = 500, antialias = true })

-- ==== Палитра (тёплая «бумажная», в отличие от синего ГО-терминала) ====
PLUGIN.Colors = {
	bg    = Color(20, 18, 14, 255),
	panel = Color(30, 27, 21, 255),
	row   = Color(38, 34, 26, 220),
	rowH  = Color(58, 50, 34, 235),
	line  = Color(210, 170, 90),
	lineD = Color(120, 95, 50),
	text  = Color(228, 220, 200),
	dim   = Color(150, 138, 112),
	green = Color(120, 200, 120),
	red   = Color(210, 80, 60),
}

-- ==== Кэш заданий ====
netstream.Hook("taskboard.sync", function(tasks)
	PLUGIN.tasks = istable(tasks) and tasks or {}

	-- обновить открытые экраны терминалов «вживую»
	for _, ent in ipairs(ents.FindByClass("ix_taskboard")) do
		if (IsValid(ent.panel) and ent.panel.Refresh) then
			ent.panel:Refresh()
		end
	end

	-- обновить открытый попап публикации, если есть
	if (IsValid(ix.gui.taskboardPost) and ix.gui.taskboardPost.RebuildList) then
		ix.gui.taskboardPost:RebuildList()
	end
end)

-- Детали приходят только тому, кто взял задание (ключ существует => мы исполнитель).
netstream.Hook("taskboard.details", function(id, details)
	PLUGIN.details[id] = details or ""
end)

-- Сброс деталей (мы отказались/закрыто) — убираем ключ.
netstream.Hook("taskboard.cleardetails", function(id)
	PLUGIN.details[id] = nil
end)

function PLUGIN:GetTasks()
	return self.tasks or {}
end

function PLUGIN:GetTaskByID(id)
	for _, v in ipairs(self.tasks or {}) do
		if (v.id == id) then return v end
	end
end

-- ==== Перенос текста по ширине ====
function PLUGIN:WrapText(text, font, maxWidth)
	surface.SetFont(font)
	local lines = {}

	for _, paragraph in ipairs(string.Explode("\n", tostring(text or ""))) do
		if (paragraph == "") then
			lines[#lines + 1] = ""
		else
			local line = ""

			for _, word in ipairs(string.Explode(" ", paragraph)) do
				local test = (line == "") and word or (line .. " " .. word)

				if (surface.GetTextSize(test) > maxWidth and line != "") then
					lines[#lines + 1] = line
					line = word
				else
					line = test
				end
			end

			if (line != "") then lines[#lines + 1] = line end
		end
	end

	return lines
end
