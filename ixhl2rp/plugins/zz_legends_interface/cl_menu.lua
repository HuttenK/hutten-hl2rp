local U, S = ix.InterfaceOS or ix.Legends, ix.Legends.Scale
local T = U.T
local PANEL = {}
local chapters = {{"Origin", "Происхождение"}, {"Identity", "Личность"},
	{"Appearance", "Внешность"}, {"Review", "Проверка"}}

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
		U.Icon("next", S(16), h/2-S(5), S(10), U.accent)
		U.Text(self.nextText or "", "Body", S(52), h / 2 - S(10)+offset, U.ink)
		U.Text("[↵]", "Mono", w - S(34), h / 2 - S(7), U.accent)
	end
	self.controlsReady = true
 self.heading = T("Loading characters…", "Загрузка персонажей…")
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
		genetic = {11, 175, 25, 1}, languages = {}}
	for key, language in SortedPairs(ix.languages and ix.languages.stored or {}) do
		if not language.notSelectable then self.draft.languages = {language.uniqueID or key}; break end
	end
end

function PANEL:PerformLayout(w,h)
 if not self.controlsReady then return end
 local pad=math.max(S(40),w*.045)
 local px,py,pw,ph=U.PortraitBounds(w,h)
 self.scene:SetPos(px,py);self.scene:SetSize(pw,ph)
 self.previewToggle:SetPos(px,h-S(142));self.previewToggle:SetSize(pw,S(40))
 if self.view=="home" then
  self.content:SetPos(pad,h*.45);self.content:SetSize(math.min(w*.38,S(480)),h*.49-S(40))
 else
  self.content:SetPos(pad,S(192));self.content:SetSize(w*.49-pad,h-S(310))
 end
 self.back:SetPos(pad,h-S(80));self.back:SetSize(S(170),S(46))
 self.next:SetPos(w*.49-S(260),h-S(80));self.next:SetSize(S(260),S(46))
end
function PANEL:Paint(w,h)
 U.Backdrop(w,h)
 local pad=math.max(S(40),w*.045)
 if self.view=="home" then
  U.Text("M E D I E V A L", "Display",pad,h*.20,U.ink)
  U.Text(T("A life to be written.","История, которую предстоит прожить."),"Heading",pad,h*.30,U.muted)
  U.Rule(pad,h*.37,math.min(w*.38,S(480)))
  U.Text(T("Roleplay","Ролевая игра"),"Small",pad,h*.15,U.accent)
 else
  U.Plate(pad-S(20),S(174),w*.49-pad+S(40),h-S(278))
  U.Text("MEDIEVAL", "Heading",pad,S(35),U.accent)
  U.Text(self.heading or "","Title",pad,S(93))
  U.Rule(pad,S(150),w*.49-pad)
  if self.view=="create" then
   for i,chapter in ipairs(chapters) do
    local x=w*.55+(i-1)*w*.105
    U.Text(tostring(i).." · "..T(unpack(chapter)),"Small",x,S(46),i==self.step and U.ink or U.muted)
    U.Rect(x,S(75),w*.085,1,i<=self.step and U.accent or U.line)
   end
  end
 end
 U.Text(T("Choose your path","Выберите свой путь"),"Small",pad,h-S(30),U.muted)
 if self.view~="home" then U.Text(T("Drag to rotate the character","Зажмите ЛКМ, чтобы повернуть персонажа"),"Small",w*.79,h-S(53),U.muted,TEXT_ALIGN_CENTER) end
end

function PANEL:PaintOver(w, h)

 if self.pendingChoose or self.awaitingResponse or not self.playerReady then
  local bw=S(330); local x=w-bw-S(45); local y=h-S(156)
  U.Plate(x,y,bw,S(46),U.panel)
  U.Text(T("Loading…","Загрузка…"),"Mono",x+S(14),y+S(13),U.cyan)
  local phase=ix.option.Get("disableAnimations",false) and .5 or ((RealTime()*.65)%1)
  U.Rect(x,y+S(44),bw,2,U.line)
  U.Rect(x+(bw-S(70))*phase,y+S(44),S(70),2,U.cyan)
 end
	if self.noticeText and RealTime() < self.noticeUntil then
		U.Plate(w * 0.51, h - S(155), w * 0.44, S(45), U.panel)
		U.Text(U.Fit(self.noticeText, "Body", w * 0.42), "Small", w * 0.52, h - S(141), U.accent)
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
	self.musicRequest = nil
	if IsValid(self.channel) then self.channel:Stop() end
	self.channel = nil
	if ix.gui.characterMenu == self then gui.EnableScreenClicker(false) end
end
function PANEL:PlayMusic()
	if self.bClosing or self.musicRequest or IsValid(self.channel) then return end
	-- Optional local menu music, independent of in-game playback.
	local path = "medieval_ui/menu.mp3"
	if not file.Exists("sound/" .. path, "GAME") and file.Exists("sound/music/" .. path, "GAME") then
		path = "music/" .. path
	end
	if not file.Exists("sound/" .. path, "GAME") then return end
	local request = {}
	self.musicRequest = request
	sound.PlayFile("sound/" .. path, "noplay", function(channel)
		if not IsValid(self) or self.bClosing or self.musicRequest ~= request then
			if IsValid(channel) then channel:Stop() end
			return
		end
		self.musicRequest = nil
		if not IsValid(channel) then return end
		self.channel = channel
		self.volume = 0
		channel:SetVolume(0)
		channel:EnableLooping(true)
		channel:Play()
		self:CreateAnimation(2, {
			index = 10,
			target = {volume = 0.25},
			Think = function(_, panel)
				if IsValid(panel.channel) then panel.channel:SetVolume(panel.volume) end
			end
		})
	end)
end

function PANEL:PresentCharacter(character)
	if not character then return end
	self.selected = character
	self.scene:PresentCharacter(character)
end
function PANEL:BeginView(view, title, nextText)
	self.view = view; self.heading = title; self.nextText = nextText
	self.scene:SetVisible(view ~= "home")
	self.previewToggle:SetVisible(view == "create" and self.step == 3)
	if view ~= "create" or self.step ~= 3 then self.scene:SetPortraitFocus(false) end
	self.content:Clear(); self.next:SetDisabled(false); self.next:SetVisible(view ~= "home")
	self.back:SetVisible(view ~= "home")
	self.content:GetVBar():SetScroll(0)
 self:InvalidateLayout(true)
 if not ix.option.Get("disableAnimations",false) then
  self.content:SetAlpha(0); self.content:AlphaTo(255,.22,0)
  self.scene:SetAlpha(0); self.scene:AlphaTo(255,.3,0)
 end
end
function PANEL:ShowHome()
 self:BeginView("home", "Medieval", T("Continue","Продолжить"))
 DockButton(self.content,T("Continue a story","Продолжить историю"),function() self:ShowRoster() end,true)
 DockButton(self.content,T("New character","Новый персонаж"),function() self:BeginCreation() end)
 if self.bUsingCharacter then
  DockButton(self.content,T("Return to the world","Вернуться в мир"),function() self:Close() end)
 else
  DockButton(self.content,T("Disconnect","Отключиться"),function() RunConsoleCommand("disconnect") end)
 end
 self.scene:SetVisible(false)
end

function PANEL:ShowRoster()
	self:BeginView("roster", T("Your characters", "Ваши персонажи"), T("Enter the world", "Войти в мир"))
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
				U.Plate(0, 0, w, h, selected and Color(50,43,29,235) or U.panel, selected and U.cyan or U.line)
				if selected then U.Rect(0, 0, S(3), h, U.accent) end
				U.Text(U.Fit(character:GetName(), "Heading", w - S(40)), "Heading", S(20), S(20))
				U.Text((faction and L(faction.name) or ""), "Mono", S(20), S(64), U.muted)
				U.Rect(0, h - 1, w, 1, U.line)
			end
		end
	end
	if not found then
		self.selected = nil; self.next:SetDisabled(true)
		U.Label(self.content, T("An unwritten story.", "Ещё не написанная история."), "Heading")
		U.Label(self.content, T("Create your first character to enter the world.", "Создайте первого персонажа, чтобы войти в мир."), "Body", U.muted)
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
	if not faction or not ix.faction.CanCreate(index) or not LocalPlayer():HasWhitelist(index) then return end
	self.draft.faction = index; self.draft.gender = (faction.genders or {1, 2})[1]
	self.draft.genetic[3] = faction.ageSelector and 1 or 25
	self.draft.model = 1; self.draft.sdSkin = 0; self.draft.face = {1, 1}
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
	local skin = istable(entry) and entry[2] or 0
 if faction.sdSkinCounts and faction.sdSkinCounts[Path(entry)] then skin = self.draft.sdSkin or 0 end
	self.scene:Present(Path(entry), skin, groups)
 if ix.SDHair then ix.SDHair.Apply(self.scene:GetEntity(), self.draft.sdHairColor or "original") end
end
function PANEL:ShowStep()
	self:BeginView("create", string.format("%02d / ", self.step) .. T(unpack(chapters[self.step])),
		self.step == 4 and T("Create character", "Создать персонажа") or T("Continue", "Продолжить"))
	self:PresentDraft()
	if self.step == 1 then self:Origin()
	elseif self.step == 2 then self:Identity()
	elseif self.step == 3 then self:Appearance()
	else self:Review() end
end
function PANEL:Origin()
	U.Label(self.content, T("Where does your story begin?", "Где начинается ваша история?"), "Heading")
	for index, faction in ipairs(ix.faction.indices) do
		local allowed = ix.faction.CanCreate(index) and LocalPlayer():HasWhitelist(index)
		if not allowed then continue end
		local button = DockButton(self.content, L(faction.name), function() self:SelectFaction(index); self:ShowStep() end, self.draft.faction == index)
		button:SetDisabled(not allowed)
		if not allowed then button:SetTooltip(T("Whitelist required", "Требуется доступ к фракции")) end
	end
	local faction = ix.faction.indices[self.draft.faction]

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
		self.draft.gender = value; self.draft.sdSkin = 0; self.draft.model = 1; self:ShowStep()
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
		icon.DoClick = function() self.draft.sdSkin = 0; self.draft.model = index; self:ShowStep() end
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
			self.draft.model = index
   local count = faction.sdSkinCounts and faction.sdSkinCounts[Path(models[index])]
   if count and (self.draft.sdSkin or 0) >= count then self.draft.sdSkin = 0 end
   self:ShowStep()
		end)
	end
 local path = Path(models[self.draft.model])
 local count = faction.sdSkinCounts and faction.sdSkinCounts[path]
 if count then
  local features = {}
  for value = 0, count-1 do features[#features+1]={value=value,label=T("Variant ","Вариант ")..value} end
  U.Choice(self.content,T("SKIN / FACE APPEARANCE","СКИН / ВНЕШНОСТЬ ЛИЦА"),features,self.draft.sdSkin or 0,function(value)
   self.draft.sdSkin=value; self:PresentDraft()
  end)
 end
	if ix.SDHair and ix.SDHair.Supported(path) then
		local colours = {}
		for _, preset in ipairs(ix.SDHair.presets) do
			colours[#colours + 1] = {value=preset.id, label=T(preset.en, preset.ru)}
		end
		U.Choice(self.content, T("HAIR COLOUR", "ЦВЕТ ВОЛОС"), colours, self.draft.sdHairColor or "original", function(value)
			self.draft.sdHairColor = value
			ix.SDHair.Apply(self.scene:GetEntity(), value)
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
function PANEL:Review()
	local faction = ix.faction.indices[self.draft.faction]
	U.Label(self.content, self.draft.name, "Title")
	U.Label(self.content, L(faction.name), "Mono", U.accent)
	U.Label(self.content, self.draft.description, "Body", U.muted)
	U.Label(self.content, T("Your character is ready. Begin your story.", "Персонаж готов. Начните свою историю."), "Small", U.muted)
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
	elseif self.step == 4 then self:Submit()
	else
		local checks = {{"faction"}, {"name", "description", "languages"}, {"gender", "model", "genetic", "face", "sdSkin", "sdHairColor"}}
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
