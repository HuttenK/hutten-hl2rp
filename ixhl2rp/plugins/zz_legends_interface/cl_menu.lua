local U, S = ix.InterfaceOS or ix.Legends, ix.Legends.Scale
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
 if U.Boot then U.Boot(self) end
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
	if self.view=="home" then
  self.content:SetPos(pad,h*.73); self.content:SetSize(w-pad*2,h*.27-S(42))
 else
  self.content:SetPos(pad,S(176)); self.content:SetSize(w*.44-pad,h-S(290))
 end
	self.back:SetPos(pad, h - S(80)); self.back:SetSize(S(170), S(48))
	self.next:SetPos(w - pad - S(290), h - S(80)); self.next:SetSize(S(290), S(48))
end

function PANEL:Paint(w,h)
 U.Rect(0,0,w,h,Color(10,3,8))
 local pad=math.max(S(40),w*.045)
 U.Signal(w,h,false)
 -- A broadcast composition, with the action deck below the central signal.
 U.Rect(pad,S(38),S(4),S(37),U.accent)
 U.Text("SCiPNET","Title",pad+S(19),S(30),U.ink)
 U.Text("FOUNDATION / RESTRICTED NETWORK","Mono",pad+S(20),S(66),U.muted)
 U.Text("SECURE. CONTAIN. PROTECT.","Mono",w-pad,S(39),U.accent,TEXT_ALIGN_RIGHT)
 U.Rect(pad,S(97),w-pad*2,1,U.line)
 if self.view=="home" then
  local size=math.min(h*.39,w*.26)
  local cx,cy=w*.5,h*.36
  -- Sparse framing leaves the emblem breathing room; text is never distorted.
  U.TransmissionLogo(cx-size/2,cy-size/2,size,Color(207,77,99,205))
  U.Text("L E G E N D S","Display",w*.5,h*.565,U.ink,TEXT_ALIGN_CENTER)
  U.Text(self.activeBrief or T("SELECT AN ACCESS PROTOCOL","ВЫБЕРИТЕ ПРОТОКОЛ ДОСТУПА"),"Mono",w*.5,h*.68,U.accent,TEXT_ALIGN_CENTER)
  local tx=pad; local ty=h*.25
  U.Text("01 / SCiPNET","Mono",tx,ty,U.accent)
  U.Text(T("PERSONNEL ACCESS","ДОСТУП ПЕРСОНАЛА"),"Heading",tx,ty+S(26))
  U.Rect(tx,ty+S(63),S(190),1,U.line)
  U.Text("SCP ROLEPLAY","Mono",tx,ty+S(83),U.muted)
  U.Text("INTERNAL / CLASSIFIED","Mono",tx,ty+S(107),U.muted)
  U.Text("[ SIGNAL MONITOR ]","Mono",w-pad,h*.25,U.accent,TEXT_ALIGN_RIGHT)
  for i=1,9 do
   local t=ix.option.Get("disableAnimations",false) and 0 or RealTime()
   local length=S(30)+S(90)*(.5+.5*math.sin(t*.8+i*1.7))
   U.Rect(w-pad-length,h*.25+S(32+i*8),length,2,Color(164,41,67,90))
  end
 else
  U.Text(self.heading or "","Title",pad,S(114))
  U.Rect(pad,S(157),w*.42,1,U.line)
  if self.view=="create" then
   for i,chapter in ipairs(chapters) do
    local x=w*.51+(i-1)*w*.088
    U.Text(string.format("%02d",i),"Mono",x,S(112),i==self.step and U.accent or U.muted)
    U.Rect(x,S(140),w*.065,S(2),i<=self.step and U.accent or U.line)
   end
  end
 end
 U.Text("SCiPNET / PERSONNEL DIVISION","Mono",pad,h-S(25),U.muted)
end

function PANEL:PaintOver(w, h)
 if IsValid(self.terminalIntro) then return end
 if self.pendingChoose or self.awaitingResponse or not self.playerReady then
  local bw=S(330); local x=w-bw-S(45); local y=h-S(156)
  U.Plate(x,y,bw,S(46),Color(24,6,15,245))
  U.Text(T("AWAITING CHARACTER SERVICE","ОЖИДАНИЕ АРХИВА ПЕРСОНАЖЕЙ"),"Mono",x+S(14),y+S(13),U.cyan)
  local phase=ix.option.Get("disableAnimations",false) and .5 or ((RealTime()*.65)%1)
  U.Rect(x,y+S(44),bw,2,U.line)
  U.Rect(x+(bw-S(70))*phase,y+S(44),S(70),2,U.cyan)
 end
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
	self.musicRequest = nil
	if IsValid(self.channel) then self.channel:Stop() end
	self.channel = nil
	if ix.gui.characterMenu == self then gui.EnableScreenClicker(false) end
end
function PANEL:PlayMusic()
	if self.bClosing or self.musicRequest or IsValid(self.channel) then return end
	-- Restore the SCiPNet menu theme independently of the manual in-game channel.
	local path = "maintheme.mp3"
	if not file.Exists("sound/" .. path, "GAME") and file.Exists("sound/music/" .. path, "GAME") then
		path = "music/" .. path
	end
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
 self:BeginView("home", "SCiPNET", T("Continue","Продолжить"))
 local entries={
  {"identity",T("Enter facility","Вход на объект"),T("ACCESS YOUR PERSONNEL RECORD","ОТКРЫТЬ ЛИЧНОЕ ДЕЛО"),function() self:ShowRoster() end},
  {"assignments",T("New record","Новое дело"),T("REGISTER A NEW IDENTITY","РЕГИСТРАЦИЯ НОВОГО ПЕРСОНАЖА"),function() self:BeginCreation() end},
  {"equipment",T("Resources","Материалы"),T("REQUIRED WORKSHOP CONTENT","НЕОБХОДИМЫЙ КОНТЕНТ WORKSHOP"),function() gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3806222048") end},
  {"journal",T("Community","Сообщество"),T("OPEN COMMUNITY CHANNEL","ОТКРЫТЬ КАНАЛ СООБЩЕСТВА"),function() gui.OpenURL("https://discord.gg/M8FRCsKHSU") end},
  {"system",self.bUsingCharacter and T("Resume","Продолжить") or T("Disconnect","Отключиться"),T("CLOSE THIS TERMINAL","ЗАКРЫТЬ ТЕРМИНАЛ"),function() if self.bUsingCharacter then self:Close() else RunConsoleCommand("disconnect") end end}
 }
 local deck=self.content:Add("Panel"); deck:Dock(TOP); deck:SetTall(S(142))
 local buttons={}
 for i,entry in ipairs(entries) do
  local b=U.Button(deck,entry[2],entry[4],i==1); buttons[i]=b
  b.Paint=function(this,w,h)
   U.ButtonFace(this,w,h,i==1,false)
   if this:IsHovered() or this:HasFocus() then self.activeBrief=entry[3] end
   U.Text("0"..i,"Mono",S(15),S(13),U.muted)
   U.Icon(entry[1],S(15),S(38),S(29),U.accent)
   U.Text(entry[2],"Body",S(15),h-S(46),U.ink)
   U.Text("[ SELECT ]","Mono",S(15),h-S(22),U.muted)
  end
 end
 deck.PerformLayout=function(_,w,h)
  local gap=S(10); local width=(w-gap*4)/5
  for i,b in ipairs(buttons) do b:SetPos((i-1)*(width+gap),0); b:SetSize(width,h) end
 end
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
				U.Plate(0, 0, w, h, selected and Color(74,13,31,230) or U.panel, selected and U.cyan or U.line)
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
		local checks = {{"faction"}, {"name", "description", "languages"}, {"gender", "model", "genetic", "face", "sdSkin", "sdHairColor"}, {"specials", "primaryStat"}}
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
