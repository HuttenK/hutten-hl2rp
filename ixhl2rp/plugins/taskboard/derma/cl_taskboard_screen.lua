-- Экран доски объявлений (3D2D на терминале): список заданий + просмотр.
-- Публикация — отдельный попап-окно (ixTaskBoardPost), т.к. ввод текста в 3D2D неудобен.

local SCREEN_W, SCREEN_H = 600, 360

local function P() return ix.plugin.list["taskboard"] end

local function MyCharID()
	local char = LocalPlayer():GetCharacter()
	return char and char:GetID()
end

local function C() return P().Colors end

----------------------------------------------------------------------
-- ЭКРАН (3D2D)
----------------------------------------------------------------------
local PANEL = {}

function PANEL:Init()
	self:SetSize(SCREEN_W, SCREEN_H)
	self.mode = "list"
	self.listScroll = 0
	self.detScroll = 0
	self:BuildList()
end

function PANEL:Refresh()
	if (self.mode == "list") then
		self:BuildList()
	else
		-- задание могло исчезнуть/смениться статусом
		local t = self.task and P():GetTaskByID(self.task.id)
		if (!t) then self:SetMode("list") else self.task = t self:BuildDetail() end
	end
end

function PANEL:SetMode(mode)
	self.mode = mode
	self:Clear()
	if (mode == "list") then self:BuildList() else self:BuildDetail() end
end

-- ===== СПИСОК =====
function PANEL:BuildList()
	self:Clear()

	local tasks = P():GetTasks()
	local rowH  = 46
	local listY = 70
	local listH = SCREEN_H - listY - 16
	local visible = math.floor(listH / rowH)

	local maxScroll = math.max(0, #tasks - visible)
	self.listScroll = math.Clamp(self.listScroll, 0, maxScroll)

	-- Кнопка «разместить»
	local post = self:Add("DButton")
	post:SetText(""); post:SetSize(150, 26); post:SetPos(16, 38)
	post.DoClick = function()
		surface.PlaySound("buttons/button14.wav")
		if (IsValid(ix.gui.taskboardPost)) then ix.gui.taskboardPost:Remove() end
		ix.gui.taskboardPost = vgui.Create("ixTaskBoardPost")
	end
	post.Paint = function(s, w, h)
		surface.SetDrawColor(s.Hovered and C().rowH or C().row); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(C().line); surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("+ РАЗМЕСТИТЬ", "ixTaskSmall", w * 0.5, h * 0.5, C().text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	for i = 0, visible - 1 do
		local entry = tasks[self.listScroll + i + 1]
		if (!entry) then break end

		local row = self:Add("DButton")
		row:SetText(""); row:SetSize(SCREEN_W - 60, rowH - 6); row:SetPos(16, listY + i * rowH)
		row.DoClick = function()
			surface.PlaySound("buttons/button14.wav")
			self.task = entry
			self.detScroll = 0
			self:SetMode("detail")
		end
		row.Paint = function(s, w, h)
			local hover = s.Hovered
			surface.SetDrawColor(hover and C().rowH or C().row); surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(entry.status == "open" and C().line or C().lineD); surface.DrawRect(0, 0, 3, h)
			draw.SimpleText(entry.title or "—", "ixTaskItem", 12, 7, C().text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText("от " .. (entry.posterName or "?"), "ixTaskSmall", 12, 27, C().dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

			local tag = (entry.status == "open") and "ОТКРЫТО" or ("ВЗЯЛ: " .. (entry.takenName or "?"))
			draw.SimpleText(tag, "ixTaskSmall", w - 10, h * 0.5, entry.status == "open" and C().green or C().dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	self:MakeScrollButtons(function() return self.listScroll > 0 end,
		function() return self.listScroll < maxScroll end,
		function() self.listScroll = math.max(0, self.listScroll - 1); self:BuildList() end,
		function() self.listScroll = math.min(maxScroll, self.listScroll + 1); self:BuildList() end)
end

-- ===== ПРОСМОТР =====
function PANEL:BuildDetail()
	self:Clear()

	local entry = self.task
	if (!entry) then self:SetMode("list") return end

	-- назад
	local back = self:Add("DButton")
	back:SetText(""); back:SetSize(110, 24); back:SetPos(16, 38)
	back.DoClick = function() surface.PlaySound("buttons/button14.wav") self:SetMode("list") end
	back.Paint = function(s, w, h)
		surface.SetDrawColor(s.Hovered and C().rowH or C().row); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(C().line); surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("◄ НАЗАД", "ixTaskSmall", w * 0.5, h * 0.5, C().text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local mine    = (entry.posterID == MyCharID())
	local haveDet = P().details[entry.id] != nil -- мы — исполнитель (детали пришли нам)

	-- ВЗЯТЬ (если открыто и не моё)
	if (entry.status == "open" and !mine) then
		local accept = self:Add("DButton")
		accept:SetText(""); accept:SetSize(150, 30); accept:SetPos(SCREEN_W - 166, 36)
		accept.DoClick = function()
			surface.PlaySound("buttons/button14.wav")
			netstream.Start("taskboard.accept", entry.id)
		end
		accept.Paint = function(s, w, h)
			surface.SetDrawColor(s.Hovered and C().line or C().lineD); surface.DrawRect(0, 0, w, h)
			draw.SimpleText("ВЗЯТЬ ЗАДАНИЕ", "ixTaskItem", w * 0.5, h * 0.5, s.Hovered and Color(20, 16, 8) or C().text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	-- ЗАКРЫТЬ (удалить) — только заказчик или админ.
	if (mine or LocalPlayer():IsAdmin()) then
		local close = self:Add("DButton")
		close:SetText(""); close:SetSize(150, 26); close:SetPos(SCREEN_W - 166, SCREEN_H - 36)
		close.DoClick = function()
			surface.PlaySound("buttons/button14.wav")
			netstream.Start("taskboard.close", entry.id)
		end
		close.Paint = function(s, w, h)
			surface.SetDrawColor(s.Hovered and C().red or C().lineD); surface.DrawRect(0, 0, w, h)
			draw.SimpleText("ЗАКРЫТЬ", "ixTaskSmall", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

	-- ОТКАЗАТЬСЯ — исполнитель возвращает объявление в открытые (не удаляет).
	elseif (haveDet) then
		local abandon = self:Add("DButton")
		abandon:SetText(""); abandon:SetSize(150, 26); abandon:SetPos(SCREEN_W - 166, SCREEN_H - 36)
		abandon.DoClick = function()
			surface.PlaySound("buttons/button14.wav")
			netstream.Start("taskboard.abandon", entry.id)
		end
		abandon.Paint = function(s, w, h)
			surface.SetDrawColor(s.Hovered and C().rowH or C().lineD); surface.DrawRect(0, 0, w, h)
			draw.SimpleText("ОТКАЗАТЬСЯ", "ixTaskSmall", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end

	self:MakeScrollButtons(function() return self.detScroll > 0 end,
		function() return self.detScroll < (self.detMax or 0) end,
		function() self.detScroll = math.max(0, self.detScroll - 2); self:BuildDetail() end,
		function() self.detScroll = math.min(self.detMax or 0, self.detScroll + 2); self:BuildDetail() end)
end

function PANEL:MakeScrollButtons(canUp, canDown, onUp, onDown)
	local bx = SCREEN_W - 34
	local up = self:Add("DButton")
	up:SetText(""); up:SetSize(26, 26); up:SetPos(bx, 70)
	up.DoClick = function() if (canUp()) then surface.PlaySound("common/talk.wav") onUp() end end
	up.Paint = function(s, w, h)
		local on = canUp()
		surface.SetDrawColor(s.Hovered and on and C().rowH or C().row); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(on and C().line or Color(70, 60, 45)); surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("▲", "ixTaskSmall", w * 0.5, h * 0.5, on and C().text or C().dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local down = self:Add("DButton")
	down:SetText(""); down:SetSize(26, 26); down:SetPos(bx, SCREEN_H - 36)
	down.DoClick = function() if (canDown()) then surface.PlaySound("common/talk.wav") onDown() end end
	down.Paint = function(s, w, h)
		local on = canDown()
		surface.SetDrawColor(s.Hovered and on and C().rowH or C().row); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(on and C().line or Color(70, 60, 45)); surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("▼", "ixTaskSmall", w * 0.5, h * 0.5, on and C().text or C().dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- ===== ОТРИСОВКА =====
local function DrawBackground(w, h)
	surface.SetDrawColor(C().bg); surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(0, 0, 0, 40)
	for y = 0, h, 3 do surface.DrawRect(0, y, w, 1) end
end

function PANEL:Paint(w, h)
	DrawBackground(w, h)

	local title = (self.mode == "detail" and self.task) and self.task.title or "ДОСКА ОБЪЯВЛЕНИЙ"
	surface.SetDrawColor(C().line)
	surface.DrawRect(16, 30, w - 32, 1)
	draw.SimpleText(":: " .. string.upper(tostring(title)) .. " ::", "ixTaskHead", 18, 7, C().line, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	if (self.mode == "detail" and self.task) then
		self:PaintDetail(w, h)
	elseif (#P():GetTasks() == 0) then
		draw.SimpleText("// НЕТ АКТИВНЫХ ОБЪЯВЛЕНИЙ", "ixTaskBody", w * 0.5, h * 0.5, C().dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	surface.SetDrawColor(C().line.r, C().line.g, C().line.b, 160)
	surface.DrawOutlinedRect(0, 0, w, h)
end

function PANEL:PaintDetail(w, h)
	local entry = self.task

	local meta = string.format("Заказчик: %s   ::   %s", entry.posterName or "?", os.date("%d.%m.%Y", entry.time or os.time()))
	draw.SimpleText(meta, "ixTaskSmall", 18, 72, C().green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	if (isstring(entry.reward) and entry.reward != "") then
		draw.SimpleText("Награда (по договорённости): " .. entry.reward, "ixTaskSmall", 18, 92, C().line, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	-- Текст: краткое описание видно всем; полные детали приходят только взявшему.
	local body = {}
	for _, l in ipairs(P():WrapText(entry.summary, "ixTaskBody", w - 60)) do body[#body + 1] = l end

	local fullDet = P().details[entry.id] -- ключ существует => мы исполнитель

	if (fullDet != nil) then
		body[#body + 1] = ""

		if (fullDet != "") then
			body[#body + 1] = "── ДЕТАЛИ ──"
			for _, l in ipairs(P():WrapText(fullDet, "ixTaskBody", w - 60)) do body[#body + 1] = l end
		else
			body[#body + 1] = "[ Вы взяли это задание. Детали и оплата — лично с заказчиком. ]"
		end
	elseif (entry.posterID == MyCharID()) then
		body[#body + 1] = ""
		body[#body + 1] = "[ Это ваше объявление. ]"
	else
		body[#body + 1] = ""
		body[#body + 1] = (entry.status == "open") and "[ Возьмите задание, чтобы увидеть детали. Оплата — лично с заказчиком. ]"
			or "[ Задание уже взято. ]"
	end

	local top    = 118
	local lineH  = 20
	local bottom = h - 16
	local vis    = math.max(1, math.floor((bottom - top) / lineH))
	self.detMax  = math.max(0, #body - vis)
	self.detScroll = math.Clamp(self.detScroll, 0, self.detMax)

	for i = 1, vis do
		local line = body[self.detScroll + i]
		if (!line) then break end
		draw.SimpleText(line, "ixTaskBody", 18, top + (i - 1) * lineH, C().text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end

vgui.Register("ixTaskBoardScreen", PANEL, "DPanel")

----------------------------------------------------------------------
-- ПОПАП ПУБЛИКАЦИИ
----------------------------------------------------------------------
local FRAME_W, FRAME_H = 560, 560

local function StyleEntry(entry, multiline)
	entry:SetFont("ixTaskBody")
	entry:SetTextColor(C().text)
	entry:SetCursorColor(C().line)
	if (multiline) then entry:SetMultiline(true) end
	entry.Paint = function(s, w, h)
		surface.SetDrawColor(C().row); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(C().line); surface.DrawRect(0, h - 2, w, 2)
		s:DrawTextEntryText(C().text, C().line, C().text)
	end
end

local POST = {}

function POST:Init()
	self.startTime = SysTime()
	self:SetSize(FRAME_W, FRAME_H)
	self:Center()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:MakePopup()
	self:SetDeleteOnClose(true)

	self.close = self:Add("DButton")
	self.close:SetText(""); self.close:SetSize(26, 26)
	self.close:SetPos(FRAME_W - 32, 6)
	self.close.DoClick = function() self:Remove() end
	self.close.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and C().red or C().lineD); surface.DrawRect(0, 0, w, h)
		draw.SimpleText("X", "ixTaskSmall", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local x  = 20
	local fw = FRAME_W - 40
	local y  = 56

	local function label(text, yy)
		local l = self:Add("DLabel")
		l:SetFont("ixTaskSmall"); l:SetTextColor(C().dim)
		l:SetPos(x, yy); l:SetText(text); l:SizeToContents()
	end

	label("НАЗВАНИЕ", y); y = y + 18
	self.title = self:Add("DTextEntry"); self.title:SetPos(x, y); self.title:SetSize(fw, 28)
	StyleEntry(self.title); y = y + 38

	label("КРАТКОЕ ОПИСАНИЕ (видно всем)", y); y = y + 18
	self.summary = self:Add("DTextEntry"); self.summary:SetPos(x, y); self.summary:SetSize(fw, 60)
	StyleEntry(self.summary, true); y = y + 70

	label("ДЕТАЛИ (откроются взявшему)", y); y = y + 18
	self.details = self:Add("DTextEntry"); self.details:SetPos(x, y); self.details:SetSize(fw, 120)
	StyleEntry(self.details, true); y = y + 130

	label("НАГРАДА — текст, обсуждается лично (не списывается автоматически)", y); y = y + 18
	self.reward = self:Add("DTextEntry"); self.reward:SetPos(x, y); self.reward:SetSize(fw, 28)
	StyleEntry(self.reward); y = y + 40

	self.post = self:Add("DButton"); self.post:SetPos(x, y); self.post:SetSize(fw, 34); self.post:SetText("")
	self.post.DoClick = function()
		local title = self.title:GetValue()
		if (!title or string.Trim(title) == "") then
			surface.PlaySound("buttons/button10.wav")
			return
		end

		netstream.Start("taskboard.post", {
			title   = title,
			summary = self.summary:GetValue(),
			details = self.details:GetValue(),
			reward  = self.reward:GetValue(),
		})

		surface.PlaySound("buttons/button14.wav")
		self:Remove()
	end
	self.post.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and C().line or C().lineD); surface.DrawRect(0, 0, w, h)
		draw.SimpleText("РАЗМЕСТИТЬ ОБЪЯВЛЕНИЕ", "ixTaskItem", w * 0.5, h * 0.5,
			s:IsHovered() and Color(20, 16, 8) or C().text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function POST:Paint(w, h)
	Derma_DrawBackgroundBlur(self, self.startTime)
	surface.SetDrawColor(C().bg); surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(0, 0, 0, 24)
	for yy = 0, h, 3 do surface.DrawRect(0, yy, w, 1) end
	surface.SetDrawColor(C().lineD); surface.DrawOutlinedRect(0, 0, w, h)
	surface.SetDrawColor(C().panel); surface.DrawRect(2, 2, w - 4, 44)
	surface.SetDrawColor(C().line); surface.DrawRect(2, 46, w - 4, 2)
	draw.SimpleText("НОВОЕ ОБЪЯВЛЕНИЕ", "ixTaskHead", 14, 13, C().text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

vgui.Register("ixTaskBoardPost", POST, "DFrame")
