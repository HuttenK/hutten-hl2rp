-- z_endingnotext: только слайды, затем стилизованный экран завершения
-- Без титров, без прокрутки текста

local SOUND_SLIDES = "sound/legends_ending.mp3"

local background_width, background_height = 1920, 1080

-- ─────────────────────────────────────────────
-- ШРИФТЫ
-- ─────────────────────────────────────────────

surface.CreateFont("ending.prompt.key", {
	font      = "Blender Pro Bold",
	extended  = true,
	size      = ix.UI.Scale(15),
	weight    = 700,
	antialias = true,
})

surface.CreateFont("ending.prompt.main", {
	font      = "Blender Pro Medium",
	extended  = true,
	size      = ix.UI.Scale(20),
	weight    = 400,
	antialias = true,
})

surface.CreateFont("ending.slide.text", {
	font      = "Blender Pro Book",
	extended  = true,
	size      = ix.UI.Scale(32),
	weight    = 500,
	antialias = true,
})

-- ─────────────────────────────────────────────
-- ПАНЕЛЬ
-- ─────────────────────────────────────────────

local PANEL = {}

local clrRed    = Color(248, 64,  64)
local clrRedDim = Color(248, 64,  64, 80)
local clrWhite  = Color(255, 255, 255)
local clrBlack  = Color(0,   0,   0)

function PANEL:Init()
	if IsValid(ix.gui.ending_notext) then
		ix.gui.ending_notext:Remove()
	end

	ix.gui.ending_notext = self

	self.slides   = {}
	self.database = {}

	-- Слайды: те же что и в оригинале — меняй по вкусу
	self:add_slide("ending_slide_1.png",   "Самое страшное позади. Вы слышите гул вертолетов. Мусор на дороге перед входом в госпиталь разлетается. Яркий свет слепит ваши глаза даже через маски.")
	self:add_slide("ending_slide_2.png",     "Один из последних эвакуационных вертолетов все же добрался до вас. Пилот не решается садиться, вместо этого вам лишь скидывают веревку. Даже сейчас вам приходится бороться за свое выживание. Вертолет с вами на борту улетает прочь из Нью-Йорка.")
	self:add_slide("ending_slide_3.png",   "Однако еще ничего не закончено. Поровнявшись с другими вертолетами, истошные крики доносятся из наушников пилота. Авиация врага никуда не делась. Американские истребители точечно работают по вам. Соседний вертолет, с такими же сотрудниками, взрывается прямо в воздухе.")
	self:add_slide("ending_slide_4.png",    "Следующая очередь авиационной пушки попадает по вам. Хвост вертолета взрывается, вы с трудом удерживаетесь внутри, пока вертолет все быстрее и быстрее закручивается... и опускается вниз.")
	self:add_slide("ending_slide_5.png",    "Крушение... Нос вертолета выглядывает из мелкого озера. Рядом плавают и целые тела, и окровавленные ошметки. Кто-то из вас точно погиб, кому-то пришлось еще дергаться в муках, дожидаясь медленной смерти. Но может быть кто-то выжил?..")

	self.initialized     = false
	self.allow_disconnect = false
	self.show_prompt     = false
	self.prompt_alpha    = 0

	self.current_slide = 0
	self.alpha         = 0
	self.data          = {}

	self.channel_slides = nil
	self.vol_slides     = 0

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetCursor("blank")
	self:SetAlpha(0)
	self:AlphaTo(255, 3, 0)

	timer.Simple(4, function()
		if not IsValid(self) then return end
		self:move_slide()
		self:play_slides_music()
	end)
end

-- ─────────────────────────────────────────────
-- АУДИО
-- ─────────────────────────────────────────────

function PANEL:play_slides_music()
	if IsValid(self.channel_slides) then self.channel_slides:Stop() end

	sound.PlayFile(SOUND_SLIDES, "noblock", function(channel)
		if not IsValid(channel) then return end
		channel:EnableLooping(true)
		channel:SetVolume(0)
		self.channel_slides = channel
		self.vol_slides = 0

		self:CreateAnimation(2, {
			index        = 10,
			target       = { vol_slides = 1 },
			bIgnoreConfig = true,
			Think = function(_, panel)
				if IsValid(panel.channel_slides) then
					panel.channel_slides:SetVolume(panel.vol_slides)
				end
			end
		})
	end)
end

function PANEL:fade_out_slides(duration)
	self:CreateAnimation(duration, {
		index        = 11,
		target       = { vol_slides = 0 },
		bIgnoreConfig = true,
		Think = function(_, panel)
			if IsValid(panel.channel_slides) then
				panel.channel_slides:SetVolume(panel.vol_slides)
			end
		end,
		OnComplete = function(_, panel)
			if IsValid(panel.channel_slides) then
				panel.channel_slides:Stop()
				panel.channel_slides = nil
			end
		end
	})
end

-- ─────────────────────────────────────────────
-- СЛАЙДЫ
-- ─────────────────────────────────────────────

function PANEL:add_slide(material, text)
	self.slides[#self.slides + 1] = {
		material = ix.util.GetMaterial(material),
		text     = text
	}
end

function PANEL:get_slides()
	return self.slides
end

function PANEL:animate()
	self.alpha = 0

	self:CreateAnimation(2.5, {
		index        = 1,
		target       = { alpha = 255 },
		easing       = "outQuint",
		bIgnoreConfig = true,
		Think = function(_, panel)
			panel.alpha = panel.alpha or 0
		end,
		OnComplete = function(_, panel)
			timer.Simple(15, function()
				if not IsValid(panel) then return end

				-- Последний слайд: начинаем затухание музыки
				if panel.current_slide == #panel:get_slides() then
					panel:fade_out_slides(3)
				end

				panel:CreateAnimation(2.5, {
					index        = 2,
					target       = { alpha = 0 },
					easing       = "inQuint",
					bIgnoreConfig = true,
					Think = function(_, pnl)
						pnl.alpha = pnl.alpha or 0
					end,
					OnComplete = function(_, pnl)
						if IsValid(pnl) then pnl:move_slide() end
					end
				})
			end)
		end
	})
end

function PANEL:move_slide()
	self.initialized   = true
	self.current_slide = self.current_slide + 1

	if self.current_slide > #self:get_slides() then
		return self:finish()
	end

	self.data.material = self:get_slides()[self.current_slide].material
	self.data.text     = self:get_slides()[self.current_slide].text

	self:animate()
end

-- ─────────────────────────────────────────────
-- ФИНАЛ: чёрный экран + приглашение выйти
-- ─────────────────────────────────────────────

function PANEL:finish()
	self.data        = {}
	self.initialized = false

	-- Небольшая пауза, затем появляется приглашение
	timer.Simple(1.5, function()
		if not IsValid(self) then return end
		self.show_prompt     = true
		self.allow_disconnect = true

		-- Плавное появление подписи
		self:CreateAnimation(2.5, {
			index        = 20,
			target       = { prompt_alpha = 255 },
			easing       = "outQuint",
			bIgnoreConfig = true,
		})
	end)
end

-- ─────────────────────────────────────────────
-- РЕНДЕР
-- ─────────────────────────────────────────────

function PANEL:Paint(w, h)
	-- Чёрный фон
	surface.SetDrawColor(clrBlack)
	surface.DrawRect(0, 0, w, h)
end

function PANEL:PaintOver(w, h)
	-- Слайд
	if self.initialized then
		local x   = w * 0.5 - background_width  * 0.5
		local y   = h * 0.5 - background_height * 0.5
		local a   = self.alpha or 0

		surface.SetDrawColor(255, 255, 255, a)
		if self.data.material then
			surface.SetMaterial(self.data.material)
			surface.DrawTexturedRect(x, y, background_width, background_height)
		end

		-- Текст слайда (вверху, с тёмной подложкой)
		if self.data.text then
			surface.SetTextColor(ColorAlpha(clrWhite, a))
			surface.SetDrawColor(0, 0, 0, math.Clamp(a, 0, 160))

			local lines   = ix.util.WrapText(self.data.text, w * 0.5, "ending.slide.text")
			local text_y  = 32
			surface.SetFont("ending.slide.text")

			for _, line in ipairs(lines) do
				local tw, th = surface.GetTextSize(line)
				surface.DrawRect(w * 0.5 - tw * 0.5 - 12, text_y, tw + 24, th + 2)
				surface.SetTextPos(w * 0.5 - tw * 0.5, text_y + 2)
				surface.DrawText(line)
				text_y = text_y + th + 2
			end
		end
	end

	-- Экран завершения
	if self.show_prompt then
		local pa  = self.prompt_alpha or 0
		local cx  = w * 0.5
		local cy  = h * 0.5
		local gap = ix.UI.Scale(10)
		local pad = ix.UI.Scale(6)

		-- Мерцание клавиши
		local pulse    = math.abs(math.sin(CurTime() * 1.4))
		local keyAlpha = math.Clamp(pa * (0.55 + pulse * 0.45), 0, 255)

		-- Измеряем все три элемента строки
		surface.SetFont("ending.prompt.main")
		local lw, lh = surface.GetTextSize("нажмите")
		local rw, rh = surface.GetTextSize("чтобы завершить игру")

		surface.SetFont("ending.prompt.key")
		local kw, kh = surface.GetTextSize("ПРОБЕЛ")

		local kbW = kw + pad * 2
		local kbH = kh + pad * 2

		-- Высота строки — самый высокий элемент
		local rowH   = math.max(lh, kbH, rh)
		local totalW = lw + gap + kbW + gap + rw
		local startX = cx - totalW * 0.5

		-- Вертикальные якоря для каждого элемента (всё выровнено по центру cy)
		local textY_left  = cy - lh  * 0.5
		local textY_right = cy - rh  * 0.5
		local boxY        = cy - kbH * 0.5
		local boxX        = startX + lw + gap

		-- Декоративные линии с отступом от строки
		local lineMargin = ix.UI.Scale(14)
		local lineTop    = cy - rowH * 0.5 - lineMargin
		local lineBot    = cy + rowH * 0.5 + lineMargin
		local lineLeft   = startX - ix.UI.Scale(20)
		local lineRight  = startX + totalW + ix.UI.Scale(20)
		local notch      = ix.UI.Scale(5)

		surface.SetDrawColor(ColorAlpha(clrRed, pa))
		-- Верхняя линия
		surface.DrawRect(lineLeft,  lineTop, lineRight - lineLeft, 1)
		-- Нижняя линия
		surface.DrawRect(lineLeft,  lineBot, lineRight - lineLeft, 1)
		-- Вертикальные засечки по углам
		surface.DrawRect(lineLeft,  lineTop - notch, 1, notch * 2 + 1)
		surface.DrawRect(lineRight, lineTop - notch, 1, notch * 2 + 1)
		surface.DrawRect(lineLeft,  lineBot - notch, 1, notch * 2 + 1)
		surface.DrawRect(lineRight, lineBot - notch, 1, notch * 2 + 1)

		-- Кнопка [ПРОБЕЛ]: заливка + рамка
		surface.SetDrawColor(ColorAlpha(clrRed, keyAlpha * 0.22))
		surface.DrawRect(boxX, boxY, kbW, kbH)
		surface.SetDrawColor(ColorAlpha(clrRed, keyAlpha))
		surface.DrawOutlinedRect(boxX, boxY, kbW, kbH)

		surface.SetFont("ending.prompt.key")
		surface.SetTextColor(ColorAlpha(clrRed, keyAlpha))
		surface.SetTextPos(boxX + pad, boxY + pad)
		surface.DrawText("ПРОБЕЛ")

		-- "нажмите" слева от кнопки
		surface.SetFont("ending.prompt.main")
		surface.SetTextColor(ColorAlpha(clrWhite, pa * 0.75))
		surface.SetTextPos(startX, textY_left)
		surface.DrawText("нажмите")

		-- "чтобы завершить игру" справа от кнопки
		surface.SetTextPos(boxX + kbW + gap, textY_right)
		surface.DrawText("чтобы завершить игру")
	end
end

-- ─────────────────────────────────────────────
-- ВВОД / ОЧИСТКА
-- ─────────────────────────────────────────────

function PANEL:Think()
	if self.allow_disconnect and input.IsKeyDown(KEY_SPACE) then
		RunConsoleCommand("disconnect")
	end
end

function PANEL:OnRemove()
	if IsValid(self.channel_slides) then self.channel_slides:Stop() end
end

vgui.Register("ui.cellar.ending.notext", PANEL, "EditablePanel")

net.Receive("autonomous.ending.notext", function()
	vgui.Create("ui.cellar.ending.notext")
end)
