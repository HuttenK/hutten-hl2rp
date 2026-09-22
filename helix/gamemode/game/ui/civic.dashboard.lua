local C, S = ix.Civic, ix.Civic.Scale
local colors = C.colors
local PANEL = {}

local function Value(object, method, fallback)
	if object and isfunction(object[method]) then return object[method](object) end
	return fallback
end

function C.Snapshot()
	local client = LocalPlayer()
	local character = IsValid(client) and client:GetCharacter()
	if not character then return end
	local health = Value(character, "Health")
	local faction = ix.faction.indices[character:GetFaction()]
	local noFood = faction and faction.dontNeedFood
	local snapshot = {
		name = character:GetName(), faction = faction and L(faction.name) or "",
		money = ix.currency.Get(character:GetMoney()), level = Value(character, "GetLevel", 1),
		xp = Value(character, "GetLevelXP", 0), points = Value(character, "GetSkillPoints", 0),
		vitals = {
			{"health", health and health.GetPercent and health:GetPercent() or client:Health() / math.max(client:GetMaxHealth(), 1)},
			{"stamina", client:GetLocalVar("stm", 0) / math.max(Value(character, "GetMaxStamina", 100), 1)},
			{"hunger", not noFood and Value(character, "GetHunger", 100) / 100 or nil},
			{"thirst", not noFood and Value(character, "GetThirst", 100) / 100 or nil},
			{"memory", Value(character, "GetSkillMemory", 0) / math.max(Value(character, "GetMaxSkillMemory", 750), 1)}
		},
		alerts = {}, journal = character:GetData("civicJournal", {})
	}
	local blackout = ix.plugin.Get("blackout")
	snapshot.powerKnown = blackout and istable(blackout.zones) or false
	snapshot.blackout = snapshot.powerKnown and blackout:IsPosBlackedOut(client:GetPos()) or false
	local levels = ix.plugin.Get("!!levelsystem")
	snapshot.requiredXP = levels and levels:GetRequiredLevelXP(snapshot.level) or 0
	if client:GetNetVar("isBleeding", false) then snapshot.alerts[#snapshot.alerts + 1] = "civic.bleeding" end
	if not noFood and Value(character, "GetHunger", 100) < 25 then snapshot.alerts[#snapshot.alerts + 1] = "civic.lowFood" end
	if not noFood and Value(character, "GetThirst", 100) < 25 then snapshot.alerts[#snapshot.alerts + 1] = "civic.lowWater" end
	if Value(character, "GetSkillMemory", 100) < 50 then snapshot.alerts[#snapshot.alerts + 1] = "civic.lowMemory" end
	return snapshot
end

local function Label(parent, text, font, color)
	local label = parent:Add("DLabel")
	label:Dock(TOP)
	label:SetFont("civic." .. (font or "Body"))
	label:SetTextColor(color or colors.text)
	label:SetText(text)
	label:SetWrap(true)
	label:SetAutoStretchVertical(true)
	label:DockMargin(0, 0, 0, S(8))
	return label
end

function PANEL:Init()
	self.scroll = self:Add("DScrollPanel")
	self.scroll:Dock(FILL)
	local bar = self.scroll:GetVBar()
	bar:SetWide(S(5))
	bar:SetHideButtons(true)
	bar.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h) C.Rect(0, 0, w, h, colors.line) end
	self.snapshot = C.Snapshot()
	self.nextRefresh = 0
end

function PANEL:Card(height, accent, parent)
	local panel = (parent or self.scroll):Add("DPanel")
	panel:Dock(TOP)
	panel:DockMargin(0, 0, S(10), S(14))
	panel:SetTall(S(height))
	panel:DockPadding(S(22), S(20), S(22), S(18))
	panel.Paint = function(_, w, h) C.Card(w, h, accent) end
	return panel
end

function PANEL:Setup(page, workspace)
	self.page, self.workspace = page, workspace
	if page == "assignments" then self:Assignments()
	elseif page == "journal" then self:Journal()
	else self:Overview() end
end

function PANEL:Overview()
	local hero = self:Card(170, colors.accent)
	hero.Paint = function(_, w, h)
		C.Card(w, h, colors.accent)
		-- Geometric city relief, drawn locally instead of fetching imagery.
		for i = 0, 24 do
			local height = S(20 + (i * 37) % 90)
			C.Rect(w * 0.60 + i * S(22), h - height, S(14), height, colors.raised)
		end
		local x = w * 0.85
		surface.SetDrawColor(colors.line)
		draw.NoTexture()
		surface.DrawPoly({{x=x-S(22),y=h},{x=x-S(8),y=S(30)},{x=x+S(8),y=S(12)},{x=x+S(28),y=h}})
		local data = self.snapshot
		if not data then return end
		C.Text(L("civic.welcome"), "Mono", S(24), S(22), colors.accent)
		C.Text(C.Fit(data.name, "Title", w - S(48)), "Title", S(24), S(52))
		C.Text(C.Fit(data.faction, "Body", w - S(48)), "Body", S(24), S(108), colors.muted)
		C.Text(C.Fit(data.money, "Mono", w - S(48)), "Mono", S(24), S(138), colors.accent)
	end
	self.overviewGrid = self.scroll:Add("Panel")
	self.overviewGrid:Dock(TOP)
	self.overviewGrid:DockMargin(0, 0, S(10), 0)
	local condition = self:Card(250, nil, self.overviewGrid)
	condition.Paint = function(_, w, h)
		C.Card(w, h)
		C.Text(L("civic.condition"), "Mono", S(22), S(18), colors.muted)
		if not self.snapshot then return end
		local y = S(58)
		for _, vital in ipairs(self.snapshot.vitals) do
			if vital[2] ~= nil then
				local fraction = math.Clamp(vital[2], 0, 1)
				local color = fraction < 0.25 and colors.danger or colors.cool
				C.Text(L("civic." .. vital[1]), "Body", S(22), y - S(4))
				local left, width = w * 0.42, w * 0.42
				C.Rect(left, y + S(3), width, S(5), colors.raised)
				C.Rect(left, y + S(3), width * fraction, S(5), color)
				C.Text(math.Round(fraction * 100) .. "%", "Mono", w - S(22), y - S(3), color, TEXT_ALIGN_RIGHT)
				y = y + S(36)
			end
		end
	end
	local development = self:Card(190, colors.cool, self.overviewGrid)
	development.Paint = function(_, w, h)
		C.Card(w, h, colors.cool)
		local data = self.snapshot
		if not data then return end
		C.Text(L("civic.progress"), "Mono", S(22), S(18), colors.muted)
		C.Text(L("civic.level", data.level), "Heading", S(22), S(44))
		C.Text(L("civic.points", data.points), "Body", S(22), S(74), colors.accent)
		local width = w - S(44)
		local fraction = data.requiredXP > 0 and math.Clamp(data.xp / data.requiredXP, 0, 1) or 1
		C.Rect(S(22), h - S(21), width, S(3), colors.raised)
		C.Rect(S(22), h - S(21), width * fraction, S(3), colors.cool)
		C.Text(data.requiredXP > 0 and L("civic.xp", math.floor(data.xp), data.requiredXP) or L("civic.maxLevel"), "Mono", S(22), h - S(43), colors.muted)
	end
	local develop = C.Button(development, L("civic.allocate"), function()
		local character = LocalPlayer():GetCharacter()
		if character and Value(character, "GetSkillPoints", 0) ~= 0 and vgui.GetControlTable("autonomous.levelup") then
			self.workspace:Close()
			vgui.Create("autonomous.levelup")
		end
	end)
	develop:SetWide(S(210))
	develop.Think = function(button)
		button:SetPos(S(22), S(100))
		button:SetDisabled(not self.snapshot or self.snapshot.points == 0 or not vgui.GetControlTable("autonomous.levelup"))
	end
	self.alertCard = self:Card(100, colors.danger, self.overviewGrid)
	self.alertTitle = Label(self.alertCard, L("civic.attention"), "Mono", colors.danger)
	self.alertText = Label(self.alertCard, "", "Body")
	self.powerCard = self:Card(175, nil, self.overviewGrid)
	Label(self.powerCard, L("civic.city"), "Mono", colors.muted)
	self.powerTitle = Label(self.powerCard, "", "Heading")
	self.powerText = Label(self.powerCard, "", "Body", colors.muted)
	local cards = {condition, development, self.alertCard, self.powerCard}
	for _, card in ipairs(cards) do card:Dock(NODOCK) end
	self.overviewGrid.PerformLayout = function(grid, width)
		local gap = S(14)
		if width >= S(820) then
			local left = math.floor((width - gap) * 0.57)
			condition:SetPos(0, 0)
			condition:SetWide(left)
			self.alertCard:SetPos(0, condition:GetTall() + gap)
			self.alertCard:SetWide(left)
			development:SetPos(left + gap, 0)
			development:SetWide(width - left - gap)
			self.powerCard:SetPos(left + gap, development:GetTall() + gap)
			self.powerCard:SetWide(width - left - gap)
			local height = math.max(condition:GetTall() + self.alertCard:GetTall(), development:GetTall() + self.powerCard:GetTall()) + gap
			if grid:GetTall() ~= height then grid:SetTall(height) end
		else
			local y = 0
			for _, card in ipairs(cards) do
				card:SetPos(0, y)
				card:SetWide(width)
				y = y + card:GetTall() + gap
			end
			if grid:GetTall() ~= y then grid:SetTall(y) end
		end
	end
	self:RefreshOverview()
end

function PANEL:RefreshOverview()
	local data = self.snapshot
	if not data or not IsValid(self.alertText) then return end
	local alerts = {}
	for _, key in ipairs(data.alerts) do alerts[#alerts + 1] = L(key) end
	self.alertTitle:SetText(L(#alerts > 0 and "civic.attention" or "civic.stable"))
	self.alertTitle:SetTextColor(#alerts > 0 and colors.danger or colors.good)
	self.alertText:SetText(table.concat(alerts, "\n"))
	self.alertCard:SetTall(S(60 + math.max(#alerts, 1) * 26))
	self.overviewGrid:InvalidateLayout()
	self.powerTitle:SetText(L(not data.powerKnown and "civic.powerUnknown" or data.blackout and "civic.outage" or "civic.power"))
	self.powerTitle:SetTextColor(data.blackout and colors.danger or colors.cool)
	self.powerText:SetText(L(data.blackout and "civic.powerHint" or "civic.safeHint"))
end

function PANEL:Assignments()
	local header = self:Card(115, colors.accent)
	Label(header, L("civic.assignments"), "Heading")
	Label(header, L("civic.taskHint"), "Body", colors.muted)
	self.search = self.scroll:Add("DTextEntry")
	self.search:Dock(TOP)
	self.search:DockMargin(0, 0, S(10), S(14))
	self.search:SetTall(S(40))
	self.search:SetFont("civic.Body")
	self.search:SetPlaceholderText(L("civic.search"))
	self.search:SetUpdateOnType(true)
	self.search.OnGetFocus = function() self.workspace:SetKeyboardInputEnabled(true) end
	self.search.OnLoseFocus = function() if IsValid(self.workspace) then self.workspace:SetKeyboardInputEnabled(false) end end
	self.search.OnValueChange = function() self:RebuildTasks() end
	self.taskList = self.scroll:Add("DPanel")
	self.taskList:Dock(TOP)
	self.taskList:DockMargin(0, 0, S(10), 0)
	self.taskList.Paint = function() end
	self:RebuildTasks()
	hook.Add("CivicTasksUpdated", self, function(panel) panel:RebuildTasks() end)
end

function PANEL:TaskAction(action, id)
	Derma_Query(L("civic.confirm"), L("civic.assignments"), L("civic.yes"), function()
		if not IsValid(self) then return end
		netstream.Start("taskboard." .. action, id)
	end, L("civic.cancel"))
end

function PANEL:RebuildTasks()
	if not IsValid(self.taskList) then return end
	self.taskList:Clear()
	local board = ix.plugin.Get("taskboard")
	local character = LocalPlayer():GetCharacter()
	if not character then return end
	local query = (self.search:GetValue() or ""):utf8lower()
	local count = 0
	for _, task in ipairs(board and board.tasks or {}) do
		if query == "" or (task.title .. " " .. task.summary):utf8lower():find(query, 1, true) then
			count = count + 1
			local row = self.taskList:Add("DPanel")
			row:Dock(TOP)
			row:DockMargin(0, 0, 0, S(10))
			row:DockPadding(S(20), S(16), S(20), S(16))
			row.Paint = function(_, w, h) C.Card(w, h, task.status == "completed" and colors.good or colors.accent) end
			local statusKey = ({open = "civic.open", taken = "civic.taken", completed = "civic.completed"})[task.status] or "civic.unknown"
			Label(row, L(statusKey) .. " / " .. (task.posterName or ""), "Mono", colors.accent)
			Label(row, task.title or "", "Heading")
			Label(row, task.summary or "", "Body", colors.muted)
			if task.reward and task.reward ~= "" then Label(row, task.reward, "Body", colors.good) end
			if board.details[task.id] then Label(row, board.details[task.id], "Body") end
			local actions = row:Add("Panel")
			actions:Dock(TOP)
			actions:SetTall(S(38))
			local function Action(action, phrase)
				local button = C.Button(actions, L(phrase), function() self:TaskAction(action, task.id) end)
				button:Dock(LEFT)
				button:SetWide(S(210))
				button:DockMargin(0, 0, S(8), 0)
			end
			if task.posterID == character:GetID() then
				if task.status == "taken" then Action("complete", "civic.complete") end
				Action("close", "civic.closeTask")
			elseif board.details[task.id] and task.status == "taken" then
				Action("abandon", "civic.abandon")
			elseif task.status == "open" then
				Action("accept", "civic.accept")
			end
			row.PerformLayout = function(this)
				local height = S(32)
				for _, child in ipairs(this:GetChildren()) do
					local _, top, _, bottom = child:GetDockMargin()
					height = height + child:GetTall() + top + bottom
				end
				if this:GetTall() ~= height then this:SetTall(height) end
			end
		end
	end
	if count == 0 then
		local empty = Label(self.taskList, L(query ~= "" and "civic.noResults" or "civic.noTasks"), "Body", colors.muted)
		empty:SetTall(S(70))
	end
	self.taskList.PerformLayout = function(this)
		local height = 0
		for _, child in ipairs(this:GetChildren()) do height = height + child:GetTall() + S(10) end
		if this:GetTall() ~= height then this:SetTall(height) end
	end
end

function PANEL:Journal()
	local title = self:Card(72, colors.cool)
	Label(title, L("civic.journal"), "Heading")
	local journal = self.snapshot and self.snapshot.journal or {}
	if #journal == 0 then
		Label(self:Card(100), L("civic.emptyJournal"), "Body", colors.muted)
	end
	for _, entry in ipairs(journal) do
		local row = self:Card(90)
		Label(row, os.date("%d.%m / %H:%M", entry.time), "Mono", colors.muted)
		Label(row, L(entry.key, entry.value or ""), "Body")
	end
end

function PANEL:Think()
	if RealTime() < self.nextRefresh then return end
	self.nextRefresh = RealTime() + 0.5
	self.snapshot = C.Snapshot()
	if self.page == "overview" then self:RefreshOverview() end
end

vgui.Register("civic.dashboard", PANEL, "EditablePanel")
