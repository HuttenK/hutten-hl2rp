-- Редактор новостей — попап (доступен админам/ГО у терминала-редактора).
local function P() return ix.plugin.list["gonews"] end

local FRAME_W, FRAME_H = 760, 620

local function StyleEntry(entry, C, multiline)
	entry:SetFont("ixNewsBody")
	entry:SetTextColor(C.text)
	entry:SetCursorColor(C.line)
	if multiline then entry:SetMultiline(true) end
	entry.Paint = function(s, w, h)
		surface.SetDrawColor(C.row); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(C.line); surface.DrawRect(0, h - 2, w, 2)
		s:DrawTextEntryText(C.text, C.line, C.text)
	end
end

local PANEL = {}

function PANEL:Init()
	self.startTime = SysTime()
	self.imageType = "url"

	self:SetSize(FRAME_W, FRAME_H)
	self:Center()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:MakePopup()
	self:SetDeleteOnClose(true)

	local C = P().Colors

	self.close = self:Add("DButton")
	self.close:SetText("")
	self.close:SetSize(26, 26)
	self.close.DoClick = function() self:Remove() end
	self.close.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and C.red or C.lineD); surface.DrawRect(0, 0, w, h)
		draw.SimpleText("X", "ixNewsSmall", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local x = 20
	local fw = (FRAME_W - 40)
	local y = 56

	local function label(text, yy)
		local l = self:Add("DLabel")
		l:SetFont("ixNewsSmall"); l:SetTextColor(C.dim)
		l:SetPos(x, yy); l:SetText(text); l:SizeToContents()
	end

	label("ЗАГОЛОВОК", y); y = y + 18
	self.title = self:Add("DTextEntry"); self.title:SetPos(x, y); self.title:SetSize(fw, 28)
	StyleEntry(self.title, C); y = y + 38

	label("ИСТОЧНИК", y); y = y + 18
	self.source = self:Add("DTextEntry"); self.source:SetPos(x, y); self.source:SetSize(fw, 28)
	self.source:SetText("Гражданская Оборона")
	StyleEntry(self.source, C); y = y + 38

	label("ТЕКСТ СТАТЬИ", y); y = y + 18
	self.text = self:Add("DTextEntry"); self.text:SetPos(x, y); self.text:SetSize(fw, 150)
	StyleEntry(self.text, C, true); y = y + 160

	-- тип изображения
	label("ИЗОБРАЖЕНИЕ", y); y = y + 18
	self.btnURL = self:Add("DButton"); self.btnURL:SetPos(x, y); self.btnURL:SetSize(90, 26); self.btnURL:SetText("")
	self.btnMat = self:Add("DButton"); self.btnMat:SetPos(x + 96, y); self.btnMat:SetSize(110, 26); self.btnMat:SetText("")
	local function modeBtn(btn, mode, text)
		btn.DoClick = function() self.imageType = mode end
		btn.Paint = function(s, w, h)
			local active = self.imageType == mode
			surface.SetDrawColor(active and C.line or C.row); surface.DrawRect(0, 0, w, h)
			draw.SimpleText(text, "ixNewsSmall", w * 0.5, h * 0.5, active and Color(10, 16, 20) or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
	modeBtn(self.btnURL, "url", "URL")
	modeBtn(self.btnMat, "material", "МАТЕРИАЛ")
	y = y + 32

	self.image = self:Add("DTextEntry"); self.image:SetPos(x, y); self.image:SetSize(fw, 28)
	self.image:SetText("")
	StyleEntry(self.image, C); y = y + 38

	-- опубликовать
	self.post = self:Add("DButton"); self.post:SetPos(x, y); self.post:SetSize(fw, 32); self.post:SetText("")
	self.post.DoClick = function()
		local title = self.title:GetValue()
		if !title or title == "" then
			surface.PlaySound("buttons/button10.wav")
			return
		end
		netstream.Start("gonews.post", {
			title     = title,
			source    = self.source:GetValue(),
			text      = self.text:GetValue(),
			image     = self.image:GetValue(),
			imageType = self.imageType,
		})
		surface.PlaySound("buttons/button14.wav")
		self.title:SetText(""); self.text:SetText(""); self.image:SetText("")
	end
	self.post.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and C.line or C.lineD); surface.DrawRect(0, 0, w, h)
		draw.SimpleText("ОПУБЛИКОВАТЬ НОВОСТЬ", "ixNewsItem", w * 0.5, h * 0.5,
			s:IsHovered() and Color(10, 16, 20) or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	y = y + 44

	label("ОПУБЛИКОВАННЫЕ (нажми × чтобы удалить)", y); y = y + 20
	self.list = self:Add("DScrollPanel"); self.list:SetPos(x, y); self.list:SetSize(fw, FRAME_H - y - 16)
	local bar = self.list:GetVBar(); bar:SetWide(6)
	bar.Paint = function() end; bar.btnUp.Paint = function() end; bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(C.line); surface.DrawRect(0, 0, w, h) end

	self:RebuildList()
end

function PANEL:RebuildList()
	if !IsValid(self.list) then return end
	self.list:Clear()
	local C = P().Colors

	for _, entry in ipairs(P():GetNews()) do
		local row = self.list:Add("DPanel")
		row:Dock(TOP); row:DockMargin(0, 0, 6, 4); row:SetTall(30)
		row.Paint = function(_, w, h)
			surface.SetDrawColor(C.row); surface.DrawRect(0, 0, w, h)
			draw.SimpleText(entry.title or "—", "ixNewsSmall", 8, h * 0.5, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end

		local del = row:Add("DButton"); del:Dock(RIGHT); del:SetWide(30); del:SetText("")
		del.DoClick = function()
			netstream.Start("gonews.remove", entry.id)
			surface.PlaySound("buttons/button14.wav")
		end
		del.Paint = function(s, w, h)
			surface.SetDrawColor(s:IsHovered() and C.red or C.lineD); surface.DrawRect(0, 0, w, h)
			draw.SimpleText("×", "ixNewsItem", w * 0.5, h * 0.5 - 1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

function PANEL:Paint(w, h)
	local C = P().Colors
	Derma_DrawBackgroundBlur(self, self.startTime)
	surface.SetDrawColor(C.bg); surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(0, 0, 0, 24)
	for yy = 0, h, 3 do surface.DrawRect(0, yy, w, 1) end
	surface.SetDrawColor(C.lineD); surface.DrawOutlinedRect(0, 0, w, h)
	surface.SetDrawColor(C.panel); surface.DrawRect(2, 2, w - 4, 44)
	surface.SetDrawColor(C.line); surface.DrawRect(2, 46, w - 4, 2)
	draw.SimpleText("ГРАЖДАНСКАЯ ОБОРОНА · РЕДАКТОР НОВОСТЕЙ", "ixNewsHead", 14, 13, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

vgui.Register("ixGONewsEditor", PANEL, "DFrame")
