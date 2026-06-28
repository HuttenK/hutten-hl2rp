-- ============================================================
--  ОКНО ДОСЬЕ — стилистика "технологии Гражданской Обороны"
-- ============================================================

surface.CreateFont("ixDfvHeader", { font = "Tahoma", size = 21, weight = 800, antialias = true })
surface.CreateFont("ixDfvSub",    { font = "Consolas", size = 14, weight = 500, antialias = true })
surface.CreateFont("ixDfvName",   { font = "Tahoma", size = 27, weight = 800, antialias = true })
surface.CreateFont("ixDfvLabel",  { font = "Consolas", size = 13, weight = 600, antialias = true })
surface.CreateFont("ixDfvValue",  { font = "Consolas", size = 17, weight = 700, antialias = true })
surface.CreateFont("ixDfvMono",   { font = "Consolas", size = 14, weight = 500, antialias = true })
surface.CreateFont("ixDfvSmall",  { font = "Consolas", size = 12, weight = 500, antialias = true })

-- Палитра ГО
local C_BG      = Color(8, 12, 15, 248)
local C_PANEL   = Color(14, 20, 24, 255)
local C_LINE    = Color(0, 170, 210)
local C_LINE_D  = Color(0, 90, 115)
local C_TEXT    = Color(196, 214, 220)
local C_DIM     = Color(110, 140, 150)
local C_RED     = Color(210, 60, 50)
local C_AMBER   = Color(235, 170, 50)

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

local CAT = {
	union = { "ЗАМЕТКА",        Color(70, 150, 200) },
	civil = { "ГРАЖД. ЗАПИСЬ",  Color(220, 80, 70) },
	med   = { "МЕД. ЗАПИСЬ",    Color(80, 190, 110) },
	reg   = { "РЕГИСТРАЦИЯ",    Color(235, 190, 70) },
}

-- ---------- Захват фото (отдельный RT) ----------
local VIEW = ixDfvPhoto or {}
ixDfvPhoto = VIEW
VIEW.rt  = VIEW.rt or GetRenderTarget("ixDfViewPhoto", 256, 512)
VIEW.mat = VIEW.mat or CreateMaterial("__ixDfViewPhotoMat", "UnlitGeneric", {
	["$basetexture"] = "ixDfViewPhoto",
	["$noclamp"]     = "1",
	["$ignorez"]     = "1",
})
VIEW.ready   = false
VIEW.capture = false
VIEW.ent     = nil

local PHOTO_MODEL_POS = Vector(0, 0, -16000)
local PHOTO_CAM_POS   = PHOTO_MODEL_POS + Vector(0, 38, 58)
local PHOTO_CAM_ANG   = Angle(0, 270, 0)

local function StartPhoto(model, skin)
	VIEW.ready   = false
	VIEW.capture = false

	if IsValid(VIEW.ent) then VIEW.ent:Remove() VIEW.ent = nil end

	model = (isstring(model) and model != "") and model or "models/player/kleiner.mdl"

	local ent = ClientsideModel(model, RENDERGROUP_OPAQUE)
	if !IsValid(ent) then return end

	ent:SetPos(PHOTO_MODEL_POS)
	ent:SetAngles(Angle(0, 90, 0))
	ent:SetNoDraw(true)
	ent:SetSkin(skin or 0)

	for i = 0, ent:GetNumBodyGroups() - 1 do
		ent:SetBodygroup(i, 0)
	end

	local seq = ent:SelectWeightedSequence(ACT_IDLE)
	if !seq or seq < 0 then
		seq = ent:LookupSequence("idle_all_01")
		if seq < 0 then seq = ent:LookupSequence("idle") end
		if seq < 0 then seq = 0 end
	end
	ent:SetSequence(seq)
	ent:SetCycle(0)

	VIEW.ent = ent
	timer.Simple(0.25, function() VIEW.capture = true end)
end

hook.Add("PostRender", "ixDfViewPhotoCapture", function()
	if !VIEW.capture then return end
	if !IsValid(VIEW.ent) then VIEW.capture = false return end

	VIEW.capture = false

	render.PushRenderTarget(VIEW.rt)
		render.Clear(7, 14, 18, 255, true, true)
		cam.Start3D(PHOTO_CAM_POS, PHOTO_CAM_ANG, 30, 0, 0, 256, 512)
			render.SuppressEngineLighting(true)
			render.SetColorModulation(0.68, 0.92, 1.0)
			render.SetBlend(1)
			VIEW.ent:SetupBones()
			VIEW.ent:DrawModel()
			render.SuppressEngineLighting(false)
		cam.End3D()
	render.PopRenderTarget()

	if IsValid(VIEW.ent) then VIEW.ent:Remove() VIEW.ent = nil end
	VIEW.ready = true
end)

-- Рамка из угловых скобок
local function CornerBrackets(x, y, w, h, len, col)
	surface.SetDrawColor(col)
	-- верх-лево
	surface.DrawRect(x, y, len, 2)
	surface.DrawRect(x, y, 2, len)
	-- верх-право
	surface.DrawRect(x + w - len, y, len, 2)
	surface.DrawRect(x + w - 2, y, 2, len)
	-- низ-лево
	surface.DrawRect(x, y + h - 2, len, 2)
	surface.DrawRect(x, y + h - len, 2, len)
	-- низ-право
	surface.DrawRect(x + w - len, y + h - 2, len, 2)
	surface.DrawRect(x + w - 2, y + h - len, 2, len)
end

-- ============================================================
--  Одна запись досье
-- ============================================================

-- Разметка строки записи
local ROW_BODY_TOP = 26   -- где начинается текст записи (под тегом/датой)
local ROW_LINE_H   = 15   -- высота строки тела
local ROW_FOOTER   = 24   -- запас снизу под «~ автор» и очки

-- Перенос текста по РЕАЛЬНОЙ ширине пикселей выбранным шрифтом + учёт явных \n.
-- Возвращает массив готовых строк. Кириллица меряется корректно (в отличие от
-- старой оценки по #text, где байт != символ).
local function WrapRecordText(text, font, maxw)
	surface.SetFont(font)

	local lines = {}
	for _, para in ipairs(string.Explode("\n", tostring(text or ""))) do
		local line = ""
		for _, word in ipairs(string.Explode(" ", para)) do
			local test = (line == "") and word or (line .. " " .. word)
			if surface.GetTextSize(test) > maxw and line != "" then
				lines[#lines + 1] = line
				line = word
			else
				line = test
			end
		end
		lines[#lines + 1] = line -- сохраняем строку (в т.ч. пустую) — держит абзацы
	end

	return lines
end

local ROW = {}

function ROW:Init()
	self:Dock(TOP)
	self:DockMargin(0, 0, 0, 6)
	self:SetTall(54)
end

function ROW:Setup(rec)
	self.rec = rec
	local meta = CAT[rec.category] or { string.upper(tostring(rec.category or "?")), C_DIM }
	self.tag = meta[1]
	self.tagColor = meta[2]
	self.text = tostring(rec.text or "")
	self.poster = tostring(rec.poster_name or "—")
	self.date = rec.unix_time and os.date("%d.%m.%Y %H:%M", rec.unix_time) or ""
	self.points = tonumber(rec.points) or 0

	-- провизорная высота; точная считается в PerformLayout, когда известна ширина
	self.lines = nil
	self.lastWrapW = nil
	self:SetTall(50)
end

-- Считаем перенос по фактической ширине и подгоняем высоту строки, чтобы тело
-- не наезжало на нижнюю подпись («~ автор»/очки) и на соседние записи.
function ROW:PerformLayout(w, h)
	local maxw = w - 22
	if (self.lastWrapW == maxw) then return end -- защита от цикла SetTall->layout
	self.lastWrapW = maxw

	self.lines = WrapRecordText(self.text, "ixDfvMono", maxw)
	self:SetTall(ROW_BODY_TOP + #self.lines * ROW_LINE_H + ROW_FOOTER)
end

function ROW:Paint(w, h)
	surface.SetDrawColor(20, 27, 32, 255)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(self.tagColor.r, self.tagColor.g, self.tagColor.b, 255)
	surface.DrawRect(0, 0, 3, h)

	draw.SimpleText(self.tag, "ixDfvSmall", 12, 8, self.tagColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(self.date, "ixDfvSmall", w - 10, 8, C_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

	-- тело: заранее перенесённые строки (PerformLayout). Фолбэк — на случай
	-- отрисовки до первой раскладки.
	local lines = self.lines or WrapRecordText(self.text, "ixDfvMono", w - 22)
	local y = ROW_BODY_TOP
	for _, line in ipairs(lines) do
		draw.SimpleText(line, "ixDfvMono", 12, y, C_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + ROW_LINE_H
	end

	draw.SimpleText("~ " .. self.poster, "ixDfvSmall", 12, h - 16, C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	if self.points and self.points != 0 then
		local pc = self.points < 0 and C_RED or Color(120, 220, 90)
		draw.SimpleText((self.points > 0 and "+" or "") .. self.points, "ixDfvSmall",
			w - 10, h - 16, pc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	end
end

vgui.Register("ixDfvRecord", ROW, "DPanel")

-- ============================================================
--  Главное окно
-- ============================================================
local PANEL = {}

function PANEL:Init()
	self.startTime = SysTime()

	self:SetSize(740, 640)
	self:Center()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:MakePopup()
	self:SetDeleteOnClose(true)

	-- кнопка закрытия
	self.close = self:Add("DButton")
	self.close:SetText("")
	self.close:SetSize(26, 26)
	self.close.DoClick = function() self:Remove() end
	self.close.Paint = function(p, w, h)
		surface.SetDrawColor(p:IsHovered() and C_RED or C_LINE_D)
		surface.DrawRect(0, 0, w, h)
		draw.SimpleText("X", "ixDfvSub", w * 0.5, h * 0.5 - 1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- список записей
	self.scroll = self:Add("DScrollPanel")
	self.scroll:SetPos(20, 404)
	self.scroll:SetSize(700, 216)

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
	if IsValid(self.close) then
		self.close:SetPos(w - 34, 10)
	end
	if IsValid(self.scroll) then
		self.scroll:SetPos(20, 404)
		self.scroll:SetSize(w - 40, h - 404 - 18)
	end
end

function PANEL:SetData(payload)
	payload = payload or {}
	self.info = payload

	-- физописание: с карты, иначе строим у онлайн-владельца
	local desc = payload.genetic or ""
	if desc == "" and payload.ownerCharID then
		for _, ply in ipairs(player.GetAll()) do
			local c = ply:GetCharacter()
			if c and c:GetID() == payload.ownerCharID then
				local ok, res = pcall(function()
					local g = c:Genetic()
					return g and g.GetDesc and g:GetDesc() or ""
				end)
				if ok and isstring(res) then desc = res end
				break
			end
		end
	end
	self.desc = desc or ""

	StartPhoto(payload.model, payload.skin)

	-- заполнить записи
	self.scroll:Clear()
	for _, rec in ipairs(payload.records or {}) do
		local row = self.scroll:Add("ixDfvRecord")
		row:Setup(rec)
	end

	if #(payload.records or {}) == 0 then
		local lbl = self.scroll:Add("DLabel")
		lbl:Dock(TOP)
		lbl:SetTall(28)
		lbl:SetFont("ixDfvMono")
		lbl:SetTextColor(C_DIM)
		lbl:SetContentAlignment(5)
		lbl:SetText("// ЗАПИСИ ОТСУТСТВУЮТ")
	end
end

local function DrawScanlines(w, h)
	surface.SetDrawColor(0, 0, 0, 26)
	for y = 0, h, 3 do
		surface.DrawRect(0, y, w, 1)
	end
end

function PANEL:Paint(w, h)
	Derma_DrawBackgroundBlur(self, self.startTime)

	-- фон
	surface.SetDrawColor(C_BG)
	surface.DrawRect(0, 0, w, h)
	DrawScanlines(w, h)

	-- внешняя рамка
	surface.SetDrawColor(C_LINE_D)
	surface.DrawOutlinedRect(0, 0, w, h)
	CornerBrackets(0, 0, w, h, 16, C_LINE)

	-- шапка
	surface.SetDrawColor(C_PANEL)
	surface.DrawRect(2, 2, w - 4, 44)
	surface.SetDrawColor(C_LINE)
	surface.DrawRect(2, 46, w - 4, 2)
	draw.SimpleText("ГРАЖДАНСКАЯ ОБОРОНА", "ixDfvHeader", 16, 13, C_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText("// ЕДИНЫЙ АРХИВ ДОСЬЕ · ДОСТУП РАЗРЕШЁН", "ixDfvSmall", 16, 30, C_LINE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local info = self.info or {}

	-- ----- ФОТО -----
	local px, py, pw, ph = 20, 64, 210, 300
	surface.SetDrawColor(6, 10, 13, 255)
	surface.DrawRect(px, py, pw, ph)

	if VIEW.ready and VIEW.mat then
		surface.SetMaterial(VIEW.mat)
		surface.SetDrawColor(200, 225, 235, 255)
		surface.DrawTexturedRect(px, py, pw, ph)

		-- сканирующая полоса
		surface.SetDrawColor(0, 200, 255, 22)
		local sp = (CurTime() * 150) % (ph + 70)
		surface.DrawRect(px, py + sp - 70, pw, 70)
	else
		surface.SetDrawColor(0, 170, 210, 26)
		local sp = (CurTime() * 110) % (ph + 50)
		surface.DrawRect(px, py + sp - 50, pw, 50)
		draw.SimpleText("СКАНИРОВАНИЕ...", "ixDfvMono", px + pw * 0.5, py + ph * 0.5, C_LINE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	CornerBrackets(px, py, pw, ph, 14, C_LINE)
	draw.SimpleText("ИЗОБРАЖЕНИЕ СУБЪЕКТА", "ixDfvSmall", px + 4, py + ph + 4, C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- ----- ИНФО -----
	local ix0 = 250
	local y = 70

	draw.SimpleText(info.name ~= "" and info.name or "НЕИЗВЕСТНО", "ixDfvName", ix0, y, C_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	y = y + 34

	draw.SimpleText("ГР. №  " .. (info.cid ~= "" and info.cid or "—"), "ixDfvValue", ix0, y, C_LINE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	y = y + 22
	draw.SimpleText("РЕГ. №  " .. (info.regid ~= "" and info.regid or "—"), "ixDfvMono", ix0, y, C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	y = y + 24

	surface.SetDrawColor(C_LINE_D)
	surface.DrawRect(ix0, y, w - ix0 - 20, 1)
	y = y + 10

	-- физописание (перенос)
	draw.SimpleText("ФИЗ. ОПИСАНИЕ", "ixDfvLabel", ix0, y, C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	y = y + 16
	surface.SetFont("ixDfvMono")
	local maxw = w - ix0 - 24
	local line = ""
	for _, word in ipairs(string.Explode(" ", self.desc or "")) do
		local test = (line == "") and word or (line .. " " .. word)
		if surface.GetTextSize(test) > maxw and line != "" then
			draw.SimpleText(line, "ixDfvMono", ix0, y, C_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			y = y + 16
			line = word
		else
			line = test
		end
	end
	if line != "" then
		draw.SimpleText(line, "ixDfvMono", ix0, y, C_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		y = y + 16
	end
	y = y + 8

	-- лояльность
	local statusName = tostring(info.status or "Citizen")
	local sc = STATUS_COLOR[statusName] or C_TEXT
	draw.SimpleText("УРОВЕНЬ ЛОЯЛЬНОСТИ", "ixDfvLabel", ix0, y, C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	y = y + 16
	draw.SimpleText(string.upper(statusName), "ixDfvValue", ix0, y, sc, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	y = y + 24

	-- кредиты
	draw.SimpleText("СОЦИАЛЬНЫЕ КРЕДИТЫ", "ixDfvLabel", ix0, y, C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	y = y + 16
	local pts = tonumber(info.points) or 0
	local ptc = pts < 0 and C_RED or (pts > 0 and Color(120, 220, 90) or C_TEXT)
	draw.SimpleText(tostring(pts), "ixDfvValue", ix0, y, ptc, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	y = y + 26

	-- флаги
	if info.bol then
		surface.SetDrawColor(C_AMBER.r, C_AMBER.g, C_AMBER.b, 30)
		surface.DrawRect(ix0, y, 150, 20)
		draw.SimpleText("! ОРИЕНТИРОВКА", "ixDfvSmall", ix0 + 6, y + 4, C_AMBER, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end
	if info.restricted then
		surface.SetDrawColor(C_RED.r, C_RED.g, C_RED.b, 30)
		surface.DrawRect(ix0 + 160, y, 150, 20)
		draw.SimpleText("! ОГРАНИЧЕНО", "ixDfvSmall", ix0 + 166, y + 4, C_RED, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	-- заголовок журнала записей (опущен, чтобы не накладывался на подпись фото)
	draw.SimpleText("ЖУРНАЛ ЗАПИСЕЙ", "ixDfvLabel", 20, 388, C_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	surface.SetDrawColor(C_LINE_D)
	surface.DrawRect(150, 396, w - 170, 1)
end

vgui.Register("ixDatafileView", PANEL, "DFrame")
