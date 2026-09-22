-- Shared visual language for the Civic Link workspace. No workshop materials
-- or web fonts are required; the Windows faces include Cyrillic glyphs.
ix.Civic = ix.Civic or {}
local C = ix.Civic
C.colors = {
	background = Color(12, 17, 20, 246), panel = Color(19, 26, 30, 248),
	raised = Color(27, 36, 40), line = Color(51, 65, 69),
	text = Color(232, 233, 222), muted = Color(153, 169, 169),
	accent = Color(221, 184, 115), cool = Color(119, 182, 186),
	good = Color(140, 187, 145), danger = Color(232, 122, 109)
}

function C.Scale(value)
	return math.floor(value * math.Clamp(math.min(ScrW() / 1600, ScrH() / 900), 0.7, 1.6) + 0.5)
end

function C.Fonts()
	for name, info in pairs({Title = {"Bahnschrift", 40, 600}, Heading = {"Bahnschrift", 23, 500},
		Body = {"Segoe UI", 17, 400}, Small = {"Segoe UI", 14, 400},
		Mono = {"Consolas", 14, 400}, Number = {"Bahnschrift", 32, 500}}) do
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
	["civic.arrival"] = "A CITY UNDER CONTROL. A LIFE OF YOUR OWN.",
	["civic.manifesto"] = "Arrive with a name. Build a life between the checkpoints. Trade, learn, endure — and decide what you are willing to become.",
	["civic.access"] = "RESIDENT ACCESS",
	["civic.overview"] = "Overview", ["civic.journal"] = "Field journal", ["civic.assignments"] = "Assignments",
	["civic.link"] = "CIVIC LINK", ["civic.subtitle"] = "PERSONAL OPERATIONS TERMINAL",
	["civic.welcome"] = "Your place in the city.", ["civic.condition"] = "CONDITION REPORT",
	["civic.health"] = "Vital signs", ["civic.stamina"] = "Stamina", ["civic.hunger"] = "Nutrition",
	["civic.thirst"] = "Hydration", ["civic.memory"] = "Learning capacity", ["civic.progress"] = "DEVELOPMENT",
	["civic.level"] = "LEVEL %s", ["civic.points"] = "%s points available", ["civic.allocate"] = "Develop attributes",
	["civic.city"] = "LOCAL INFRASTRUCTURE", ["civic.power"] = "Power available", ["civic.outage"] = "Local power interruption",
	["civic.powerUnknown"] = "Power telemetry unavailable", ["civic.powerHint"] = "Use a fusebox to restore local services. Electronics skill is required.",
	["civic.safeHint"] = "Terminal access and equipment remain subject to local conditions.",
	["civic.attention"] = "ATTENTION REQUIRED", ["civic.stable"] = "No immediate condition alerts",
	["civic.bleeding"] = "Bleeding detected. Seek medical assistance.", ["civic.lowFood"] = "Low nutrition is slowing your recovery.",
	["civic.lowWater"] = "Low hydration is slowing your recovery.", ["civic.lowMemory"] = "Learning capacity depleted. Rest to recover.",
	["civic.noTasks"] = "No active assignments. Visit a noticeboard to find work.",
	["civic.taskHint"] = "Accept and publish at a powered noticeboard or with a raised PDA. Payment is agreed in person.",
	["civic.open"] = "OPEN", ["civic.taken"] = "ASSIGNED", ["civic.completed"] = "COMPLETED",
	["civic.accept"] = "Accept assignment", ["civic.abandon"] = "Return assignment", ["civic.complete"] = "Confirm completion",
	["civic.closeTask"] = "Close listing", ["civic.confirm"] = "Confirm this assignment action?", ["civic.yes"] = "Confirm", ["civic.cancel"] = "Cancel",
	["civic.emptyJournal"] = "Your field record begins here. Progress and assignments will appear as you play.",
	["civic.event.level"] = "Development: level %s", ["civic.event.task"] = "Assignment: %s",
	["civic.event.complete"] = "Assignment completed: %s", ["civic.event.skills"] = "Attributes updated",
	["civic.event.craft"] = "Manufactured: %s",
	["civic.footer"] = "HUTTEN / HELIX + AUTONOMOUS", ["civic.return"] = "Return to city", ["civic.unknown"] = "Unavailable",
	["civic.search"] = "Search assignments…", ["civic.noResults"] = "No assignments match your search.",
	["civic.xp"] = "%s / %s XP", ["civic.maxLevel"] = "Maximum level reached"
})
ix.Locale:AddTable("ru", {
	["civic.arrival"] = "ГОРОД ПОД КОНТРОЛЕМ. ЖИЗНЬ В ВАШИХ РУКАХ.",
	["civic.manifesto"] = "Прибудьте с именем. Постройте жизнь между блокпостами. Торгуйте, учитесь, выживайте — и решайте, кем готовы стать.",
	["civic.access"] = "ДОСТУП ЖИТЕЛЯ",
	["civic.overview"] = "Обзор", ["civic.journal"] = "Журнал", ["civic.assignments"] = "Поручения",
	["civic.link"] = "CIVIC LINK", ["civic.subtitle"] = "ПЕРСОНАЛЬНЫЙ ТЕРМИНАЛ",
	["civic.welcome"] = "Ваше место в городе.", ["civic.condition"] = "СОСТОЯНИЕ",
	["civic.health"] = "Здоровье", ["civic.stamina"] = "Выносливость", ["civic.hunger"] = "Питание",
	["civic.thirst"] = "Вода", ["civic.memory"] = "Способность к обучению", ["civic.progress"] = "РАЗВИТИЕ",
	["civic.level"] = "УРОВЕНЬ %s", ["civic.points"] = "Доступно очков: %s", ["civic.allocate"] = "Развить атрибуты",
	["civic.city"] = "ИНФРАСТРУКТУРА", ["civic.power"] = "Питание доступно", ["civic.outage"] = "Локальное отключение питания",
	["civic.powerUnknown"] = "Нет данных о питании", ["civic.powerHint"] = "Восстановите питание через электрощиток. Требуется навык электроники.",
	["civic.safeHint"] = "Доступ к терминалам и оборудованию зависит от местных условий.",
	["civic.attention"] = "ТРЕБУЕТСЯ ВНИМАНИЕ", ["civic.stable"] = "Критических сигналов нет",
	["civic.bleeding"] = "Кровотечение. Обратитесь за медицинской помощью.", ["civic.lowFood"] = "Нехватка питания замедляет восстановление.",
	["civic.lowWater"] = "Нехватка воды замедляет восстановление.", ["civic.lowMemory"] = "Способность к обучению истощена. Отдохните.",
	["civic.noTasks"] = "Активных поручений нет. Посетите доску объявлений, чтобы найти работу.",
	["civic.taskHint"] = "Публикация и приём — у работающей доски или с поднятым КПК. Оплата по личной договорённости.",
	["civic.open"] = "ОТКРЫТО", ["civic.taken"] = "ПРИНЯТО", ["civic.completed"] = "ЗАВЕРШЕНО",
	["civic.accept"] = "Принять поручение", ["civic.abandon"] = "Вернуть поручение", ["civic.complete"] = "Подтвердить выполнение",
	["civic.closeTask"] = "Закрыть объявление", ["civic.confirm"] = "Подтвердить действие с поручением?", ["civic.yes"] = "Подтвердить", ["civic.cancel"] = "Отмена",
	["civic.emptyJournal"] = "Здесь начинается ваша история. Развитие и поручения появятся по мере игры.",
	["civic.event.level"] = "Развитие: уровень %s", ["civic.event.task"] = "Поручение: %s",
	["civic.event.complete"] = "Поручение выполнено: %s", ["civic.event.skills"] = "Атрибуты обновлены",
	["civic.event.craft"] = "Изготовлено: %s",
	["civic.footer"] = "HUTTEN / HELIX + AUTONOMOUS", ["civic.return"] = "Вернуться в город", ["civic.unknown"] = "Недоступно",
	["civic.search"] = "Поиск поручений…", ["civic.noResults"] = "Подходящих поручений нет.",
	["civic.xp"] = "%s / %s ОП", ["civic.maxLevel"] = "Достигнут максимальный уровень"
})
