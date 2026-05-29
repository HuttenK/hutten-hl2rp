local sound_path = "sound/pr_intro.mp3"

local background_width, background_height = 1920, 1080
local PANEL = {}

function PANEL:Init()
	if IsValid(ix.gui.intro) then
		ix.gui.intro:Remove()
	end

	ix.gui.intro = self

	self.slides = {}

	-- self:add_slide(path, text)
    self:add_slide("pr_intro_slide1.png", "Прошедшие войны показали, что ядерное оружие более не имеет никакого веса в этом мире: нет на этой планете тех, кто был бы готов его применить. Именно тогда встал вопрос о разработке нового средства массового поражения, что способно делать огромные территории непригодными для жизни в кратчайшие сроки.")
    self:add_slide("pr_intro_slide2.png", "Архипелаг Меидзима - давно забытое место. Ведущие мировые силы вновь отчаянно ищут способ уничтожить друг друга в новом конфликте и данный клочок земли стал самым настоящим сокровищем. Всё дело в военных лабораториях, построенных армией США ещё во времена холодной войны. Хотя комплексы давно заброшены, то, что разрабатывалось внутри, всё ещё представляет огромный интерес.")
    self:add_slide("pr_intro_slide3.png", "Каждый сектор Земного Альянса - по своей сути отдельное государство, отчитывающееся лишь перед одним человеком. Именно по этой причине они часто враждуют друг с другом, пытаясь заполучить расположения высших эшелонов власти на планете. Наличие нового оружия массового поражения - сильнейший козырь.")
    self:add_slide("pr_intro_slide4.png", "Несмотря на свои разногласия, Сектор 2 и 3 объединили силы по поиску био-оружия, спрятанного где-то на архипелаге. О прочности данного союза судить не приходится, однако перед каждой из сторон стоит одна общая цель: не дать сопротивлению заполучить эти разработки в свои руки.")

	self.initialized = false
	self.base_x = background_width
	self.current_slide = 0
	self.alpha = 0
	self.data = {}
	self.blur_alpha = 255

	self:SetSize(ScrW(), ScrH())
	self:SetPos(0, 0)
	self:MakePopup()
	self:SetCursor("blank")
	self:SetAlpha(0)

	self.channel = nil
	self.volume = 1

	-- Появляемся, затем начинаем слайды
	self:AlphaTo(255, 3, 0, function()
		timer.Simple(1, function()
			if IsValid(self) then
				self:move_slide()
			end
		end)

		sound.PlayFile(sound_path, "noblock", function(channel, status, error)
			if IsValid(channel) then
				channel:EnableLooping(false)
				channel:SetVolume(self.volume)
				self.channel = channel
			end
		end)
	end)
end

function PANEL:add_slide(material, text)
	self.slides[#self.slides + 1] = {material = ix.util.GetMaterial(material), text = text}
end

function PANEL:get_slides()
	return self.slides
end

-- Длительности: въезд 2с, появление текста 1с, показ 12с, уход текста 1с, выезд 1.5с
function PANEL:animate()
	self:CreateAnimation(2, {
		index = 1,
		target = {base_x = 0, blur_alpha = 0},
		easing = "outQuart",
		bIgnoreConfig = true,
		Think = function(animation, panel)
			panel.base_x = panel.base_x
			panel.blur_alpha = panel.blur_alpha
		end
	})
	:CreateAnimation(1, {
		index = 2,
		target = {alpha = 255},
		easing = "inQuint",
		bIgnoreConfig = true,
		Think = function(animation, panel)
			panel.alpha = panel.alpha
		end
	})
	:CreateAnimation(12, {
		index = 3,
		bIgnoreConfig = true
	})
	:CreateAnimation(1, {
		index = 4,
		target = {alpha = 0},
		easing = "outQuint",
		bIgnoreConfig = true,
		Think = function(animation, panel)
			panel.alpha = panel.alpha
		end,
		OnComplete = function(animation, panel)
			self:CreateAnimation(1.5, {
				index = 5,
				target = {base_x = -background_width, blur_alpha = 255},
				easing = "inQuart",
				bIgnoreConfig = true,
				Think = function(animation, panel)
					panel.base_x = panel.base_x
					panel.blur_alpha = panel.blur_alpha
				end,
				OnComplete = function(animation, panel)
					self:move_slide()
				end
			})
		end
	})
end

function PANEL:move_slide()
    self.initialized = true
    self.current_slide = self.current_slide + 1

    if self.current_slide > #self:get_slides() then
        return self:finish()
    end

    self.base_x = background_width
    self.blur_alpha = 255
    self.data.material = self:get_slides()[self.current_slide].material
    self.data.text = self:get_slides()[self.current_slide].text

    self:animate()
end

function PANEL:finish()
	local fade_time = 3.5 -- Длительность затухания
	local steps = 35 -- Количество шагов анимации
	local step_time = fade_time / steps
	
	local start_vol = 1
	if IsValid(self.channel) then
		start_vol = self.channel:GetVolume()
	end
	
	local start_alpha = self:GetAlpha()

	-- Надежный цикл, плавно снижающий звук и прозрачность
	for i = 1, steps do
		timer.Simple(step_time * i, function()
			if not IsValid(self) then return end
			
			local fraction = 1 - (i / steps) -- Идет от 1 до 0
			
			-- Плавно гасим саму панель
			self:SetAlpha(start_alpha * fraction)
			
			-- Плавно гасим звук
			if IsValid(self.channel) then
				self.channel:SetVolume(start_vol * fraction)
			end
		end)
	end

	-- Гарантированное удаление интерфейса после затухания
	timer.Simple(fade_time + 0.1, function()
		if IsValid(self) then 
			self:Remove() 
		end
	end)
end

function PANEL:OnRemove()
	if IsValid(self.channel) then
		self.channel:Stop()
	end

	ix.gui.intro = nil

	-- Восстанавливаем курсор на стандартный
	-- (MakePopup захватывает фокус, Remove его освобождает автоматически)
end

function PANEL:Paint(w, h)
	-- Заставляем отрисовку подчиняться прозрачности панели
	surface.SetAlphaMultiplier(self:GetAlpha() / 255)
	
	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, w, h)
	
	-- Обязательно сбрасываем множитель, чтобы не сломать другие элементы игры
	surface.SetAlphaMultiplier(1) 
end

function PANEL:PaintOver(w, h)
	surface.SetAlphaMultiplier(self:GetAlpha() / 255)
	
	if not self.initialized then 
		surface.SetAlphaMultiplier(1)
		return 
	end

	local x = self.base_x + w * 0.5 - background_width * 0.5
	local y = h * 0.5 - background_height * 0.5

	for i = 1, 3, 1 do
		surface.SetDrawColor(color_white)
		surface.SetMaterial(self.data.material)
		surface.DrawTexturedRect(x, y, background_width, background_height)
	end
	if self.blur_alpha > 0 then
    	ix.util.DrawBlurAt(x, y, background_width, background_height, 5, 0.1, self.blur_alpha)
	end

for i = 1, 3, 1 do
    surface.SetDrawColor(color_white)        -- reset color
    surface.SetMaterial(self.data.material)  -- reset material
    surface.DrawTexturedRect(x, y, background_width, background_height)
end
	surface.SetTextColor(ColorAlpha(color_white, self.alpha))
	surface.SetDrawColor(0, 0, 0, math.Clamp(0, self.alpha, 160))

	local lines = ix.util.WrapText(self.data.text, w * 0.5, "credits.book")
	local text_y = 32

	for i = 1, #lines do
		local line = lines[i]
		local text_width, text_height = surface.GetTextSize(line)

		surface.DrawRect(w * 0.5 - text_width * 0.5 - 12, text_y, text_width + 24, text_height + 2)
		surface.SetTextPos(w * 0.5 - text_width * 0.5, text_y + 1)
		surface.DrawText(line)

		text_y = text_y + text_height + 2
	end
	
	surface.SetAlphaMultiplier(1) -- Сбрасываем множитель в конце
end

--[[
surface.CreateFont("credits.book", {
	font = "Blender Pro Book",
	extended = true,
	size = ix.UI.Scale(32),
	weight = 500,
	antialias = true,
})
]]

vgui.Register("ui.cellar.intro", PANEL, "EditablePanel")

net.Receive("autonomous.intro", function()
	vgui.Create("ui.cellar.intro")
end)