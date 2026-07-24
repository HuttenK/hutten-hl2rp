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

-- Длинный заголовок в списке налезал на кнопку «ОТКРЫТЬ» и уходил за край экрана.
-- Режем не по числу символов (широкие буквы не влезают там, где влезают узкие), а
-- по реальной ширине текста, и добавляем многоточие. В открытой статье заголовок
-- показывается целиком.
--
-- utf8sub — потому что заголовки кириллические, а string.sub режет байты и может
-- разорвать символ пополам.
local TITLE_RESERVED = 96   -- место справа под кнопку «► ОТКРЫТЬ» в списке
local HEADER_RESERVED = 200 -- место справа под «:: ГОРОДСКОЙ ТЕРМИНАЛ ::» и иконку

-- Шапка открытой статьи: заголовок показывается ЦЕЛИКОМ, при нехватке ширины
-- переносится на вторую строку. Больше двух строк не даём — иначе шапка съедает
-- экран; такой заголовок обрезается многоточием.
local HEADER_LINE_H = 22
local HEADER_MAX_LINES = 2

local function ClipTitle(text, font, maxWidth)
	text = tostring(text or "—")

	surface.SetFont(font)

	if surface.GetTextSize(text) <= maxWidth then
		return text
	end

	local dots = "..."
	local dotsWidth = surface.GetTextSize(dots)
	local length = utf8.len(text) or #text

	-- Отрезаем по одному символу, пока строка с многоточием не влезет.
	for i = length - 1, 1, -1 do
		local clipped = string.utf8sub(text, 1, i)

		if surface.GetTextSize(clipped) + dotsWidth <= maxWidth then
			return clipped .. dots
		end
	end

	return dots
end

-- Разбивает заголовок статьи по словам на строки, влезающие в maxWidth.
-- Обрамление «:: ::» приклеивается к первой и последней строке.
local function WrapHeaderTitle(text, font, maxWidth)
	text = string.upper(tostring(text or "—"))

	surface.SetFont(font)

	if surface.GetTextSize(text) <= maxWidth then
		return {text}
	end

	local lines = {}
	local current

	for word in string.gmatch(text, "%S+") do
		local candidate = current and (current .. " " .. word) or word

		if surface.GetTextSize(candidate) <= maxWidth then
			current = candidate
		else
			if current then
				lines[#lines + 1] = current
			end

			-- Одно слово шире строки — режем его само по себе.
			current = surface.GetTextSize(word) <= maxWidth and word or ClipTitle(word, font, maxWidth)
		end

		if #lines >= HEADER_MAX_LINES then break end
	end

	if current and #lines < HEADER_MAX_LINES then
		lines[#lines + 1] = current
	end

	-- Если текст не поместился в отведённые строки, последнюю закрываем многоточием.
	local used = table.concat(lines, " ")

	if utf8.len(used) < utf8.len(text) then
		local last = lines[#lines]

		lines[#lines] = ClipTitle(last .. " ...", font, maxWidth)
	end

	return lines
end

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

-- Размер области картинки (под него же делаем HTML-канвас, чтобы не было двойного letterbox).
-- Высота ~ по 16:9 от ширины: типовые (широкоформатные) изображения заполняют всю
-- ширину, а не жмутся по бокам. Картинка теперь в конце прокручиваемого потока, так
-- что она может быть выше окна просмотра — её целиком видно прокруткой.
local IMG_X, IMG_Y = 18, 66
local IMG_W = SCREEN_W - 36
local IMG_H = math.floor(IMG_W * 9 / 16)

-- ===== RT для тела статьи (текст + картинка одним прокручиваемым потоком) =====
-- Paint3D2D НЕ обрезает по границам панели, поэтому длинный текст/картинка вылезали
-- за края монитора. Рисуем всё тело статьи (сначала текст, затем картинку внизу) в
-- RT — там отсечка по размеру RT, — и показываем на экране только видимый срез,
-- сдвигая по пикселям. RT обновляем в PANEL:Think (вне 3D2D, безопасно для
-- PushRenderTarget). RT персональный на панель (из небольшого пула имён), чтобы
-- два близких терминала с разными статьями не мешали друг другу.
local ART_RT_W, ART_RT_H = 1024, 256
local ART_RT_POOL = 6
local artRTCounter = 0

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

-- Материал изображения статьи (URL -> отрендеренный HTML-материал, либо локальный).
local function ResolveImageMat(entry)
	if entry.imageType == "url" then
		return GetURLImageMat(entry.image)
	end

	local m = Material(entry.image, "smooth")
	if m and !m:IsError() then return m end
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
	-- И RT тела статьи — тоже вне 3D2D.
	self:UpdateArticleRT()
end

function PANEL:Init()
	self:SetSize(SCREEN_W, SCREEN_H)
	self.mode = "list"
	self.listScroll = 0
	self.artScrollPx = 0

	-- Персональный RT тела статьи из пула имён (см. коммент у ART_RT_*).
	artRTCounter = artRTCounter + 1
	local slot = artRTCounter % ART_RT_POOL
	self.artRT  = GetRenderTarget("ixGoNewsArtRT_" .. slot, ART_RT_W, ART_RT_H)
	self.artMat = CreateMaterial("ixGoNewsArtMat_" .. slot, "UnlitGeneric", {
		["$basetexture"] = "ixGoNewsArtRT_" .. slot,
		["$translucent"] = "1",
		["$vertexalpha"] = "1",
	})

	self:BuildList()
end

-- Рендер тела статьи в персональный RT: сначала весь текст, затем картинка снизу,
-- всё сдвинуто на artScrollPx. RT обрезает по своему размеру, поэтому за границы
-- видимой области (и монитора) ничего не вылезает. Зовётся из Think (не из 3D2D).
function PANEL:UpdateArticleRT()
	if self.mode != "article" or !self.article or !self.artRT then return end

	local lines    = self.artLines or {}
	local lineH    = self.artLineH or 20
	local scroll   = self.artScrollPx or 0
	local viewH    = self.artViewportH or 200

	render.PushRenderTarget(self.artRT)
		render.Clear(0, 0, 0, 0, true, false)
		cam.Start2D()
			-- Текст (рисуем только строки, попадающие в видимое окно).
			for i, line in ipairs(lines) do
				local y = (i - 1) * lineH - scroll
				if y > -lineH and y < viewH then
					draw.SimpleText(line, "ixNewsCmbBody", 18, y, CLR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
				end
			end

			-- Картинка — ПОСЛЕ текста, у самого низа потока.
			if self.artHasImg then
				local iy = (self.artImgTop or 0) - scroll
				if iy + IMG_H > 0 and iy < viewH then
					surface.SetDrawColor(4, 8, 11, 255)
					surface.DrawRect(IMG_X, iy, IMG_W, IMG_H)

					local mat = ResolveImageMat(self.article)
					if mat then
						DrawFitted(mat, IMG_X, iy, IMG_W, IMG_H)
					else
						draw.SimpleText(self.article.imageType == "url" and "ЗАГРУЗКА ИЗОБРАЖЕНИЯ..." or "[ИЗОБРАЖЕНИЕ НЕДОСТУПНО]",
							"ixNewsCmbSmall", IMG_X + IMG_W * 0.5, iy + IMG_H * 0.5, CLR_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					end

					surface.SetDrawColor(CLR_BLUE.r, CLR_BLUE.g, CLR_BLUE.b, 150)
					surface.DrawOutlinedRect(IMG_X, iy, IMG_W, IMG_H)
				end
			end
		cam.End2D()
	render.PopRenderTarget()
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
			self.artScrollPx = 0
			self:SetMode("article")
		end
		row.Paint = function(s, w, h)
			local hover = s.Hovered
			surface.SetDrawColor(hover and Color(22, 40, 48, 230) or Color(14, 24, 30, 200))
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(hover and CLR_GREEN or CLR_BLUE)
			surface.DrawRect(0, 0, 3, h)
			draw.SimpleText(ClipTitle(entry.title, "ixNewsCmbItem", w - 12 - TITLE_RESERVED), "ixNewsCmbItem", 12, 8, CLR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
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
		-- Двухстрочный заголовок опускает область содержимого.
		local extra   = self:GetHeaderOffset()
		local lineH   = 20
		-- Содержимое (текст, затем картинка) идёт под мета-строкой; низ — над лентой.
		local contentTop    = 66 + extra
		local contentBottom = TICKER_Y - 40
		local viewH   = math.max(lineH, contentBottom - contentTop)

		self.artLines     = P():WrapText(entry.text, "ixNewsCmbBody", SCREEN_W - 60)
		self.artLineH     = lineH
		self.artContentTop = contentTop
		self.artViewportH  = viewH
		self.artHasImg     = hasImg

		-- Полная высота потока: текст -> зазор -> картинка.
		local textH  = #self.artLines * lineH
		local imgGap = hasImg and 16 or 0
		self.artImgTop = textH + imgGap
		local totalH   = textH + imgGap + (hasImg and IMG_H or 0)

		local maxScroll = math.max(0, totalH - viewH)
		self.artScrollPx = math.Clamp(self.artScrollPx or 0, 0, maxScroll)
		self.artMaxScrollPx = maxScroll

		local step = lineH * 2
		self:MakeScrollButtons(function() return self.artScrollPx > 0 end,
			function() return self.artScrollPx < maxScroll end,
			function() self.artScrollPx = math.max(0, self.artScrollPx - step); self:BuildArticle() end,
			function() self.artScrollPx = math.min(maxScroll, self.artScrollPx + step); self:BuildArticle() end)
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

-- Строки заголовка шапки: в списке — статичная надпись, в статье — её заголовок.
-- Paint зовётся каждый кадр, поэтому разбивку кэшируем по самому заголовку.
function PANEL:GetHeaderLines()
	if self.mode != "article" or !self.article then
		return {"НОВОСТНАЯ СВОДКА ГО"}
	end

	local title = self.article.title

	if self.headerCacheKey != title then
		surface.SetFont("ixNewsCmbHead")

		-- Первая строка начинается с «:: », последняя кончается « ::» — учитываем.
		local wrapWidth = surface.GetTextSize(":: " .. " ::")
		local available = SCREEN_W - 18 - HEADER_RESERVED - wrapWidth

		self.headerCacheKey = title
		self.headerCacheLines = WrapHeaderTitle(title, "ixNewsCmbHead", available)
	end

	return self.headerCacheLines
end

-- На сколько шапка выросла из-за второй строки заголовка.
function PANEL:GetHeaderOffset()
	return (#self:GetHeaderLines() - 1) * HEADER_LINE_H
end

function PANEL:Paint(w, h)
	DrawBackground(w, h)

	-- Заголовок статьи показываем целиком, при необходимости в две строки; шапка
	-- при этом становится выше, а всё содержимое ниже сдвигается на GetHeaderOffset().
	local lines = self:GetHeaderLines()
	local extra = self:GetHeaderOffset()

	surface.SetDrawColor(CLR_BLUE)
	surface.DrawRect(16, 34 + extra, w - 32, 1)

	for i, line in ipairs(lines) do
		-- Обрамление «:: ::» открывает первую строку и закрывает последнюю.
		local text = (i == 1 and ":: " or "") .. line .. (i == #lines and " ::" or "")

		draw.SimpleText(text, "ixNewsCmbHead", 18, 9 + (i - 1) * HEADER_LINE_H, CLR_BLUE, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

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
	local extra = self:GetHeaderOffset()

	local meta = string.format("%s  ::  %s  ::  %s",
		entry.source or "ГО",
		os.date("%d.%m.%Y %H:%M", entry.time or os.time()),
		entry.author or "")
	draw.SimpleText(meta, "ixNewsCmbSmall", 18, 46 + extra, CLR_GREEN, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- Тело статьи (текст + картинка внизу) берём из RT — обрезано по видимой области,
	-- за границы монитора ничего не вылезает. UV масштабируем под размер RT.
	local contentTop = self.artContentTop or (66 + extra)
	local viewH      = self.artViewportH or 200

	if self.artMat then
		surface.SetMaterial(self.artMat)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRectUV(0, contentTop, SCREEN_W, viewH, 0, 0, SCREEN_W / ART_RT_W, viewH / ART_RT_H)
	end

	-- Индикатор прокрутки (в процентах), если есть куда листать.
	local maxScroll = self.artMaxScrollPx or 0
	if maxScroll > 0 then
		local pct = math.Round((self.artScrollPx or 0) / maxScroll * 100)
		draw.SimpleText(pct .. "%", "ixNewsCmbSmall", w - 44, TICKER_Y - 18, CLR_DIM, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

vgui.Register("ixGONewsScreen", PANEL, "DPanel")
