netstream.Hook("ixDfBrowserOpen", function(list)
	if IsValid(ix.gui.dfBrowser) then
		ix.gui.dfBrowser:Remove()
	end

	ix.gui.dfBrowser = vgui.Create("ixDatafileBrowser")

	if IsValid(ix.gui.dfBrowser) then
		ix.gui.dfBrowser:SetList(list or {})
	end
end)

-- Полные данные одного досье -> открываем окно с фото
netstream.Hook("ixDfView", function(payload)
	if IsValid(ix.gui.dfView) then
		ix.gui.dfView:Remove()
	end

	ix.gui.dfView = vgui.Create("ixDatafileView")

	if IsValid(ix.gui.dfView) then
		ix.gui.dfView:SetData(payload or {})
	end
end)

-- ============================================================
--  КПК: ввод CID -> досье /datafile, ОТРИСОВАННОЕ НА ЭКРАНЕ устройства
-- ============================================================
-- Поднятый КПК показывает поле ВВОДА CID (нативное окно — нужна клавиатура).
-- После ввода открывается РЕДАКТИРУЕМОЕ окно /datafile (cwFullDatafile); оно
-- НЕ рисуется по центру, а МАСШТАБИРУЕТСЯ в прямоугольник экрана устройства, и
-- кликается реальным курсором (курсор пересчитывается в координаты панели).
-- Текстовый ввод (заметки) идёт через стандартные диалоги cwDfNoteEntry и т.п.
local PDA_CLASS = "pdaremake1"

-- Режим ON-MESH: UI рендерится в RenderTarget и выводится на сабматериал экрана
-- МОДЕЛИ (perspective-correct, на самом устройстве). Клик считается через
-- откалиброванный 4-угольник (обратная билинейная) — углы один раз подгоняются
-- под видимый экран модели (поза держится стабильно из SWEP). Ввод текста — по
-- фокусу поля (текст виден на экране устройства). Калибровка: ix_pda_calib.
local pdaActive   = false
local sessionSeen = false
local lastPopup   = 0
local openTime    = 0
local inputPanel
local homePanel, newsPanel, taskPanel
-- Прямые объявления: домашнее меню и кнопки ссылаются на эти функции (заданы ниже).
local OpenHome, OpenInput, OpenNews, OpenTask

-- Анимация закрытия: устройство сначала «уезжает» вниз, и только потом сервер его
-- реально прячет (см. CalcViewModelView и главный Think).
local pdaClosing  = false
local pdaCloseAt  = 0
local function BeginPdaClose()
	if pdaClosing then return end
	pdaClosing = true
	pdaCloseAt = CurTime()
end

-- ---------- Поле ввода CID (стиль терминалов ГО) ----------
-- Крупный размер (950x570) — так панель рендерится в RT почти 1:1 и не «мылится».
surface.CreateFont("ixPdaHeader", { font = "Blender Pro Medium", size = 54, weight = 600, extended = true, antialias = true })
surface.CreateFont("ixPdaSub",    { font = "Blender Pro Book",   size = 28, weight = 500, extended = true, antialias = true })
surface.CreateFont("ixPdaPrompt", { font = "Blender Pro Book",   size = 30, weight = 500, extended = true, antialias = true })
surface.CreateFont("ixPdaMono",   { font = "Consolas",           size = 54, weight = 700, antialias = true })
surface.CreateFont("ixPdaBtn",    { font = "Blender Pro Medium", size = 34, weight = 600, extended = true, antialias = true })

local PDA_BG    = Color(8, 12, 15, 255)
local PDA_PANEL = Color(14, 20, 24, 255)
local PDA_DEEP  = Color(4, 8, 11, 255)
local PDA_LINE  = Color(0, 170, 210)
local PDA_LINED = Color(0, 90, 115)
local PDA_TEXT  = Color(200, 235, 245)
local PDA_DIM   = Color(110, 140, 150)
local PDA_RED   = Color(210, 60, 50)

-- Угловые скобки (как в окне досье терминала).
local function PdaBrackets(x, y, w, h, len, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, len, 2)             surface.DrawRect(x, y, 2, len)
	surface.DrawRect(x + w - len, y, len, 2)   surface.DrawRect(x + w - 2, y, 2, len)
	surface.DrawRect(x, y + h - 2, len, 2)     surface.DrawRect(x, y + h - len, 2, len)
	surface.DrawRect(x + w - len, y + h - 2, len, 2) surface.DrawRect(x + w - 2, y + h - len, 2, len)
end

local function PdaScanlines(w, h)
	surface.SetDrawColor(0, 0, 0, 24)
	for y = 0, h, 4 do surface.DrawRect(0, y, w, 1) end
end

local INPUT = {}

function INPUT:Init()
	self:SetSize(950, 570)
	self:Center()
	self:SetTitle("")
	self:ShowCloseButton(false)
	self:MakePopup()
	self:SetDeleteOnClose(true)

	self.close = self:Add("DButton")
	self.close:SetSize(46, 46)
	self.close:SetText("")
	self.close.DoClick = function() self:Remove() end
	self.close.Paint = function(s, w, h)
		surface.SetDrawColor(s:IsHovered() and PDA_RED or PDA_PANEL) surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(PDA_LINE) surface.DrawOutlinedRect(0, 0, w, h)
		draw.SimpleText("✕", "ixPdaSub", w * 0.5, h * 0.5 - 1, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	self.entry = self:Add("DTextEntry")
	self.entry:SetFont("ixPdaMono")
	self.entry:SetPlaceholderText("CID")
	self.entry:SetUpdateOnType(true)
	self.entry:RequestFocus()
	self.entry.OnEnter = function() self:DoSubmit() end
	self.entry.Paint = function(s, w, h)
		surface.SetDrawColor(PDA_DEEP) surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(PDA_LINE) surface.DrawOutlinedRect(0, 0, w, h)
		surface.SetDrawColor(PDA_LINE) surface.DrawRect(0, 0, 4, h)
		s:DrawTextEntryText(PDA_TEXT, PDA_LINE, PDA_TEXT)
	end

	self.btn = self:Add("DButton")
	self.btn:SetText("")
	self.btn.DoClick = function() self:DoSubmit() end
	self.btn.Paint = function(s, w, h)
		local hov = s:IsHovered()
		surface.SetDrawColor(hov and PDA_LINED or PDA_PANEL) surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(PDA_LINE) surface.DrawOutlinedRect(0, 0, w, h)
		surface.SetDrawColor(PDA_LINE) surface.DrawRect(0, h - 4, w, 4)
		draw.SimpleText("► ОТКРЫТЬ ДОСЬЕ", "ixPdaBtn", w * 0.5, h * 0.5, hov and color_white or PDA_TEXT,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

function INPUT:PerformLayout(w, h)
	if IsValid(self.close) then self.close:SetPos(w - 58, 96) end
	if IsValid(self.entry) then self.entry:SetPos(80, 255) self.entry:SetSize(w - 160, 80) end
	if IsValid(self.btn)   then self.btn:SetPos(80, 365)   self.btn:SetSize(w - 160, 74) end
end

function INPUT:DoSubmit()
	local cid = string.Trim(self.entry:GetValue() or "")
	if cid == "" then return end

	net.Start("ixDfPdaQuery")
		net.WriteString(cid)
	net.SendToServer()

	self.entry:SetText("")
	self.entry:RequestFocus()
end

function INPUT:Paint(w, h)
	surface.SetDrawColor(PDA_BG) surface.DrawRect(0, 0, w, h)
	PdaScanlines(w, h)

	surface.SetDrawColor(PDA_LINED) surface.DrawOutlinedRect(0, 0, w, h)
	PdaBrackets(0, 0, w, h, 30, PDA_LINE)

	-- шапка (опущена ниже — верх RT уходит за край экрана устройства)
	local hy = 90
	surface.SetDrawColor(PDA_PANEL) surface.DrawRect(3, hy, w - 6, 96)
	surface.SetDrawColor(PDA_LINE)  surface.DrawRect(3, hy + 96, w - 6, 3)
	draw.SimpleText("ГРАЖДАНСКАЯ ОБОРОНА", "ixPdaHeader", 40, hy + 15, PDA_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText("// ЕДИНЫЙ АРХИВ ДОСЬЕ · ЗАПРОС ПО НОМЕРУ ГРАЖДАНИНА", "ixPdaSub", 42, hy + 67, PDA_LINE,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	draw.SimpleText("ВВЕДИТЕ CID И НАЖМИТЕ ENTER", "ixPdaPrompt", 80, hy + 120, PDA_DIM,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

vgui.Register("ixPdaDatafileInput", INPUT, "DFrame")

-- ---------- Домашнее меню КПК (контент 600x360 — оборачивается в видимую зону) ----------
surface.CreateFont("ixPdaHomeTitle", { font = "Blender Pro Medium", size = 26, weight = 600, extended = true, antialias = true })
surface.CreateFont("ixPdaHomeBtn",   { font = "Blender Pro Medium", size = 23, weight = 600, extended = true, antialias = true })

local HOMEC = {}

function HOMEC:Init()
	self:SetSize(600, 360)

	local function makeBtn(label, yy, fn)
		local b = self:Add("DButton")
		b:SetText("")
		b:SetPos(30, yy)
		b:SetSize(540, 62)
		b.DoClick = fn
		b.Paint = function(s, w, h)
			local hov = s:IsHovered()
			surface.SetDrawColor(hov and PDA_LINED or PDA_PANEL) surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(PDA_LINE) surface.DrawOutlinedRect(0, 0, w, h)
			surface.SetDrawColor(PDA_LINE) surface.DrawRect(0, 0, 4, h)
			draw.SimpleText(label, "ixPdaHomeBtn", 22, h * 0.5, hov and color_white or PDA_TEXT,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		end
	end

	makeBtn("► ВВЕСТИ CID — ДОСЬЕ",        96, function() if (OpenInput) then OpenInput() end end)
	makeBtn("► НОВОСТИ — ГРАЖД. ОБОРОНА", 172, function() if (OpenNews) then OpenNews() end end)
	makeBtn("► ДОСКА ОБЪЯВЛЕНИЙ",        248, function() if (OpenTask) then OpenTask() end end)
end

function HOMEC:Paint(w, h)
	surface.SetDrawColor(PDA_BG) surface.DrawRect(0, 0, w, h)
	PdaScanlines(w, h)
	surface.SetDrawColor(PDA_LINED) surface.DrawOutlinedRect(0, 0, w, h)
	PdaBrackets(0, 0, w, h, 18, PDA_LINE)

	draw.SimpleText("ГРАЖДАНСКАЯ ОБОРОНА · ТЕРМИНАЛ", "ixPdaHomeTitle", 20, 16, PDA_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	surface.SetDrawColor(PDA_LINE) surface.DrawRect(20, 52, w - 40, 2)
end

vgui.Register("ixPdaHomeContent", HOMEC, "DPanel")

-- ============================================================
--  Драйвер: панель, отрисованная МАСШТАБОМ на экране устройства + клики
-- ============================================================
-- Реальный курсор пересчитываем в координаты панели и сами рассылаем hover/click,
-- т.к. панель рисуется в другом месте/размере, чем её настоящие координаты.
local overlayPanel -- панель, которую сейчас показываем на экране устройства

local function panelAbsPos(p)
	local x, y = p:GetPos()
	local parent = p:GetParent()
	while IsValid(parent) do
		local px, py = parent:GetPos()
		x, y = x + px, y + py
		parent = parent:GetParent()
	end
	return x, y
end

local function panelHit(p, lx, ly)
	if !lx then return false end
	local px, py = panelAbsPos(p)
	local sw, sh = p:GetSize()
	return p:IsVisible() and lx >= px and ly >= py and lx <= px + sw and ly <= py + sh
end

local function panelDispatch(p, lx, ly, event, ...)
	if !IsValid(p) or !p:IsVisible() or !panelHit(p, lx, ly) then return false end
	for _, c in ipairs(table.Reverse(p:GetChildren())) do
		if panelDispatch(c, lx, ly, event, ...) then return true end
	end
	if isfunction(p[event]) then
		p[event](p, ...)
		return true
	end
	return false
end

-- Активация листа под курсором: OnMousePressed (фокус полей/нажатие) + DoClick.
-- DoClick зовём напрямую, т.к. штатный DButton проверяет реальный hover, а наша
-- панель уведена за экран -> штатный путь DoClick не сработал бы.
local function panelActivate(p, lx, ly, mc)
	if !IsValid(p) or !p:IsVisible() or !panelHit(p, lx, ly) then return false end
	for _, c in ipairs(table.Reverse(p:GetChildren())) do
		if panelActivate(c, lx, ly, mc) then return true end
	end
	local acted = false
	if isfunction(p.OnMousePressed) then p:OnMousePressed(mc) acted = true end
	if mc == MOUSE_LEFT and isfunction(p.DoClick) then p:DoClick() acted = true end
	return acted
end

local function panelHover(p, lx, ly, blocked)
	local childBlocked = false
	for _, c in ipairs(table.Reverse(p:GetChildren())) do
		if panelHover(c, lx, ly, blocked or childBlocked) then childBlocked = true end
	end
	if blocked or childBlocked then
		if p.Hovered then p.Hovered = false; if p.OnCursorExited then p:OnCursorExited() end end
		return blocked or childBlocked
	end
	if panelHit(p, lx, ly) then
		if !p.Hovered then p.Hovered = true; if p.OnCursorEntered then p:OnCursorEntered() end end
		return true
	end
	if p.Hovered then p.Hovered = false; if p.OnCursorExited then p:OnCursorExited() end end
	return false
end

-- ===== RT экрана модели + ввод по откалиброванному квадру =====
local RT_W, RT_H     = 1024, 1024
local SCREEN_MAT_KEY = "screen"          -- часть имени сабматериала экрана (ix_pda_mats)
local PDA_MAT_NAME   = "ixPdaScreenMat"
local pdaRT

-- 4 угла экрана устройства В ДОЛЯХ экрана (где визуально виден экран модели).
-- Подгоняются мышью в режиме ix_pda_calib, затем ix_pda_calib_save -> вписать сюда.
local corners = {
	tl = { 0.2974, 0.3602 }, tr = { 0.7036, 0.3593 },
	br = { 0.7490, 0.7972 }, bl = { 0.2536, 0.7963 },
}
local CALIB    = false
local dragName = nil

-- Подгонка картинки под UV экрана модели:
--  screenScale* — масштаб (UV экрана покрывает не весь [0,1] -> «слишком крупно»,
--                 увеличиваем масштаб, чтобы влез весь UI);
--  screenOff*   — сдвиг (центрируем);
--  screenRot / screenFlip* — ориентация.
-- Команды: ix_pda_screen_fit <scaleX> <scaleY> <offX> <offY> и ix_pda_screen_uv.
local screenRot, screenFlipX, screenFlipY = 0, false, false
local screenScaleX, screenScaleY = 1.900, 1.600
local screenOffX, screenOffY = 0.450, 0.680

local function ApplyScreenUV()
	local mat = Material("!" .. PDA_MAT_NAME)
	if !mat then return end

	local m = Matrix()
	m:Translate(Vector(screenOffX, screenOffY, 0))
	m:Translate(Vector(0.5, 0.5, 0))
	m:Rotate(Angle(0, screenRot, 0)) -- поворот в плоскости UV (вокруг Z)
	m:Scale(Vector((screenFlipX and -1 or 1) * screenScaleX,
		(screenFlipY and -1 or 1) * screenScaleY, 1))
	m:Translate(Vector(-0.5, -0.5, 0))

	mat:SetMatrix("$basetexturetransform", m)
end

local function EnsureRT()
	if pdaRT then return end
	pdaRT = GetRenderTarget("ixPdaScreenRT", RT_W, RT_H)
	CreateMaterial(PDA_MAT_NAME, "UnlitGeneric", {
		["$basetexture"]          = "ixPdaScreenRT",
		["$nolod"]                = "1",
		["$basetexturetransform"] = "center .5 .5 scale 1 1 rotate 0 translate 0 0",
	})
	ApplyScreenUV()
end

local function ScreenMatIndex(vm)
	for i, name in ipairs(vm:GetMaterials() or {}) do
		if string.find(string.lower(name), SCREEN_MAT_KEY, 1, true) then
			return i - 1
		end
	end
end

-- углы в пикселях (a=TL b=TR c=BR d=BL)
local function cornerPx()
	local w, h = ScrW(), ScrH()
	return { x = corners.tl[1] * w, y = corners.tl[2] * h },
	       { x = corners.tr[1] * w, y = corners.tr[2] * h },
	       { x = corners.br[1] * w, y = corners.br[2] * h },
	       { x = corners.bl[1] * w, y = corners.bl[2] * h }
end

local function cross2(ax, ay, bx, by) return ax * by - ay * bx end

-- Обратная билинейная (Iñigo Quilez): точка p в квадре a,b,c,d -> u,v ∈ [0,1].
local function invBilinear(px, py, a, b, c, d)
	local ex, ey = b.x - a.x, b.y - a.y
	local fx, fy = d.x - a.x, d.y - a.y
	local gx, gy = a.x - b.x + c.x - d.x, a.y - b.y + c.y - d.y
	local hx, hy = px - a.x, py - a.y

	local k2 = cross2(gx, gy, fx, fy)
	local k1 = cross2(ex, ey, fx, fy) + cross2(hx, hy, gx, gy)
	local k0 = cross2(hx, hy, ex, ey)

	local u, v
	if math.abs(k2) < 0.001 then
		local denom = ex * k1 - gx * k0
		if math.abs(denom) < 1e-6 then return end
		u = (hx * k1 - fx * k0) / denom
		v = (math.abs(k1) < 1e-6) and -1 or (-k0 / k1)
	else
		local disc = k1 * k1 - 4 * k0 * k2
		if disc < 0 then return end
		disc = math.sqrt(disc)
		v = (-k1 - disc) / (2 * k2)
		local denom = ex + gx * v
		if v < -0.01 or v > 1.01 or math.abs(denom) < 1e-6 then
			v = (-k1 + disc) / (2 * k2)
			denom = ex + gx * v
		end
		if math.abs(denom) < 1e-6 then return end
		u = (hx - fx * v) / denom
	end
	return u, v
end

-- курсор -> координаты панели через квадр
local function cursorPanel(panel)
	local a, b, c, d = cornerPx()
	local mx, my = input.GetCursorPos()
	local u, v = invBilinear(mx, my, a, b, c, d)
	if !u or u < 0 or u > 1 or v < 0 or v > 1 then return end
	return u * panel:GetWide(), v * panel:GetTall()
end

local function CaptureOverlay(panel)
	if overlayPanel == panel then return end
	overlayPanel = panel
	EnsureRT()
	panel:SetPaintedManually(true)  -- не рисуем штатно; выводим через RT на меш
	panel:SetMouseInputEnabled(false)
	panel:SetAlpha(0)               -- невидимо для обычной отрисовки (анти-попап)
	panel:SetPos(0, 0)              -- PaintManual рисует от (0,0); матрица растянет в RT
	gui.EnableScreenClicker(true)   -- свободный курсор + GUIMouse-хуки
	-- Автофокус текстового поля (CID/заметка) — набор сразу виден на экране.
	-- G всё равно закрывает КПК: гард срабатывает только при открытом ДИАЛОГЕ записи.
	local field = panel.entry or panel.Entry
	if IsValid(field) then field:RequestFocus() end
end

local function ClearScreenMat()
	local vm = LocalPlayer():GetViewModel()
	if !IsValid(vm) then return end
	for i = 0, #(vm:GetMaterials() or {}) - 1 do
		vm:SetSubMaterial(i, nil)
	end
end

local function ReleaseOverlay()
	if IsValid(overlayPanel) then
		overlayPanel:SetPaintedManually(false)
		overlayPanel:SetMouseInputEnabled(true)
		overlayPanel:SetAlpha(255)
	end
	overlayPanel = nil
	gui.EnableScreenClicker(CALIB) -- в калибровке курсор оставляем свободным
	ClearScreenMat()
end

-- Рендер активной панели в RT (PostRender — безопасный контекст для RT).
hook.Add("PostRender", "ixPdaDatafileScreen", function()
	if !IsValid(overlayPanel) then return end
	-- Каждый кадр заново гасим обычную отрисовку — иначе попап-окно записи может
	-- снова «всплыть» (DFrame порой сбрасывает флаг).
	overlayPanel:SetPaintedManually(true)
	overlayPanel:SetMouseInputEnabled(false)
	EnsureRT()

	local pw, ph = overlayPanel:GetWide(), overlayPanel:GetTall()
	if pw <= 0 or ph <= 0 then return end

	-- ховер по текущему положению курсора (в координатах панели)
	local lx, ly = cursorPanel(overlayPanel)
	panelHover(overlayPanel, lx, ly, false)

	-- непрозрачно только на время рендера в RT
	overlayPanel:SetAlpha(255)

	render.PushRenderTarget(pdaRT)
		render.Clear(0, 0, 0, 255, true, true)
		cam.Start2D()
			local oldX, oldY = gui.MouseX, gui.MouseY
			gui.MouseX = function() return lx or -1 end
			gui.MouseY = function() return ly or -1 end

			local m = Matrix()
			m:Scale(Vector(RT_W / pw, RT_H / ph, 1)) -- растягиваем панель на весь RT
			cam.PushModelMatrix(m)
				overlayPanel:PaintManual()
			cam.PopModelMatrix()

			gui.MouseX, gui.MouseY = oldX, oldY
		cam.End2D()
	render.PopRenderTarget()

	-- ... и невидимо для обычной отрисовки экрана (на случай, если SetPaintedManually
	-- не подавляет попап у этого DFrame). Курсор-перехват и фокус при этом сохраняются.
	overlayPanel:SetAlpha(0)
end)

-- Выводим RT на сабматериал экрана модели.
hook.Add("PreDrawViewModel", "ixPdaDatafileScreen", function(vm, wply, weapon)
	if !IsValid(overlayPanel) or !IsValid(vm) then return end
	if !IsValid(weapon) or weapon:GetClass() != PDA_CLASS then return end

	local idx = ScreenMatIndex(vm)
	if idx then vm:SetSubMaterial(idx, "!" .. PDA_MAT_NAME) end

	-- Замораживаем штатную анимацию модели (draw/holster дёргались поверх
	-- нашей позы-слайда — отсюда мелькание «финального кадра»).
	local seq = vm:LookupSequence("idle")
	if !seq or seq < 0 then seq = 0 end
	vm:SetSequence(seq)
	vm:SetPlaybackRate(0)
end)

-- Клики по экрану модели.
hook.Add("GUIMousePressed", "ixPdaDatafileScreen", function(mc)
	if CALIB then
		-- режим калибровки: хватаем ближайший угол
		local mx, my = input.GetCursorPos()
		local best, bestD
		for name, frac in pairs(corners) do
			local d = (frac[1] * ScrW() - mx) ^ 2 + (frac[2] * ScrH() - my) ^ 2
			if !bestD or d < bestD then best, bestD = name, d end
		end
		if best and bestD <= 40 * 40 then dragName = best end
		return
	end

	if mc == MOUSE_RIGHT then return end -- ПКМ = «назад», обрабатывается отдельным хуком

	if !IsValid(overlayPanel) then return end
	local lx, ly = cursorPanel(overlayPanel)
	if !lx then return end
	panelActivate(overlayPanel, lx, ly, mc)
end)

hook.Add("GUIMouseReleased", "ixPdaDatafileScreen", function(mc)
	if CALIB then dragName = nil return end
	if !IsValid(overlayPanel) then return end
	local lx, ly = cursorPanel(overlayPanel)
	if !lx then return end
	panelDispatch(overlayPanel, lx, ly, "OnMouseReleased", mc)
end)

-- Калибровка: тянем углы мышью, рисуем квадр.
hook.Add("HUDPaint", "ixPdaDatafileCalib", function()
	if !CALIB then return end

	if dragName then
		local mx, my = input.GetCursorPos()
		corners[dragName] = { mx / ScrW(), my / ScrH() }
	end

	local a, b, c, d = cornerPx()
	surface.SetDrawColor(0, 220, 255, 220)
	surface.DrawLine(a.x, a.y, b.x, b.y)
	surface.DrawLine(b.x, b.y, c.x, c.y)
	surface.DrawLine(c.x, c.y, d.x, d.y)
	surface.DrawLine(d.x, d.y, a.x, a.y)

	for name, p in pairs({ TL = a, TR = b, BR = c, BL = d }) do
		surface.SetDrawColor(255, 220, 0, 255)
		surface.DrawRect(p.x - 4, p.y - 4, 8, 8)
		draw.SimpleText(name, "DermaDefault", p.x + 6, p.y - 6, color_white)
	end

	draw.SimpleText("КАЛИБРОВКА: тяните углы на экран КПК. ix_pda_calib_save — сохранить, ix_pda_calib — выход",
		"DermaDefault", ScrW() * 0.5, 24, Color(0, 220, 255), TEXT_ALIGN_CENTER)
end)

-- ---------- Клавиша G: включить/выключить КПК ----------
-- Сервер проверяет наличие предмета (включение) и сам решает вкл/выкл.
-- Детект через ОПРОС клавиши (PlayerButtonDown тут не срабатывал). Не переключаем,
-- когда открыт чат или сфокусировано текстовое поле — иначе буква «g» во время
-- набора (в т.ч. заметок/CID) закрывала бы КПК.
local gWasDown = false
local chatOpen = false

hook.Add("StartChat",  "ixPdaChatGuard", function() chatOpen = true end)
hook.Add("FinishChat", "ixPdaChatGuard", function() chatOpen = false end)

-- Надёжно отслеживаем открытый диалог ввода записи: оборачиваем Init классов, чтобы
-- свежесозданный диалог САМ себя регистрировал (рекурсивный поиск по дереву иногда
-- не находит попап -> он показывался отдельным окном). Запасной поиск — сканом.
local pdaDialog
local DIALOG_CLASSES = { "cwDfNoteEntry", "cwDfCivilEntry", "cwDfMedicalEntry", "cwDfRegistryEntry" }

local function EnsureDialogHooks()
	for _, name in ipairs(DIALOG_CLASSES) do
		local tbl = vgui.GetControlTable(name)
		if tbl and not tbl.__ixPdaWrap then
			tbl.__ixPdaWrap = true
			local origInit = tbl.Init
			tbl.Init = function(self)
				if origInit then origInit(self) end
				pdaDialog = self
			end
		end
	end
end
EnsureDialogHooks()

local function scanDialog(parent)
	parent = parent or vgui.GetWorldPanel()
	for _, p in ipairs(parent:GetChildren()) do
		if IsValid(p) and p:IsVisible() then
			if IsValid(p.Entry) and IsValid(p.Submit) then return p end
			local nested = scanDialog(p)
			if nested then return nested end
		end
	end
end

-- Возвращает открытый диалог записи (или nil). Внутри него печатают свободный текст
-- с буквой «g», поэтому G не переключает КПК, пока он открыт.
local function FindRecordDialog()
	EnsureDialogHooks()
	if IsValid(pdaDialog) and pdaDialog:IsVisible() then return pdaDialog end
	return scanDialog()
end

hook.Add("Think", "ixPdaToggleKey", function()
	local down = input.IsKeyDown(KEY_G)

	if down and !gWasDown and !chatOpen and !IsValid(FindRecordDialog()) then
		local ply = LocalPlayer()
		if IsValid(ply) and ply:Alive() and (ply.ixNextPdaG or 0) <= CurTime() then
			ply.ixNextPdaG = CurTime() + 0.35
			if pdaActive then
				BeginPdaClose() -- закрываем с анимацией (сервер спрячет после слайда)
			else
				net.Start("ixPdaToggle") net.SendToServer() -- открыть
			end
		end
	end

	gWasDown = down
end)

-- ---------- ПКМ: «назад» на один уровень ----------
-- Диалог записи -> досье -> ввод CID -> закрыть КПК. Запасной способ навигации,
-- чтобы не целиться в маленькие крестики.
hook.Add("GUIMousePressed", "ixPdaBack", function(mc)
	if mc != MOUSE_RIGHT then return end
	if CALIB or !IsValid(overlayPanel) then return end -- только когда открыт UI КПК

	-- 1. открыт диалог записи -> закрыть (назад к досье)
	local dlg = FindRecordDialog()
	if IsValid(dlg) then dlg:Remove() return end

	-- 2. попап публикации объявления -> закрыть (назад к доске)
	if IsValid(ix.gui.taskboardPost) then ix.gui.taskboardPost:Remove() return end

	-- 3. открыто окно досье -> закрыть (назад к вводу CID)
	local dfp = ix.plugin.list["datafile"]
	if dfp and IsValid(dfp.GUI) then dfp.GUI:Remove() return end
	if dfp and IsValid(dfp.Managefile) then dfp.Managefile:Remove() return end
	if IsValid(ix.gui.dfBrowser) then ix.gui.dfBrowser:Remove() return end
	if IsValid(ix.gui.dfView) then ix.gui.dfView:Remove() return end

	-- 4. раздел (ввод CID / новости / доска) -> назад в домашнее меню
	if IsValid(inputPanel) or IsValid(newsPanel) or IsValid(taskPanel) then
		OpenHome()
		return
	end

	-- 5. домашнее меню -> закрыть КПК (с анимацией)
	BeginPdaClose()
end)

-- ---------- Поза вьюмодели КПК ----------
-- Держим модель крупно/стабильно по центру взгляда. Поза задаётся ЗДЕСЬ (в плагине),
-- а не в SWEP: gamemode-хук CalcViewModelView перекрывает метод оружия и надёжно
-- перезагружается через lua_reload (файлы оружия кэшируются и так не перезагружаются).
-- Меньше fwd = крупнее; больше up = выше. Команда: ix_pda_pose <fwd> <right> <up> <pitch> <yaw> <roll>.
local poseFwd, poseRight, poseUp = 4.5, 0, 1
local posePitch, poseYaw, poseRoll = 0, 0, 0

-- Анимация открытия: устройство «въезжает» снизу за ~0.28с, а не снапается в
-- финальную позу (из-за чего раньше мелькал последний кадр перед анимацией).
local PDA_ANIM   = 0.2
local pdaAnimAt  = 0
local pdaWasEq   = false

hook.Add("CalcViewModelView", "ixPdaPose", function(weapon, vm, oldPos, oldAng, pos, ang)
	if !IsValid(weapon) or weapon:GetClass() != PDA_CLASS then pdaWasEq = false return end
	if !(weapon.GetPDAEquipped and weapon:GetPDAEquipped()) then pdaWasEq = false return end

	local ply = LocalPlayer()
	if !IsValid(ply) then return end

	-- старт анимации в момент появления
	if !pdaWasEq then
		pdaWasEq  = true
		pdaAnimAt = CurTime()
	end

	local frac
	if pdaClosing then
		-- закрытие: едет вниз (1 -> 0)
		frac = 1 - math.Clamp((CurTime() - pdaCloseAt) / PDA_ANIM, 0, 1)
	else
		-- открытие: едет вверх (0 -> 1)
		frac = math.Clamp((CurTime() - pdaAnimAt) / PDA_ANIM, 0, 1)
	end
	frac = 1 - (1 - frac) * (1 - frac) -- ease-out: резкий старт, мягкое торможение

	local eye = ply:EyeAngles()
	-- стартовая поза: чуть ниже и слегка наклонена -> быстро встаёт в рабочую
	local fwd   = Lerp(frac, poseFwd + 1.5, poseFwd)
	local up    = Lerp(frac, poseUp - 6, poseUp)
	local pitch = Lerp(frac, posePitch + 12, posePitch)

	local newPos = ply:EyePos()
		+ eye:Forward() * fwd
		+ eye:Right()   * poseRight
		+ eye:Up()      * up

	local newAng = Angle(eye.p, eye.y, eye.r)
	newAng:RotateAroundAxis(newAng:Up(),      poseYaw)
	newAng:RotateAroundAxis(newAng:Right(),   pitch)
	newAng:RotateAroundAxis(newAng:Forward(), poseRoll)

	return newPos, newAng
end)

concommand.Add("ix_pda_pose", function(_, _, args)
	poseFwd   = tonumber(args[1]) or poseFwd
	poseRight = tonumber(args[2]) or poseRight
	poseUp    = tonumber(args[3]) or poseUp
	posePitch = tonumber(args[4]) or posePitch
	poseYaw   = tonumber(args[5]) or poseYaw
	poseRoll  = tonumber(args[6]) or poseRoll
	print(string.format("[PDA] pose: fwd=%.1f right=%.1f up=%.1f pitch=%.1f yaw=%.1f roll=%.1f",
		poseFwd, poseRight, poseUp, posePitch, poseYaw, poseRoll))
end)

-- ---------- Логика КПК ----------
-- Диалоги добавления записей выводим НА ЭКРАН устройства (а не отдельным окном).
-- Используем тот же РЕКУРСИВНЫЙ поиск, что и гард клавиши G.
local function FindDialog()
	return FindRecordDialog()
end

-- Панель, которую сейчас показываем на экране устройства. Приоритет: диалог ввода
-- записи -> редактируемое досье -> поле ввода CID.
local function OverlayTarget()
	local dlg = FindDialog()
	if IsValid(dlg) then return dlg end

	local dfp = ix.plugin.list["datafile"]
	if dfp then
		if IsValid(dfp.GUI) then return dfp.GUI end
		if IsValid(dfp.Managefile) then return dfp.Managefile end
	end
	if IsValid(newsPanel) then return newsPanel end
	if IsValid(taskPanel) then return taskPanel end
	if IsValid(inputPanel) then return inputPanel end
	if IsValid(homePanel) then return homePanel end
end

-- Любое открытое окно сессии (для удержания КПК поднятым).
local function AnySession()
	return IsValid(OverlayTarget())
		or IsValid(ix.gui.dfBrowser) or IsValid(ix.gui.dfView)
end

local function ClosePdaUI()
	if IsValid(inputPanel) then inputPanel:Remove() end
	if IsValid(homePanel) then homePanel:Remove() end
	if IsValid(newsPanel) then newsPanel:Remove() end
	if IsValid(taskPanel) then taskPanel:Remove() end
	if IsValid(ix.gui.taskboardPost) then ix.gui.taskboardPost:Remove() end
	local dfp = ix.plugin.list["datafile"]
	if dfp then
		if IsValid(dfp.GUI) then dfp.GUI:Remove() end
		if IsValid(dfp.Managefile) then dfp.Managefile:Remove() end
	end
	if IsValid(ix.gui.dfBrowser) then ix.gui.dfBrowser:Remove() end
	if IsValid(ix.gui.dfView) then ix.gui.dfView:Remove() end
	-- закрыть незакрытые диалоги ввода записей
	local dlg = FindDialog()
	while IsValid(dlg) do dlg:Remove() dlg = FindDialog() end
	ReleaseOverlay()
end

-- Открыть один экран КПК, закрыв остальные (рендер на экране устройства через overlay).
local function CloseSubScreens()
	if IsValid(homePanel)  then homePanel:Remove()  homePanel  = nil end
	if IsValid(inputPanel) then inputPanel:Remove() inputPanel = nil end
	if IsValid(newsPanel)  then newsPanel:Remove()  newsPanel  = nil end
	if IsValid(taskPanel)  then taskPanel:Remove()  taskPanel  = nil end
end

-- Срезается только ВЕРХ экрана устройства (низ виден до самого края). Поэтому
-- сверху небольшой отступ (чтобы шапка не ушла за край), снизу — почти нет, иначе
-- контент «сплющивается» к середине. Подстройка вживую: ix_pda_menu_inset <top> <bot>.
local pdaTopClip, pdaBotClip = 0.15, 0.03

-- Обернуть контент-панель (600x360) так, чтобы она целиком попала в видимую полосу.
-- Делаем обёртку выше контента, помещаем контент с отступом — при растяжке в RT
-- контент занимает ровно видимую часть экрана устройства.
local function MakeWrap(class)
	local child = vgui.Create(class)
	if (!IsValid(child)) then return end

	local cw = child:GetWide(); if (cw <= 0) then cw = 600 end
	local ch = child:GetTall(); if (ch <= 0) then ch = 360 end

	local frac = math.max(0.2, 1 - pdaTopClip - pdaBotClip)
	local H = math.Round(ch / frac)

	local wrap = vgui.Create("DPanel")
	wrap:SetSize(cw, H)
	wrap.Paint = function(_, w, h)
		surface.SetDrawColor(PDA_BG) surface.DrawRect(0, 0, w, h)
	end

	child:SetParent(wrap)
	child:SetPos(0, math.Round(pdaTopClip * H))
	wrap.child = child

	return wrap
end

function OpenHome()
	CloseSubScreens()
	homePanel = MakeWrap("ixPdaHomeContent")
	if IsValid(homePanel) then CaptureOverlay(homePanel) end
end

function OpenInput()
	CloseSubScreens()
	inputPanel = vgui.Create("ixPdaDatafileInput")
	if IsValid(inputPanel) then CaptureOverlay(inputPanel) end
end

function OpenNews()
	CloseSubScreens()
	newsPanel = MakeWrap("ixGONewsScreen")
	if IsValid(newsPanel) then CaptureOverlay(newsPanel) end
end

function OpenTask()
	CloseSubScreens()
	taskPanel = MakeWrap("ixTaskBoardScreen")
	if IsValid(taskPanel) then CaptureOverlay(taskPanel) end
end

-- Подстройка видимой полосы меню вживую (если шапка/низ срезаны).
concommand.Add("ix_pda_menu_inset", function(_, _, args)
	pdaTopClip = tonumber(args[1]) or pdaTopClip
	pdaBotClip = tonumber(args[2]) or pdaBotClip
	print(string.format("[PDA] menu inset: top=%.3f bot=%.3f", pdaTopClip, pdaBotClip))

	if (IsValid(homePanel)) then OpenHome()
	elseif (IsValid(newsPanel)) then OpenNews()
	elseif (IsValid(taskPanel)) then OpenTask() end
end)

hook.Add("Think", "ixPdaDatafile", function()
	local ply = LocalPlayer()
	if !IsValid(ply) then return end

	-- идёт анимация закрытия: ждём её конца, затем реально прячем на сервере
	if pdaClosing then
		if CurTime() >= pdaCloseAt + PDA_ANIM then
			pdaClosing = false
			pdaActive  = false
			ClosePdaUI()
			net.Start("ixDfPdaClose") net.SendToServer()
		end
		return
	end

	local wep = ply:GetActiveWeapon()
	local raised = IsValid(wep) and wep:GetClass() == PDA_CLASS
		and wep.GetPDAEquipped and wep:GetPDAEquipped() or false

	-- подняли -> показать домашнее меню (3 кнопки)
	if raised and !pdaActive then
		pdaActive   = true
		sessionSeen = false
		openTime    = CurTime()
		lastPopup   = 0
		pdaClosing  = false
		OpenHome()
		return
	end

	-- опустили (RMB/иначе) -> закрыть всё и убрать устройство
	if !raised and pdaActive then
		pdaActive = false
		ClosePdaUI()
		net.Start("ixDfPdaClose") net.SendToServer()
		return
	end

	if !pdaActive then return end

	-- держим оверлей на актуальном окне досье
	local target = OverlayTarget()
	if IsValid(target) then
		CaptureOverlay(target)
	elseif IsValid(overlayPanel) then
		ReleaseOverlay()
	end

	if AnySession() then
		sessionSeen = true
		lastPopup   = CurTime()
	else
		-- всё закрыто -> закрываем КПК С АНИМАЦИЕЙ
		if (sessionSeen and CurTime() > lastPopup + 0.25)
		or (!sessionSeen and CurTime() > openTime + 1.5) then
			BeginPdaClose()
		end
	end
end)

-- Ориентация картинки на экране: ix_pda_screen_uv <rotDeg> <flipX 0/1> <flipY 0/1>
concommand.Add("ix_pda_screen_uv", function(_, _, args)
	screenRot   = tonumber(args[1]) or screenRot
	screenFlipX = (args[2] == "1")
	screenFlipY = (args[3] == "1")
	EnsureRT()
	ApplyScreenUV()
	print(string.format("[PDA] screen UV: rot=%d flipX=%s flipY=%s",
		screenRot, tostring(screenFlipX), tostring(screenFlipY)))
end)

-- Подгон масштаба/сдвига картинки под UV экрана: ix_pda_screen_fit <sx> <sy> <offX> <offY>
-- «Слишком крупно, виден кусок» -> увеличивайте sx/sy (напр. 3 3), потом сдвигайте offX/offY.
concommand.Add("ix_pda_screen_fit", function(_, _, args)
	screenScaleX = tonumber(args[1]) or screenScaleX
	screenScaleY = tonumber(args[2]) or screenScaleY
	screenOffX   = tonumber(args[3]) or screenOffX
	screenOffY   = tonumber(args[4]) or screenOffY
	EnsureRT()
	ApplyScreenUV()
	print(string.format("[PDA] screen fit: scale=%.3f,%.3f off=%.3f,%.3f",
		screenScaleX, screenScaleY, screenOffX, screenOffY))
end)

-- Калибровка экрана: вкл/выкл. Поднимите КПК, включите — и перетащите 4 угла
-- (TL/TR/BR/BL) ровно на видимый экран модели. Курсор свободен в этом режиме.
concommand.Add("ix_pda_calib", function()
	CALIB = !CALIB
	dragName = nil
	gui.EnableScreenClicker(CALIB or IsValid(overlayPanel))
	print("[PDA] калибровка экрана: " .. tostring(CALIB))
end)

-- Сохранить настройки: печатает готовые значения для вставки в начало драйвера.
concommand.Add("ix_pda_calib_save", function()
	print("[PDA] вставьте в cl_hooks.lua:")
	print(string.format("local corners = {\n\ttl = { %.4f, %.4f }, tr = { %.4f, %.4f },\n\tbr = { %.4f, %.4f }, bl = { %.4f, %.4f },\n}",
		corners.tl[1], corners.tl[2], corners.tr[1], corners.tr[2],
		corners.br[1], corners.br[2], corners.bl[1], corners.bl[2]))
	print(string.format("local screenRot, screenFlipX, screenFlipY = %d, %s, %s",
		screenRot, tostring(screenFlipX), tostring(screenFlipY)))
	print(string.format("local screenScaleX, screenScaleY = %.3f, %.3f", screenScaleX, screenScaleY))
	print(string.format("local screenOffX, screenOffY = %.3f, %.3f", screenOffX, screenOffY))
end)

-- АВАРИЙНЫЙ выход: принудительно закрыть оверлей и разблокировать игрока.
-- Доступно из консоли (~), даже если экран заблокирован.
concommand.Add("ix_pda_close", function()
	if IsValid(inputPanel) then inputPanel:Remove() end
	local dfp = ix.plugin.list["datafile"]
	if dfp then
		if IsValid(dfp.GUI) then dfp.GUI:Remove() end
		if IsValid(dfp.Managefile) then dfp.Managefile:Remove() end
	end
	ReleaseOverlay()
	gui.EnableScreenClicker(false)
	pdaActive = false
	net.Start("ixDfPdaClose") net.SendToServer()
	print("[PDA] оверлёй закрыт принудительно")
end)
