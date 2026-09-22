local U, S = ix.Legends, ix.Legends.Scale
local T = U.T
local PANEL = {}
local chapters = {{"Origin", "Происхождение"}, {"Identity", "Личность"},
	{"Appearance", "Внешность"}, {"Attributes", "Атрибуты"}, {"Review", "Проверка"}}

local function Path(entry) return istable(entry) and entry[1] or entry end
local function DockButton(parent, title, action, primary)
	local p = U.Button(parent, title, action, primary)
	p:Dock(TOP); p:DockMargin(0, 0, S(8), S(10)); return p
end

function PANEL:Init()
	self.currentAlpha = 255
	if IsValid(ix.gui.loading) then ix.gui.loading:Remove() end
	if IsValid(ix.gui.characterMenu) then ix.gui.characterMenu:Remove() end
	ix.gui.characterMenu = self
	self:SetSize(ScrW(), ScrH()); self:MakePopup()
	self.mainPanel, self.newCharacterPanel, self.loadCharacterPanel = self, self, self
	self.bUsingCharacter = false
	self.scene = self:Add("legends.portrait")
	self.previewToggle = U.Button(self, T("Face / full body", "Лицо / полный рост"), function()
		self.scene:SetPortraitFocus(not self.scene.faceFocus)
	end)
	self.content = U.Scroll(self)
	self.back = U.Button(self, T("Back", "Назад"), function() self:Back() end)
	self.next = U.Button(self, "", function() self:Advance() end, true)
	self.next.Paint = function(this, w, h)
		local offset = U.ButtonFace(this, w, h, true)
		U.Text(">_", "Mono", S(10), h/2-S(7), U.accent)
		U.Text(self.nextText or "", "Body", S(52), h / 2 - S(10)+offset, U.ink)
		U.Text("[↵]", "Mono", w - S(34), h / 2 - S(7), U.accent)
	end
	self.controlsReady = true
 self.heading = T("Connecting to character service…", "Подключение к архиву персонажей…")
 self.scene:SetVisible(false); self.previewToggle:SetVisible(false)
 self.back:SetVisible(false); self.next:SetVisible(false)
 self:InitializeForPlayer()
end

-- The character-list net message can precede a usable LocalPlayer entity.
-- Build the shell immediately, then initialize player-dependent views once ready.
function PANEL:InitializeForPlayer()
 if self.playerReady or not self.controlsReady then return end
 local client = LocalPlayer()
 if not IsValid(client) or not isfunction(client.GetCharacter) or not isfunction(client.HasWhitelist) then return end
 self.bUsingCharacter = client:GetCharacter() ~= nil
 self.playerReady = true
 self:ResetDraft(); self:ShowHome(); self:PlayMusic()
 hook.Run("OnCharacterMenuCreated", self)
end

function PANEL:ResetDraft()
	self.draft = {name = "", description = "", gender = 1, model = 1, face = {1, 1},
		genetic = {11, 175, 25, 1}, languages = {}, specials = {}, primaryStat = {}}
	for key in pairs(ix.specials.list) do self.draft.specials[key] = 0 end
	for key, language in SortedPairs(ix.languages and ix.languages.stored or {}) do
		if not language.notSelectable then self.draft.languages = {language.uniqueID or key}; break end
	end
end

function PANEL:PerformLayout(w, h)
 if not self.controlsReady then return end
	local pad = math.max(S(40), w * 0.045)
	self.scene:SetPos(w * 0.48, S(86)); self.scene:SetSize(w * 0.5, h - S(160))
	self.previewToggle:SetPos(w-S(320), S(170)); self.previewToggle:SetSize(S(240), S(40))
	self.content:SetPos(pad, S(176)); self.content:SetSize(w * 0.48 - pad, h - S(290))
	self.back:SetPos(pad, h - S(80)); self.back:SetSize(S(170), S(48))
	self.next:SetPos(w - pad - S(290), h - S(80)); self.next:SetSize(S(290), S(48))
end

function PANEL:Paint(w, h)
	U.Backdrop(w, h)
	local pad = math.max(S(40), w * 0.045)
	U.Text("[ SCP ]  /  INTERNAL NETWORK", "Heading", pad, S(35))
	U.Text("SECURE TERMINAL  /  " .. T("CHARACTER ARCHIVE", "АРХИВ ПЕРСОНАЖЕЙ"), "Mono", w - pad, S(46), U.muted, TEXT_ALIGN_RIGHT)
	U.Rect(pad, S(86), w - pad * 2, 1, U.line)
	U.Text(self.heading or "", "Title", pad, S(110))
	if self.view == "create" then
		for i, chapter in ipairs(chapters) do
			local x = w * 0.51 + (i - 1) * w * 0.088
			U.Text(string.format("%02d", i), "Mono", x, S(112), i == self.step and U.accent or U.muted)
			U.Rect(x, S(140), w * 0.065, S(2), i <= self.step and U.accent or U.line)
		end
	end
	if self.view == "home" then
  local x,y,bw,bh = w*0.55,S(186),w*0.38,h-S(340)
  U.Plate(x,y,bw,bh,Color(9,6,10,225),U.line)
  U.Rect(x+S(20),y+S(22),S(5),S(5),U.accent)
  U.Text("SECURITY DIRECTIVE / 001", "Mono", x+S(36),y+S(17),U.accent)
  U.Rect(x+S(20),y+S(48),bw-S(40),1,U.line)
  U.Text(T("AUTHORIZED ACCESS", "СЛУЖЕБНЫЙ ДОСТУП"), "Heading",x+S(24),y+S(76),U.ink)
  local rows = {
   T("01 / SELECT PERSONNEL RECORD", "01 / ВЫБЕРИТЕ ЛИЧНОЕ ДЕЛО"),
   T("02 / VERIFY IDENTITY", "02 / ПОДТВЕРДИТЕ ЛИЧНОСТЬ"),
   T("03 / ENTER FACILITY", "03 / ВОЙДИТЕ НА ОБЪЕКТ")}
  for i,row in ipairs(rows) do
   U.Text(row,"Small",x+S(24),y+S(112+i*34),U.muted)
  end
  U.Rect(x+S(24),y+bh-S(80),bw-S(48),1,U.line)
  U.Text(T("ALL ACCESS IS SUBJECT TO REVIEW", "ДОСТУП ПОДЛЕЖИТ КОНТРОЛЮ"),"Mono",x+S(24),y+bh-S(57),U.accent)
  U.Text("SECURE / CONTAIN / PROTECT", "Mono",x+S(24),y+bh-S(32),U.muted)
 end
 U.Rect(pad, h - S(98), w - pad * 2, 1, U.line)
	U.Text(T("SECURE. CONTAIN. PROTECT.", "ОБЕЗОПАСИТЬ. УДЕРЖАТЬ. СОХРАНИТЬ."), "Mono", w * 0.5, h - S(25), U.muted, TEXT_ALIGN_CENTER)
end

function PANEL:PaintOver(w, h)
	if self.noticeText and RealTime() < self.noticeUntil then
		U.Rect(w * 0.51, h - S(155), w * 0.44, S(45), U.panel)
		U.Text(ix.Civic.Fit(self.noticeText, "Body", w * 0.42), "Small", w * 0.52, h - S(141), U.accent)
	end
end

function PANEL:ShowNotice(_, text)
	self.noticeText = tostring(text); self.noticeUntil = RealTime() + 10
end
function PANEL:HideNotice() self.noticeText = nil end
function PANEL:UpdateReturnButton(value) self.bUsingCharacter = value end
function PANEL:Undim() self:ShowRoster() end
function PANEL:IsClosing() return self.bClosing end
function PANEL:OnCharacterDeleted() self:ShowRoster() end
function PANEL:OnCharacterLoadFailed(message)
	self.pendingChoose = nil; self.next:SetDisabled(false); self:ShowNotice(3, message)
end
function PANEL:Close()
	if self.bClosing then return end
	self.bClosing = true; self:Remove()
end
function PANEL:OnRemove()
	if IsValid(self.channel) then self.channel:Stop() end
	if ix.gui.characterMenu == self then gui.EnableScreenClicker(false) end
end
function PANEL:PlayMusic()
	if self.musicStarted then return end
	self.musicStarted = true
	local path = ix.config.Get("music", "")
	if path == "" then return end
	local url = path:match("^https?://")
	local play = url and sound.PlayURL or sound.PlayFile
	play(url and path or "sound/" .. path, "noplay", function(channel)
		if not IsValid(channel) then return end
		if not IsValid(self) then channel:Stop(); return end
		self.channel = channel; channel:SetVolume(0.25); channel:Play()
	end)
end

function PANEL:PresentCharacter(character)
	if not character then return end
	self.selected = character
	self.scene:Present(character:GetModel(), character:GetData("skin", 0), character:GetData("bgcache", character:GetData("groups", {})))
end
function PANEL:BeginView(view, title, nextText)
	self.view = view; self.heading = title; self.nextText = nextText
	self.scene:SetVisible(view ~= "home")
	self.previewToggle:SetVisible(view == "create" and self.step == 3)
	if view ~= "create" or self.step ~= 3 then self.scene:SetPortraitFocus(false) end
	self.content:Clear(); self.next:SetDisabled(false); self.next:SetVisible(view ~= "home")
	self.back:SetVisible(view ~= "home")
	self.content:GetVBar():SetScroll(0)
end
function PANEL:ShowHome()
	self:BeginView("home", T("RESTRICTED ACCESS", "ДОСТУП ОГРАНИЧЕН"), T("Continue", "Продолжить"))
	U.Label(self.content, "FOUNDATION /", "Heading", U.muted)
	U.Label(self.content, T("ACCESS NODE", "УЗЕЛ ДОСТУПА"), "Display", U.ink)
	U.Label(self.content, T("Authorized personnel only. All activity is monitored.",
		"Только для уполномоченного персонала. Все действия протоколируются."), "Heading", U.muted)
	DockButton(self.content, T("Your characters", "Ваши персонажи"), function() self:ShowRoster() end, true)
	DockButton(self.content, T("Create a personnel file", "Создать личное дело"), function() self:BeginCreation() end)
	DockButton(self.content, T("Workshop content", "Контент Workshop"), function() gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3680347522") end)
	DockButton(self.content, T("Community", "Сообщество"), function() gui.OpenURL("https://discord.gg/M8FRCsKHSU") end)
	DockButton(self.content, self.bUsingCharacter and T("Return to facility", "Вернуться на объект") or T("Disconnect", "Отключиться"), function()
		if self.bUsingCharacter then self:Close() else RunConsoleCommand("disconnect") end
	end)
	local character = LocalPlayer():GetCharacter() or ix.char.loaded[(ix.characters or {})[1]]
	if character then self:PresentCharacter(character) end
	self.scene:SetVisible(false)
end
function PANEL:ShowRoster()
	self:BeginView("roster", T("PERSONNEL ARCHIVE", "АРХИВ ЛИЧНЫХ ДЕЛ"), T("Enter facility", "Войти на объект"))
	local found = false
	for _, id in ipairs(ix.characters or {}) do
		local character = ix.char.loaded[id]
		if character then
			if not found then self:PresentCharacter(character); found = true end
			local faction = ix.faction.indices[character:GetFaction()]
			local button = DockButton(self.content, character:GetName(), function() self:PresentCharacter(character) end)
			button:SetTall(S(110))
			button.Paint = function(this, w, h)
				local selected = self.selected == character
				U.Plate(0, 0, w, h, selected and Color(65, 15, 25, 240) or U.panel, selected and U.cyan or U.line)
				if selected then U.Rect(0, 0, S(3), h, U.accent) end
				U.Text(ix.Civic.Fit(character:GetName(), "Heading", w - S(40)), "Heading", S(20), S(20))
				U.Text((faction and L(faction.name) or "") .. "  /  " .. T("LEVEL ", "УРОВЕНЬ ") .. tostring(character:GetLevel()), "Mono", S(20), S(64), U.muted)
				U.Rect(0, h - 1, w, 1, U.line)
			end
		end
	end
	if not found then
		self.selected = nil; self.next:SetDisabled(true)
		U.Label(self.content, T("An unwritten story.", "Ещё не написанная история."), "Heading")
		U.Label(self.content, T("Create your first character to enter the facility.", "Создайте первого персонажа, чтобы войти на объект."), "Body", U.muted)
	end
	DockButton(self.content, "+  " .. T("New character", "Новый персонаж"), function() self:BeginCreation() end)
end

function PANEL:BeginCreation()
	local maximum = hook.Run("GetMaxPlayerCharacter", LocalPlayer()) or ix.config.Get("maxCharacters", 5)
	if #(ix.characters or {}) >= maximum then self:ShowNotice(3, L("maxCharacters")); return end
	self:ResetDraft(); self.step = 1; self:ShowStep()
end
function PANEL:SelectFaction(index)
	local faction = ix.faction.indices[index]
	if not faction or not LocalPlayer():HasWhitelist(index) then return end
	self.draft.faction = index; self.draft.gender = (faction.genders or {1, 2})[1]
	self.draft.genetic[3] = faction.ageSelector and 1 or 25
	self.draft.model = 1; self.draft.face = {1, 1}
	if faction.GenerateName then self.draft.name = faction:GenerateName(self.draft.gender) or "" end
	self:PresentDraft()
end
function PANEL:PresentDraft()
	local faction = ix.faction.indices[self.draft.faction]
	if not faction then return end
	local models = faction:GetModels(LocalPlayer(), self.draft.gender) or {}
	local entry = models[self.draft.model]
	local groups = {}
	if istable(entry) and isstring(entry[3]) then
		for i = 1, #entry[3] do groups[i - 1] = tonumber(entry[3]:sub(i, i)) or 0 end
	end
	self.scene:Present(Path(entry), istable(entry) and entry[2] or 0, groups)
end
function PANEL:ShowStep()
	self:BeginView("create", string.format("%02d / ", self.step) .. T(unpack(chapters[self.step])),
		self.step == 5 and T("Create character", "Создать персонажа") or T("Continue", "Продолжить"))
	self:PresentDraft()
	if self.step == 1 then self:Origin()
	elseif self.step == 2 then self:Identity()
	elseif self.step == 3 then self:Appearance()
	elseif self.step == 4 then self:Attributes()
	else self:Review() end
end
function PANEL:Origin()
	U.Label(self.content, T("Where does your story begin?", "Где начинается ваша история?"), "Heading")
	for index, faction in ipairs(ix.faction.indices) do
		local allowed = LocalPlayer():HasWhitelist(index)
		local button = DockButton(self.content, L(faction.name), function() self:SelectFaction(index); self:ShowStep() end, self.draft.faction == index)
		button:SetDisabled(not allowed)
		if not allowed then button:SetTooltip(T("Whitelist required", "Требуется доступ к фракции")) end
	end
	local faction = ix.faction.indices[self.draft.faction]
	if faction then U.Label(self.content, L(faction.description or ""), "Body", U.muted) end
end
function PANEL:Identity()
	U.Field(self.content, T("FULL NAME", "ПОЛНОЕ ИМЯ"), self.draft.name, function(value) self.draft.name = value end)
	U.Field(self.content, T("PHYSICAL DESCRIPTION", "ОПИСАНИЕ ВНЕШНОСТИ"), self.draft.description, function(value) self.draft.description = value end, true)
	U.Label(self.content, T("Describe what another person can see. Your history is yours to reveal.",
		"Опишите то, что видит другой человек. Свою историю вы расскажете сами."), "Small", U.muted)
	local entries = {}
	for key, language in SortedPairs(ix.languages and ix.languages.stored or {}) do
		if not language.notSelectable then entries[#entries + 1] = {value = language.uniqueID or key, label = L(language.name)} end
	end
	U.Choice(self.content, T("NATIVE LANGUAGE", "РОДНОЙ ЯЗЫК"), entries, self.draft.languages[1], function(value) self.draft.languages = {value} end)
end
function PANEL:Appearance()
	local faction = ix.faction.indices[self.draft.faction]
	local genders = {}
	for _, value in ipairs(faction.genders or {1, 2}) do genders[#genders + 1] = {value = value, label = value == 1 and T("Male", "Мужской") or T("Female", "Женский")} end
	U.Choice(self.content, T("BODY TYPE", "ТИП ТЕЛА"), genders, self.draft.gender, function(value)
		self.draft.gender = value; self.draft.model = 1; self:ShowStep()
	end)
	local models = faction:GetModels(LocalPlayer(), self.draft.gender) or {}
	local grid = self.content:Add("DIconLayout")
	grid:Dock(TOP); grid:DockMargin(0, 0, 0, S(24)); grid:SetSpaceX(S(6)); grid:SetSpaceY(S(6))
	local choices = ix.BuildCharacterModelChoices(models, ix.CharGen)
	local selectedChoice
	for ordinal, choice in ipairs(choices) do
		local index, entry = choice.index, choice.entry
		local selected = false
		for _, variant in ipairs(choice.variants) do
			if variant.index == self.draft.model then selected = true; selectedChoice = choice end
		end
		local icon = grid:Add("SpawnIcon"); icon:SetSize(S(72), S(84))
		icon:SetModel(Path(entry), istable(entry) and entry[2] or 0, istable(entry) and entry[3] or nil)
		icon:SetTooltip(T("Appearance ", "Облик ") .. string.format("%02d", ordinal))
		icon.DoClick = function() self.draft.model = index; self:ShowStep() end
		icon.PaintOver = function(_, w, h)
			if selected then surface.SetDrawColor(U.accent); surface.DrawOutlinedRect(0, 0, w, h, S(2)) end
		end
	end
	if selectedChoice and #selectedChoice.variants > 1 then
		local hairstyles = {}
		for ordinal, variant in ipairs(selectedChoice.variants) do
			hairstyles[#hairstyles + 1] = {value = variant.index, label = T("Hairstyle ", "Причёска ") .. ordinal}
		end
		U.Choice(self.content, T("HAIRSTYLE", "ПРИЧЁСКА"), hairstyles, self.draft.model, function(index)
			self.draft.model = index; self:PresentDraft()
		end)
	end
	local function numeric(label, slot, low, high)
		U.Label(self.content, label, "Mono", U.muted)
		local slider = self.content:Add("DNumSlider")
		slider:Dock(TOP); slider:DockMargin(0, 0, S(12), S(18)); slider:SetTall(S(38))
		slider:SetMin(low); slider:SetMax(high); slider:SetDecimals(0); slider:SetValue(self.draft.genetic[slot])
		slider.OnValueChanged = function(_, value) self.draft.genetic[slot] = math.Round(value) end
	end
	if faction.ageSelector then
		local ages = {}; for i, name in ipairs(faction.ageSelector) do ages[#ages + 1] = {value = i, label = L(name)} end
		U.Choice(self.content, T("AGE", "ВОЗРАСТ"), ages, self.draft.genetic[3], function(value) self.draft.genetic[3] = value end)
	else numeric(T("AGE", "ВОЗРАСТ"), 3, 18, 60) end
	numeric(T("HEIGHT / CM", "РОСТ / СМ"), 2, 155, 190)
	local shapes = {}; for i = 1, 20 do shapes[i] = {value = i, label = L("shape" .. math.ceil(i / 5) .. "_" .. ((i - 1) % 5 + 1))} end
	U.Choice(self.content, T("BUILD", "ТЕЛОСЛОЖЕНИЕ"), shapes, self.draft.genetic[1], function(value) self.draft.genetic[1] = value end)
	local eyes = {}; for i, eye in ipairs(faction.eyeColors or {{"eyes1"}, {"eyes2"}, {"eyes3"}, {"eyes4"}, {"eyes5"}, {"eyes6"}}) do eyes[i] = {value = i, label = L(eye[1])} end
	U.Choice(self.content, T("EYE COLOUR", "ЦВЕТ ГЛАЗ"), eyes, self.draft.genetic[4], function(value) self.draft.genetic[4] = value end)
end
function PANEL:PointsRemaining()
	local spent = 0; for _, value in pairs(self.draft.specials) do spent = spent + value end
	return (hook.Run("GetDefaultSpecialPoints", LocalPlayer(), self.draft) or 0) - spent
end
function PANEL:Attributes()
	U.Label(self.content, T("Choose two strengths. Invest in who you want to become.", "Выберите две сильные стороны. Вложите очки в своё будущее."), "Body", U.muted)
	local remaining = U.Label(self.content, "", "Heading", U.accent)
	remaining.Think = function(label) label:SetText(T("Points remaining: ", "Осталось очков: ") .. self:PointsRemaining()) end
	for key, definition in SortedPairsByMemberValue(ix.specials.list, "weight") do
		local row = self.content:Add("Panel"); row:Dock(TOP); row:SetTall(S(112)); row:DockMargin(0, 0, S(8), S(8))
		row.Paint = function(_, w, h)
			U.Plate(0, 0, w, h, U.panel, self.draft.primaryStat[key] and U.accent or U.line)
			local primary = self.draft.primaryStat[key]
			local value = 1 + math.floor(self.draft.specials[key] / (primary and 1 or 4))
			U.Text(L(definition.name), "Heading", S(16), S(14))
			U.Text(tostring(value), "Title", S(16), S(46), primary and U.accent or U.ink)
		end
		local star = U.Button(row, T("Primary", "Основной"), function()
			if self.draft.primaryStat[key] then self.draft.primaryStat[key] = nil
			elseif table.Count(self.draft.primaryStat) < 2 then self.draft.primaryStat[key] = true
			else self:ShowNotice(3, T("Choose at most two primary attributes.", "Можно выбрать не более двух основных атрибутов.")) end
		end)
		star:SetSize(S(154), S(40))
		star.Think = function(p) p:SetPos(row:GetWide() - S(168), S(8)); p:SetTooltip(self.draft.primaryStat[key] and T("Selected", "Выбрано") or T("Select primary", "Выбрать основным")) end
		local minus = U.Button(row, "−", function()
			local cost = self.draft.primaryStat[key] and 1 or 4
			self.draft.specials[key] = math.max(0, self.draft.specials[key] - cost)
		end)
		minus:SetSize(S(62), S(44)); minus.Think = function(p) p:SetPos(row:GetWide() - S(168), S(57)); p:SetDisabled(self.draft.specials[key] <= 0) end
		local plus = U.Button(row, "+", function()
			local cost = self.draft.primaryStat[key] and 1 or 4
			if self:PointsRemaining() >= cost then self.draft.specials[key] = self.draft.specials[key] + cost end
		end)
		plus:SetSize(S(62), S(44)); plus.Think = function(p) p:SetPos(row:GetWide() - S(82), S(57)); p:SetDisabled(self:PointsRemaining() < (self.draft.primaryStat[key] and 1 or 4)) end
	end
end
function PANEL:Review()
	local faction = ix.faction.indices[self.draft.faction]
	U.Label(self.content, self.draft.name, "Title")
	U.Label(self.content, L(faction.name), "Mono", U.accent)
	U.Label(self.content, self.draft.description, "Body", U.muted)
	for key, definition in SortedPairsByMemberValue(ix.specials.list, "weight") do
		local primary = self.draft.primaryStat[key]
		U.Label(self.content, L(definition.name) .. "  /  " .. (1 + math.floor(self.draft.specials[key] / (primary and 1 or 4))) .. (primary and "  ★" or ""), "Body")
	end
	U.Label(self.content, T("Your appearance and choices are ready. Enter facility and make them matter.", "Облик и навыки готовы. Войдите на объект и начните свою историю."), "Small", U.muted)
end
function PANEL:Validate(keys)
	for _, key in ipairs(keys) do
		local definition = ix.char.vars[key]
		if definition and definition.OnValidate then
			local ok, message, argument = definition:OnValidate(self.draft[key], self.draft, LocalPlayer())
			if ok == false then self:ShowNotice(3, L(message or "unknownError", argument)); return false end
		end
	end
	return true
end
function PANEL:Advance()
	if self.awaitingResponse or self.pendingChoose then return end
	if self.view == "home" then self:ShowRoster()
	elseif self.view == "roster" then
		if not self.selected then return end
		self.pendingChoose = RealTime() + 15; self.next:SetDisabled(true)
		net.Start("ixCharacterChoose"); net.WriteUInt(self.selected:GetID(), 32); net.SendToServer()
	elseif self.step == 5 then self:Submit()
	else
		local checks = {{"faction"}, {"name", "description", "languages"}, {"gender", "model", "genetic", "face"}, {"specials", "primaryStat"}}
		if not self:Validate(checks[self.step]) then return end
		self.step = self.step + 1; self:ShowStep()
	end
end
function PANEL:Back()
	if self.awaitingResponse or self.pendingChoose then return end
	if self.view == "create" and self.step > 1 then self.step = self.step - 1; self:ShowStep()
	elseif self.view == "home" and self.bUsingCharacter then self:Close()
	else self:ShowHome() end
end
function PANEL:Submit()
	local keys = {}; for key in SortedPairsByMemberValue(ix.char.vars, "index") do keys[#keys + 1] = key end
	if not self:Validate(keys) then return end
	self.awaitingResponse = RealTime() + 15; self.next:SetDisabled(true)
	net.Start("ixCharacterCreate"); net.WriteUInt(table.Count(self.draft), 8)
	for key, value in pairs(self.draft) do net.WriteString(key); net.WriteType(value) end
	net.SendToServer()
end
function PANEL:Think()
 self:InitializeForPlayer()
 if not self.playerReady then return end
	if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then self:SetSize(ScrW(), ScrH()); self:InvalidateLayout() end
	if (self.awaitingResponse and RealTime() > self.awaitingResponse) or (self.pendingChoose and RealTime() > self.pendingChoose) then
		self.awaitingResponse = nil; self.pendingChoose = nil; self.next:SetDisabled(false)
		self:ShowNotice(3, T("No response yet. Please try again.", "Ответ не получен. Попробуйте ещё раз."))
	end
end
vgui.Register("ixCharMenu", PANEL, "EditablePanel")

-- Install once, not inside a panel instance: responses cannot retain a removed
-- creation panel or send the user back through a legacy character menu.
net.Receive("ixCharacterAuthed", function()
	local id, count = net.ReadUInt(32), net.ReadUInt(6)
	local characters = {}; for _ = 1, count do characters[#characters + 1] = net.ReadUInt(32) end
	ix.characters = characters
	local menu = ix.gui.characterMenu
	if not IsValid(menu) then return end
	menu.awaitingResponse = nil; menu.next:SetDisabled(false)
	local client = LocalPlayer()
 if IsValid(client) and isfunction(client.GetCharacter) and client:GetCharacter() then menu:ShowRoster(); menu:ShowNotice(2, L("charCreated"))
	elseif id > 0 then
		menu.pendingChoose = RealTime() + 15; menu.next:SetDisabled(true)
		net.Start("ixCharacterChoose"); net.WriteUInt(id, 32); net.SendToServer()
	end
end)
net.Receive("ixCharacterAuthFailed", function()
	local message, args = net.ReadString(), net.ReadTable()
	local menu = ix.gui.characterMenu
	if not IsValid(menu) then return end
	menu.awaitingResponse = nil; menu.next:SetDisabled(false)
	menu:ShowNotice(3, L(message ~= "" and message or "unknownError", unpack(args or {})))
end)
