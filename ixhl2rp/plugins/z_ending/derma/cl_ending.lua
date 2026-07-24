local disconnect_message = "НАЖМИТЕ [ПРОБЕЛ] ЧТОБЫ ЗАВЕРШИТЬ ИГРУ"

-- Укажите здесь пути к вашим аудиофайлам
local SOUND_SLIDES = "sound/slides_music.mp3"
local SOUND_CREDITS = "sound/wrathofman.mp3"

-- ФОН ПОД ТИТРАМИ. Укажите путь к КАРТИНКЕ или к ВИДЕО — больше ничего менять не нужно,
-- формат определяется по расширению файла:
--     local TITLES_BACKGROUND = "slide_titles.png"       -- картинка
--     local TITLES_BACKGROUND = "ending/titles_bg.webm"  -- зацикленное видео
-- Путь всегда относительно папки garrysmod/materials/ (как у слайдов выше).
-- Видео: только .webm (VP8/VP9), проигрывается без звука (звучит музыка титров),
-- автозапуск, бесконечный цикл, растягивается на весь экран без искажений.
local TITLES_BACKGROUND = "os_background.png"

-- СКОРОСТЬ ПРОКРУТКИ ТИТРОВ, пикселей в секунду. Больше значение — быстрее.
-- Комфортный диапазон для чтения — 60..90.
-- Раньше в MoveTo стояла фиксированная ДЛИТЕЛЬНОСТЬ (320 секунд), из-за чего
-- темп менялся сам собой каждый раз, когда список титров рос или сокращался:
-- одно и то же число прокручивало длинный список быстрее, чем короткий.
-- Теперь длительность считается от реальной высоты списка, и скорость
-- остаётся одинаковой независимо от того, сколько в нём имён.
local CREDITS_SPEED = 30

local background_width, background_height = 1920, 1080
local PANEL = {}

function PANEL:Init()
    if IsValid(ix.gui.ending) then
        ix.gui.ending:Remove()
    end
    
    ix.gui.ending = self

    self.slides = {}
    
    self:add_slide("slide_1.png", "Район Девять пал. Несмотря на старания Администрации, Гражданской Обороны, ополчения и даже завода, Сопротивление, ценой огромных жертв, одержало верх. Стратегические объекты были уничтожены в ходе диверсий и ракетных атак. Сити-57 покинул район, оставив позади попытки его интеграции.")
    self:add_slide("slide_2.png", "Смерть администратора Ивана Гольдмана не была шоком для горожан, а для кураторов из Сити-55 это было давно ожидаемым событием. Даже так, убийство руководителя создало вакуум власти и запустило цепочку страшных событий.")
    self:add_slide("slide_3.png", "Дмитрий Стрижцев, ухватившись за первую попавшуюся возможность, принял на себя бразды правления над Сити-57 после смерти Ивана Гольдмана. Однако Стрижцеву также пришлось отвечать и за ошибки Гольдмана . Никто не стал разбираться и искать настоящих виновных. Дальнейшая судьба Дмитрия остается неизвестной.")
    self:add_slide("slide_extra.png", "Захарии Левковской повезло больше всего. Воспользовавшись оставшимися связями в Сити-13, она успела покинуть Сектор Два до того, как ЕСБ начала отлов всех причастных. Теперь дорога лежит в Европу. Но ее дальнейшая судьба также туманна.")
    self:add_slide("slide_4.png", "Районы Пять и Шесть также попали под удар Сопротивления и были уничтожены. Администрация Сити-57 не могла допустить формальной потери практически трети города. Армия и синтеты зачистили мятежные улицы от любой жизни. Теперь брошенные дома и предприятия патрулирует армия, создавая иллюзию контроля.")
    self:add_slide("slide_12.png", "Руководство Сити-57 бросило все оставшиеся силы, чтобы отомстить Сопротивлению за столь серьезный удар. Десятки людей с обеих сторон были убиты. На поле боя все еще осталась брошенная техника, которую никто не спешит забирать.")
    self:add_slide("slide_5.png", "Руководители Сити-55 оставили попытки преобразования Ульяновска. Их колоссальные вложения ушли в небытие, а репутация в глазах Москвы испорчена. Последующие месяцы и годы Самара планомерно выкачивала все возможные ресурсы и богатства из Сити-57, наказывая таким образом за провал.")
    self:add_slide("slide_6.png", "Гарнизон Района Девять был расформирован. Часть его сотрудников ожидали переводы, других же — суровые наказания. Еще долгие месяцы офицеры терроризировали население Сити-57, выискивая диверсантов и предателей. Еще сотни невинных людей умрут по вине карателей.")
    self:add_slide("slide_7.png", "Несмотря на все провалы, Сити-55 высоко оценил вклад районного Завода и его сотрудников. Они стали одними из немногих, кто вместо наказания получил похвалы и награды. Большую часть работников перевели на предприятия Самары, где они продолжили трудиться.")
    self:add_slide("slide_8.png", "Корпорация Сильверскай влетела в свободный рынок Евразийского Содружества с двух ног. Люди еще долго будут вспоминать вкус Юни-колы. Однако, несмотря на местечковую прибыль, вложенные в Сити-57 ресурсы и капитал вмиг испарились. Корпорация понесла существенные убытки.")
    self:add_slide("slide_9.png", "Альянс не смог взять пустоши вокруг Ульяновска под контроль. Партизаны, маргиналы и диверсанты продолжили свои нападения на отряды армии и конвои. Сити-57, сейчас слабый как никогда ранее, мог лишь наблюдать, как контроль над ситуацией улетучивается с каждым днем.")
    self:add_slide("slide_10.png", "Еще никогда Ульяновск не был в таком плачевном положении. Местечковые руководители, словно коршуны, ринулись выжимать из Сити-57 оставшиеся крупицы капитала. И хоть город не был взят грубой силой оружия, его экономический и социальный коллапс — это ближайшее неминуемое будущее.")
    self:add_slide("slide_11.png", "«Победишь — будешь жить! Проиграешь — умрешь! Без сражений не победить! Сражайтесь! Сражайтесь!» — скандируют офицеры и бойцы РНОА. Деяния группы Томаша «Химика» показали, что Альянс слаб и уязвим. События Сити-57 вернули населению надежду на свободное будущее. Новая война неизбежна.")

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

    { text = "ЗАПУСК БЫЛ ПОДГОТОВЛЕН", padding = true },
    { text = "Антон Чигур", role = "ВЕДУЩИЙ ЗАПУСКА" },
    { text = "SHIRAORI", role = "ВЕДУЩИЙ ЗАПУСКА" },
    { text = "FILL KURY", role = "ВЕДУЩИЙ ЗАПУСКА" },
    { text = "Hutten", role = "ВЕДУЩИЙ ЗАПУСКА", bigpadding = true },

    { text = "КОМАНДА ЗАПУСКА", padding = true },
    { text = "Антон Чигур", role = "главный проводящий" },
    { text = "Hutten", role = "главный проводящий" },
    { text = "Fill Kury", role = "проводящий" },
    { text = "Shiraori", role = "проводящий" },
    { text = "Hutten", role = "технический специалист" },
    { text = "Avva", role = "помощник" },
    { text = "KiverG", role = "помощник" },
    { text = "Doming", role = "помощник" },
    { text = "dogovornyachok", role = "помощник" },
    { text = "Abelard", role = "помощник", bigpadding = true },
    
    { text = "ОТДЕЛЬНАЯ БЛАГОДАРНОСТЬ", padding = true },
    { text = "komandante_merk12", role = "За предоставление моделей" },
    { text = "FEELIS", role = "За помощь в организации и постоянную поддержку" },
    { text = "Hacker", role = "За помощь в организации и постоянную поддержку" },
    { text = "Команда FUNCLUB HRP", role = "За поддержку в проведении, маппинге и организации", bigpadding = true },

    { text = "В ходе беспорядков и террористических атак на девятый район было убито 195 человек", padding = true },
    { sub = true, text = "Еще больше остались инвалидами с искалеченными телами и судьбами", bigpadding = true },
    { text = "Огромное количество людей еще будет найдено убитыми", padding = true },
    { sub = true, text = "в подвалах, под завалами и на улицах", bigpadding = true },
    
    { text = "ИХ БУДУТ ПОМНИТЬ", padding = true },
    { text = "9812" },
    { text = "Хэ Юйфэн" },
    { text = "Серафим Семенов" },
    { text = "Ахмет Ауэзов" },
    { text = "Батырхан Абылкосымович" },
    { text = "Кшиштоф Вишневский" },
    { text = "0044" },
    { text = "8030" },
    { text = "Саша Белый" },
    { text = "Афанасий Гаплык" },
    { text = "Монджаро Шенькуй" },
    { text = "Артём Франк" },
    { text = "Эллен Московиц" },
    { text = "Эрик Оливье" },
    { text = "Эли Борзович", padding = true },
    { text = "и другие...", bigpadding = true },

    { text = "ВАШИ ПОКАЗАТЕЛИ", bigpadding = true },
    { text = "Самые богатые", padding = true },
    { text = "Дмитрий Стрижцев", role = "22316 токенов" },
    { text = "Олимпиада Сильверскай", role = "8284 токенов" },
    { text = "Jose Garcia", role = "3679 токенов" },
    { text = "Милица Симич", role = "2345 токенов" },
    { text = "Мезуми Исикава", role = "1395 токенов", bigpadding = true },

    { text = "Наибольший уровень", padding = true },
    { text = "Сергей Курагин", role = "31 уровень" },
    { text = "Хейкки Юнтуен", role = "29 уровень" },
    { text = "Лейзи Таунс", role = "29 уровень" },
    { text = "Серафим Семенов", role = "28 уровень" },
    { text = "0868", role = "27 уровень", bigpadding = true },

    { text = "Наибольшее количество текста", padding = true },
    { text = "Handsome Jack", role = "11493 сообщений или 405787 символов" },
    { text = "Vesthamer", role = "9368 сообщений или 315526 символов" },
    { text = "Volition", role = "9419 сообщений или 313437 символов" },
    { text = "antihero.chicha", role = "4022 сообщений или 263205 символов" },
    { text = "Taro", role = "3145 сообщений или 198201 символов", bigpadding = true },

    { text = "Наибольшее количество часов наиграно", padding = true },
    { text = "showl1s", role = "100 часов" },
    { text = "DIPER", role = "88 часов" },
    { text = "Danbazik", role = "87 часов" },
    { text = "Handsome Jack", role = "85 часов" },
    { text = "John Poscalovich", role = "85 часов", bigpadding = true },

    { text = "СТАТИСТИКА", padding = true },
    { text = "63885", role = "общее число токенов в обороте" },
    { text = "149881", role = "строк чата написано" },
    { text = "43845", role = "общее число предметов" },
    { text = "195", role = "созданных персонажей" },
    { text = "152", role = "уникальных игрока", bigpadding = true },

    { text = "ДОСКА ПОЗОРА", padding = true },
    { text = "Станислав Болгарка", role = "забанен навсегда" },
    { text = "JyBan", role = "забанен на 4,5 месяца" },
    { text = "Зорро Бармон", role = "забанен до 2030 года" },
    { text = "Захар Игнатов", role = "забанен навсегда" },
    { text = "Илья Петухов", role = "забанен всего лишь на четыре дня", bigpadding = true },

    { text = "УЧАСТВОВАЛИ В СОБЫТИЯХ", padding = true },
    { text = "Константин Луньков" },
    { text = "Канн'Др" },
    { text = "Мыкола Худолей" },
    { text = "Лейзи Таунс" },
    { text = "Евгений Кривозубов" },
    { text = "Кирилл Найденко" },
    { text = "Андрей Тетерин" },
    { text = "9812" },
    { text = "1615" },
    { text = "0642" },
    { text = "0044" },
    { text = "0868" },
    { text = "0505" },
    { text = "0143" },
    { text = "0067" },
    { text = "9641" },
    { text = "7388" },
    { text = "0801" },
    { text = "0764" },
    { text = "0601" },
    { text = "0077" },
    { text = "8030" },
    { text = "7159" },
    { text = "0203" },
    { text = "0700" },
    { text = "0436" },
    { text = "0010" },
    { text = "Zhora Smirnov" },
    { text = "Millisa Fatton" },
    { text = "Хейкки Юнтуен" },
    { text = "Ханна Остерман" },
    { text = "Сук Джа Мён" },
    { text = "Сергей Курагин" },
    { text = "Оливия Демиревски" },
    { text = "Милица Симич" },
    { text = "Маркус Тетчер" },
    { text = "Ма Ким Шин" },
    { text = "Ку Чин'А" },
    { text = "Иса Амирханов" },
    { text = "Иннокентий Двинятин" },
    { text = "Евгений Кравченко" },
    { text = "Денис Гронский" },
    { text = "Виктор Романенко" },
    { text = "Ахмет Ауэзов" },
    { text = "Арри Сильфа" },
    { text = "Александр Коэн" },
    { text = "Александр Гёрликард" },
    { text = "Xacier Jacksfield" },
    { text = "William Cooper" },
    { text = "Vivan Fields" },
    { text = "Tyrel Davis" },
    { text = "Truman Porter" },
    { text = "Tajuana Kim" },
    { text = "Sadhbh Hayes" },
    { text = "Robin Sandoval" },
    { text = "Reuben Sloan" },
    { text = "Phil Davenport" },
    { text = "Paz Pace" },
    { text = "Patricia Lulumba" },
    { text = "Pari Behdad" },
    { text = "Nakamori Kiyoshi" },
    { text = "Mule" },
    { text = "Miroslav Lustig" },
    { text = "Milan Hendrickson" },
    { text = "Milan Burton" },
    { text = "Mariya Yuriyivna Bojchenko" },
    { text = "Maria Muños" },
    { text = "Marcell Frye" },
    { text = "Malcolm Perthel" },
    { text = "Leon Mercer" },
    { text = "Leandro Adams" },
    { text = "Jurgen Siedel" },
    { text = "Jose Garcia" },
    { text = "Jerry Love" },
    { text = "Jennette Esposito" },
    { text = "Jarad Witt" },
    { text = "James McGarvy" },
    { text = "Jamal Europe" },
    { text = "Igor Nowak" },
    { text = "Ignacio Horace" },
    { text = "Fernando Caesar" },
    { text = "Erwin Rangel" },
    { text = "Ellen Moskowitz" },
    { text = "Elizabeth König" },
    { text = "Dewayne Alvarez" },
    { text = "Danil Roslee" },
    { text = "Curtis Kevelas" },
    { text = "Benjamin Goldstein" },
    { text = "Alice Hil" },
    { text = "Abdul Martinez" },
    { text = "Эрик Фавелл" },
    { text = "Эрик Оливье" },
    { text = "Эльвира Найденова" },
    { text = "Эли Борзович" },
    { text = "Шмаль Анатолий Харитонович" },
    { text = "Хэйден Родригес" },
    { text = "Хэ Юйфэн" },
    { text = "Хадерн аль-Факир" },
    { text = "Томаш Пржемыслович" },
    { text = "Сян Ли" },
    { text = "Сэм Стоун" },
    { text = "Станислав Ковалевич" },
    { text = "Станислав Завадский" },
    { text = "Станислав Болгарка" },
    { text = "Сергей Чернов" },
    { text = "Сергей Ситов" },
    { text = "Сергей Воркутинский" },
    { text = "Серафим Семенов" },
    { text = "Семен Танкер" },
    { text = "Саша Белый" },
    { text = "Роман Македонский" },
    { text = "Роза Козлова" },
    { text = "Монджаро Шенькуй" },
    { text = "Минь Суан Хо" },
    { text = "Мин Юнхо" },
    { text = "Мила Февральская" },
    { text = "Микита Шевченко" },
    { text = "Мезуми Исикава" },
    { text = "Мария Альборшвилли" },
    { text = "Максим Ленкевич" },
    { text = "Макдональд Куценко" },
    { text = "Леонид Окулуг" },
    { text = "Лейф Нильссон" },
    { text = "Кшиштоф Вишневский" },
    { text = "Константин Коштовица" },
    { text = "Клэй Портинс" },
    { text = "Кирилл Болтаренко" },
    { text = "Исмаил Абдрухманчик" },
    { text = "Ирина Слободкина" },
    { text = "Илья Петухов" },
    { text = "Зорро Бармон" },
    { text = "Захар Игнатов" },
    { text = "Захар Алексеевич Глотов" },
    { text = "Екатерина Островская" },
    { text = "Екатерина Лавриненко" },
    { text = "Дмитрий Кузнецов" },
    { text = "Джейсон Миллер" },
    { text = "Данил Грачевский" },
    { text = "Григорий Блинов" },
    { text = "Георгий Твердохлебов" },
    { text = "Генрих Шоффенбаум" },
    { text = "Ганс Финкельхаймер" },
    { text = "Виолетта Соловьёва" },
    { text = "Винсент Абернати" },
    { text = "Виктор Подавитель" },
    { text = "Виктор Могликин" },
    { text = "Виктор Меркушев" },
    { text = "Вася Ви" },
    { text = "Василий Петрушкин" },
    { text = "Валерия Абернати" },
    { text = "Бэргэн Баллыев" },
    { text = "Артём Франк" },
    { text = "Батырхан Абылкосымович" },
    { text = "Ангелина Зорина" },
    { text = "Артур Гранник" },
    { text = "Афанасий Гаплык" },
    { text = "Анатолий Милюков" },
    { text = "Альберт Мустафин" },
    { text = "Альберт Громов" },
    { text = "Александр Каштанов" },
    { text = "Алекс Моунтейн" },
    { text = "Олимпиада Сильверскай" },
    { text = "Артём Золкин" },
    { text = "Иван Гольдман" },
    { text = "Захария Левковская" },
    { text = "Дмитрий Стрижцев" },
    { text = "Дмитрий Медведкин" },
    { text = "Вячеслав Бульба" },
    { text = "Акане Цуки" },
    { text = "Андрей Пилотов" },
    { text = "и другие...", bigpadding = true },
    { text = "СПАСИБО ВАМ ЗА ИГРУ", bigpadding = true },
}

function PANEL:push_titles()
    -- Фон титров: картинка или видео — смотрим на расширение TITLES_BACKGROUND.
    local bg

    if string.lower(string.GetExtensionFromFilename(TITLES_BACKGROUND) or "") == "webm" then
        -- Видео. surface/материалы webm не проигрывают, поэтому берём встроенный
        -- браузер (Chromium умеет webm), а локальный файл отдаём ему через asset://.
        bg = self:Add("DHTML")
        bg:SetKeyboardInputEnabled(false)
        bg:SetHTML([[<html><body style="margin:0;padding:0;overflow:hidden;background:#000;">
            <video autoplay muted loop playsinline
                style="position:fixed;top:0;left:0;width:100vw;height:100vh;object-fit:cover;"
                src="asset://garrysmod/materials/]] .. TITLES_BACKGROUND .. [["></video>
        </body></html>]])
    else
        -- Картинка.
        bg = self:Add("DImage")
        bg:SetImage(TITLES_BACKGROUND)
    end

    bg:SetPos(0, 0)
    bg:SetSize(ScrW(), ScrH())
    bg:SetMouseInputEnabled(false) -- чисто декоративный, не перехватывает ПРОБЕЛ
    self.bg = bg

    -- Плавное появление на 5 сек. Прозрачность самого DHTML (браузерной поверхности)
    -- работает ненадёжно, поэтому гасим не видео, а чёрную панель ПОВЕРХ него: она
    -- уходит из непрозрачной в прозрачную — тот же эффект «проявления из черноты».
    local fade = self:Add("DPanel")
    fade:SetPos(0, 0)
    fade:SetSize(ScrW(), ScrH())
    fade:SetMouseInputEnabled(false)
    fade.Paint = function(_, w, h)
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, w, h)
    end
    fade:SetAlpha(255)
    fade:AlphaTo(0, 5, 0)

    local test = self:Add("Panel")
    test:SetSize(ScrW(), 0)

    local img = test:Add("Panel")
    img:Dock(TOP)
    img:SetSize(0, 232)    
    img:DockMargin(0, 0, 0, 64)

    local img_construct = img:Add("DImage") 
    img_construct:SetPos(ScrW() * 0.5 - 943 * 0.5, 0)
    img_construct:SetSize(943, 232)        
    img_construct:SetImage("oslogo.png")

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

    -- Путь = высота списка + высота экрана: панель стартует за нижней кромкой.
    local distance = test:GetTall() + ScrH()

    test:MoveTo(0, -test:GetTall(), distance / CREDITS_SPEED, 0, 1, function()
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
    vgui.Create("ui.cellar.ending")
end)