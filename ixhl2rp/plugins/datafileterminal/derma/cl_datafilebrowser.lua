-- ============================================================
--  СПИСОК ДОСЬЕ — стилистика "технологии Гражданской Обороны"
-- ============================================================

surface.CreateFont("ixDfbTitle", { font = "Tahoma", size = 21, weight = 800, antialias = true })
surface.CreateFont("ixDfbName",  { font = "Tahoma", size = 18, weight = 700, antialias = true })
surface.CreateFont("ixDfbMono",  { font = "Consolas", size = 14, weight = 500, antialias = true })
surface.CreateFont("ixDfbSmall", { font = "Consolas", size = 12, weight = 500, antialias = true })

local C_BG     = Color(8, 12, 15, 248)
local C_PANEL  = Color(14, 20, 24, 255)
local C_ROW    = Color(18, 26, 31, 255)
local C_ROW_H  = Color(26, 40, 48, 255)
local C_LINE   = Color(0, 170, 210)
local C_LINE_D = Color(0, 90, 115)
local C_TEXT   = Color(196, 214, 220)
local C_DIM    = Color(110, 140, 150)

local STATUS_COLOR = {
	["Anti-Citizen"] = Color(190, 55, 50),
	["Citizen"]      = Color(185, 200, 210),
	["Black"]        = Color(120, 125, 135),
	["Brown"]        = Color(150, 110, 70),
	["Orange"]       = Color(230, 140, 40),
	["Red"]          = Color(230, 70, 60),
	["Green"]        = Color(80, 200, 110),
	["Blue"]         = Color(70, 140, 255),
	["White"]        = Color(235, 240, 245),
	["Gold"]         = Color(240, 200, 60),
	["Platinum"]     = Color(210, 190, 255),
}

local function CornerBrackets(x, y, w, h, len, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, len, 2)            surface.DrawRect(x, y, 2, len)
	surface.DrawRect(x + w - len, y, len, 2)  surface.DrawRect(x + w - 2, y, 2, len)
	surface.DrawRect(x, y + h - 2, len, 2)    surface.DrawRect(x, y + h - len, 2, len)
	surface.DrawRect(x + w - len, y + h - 2, len, 2)
	surface.DrawRect(x + w - 2, y + h - len, 2, len)
end

local PANEL = {}

function PANEL:Init()
	self.startTime = SysTime()

	self:SetSize(580, 660)
	self:Center()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:MakePopup()
	self:SetDeleteOnClose(true)

	self.data = {}
	self.count = 0

	self.close = self:Add("DButton")
	self.close:SetText("")
	self.close:SetSize(26, 26)
	self.close.DoClick = function() self:Remove() end
	self.close.Paint = function(p, w, h)
		surface.SetDrawColor(p:IsHovered() and Color(210, 60, 50) or C_LINE_D)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("X", "ixDfbMono", w * 0.5, h * 0.5 - 1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	self.search = self:Add("DTextEntry")
	self.search:SetTall(30)
	self.search:SetUpdateOnType(true)
	self.search:SetFont("ixDfbMono")
	if self.search.SetPlaceholderText then
		self.search:SetPlaceholderText("Поиск по имени или CID...")
	end
	self.search.OnValueChange = function(_, val) self:Rebuild(val) end
	self.search.Paint = function(p, w, h)
		surface.SetDrawColor(C_ROW)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(C_LINE)
		surface.DrawRect(0, h - 2, w, 2)
		p:DrawTextEntryText(C_TEXT, C_LINE, C_TEXT)
	end

	self.scroll = self:Add("DScrollPanel")
	local bar = self.scroll:GetVBar()
	bar:SetWide(6)
	bar.Paint = function() end
	bar.btnUp.Paint = function() end
	bar.btnDown.Paint = function() end
	bar.btnGrip.Paint = function(_, w, h)
		surface.SetDrawColor(C_LINE)
		surface.DrawRect(0, 0, w, h)
	end
end

function PANEL:PerformLayout(w, h)
	if IsValid(self.close) then self.close:SetPos(w - 34, 10) end
	if IsValid(self.search) then
		self.search:SetPos(16, 54)
		self.search:SetWide(w - 32)
	end
	if IsValid(self.scroll) then
		self.scroll:SetPos(16, 92)
		self.scroll:SetSize(w - 32, h - 92 - 16)
	end
end

function PANEL:SetList(list)
	self.data = list or {}
	self:Rebuild("")
end

local function norm(s)
	return tostring(s or ""):lower():gsub("[%- ]", "")
end

function PANEL:Rebuild(filter)
	if !IsValid(self.scroll) then return end
	self.scroll:Clear()

	filter = tostring(filter or ""):lower()
	local fnorm = norm(filter)
	local shown = 0

	for _, v in ipairs(self.data) do
		local pass = true
		if filter != "" then
			local nameMatch = tostring(v.name):lower():find(filter, 1, true)
			local cidMatch  = norm(v.cid):find(fnorm, 1, true)
			pass = (nameMatch or cidMatch) and true or false
		end
		if pass then
			shown = shown + 1
			self:AddRow(v)
		end
	end

	self.count = shown

	if shown == 0 then
		local lbl = self.scroll:Add("DLabel")
		lbl:Dock(TOP)
		lbl:DockMargin(0, 12, 0, 0)
		lbl:SetTall(28)
		lbl:SetFont("ixDfbMono")
		lbl:SetTextColor(C_DIM)
		lbl:SetContentAlignment(5)
		lbl:SetText("// СОВПАДЕНИЙ НЕТ")
	end
end

function PANEL:AddRow(v)
	local row = self.scroll:Add("DButton")
	row:Dock(TOP)
	row:DockMargin(0, 0, 6, 6)
	row:SetTall(52)
	row:SetText("")
	row.hov = 0

	row.DoClick = function()
		surface.PlaySound("buttons/button14.wav")
		netstream.Start("ixDfBrowserSelect", v.id)
	end

	row.Paint = function(p, w, h)
		row.hov = Lerp(FrameTime() * 12, row.hov, p:IsHovered() and 1 or 0)
		surface.SetDrawColor(
			Lerp(row.hov, C_ROW.r, C_ROW_H.r),
			Lerp(row.hov, C_ROW.g, C_ROW_H.g),
			Lerp(row.hov, C_ROW.b, C_ROW_H.b), 255)
		surface.DrawRect(0, 0, w, h)

		local sc = STATUS_COLOR[tostring(v.status)] or C_LINE
		surface.SetDrawColor(sc)
		surface.DrawRect(0, 0, 3, h)

		if row.hov > 0.05 then
			surface.SetDrawColor(C_LINE.r, C_LINE.g, C_LINE.b, math.floor(row.hov * 90))
			surface.DrawOutlinedRect(0, 0, w, h)
		end

		draw.SimpleText(v.name ~= "" and v.name or "Без имени", "ixDfbName", 14, 9, C_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		draw.SimpleText("ГР. № " .. (v.cid ~= "" and v.cid or "—"), "ixDfbSmall", 14, 31, C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

		draw.SimpleText(string.upper(tostring(v.status or "")), "ixDfbSmall", w - 12, 12, sc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		draw.SimpleText("Кредиты: " .. tostring(v.points or 0), "ixDfbSmall", w - 12, 31, C_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end
end

function PANEL:Paint(w, h)
	Derma_DrawBackgroundBlur(self, self.startTime)

	surface.SetDrawColor(C_BG)
	surface.DrawRect(0, 0, w, h)

	-- scanlines
	surface.SetDrawColor(0, 0, 0, 26)
	for y = 0, h, 3 do surface.DrawRect(0, y, w, 1) end

	surface.SetDrawColor(C_LINE_D)
	surface.DrawOutlinedRect(0, 0, w, h)
	CornerBrackets(0, 0, w, h, 16, C_LINE)

	surface.SetDrawColor(C_PANEL)
	surface.DrawRect(2, 2, w - 4, 44)
	surface.SetDrawColor(C_LINE)
	surface.DrawRect(2, 46, w - 4, 2)

	draw.SimpleText("БАЗА ДАННЫХ ДОСЬЕ", "ixDfbTitle", 16, 13, C_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText("// ГРАЖДАНСКАЯ ОБОРОНА", "ixDfbSmall", 16, 31, C_LINE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText("ЗАПИСЕЙ: " .. (self.count or 0), "ixDfbSmall", w - 44, 20, C_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
end

vgui.Register("ixDatafileBrowser", PANEL, "DFrame")
