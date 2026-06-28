-- Экран читалки новостей (3D2D на мониторе). Стиль — citizen terminal:
-- комбайновская палитра, анимированный фон, сканлайн, бегущая строка.
-- Список и полная статья открываются прямо на экране. Прокрутка — кнопками ▲/▼.

local SCREEN_W, SCREEN_H = 600, 360
local TICKER_H = 24
-- Отступ снизу: лента (и привязанные к ней кнопки) поднята над нижней рамкой
-- монитора, иначе текст уходил под бортик экрана. Увеличь, чтобы поднять выше.
local TICKER_GAP = 8
local TICKER_Y = SCREEN_H - TICKER_H - TICKER_GAP -- верх бегущей строки

local function P() return ix.plugin.list["gonews"] end

local function pal(name, fb)
	return (ix.Palette and ix.Palette[name]) or fb
end
local CLR_BLUE   = pal("combineblue",   Color(32, 225, 255))
local CLR_GREEN  = pal("combinegreen",  Color(60, 200, 130))
local CLR_YELLOW = pal("combineyellow", Color(231, 200, 60))
local CLR_RED    = pal("combinered",    Color(210, 60, 50))
local CLR_BLACK  = pal("black",         Color(8, 12, 15))
local CLR_TEXT   = Color(200, 235, 245)
local CLR_DIM    = Color(120, 160, 175)

local MAT_ANIM = Material("autonomous/ui/terminal/cmb_bg_animated")
local MAT_BG   = Material("autonomous/ui/terminal/bg.png")

-- Размер области картинки (под него же делаем HTML-канвас, чтобы не было двойного letterbox)
local IMG_X, IMG_Y = 18, 66
local IMG_W, IMG_H = SCREEN_W - 36, 178

-- ===== Кэш URL-изображений (рендер HTML -> материал для 3D2D) =====
local URLImg = {}
local function GetURLImageMat(url)
	local e = URLImg[url]
	if !e then
		e = {}
		e.html = vgui.Create("DHTML")
		e.html:SetSize(IMG_W, IMG_H)
		e.html:SetVisible(false)
		e.html:SetHTML([[<html><body style="margin:0;padding:0;overflow:hidden;background:#0a1014;display:flex;align-items:center;justify-content:center;height:]] ..
			IMG_H .. [[px;"><img src="]] .. url ..
			[[" style="max-width:100%;max-height:100%;object-fit:contain;"></body></html>]])
		URLImg[url] = e
	end
	if IsValid(e.html) then
		e.html:UpdateHTMLTexture()
		e.mat = e.html:GetHTMLMaterial()
	end
	return e.mat
end

-- Рисует материал, вписывая по соотношению сторон в область (центрировано)
local function DrawFitted(mat, ax, ay, aw, ah)
	local mw = mat:Width()
	local mh = mat:Height()
	if !mw or mw <= 0 then mw = aw end
	if !mh or mh <= 0 then mh = ah end

	local scale = math.min(aw / mw, ah / mh)
	local dw, dh = mw * scale, mh * scale
	local dx = ax + (aw - dw) * 0.5
	local dy = ay + (ah - dh) * 0.5

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(mat)
	surface.DrawTexturedRect(dx, dy, dw, dh)
end

-- ===== Бегущая строка через RenderTarget =====
-- Paint3D2D НЕ обрезает по границам панели, поэтому длинный текст вылезал за
-- края монитора. Рисуем строку в RT (там отсечка по размеру RT), затем
-- показываем нужный кусок RT на ленте — текст обрезается ровно по краю экрана.
-- RT обновляем в PANEL:Think (вне 3D2D), один раз за кадр на всех терминалах.
local TICKER_RT_W, TICKER_RT_H = 1024, 32
local TICKER_RT  = GetRenderTarget("ixGoNewsTickerRT", TICKER_RT_W, TICKER_RT_H)
local TICKER_MAT = CreateMaterial("ixGoNewsTickerMat", "UnlitGeneric", {
	["$basetexture"] = "ixGoNewsTickerRT",
	["$translucent"] = "1",
	["$vertexalpha"] = "1",
})
local tickerFrame = -1

local function UpdateTickerRT()
	if tickerFrame == FrameNumber() then return end
	tickerFrame = FrameNumber()

	local news = P():GetNews()
	local text = "ГРАЖДАНСКАЯ ОБОРОНА :: ЕДИНАЯ ИНФОРМАЦИОННАЯ СЕТЬ :: "
	for _, v in ipairs(news) do
		text = text .. (v.title or "") .. "     ::     "
	end

	render.PushRenderTarget(TICKER_RT)
		render.Clear(0, 0, 0, 0, true, false)
		cam.Start2D()
			surface.SetFont("ixNewsCmbTick")
			surface.SetTextColor(10, 12, 14)
			local tw = surface.GetTextSize(text)
			if tw > 0 then
				-- Начинаем на одну ширину текста ЛЕВЕЕ: иначе слева оставался пустой
				-- зазор (0..x), и строка будто исчезала, не дойдя до края. Так копии
				-- покрывают всю ленту бесшовно, заходя за левый край.
				local x = -(RealTime() * 70) % tw - tw
				while x < SCREEN_W do
					surface.SetTextPos(x, 5)
					surface.DrawText(text)
					x = x + tw
				end
			end
		cam.End2D()
	render.PopRenderTarget()
end

local PANEL = {}

function PANEL:Think()
	-- Обновляем RT ленты вне контекста 3D2D (безопасно для PushRenderTarget).
	UpdateTickerRT()
end

function PANEL:Init()
	self:SetSize(SCREEN_W, SCREEN_H)
	self.mode = "list"
	self.listScroll = 0
	self.artScroll = 0
	self:BuildList()
end

function PANEL:Refresh()
	if self.mode == "list" then self:BuildList() end
end

function PANEL:SetMode(mode)
	self.mode = mode
	self:Clear()
	if mode == "list" then self:BuildList() else self:BuildArticle() end
end

-- ===================== СПИСОК =====================
function PANEL:BuildList()
	self:Clear()

	local news = P():GetNews()
	local rowH = 50
	local listY = 44
	local listH = TICKER_Y - listY - 12
	local visible = math.floor(listH / rowH)

	local maxScroll = math.max(0, #news - visible)
	self.listScroll = math.Clamp(self.listScroll, 0, maxScroll)

	for i = 0, visible - 1 do
		local entry = news[self.listScroll + i + 1]
		if !entry then break end

		local row = self:Add("DButton")
		row:SetText("")
		row:SetSize(SCREEN_W - 60, rowH - 6)
		row:SetPos(16, listY + i * rowH)
		row.DoClick = function()
			surface.PlaySound("buttons/button14.wav")
			self.article = entry
			self.artScroll = 0
			self:SetMode("article")
		end
		row.Paint = function(s, w, h)
			local hover = s.Hovered
			surface.SetDrawColor(hover and Color(22, 40, 48, 230) or Color(14, 24, 30, 200))
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(hover and CLR_GREEN or CLR_BLUE)
			surface.DrawRect(0, 0, 3, h)
			draw.SimpleText(entry.title or "—", "ixNewsCmbItem", 12, 8, CLR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			local meta = string.format("%s  ::  %s", entry.source or "ГО", os.date("%d.%m.%Y", entry.time or os.time()))
			draw.SimpleText(meta, "ixNewsCmbSmall", 12, 28, CLR_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			draw.SimpleText(hover and "► ОТКРЫТЬ" or "ОТКРЫТЬ", "ixNewsCmbSmall", w - 10, h * 0.5, CLR_GREEN, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		end
	end

	self:MakeScrollButtons(function() return self.listScroll > 0 end,
		function() return self.listScroll < maxScroll end,
		function() self.listScroll = math.max(0, self.listScroll - 1); self:BuildList() end,
		function() self.listScroll = math.min(maxScroll, self.listScroll + 1); self:BuildList() end)

	self:MakeTicker()
end

-- ===================== СТАТЬЯ =====================
function PANEL:BuildArticle()
	self:Clear()

	-- Назад (над бегущей строкой)
	local back = self:Add("DButton")
	back:SetText("")
	back:SetSize(120, 26)
	back:SetPos(16, TICKER_Y - 32)
	back.DoClick = function()
		surface.PlaySound("buttons/button14.wav")
		self:SetMode("list")
	end
	back.Paint = function(s, w, h)
		surface.SetDrawColor(s.Hovered and Color(22, 40, 48) or Color(14, 24, 30)); surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(CLR_BLUE); surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("◄ К СПИСКУ", "ixNewsCmbSmall", w * 0.5, h * 0.5, CLR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local entry = self.article
	if entry then
		local hasImg = isstring(entry.image) and entry.image != ""
		local textTop = hasImg and (IMG_Y + IMG_H + 12) or 70
		local textBottom = TICKER_Y - 40
		local lineH = 20
		self.artLines = P():WrapText(entry.text, "ixNewsCmbBody", SCREEN_W - 60)
		self.artVisible = math.max(1, math.floor((textBottom - textTop) / lineH))
		self.artTextTop = textTop
		self.artLineH = lineH

		local maxScroll = math.max(0, #self.artLines - self.artVisible)
		self.artScroll = math.Clamp(self.artScroll, 0, maxScroll)

		self:MakeScrollButtons(function() return self.artScroll > 0 end,
			function() return self.artScroll < maxScroll end,
			function() self.artScroll = math.max(0, self.artScroll - 2); self:BuildArticle() end,
			function() self.artScroll = math.min(maxScroll, self.artScroll + 2); self:BuildArticle() end)
	end

	self:MakeTicker()
end

function PANEL:MakeScrollButtons(canUp, canDown, onUp, onDown)
	local bx = SCREEN_W - 34
	local up = self:Add("DButton")
	up:SetText(""); up:SetSize(26, 26); up:SetPos(bx, 44)
	up.DoClick = function() if canUp() then surface.PlaySound("common/talk.wav") onUp() end end
	up.Paint = function(s, w, h)
		local on = canUp()
		surface.SetDrawColor(s.Hovered and on and Color(22,40,48) or Color(14,24,30)); surface.DrawRect(0,0,w,h)
		surface.SetDrawColor(on and CLR_BLUE or Color(40,50,55)); surface.DrawOutlinedRect(0,0,w,h)
		draw.SimpleText("▲", "ixNewsCmbSmall", w*0.5, h*0.5, on and CLR_TEXT or Color(60,70,75), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	local down = self:Add("DButton")
	down:SetText(""); down:SetSize(26, 26); down:SetPos(bx, TICKER_Y - 42)
	down.DoClick = function() if canDown() then surface.PlaySound("common/talk.wav") onDown() end end
	down.Paint = function(s, w, h)
		local on = canDown()
		surface.SetDrawColor(s.Hovered and on and Color(22,40,48) or Color(14,24,30)); surface.DrawRect(0,0,w,h)
		surface.SetDrawColor(on and CLR_BLUE or Color(40,50,55)); surface.DrawOutlinedRect(0,0,w,h)
		draw.SimpleText("▼", "ixNewsCmbSmall", w*0.5, h*0.5, on and CLR_TEXT or Color(60,70,75), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

-- Бегущая строка как ДОЧЕРНЯЯ панель — обрезается по своим границам
function PANEL:MakeTicker()
	local t = self:Add("DPanel")
	t:SetSize(SCREEN_W, TICKER_H)
	t:SetPos(0, TICKER_Y)
	t.Paint = function(_, w, h)
		surface.SetDrawColor(CLR_YELLOW)
		surface.DrawRect(0, 0, w, h)

		-- Текст ленты берём из RT (обрезан по ширине экрана — за край не вылезает).
		surface.SetMaterial(TICKER_MAT)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, SCREEN_W / TICKER_RT_W, TICKER_H / TICKER_RT_H)
	end
end

-- ===================== ОТРИСОВКА =====================
local function DrawBackground(w, h)
	surface.SetDrawColor(CLR_BLACK.r, CLR_BLACK.g, CLR_BLACK.b, 255)
	surface.DrawRect(0, 0, w, h)

	if MAT_BG and !MAT_BG:IsError() then
		surface.SetDrawColor(255, 255, 255, 40)
		surface.SetMaterial(MAT_BG)
		surface.DrawTexturedRect(0, 0, w, h)
	end
	if MAT_ANIM and !MAT_ANIM:IsError() then
		render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE, BLENDFUNC_ADD)
			surface.SetMaterial(MAT_ANIM)
			surface.SetDrawColor(255, 255, 255, 60)
			surface.DrawTexturedRect(0, 0, w, h)
		render.OverrideBlend(false)
	end

	surface.SetDrawColor(0, 0, 0, 40)
	for y = 0, h, 3 do surface.DrawRect(0, y, w, 1) end
end

function PANEL:Paint(w, h)
	DrawBackground(w, h)

	local title = (self.mode == "article" and self.article) and self.article.title or "НОВОСТНАЯ СВОДКА ГО"
	surface.SetDrawColor(CLR_BLUE)
	surface.DrawRect(16, 34, w - 32, 1)
	draw.SimpleText(":: " .. string.upper(tostring(title)) .. " ::", "ixNewsCmbHead", 18, 9, CLR_BLUE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	if self.mode == "article" and self.article then
		self:PaintArticle(w, h)
	elseif #P():GetNews() == 0 then
		draw.SimpleText("// НЕТ АКТИВНЫХ СВОДОК", "ixNewsCmbBody", w * 0.5, h * 0.5, CLR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	-- Световая полоса-«скан»: держим строго в пределах экрана (3D2D не обрезает,
	-- иначе полоса вылезает над верхом и под низом монитора).
	local band = 60
	local top  = (CurTime() * 90) % (h + band) - band -- от -band до h
	local y1   = math.max(0, top)
	local y2   = math.min(h, top + band)
	if y2 > y1 then
		surface.SetDrawColor(CLR_GREEN.r, CLR_GREEN.g, CLR_GREEN.b, 14)
		surface.DrawRect(0, y1, w, y2 - y1)
	end

	surface.SetDrawColor(CLR_BLUE.r, CLR_BLUE.g, CLR_BLUE.b, 180)
	surface.DrawOutlinedRect(0, 0, w, h)
end

function PANEL:PaintArticle(w, h)
	local entry = self.article

	local meta = string.format("%s  ::  %s  ::  %s",
		entry.source or "ГО",
		os.date("%d.%m.%Y %H:%M", entry.time or os.time()),
		entry.author or "")
	draw.SimpleText(meta, "ixNewsCmbSmall", 18, 46, CLR_GREEN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- изображение (вписано по соотношению сторон)
	if isstring(entry.image) and entry.image != "" then
		surface.SetDrawColor(4, 8, 11, 255)
		surface.DrawRect(IMG_X, IMG_Y, IMG_W, IMG_H)

		local mat
		if entry.imageType == "url" then
			mat = GetURLImageMat(entry.image)
		else
			local m = Material(entry.image, "smooth")
			if m and !m:IsError() then mat = m end
		end

		if mat then
			DrawFitted(mat, IMG_X, IMG_Y, IMG_W, IMG_H)
		else
			draw.SimpleText(entry.imageType == "url" and "ЗАГРУЗКА ИЗОБРАЖЕНИЯ..." or "[ИЗОБРАЖЕНИЕ НЕДОСТУПНО]",
				"ixNewsCmbSmall", IMG_X + IMG_W * 0.5, IMG_Y + IMG_H * 0.5, CLR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		surface.SetDrawColor(CLR_BLUE.r, CLR_BLUE.g, CLR_BLUE.b, 150)
		surface.DrawOutlinedRect(IMG_X, IMG_Y, IMG_W, IMG_H)
	end

	-- текст с прокруткой
	local lines = self.artLines or {}
	local top = self.artTextTop or 70
	local lineH = self.artLineH or 20
	local vis = self.artVisible or 6

	for i = 1, vis do
		local line = lines[self.artScroll + i]
		if !line then break end
		draw.SimpleText(line, "ixNewsCmbBody", 18, top + (i - 1) * lineH, CLR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	if #lines > vis then
		draw.SimpleText(string.format("%d-%d / %d", self.artScroll + 1, math.min(self.artScroll + vis, #lines), #lines),
			"ixNewsCmbSmall", w - 44, TICKER_Y - 18, CLR_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("ixGONewsScreen", PANEL, "DPanel")
