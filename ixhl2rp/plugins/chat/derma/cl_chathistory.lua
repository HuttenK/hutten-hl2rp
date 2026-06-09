local PANEL = {}

AccessorFunc(PANEL, "filter", "Filter")
AccessorFunc(PANEL, "id", "ID", FORCE_STRING)
AccessorFunc(PANEL, "button", "Button")

function PANEL:Init()
	self:DockMargin(4, 2, 4, 4)
	self:SetPaintedManually(true)
	
	local bar = self:GetVBar()
	bar:SetWide(0)
	
	self.entries = {}
	self.filter = {}
end

DEFINE_BASECLASS("DScrollPanel")
function PANEL:SetVisible(bState)
	self:GetCanvas():SetVisible(bState)
	BaseClass.SetVisible(self, bState)
end

function PANEL:ScrollToBottom()
	timer.Simple(0.01, function()
		if IsValid(self) then
			local bar = self:GetVBar()
			bar:SetScroll(bar.CanvasSize)
		end
	end)
end

function PANEL:AddLine(elements, bShouldScroll, class)
	local classData = ix.chat.classes[class]
	local font = classData and classData.font or "ixChatFontNormal"
	
	local text = string.format("<font=%s>", font)
	local materials = {} 
	
	if (ix.option.Get("chatTimestamps", false)) then
		local timeStr = os.date(ix.option.Get("hour24Time", false) and "%H:%M" or "%I:%M %p")
		text = text .. string.format("<font=ixChatFontNormal><color=150,150,150>(%s) </color></font>", timeStr)
	end
	
	for _, v in ipairs(elements) do
		if (istable(v) and v.r and v.g and v.b) then
			text = text .. string.format("<color=%d,%d,%d>", v.r, v.g, v.b)
		elseif (type(v) == "Player" and IsValid(v)) then
			local color = team.GetColor(v:Team())
			text = text .. string.format("<color=%d,%d,%d>%s</color>", color.r, color.g, color.b, v:GetName():gsub("<", "&lt;"):gsub(">", "&gt;"))
		elseif (type(v) == "userdata") then
			-- type() returns "userdata" for IMaterial, never "IMaterial"
			if not tostring(v):find("^bad") then
				table.insert(materials, v)
			end
		else
			local str = tostring(v)
			if str == "" or type(v) == "Material" or string.StartWith(str, "Material ") then
				continue
			end
			text = text .. str:gsub("<", "&lt;"):gsub(">", "&gt;")
		end
	end
	
	text = text .. "</font>"

	-- Принудительно обновляем ширину истории перед добавлением сообщения
	self:InvalidateLayout(true)

	local panel = self:Add("ixChatMessage")
	panel:Dock(TOP)

	if panel.SetMaterials then
		panel:SetMaterials(materials)
	end

	panel:SetMarkup(text)
	panel:InvalidateLayout(true)

	table.insert(self.entries, panel)

	if (bShouldScroll) then
		self:ScrollToBottom()
	end
end

vgui.Register("ixChatboxHistory", PANEL, "DScrollPanel")