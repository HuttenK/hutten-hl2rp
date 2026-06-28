-- Реколор меню персонажа под стиль ГЛАВНОГО меню (тёмно-красная схема как в
-- ui.mainmenu): фон rgba(22,7,7), акцент #f84040 (248,64,64), левая красная
-- полоса-акцент и слабая красная подложка при наведении/выборе (как пункты
-- навигации главного меню). Переопределяем функции скина и фоны кнопок ИЗ
-- ПЛАГИНА — ядро Helix не трогаем. Только визуал.

local BG  = Color(22, 7, 7)    -- тёмно-красный фон (#sidebar: rgba(22,7,7,.88))
local RED = Color(248, 64, 64) -- акцент #f84040

local SKIN = derma.GetNamedSkin("helix")

if (SKIN) then
	-- Фоны меню: плоский тёмно-красный вместо градиента.
	function SKIN:PaintCharacterCreateBackground(panel, width, height)
		surface.SetDrawColor(BG.r, BG.g, BG.b, 255)
		surface.DrawRect(0, 0, width, height)
	end

	function SKIN:PaintCharacterLoadBackground(panel, width, height)
		local frac = (panel.GetBackgroundFraction and panel:GetBackgroundFraction()) or 1

		surface.SetDrawColor(BG.r, BG.g, BG.b, frac * 255)
		surface.DrawRect(0, 0, width, height)
	end

	-- Полоса/шторка перехода между персонажами — в красный акцент.
	function SKIN:PaintCharacterTransitionOverlay(panel, x, y, width, height, color)
		surface.SetDrawColor(RED.r, RED.g, RED.b, 255)
		surface.DrawRect(x, y, width, height)
	end

	-- Подложка кнопок выбора персонажа: как пункт навигации главного меню —
	-- слабая красная заливка + левая красная полоса. Цвет фракции игнорируем,
	-- держим единую красную схему; альфа (color.a) несёт состояние наведения/выбора.
	function SKIN:DrawImportantBackground(x, y, width, height, color)
		local a = (color and color.a) or 255
		if (a <= 1) then return end

		surface.SetDrawColor(RED.r, RED.g, RED.b, a * 0.12) -- rgba(248,64,64,~0.1)
		surface.DrawRect(x, y, width, height)

		surface.SetDrawColor(RED.r, RED.g, RED.b, a)         -- border-left: 3px #f84040
		surface.DrawRect(x, y, 3, height)
	end
end

-- Кнопки-действия (выбрать/назад/удалить и т.п.): тот же стиль навигации.
local BUTTON = vgui.GetControlTable("ixMenuButton")

if (BUTTON) then
	function BUTTON:PaintBackground(width, height)
		local a = self.currentBackgroundAlpha or 0
		if (a <= 1) then return end

		surface.SetDrawColor(RED.r, RED.g, RED.b, a * 0.12)
		surface.DrawRect(0, 0, width, height)

		surface.SetDrawColor(RED.r, RED.g, RED.b, a)
		surface.DrawRect(0, 0, 3, height)
	end
end
