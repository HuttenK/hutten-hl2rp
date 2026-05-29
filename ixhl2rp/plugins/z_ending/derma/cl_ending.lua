local disconnect_message = "НАЖМИТЕ [ПРОБЕЛ] ЧТОБЫ ЗАВЕРШИТЬ ИГРУ"

-- Укажите здесь пути к вашим аудиофайлам
local SOUND_SLIDES = "sound/slides_music.mp3"   
local SOUND_CREDITS = "sound/music_titles.mp3" 

local background_width, background_height = 1920, 1080
local PANEL = {}

function PANEL:Init()
    if IsValid(ix.gui.ending) then
        ix.gui.ending:Remove()
    end
    
    ix.gui.ending = self

    self.slides = {}
    self.database = {}
    
    self:add_slide("meetwithcps.png", "Каждый желает отобрать свободу у ближнего. Вы ощутили это как никто другой. Сперва Мак-Мердо, затем Техас. Вы ожидали увидеть выживших и сохранивших надежду людей, но встретили лишь порожденных Вселенским Союзом монстров.")
    self:add_slide("cpcruelty.png", "Некогда «бравые офицеры Гражданской Обороны», брошенные Альянсом в центре пустоши, одичали и озверели. Ведомый обидой и злобой, этот призрак Альянса будет терроризировать простых жителей Хьюстона еще долгие годы.")
    self:add_slide("trainescape.png", "В Хьюстоне ваш путь в качестве единой группы окончательно завершился. Выбравшие поезд полярники первыми покинули Техас — пути унесли их куда-то на запад. Сами того не осознавая, они направились в эпицентр всех бедствий — Чёрную Мезу.")
    self:add_slide("boatescape.png", "Течение устремилось на восток, в Мексиканский залив. Вы плыли несколько дней, пока на горизонте не показались огни... Один за другим проступали очертания домов. Цивилизация. Облегченно выдохнув, вы причалили к набережной, но резкий свет прожекторов ослепил вас. Десятки военных целились и кричали. Республика Флорида приветствует вас.")
    self:add_slide("gowitharmy.png", "Доверившись институтам старого мира, вы покинули Техас вместе с остатками армии Соединенных Штатов. К сожалению, вы не получили радушного приема, на который рассчитывали. Военная полиция схватила вас и долгие недели держала в карцерах, обращаясь с вами как с врагами и животными.")
    self:add_slide("staywithpc.png", "Не каждый способен сохранить человечность в условиях анархии и хаоса. Не все из вас захотели и дальше истязать себя неизвестностью, решив примкнуть к бывшим сотрудникам Обороны. Ваша дорога будет усеяна слезами и телами невинных людей, а жизнь вскоре оборвется в очередной перестрелке. Или нет?")

    self.initialized = false
    self.allow_disconnect = false

    self.current_slide = 0
    self.alpha = 0
    self.data = {}

    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetCursor("blank")
    
    -- Разделяем каналы аудио для кроссфейда
    self.channel_slides = nil
    self.channel_credits = nil
    self.vol_slides = 0
    self.vol_credits = 0

    self:SetAlpha(0)
    self:AlphaTo(255, 3, 0)

    timer.Simple(4, function()
        if not IsValid(self) then return end
        self:move_slide()
        self:play_slides_music(SOUND_SLIDES)
    end)
end

-- ========================================================
-- АУДИО ДВИЖОК ДЛЯ КРОССФЕЙДА (ДВА КАНАЛА)
-- ========================================================

-- Запуск музыки слайдов
function PANEL:play_slides_music(path)
    if IsValid(self.channel_slides) then self.channel_slides:Stop() end

    sound.PlayFile(path, "noblock", function(channel, status, error)
        if IsValid(channel) then
            channel:EnableLooping(true)
            channel:SetVolume(0) 
            self.channel_slides = channel
            self.vol_slides = 0
            
            self:CreateAnimation(2, {
                index = 10, 
                target = {vol_slides = 1},
                bIgnoreConfig = true, -- Игнорируем настройки UI анимаций игрока
                Think = function(anim, panel)
                    if IsValid(panel.channel_slides) then
                        panel.channel_slides:SetVolume(panel.vol_slides)
                    end
                end
            })
        end
    end)
end

-- Плавное затухание музыки слайдов
function PANEL:fade_out_slides(duration)
    self:CreateAnimation(duration, {
        index = 11, 
        target = {vol_slides = 0},
        bIgnoreConfig = true, -- Игнорируем настройки UI анимаций игрока
        Think = function(anim, panel)
            if IsValid(panel.channel_slides) then
                panel.channel_slides:SetVolume(panel.vol_slides)
            end
        end,
        OnComplete = function(anim, panel)
            -- Выключаем первый канал полностью, когда громкость на нуле
            if IsValid(panel.channel_slides) then
                panel.channel_slides:Stop()
                panel.channel_slides = nil
            end
        end
    })
end

-- Запуск музыки титров (начинает нарастать одновременно с затуханием слайдов)
function PANEL:play_credits_music(path, fade_time)
    if IsValid(self.channel_credits) then self.channel_credits:Stop() end

    sound.PlayFile(path, "noblock", function(channel, status, error)
        if IsValid(channel) then
            channel:EnableLooping(true)
            channel:SetVolume(0) 
            self.channel_credits = channel
            self.vol_credits = 0
            
            self:CreateAnimation(fade_time, {
                index = 12, 
                target = {vol_credits = 1},
                bIgnoreConfig = true, -- Игнорируем настройки UI анимаций игрока
                Think = function(anim, panel)
                    if IsValid(panel.channel_credits) then
                        panel.channel_credits:SetVolume(panel.vol_credits)
                    end
                end
            })
        end
    end)
end

-- ========================================================
-- ЛОГИКА СЛАЙДОВ И АНИМАЦИИ
-- ========================================================

function PANEL:add_slide(material, text)
    self.slides[#self.slides + 1] = {material = ix.util.GetMaterial(material), text = text}
end

function PANEL:get_slides()
    return self.slides
end

function PANEL:animate()
    self.alpha = 0

    self:CreateAnimation(2.5, {
        index = 1,
        target = { alpha = 255 },
        easing = "outQuint",
        bIgnoreConfig = true, -- ЖЕСТКО ЗАДАЕМ ВРЕМЯ АНИМАЦИИ
        Think = function(animation, panel)
            panel.alpha = panel.alpha or 0
        end,
        OnComplete = function(animation, panel)
            -- Удержание на экране 15 секунд
            timer.Simple(15, function()
                if not IsValid(panel) then return end
                
                -- КРОССФЕЙД: Если это последний слайд, запускаем смену музыки прямо сейчас
                if panel.current_slide == #panel:get_slides() then
                    panel:fade_out_slides(2.5) -- Музыка слайдов гаснет 2.5 сек
                    -- Музыка титров нарастает за 5 сек (очень кинематографично)
                    panel:play_credits_music(SOUND_CREDITS, 5) 
                end

                -- Затухание слайда
                panel:CreateAnimation(2.5, {
                    index = 2,
                    target = { alpha = 0 },
                    easing = "inQuint",
                    bIgnoreConfig = true, -- ЖЕСТКО ЗАДАЕМ ВРЕМЯ АНИМАЦИИ
                    Think = function(anim2, pnl2)
                        pnl2.alpha = pnl2.alpha or 0
                    end,
                    OnComplete = function(anim2, pnl2)
                        if IsValid(pnl2) then pnl2:move_slide() end
                    end
                })
            end)
        end
    })
end

function PANEL:move_slide()
    self.initialized = true
    self.current_slide = self.current_slide + 1

    if self.current_slide > #self:get_slides() then
        return self:finish()
    end

    self.data.material = self:get_slides()[self.current_slide].material
    self.data.text = self:get_slides()[self.current_slide].text

    self:animate()
end

function PANEL:finish()
    self.current_slide = 0
    -- Музыка уже включилась через кроссфейд на последнем слайде, 
    -- просто запускаем анимацию текста
    self:push_titles()
end

-- ========================================================
-- ТИТРЫ
-- ========================================================

surface.CreateFont("credits.subtext", {
    font = "Blender Pro Medium",
    extended = true,
    size = ix.UI.Scale(22),
    weight = 100,
    antialias = true,
})

surface.CreateFont("credits.text", {
    font = "Blender Pro Medium",
    extended = true,
    size = ix.UI.Scale(32),
    weight = 500,
    antialias = true,
})

surface.CreateFont("credits.book", {
    font = "Blender Pro Book",
    extended = true,
    size = ix.UI.Scale(32),
    weight = 500,
    antialias = true,
})

local credits = {

    { text = "ЭПИЛОГ БЫЛ ПОДГОТОВЛЕН", padding = true },
    { text = "Антон Чигур", role = "ВЕДУЩИЙ ЗАПУСКА" },
    { text = "SHIRAORI", role = "ВЕДУЩИЙ ЗАПУСКА" },
    { text = "Hutten", role = "ВЕДУЩИЙ ЗАПУСКА", bigpadding = true },

    { text = "КОМАНДА ЗАПУСКА", padding = true },
    { text = "Антон Чигур", role = "главный проводящий" },
    { text = "Hutten", role = "главный проводящий" },
    { text = "Fill Kury", role = "проводящий" },
    { text = "Shiraori", role = "проводящий" },
    { text = "komandante_merk12", role = "технический специалист" },
    { text = "Apokrif", role = "актёр" },
    { text = "Kommandant Hans", role = "актёр" },
    { text = "Hubble", role = "актёр" },
    { text = "John_Poscalovich", role = "актёр" },
    { text = "Folvixiii", role = "актёр" },
    { text = "Tory", role = "актёр" },
    { text = "Doming", role = "актёр", bigpadding = true },
    
    { text = "ОТДЕЛЬНАЯ БЛАГОДАРНОСТЬ", padding = true },
    { text = "SCHWARZ KRUPPZO", role = "За предоставление сборки" },
    { text = "FEELIS", role = "За помощь в организации" },
    { text = "ADANRIAL", role = "За предоставление хостинга" },
    { text = "Komandante_merk12", role = "За создание тематических моделей" },
    { text = "Команда FUNCLUB HRP", role = "За поддержку в проведении, маппинге и организации", bigpadding = true },
    
    { text = "ИХ БУДУТ ПОМНИТЬ", padding = true },
    { text = "Эрнест Сода" },
    { text = "Алекс Лебо" },
    { text = "Александр Бисли" },
    { text = "Датч", padding = true },
    { text = "и другие...", bigpadding = true },

    { text = "УЧАСТВОВАЛИ В СОБЫТИЯХ", padding = true },
    { text = "Элени Фотопулос", role = "пережила Зен заражение, осталась в общине вортигонтов" },
    { text = "Сара Ковалёва", role = "пережила страшное нападение зомби" },
    { text = "Эрнест Сода", role = "сошел с ума, расстрелян своими друзьями" },
    { text = "Чгон Пок Ю", role = "потеряла руку в битве с муравьиным стражем" },
    { text = "Эрсан Елясин", role = "никого не убивал" },
    { text = "Клаус Фейер", role = "вскрыл и взломал КПК Вселенского Союза" },
    { text = "Бенджамин Эйнсворт", role = "вскрыл и взломал КПК Вселенского Союза, уплыл на лодке" },
    { text = "Датч Шеффер", role = "спас группу ценой своей жизни" },
    { text = "Луций Гедеон", role = "исследователь" },
    { text = "Пильве Юргенссон", role = "инженер, уплыл в сторону Рио-де-Жанейро на лодке" },
    { text = "Алекс Рид", role = "медик" },
    { text = "Фрэнк Борман", role = "медик" },
    { text = "Игнасио Родригез", role = "медик" },
    { text = "Сесил Кок", role = "сотрудник безопасности" },
    { text = "Алекс Лебо", role = "сотрудник безопасности" },
    { text = "Дэниел Рэй", role = "сотрудник безопасности" },
    { text = "Равири Хеке", role = "сотрудник безопасности" },
    { text = "Томас Хейз", role = "сотрудник безопасности" },
    { text = "Алексендр Бисли", role = "убит в темнице Фолклендских островов" },
    { text = "Амура Мур", role = "исследователь" },
    { text = "Вормганг Шонан", role = "инженер, уплыл в сторону Рио-де-Жанейро на лодке" },
    { text = "Данияр Каримов", role = "сотрудник безопасности" },
    { text = "Зорро Вильгельм", role = "сотрудник безопасности" },
    { text = "Ия Корт", role = "исследователь" },
    { text = "Йи Муянг", role = "инженер, уплыл в сторону Рио-де-Жанейро на лодке" },
    { text = "Ли Храйм", role = "исследователь, уплыл в сторону Рио-де-Жанейро на лодке" },
    { text = "Сэм Хасоп", role = "медик" },
    { text = "Эвелин Уилсон", role = "исследователь" },
    { text = "и другие...", bigpadding = true },
    { text = "ПРИ ПОДДЕРЖКЕ AUTONOMOUS FRAMEWORK" },
    { text = "ВЕРСИИ ALPHA 28", bigpadding = true },
    { text = "РАЗРАБОТАНО" },
    { text = "КОМАНДОЙ AUTONOMOUS И SCHWARZ KRUPPZO", bigpadding = true },
}

function PANEL:push_titles()
    local img_bg = self:Add("DImage") 
    img_bg:SetPos(0, 0)
    img_bg:SetSize(ScrW(), ScrH())        
    img_bg:SetImage("slide_titles.png")
    img_bg:SetAlpha(0)

    img_bg:AlphaTo(255, 5, 0)

    local test = self:Add("Panel")
    test:SetSize(ScrW(), 0)

    local img = test:Add("Panel")
    img:Dock(TOP)
    img:SetSize(0, 232)    
    img:DockMargin(0, 0, 0, 64)

    local img_construct = img:Add("DImage") 
    img_construct:SetPos(ScrW() * 0.5 - 943 * 0.5, 0)
    img_construct:SetSize(943, 232)        
    img_construct:SetImage("newlogo.png")

    local gray = Color(170, 170, 170)
    for k, v in ipairs(credits) do
        if v.role then
            local entry = test:Add("Panel")
            entry:Dock(TOP)

            local label = entry:Add("DLabel")
            label:SetFont("credits.subtext")
            label:SetText(v.role)
            label:SetWide(test:GetWide() * 0.5)
            label:Dock(LEFT)
            label:DockMargin(0, 2, 10, 0)
            label:SetContentAlignment(6)
            label:SizeToContentsY()

            local label2 = entry:Add("DLabel")
            label2:SetFont(v.sub and "credits.subtext" or "credits.text")
            label2:SetText(v.sub and v.text or v.text:utf8upper())
            label2:Dock(FILL)
            label2:DockMargin(10, 0, 0, 0)
            label2:SetContentAlignment(4)
            label2:SizeToContentsY()
            label:SetTextColor(gray)

            entry:SizeToChildren(false, true)

            if v.padding then
                entry:DockMargin(0, 0, 0, ix.UI.Scale(16))
            elseif v.bigpadding then
                entry:DockMargin(0, 0, 0, ix.UI.Scale(16) * 5)
            end
        else
            local label = test:Add("DLabel")
            if v.sub2 then
                label:SetFont(v.sub2 and "credits.subtext" or "credits.text")
                label:SetText(v.text:utf8upper())
                label:SetTextColor(v.sub2 and gray or color_white)
            else
                label:SetFont(v.sub and "credits.subtext" or "credits.text")
                label:SetText(v.text or " ")
                label:SetTextColor(v.sub and gray or color_white)
            end
            label:Dock(TOP)
            label:SetContentAlignment(5)
            label:SizeToContents()

            if v.padding then
                label:DockMargin(0, 0, 0, ix.UI.Scale(16))
            elseif v.bigpadding then
                label:DockMargin(0, 0, 0, ix.UI.Scale(16) * 5)
            end
        end
    end
    
    test:InvalidateLayout(true)
    test:SizeToChildren(false, true)
    test:SetPos(0, ScrH())

    self.titles = test

    test:MoveTo(0, -test:GetTall(), 400, 0, 1, function()
        if IsValid(self) then self:on_finish() end
    end)
end

function PANEL:on_finish()
    self.allow_disconnect = true

    -- Плавно глушим канал титров перед концом игры
    self:CreateAnimation(5, {
        index = 13, 
        target = {vol_credits = 0},
        bIgnoreConfig = true, -- Игнорируем настройки UI анимаций игрока
        Think = function(anim, panel)
            if IsValid(panel.channel_credits) then
                panel.channel_credits:SetVolume(panel.vol_credits or 0)
            end
        end,
        OnComplete = function(anim, panel)
            if IsValid(panel) and IsValid(panel.channel_credits) then
                panel.channel_credits:Stop()
            end
        end
    })
end

function PANEL:Think()
    if self.allow_disconnect then
        if input.IsKeyDown(KEY_SPACE) then
            RunConsoleCommand("disconnect")
        end
    end
end

-- Надежно обрубаем ВСЕ звуки, если панель удалили до конца
function PANEL:OnRemove()
    if IsValid(self.channel_slides) then self.channel_slides:Stop() end
    if IsValid(self.channel_credits) then self.channel_credits:Stop() end
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(color_black)
    surface.DrawRect(0, 0, w, h)
end

function PANEL:PaintOver(w, h)
    if self.allow_disconnect then
        local curtime = CurTime()
        local glow = math.abs(math.sin(curtime))

        surface.SetFont("credits.text")

        local text_width, text_height = surface.GetTextSize(disconnect_message)

        surface.SetTextColor(ColorAlpha(color_white, glow * 160))
        surface.SetTextPos(w * 0.5 - text_width * 0.5, h * 0.9 - text_height * 0.9 - 12)
        surface.DrawText(disconnect_message)
    end
    
    if not self.initialized then return end

    local x, y = w * 0.5 - background_width * 0.5, h * 0.5 - background_height * 0.5
    local current_alpha = self.alpha or 0

    surface.SetDrawColor(255, 255, 255, current_alpha)
    if self.data.material then
        surface.SetMaterial(self.data.material)
        surface.DrawTexturedRect(x, y, background_width, background_height)
    end

    surface.SetTextColor(ColorAlpha(color_white, current_alpha))
    surface.SetDrawColor(0, 0, 0, math.Clamp(current_alpha, 0, 160))

    if self.data.text then
        local lines = ix.util.WrapText(self.data.text, w * 0.5, "credits.book")
        local text_y = 32

        for i = 1, #lines do
            local line = lines[i]
            local text_width, text_height = surface.GetTextSize(line)

            surface.DrawRect(w * 0.5 - text_width * 0.5 - 12, text_y, text_width + 24, text_height + 2)

            surface.SetTextPos(w * 0.5 - text_width * 0.5, text_y + 2)
            surface.DrawText(line)

            text_y = text_y + text_height + 2
        end
    end
end

vgui.Register("ui.cellar.ending", PANEL, "EditablePanel")

net.Receive("autonomous.ending", function(length, client)
    local ending = vgui.Create("ui.cellar.ending")
end)