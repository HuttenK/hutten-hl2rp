local Scale = ix.UI.Scale

surface.CreateFont("autonomous.hint.title", {
	font = "Tahoma",
	size = Scale(25),
	extended = true,
	weight = 500
})
surface.CreateFont("autonomous.hint.small", {
	font = "Tahoma",
	size = Scale(16),
	extended = true,
	weight = 500
})
surface.CreateFont("autonomous.hint.info", {
	font = "Tahoma",
	size = Scale(18),
	extended = true,
	weight = 500
})
surface.CreateFont("autonomous.hint.infobig", {
	font = "Tahoma",
	size = Scale(18),
	extended = true,
	weight = 500
})


local PANEL = {}

function PANEL:Init()
	self.text = ""
	self.markup = nil

	self.alignx = nil
	self.aligny = nil

	self.hoveredLink = nil
end

function PANEL:SetMarkup(text, x, y, w)
	self.text = text
	self.alignx = x
	self.aligny = y
	
	-- Парсим markup с жестко заданной шириной
	self.markup = ix.markup.Parse(self.text, w)

	-- Устанавливаем высоту панели равной высоте распарсеного текста
	self:SetTall(self.markup:GetHeight())
	
	-- Если мы внутри контейнера с Docking, нужно сказать ему, что мы изменились
	self:InvalidateParent(true)
end

function PANEL:Paint(width, height)
	local x, y = 0, 0

	if self.alignx == TEXT_ALIGN_CENTER then
		x = x + width * 0.5
	end

	if self.alignx == TEXT_ALIGN_RIGHT then
		x = x + width
	end

	if self.aligny == TEXT_ALIGN_CENTER then
		y = y + height * 0.5
	end
	
	self.markup:draw(x, y, self.alignx, self.aligny, 255, self.hoveredLink)
end

function PANEL:Think()
    if !self.markup then return end

    local childTooltip = self.childTooltip

    if IsValid(childTooltip) and childTooltip.depth != ix.Tooltip.active then
    	return
    end
    
    local mx, my = self:CursorPos()
    local linkID, bx, by, bw, bh = self.markup:GetLinkAtPos(mx, my, 0, 0, self.alignx, self.aligny)

    if linkID and (linkID != self.hoveredLink) then
        self.hoveredLink = linkID
        
        if linkID then
        	local depth = #ix.Tooltip.active + 1
        	local screenX, screenY = input.GetCursorPos()

            ix.Tooltip:Clear(depth)
            ix.Tooltip:Create(self, depth, linkID, screenX, screenY)
        end
    end
end

vgui.Register("hint.textpanel", PANEL, "Panel")

local PANEL = {}
PANEL.colors = {}

AccessorFunc(PANEL, "mousePadding", "MousePadding", FORCE_NUMBER)

local pos, ang = vector_origin, Angle()

local y = -239.188995/2
local x = -239.188995/2

local dividerColor = Color(248, 64, 64, 8)
function PANEL:AddDivider(padding)
	padding = padding or Scale(8)
	local divider = self.container:Add("Panel")
	divider:Dock(TOP)
	divider:SetTall(padding * 2)
	divider.Paint = function(this, w, h)
		local pos = h / 2
		surface.SetDrawColor(dividerColor)
		surface.DrawLine(0, pos, w, pos)
	end

	return divider
end

local smallColor = Color(130, 130, 130)
function PANEL:AddSmallText(value, alignment, color)
	local text = self.container:Add("DLabel")
	text:Dock(TOP)
	text:SetFont("autonomous.hint.small")
	text:SetText(value)
	text:SetTextColor(color or smallColor)
	text:SizeToContents()

	return text
end

function PANEL:AddMarkup(value, alignmentX, alignmentY, offset)
	local paddingLeft, paddingTop, paddingRight, paddingBottom = self.container:GetDockPadding()
	local availableWidth = self.minWidth - paddingLeft - paddingRight - (offset or 0)

	local text = self.container:Add("hint.textpanel")
	text:Dock(TOP)
	text:SetMarkup(value, alignmentX or TEXT_ALIGN_LEFT, alignmentY or TEXT_ALIGN_TOP, availableWidth)
	text:DockMargin(0, 0, 0, Scale(4)) 

	table.insert(self.markups, text)

	return text
end

function PANEL:SetTitle(text)
	self.title:SetText(text)
end

function PANEL:Init()
	local padding = 30

	self.isAutonomousTooltip = true
	self.fraction = 1
	self.mousePadding = 8
	self.minWidth = Scale(640)
	self.minHeightBottom = 64

	self:SetAlpha(255)
	self:SetDrawOnTop(true)
	self:SetSize(self.minWidth, 200)
	self:Center()

	self.markups = {}

	local paddingLeft = Scale(36)
	local paddingTop = Scale(16)

	self.padding = paddingLeft

	self.container = self:Add("EditablePanel")
	self.container:Dock(TOP)
	self.container:SetSize(self.minWidth, 200)
	--self.container:SetAlpha(0)
	self.container:DockPadding(paddingLeft, 0, paddingLeft * 0.5, paddingTop)

	self.title = self.container:Add("DLabel")
	self.title:Dock(TOP)
	self.title:DockMargin(0, paddingTop, 0, 0)
	self.title:SetFont("autonomous.hint.title")
	self.title:SetTextColor(Color(248, 64, 64))
	self.title:SizeToContents()

	self:AddDivider()
/*
	self:CreateAnimation(1, {
		index = 1,
		target = {fraction = 1},
		easing = "outQuint",

		Think = function(animation, panel)
			panel.container:SetAlpha(panel.fraction * 255)
		end
	})*/
end

function PANEL:Resize()
	self.container:InvalidateLayout(true)
	self.container:SizeToChildren(false, true) 

	local contentTall = self.container:GetTall()
	local minHeight = 100
	
	contentTall = math.max(contentTall, minHeight)

	if self:GetTall() == contentTall then return end

	self:SetTall(contentTall)

	self:RecacheHintSize(self:GetWide(), contentTall)
end

/*
function PANEL:GetCursorPosition()
	local width, height = self:GetSize()
	local mouseX, mouseY = gui.MousePos()

	return math.Clamp(mouseX + self.mousePadding, 0, ScrW() - width), math.Clamp(mouseY + self.mousePadding, 0, ScrH() - height)
end
*/

function PANEL:Think()
	if self.parent then
		if self.parent.update_tooltip then
			self.parent.update_tooltip = false
			self:Clear()
			self.parent.OverrideTooltip(self)
			self:Resize()
		end
	end
/*
	local newX, newY = self:GetCursorPosition()

	self:SetPos(newX, newY)
	self.lastX, self.lastY = newX, newY

	self:MoveToFront() -- dragging a panel w/ tooltip will push the tooltip beneath even the menu panel(???)*/
end

function PANEL:RecacheHintSize(w,h) end
function PANEL:Paint(w,h)
 surface.SetDrawColor(12,8,13,248); surface.DrawRect(0,0,w,h)
 surface.SetDrawColor(105,38,49,230); surface.DrawOutlinedRect(0,0,w,h)
 surface.SetDrawColor(235,65,82,230); surface.DrawRect(0,0,2,h)
end

vgui.Register("autonomous.tooltip", PANEL, "EditablePanel")

do
	local PANEL = FindMetaTable("Panel")
	local ixChangeTooltip = ChangeTooltip
	local ixRemoveTooltip = RemoveTooltip
	local tooltip
	local lastHover

	function PANEL:SetAutonomousTooltip(callbackOrKey)
		self:SetMouseInputEnabled(true)

		self.OverrideTooltipCallback = callbackOrKey
	end

	function ChangeTooltip(panel, ...) -- luacheck: globals ChangeTooltip
		if (!panel.OverrideTooltipCallback) then
			return ixChangeTooltip(panel, ...)
		end

		RemoveTooltip()

		timer.Create("ixTooltip", 0.1, 1, function()
			if (!IsValid(panel) or lastHover != panel) then
				return
			end

			if lastHover and lastHover.OverrideTooltipCallback then
				ix.Tooltip:Clear(1)
			end
			
			if IsValid(tooltip) then
				return
			end

			local screenX, screenY = input.GetCursorPos()

			tooltip = ix.Tooltip:Create(panel, 1, panel.OverrideTooltipCallback, screenX, screenY)
		end)

		lastHover = panel
	end

	function RemoveTooltip() -- luacheck: globals RemoveTooltip
		timer.Remove("ixTooltip")
		lastHover = nil

		return ixRemoveTooltip()
	end
end