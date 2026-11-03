local U, S = ix.InterfaceOS, ix.Legends.Scale
local T = U.T
local PANEL = {}
local previous = vgui.GetControlTable("ui.tabmenu")
-- Reuse isolated input behavior, not panel inheritance or legacy layout Init.
PANEL.PlayerBindPress = previous.PlayerBindPress
PANEL.OnMouseWheeled = previous.OnMouseWheeled
PANEL.OnMousePressed = previous.OnMousePressed
local pages = {{"equipment", "Inventory", "Инвентарь"}, {"identity", "Character", "Персонаж"},
 {"craft", "Crafting", "Ремесло"}, {"assignments", "Tasks", "Поручения"},
 {"journal", "Journal", "Дневник"}, {"system", "Settings", "Настройки"}}

-- Remember the last app for each character during this client session.
U.lastTabByCharacter = U.lastTabByCharacter or {}
function PANEL:RememberedPage()
 local id=self.character and self.character:GetID()
 local saved=id and U.lastTabByCharacter[id]
 for _,page in ipairs(pages) do if page[1]==saved then return saved end end
 return "equipment"
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
            draw.SimpleText(U.Fit(T(page[2],page[3]),"Heading",w-S(18)),"legends.Heading",w/2,h/2,active and U.ink or U.muted,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
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
 local pad=S(24)
 self.navigation:SetPos(pad,S(12));self.navigation:SetSize(w-pad*2,S(47))
 local width=self.navigation:GetWide()/#self.tabs
 for i,button in ipairs(self.tabs) do button:SetPos((i-1)*width,0);button:SetSize(width-S(5),S(46)) end
 self.body:SetPos(pad,S(80));self.body:SetSize(w-pad*2,h-S(155))
 self.returnButton:SetPos(w-pad-S(170),h-S(53));self.returnButton:SetSize(S(170),S(35))
end
function PANEL:Paint(w,h)
 U.Backdrop(w,h)
 local pad=S(24)
 U.Rule(pad,S(69),w-pad*2)
 U.Plate(pad,h-S(63),w-pad*2,S(53))
 U.Text(T("LMB · select     Drag · move     Click · actions","ЛКМ · выбор     Перетащить · переместить     Нажатие · действия"),"Small",pad+S(20),h-S(43),U.muted)
end

function PANEL:ShowPage(page)
	if not self.character then self:Close(); return end
	ix.Item:DropPreview(false); self:SetKeyboardInputEnabled(false)
	self.body:Clear(); self.body.PerformLayout=nil; self.frames = {}; self.page = page; self.taskList = nil; self.inspectedID=nil
 U.lastTabByCharacter[self.character:GetID()] = page
 if not ix.option.Get("disableAnimations",false) then self.body:SetAlpha(0); self.body:AlphaTo(255,0.14,0)
 else self.body:SetAlpha(255) end
	if page == "identity" then self:Identity()
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
 U.Label(info,snapshot.money,"Body",U.muted)
 local content=self.body:Add("Panel"); content:Dock(FILL)
 if ix.Traits then
  local traits=U.Scroll(content); traits:Dock(RIGHT); traits:SetWide(S(300)); traits:DockMargin(S(20),0,0,0)
  U.Label(traits,T("Character traits","Черты персонажа"),"Heading",U.accent)
  ix.Traits.BuildSummary(traits,self.character)
 end
 local medical=content:Add("Panel"); medical:Dock(FILL)
 self:Health(medical)
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
    (selected.hitgroup>=6 and T("Running is blocked; walking is slower. Treat with a splint .","Бег недоступен, ходьба замедлена. Нужны шина .") or T("Two-handed weapons are unavailable. Treat with a splint .","Двуручное оружие недоступно. Нужны шина ."))
  end
  local text=selected and (#names>0 and table.concat(names,"\n\n") or T("No visible injuries","Видимых травм нет")) or ""
  if this.lastHeading~=heading then title:SetText(heading); this.lastHeading=heading end
  if this.lastInfo~=info then summary:SetText(info); this.lastInfo=info end
  if this.lastDetails~=text then conditions:SetText(text); this.lastDetails=text end
 end
end

function PANEL:AddInventory(parent, inventory, title, size, icon)
 if not inventory then return end
 if title and title~="" then U.Label(parent,title,"Small",U.muted) end
 local holder=parent:Add("Panel");holder.container=true
 holder:Dock(TOP);holder:DockMargin(0,0,0,S(18))
 local panel=inventory:CreatePanel(holder)
 if icon then panel:SetIcon(icon) end
 panel:SetSlotSize(size);panel:SetTitle("");panel:Rebuild();panel:SizeToContents()
 panel.bNoBackgroundBlur=true
 -- Do not clip a large bag to a fixed height; its parent provides scrolling.
 local height=panel:GetTall()
 holder:SetTall(height);panel:Dock(FILL)
 holder.PerformLayout=function(this,w)
  if w<=0 then return end
  local current=panel:GetSlotSize()
  local cw=panel:GetContentSize()
  -- Fit presentation to this column; never alter inventory rows or regions.
  local wanted=math.max(S(24),math.min(size,math.floor(current*(w-S(4))/math.max(1,cw))))
  if math.abs(current-wanted)>=2 then panel:SetSlotSize(wanted);panel:Rebuild() end
  local _,ch=panel:GetContentSize()
  if this:GetTall()~=ch then this:SetTall(ch) end
 end
 return panel
end
function PANEL:EquipmentGeometry(w,h)
 local gap=S(10)
 local seam=U.BackdropGeometry(w+S(48),h+S(155))
 local available=math.max(1,seam-S(24)-gap*2)
 local lw=math.floor(available*.63)
 local dw=available-lw
 return lw,dw,gap,math.max(1,w-lw-dw-gap*2)
end
function PANEL:Equipment()
 local client=LocalPlayer()
 local leftFrame=self.body:Add("Panel")
 leftFrame:DockPadding(S(18),S(18),S(14),S(18))
 leftFrame.Paint=function(_,w,h) U.Plate(0,0,w,h) end
 local left=U.Scroll(leftFrame);left:Dock(FILL)
 local detail=self.body:Add("Panel")
 local portrait=self.body:Add("legends.portrait")
 portrait:PresentCharacter(self.character)
 local vitals=self.body:Add("Panel");vitals:SetMouseInputEnabled(false)
 vitals.Paint=function(_,w,h)
  local char=self.character
  U.Plate(0,0,w,h,Color(255,255,255,222))
  U.Text(U.Fit(char:GetName(),"Heading",w-S(34)),"Heading",S(17),S(10))
  local health=char.Health and char:Health()
  local hp=health and health.GetPercent and health:GetPercent() or client:Health()/math.max(1,client:GetMaxHealth())
  local stamina=client:GetLocalVar("stm",0)/math.max(1,char.GetMaxStamina and char:GetMaxStamina() or 100)
  for i,bar in ipairs({{hp,U.rose,T("Health","Здоровье")},{stamina,Color(131,140,91),T("Stamina","Выносливость")}}) do
   local y=S(40+(i-1)*22)
   U.Text(bar[3],"Small",S(17),y-S(2),U.muted)
   local x,bw=w*.44,w*.56-S(18)
   U.Rect(x,y+S(3),bw,S(8),U.dark)
   U.Rect(x+1,y+S(4),(bw-2)*math.Clamp(bar[1],0,1),S(6),bar[2])
   surface.SetDrawColor(U.line);surface.DrawOutlinedRect(x,y+S(3),bw,S(8))
  end
  U.Icon("coins",S(16),h-S(27),S(19))
  U.Text(ix.currency.Get(char:GetMoney()),"Small",S(42),h-S(25),U.ink)
 end
 detail:DockPadding(S(22),S(18),S(22),S(18))
 detail.Paint=function(_,w,h) U.Plate(0,0,w,h) end
 self.equipmentColumns={leftFrame,detail,portrait}
 self.body.PerformLayout=function(_,w,h)
  local lw,dw,gap,rw=self:EquipmentGeometry(w,h)
  leftFrame:SetPos(0,0);leftFrame:SetSize(lw,h)
  detail:SetPos(lw+gap,0);detail:SetSize(dw,h)
  local rx=lw+dw+gap*2
  local px,py,pw,ph=U.PortraitBounds(w+S(48),h+S(155))
  portrait:SetPos(px-S(24),py-S(80));portrait:SetSize(pw,ph)
  vitals:SetPos(rx+S(16),h-S(104));vitals:SetSize(rw-S(32),S(104))
 end
 U.Label(left,T("Equipment","Экипировка"),"Heading")
 local slots=left:Add("DIconLayout");slots:Dock(TOP)
 slots:SetSpaceX(S(5));slots:SetSpaceY(S(5));slots:DockMargin(0,0,S(8),S(21))
 local entries={}
 for i=1,ix.WeaponSlots.count do entries[#entries+1]={"weapon"..i,ix.WeaponSlots.Label(i)} end
 for _,slot in ipairs({{"head","Голова"},{"mask","Лицо"},{"torso","Одежда"},{"vest","Доспех"},
  {"hands","Кисти"},{"armprotection","Наручи"},{"legs","Ноги"},{"legprotection","Поножи"},
  {"backpack","Сумка"},{"satchel","Подсумок"}}) do entries[#entries+1]=slot end
 for _,entry in ipairs(entries) do
  local inventory=client:GetInventory(entry[1])
  if inventory then
   local card=slots:Add("Panel");card:SetSize(S(76),S(76))
   local grid=self:AddInventory(card,inventory,nil,S(76),entry[1])
   if IsValid(grid) then grid:SetTooltip(entry[2]) end
  end
 end
 U.Label(left,T("Belongings","При себе"),"Heading")
 local main=client:GetInventory("main")
 -- Same inventory APIs as containers/looting: drag, split, transfer and use
 -- continue through the existing server validations.
 self:AddInventory(left,main,nil,S(82))
 self.bagHost=left;self.bagSection=left:Add("Panel");self.bagSection:Dock(TOP)
 self.backpackID=nil;self:UpdateBackpack()
 U.Label(detail,T("Item description","Описание предмета"),"Heading")
 self.itemPreview=detail:Add("DModelPanel");self.itemPreview:Dock(TOP)
 self.itemPreview:SetTall(S(225));self.itemPreview:SetFOV(40)
 self.itemPreview:SetAmbientLight(Color(115,110,98))
 self.itemPreview:SetDirectionalLight(BOX_FRONT,Color(235,224,193))
 self.itemPreview.LayoutEntity=function() end
 self.itemPreview:SetMouseInputEnabled(false);self.itemPreview:SetVisible(false)
 local divider=detail:Add("Panel");divider:Dock(TOP);divider:SetTall(S(18))
 divider.Paint=function(_,w,h) U.Rule(0,h/2,w) end
 self.itemTitle=U.Label(detail,T("Select an item","Выберите предмет"),"Heading")
 self.itemCategory=U.Label(detail,T("Click an inventory slot","Нажмите на предмет в инвентаре"),"Small",U.muted)
 local info=U.Scroll(detail);info:Dock(FILL)
 self.itemDescription=U.Label(info,T("Drag an item to equip it. Right-click opens its actions.","Перетащите предмет в слот, чтобы надеть его. Меню действий открывается нажатием на предмет."),"Body",U.muted)
 self.itemFacts=U.Label(info,"","Small",U.accent)
 self.itemAction=U.Button(detail,T("Actions","Действия"),function()
  local item=self.inspectedID and ix.Item.instances[self.inspectedID]
  if item then ix.Item:OpenItemMenu({item.id},item.inventory_id) end
 end)
 self.itemAction:Dock(BOTTOM);self.itemAction:SetVisible(false)
 self.inspectedID=nil
 self.body:InvalidateLayout(true)
end
function PANEL:InspectItem(id)
 if self.page~="equipment" or not IsValid(self.itemTitle) then return end
 local item=id and ix.Item.instances[id]
 if not item then
  self.inspectedID=nil;self.itemTitle:SetText(T("Select an item","Выберите предмет"))
  self.itemCategory:SetText("");self.itemDescription:SetText("");self.itemFacts:SetText("")
  self.itemPreview:SetVisible(false);self.itemAction:SetVisible(false)
  return
 end
 self.inspectedID=id
 self.itemTitle:SetText(item:GetPrintName())
 self.itemCategory:SetText(L(item.category or "item"))
 self.itemDescription:SetText(item:GetDescription())
 local facts={}
 local weight=tonumber(item:GetWeight())
 if weight and weight>0 then facts[#facts+1]=T("Weight: ","Вес: ")..tostring(weight) end
 local count=item.GetValue and item:GetValue()
 if isnumber(count) and count>1 then facts[#facts+1]=T("Quantity: ","Количество: ")..count end
 self.itemFacts:SetText(table.concat(facts,"\n"))
 self.itemAction:SetVisible(true)
 local model=item:GetModel()
 if not isstring(model) or model=="" then self.itemPreview:SetVisible(false) return end
 local preview=self.itemPreview
 preview:SetVisible(true);preview:SetModel(model)
 local entity=preview:GetEntity()
 if not IsValid(entity) then preview:SetVisible(false) return end
 entity:SetSkin(item:GetSkin())
 local lo,hi=entity:GetRenderBounds();local center=(lo+hi)*.5
 local radius=math.max((hi-lo):Length()*.5,4)
 preview:SetLookAt(center)
 preview:SetCamPos(center+Vector(1,.7,.5):GetNormalized()*radius*3.2)
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
 if inventory then self:AddInventory(self.bagSection, inventory, L("tab_backpack"), S(82)) end
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
				host.Paint = function(_, w, h) U.Rect(0, 0, w, h, Color(16,17,15,210)) end
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
	if self.page == "equipment" then
  self:UpdateBackpack()
  if self.inspectedID and not ix.Item.instances[self.inspectedID] then self:InspectItem(nil) end
 end
	if self.page == "identity" then end
end
vgui.Register("ui.tabmenu", PANEL, "EditablePanel")
