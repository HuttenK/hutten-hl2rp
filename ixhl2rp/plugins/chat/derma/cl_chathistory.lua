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
	-- Прокрутка вниз должна срабатывать и когда чат ЗАКРЫТ. Закрытый чат — невидимая
	-- панель, а невидимые панели НЕ проходят авто-лейаут, поэтому bar.CanvasSize
	-- оставался старым (без только что добавленного сообщения), и SetScroll уводил не
	-- в самый низ — новое сообщение оказывалось «за дном» и появлялось только после
	-- открытия чата. Принудительно пересчитываем лейаут СИНХРОННО, затем скроллим вниз.
	local function scroll()
		if (!IsValid(self)) then return end

		self:InvalidateLayout(true) -- форс-лейаут работает даже на скрытой панели

		local canvas = self:GetCanvas()
		if (IsValid(canvas)) then
			canvas:InvalidateLayout(true)
		end

		local bar = self:GetVBar()
		if (IsValid(bar)) then
			bar:SetScroll(bar.CanvasSize)
		end
	end

	scroll()                   -- немедленно (важно для закрытого чата)
	timer.Simple(0.01, scroll) -- и на след. кадре, если высота markup доуточнилась
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

			str = str:gsub("<", "&lt;"):gsub(">", "&gt;")

			-- *курсив*: текст, окружённый одиночными звёздочками с обеих сторон,
			-- отображается курсивом (сами звёздочки убираются). Escape уже сделан выше,
			-- поэтому вставка <font> безопасна.
			-- ...и в тот же золотой цвет, что и текст /me (Color(255,200,50) в schema/sh_hooks.lua)
			str = str:gsub("%*([^%*\n]+)%*", "<font=ixChatItalic><color=255,200,50>%1</color></font>")

			text = text .. str
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