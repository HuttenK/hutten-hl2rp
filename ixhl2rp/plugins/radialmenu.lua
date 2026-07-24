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

-- UTF-8-безопасный перенос по словам (только по пробелам). Штатный ix.util.WrapText
-- при длинном слове режет его «посимвольно» через байтовую индексацию word[i]
-- (sh_util.lua), что рвёт многобайтовую кириллицу и рисует «?». Здесь слова не
-- разбиваем — длинное слово просто остаётся целой строкой.
local function WrapTextSafe(text, maxW, font)
	surface.SetFont(font)

	if (surface.GetTextSize(text) <= maxW) then
		return {text}
	end

	local lines = {}
	local line = ""

	for _, word in ipairs(string.Explode(" ", text)) do
		local try = (line == "") and word or (line .. " " .. word)

		if (line != "" and surface.GetTextSize(try) > maxW) then
			lines[#lines + 1] = line
			line = word
		else
			line = try
		end
	end

	if (line != "") then
		lines[#lines + 1] = line
	end

	return lines
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

-- Запуск функции предмета на клиенте через штатное сетевое сообщение инвентаря
-- Helix (item.action). Сервер сам выполнит OnRun: каст-бар (SetAction), модификатор
-- навыка медицины и расход использований. У функции inject цель определяется по
-- прицелу (трасса 96 ед.); курсор меню не меняет угол обзора, поэтому персонаж,
-- на которого смотрит игрок, остаётся под прицелом.
local function RunItemFunction(item, key, data)
	local func = item and item.functions and item.functions[key]
	if (!func or func.index == nil or !item.id) then return end

	net.Start("item.action")
		net.WriteUInt(item.id, 32)
		net.WriteUInt(item.inventory_id or 0, 32)
		net.WriteUInt(func.index, item.functions_bits)
		net.WriteTable(data or {})
		net.WriteBool(false) -- без разбиения стака
	net.SendToServer()
end

-- Подменю ампутации: показывается, только если у игрока есть подходящий клинок
-- и навык медицины 5. Согласие цели спрашивает сервер.
local function BuildAmputationOptions(target)
	local client = LocalPlayer()

	if (!ix.Amputation or !client.GetItems) then return {} end
	if (!ix.Amputation.HasSkill(client:GetCharacter())) then return {} end

	local tool

	for _, item in ipairs(client:GetItems()) do
		if (istable(item) and ix.Amputation.IsTool(item)) then
			tool = item
			break
		end
	end

	if (!tool) then return {} end

	local options = {}

	for _, key in ipairs({"larm", "rarm", "lleg", "rleg"}) do
		options[#options + 1] = {
			label = L(ix.Amputation.limbs[key].phrase),
			icon = "icon16/cut.png",
			callback = function()
				if (IsValid(target)) then
					RunItemFunction(tool, "amputate", {limb = key})
				end
			end
		}
	end

	return options
end

-- Подменю пришивания: по одной опции на каждую носимую отрезанную конечность.
-- Совпадение конечности с недостающей проверяет сервер (functions.reattach).
local function BuildReattachOptions(target)
	local client = LocalPlayer()

	if (!ix.Amputation or !client.GetItems) then return {} end
	if (!ix.Amputation.HasSkill(client:GetCharacter())) then return {} end

	local options = {}

	for _, item in ipairs(client:GetItems()) do
		if (!istable(item) or !item.limb or !item.functions or !item.functions.reattach) then continue end

		options[#options + 1] = {
			label = (item.GetName and item:GetName()) or item.name or item.uniqueID,
			icon = "icon16/user_add.png",
			callback = function()
				if (IsValid(target)) then
					RunItemFunction(item, "reattach")
				end
			end
		}
	end

	return options
end

-- Подменю медикаментов: по одной опции на КАЖДЫЙ вид носимого медицинского
-- предмета (бинт, аптечка, пакет крови и т.п.). Радиальное меню открывается
-- только при взгляде на другого персонажа, поэтому применение всегда идёт на
-- цель — через функцию inject базового предмета medical.
local function BuildMedicalOptions(target)
	local client = LocalPlayer()
	if (!client.GetItems) then return {} end

	local groups = {}
	local order = {}

	-- Признак «медицинский предмет» — наличие функции inject (её определяет
	-- только база medical: bandage/bloodbag/healthkit и т.п.). Поле .base тут
	-- ненадёжно — предметы используют кастомный фреймворк class("ItemMedical").
	for _, item in ipairs(client:GetItems()) do
		if (!istable(item) or !item.functions or !item.functions.inject) then continue end

		local uid = item.uniqueID
		local g = groups[uid]

		if (g) then
			g.count = g.count + 1
		else
			g = {
				item = item,
				count = 1,
				name = (item.GetName and item:GetName()) or item.name or uid
			}

			groups[uid] = g
			order[#order + 1] = g
		end
	end

	table.sort(order, function(a, b) return a.name < b.name end)

	local options = {}

	for _, g in ipairs(order) do
		local item = g.item
		local label = (g.count > 1) and string.format("%s (x%d)", g.name, g.count) or g.name

		options[#options + 1] = {
			label = label,
			icon = "icon16/heart.png",
			callback = function()
				if (IsValid(target)) then
					RunItemFunction(item, "inject")
				end
			end
		}
	end

	return options
end

-- Строит список опций для радиального меню по цели.
--  target     — игрок (для живого — он сам, для лежачего — владелец prop_ragdoll).
--  menuEntity — сущность для контекстных опций и проверок валидности
--               (живой игрок либо его prop_ragdoll).
--  isRagdoll  — цель в нокдауне/лежачем состоянии (взаимодействие через рэгдолл).
local function BuildOptions(target, menuEntity, isRagdoll)
	local options = {}

	if (!isRagdoll) then
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
	else
		-- Лежачего обыскиваем через систему searchragdoll: серверный обработчик
		-- rp.search.ragdoll трассирует прицел и открывает инвентарь рэгдолла.
		options[#options + 1] = {
			label = "Обыскать",
			icon = "icon16/magnifier.png",
			callback = function()
				if (IsValid(menuEntity)) then
					net.Start("rp.search.ragdoll")
						net.WriteEntity(menuEntity)
					net.SendToServer()
				end
			end
		}
	end

	options[#options + 1] = {
		label = "Запомнить",
		icon = "icon16/user_comment.png",
		callback = function() DoRecognize(target) end
	}

	-- Уколоть транквилизатором — только по стоящему игроку (инъектор не берёт
	-- лежачего) и только если он есть в инвентаре. Применение делает серверный
	-- обработчик OnPlayerOptionSelected в плагине transvil.
	if (!isRagdoll and LocalPlayer():HasItem("tranq_injector")) then
		options[#options + 1] = {
			label = "Усыпить",
			callback = function()
				if (IsValid(target)) then
					ix.menu.NetworkChoice(target, "TranqInject")
				end
			end
		}
	end

	-- Медикаменты — применить носимый медпрепарат на цель. Работает и по лежачему:
	-- функция inject на сервере резолвит prop_ragdoll → игрока по прицелу.
	-- Ампутация и пришивание — это тоже медицина, поэтому лежат внутри «Лечить».
	local medical = BuildMedicalOptions(target)

	-- Резать и шить можно только стоящего: серверные проверки всё равно
	-- трассируют прицел в живого игрока, а не в его рэгдолл.
	if (!isRagdoll) then
		local amputation = BuildAmputationOptions(target)

		if (#amputation > 0) then
			medical[#medical + 1] = {
				label = L("amputation.cut"),
				icon = "icon16/cut.png",
				children = amputation
			}
		end

		local reattach = BuildReattachOptions(target)

		if (#reattach > 0) then
			medical[#medical + 1] = {
				label = L("amputation.reattach"),
				icon = "icon16/user_add.png",
				children = reattach
			}
		end
	end

	if (#medical > 0) then
		options[#options + 1] = {
			label = "Лечить",
			icon = "icon16/heart.png",
			children = medical
		}
	end

	-- Контекстные опции от плагинов: GetPlayerEntityMenu у живого игрока либо меню
	-- рэгдолла. У prop_ragdoll метод может отсутствовать — поэтому проверяем.
	local dynamic = isfunction(menuEntity.GetEntityMenu) and menuEntity:GetEntityMenu(LocalPlayer())

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

					if (status != false and IsValid(menuEntity)) then
						ix.menu.NetworkChoice(menuEntity, key, status)
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
	self.menuStack = {} -- для вложенных меню (Медикаменты → предметы)

	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(true)
	self:MakePopup()

	if (IsValid(LocalPlayer())) then
		LocalPlayer():EmitSound("Helix.Rollover")
	end
end

function PANEL:SetTarget(target, menuEntity, isRagdoll)
	self.target = target
	self.menuEntity = menuEntity or target
	self.isRagdoll = isRagdoll or false
	self.options = BuildOptions(target, self.menuEntity, self.isRagdoll)

	for i = 1, #self.options do
		self.scales[i] = 1
	end

	self.centerName = hook.Run("GetCharacterName", target, "ic") or "Цель"
end

-- Сброс состояния под новый набор опций + повтор анимации «выезда» кольца.
function PANEL:ResetForLevel()
	self.hovered = 0
	self.scales = {}

	for i = 1, #self.options do
		self.scales[i] = 1
	end

	self.openFrac = 0

	if (IsValid(LocalPlayer())) then
		LocalPlayer():EmitSound("Helix.Rollover")
	end
end

-- Открыть вложенное меню. Опция «Назад» добавляется автоматически.
function PANEL:PushOptions(options, centerName)
	self.menuStack[#self.menuStack + 1] = {
		options = self.options,
		centerName = self.centerName
	}

	local newOptions = {}

	for _, opt in ipairs(options) do
		newOptions[#newOptions + 1] = opt
	end

	newOptions[#newOptions + 1] = {
		label = "Назад",
		icon = "icon16/arrow_left.png",
		isBack = true
	}

	self.options = newOptions
	self.centerName = centerName or self.centerName
	self:ResetForLevel()
end

-- Вернуться на уровень выше. Возвращает false, если мы уже в корне.
function PANEL:PopOptions()
	local entry = self.menuStack[#self.menuStack]
	if (!entry) then return false end

	self.menuStack[#self.menuStack] = nil
	self.options = entry.options
	self.centerName = entry.centerName
	self:ResetForLevel()

	return true
end

function PANEL:Think()
	-- Закрываемся, если цель пропала, либо лежачий встал/исчез его рэгдолл.
	if (!IsValid(self.target) or (self.isRagdoll and !IsValid(self.menuEntity))) then
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
	-- Длинные названия переносим по строкам, чтобы текст не вылезал за сектор.
	local lblFont = "ixMenuButtonFontSmall"
	surface.SetFont(lblFont)
	local _, lblLineH = surface.GetTextSize("Ag")
	local lblMaxW = outerR * 0.7

	for i = 1, count do
		local opt = self.options[i]
		local centerAng = math.rad(-90 + (i - 1) * sweep)
		local scale = self.scales[i] or 1
		local midR = (innerR + outerR * scale) * 0.5
		local lx = cx + math.cos(centerAng) * midR
		local ly = cy + math.sin(centerAng) * midR
		local bHover = (i == self.hovered)
		local col = bHover and color_white or ColorAlpha(color_white, 200 * a)

		local lines = WrapTextSafe(opt.label:utf8upper(), lblMaxW, lblFont)
		local ty = ly - (#lines - 1) * lblLineH * 0.5

		for _, line in ipairs(lines) do
			draw.SimpleText(line, lblFont, lx, ty, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			ty = ty + lblLineH
		end
	end

	draw.NoTexture()

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
	local lines = WrapTextSafe(title, maxW, titleFont)

	local gap = math.max(4, lineH * 0.3)
	local totalH = (#lines + 1) * lineH + gap -- +1 строка под подсказку
	local y = cy - totalH * 0.5 + lineH * 0.5

	local titleCol = self.hovered > 0 and ColorAlpha(color_white, 255 * a) or ColorAlpha(accent, 255 * a)

	for _, line in ipairs(lines) do
		draw.SimpleText(line, titleFont, cx, y, titleCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		y = y + lineH
	end

	y = y + gap
	local hint = (#self.menuStack > 0) and "ПКМ — НАЗАД" or "ЛКМ — ВЫБОР"
	draw.SimpleText(hint, titleFont, cx, y, ColorAlpha(color_white, 150 * a),
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function PANEL:OnMousePressed(code)
	if (self.bClosing) then return end

	if (code == MOUSE_LEFT) then
		local opt = self.hovered > 0 and self.options[self.hovered]

		if (opt) then
			if (IsValid(LocalPlayer())) then
				LocalPlayer():EmitSound("Helix.Press")
			end

			if (opt.isBack) then
				self:PopOptions()
			elseif (opt.children) then
				self:PushOptions(opt.children, opt.label)
			else
				self:CloseMenu(false, opt.callback)
			end
		else
			self:CloseMenu(true)
		end
	elseif (code == MOUSE_RIGHT) then
		-- ПКМ — на уровень выше; в корне — закрыть меню.
		if (self:PopOptions()) then
			if (IsValid(LocalPlayer())) then
				LocalPlayer():EmitSound("Helix.Press")
			end
		else
			self:CloseMenu(true)
		end
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

-- По сущности под прицелом возвращает (target, menuEntity, isRagdoll) либо nil.
-- Живой игрок — он сам. prop_ragdoll лежачего/мертвого игрока — резолвим владельца
-- по сетевой переменной "doll" (ставится в !healthsystem на нокдаун, networked всем).
local function ResolveTarget(entity)
	if (!IsValid(entity)) then return end

	if (entity:IsPlayer()) then
		if (entity == LocalPlayer() or !entity:GetCharacter()) then return end
		return entity, entity, false
	end

	if (entity:GetClass() == "prop_ragdoll") then
		local ply = IsValid(entity.ixPlayer) and entity.ixPlayer or nil

		if (!IsValid(ply)) then
			for _, p in ipairs(player.GetAll()) do
				local doll = p:GetNetVar("doll")

				if (doll and Entity(doll) == entity) then
					ply = p
					break
				end
			end
		end

		if (IsValid(ply) and ply != LocalPlayer() and ply:GetCharacter()) then
			return ply, entity, true
		end
	end
end

-- Открыть радиальное меню по сущности (игрок или его рэгдолл). true — если открыли
-- (либо меню уже открыто), чтобы подавить стандартный список опций Helix.
function PLUGIN:OpenRadialOn(entity)
	local target, menuEntity, isRagdoll = ResolveTarget(entity)
	if (!target) then return end

	if (IsValid(ix.gui.charRadial)) then
		return true
	end

	local panel = vgui.Create("ixCharRadialMenu")
	panel:SetTarget(target, menuEntity, isRagdoll)

	ix.gui.charRadial = panel

	return true
end

-- Перехват стандартного меню сущности (живые персонажи + рэгдоллы, которым плагины
-- выдали GetEntityMenu).
function PLUGIN:ShowEntityMenu(entity)
	return self:OpenRadialOn(entity)
end

-- Лежачие/мертвые игроки — это prop_ragdoll БЕЗ GetEntityMenu (рассылка меню в
-- !healthsystem отключена), поэтому штатный E-поток (KeyRelease → ShowEntityMenu)
-- их не ловит. Ловим E здесь сами и открываем радиальное меню по рэгдоллу.
hook.Add("KeyRelease", "ixRadialRagdoll", function(client, key)
	if (key != IN_USE or client != LocalPlayer()) then return end
	if (ix.menu.IsOpen() or IsValid(ix.gui.charRadial)) then return end

	local data = {}
		data.start = client:GetShootPos()
		data.endpos = data.start + client:GetAimVector() * 96
		data.filter = client

	local entity = util.TraceLine(data).Entity

	if (IsValid(entity) and entity:GetClass() == "prop_ragdoll") then
		PLUGIN:OpenRadialOn(entity)
	end
end)
