local C, S = ix.Civic, ix.Civic.Scale
local colors = C.colors
local PANEL = {}
local windowState = {}

function PANEL:Init()
	if IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
	ix.gui.menu = self
	self.character = LocalPlayer():GetCharacter()
	self.frames, self.navigation = {}, {}
	self.currentAlpha = 255
	self:SetSize(ScrW(), ScrH())
	self:SetMouseInputEnabled(true)
	-- Do not steal movement/voice binds. Text controls explicitly request focus.
	self:SetKeyboardInputEnabled(false)
	gui.EnableScreenClicker(true)
	self.openedAt = RealTime()

	self.header = self:Add("Panel")
	self.header:Dock(TOP)
	self.header:SetTall(S(76))
	self.header.Paint = function(_, w, h)
		C.Rect(0, 0, w, h, colors.background)
		C.Rect(S(24), S(23), S(4), S(30), colors.accent)
		C.Text(L("civic.link"), "Heading", S(42), S(16), colors.accent)
		C.Text(L("civic.subtitle"), "Mono", S(42), S(45), colors.muted)
		C.Text(os.date("%H:%M  /  %d.%m.%Y"), "Mono", w - S(24), S(20), colors.text, TEXT_ALIGN_RIGHT)
		C.Text(C.Fit(game.GetMap(), "Mono", w * 0.3), "Mono", w - S(24), S(44), colors.muted, TEXT_ALIGN_RIGHT)
		C.Rect(0, h - 1, w, 1, colors.line)
	end
	self.footer = self:Add("Panel")
	self.footer:Dock(BOTTOM)
	self.footer:SetTall(S(32))
	self.footer.Paint = function(_, w, h)
		C.Rect(0, 0, w, h, colors.background)
		C.Text(L("civic.footer"), "Mono", S(24), S(8), colors.muted)
		C.Text("TAB / " .. L("civic.return"), "Mono", w - S(24), S(8), colors.accent, TEXT_ALIGN_RIGHT)
	end

	self.sidebar = self:Add("DScrollPanel")
	self.sidebar:Dock(LEFT)
	self.sidebar:SetWide(S(226))
	self.sidebar:DockMargin(S(16), S(18), S(14), S(18))
	self.workspace = self:Add("Panel")
	self.workspace:Dock(FILL)
	self.workspace:DockMargin(0, S(18), S(24), S(18))

	self:AddNavigation("overview", L("civic.overview"), function() self:ShowPage("overview") end, "01")
	for _, entry in ipairs(ix.UI.MenuEntries.primary) do self:AddEntry(entry) end
	self:AddNavigation("assignments", L("civic.assignments"), function() self:ShowPage("assignments") end, "05")
	self:AddNavigation("journal", L("civic.journal"), function() self:ShowPage("journal") end, "06")
	local divider = self.sidebar:Add("Panel")
	divider:Dock(TOP)
	divider:SetTall(S(25))
	for _, entry in ipairs(ix.UI.MenuEntries.secondary) do self:AddEntry(entry) end
	self:AddNavigation("return", L("civic.return"), function() self:Close() end, "↗")

	self:Receiver("ix.item", function(_, dropped, released)
		local panel = dropped and dropped[1]
		if not IsValid(panel) or not panel.instance_ids then return end
		local id = panel.instance_ids[1]
		local item = ix.Item.instances[id]
		if not item then return end
		if released then
			local direction, angle = ix.Item:GetDropAngles()
			if not isvector(direction) then direction = LocalPlayer():GetAimVector() end
			if not isangle(angle) then angle = direction:Angle() end
			net.Start("item.drop")
				net.WriteUInt(id, 32)
				net.WriteVector(direction)
				net.WriteAngle(angle)
			net.SendToServer()
			ix.Item:DropPreview(false)
		else
			ix.Item:DropPreview(true, item)
		end
	end)
	hook.Add("VGUIMousePressed", self, self.VGUIMousePressed)
	hook.Add("PlayerBindPress", self, self.PlayerBindPress)
	self:ShowPage("overview")
	hook.Run("OnTabMenuCreated", self)
end

function PANEL:AddNavigation(id, title, callback, code)
	local button = C.Button(self.sidebar, title, callback)
	button:Dock(TOP)
	button:DockMargin(0, 0, S(8), S(4))
	button:SetTall(S(44))
	button.Paint = function(this, w, h)
		local selected = self.activePage == id or IsValid(self.frames[id])
		if selected or this:IsHovered() then C.Rect(0, 0, w, h, colors.raised) end
		if selected then C.Rect(0, 0, S(3), h, colors.accent) end
		C.Text(code or "·", "Mono", S(12), S(14), selected and colors.accent or colors.muted)
		C.Text(C.Fit(title, "Body", w - S(52)), "Body", S(40), S(12), selected and colors.text or colors.muted)
	end
	self.navigation[id] = button
	return button
end

function PANEL:AddEntry(entry)
	if entry.CanUse and not entry.CanUse() then return end
	local codes = {character = "02", inventory = "03", equipment = "03", craft = "04"}
	self:AddNavigation(entry.id, L(entry.text), function()
		if entry.CanUse and not entry.CanUse() then return end
		if entry.OnClick then entry.OnClick(self) else self:OpenEntry(entry) end
	end, codes[entry.id])
end

function PANEL:ShowPage(id)
	for frameID in pairs(self.frames) do self:CloseFrame(frameID) end
	self.activePage = id
	self.lastPage = id
	self.workspace:Clear()
	self.workspace:SetVisible(true)
	local panel = self.workspace:Add("civic.dashboard")
	panel:Dock(FILL)
	panel:Setup(id, self)
end

function PANEL:OpenEntry(entry)
	if IsValid(self.frames[entry.id]) then
		self:CloseFrame(entry.id)
		if table.IsEmpty(self.frames) then self:ShowPage("overview") end
		return
	end
	self.workspace:SetVisible(false)
	self.activePage = nil
	local frame = self:Add("ui.tab.frame")
	self.frames[entry.id] = frame
	frame.frameID = entry.id
	frame:SetTitle(L(entry.text))
	local left, top = S(256), S(94)
	local maxWidth, maxHeight = ScrW() - left - S(24), ScrH() - top - S(50)
	frame:SetSize(math.min(S(entry.width), maxWidth), math.min(S(entry.height), maxHeight))
	frame:DockPadding(S(16), 22 + S(16), S(16), S(16))
	frame:SetPos(left + (maxWidth - frame:GetWide()) / 2, top + (maxHeight - frame:GetTall()) / 2)
	frame:SetMinWidth(math.min(S(420), maxWidth))
	frame:SetMinHeight(math.min(S(300), maxHeight))
	entry.OnShow(self, frame)
	local saved = windowState[entry.id]
	if saved then
		frame:SetSize(math.min(saved.w, maxWidth), math.min(saved.h, maxHeight))
		frame:SetPos(math.Clamp(saved.x, 0, ScrW() - frame:GetWide()), math.Clamp(saved.y, top, ScrH() - frame:GetTall()))
	end
	ix.util.TabFocus(frame, frame)
	ix.util.TabRequestFocus(frame)
end

function PANEL:CloseFrame(id)
	local frame = self.frames[id]
	if IsValid(frame) then
		local x, y = frame:GetPos()
		windowState[id] = {x = x, y = y, w = frame:GetWide(), h = frame:GetTall()}
		frame:Remove()
	end
	self.frames[id] = nil
	if table.IsEmpty(self.frames) and IsValid(self.workspace) then
		self.workspace:SetVisible(true)
		self.activePage = self.lastPage or "overview"
	end
end

function PANEL:Think()
	local client = LocalPlayer()
	if not IsValid(client) or client:GetCharacter() ~= self.character then self:Close() return end
	if self:GetWide() ~= ScrW() or self:GetTall() ~= ScrH() then self:Close() end
end

function PANEL:OnFrameFocus(selected)
	for _, frame in pairs(self.frames) do
		if IsValid(frame) then frame:AlphaTo(frame == selected and 255 or 215, 0.1) end
	end
end

function PANEL:VGUIMousePressed()
	local hovered = vgui.GetHoveredPanel()
	if IsValid(hovered) then ix.util.TabRequestFocus(hovered) end
end

function PANEL:OnMousePressed(code)
	if code ~= MOUSE_RIGHT then return end
	local entity = ix.GetViewTrace().Entity
	if not IsValid(entity) or not entity.GetEntityMenu then return end
	local options = entity:GetEntityMenu(LocalPlayer())
	if istable(options) and not table.IsEmpty(options) then ix.menu.Open(options, entity) end
end

function PANEL:OnMouseWheeled(delta)
	ix.Item:RotatePreview(delta)
end

function PANEL:PlayerBindPress(_, _, pressed, key)
	if not pressed or key ~= KEY_R then return end
	local items = dragndrop.GetDroppable("ix.item")
	local item = items and items[1]
	if not IsValid(item) or not item.Turn then return end
	item:Turn()
	local slot = ix.inventory_drop_slot
	if IsValid(slot) then slot.is_hovered = false end
	ix.inventory_drop_slot = nil
	return true
end

function PANEL:Close()
	if self.bClosing then return end
	self:Remove()
end

function PANEL:Remove()
	if self.bClosing then return end
	self.bClosing = true
	for id in pairs(self.frames or {}) do self:CloseFrame(id) end
	-- Call the engine base directly; the old animated Remove disables the cursor
	-- after a successor menu has already opened (e.g. character/level-up screens).
	FindMetaTable("Panel").Remove(self)
end

function PANEL:OnRemove()
	hook.Remove("VGUIMousePressed", self)
	hook.Remove("PlayerBindPress", self)
	if ix.gui.menu == self then gui.EnableScreenClicker(false) end
	if ix.Item and ix.Item.DropPreview then ix.Item:DropPreview(false) end
end

function PANEL:Paint(w, h)
	C.Rect(0, 0, w, h, Color(8, 12, 15, 190))
end

-- Keep the existing public panel ID used by TAB and both VR controller paths.
-- Register an independent class: baseclass.Set merges earlier registrations in
-- place, so aliasing the legacy table can turn its Base into a self-reference.
vgui.Register("ui.tabmenu", PANEL, "EditablePanel")
