
function Schema:PopulateCharacterInfo(client, character, tooltip)
	if (client:IsRestricted()) then
		local panel = tooltip:AddRowAfter("rarity", "ziptie")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("tiedUp"))
		panel:SizeToContents()
	elseif (client:GetNetVar("tying")) then
		local panel = tooltip:AddRowAfter("rarity", "ziptie")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("beingTied"))
		panel:SizeToContents()
	elseif (client:GetNetVar("untying")) then
		local panel = tooltip:AddRowAfter("rarity", "ziptie")
		panel:SetBackgroundColor(derma.GetColor("Warning", tooltip))
		panel:SetText(L("beingUntied"))
		panel:SizeToContents()
	end
end

do
	local chatTypes = {
		["ic"] = true,
		["w"] = true,
		["y"] = true,
		["radio"] = true,
		["request"] = true,
		["dispatch"] = true,
		["dispatch_radio"] = true
	}

	function Schema:ShouldPlayTypingBeep(client, chatType)
		return client:IsCombine() and chatTypes[chatType] and client:GetMoveType() != MOVETYPE_NOCLIP
	end
end

function Schema:ChatTextChanged(text)
	if (LocalPlayer():IsCombine()) then -- and (text:sub(1, 1):find("%w") or text:find("/%a+%s"))) then
		local chatType = ix.chat.Parse(LocalPlayer(), text, true)

		if (self:ShouldPlayTypingBeep(LocalPlayer(), chatType)) then
			netstream.Start("PlayerChatTextChanged", chatType)
		end
	end
end

function Schema:FinishChat()
	netstream.Start("PlayerFinishChat")
end

function Schema:GetPlayerEntityMenu(client, options)
	local callingPlayer = LocalPlayer()

	if (!callingPlayer:IsRestricted() and client:IsRestricted() and !client:GetNetVar("untying")) then
		options["Untie"] = true
		options["Search"] = true
	elseif (!callingPlayer:IsRestricted() and !client:IsRestricted() and !client:GetNetVar("tying") and
		callingPlayer:HasItem("ziptie")) then
			options["Ziptie"] = true
	end
end

-- Случайные строки фонового статуса на оверлее Гражданской Обороны.
-- Раньше таблица не была определена — фича молчала из-за бага с таймером.
-- Записи — простые строки или {аргумент, функция} (текст = функция(аргумент)).
Schema.randomDisplayLines = Schema.randomDisplayLines or {
	"СКАНИРОВАНИЕ СЕКТОРА...",
	"БИОСИГНАЛ: В НОРМЕ",
	"СВЯЗЬ С НАДЗОРОМ: АКТИВНА",
	"ПАТРУЛЬНЫЙ МАРШРУТ: СОБЛЮДАЕТСЯ",
	"УРОВЕНЬ УГРОЗЫ: НИЗКИЙ",
	"МОНИТОРИНГ ГРАЖДАН...",
	"ПРОТОКОЛ ПОДАВЛЕНИЯ: ГОТОВ",
	"ЭНЕРГОЩИТ: 100%",
	"СИНХРОНИЗАЦИЯ С СЕТЬЮ АЛЬЯНСА...",
	"ОБРАБОТКА БИОМЕТРИИ...",
}

function Schema:CharacterLoaded(character)
	if (character:IsCombine()) then
		vgui.Create("ixCombineDisplay")

		timer.Create("ixRandomDisplayLines", 12, 0, function()
			local client = LocalPlayer()

			if (IsValid(client) and client:IsCombine()) then
				local lines = self.randomDisplayLines

				if (!lines or #lines == 0) then return end

				local text = lines[math.random(1, #lines)]

				if (istable(text)) then
					text = text[2](text[1]) or ""
				end

				if (text and self.LastRandomDisplayLine != text) then
					self:AddCombineDisplayMessage(text)

					self.LastRandomDisplayLine = text
				end
			else
				self.LastRandomDisplayLine = nil

				timer.Remove("ixRandomDisplayLines")
			end
		end)
	elseif (IsValid(ix.gui.combine)) then
		ix.gui.combine:Remove()

		timer.Remove("ixRandomDisplayLines")
	end
end

function Schema:PlayerFootstep(client, position, foot, soundName, volume)
	return true
end

local colorModify = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = -0.015,
	["$pp_colour_contrast"] = 1.2,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

-- Use base HL2 material as fallback if custom combine_mockup5 is missing
local _combineOverlayMat = ix.util.GetMaterial("effects/combine_mockup5")
local combineOverlay = (_combineOverlayMat and not _combineOverlayMat:IsError()) and _combineOverlayMat or Material("effects/combine_mockup4")

function Schema:ShouldShowPlayerOnScoreboard(client)
	local clientFaction = LocalPlayer():Team()
	local playerFaction = client:Team()

	if (playerFaction == clientFaction) then
		return
	end
end

function Schema:CanDrawAmmoHUD(weapon)
	return false
end

-- Скрываем стандартный GMod-отображение боезапаса (иконка + счётчик справа снизу)
local hiddenHudElements = {
	["CHudAmmo"]          = true,
	["CHudSecondaryAmmo"] = true,
}

function Schema:HUDShouldDraw(name)
	if hiddenHudElements[name] then
		return false
	end
end

function Schema:IsPlayerRecognized(target)

end

function Schema:IsRecognizedChatType(chatType)
	if (chatType == "mec" or chatType == "mel" or chatType == "med") then
		return true
	end
end

netstream.Hook("CombineDisplayMessage", function(text, color, arguments)
	if (IsValid(ix.gui.combine)) then
		ix.gui.combine:AddLine(text, color, nil, unpack(arguments))
	end
end)

netstream.Hook("PlaySound", function(sound)
	surface.PlaySound(sound)
end)

netstream.Hook("ixEmitQueuedSounds", function(sounds, delay, spacing, volume, pitch)
	ix.util.EmitQueuedSounds(LocalPlayer(), sounds, delay, spacing, volume, pitch)
end)

netstream.Hook("ixPlayLocalSound", function(path, position, level, pitch, volume)
	sound.Play(path, position, level, pitch, volume)
end)

function Schema:PopulateHelpMenu(tabs)
	tabs["activities"] = function(container)
		-- Полный справочник по системам сервера. {section=...} — заголовок раздела,
		-- {название, описание} — отдельная система.
		local guide = {
			{section = "Общение и отыгрыш"},
			{"Чат и отыгрыш", "Говорите голосом через обычный чат. /me — описание вашего действия, /it — описание окружения, /w — шёпот (малая дальность), /y — крик (большая дальность). Незнакомцы видны как «кто-то», пока вы не познакомитесь. Можно изучать и использовать разные языки."},
			{"Кубики и проверки", "/Roll — случайное число для разрешения спорных ситуаций в отыгрыше. /Dice — бросок кубика. /RollSkill и /RollStat — проверка с учётом вашего навыка или атрибута."},
			{"Рации", "Возьмите рацию в руки. /Radio <текст> — передать в эфир, /RadioYell и /RadioWhisper — громче или тише. /SetChannel — сменить частоту, /CharToggleChannel — слушать дополнительный канал."},
			{"Устройство связи", "Нужно носить «устройство связи». /Request <текст> отправляет запрос Гражданской Обороне (например, вызвать патруль или сообщить о происшествии). ГО отвечает командой /ReplyRequest."},
			{"Громкоговорители", "Гражданская Оборона объявляет через динамики: /loudspeaker <звук> проигрывает звук синхронно из всех громкоговорителей на карте, /loudspeakerstop — выключает."},
			{"Заметки", "/MyNotes — ваши личные записи, /CharNotes — заметки о персонаже. Удобно вести записи прямо в игре."},

			{section = "Персонаж и развитие"},
			{"Меню навыков и уровня", "/lvl открывает меню развития: тратьте очки на атрибуты и навыки. Навыки растут от использования и открывают новые рецепты крафта и действия."},
			{"Здоровье и раны", "Тело состоит из отдельных конечностей. Ранения вызывают кровотечение, боль и потерю функций. Лечитесь медикаментами — бинты, обезболивающее, аптечки; тяжёлые раны нужно обрабатывать, иначе наступит критическое состояние."},
			{"Голод и жажда", "Со временем растут голод и жажда. Ешьте и пейте (предметы еды и напитков), иначе пострадают самочувствие и выносливость."},
			{"Радиация", "В радиоактивных зонах вы накапливаете дозу. Противогаз с фильтром снижает урон, но фильтр изнашивается — следите за его качеством и меняйте вовремя."},
			{"Книги навыков", "Используйте книгу навыка из инвентаря, чтобы изучить или повысить соответствующий навык."},
			{"Падение и обморок", "/CharFallOver <секунды> — намеренно упасть (отыгрыш обморока, спотыкания, ранения). Подъём происходит автоматически по истечении времени."},

			{section = "Заработок и ремёсла"},
			{"Добыча ресурсов", "Кирка добывает руду, золото и титан из жил, топор — древесину из деревьев. Возьмите инструмент в руки и бейте по жиле или дереву, пока объект не разрушится и не выдаст сырьё."},
			{"Крафт", "Во вкладке крафта (в инвентаре) создавайте предметы из материалов. Рецепты привязаны к навыку «Крафт» и к станциям (верстак, оружейный стол). Чем выше навык, тем сложнее доступные схемы."},
			{"Готовка", "Из сырых продуктов готовьте еду на кухонной станции по кулинарным рецептам."},
			{"Фермерство", "Сажайте и выращивайте культуры, затем собирайте урожай — для еды и крафта."},
			{"Переработка", "На заводе переработки превращайте мусор и лом в полезные материалы для крафта."},
			{"Торговцы", "Подойдите к NPC-торговцу и нажмите взаимодействие (E), чтобы покупать и продавать товары за токены."},
			{"Бизнес", "Ведите своё дело на арендованной точке: /OpenBusiness — открыть, /CloseBusiness — закрыть, /AddCashRegister — поставить кассу, /GetCash — забрать выручку, /BusinessInfo — сведения о деле."},
			{"Личный сейф", "/vault открывает ваш персональный контейнер для хранения вещей."},
			{"Доска объявлений", "На терминале доски разместите заказ (заголовок, описание и желаемая оплата — текстом) или возьмите чужой. Детали раскрываются только после принятия; оплата и условия обсуждаются лично."},
			{"Лут и контейнеры", "Ящики и контейнеры в мире можно обыскивать — внутри случайные припасы, патроны, медикаменты или снаряжение."},
			{"Пайки", "В пунктах выдачи можно получить паёк (еда и припасы). Между выдачами действует интервал ожидания."},

			{section = "События и угрозы"},
			{"Зоны заражения", "Иногда появляется очаг с зомби и чужой флорой (Xen). Возьмите защитный мешок, зачистите заражённые объекты и утилизируйте биомассу — за это полагается награда. Действуйте сообща."},
			{"Затопление", "Во время событий вода поднимается в замкнутых зонах (канализация, подвалы, тоннели). Поставьте насос и бак, соедините их кабелем (наведитесь, TAB → ПКМ по технике) и запустите откачку. Несколько насосов и людей справятся быстрее."},
			{"ЭМИ-инструмент", "Наведитесь на цель и активируйте (ЛКМ), чтобы временно вскрыть замок Альянса, обесточить силовое поле, заглушить сканер контрабанды или обезвредить мину. После применения нужна перезарядка. Создаётся крафтом."},
			{"Транквилизатор", "Одноразовый дротомёт с нейротоксином: попадание валит цель примерно на 2 минуты — она всё видит и слышит, но не может двигаться. Создаётся крафтом по цепочке из Зен-сырья."},
			{"Транквилизаторный инъектор", "Контактная альтернатива дротомёту: подойдите вплотную, наведитесь на цель и примените предмет из инвентаря — после нескольких секунд удержания жертва падает с тем же эффектом нейротоксина. Тихо и для ближнего боя; расходуется за одно применение."},

			{section = "Документы и Гражданская Оборона"},
			{"Удостоверение (CID)", "Ваша гражданская карта удостоверяет личность. Гражданская Оборона может её считать; /CardImprint отпечатывает на карте данные."},
			{"Досье граждан", "Гражданская Оборона ведёт досье на жителей. Просматриваются на терминале досье или через КПК по номеру CID."},
			{"КПК / терминал досье", "Нажмите на терминал: меню предложит ввести CID, открыть ГО-Новости или Доску объявлений."},
			{"ГО-Новости", "На новостном терминале читайте сводки Гражданской Обороны; уполномоченные сотрудники могут публиковать новости через редактор."},
			{"Лоялист-терминалы", "Используйте терминал лоялиста, чтобы проверить свои очки лояльности."},
			{"Документы и бумаги", "Заполняйте, подписывайте и штампуйте документы (бланки, пропуска, протоколы). Бумаги печатаются и передаются из рук в руки для отыгрыша бюрократии."},

			{section = "Мир и предметы"},
			{"Двери и ключи", "Двери можно купить и выдавать к ним доступ. /DoorLock и /DoorUnlock — запереть или открыть. Физический ключ-предмет привязывается к двери: /KeyGive выдаёт ключ другому игроку."},
			{"Замки и поля Альянса", "Гражданская Оборона устанавливает замки Альянса, силовые поля и сканеры контрабанды для контроля территории и проверки граждан."},
			{"Точки навигации", "Некоторые фракции видят и ставят маркеры на местности: /WaypointAdd, /WaypointUpdate, /WaypointRemove."},
			{"Бумбокс и кассеты", "Поставьте бумбокс и вставьте кассету-предмет — музыка играет в 3D-пространстве вокруг устройства."},
			{"ТВ и экраны", "На телевизорах и экранах карты можно показывать синхронную картинку или видео (управляется Гражданской Обороной и администрацией)."},
			{"Статичные надписи", "/SceneText создаёт постоянную текстовую табличку в мире — вывески, указатели, объявления."},
			{"Фонарик", "Используйте предмет-фонарик, чтобы включать и выключать свет."},

			{section = "Управление и информация"},
			{"Меню F1", "Клавиша F1 открывает это информационное меню: занятия, список команд, голосовые строки и прочее."},
			{"Эмоции и позы", "Эмоции и act-команды задают анимации и позы для отыгрыша."},
			{"Удобство игры", "Автобег, компас, помощь при посадке на стулья, плавный обзор от первого лица и видимые собственные ноги — для комфортной игры."},
			{"Полезные команды", "/Guide — игровой гайд, /Rules — правила сервера, /Discord — ссылка на Discord, /Content — контент-паки."},
		}

		for _, data in ipairs(guide) do
			if (data.section) then
				local header = container:Add("Panel")
				header:Dock(TOP)
				header:DockMargin(0, 12, 0, 6)
				header:SetTall(28)
				header.Paint = function(_, width, height)
					surface.SetDrawColor(ix.config.Get("color"))
					surface.DrawRect(0, 0, width, height)
				end

				local headerLabel = header:Add("DLabel")
				headerLabel:Dock(FILL)
				headerLabel:DockMargin(8, 0, 0, 0)
				headerLabel:SetFont("ixMediumFont")
				headerLabel:SetText(data.section:upper())
				headerLabel:SetContentAlignment(4)
				headerLabel:SetTextColor(color_white)
				headerLabel:SetExpensiveShadow(1, color_black)

				continue
			end

			local category = container:Add("Panel")
			category:Dock(TOP)
			category:DockMargin(0, 0, 0, 4)
			category:DockPadding(8, 8, 8, 8)
			category.Paint = function(_, width, height)
				surface.SetDrawColor(Color(0, 0, 0, 66))
				surface.DrawRect(0, 0, width, height)
			end

			local categoryLabel = category:Add("DLabel")
			categoryLabel:SetFont("ixMediumLightFont")
			categoryLabel:SetText(data[1]:upper())
			categoryLabel:Dock(FILL)
			categoryLabel:SetTextColor(ix.config.Get("color"))
			categoryLabel:SetExpensiveShadow(1, color_black)
			categoryLabel:SizeToContents()
			category:SizeToChildren(true, true)

			local description = container:Add("DLabel")
			description:SetFont("ixSmallFont")
			description:SetText(data[2])
			description:Dock(TOP)
			description:SetTextColor(color_white)
			description:SetExpensiveShadow(1, color_black)
			description:SetWrap(true)
			description:SetAutoStretchVertical(true)
			description:SizeToContents()
			description:DockMargin(0, 0, 0, 8)
		end
	end

	tabs["voices"] = function(container)
		local classes = {}

		for k, v in pairs(Schema.voices.classes) do
			if (v.condition(LocalPlayer())) then
				classes[#classes + 1] = k
			end
		end

		if (#classes < 1) then
			local info = container:Add("DLabel")
			info:SetFont("ixSmallFont")
			info:SetText(L("voices.noAccess"))
			info:SetContentAlignment(5)
			info:SetTextColor(color_white)
			info:SetExpensiveShadow(1, color_black)
			info:Dock(TOP)
			info:DockMargin(0, 0, 0, 8)
			info:SizeToContents()
			info:SetTall(info:GetTall() + 16)

			info.Paint = function(_, width, height)
				surface.SetDrawColor(ColorAlpha(derma.GetColor("Error", info), 160))
				surface.DrawRect(0, 0, width, height)
			end

			return
		end

		table.sort(classes, function(a, b)
			return a < b
		end)

		for _, class in ipairs(classes) do
			local category = container:Add("Panel")
			category:Dock(TOP)
			category:DockMargin(0, 0, 0, 8)
			category:DockPadding(8, 8, 8, 8)
			category.Paint = function(_, width, height)
				surface.SetDrawColor(Color(0, 0, 0, 66))
				surface.DrawRect(0, 0, width, height)
			end

			local categoryLabel = category:Add("DLabel")
			categoryLabel:SetFont("ixMediumLightFont")
			categoryLabel:SetText(class:upper())
			categoryLabel:Dock(FILL)
			categoryLabel:SetTextColor(color_white)
			categoryLabel:SetExpensiveShadow(1, color_black)
			categoryLabel:SizeToContents()
			category:SizeToChildren(true, true)

			for command, info in SortedPairs(self.voices.stored[class]) do
				local title = container:Add("DLabel")
				title:SetFont("ixMediumLightFont")
				title:SetText(command:upper())
				title:Dock(TOP)
				title:SetTextColor(ix.config.Get("color"))
				title:SetExpensiveShadow(1, color_black)
				title:SizeToContents()

				local description = container:Add("DLabel")
				description:SetFont("ixSmallFont")
				description:SetText(info.text)
				description:Dock(TOP)
				description:SetTextColor(color_white)
				description:SetExpensiveShadow(1, color_black)
				description:SetWrap(true)
				description:SetAutoStretchVertical(true)
				description:SizeToContents()
				description:DockMargin(0, 0, 0, 8)
			end
		end
	end
end

function Schema:RenderScreenspaceEffects()
	if (LocalPlayer():IsCombine() and combineOverlay and not combineOverlay:IsError()) then
		render.UpdateScreenEffectTexture()

		combineOverlay:SetFloat("$refractamount", 0.3)
		combineOverlay:SetFloat("$alpha", 0.5)
		combineOverlay:SetInt("$ignorez", 1)

		render.SetMaterial(combineOverlay)
		render.DrawScreenQuad()
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Sound Tape item — клиентские хуки
-- ─────────────────────────────────────────────────────────────────────────────

netstream.Hook("ixSoundTapeEdit", function(data)
	if IsValid(ix.gui.soundTapeEdit) then
		ix.gui.soundTapeEdit:Remove()
	end

	local frame = vgui.Create("DFrame")
	frame:SetTitle("Sound Tape — Edit")
	frame:SetSize(420, 160)
	frame:Center()
	frame:MakePopup()
	ix.gui.soundTapeEdit = frame

	local labelSound = frame:Add("DLabel")
	labelSound:SetPos(10, 30)
	labelSound:SetText("Sound path (relative to sound/):")
	labelSound:SizeToContents()

	local entrySound = frame:Add("DTextEntry")
	entrySound:SetPos(10, 48)
	entrySound:SetSize(400, 22)
	entrySound:SetText(data.sound or "")
	entrySound:SetPlaceholderText("e.g. ambient/alarms/klaxon1.wav")

	local labelName = frame:Add("DLabel")
	labelName:SetPos(10, 76)
	labelName:SetText("Tape label (optional, visible to others):")
	labelName:SizeToContents()

	local entryLabel = frame:Add("DTextEntry")
	entryLabel:SetPos(10, 94)
	entryLabel:SetSize(400, 22)
	entryLabel:SetText(data.label or "")
	entryLabel:SetPlaceholderText("e.g. PA Announcement #4")

	local btnSave = frame:Add("DButton")
	btnSave:SetPos(10, 124)
	btnSave:SetSize(195, 24)
	btnSave:SetText("Save")
	btnSave.DoClick = function()
		netstream.Start("ixSoundTapeSave", {
			id    = data.id,
			sound = entrySound:GetText(),
			label = entryLabel:GetText(),
		})
		frame:Remove()
	end

	local btnTest = frame:Add("DButton")
	btnTest:SetPos(215, 124)
	btnTest:SetSize(195, 24)
	btnTest:SetText("Test sound")
	btnTest.DoClick = function()
		local snd = entrySound:GetText():Trim()
		if snd != "" then
			surface.PlaySound(snd)
		end
	end
end)

