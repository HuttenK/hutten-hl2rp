-- Полная статья — обычное окно-попап (надёжно рендерит текст и изображения).
local function P() return ix.plugin.list["gonews"] end

local FRAME_W, FRAME_H = 720, 580
local CONTENT_W = FRAME_W - 48

local PANEL = {}

function PANEL:Init()
	self.startTime = SysTime()

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
		surface.SetDrawColor(s:IsHovered() and C.red or C.lineD)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("X", "ixNewsSmall", w * 0.5, h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	self.scroll = self:Add("DScrollPanel")
	local bar = self.scroll:GetVBar()
	bar:SetWide(8)
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h)
		surface.SetDrawColor(C.line); surface.DrawRect(0, 0, w, h)
	end
end

function PANEL:PerformLayout(w, h)
	if IsValid(self.close) then self.close:SetPos(w - 34, 10) end
	if IsValid(self.scroll) then
		self.scroll:SetPos(20, 92)
		self.scroll:SetSize(w - 40, h - 92 - 16)
	end
end

function PANEL:SetArticle(id)
	self.id = id
	self:Refresh()
end

function PANEL:Refresh()
	local entry = P():GetNewsByID(self.id)
	if !entry then self:Remove() return end
	self.entry = entry

	if !IsValid(self.scroll) then return end
	self.scroll:Clear()

	local C = P().Colors

	-- Изображение
	if isstring(entry.image) and entry.image != "" then
		if entry.imageType == "url" then
			local html = self.scroll:Add("DHTML")
			html:Dock(TOP)
			html:DockMargin(0, 0, 0, 12)
			html:SetTall(320)
			html:SetMouseInputEnabled(false)
			html:SetHTML([[<html><body style="margin:0;padding:0;background:#0a1014;display:flex;align-items:center;justify-content:center;height:320px;overflow:hidden;"><img src="]] ..
				entry.image ..
				[[" style="max-width:100%;max-height:320px;object-fit:contain;"></body></html>]])
		else
			local mat = Material(entry.image, "smooth")
			local img = self.scroll:Add("DPanel")
			img:Dock(TOP)
			img:DockMargin(0, 0, 0, 12)
			img:SetTall(320)
			img.Paint = function(_, w, h)
				surface.SetDrawColor(6, 10, 13, 255)
				surface.DrawRect(0, 0, w, h)
				if mat and !mat:IsError() then
					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(mat)
					surface.DrawTexturedRect(0, 0, w, h)
				else
					draw.SimpleText("[ИЗОБРАЖЕНИЕ НЕДОСТУПНО]", "ixNewsSmall", w * 0.5, h * 0.5, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
			end
		end
	end

	-- Текст статьи
	local lines = P():WrapText(entry.text, "ixNewsBody", CONTENT_W - 8)
	local lineH = 22

	local body = self.scroll:Add("DPanel")
	body:Dock(TOP)
	body:SetTall(#lines * lineH + 12)
	body.Paint = function(_, w, h)
		for i, line in ipairs(lines) do
			draw.SimpleText(line, "ixNewsBody", 4, (i - 1) * lineH, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end
end

local function DrawScanlines(w, h)
	surface.SetDrawColor(0, 0, 0, 24)
	for y = 0, h, 3 do surface.DrawRect(0, y, w, 1) end
end

function PANEL:Paint(w, h)
	local C = P().Colors

	Derma_DrawBackgroundBlur(self, self.startTime)

	surface.SetDrawColor(C.bg)
	surface.DrawRect(0, 0, w, h)
	DrawScanlines(w, h)

	surface.SetDrawColor(C.lineD)
	surface.DrawOutlinedRect(0, 0, w, h)

	surface.SetDrawColor(C.panel)
	surface.DrawRect(2, 2, w - 4, 80)
	surface.SetDrawColor(C.line)
	surface.DrawRect(2, 84, w - 4, 2)

	local entry = self.entry
	if entry then
		draw.SimpleText(entry.title or "—", "ixNewsTitle", 16, 12, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		local meta = string.format("%s · %s · %s",
			entry.source or "ГО",
			os.date("%d.%m.%Y %H:%M", entry.time or os.time()),
			entry.author or "")
		draw.SimpleText(meta, "ixNewsSmall", 16, 52, C.line, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
end

vgui.Register("ixGONewsArticle", PANEL, "DFrame")
