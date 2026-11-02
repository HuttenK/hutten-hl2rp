# Medieval: предметы, хранилища и Templar

Добавлено 45 предметов: 34 блюда/напитка, 2 письменных принадлежности, 4 размещаемых хранилища, 5 комплектов одежды. Все изменения — в gamemode; сторонние аддоны не изменялись.

## Внешность

Первой моделью в мужском выборе персонажа стала `models/players/templar_archer_03.mdl`. Прежние мужские и женские варианты оставлены доступными, существующие персонажи не меняются автоматически.

У всех восьми Templar-моделей проверены MDL: 12 скинов меняют только материал головы (`Tete_01` … `Tete_01_12`), в одинаковом порядке. Группа `Yeux/Eyes` имеет три варианта и отдельный переключатель в создании персонажа. Она сохраняется вместе с лицом при экипировке, снятии одежды, загрузке персонажа и смене накидки. Остальные bodygroup не копируются по индексам: их раскладка у лучника и рыцаря разная.

Выбор лица хранится в существующем поле `sd_skin`, глаз — в `templar_eyes`. Внешность видна в предпросмотре, TAB и на игроке. Указанный ниже комплект использует слот торса: два таких комплекта одновременно надеть нельзя. Снятие возвращает исходную модель персонажа.

## Комплекты

| ID | Название | Защита |
|---|---|---|
| `med_armor_black` | Латы Чёрного караула | Тяжёлые латы: высокая защита торса, рук и ног; скорость передвижения снижена на 30%. |
| `med_armor_white` | Латы Белого обета | Тяжёлые латы: высокая защита торса, рук и ног; скорость передвижения снижена на 30%. |
| `med_mail_long` | Кольчуга Сумеречного дозора | Кольчуга: защита торса, частично рук и ног; скорость передвижения снижена на 15%. |
| `med_mail_short` | Кольчуга Вольного копья | Кольчуга: защита торса и рук, небольшое прикрытие ног; скорость передвижения снижена на 15%. |
| `med_tunic_black` | Туника Чёрного тракта | Плотная ткань: небольшая защита прикрытых частей тела, без замедления. |

Защита проходит через штатную медицинскую систему: учитываются зона попадания и износ, при нулевой прочности защита исчезает. Это не постоянный процент снижения любого урона. Шлем не добавляется: голова этими комплектами не защищена. Цифры — начальный баланс; ощущения от боя требуется оценить в игре.

У **Туники Чёрного тракта** в контекстном меню надетого предмета есть действия «Надеть наплечную накидку» и «Снять наплечную накидку». Они переключают `templar_archer_02.mdl` ↔ `templar_archer_01.mdl`. Выбор сохраняется в конкретном предмете, не меняет прочность и не затрагивает других владельцев туники.

## Письмо

Дневник и свиток открывают существующий редактор бумаги, поддерживают заголовок, текст и форматирование. Автор может дописывать их после десяти минут и после повторного входа. Другие персонажи могут читать записи. Текст хранится в данных конкретного предмета; предметы не складываются в стопки. Сохранение проверяет открытый редактор, персонажа, авторство и доступ к предмету. Чтение не даёт права переписать весь документ. Обычная записка сохраняет прежний срок редактирования.

## Хранилища

| ID | Название | Размер инвентаря |
|---|---|---|
| `furn_oaken_chest` | Сундук бережливого хозяина | 8 × 5 |
| `furn_oaken_wardrobe` | Шкаф доброго плотника | 8 × 8 |
| `furn_cabinet_four` | Поставец хозяйского дома | 6 × 5 |
| `furn_cabinet_six` | Шкафец старого поместья | 6 × 6 |

Используйте действие размещения предмета: оно запускает существующий режим обустройства. Модель становится полноценным `ix_container`. Содержимое и размещение сохраняются существующей системой furnishing; перемещение и упаковка следуют её правилам. Пропы этих моделей, созданные через Q-меню, также распознаются штатной системой контейнеров.

## Полный каталог

Категории: «Яства и трапезы», «Напитки», «Письменные принадлежности», «Средневековые доспехи» и категория мебели. Блюда едятся порциями; напитки используют существующие реагенты воды, пива, вина и виски. У всех перечисленных предметов есть отдельное русское описание.

| ID | Название | Модель |
|---|---|---|
| `feast_caviar` | Жемчуг княжеского стола | `models/prop/re9_requiem_black_rice.mdl` |
| `feast_chicken` | Курица «Праздник у старосты» | `models/prop/re9_requiem_chicken_plate.mdl` |
| `feast_cakes` | Пирожные придворного сладкоежки | `models/prop/re9_requiem_dessert.mdl` |
| `feast_bread_basket` | Корзина золотых корочек | `models/prop/re9_requiem_french_bread.mdl` |
| `feast_apples` | Яблоки из господского сада | `models/prop/re9_requiem_fruits.mdl` |
| `feast_ham` | Окорок щедрого хозяина | `models/prop/re9_requiem_ham_plate.mdl` |
| `feast_ham_slices` | Ветчина «Всего один ломтик» | `models/prop/re9_requiem_ham_slices_plate.mdl` |
| `feast_lamb` | Ягнёнок к большому пиру | `models/prop/re9_requiem_lamb_plate.mdl` |
| `feast_lamb_ribs` | Рёбрышки молодого ягнёнка | `models/prop/re9_requiem_lamb_plate_ribs_plate.mdl` |
| `feast_pork` | Свинина под хозяйским соусом | `models/prop/re9_requiem_pork_dish.mdl` |
| `feast_pork_platter` | Свиной жаркий «На всю дружину» | `models/prop/re9_requiem_pork_plate.mdl` |
| `feast_salad` | Зелень монастырского сада | `models/prop/re9_requiem_salads.mdl` |
| `feast_meat_salad` | Салат охотничьего двора | `models/prop/re9_requiem_slices_of_meat_plate.mdl` |
| `feast_meat_salad_fine` | Мясное ассорти «Листик для вида» | `models/prop/re9_requiem_slices_plate.mdl` |
| `feast_steak` | Стейк баронского стола | `models/prop/re9_requiem_steak_dish.mdl` |
| `feast_steak_reserve` | Стейк «Последнее слово повара» | `models/prop/re9_requiem_steak_plate.mdl` |
| `med_soup_1` | Густая похлёбка путника | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/soup1.mdl` |
| `med_soup_2` | Суп «Щедрый половник» | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/soup2.mdl` |
| `med_soup_3` | Похлёбка вечернего очага | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/soup3.mdl` |
| `med_soup_4` | Суп «Доброе утро, трактирщик» | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/soup4.mdl` |
| `med_soup_5` | Похлёбка ярмарочного дня | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/soup5.mdl` |
| `med_soup_6` | Суп из старой поваренной книги | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/soup6.mdl` |
| `med_soup_7` | Похлёбка «Ещё полмиски» | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/soup7.mdl` |
| `med_lobster` | Лобстер купеческого пира | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/lobster.mdl` |
| `med_fresh_bread` | Хлеб из утренней печи | `models/lil_prin/monsterhunter/iceborne/food/bread_kneading_board.mdl` |
| `feast_whisky` | Виски «Старый бочар» | `models/prop/re9_requiem_whiskey.mdl` |
| `feast_wine_creek` | Вино «У ручья» | `models/prop/re9_requiem_wine_coopercreek.mdl` |
| `feast_wine_rose` | Вино «Роза на рассвете» | `models/prop/re9_requiem_wine_flamantrose.mdl` |
| `feast_wine_cellar` | Вино «Печать погреба» | `models/prop/re9_requiem_wine_hwc.mdl` |
| `feast_wine_forest` | Вино «Тень старого леса» | `models/prop/re9_requiem_wine_sequola.mdl` |
| `med_beer_wood` | Пиво «Дубовая кружка» | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/drink.mdl` |
| `med_beer_metal` | Пиво «Оловянный звон» | `models/lil_prin/monsterhunter/iceborne/food/platters/individual/drink2.mdl` |
| `med_water_flask` | Бутыль ключевой воды | `models/glassware.mdl` |
| `med_water_carafe` | Графин чистой воды | `models/glassware1.mdl` |
| `furn_oaken_chest` | Сундук бережливого хозяина | `models/woodenchest.mdl` |
| `furn_oaken_wardrobe` | Шкаф доброго плотника | `models/wardrobe.mdl` |
| `furn_cabinet_four` | Поставец хозяйского дома | `models/cabinets4.mdl` |
| `furn_cabinet_six` | Шкафец старого поместья | `models/cabinets6.mdl` |
| `med_armor_black` | Латы Чёрного караула | `models/players/templar_knight_02.mdl` |
| `med_armor_white` | Латы Белого обета | `models/players/templar_knight_01.mdl` |
| `med_mail_long` | Кольчуга Сумеречного дозора | `models/players/templar_archer_06.mdl` |
| `med_mail_short` | Кольчуга Вольного копья | `models/players/templar_archer_04.mdl` |
| `med_tunic_black` | Туника Чёрного тракта | `models/players/templar_archer_02.mdl` |
| `med_diary` | Дорожный дневник | `models/irisitems1.mdl` |
| `med_scroll` | Свиток добрых намерений | `models/irisitems3.mdl` |

## Контент

В локальном Workshop найдены Templar (`2983897298`), еда RE9 (`3686142926`) и Monster Hunter (`3654226879`). Код не поставляет и не меняет их модели.

На момент проверки не найдены в установленном локальном контенте:

- `models/irisitems1.mdl`, `models/irisitems3.mdl`;
- `models/woodenchest.mdl`, `models/wardrobe.mdl`, `models/cabinets4.mdl`, `models/cabinets6.mdl`;
- `models/glassware.mdl`, `models/glassware1.mdl`.

Определения предметов используют точные пути из запроса. Нужный аддон должен быть установлен/смонтирован у сервера и клиентов; без него модели не отобразятся, а размещение мебели может быть отклонено проверкой модели.

## Проверка

Автоматические проверки: `npm test` — 42 набора сценариев; новые сценарии охватывают 12 × 3 вариантов внешности и все 5 комплектов, сохранение накидки, независимость предметов, смену персонажа, штатную обработку урона и износа, редактор документов, порции всех 34 блюд/напитков и подключение четырёх моделей к furnishing. `npm run audit:medieval` проверяет ссылки на базы предметов/зависимости; `npm run audit` — синтаксис GLua после нормализации. Это проверки кода, а не запуск GMod.

После обновления перезапустите карту/сервер. В игре нужно проверить:

1. Создать персонажа Templar с лицом и глазами не по умолчанию; надеть/снять каждый комплект, сменить накидку, переподключиться.
2. Записать текст, передать дневник другому персонажу, вернуть его автору и дополнить запись.
3. Разместить каждое хранилище, положить предметы, перезапустить сервер и проверить содержимое.
4. Попробовать блюда и напитки, проверить иконки, модели на земле и физику новых пропов.
5. Сравнить попадания в торс, конечности и незащищённую голову; проверить замедление и износ.
