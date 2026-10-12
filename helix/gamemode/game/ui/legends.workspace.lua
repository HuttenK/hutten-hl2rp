local U, S = ix.InterfaceOS, ix.Legends.Scale
local T = U.T
local PANEL = {}
local previous = vgui.GetControlTable("ui.tabmenu")
-- Reuse isolated input behavior, not panel inheritance or legacy layout Init.
PANEL.PlayerBindPress = previous.PlayerBindPress
PANEL.OnMouseWheeled = previous.OnMouseWheeled
PANEL.OnMousePressed = previous.OnMousePressed
local pages = {{"launcher", "Home", "Главная"}, {"identity", "Identity", "Личность"}, {"equipment", "Equipment", "Снаряжение"},
	{"craft", "Fabrication", "Изготовление"}, {"assignments", "Assignments", "Поручения"},
	{"journal", "Journal", "Дневник"}, {"system", "System", "Система"}}

-- Remember the last app for each character during this client session.
U.lastTabByCharacter = U.lastTabByCharacter or {}
function PANEL:RememberedPage()
 local id=self.character and self.character:GetID()
 local saved=id and U.lastTabByCharacter[id]
 for _,page in ipairs(pages) do if page[1]==saved then return saved end end
 return "launcher"
end

function PANEL:Init()
	self.currentAlpha = 255
	if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
	ix.gui.menu = self; self.character = LocalPlayer():GetCharacter(); self.frames = {}
	self:SetSize(ScrW(), ScrH()); self:SetMouseInputEnabled(true); self:SetKeyboardInputEnabled(false)
	gui.EnableScreenClicker(true)
	self.navigation = self:Add("Panel"); self.body = self:Add("Panel")
	self.tabs = {}
	for index, page in ipairs(pages) do
		local button = U.Button(self.navigation, T(page[2], page[3]), function() self:ShowPage(page[1]) end)

        button.Paint=function(this,w,h)
            local active=self.page==page[1]
            U.ButtonFace(this,w,h,false,active)
            U.Icon(page[1],S(10),S(15),S(26),active and U.cyan or U.muted)
            draw.SimpleText(T(page[2],page[3]),"facility.Small",w/2+S(17),h/2,active and U.ink or U.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
        end
		self.tabs[#self.tabs + 1] = button
	end
	self.returnButton = U.Button(self, T("TAB  ·  Close", "TAB  ·  Закрыть"), function() self:Close() end)
	self:Receiver("ix.item", function(_, dropped, released)
		local p = dropped and dropped[1]; local id = IsValid(p) and p.instance_ids and p.instance_ids[1]
		local item = id and ix.Item.instances[id]; if not item then return end
		if released then
			local direction, angle = ix.Item:GetDropAngles()
			if not isvector(direction) then direction = LocalPlayer():GetAimVector() end
			if not isangle(angle) then angle = direction:Angle() end
			net.Start("item.drop"); net.WriteUInt(id, 32); net.WriteVector(direction); net.WriteAngle(angle); net.SendToServer()
			ix.Item:DropPreview(false)
		else ix.Item:DropPreview(true, item) end
	end)
	hook.Add("PlayerBindPress", self, self.PlayerBindPress)
	hook.Add("CivicTasksUpdated", self, function(panel) if panel.page == "assignments" then panel:BuildTasks() end end)
	self:ShowPage(self:RememberedPage()); hook.Run("OnTabMenuCreated", self)
end
function PANEL:PerformLayout(w,h)
 local pad=S(40)
 self.navigation:SetPos(pad,S(98)); self.navigation:SetSize(w-pad*2,S(63))
 local width=self.navigation:GetWide()/#self.tabs
 for i,button in ipairs(self.tabs) do button:SetPos((i-1)*width,0); button:SetSize(width-S(7),S(60)) end
 self.body:SetPos(pad,S(186)); self.body:SetSize(w-pad*2,h-S(268))
 self.returnButton:SetPos(w-pad-S(185),h-S(63)); self.returnButton:SetSize(S(185),S(40))
end
function PANEL:Paint(w,h)
 U.Rect(0,0,w,h,Color(12,3,9,145))
 U.Signal(w,h,true)
 local pad=S(40)
 U.Rect(pad,S(30),S(3),S(45),U.accent)
 U.Text("FIELDLINK / SCiPNET", "Heading",pad+S(18),S(26),U.ink)
 local title=T("Home","Главная")
 for _,page in ipairs(pages) do if page[1]==self.page then title=T(page[2],page[3]) end end
 U.Text("// "..title,"Mono",pad+S(18),S(59),U.accent)
 U.Text(os.date("%H:%M"),"Title",w-pad,S(23),U.ink,TEXT_ALIGN_RIGHT)
 U.Text("PERSONAL TERMINAL / "..os.date("%d.%m.%Y"),"Mono",w-pad,S(65),U.muted,TEXT_ALIGN_RIGHT)
 U.Rect(pad,S(174),w-pad*2,1,U.line)
 U.Rect(pad,h-S(75),w-pad*2,1,U.line)
 U.Text(T("LOCAL RECORD / PERSONAL ACCESS","ЛИЧНОЕ ДЕЛО / ПЕРСОНАЛЬНЫЙ ДОСТУП"),"Mono",pad,h-S(46),U.muted)
end

function PANEL:Launcher()
 local header=self.body:Add("Panel"); header:Dock(TOP); header:SetTall(S(105)); header:DockMargin(0,0,0,S(20)); header:DockPadding(S(22),S(14),S(22),0)
 header.Paint=function(_,w,h) U.Plate(0,0,w,h,Color(48,8,23,150)) end
 U.Label(header,self.character:GetName(),"Title")
 U.Label(header,T("Your equipment, health and field records. Choose an application.","Снаряжение, здоровье и полевые записи. Выберите приложение."),"Body",U.muted)
 local scroll=U.Scroll(self.body); scroll:Dock(FILL)
 local grid=scroll:Add("DIconLayout"); grid:Dock(TOP); grid:SetSpaceX(S(16)); grid:SetSpaceY(S(16))
 local descriptions={identity={"Vitals & profile","Здоровье и профиль"},equipment={"Inventory & loadout","Инвентарь и экипировка"},craft={"Tools & fabrication","Инструменты и рецепты"},assignments={"Available work","Доступные поручения"},journal={"Your field history","Полевые записи"},system={"Session & preferences","Сеанс и настройки"}}
 local cards={}
 for _,page in ipairs(pages) do if page[1]~="launcher" then
  local b=U.Button(grid,T(page[2],page[3]),function() self:ShowPage(page[1]) end)
  b.Paint=function(this,w,h)
   U.ButtonFace(this,w,h,false,false)
   U.Plate(S(18),S(18),S(52),S(52),Color(86,13,35,180))
   U.Icon(page[1],S(29),S(29),S(30),U.cyan)
   U.Text(T(page[2],page[3]),"Heading",S(18),S(86))
   local d=descriptions[page[1]]; U.Text(T(d[1],d[2]),"Small",S(18),S(115),U.muted)
   U.Text("[ OPEN ]","Mono",w-S(18),S(24),U.accent,TEXT_ALIGN_RIGHT)
  end
  cards[#cards+1]=b
 end end
 grid.Think=function(this)
  local width=this:GetWide(); if this.lastWidth==width then return end; this.lastWidth=width
  local cols=2
  for _,b in ipairs(cards) do b:SetSize(math.max(S(180),(width-S(16)*(cols-1))/cols),S(140)) end
  this:InvalidateLayout(true)
 end
end
function PANEL:ShowPage(page)
	if not self.character then self:Close(); return end
	ix.Item:DropPreview(false); self:SetKeyboardInputEnabled(false)
	self.body:Clear(); self.frames = {}; self.page = page; self.taskList = nil; self.skillRows = nil
 U.lastTabByCharacter[self.character:GetID()] = page
 if not ix.option.Get("disableAnimations",false) then self.body:SetAlpha(0); self.body:AlphaTo(255,0.14,0)
 else self.body:SetAlpha(255) end
	if page == "launcher" then self:Launcher()
 elseif page == "identity" then self:Identity()
	elseif page == "health" then self:Health()
	elseif page == "equipment" then self:Equipment()
	elseif page == "assignments" then self:Assignments()
	elseif page == "journal" then self:Journal()
	elseif page == "system" then self:System()
	else self:OpenModule(page) end
end
function PANEL:Identity()
 local header=self.body:Add("Panel"); header:Dock(TOP); header:SetTall(S(94)); header:DockMargin(0,0,0,S(24))
 local snapshot=ix.Civic.Snapshot()
 local info=U.Scroll(header); info:Dock(FILL); info:DockMargin(0,0,S(24),0)
 U.Label(info,snapshot.faction,"Mono",U.accent)
 U.Label(info,snapshot.name,"Heading")
 U.Label(info,T("LEVEL ","УРОВЕНЬ ")..snapshot.level.."   /   "..snapshot.money,"Body",U.muted)
 local progress=U.Button(header,T("Develop attributes","Развитие атрибутов"),function()
  self:Close(); vgui.Create("autonomous.levelup")
 end)
 progress:SetSize(S(250),S(46))
 header.PerformLayout=function(_,w) progress:SetPos(w-S(250),S(18)) end
 info:DockMargin(0,0,S(274),0)
 local content=self.body:Add("Panel"); content:Dock(FILL)
 local skills=content:Add("Panel"); skills:Dock(RIGHT); skills:SetWide(S(380)); skills:DockMargin(S(28),0,0,0)
 self:Skills(skills)
 local medical=content:Add("Panel"); medical:Dock(FILL)
 self:Health(medical)
end

function PANEL:Skills(parent)
 U.Label(parent,T("SKILLS","НАВЫКИ"),"Heading")
 local hint=U.Label(parent,T("Improve through practice. Hover for details.","Развиваются на практике. Наведите для описания."),"Small",U.muted)
 hint:DockMargin(0,0,0,S(18))
 local scroll=U.Scroll(parent); scroll:Dock(FILL)
 local entries={}
 for id,definition in pairs(ix.skills and ix.skills.list or {}) do
  entries[#entries+1]={id=id,definition=definition,name=L(definition.name)}
 end
 table.sort(entries,function(a,b)
  local ac,bc=a.definition.category or 0,b.definition.category or 0
  if ac~=bc then return ac<bc end
  if a.name~=b.name then return a.name<b.name end
  return a.id<b.id
 end)
 self.skillRows={}
 if #entries==0 then U.Label(scroll,T("Skill data unavailable","Данные навыков недоступны"),"Body",U.muted) end
 for _,entry in ipairs(entries) do
  local row=scroll:Add("DPanel"); row:Dock(TOP); row:SetTall(S(88)); row:DockMargin(0,0,S(12),S(8))
  row:DockPadding(S(14),S(10),S(82),0)
  local name=U.Label(row,entry.name,"Body"); name:SetMouseInputEnabled(false)
  row.definition=entry.definition; row.skillID=entry.id
  row.Paint=function(this,w,h)
   U.Plate(0,0,w,h,U.panel)
   local state=this.skillState; if not state then return end
   U.Text(state.level.." / "..state.maximum,"Body",w-S(14),S(10),U.ink,TEXT_ALIGN_RIGHT)
   U.Text(state.caption,"Small",S(14),h-S(36),state.modified~=state.level and U.cyan or U.muted)
   U.Rect(S(14),h-S(14),w-S(28),S(3),U.line)
   U.Rect(S(14),h-S(14),(w-S(28))*state.fraction,S(3),U.accent)
  end
  self.skillRows[#self.skillRows+1]=row
 end
 self:UpdateSkills()
end

function PANEL:UpdateSkills()
 if not self.skillRows or not self.character.GetSkills then return end
 local skills=self.character:GetSkills() or {}
 for _,row in ipairs(self.skillRows) do
  local definition,id=row.definition,row.skillID
  local stored=skills[id] or {0,0}
  local level=tonumber(stored[1]) or 0
  local xp=math.max(0,tonumber(stored[2]) or 0)
  local maximum=definition:GetMaximum(self.character,skills)
  local required=math.max(1,definition:GetRequiredXP(skills,level))
  local modified=self.character:GetSkillModified(id)
  local capped=level>=maximum
  local caption=capped and T("Maximum level","Максимальный уровень") or (math.floor(xp).." / "..required.." XP")
  local description=L(definition.description)
  if modified~=level then
   caption=caption.."  ·  "..T("Effective ","С учётом бонусов ")..modified
   description=description.."\n"..T("Base level: ","Базовый уровень: ")..level..T(". Effective: ",". С учётом бонусов: ")..modified
  end
  row.skillState={level=level,xp=xp,maximum=maximum,modified=modified,caption=caption,fraction=capped and 1 or math.Clamp(xp/required,0,1)}
  if row.skillTooltip~=description then row:SetTooltip(description); row.skillTooltip=description end
 end
end

function PANEL:Health(parent)
 parent=parent or self.body
 local A=ix.Anatomy
 if not A or not A.Read(self.character) then U.Label(parent,T("Medical data unavailable","Медицинские данные недоступны"),"Heading"); return end
 local canvas=parent:Add("Panel"); canvas:Dock(FILL); canvas:SetMouseInputEnabled(true)
 local details=U.Scroll(canvas)
 local title=U.Label(details,T("Body status","Состояние тела"),"Heading")
 local summary=U.Label(details,"","Body",U.muted)
 local conditions=details:Add("DLabel"); conditions:Dock(TOP); conditions:SetFont("facility.Body")
 conditions:SetTextColor(U.muted); conditions:SetWrap(true); conditions:SetAutoStretchVertical(true)
 conditions:DockMargin(0,S(18),0,0)
 canvas.PerformLayout=function(_,w,h)
  local dw=math.min(S(300),w*0.38)
  details:SetPos(dw+S(32),S(110)); details:SetSize(math.min(S(420),w-dw-S(44)),math.max(0,h-S(122)))
 end
 canvas.Paint=function(this,w,h)
  local state=A.Read(self.character); if not state then return end
  local dw=math.min(S(300),w*0.38)
  local dh=math.max(0,math.min(S(420),h-S(48)))
  local mx,my=this:LocalCursorPos()
  local part=this:IsHovered() and A.HitTest(mx,my,0,S(36),dw,dh,state) or nil
  U.Text(T("MEDICAL OVERVIEW","МЕДИЦИНСКИЙ ОБЗОР"),"Heading",0,0)
  A.Draw(0,S(36),dw,dh,state,part and part.id)
  local dx=dw+S(32); local bw=math.min(S(420),w-dx-S(12))
  U.Text(T("BLOOD RESERVE","ЗАПАС КРОВИ"),"Mono",dx,S(38),U.muted)
  U.Text(math.Round(state.blood*100).."%","Mono",dx+bw,S(38),U.ink,TEXT_ALIGN_RIGHT)
  U.Rect(dx,S(67),bw,S(3),U.line); U.Rect(dx,S(67),bw*state.blood,S(3),A.Color(state.blood))
  if (state.painRemaining or 0)>0 then
   U.Text(T("PAIN RELIEF","ОБЕЗБОЛИВАНИЕ").."  "..string.format("%d:%02d",math.floor(state.painRemaining/60),math.floor(state.painRemaining%60)),"Mono",dx,S(83),U.muted)
  end
  -- Keep the most recently inspected limb readable while moving into its details.
  if part then this.selectedPart=part.id end
  local selected
  for _,limb in ipairs(state.parts) do if limb.id==this.selectedPart then selected=limb; break end end
  local heading=selected and L(selected.name) or T("Inspect a body part","Осмотр части тела")
  local info=selected and (selected.current.." / "..selected.maximum.."  HP") or T("Hover over the silhouette to inspect injuries.","Наведите курсор на силуэт, чтобы осмотреть травмы.")
  local names={}
  if selected and selected.amputated then
   info=T("Amputated","Ампутировано")
   names[#names+1]=T("The limb is missing. Reattachment requires a matching limb and a qualified medic.","Конечность отсутствует. Для восстановления нужны подходящая конечность и квалифицированный медик.")
  end
  for _,condition in pairs(state.health.hediffs or {}) do
   if selected and condition.part==selected.id and condition:IsVisible() then
    names[#names+1]=condition.Stage and condition:Stage() or condition.name
   end
  end
  table.sort(names)
  if selected and selected.fractured then
   names[#names+1]=(state.painRemaining or 0)>0 and T("Pain relief temporarily suppresses fracture restrictions.","Обезболивающее временно подавляет ограничения перелома.") or
    (selected.hitgroup>=6 and T("Running is blocked; walking is slower. Treat with a splint or CMS.","Бег недоступен, ходьба замедлена. Нужны шина или CMS.") or T("Two-handed weapons are unavailable. Treat with a splint or CMS.","Двуручное оружие недоступно. Нужны шина или CMS."))
  end
  local text=selected and (#names>0 and table.concat(names,"\n\n") or T("No visible injuries","Видимых травм нет")) or ""
  if this.lastHeading~=heading then title:SetText(heading); this.lastHeading=heading end
  if this.lastInfo~=info then summary:SetText(info); this.lastInfo=info end
  if this.lastDetails~=text then conditions:SetText(text); this.lastDetails=text end
 end
end

function PANEL:AddInventory(parent, inventory, title, size)
	if not inventory then return end
	U.Label(parent, title, "Mono", U.muted)
	local holder = parent:Add("Panel"); holder.container = true
	holder:Dock(TOP); holder:DockMargin(0, 0, 0, S(22))
	local panel = inventory:CreatePanel(holder)
	panel:SetSlotSize(size); panel:SetTitle(""); panel:Rebuild(); panel:SizeToContents()
	panel.bNoBackgroundBlur = true; panel:Dock(FILL)
	holder:SetTall(math.min(panel:GetTall(), S(430)))
	return panel
end
function PANEL:Equipment()
	local client = LocalPlayer()
	local equipment = U.Scroll(self.body); equipment:Dock(LEFT); equipment:SetWide((ScrW() - S(96)) * 0.27)
	equipment:DockMargin(0, 0, S(28), 0)
	U.Label(equipment, T("LOADOUT", "ЭКИПИРОВКА"), "Heading")
	-- The workspace has its own layout; the legacy ixEquipment panel is used
	-- by containers/looting, not by FIELDLINK's equipment tab.
	if ix.WeaponSlots then
		local weapons = equipment:Add("DIconLayout"); weapons:Dock(TOP)
		weapons:SetSpaceX(S(14)); weapons:SetSpaceY(S(14))
		for slot = 1, ix.WeaponSlots.count do
			local inventory = client:GetInventory("weapon" .. slot)
			if inventory then
				local card = weapons:Add("Panel"); card:SetSize(S(112), S(110))
				card:SetTooltip(ix.WeaponSlots.Description(slot))
				self:AddInventory(card, inventory, ix.WeaponSlots.Label(slot), S(56))
			end
		end
		U.Label(equipment, T("Drag to equip; drag back or right-click to remove.", "Перетащите в слот. Обратно — в инвентарь или ПКМ: убрать."), "Small", U.muted)
	end
	local grid = equipment:Add("DIconLayout"); grid:Dock(TOP)
	grid:SetSpaceX(S(14)); grid:SetSpaceY(S(14))
	for _, slot in ipairs({{"head", "tab_slot_head"}, {"mask", "tab_slot_face"}, {"glasses", "equip.glasses"},
		{"ears", "tab_slot_ears"}, {"torso", "tab_slot_torso"}, {"vest", "equip.vest"}, {"hands", "tab_slot_hands"}, {"armprotection", "equip.armprotection"},
		{"legs", "tab_slot_legs"}, {"legprotection", "equip.legprotection"}, {"radio", "tab_radio"}, {"cid", "label_cid"}, {"backpack", "tab_backpack"}}) do
		local inventory = client:GetInventory(slot[1])
		if inventory then
			local card = grid:Add("Panel"); card:SetSize(S(112), S(110))
			self:AddInventory(card, inventory, L(slot[2]), S(56))
		end
	end
	local portrait = self.body:Add("legends.portrait"); portrait:Dock(RIGHT); portrait:SetWide((ScrW() - S(96)) * 0.29)
	portrait:PresentCharacter(self.character)
	local bags = U.Scroll(self.body); bags:Dock(FILL)
	U.Label(bags, T("CARRIED ITEMS", "ПРИ СЕБЕ"), "Heading")
	self:AddInventory(bags, client:GetInventory("main"), L("inv"), S(54))
	self.bagHost = bags; self.bagSection = bags:Add("Panel"); self.bagSection:Dock(TOP)
	self.backpackID = nil; self:UpdateBackpack()
end
function PANEL:UpdateBackpack()
	if not IsValid(self.bagSection) then return end
	local bagSlot = LocalPlayer():GetInventory("backpack")
	local ids = bagSlot and bagSlot:GetSlot(1, 1)
	local itemID = ids and ids[1] or false
	local inventory
	if itemID then for _, candidate in pairs(ix.Inventory:All()) do if candidate.instance_id == itemID then inventory = candidate; break end end end
	local id = inventory and inventory.id or false
	if self.backpackID == id then return end
	self.backpackID = id; self.bagSection:Clear()
	if inventory then self:AddInventory(self.bagSection, inventory, L("tab_backpack"), S(54)) end
	self.bagSection.PerformLayout = function(p)
		local height = 0; for _, child in ipairs(p:GetChildren()) do local _, top, _, bottom = child:GetDockMargin(); height = height + child:GetTall() + top + bottom end
		if p:GetTall() ~= height then p:SetTall(height) end
	end
end
function PANEL:Assignments()
	local content = U.Scroll(self.body); content:Dock(FILL)
	U.Label(content, T("Work worth doing.", "Дело найдётся."), "Title")
	U.Label(content, L("civic.taskHint"), "Small", U.muted)
	local search = U.Field(content, T("SEARCH", "ПОИСК"), "", function(value) self.query = value; self:BuildTasks() end)
	search.OnGetFocus = function() self:SetKeyboardInputEnabled(true) end
	search.OnLoseFocus = function() if IsValid(self) then self:SetKeyboardInputEnabled(false) end end
	self.query = ""; self.taskList = content:Add("Panel"); self.taskList:Dock(TOP); self:BuildTasks()
end
function PANEL:BuildTasks()
	if not IsValid(self.taskList) then return end
	self.taskList:Clear()
	local board = ix.plugin.Get("taskboard"); local count = 0
	for _, task in ipairs(board and board.tasks or {}) do
		if self.query == "" or ((task.title or "") .. " " .. (task.summary or "")):utf8lower():find(self.query:utf8lower(), 1, true) then
			count = count + 1
			local row = self.taskList:Add("Panel"); row:Dock(TOP); row:DockMargin(0, 0, S(12), S(22)); row:DockPadding(S(22), S(18), S(22), S(18))
			row.Paint = function(_, w, h) U.Rect(0, 0, w, h, U.panel); U.Rect(0, 0, S(2), h, U.accent) end
			U.Label(row, L("civic." .. task.status) .. " / " .. (task.posterName or ""), "Mono", U.accent)
			U.Label(row, task.title, "Heading"); U.Label(row, task.summary, "Body", U.muted)
			if task.reward and task.reward ~= "" then U.Label(row, task.reward, "Body", U.accent) end
			local detail = board.details and board.details[task.id]
			if detail then U.Label(row, detail, "Body") end
			local function action(id, phrase)
				local button = U.Button(row, L(phrase), function()
					Derma_Query(L("civic.confirm"), task.title, L("civic.yes"), function()
						if IsValid(self) then netstream.Start("taskboard." .. id, task.id) end
					end, L("civic.cancel"))
				end)
				button:Dock(TOP); button:DockMargin(0, 0, 0, S(6))
			end
			if task.posterID == self.character:GetID() then
				if task.status == "taken" then action("complete", "civic.complete") end
				action("close", "civic.closeTask")
			elseif detail and task.status == "taken" then action("abandon", "civic.abandon")
			elseif task.status == "open" then action("accept", "civic.accept") end
			row.PerformLayout = function(p)
				local height = S(36); for _, child in ipairs(p:GetChildren()) do local _, top, _, bottom = child:GetDockMargin(); height = height + child:GetTall() + top + bottom end
				if p:GetTall() ~= height then p:SetTall(height) end
			end
		end
	end
	if count == 0 then U.Label(self.taskList, L("civic.noTasks"), "Body", U.muted) end
	self.taskList.PerformLayout = function(p)
		local height = 0; for _, child in ipairs(p:GetChildren()) do local _, top, _, bottom = child:GetDockMargin(); height = height + child:GetTall() + top + bottom end
		if p:GetTall() ~= height then p:SetTall(height) end
	end
end
function PANEL:Journal()
	local content = U.Scroll(self.body); content:Dock(FILL)
	U.Label(content, T("The story so far.", "История продолжается."), "Title")
	local journal = self.character:GetData("civicJournal", {})
	if #journal == 0 then U.Label(content, L("civic.emptyJournal"), "Body", U.muted) end
	for _, entry in ipairs(journal) do
		U.Label(content, os.date("%d.%m.%Y / %H:%M", entry.time), "Mono", U.accent)
		local label = U.Label(content, L(entry.key, entry.value or ""), "Heading")
		label:DockMargin(S(20), 0, 0, S(32))
	end
end
function PANEL:System()
	local content = U.Scroll(self.body); content:Dock(FILL)
	U.Label(content, T("Your session.", "Ваш сеанс."), "Title")
	for _, entry in ipairs(ix.UI.MenuEntries.secondary) do
		if not entry.CanUse or entry.CanUse() then
			local button = U.Button(content, L(entry.text), function()
				if entry.CanUse and not entry.CanUse() then return end
				if entry.OnClick then entry.OnClick(self) else self:ShowPage(entry.id) end
			end)
			button:Dock(TOP); button:DockMargin(0, 0, 0, S(10))
		end
	end
end
function PANEL:OpenModule(id)
	for _, entries in pairs(ix.UI.MenuEntries) do
		for _, entry in ipairs(entries) do
			if entry.id == id and entry.OnShow and (not entry.CanUse or entry.CanUse()) then
				local host = self.body:Add("EditablePanel"); host:Dock(FILL)
				-- Legacy builders measure their parent synchronously during Setup.
				self:InvalidateLayout(true); self.body:InvalidateLayout(true)
				host:SetSize(self.body:GetWide(), self.body:GetTall())
				host.Paint = function(_, w, h) U.Rect(0, 0, w, h, Color(20, 9, 15, 110)) end
				-- A nested popup escapes the TAB body's clipping and screen position.
				host.MakePopup = function() self:SetKeyboardInputEnabled(true) end
				entry.OnShow(self, host); host:DockPadding(0, 0, 0, 0); self.frames[id] = host
				host:InvalidateLayout(true)
				return
			end
		end
	end
end
function PANEL:OnFrameFocus() end
function PANEL:CloseFrame() self:ShowPage("identity") end
function PANEL:Close() self:Remove() end
function PANEL:OnRemove()
	hook.Remove("PlayerBindPress", self); hook.Remove("CivicTasksUpdated", self)
	if ix.gui.menu == self then gui.EnableScreenClicker(false) end
	ix.Item:DropPreview(false)
end
function PANEL:Think()
	if LocalPlayer():GetCharacter() ~= self.character then self:Close(); return end
	if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then self:Close(); return end
	if RealTime() < (self.nextRefresh or 0) then return end
	self.nextRefresh = RealTime() + 0.5; self.snapshot = ix.Civic.Snapshot()
	if self.page == "equipment" then self:UpdateBackpack() end
	if self.page == "identity" then self:UpdateSkills() end
end
vgui.Register("ui.tabmenu", PANEL, "EditablePanel")
