--[[
	Радиальное меню взаимодействия с персонажем.

	При нажатии E на другого игрока вместо стандартного списка опций
	открывается круговое меню с плавной анимацией. Содержит наиболее
	полезные действия: передать деньги (/GiveMoney), обыскать (/CharSearch),
	запомнить (как F3), посмотреть профиль, а также любые контекстные
	опции игрока (Связать/Развязать и т.п.), добавленные другими плагинами
	через хук GetPlayerEntityMenu.
]]

local PLUGIN = PLUGIN

PLUGIN.name = "Радиальное меню"
PLUGIN.author = ""
PLUGIN.description = "Круговое меню взаимодействия при нажатии E на персонажа."

if (!CLIENT) then
	return
end

-- Русские названия и иконки для контекстных опций из GetPlayerEntityMenu.
-- Ключ — оригинальное имя опции (то, что уходит на сервер), значение —
-- {label, icon}. Неизвестные ключи показываются как есть.
local DYNAMIC_OPTIONS = {
	["Untie"]  = {"Развязать", "icon16/lock_open.png"},
	["Ziptie"] = {"Связать",   "icon16/lock.png"},
	-- "Search" намеренно не дублируем — есть базовая опция «Обыскать».
}
local DYNAMIC_SKIP = {
	["Search"] = true,
}

local function EaseOut(f)
	f = math.Clamp(f, 0, 1)
	return 1 - (1 - f) ^ 5
end

local function NormDiff(a, b)
	local d = (a - b) % 360
	if (d > 180) then d = d - 360 end
	return d
end

-- Повтор стандартного потока «запомнить» (recognition.lua), но нацеленный
-- на конкретного игрока, а не на тех, на кого смотрит прицел.
local function DoRecognize(target)
	if (!IsValid(target) or !target:IsPlayer()) then return end
	if (ix.gui.recognize) then return end

	local client = LocalPlayer()
	local character = client:GetCharacter()
	local targetCharacter = target:GetCharacter()

	if (!character or !targetCharacter) then return end
	if (target:GetNetVar("hide", 0) == targetCharacter:GetID()) then return end
	if (target:Team() == FACTION_MPF or target:Team() == FACTION_OTA) then return end

	ix.gui.recognize = true

	local name = hook.Run("GetCharacterName", target, "ic")

	Derma_StringRequest(L("recognition.rememberTitle"), L("recognition.rememberPrompt", name), "", function(text)
		ix.gui.recognize = nil

		client.recognize = client.recognize or {}
		client.recognize[targetCharacter:GetID()] = text

		local id = character:GetID()
		ix.recognize = ix.recognize or {}
		ix.recognize[id] = table.Copy(client.recognize)

		ix.data.Set("recognition", ix.recognize, false, true)

		surface.PlaySound("buttons/button17.wav")
	end, function()
		ix.gui.recognize = nil
	end)
end

local function DoGiveMoney(target)
	Derma_StringRequest("Передать деньги", "Введите сумму для передачи:", "", function(text)
		local amount = math.floor(tonumber(text) or 0)

		if (amount > 0) then
			-- Команда трассирует прицел на 96 ед.; курсор меню не меняет
			-- угол обзора, поэтому цель остаётся под прицелом.
			ix.command.Send("GiveMoney", amount)
		end
	end)
end

-- Строит список опций для радиального меню по цели.
local function BuildOptions(target)
	local options = {}

	options[#options + 1] = {
		label = "Передать деньги",
		icon = "icon16/money_add.png",
		callback = function() DoGiveMoney(target) end
	}
	options[#options + 1] = {
		label = "Обыскать",
		icon = "icon16/magnifier.png",
		callback = function() ix.command.Send("CharSearch") end
	}
	options[#options + 1] = {
		label = "Запомнить",
		icon = "icon16/user_comment.png",
		callback = function() DoRecognize(target) end
	}

	-- Уколоть транквилизатором — только если он есть в инвентаре. Применение
	-- (трасса + контактное удержание + эффект) делает серверный обработчик
	-- OnPlayerOptionSelected в плагине transvil.
	if (LocalPlayer():HasItem("tranq_injector")) then
		options[#options + 1] = {
			label = "Уколоть транквилизатором",
			icon = "icon16/pill.png",
			callback = function()
				if (IsValid(target)) then
					ix.menu.NetworkChoice(target, "TranqInject")
				end
			end
		}
	end

	-- Контекстные опции, добавленные плагинами через GetPlayerEntityMenu.
	local dynamic = target:GetEntityMenu(LocalPlayer())

	if (istable(dynamic)) then
		for key, value in pairs(dynamic) do
			if (DYNAMIC_SKIP[key]) then continue end

			local info = DYNAMIC_OPTIONS[key]
			local label = info and info[1] or key
			local icon = info and info[2] or "icon16/bullet_go.png"

			options[#options + 1] = {
				label = label,
				icon = icon,
				callback = function()
					-- Точное повторение поведения стандартного меню Helix:
					-- функция-значение вызывается на клиенте; иначе выбор
					-- уходит на сервер через NetworkChoice.
					local status = true

					if (isfunction(value)) then
						status = value()
					elseif (istable(value) and isfunction(value[2])) then
						status = value[2]()
					end

					if (status != false and IsValid(target)) then
						ix.menu.NetworkChoice(target, key, status)
					end
				end
			}
		end
	end

	return options
end

--[[ Панель радиального меню ]]
local PANEL = {}

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)

	self.options = {}
	self.hovered = 0
	self.openFrac = 0
	self.bClosing = false
	self.scales = {}

	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(true)
	self:MakePopup()

	if (IsValid(LocalPlayer())) then
		LocalPlayer():EmitSound("Helix.Rollover")
	end
end

function PANEL:SetTarget(target)
	self.target = target
	self.options = BuildOptions(target)

	for i = 1, #self.options do
		self.scales[i] = 1
	end

	self.centerName = hook.Run("GetCharacterName", target, "ic") or "Цель"
end

function PANEL:Think()
	if (!IsValid(self.target)) then
		self:CloseMenu(true)
		return
	end

	if (input.IsKeyDown(KEY_ESCAPE)) then
		self:CloseMenu(true)
		return
	end

	local target = self.bClosing and 0 or 1
	self.openFrac = math.Approach(self.openFrac, target, FrameTime() * 6)

	if (self.bClosing and self.openFrac <= 0.01) then
		local action = self.pendingAction
		self:Remove()

		if (action) then
			action()
		end

		return
	end

	-- Определяем наведённый сектор.
	local count = #self.options
	local cx, cy = ScrW() * 0.5, ScrH() * 0.5
	local mx, my = gui.MousePos()
	local dx, dy = mx - cx, my - cy
	local dist = math.sqrt(dx * dx + dy * dy)

	local outerR = ScrH() * 0.21
	local innerR = outerR * 0.46

	local newHover = 0

	if (count > 0 and dist >= innerR and dist <= outerR * 1.15) then
		local sweep = 360 / count
		local ang = math.deg(math.atan2(dy, dx))

		for i = 1, count do
			local centerAng = -90 + (i - 1) * sweep

			if (math.abs(NormDiff(ang, centerAng)) <= sweep * 0.5) then
				newHover = i
				break
			end
		end
	end

	if (newHover != self.hovered) then
		self.hovered = newHover

		if (newHover > 0 and IsValid(LocalPlayer())) then
			LocalPlayer():EmitSound("Helix.Rollover")
		end
	end

	-- Плавный «выезд» наведённого сектора.
	for i = 1, count do
		local want = (i == self.hovered) and 1.08 or 1
		self.scales[i] = Lerp(FrameTime() * 12, self.scales[i] or 1, want)
	end
end

-- Заливка кольцевого сектора (одним проходом DrawPoly по квадам-сегментам).
local function FillSector(cx, cy, rin, rout, a0, a1, segments)
	for s = 0, segments - 1 do
		local ra = math.rad(Lerp(s / segments, a0, a1))
		local rb = math.rad(Lerp((s + 1) / segments, a0, a1))

		surface.DrawPoly({
			{x = cx + math.cos(ra) * rin, y = cy + math.sin(ra) * rin},
			{x = cx + math.cos(ra) * rout, y = cy + math.sin(ra) * rout},
			{x = cx + math.cos(rb) * rout, y = cy + math.sin(rb) * rout},
			{x = cx + math.cos(rb) * rin, y = cy + math.sin(rb) * rin}
		})
	end
end

-- Заливка круга (триангл-фан из центра).
local function FillCircle(cx, cy, r, segments)
	for s = 0, segments - 1 do
		local ra = math.rad((s / segments) * 360)
		local rb = math.rad(((s + 1) / segments) * 360)

		surface.DrawPoly({
			{x = cx, y = cy},
			{x = cx + math.cos(ra) * r, y = cy + math.sin(ra) * r},
			{x = cx + math.cos(rb) * r, y = cy + math.sin(rb) * r}
		})
	end
end

function PANEL:Paint(width, height)
	local frac = EaseOut(self.openFrac)
	if (frac <= 0.001) then return end

	local count = #self.options
	if (count == 0) then return end

	local cx, cy = width * 0.5, height * 0.5
	local baseR  = ScrH() * 0.22
	local outerR = baseR * frac
	local innerR = baseR * 0.5 * frac
	local sweep  = 360 / count
	local gap    = count > 1 and 2.5 or 0

	local accent = ix.config.Get("color")
	local a      = frac

	-- Размытый затемнённый фон — фирменный вид меню Helix.
	ix.util.DrawBlur(self, 4 * frac)
	surface.SetDrawColor(0, 0, 0, 110 * a)
	surface.DrawRect(0, 0, width, height)

	draw.NoTexture()

	-- Сектора.
	for i = 1, count do
		local centerAng = -90 + (i - 1) * sweep
		local a0 = centerAng - sweep * 0.5 + gap * 0.5
		local a1 = centerAng + sweep * 0.5 - gap * 0.5
		local scale = self.scales[i] or 1
		local bHover = (i == self.hovered)
		local rout = outerR * scale

		if (bHover) then
			surface.SetDrawColor(accent.r, accent.g, accent.b, 235 * a)
		else
			surface.SetDrawColor(0, 0, 0, 170 * a)
		end

		FillSector(cx, cy, innerR, rout, a0, a1, 22)

		-- Тонкая акцентная дуга по внешнему краю наведённого сектора.
		if (bHover) then
			surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * a)
			FillSector(cx, cy, rout - 2, rout, a0, a1, 22)
		end
	end

	-- Подписи (заглавными, шрифтом меню Helix — как в стандартном меню).
	for i = 1, count do
		local opt = self.options[i]
		local centerAng = math.rad(-90 + (i - 1) * sweep)
		local scale = self.scales[i] or 1
		local midR = (innerR + outerR * scale) * 0.5
		local lx = cx + math.cos(centerAng) * midR
		local ly = cy + math.sin(centerAng) * midR
		local bHover = (i == self.hovered)

		draw.SimpleText(opt.label:utf8upper(), "ixMenuButtonFontSmall", lx, ly,
			bHover and color_white or ColorAlpha(color_white, 200 * a),
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

		draw.NoTexture()
	end

	-- Центральная ступица.
	surface.SetDrawColor(0, 0, 0, 210 * a)
	FillCircle(cx, cy, innerR * 0.94, 40)

	-- Тонкое акцентное кольцо вокруг ступицы.
	surface.SetDrawColor(accent.r, accent.g, accent.b, 220 * a)
	FillSector(cx, cy, innerR * 0.94 - 1.5, innerR * 0.94, 0, 360, 48)

	draw.NoTexture()

	-- Центр: наведённый пункт, иначе имя/описание цели. Имя нераспознанного —
	-- это длинное физ-описание, поэтому переносим по строкам и держим ВНУТРИ
	-- ступицы, чтобы текст не вылезал на кнопки.
	local title = self.hovered > 0 and self.options[self.hovered].label or (self.centerName or "")
	title = title:utf8upper()

	if (utf8.len(title) > 64) then
		title = utf8.sub(title, 1, 61) .. "..."
	end

	local titleFont = "ixMenuButtonFontSmall"
	local maxW = innerR * 1.45

	surface.SetFont(titleFont)
	local _, lineH = surface.GetTextSize("Ag")
	local lines = ix.util.WrapText(title, maxW, titleFont)

	local gap = math.max(4, lineH * 0.3)
	local totalH = (#lines + 1) * lineH + gap -- +1 строка под подсказку
	local y = cy - totalH * 0.5 + lineH * 0.5

	local titleCol = self.hovered > 0 and ColorAlpha(color_white, 255 * a) or ColorAlpha(accent, 255 * a)

	for _, line in ipairs(lines) do
		draw.SimpleText(line, titleFont, cx, y, titleCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		y = y + lineH
	end

	y = y + gap
	draw.SimpleText("ЛКМ — ВЫБОР", titleFont, cx, y, ColorAlpha(color_white, 150 * a),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:OnMousePressed(code)
	if (self.bClosing) then return end

	if (code == MOUSE_LEFT) then
		if (self.hovered > 0 and self.options[self.hovered]) then
			if (IsValid(LocalPlayer())) then
				LocalPlayer():EmitSound("Helix.Press")
			end
			self:CloseMenu(false, self.options[self.hovered].callback)
		else
			self:CloseMenu(true)
		end
	elseif (code == MOUSE_RIGHT) then
		self:CloseMenu(true)
	end
end

function PANEL:CloseMenu(bCancel, action)
	if (self.bClosing) then return end

	self.bClosing = true
	self.pendingAction = (!bCancel) and action or nil

	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)
	gui.EnableScreenClicker(false)
end

function PANEL:OnRemove()
	if (ix.gui.charRadial == self) then
		ix.gui.charRadial = nil
	end
end

vgui.Register("ixCharRadialMenu", PANEL, "EditablePanel")

-- Перехват стандартного меню сущности: для живых персонажей открываем радиальное.
function PLUGIN:ShowEntityMenu(entity)
	if (!IsValid(entity) or !entity:IsPlayer()) then return end
	if (entity == LocalPlayer()) then return end
	if (!entity:GetCharacter()) then return end

	if (IsValid(ix.gui.charRadial)) then
		return true
	end

	local panel = vgui.Create("ixCharRadialMenu")
	panel:SetTarget(entity)

	ix.gui.charRadial = panel

	return true -- подавляем стандартный список опций
end
