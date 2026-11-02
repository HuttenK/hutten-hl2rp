-- Shared visual language for the Civic Link workspace. No workshop materials
-- or web fonts are required; the Windows faces include Cyrillic glyphs.
ix.Civic = ix.Civic or {}
local C = ix.Civic
C.colors = {
	background = Color(12, 13, 11, 246), panel = Color(22, 22, 18, 248),
	raised = Color(37, 34, 26), line = Color(94, 80, 54),
	text = Color(232, 233, 222), muted = Color(161, 151, 128),
	accent = Color(221, 184, 115), cool = Color(182, 151, 91),
	good = Color(140, 187, 145), danger = Color(232, 122, 109)
}

function C.Scale(value)
	return math.floor(value * math.Clamp(math.min(ScrW() / 1600, ScrH() / 900), 0.7, 1.6) + 0.5)
end

function C.Fonts()
	for name, info in pairs({Title = {"Georgia", 40, 600}, Heading = {"Georgia", 23, 500},
		Body = {"Georgia", 17, 400}, Small = {"Georgia", 14, 400},
		Mono = {"Georgia", 14, 400}, Number = {"Georgia", 32, 500}}) do
		surface.CreateFont("civic." .. name, {font = info[1], size = C.Scale(info[2]), weight = info[3], extended = true, antialias = true})
	end
end
C.Fonts()
hook.Add("OnScreenSizeChanged", "ixCivicFonts", C.Fonts)

function C.Rect(x, y, w, h, color)
	surface.SetDrawColor(color)
	surface.DrawRect(x, y, w, h)
end

function C.Text(text, font, x, y, color, align)
	return draw.SimpleText(tostring(text or ""), "civic." .. (font or "Body"), x, y, color or C.colors.text, align or TEXT_ALIGN_LEFT)
end

-- Width-aware truncation never cuts a UTF-8 byte sequence in half.
function C.Fit(text, font, width)
	text = tostring(text or "")
	surface.SetFont("civic." .. font)
	if surface.GetTextSize(text) <= width then return text end
	local count = text:utf8len()
	while count > 0 do
		local result = text:utf8sub(1, count) .. "…"
		if surface.GetTextSize(result) <= width then return result end
		count = count - 1
	end
	return ""
end

function C.Card(w, h, accent)
	C.Rect(0, 0, w, h, C.colors.panel)
	surface.SetDrawColor(C.colors.line)
	surface.DrawOutlinedRect(0, 0, w, h)
	if accent then C.Rect(0, 0, C.Scale(3), h, accent) end
end

function C.Button(parent, text, click)
	local button = parent:Add("DButton")
	button:SetText("")
	button:SetTall(C.Scale(38))
	button:SetTooltip(text)
	button.Paint = function(self, w, h)
		C.Rect(0, 0, w, h, self:IsHovered() and C.colors.raised or C.colors.panel)
		surface.SetDrawColor(self:IsHovered() and C.colors.accent or C.colors.line)
		surface.DrawOutlinedRect(0, 0, w, h)
		C.Text(C.Fit(text, "Body", w - C.Scale(20)), "Body", C.Scale(10), C.Scale(8), self:GetDisabled() and C.colors.muted or C.colors.text)
	end
	button.DoClick = function(self)
		if self:GetDisabled() then return end
		surface.PlaySound("buttons/lightswitch2.wav")
		click(self)
	end
	return button
end

ix.Locale:AddTable("en", {
	["civic.overview"] = "Overview", ["civic.journal"] = "Field journal", ["civic.assignments"] = "Assignments",
	["civic.condition"] = "CONDITION REPORT",
	["civic.health"] = "Vital signs", ["civic.stamina"] = "Stamina", ["civic.hunger"] = "Nutrition",
	["civic.thirst"] = "Hydration", ["civic.attention"] = "ATTENTION REQUIRED", ["civic.stable"] = "No immediate condition alerts",
	["civic.bleeding"] = "Bleeding detected. Seek medical assistance.", ["civic.lowFood"] = "Low nutrition is slowing your recovery.",
	["civic.lowWater"] = "Low hydration is slowing your recovery.", ["civic.noTasks"] = "No active assignments. Visit a noticeboard to find work.",
	["civic.taskHint"] = "Accept and publish at the notice board. Payment is agreed in person.",
	["civic.open"] = "OPEN", ["civic.taken"] = "ASSIGNED", ["civic.completed"] = "COMPLETED",
	["civic.accept"] = "Accept assignment", ["civic.abandon"] = "Return assignment", ["civic.complete"] = "Confirm completion",
	["civic.closeTask"] = "Close listing", ["civic.confirm"] = "Confirm this assignment action?", ["civic.yes"] = "Confirm", ["civic.cancel"] = "Cancel",
	["civic.emptyJournal"] = "Your field record begins here. Progress and assignments will appear as you play.",
	["civic.event.task"] = "Assignment: %s",
	["civic.event.complete"] = "Assignment completed: %s", ["civic.event.craft"] = "Manufactured: %s",
	["civic.footer"] = "MEDIEVAL", ["civic.return"] = "Return to the world", ["civic.unknown"] = "Unavailable",
	["civic.search"] = "Search assignments…", ["civic.noResults"] = "No assignments match your search.",
	})
ix.Locale:AddTable("ru", {
	["civic.overview"] = "Обзор", ["civic.journal"] = "Журнал", ["civic.assignments"] = "Поручения",
	["civic.condition"] = "СОСТОЯНИЕ",
	["civic.health"] = "Здоровье", ["civic.stamina"] = "Выносливость", ["civic.hunger"] = "Питание",
	["civic.thirst"] = "Вода", ["civic.attention"] = "ТРЕБУЕТСЯ ВНИМАНИЕ", ["civic.stable"] = "Критических сигналов нет",
	["civic.bleeding"] = "Кровотечение. Обратитесь за медицинской помощью.", ["civic.lowFood"] = "Нехватка питания замедляет восстановление.",
	["civic.lowWater"] = "Нехватка воды замедляет восстановление.", ["civic.noTasks"] = "Активных поручений нет. Посетите доску объявлений, чтобы найти работу.",
	["civic.taskHint"] = "Публикация и приём — у доски объявлений. Оплата по личной договорённости.",
	["civic.open"] = "ОТКРЫТО", ["civic.taken"] = "ПРИНЯТО", ["civic.completed"] = "ЗАВЕРШЕНО",
	["civic.accept"] = "Принять поручение", ["civic.abandon"] = "Вернуть поручение", ["civic.complete"] = "Подтвердить выполнение",
	["civic.closeTask"] = "Закрыть объявление", ["civic.confirm"] = "Подтвердить действие с поручением?", ["civic.yes"] = "Подтвердить", ["civic.cancel"] = "Отмена",
	["civic.emptyJournal"] = "Здесь начинается ваша история. Записи о поручениях и ремесле появятся по мере игры.",
	["civic.event.task"] = "Поручение: %s",
	["civic.event.complete"] = "Поручение выполнено: %s", ["civic.event.craft"] = "Изготовлено: %s",
	["civic.footer"] = "MEDIEVAL", ["civic.return"] = "Вернуться в мир", ["civic.unknown"] = "Недоступно",
	["civic.search"] = "Поиск поручений…", ["civic.noResults"] = "Подходящих поручений нет.",
	})
