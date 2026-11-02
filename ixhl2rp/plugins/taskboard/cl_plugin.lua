local PLUGIN = PLUGIN

PLUGIN.tasks   = PLUGIN.tasks or {}
PLUGIN.details = PLUGIN.details or {} -- [taskID] = текст деталей (для принятых лично нами)

-- ==== Шрифты ====
surface.CreateFont("ixTaskTitle", { font = "Georgia",   size = 24, weight = 800, extended = true, antialias = true })
surface.CreateFont("ixTaskHead",  { font = "Georgia",   size = 20, weight = 700, extended = true, antialias = true })
surface.CreateFont("ixTaskItem",  { font = "Georgia",   size = 18, weight = 700, extended = true, antialias = true })
surface.CreateFont("ixTaskBody",  { font = "Georgia", size = 16, weight = 500, extended = true, antialias = true })
surface.CreateFont("ixTaskSmall", { font = "Georgia", size = 13, weight = 500, extended = true, antialias = true })

-- ==== Палитра (кожа и потёртая латунь) ====
PLUGIN.Colors = {
	bg    = Color(20, 18, 14, 255),
	panel = Color(30, 27, 21, 255),
	row   = Color(38, 34, 26, 220),
	rowH  = Color(58, 50, 34, 235),
	line  = Color(182,151,91),
	lineD = Color(120, 95, 50),
	text  = Color(228, 220, 200),
	dim   = Color(150, 138, 112),
	green = Color(139,157,107),
	red   = Color(210, 80, 60),
}

-- ==== Кэш заданий ====
netstream.Hook("taskboard.sync", function(tasks)
	PLUGIN.tasks = istable(tasks) and tasks or {}
	local active = {}
	for _, task in ipairs(PLUGIN.tasks) do
		if task.status == "taken" then active[task.id] = true end
	end
	for id in pairs(PLUGIN.details) do
		if not active[id] then PLUGIN.details[id] = nil end
	end
	hook.Run("CivicTasksUpdated")

	-- обновить окна доски «вживую»
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
	hook.Run("CivicTasksUpdated")
end)

-- Сброс деталей (мы отказались/закрыто) — убираем ключ.
netstream.Hook("taskboard.cleardetails", function(id)
	PLUGIN.details[id] = nil
	hook.Run("CivicTasksUpdated")
end)

netstream.Hook("taskboard.resetdetails", function()
	PLUGIN.details = {}
	hook.Run("CivicTasksUpdated")
end)

function PLUGIN:CharacterLoaded(character)
	PLUGIN.details = {}
	hook.Run("CivicTasksUpdated")
end

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

netstream.Hook("taskboard.open",function(entity)
 if not IsValid(entity) or entity:GetClass()~="ix_taskboard" then return end
 if IsValid(ix.gui.noticeBoard) then ix.gui.noticeBoard:Remove() end
 local frame=vgui.Create("DFrame")
 ix.gui.noticeBoard=frame
 frame:SetTitle("Доска объявлений")
 frame:SetSize(math.min(632,ScrW()-24),math.min(404,ScrH()-24))
 frame:Center();frame:MakePopup()
 local board=frame:Add("ixTaskBoardScreen")
 board:Dock(FILL);board.entity=entity;entity.panel=board
 frame.Think=function(self)
  local p=LocalPlayer()
  if not IsValid(entity) or not IsValid(p) or not p:GetCharacter() or p:GetPos():DistToSqr(entity:GetPos())>180^2 then self:Remove() end
 end
end)
