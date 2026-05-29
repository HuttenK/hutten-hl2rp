if SERVER then return end

-- ================================================================
--  ix_EffectsPanel  — панель управления эффектами экрана
--  Открыть: в консоли  ix_effects_panel
-- ================================================================

local COL_BG      = Color(22,  26,  34,  245)
local COL_PANEL   = Color(30,  35,  45,  255)
local COL_ROW     = Color(38,  44,  56,  255)
local COL_SEL     = Color(50,  80, 140,  255)
local COL_ACCENT  = Color(75, 119, 190,  255)
local COL_TEXT    = Color(220, 225, 235, 255)
local COL_MUTED   = Color(130, 140, 160, 255)
local COL_ON      = Color(80,  200, 100, 255)
local COL_OFF     = Color(180,  60,  60, 255)
local COL_BTN     = Color(50,  60,  80,  255)
local COL_BTN_HOV = Color(65,  80, 110,  255)

local FONT_TITLE = "DermaLarge"
local FONT_LABEL = "DermaDefault"
local FONT_SMALL = "DermaDefaultBold"

-- ----------------------------------------------------------------
-- Кнопка со стилем
-- ----------------------------------------------------------------
local function makeButton(parent, x, y, w, h, text, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetPos(x, y)
    btn:SetSize(w, h)
    btn:SetText("")
    btn.label   = text
    btn.hovered = false
    btn.Paint = function(s, bw, bh)
        draw.RoundedRect(4, 0, 0, bw, bh, s.hovered and COL_BTN_HOV or COL_BTN)
        draw.SimpleText(s.label, FONT_SMALL, bw/2, bh/2,
            COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    btn.OnCursorEntered = function(s) s.hovered = true  end
    btn.OnCursorExited  = function(s) s.hovered = false end
    btn.DoClick = onClick
    return btn
end

-- ----------------------------------------------------------------
-- Слайдер с подписью
-- ----------------------------------------------------------------
local function makeSlider(parent, y, meta, currentVal, onChange)
    local ROW_H     = 36
    local container = vgui.Create("DPanel", parent)
    container:SetSize(parent:GetWide() - 10, ROW_H)
    container:SetPos(5, y)
    container.Paint = function() end

    local lbl = vgui.Create("DLabel", container)
    lbl:SetPos(0, 0)
    lbl:SetSize(175, ROW_H)
    lbl:SetText(meta.label)
    lbl:SetTextColor(COL_TEXT)
    lbl:SetFont(FONT_LABEL)

    local sl = vgui.Create("DNumSlider", container)
    sl:SetPos(178, 2)
    sl:SetSize(container:GetWide() - 178, ROW_H - 4)
    sl:SetMin(meta.min)
    sl:SetMax(meta.max)
    sl:SetDecimals(meta.isInt and 0 or 2)
    sl:SetValue(currentVal)
    sl:SetConVar(nil)
    sl.Label:SetText("")
    sl.Label:SetWide(0)
    sl.TextArea:SetFont(FONT_SMALL)
    sl.TextArea:SetTextColor(COL_TEXT)
    sl.OnValueChanged = function(_, val)
        if meta.isInt then val = math.Round(val) end
        onChange(meta.key, val)
    end
    return container, ROW_H
end

-- ================================================================
-- Панель
-- ================================================================
vgui.Register("ix_EffectsPanel", {

    Init = function(self)
        self:SetTitle("")
        self:SetSize(680, 460)
        self:Center()
        self:SetDraggable(true)
        self:ShowCloseButton(false)

        self.Paint = function(s, w, h)
            draw.RoundedRect(6, 0, 0, w, h, COL_BG)
            draw.RoundedRectEx(6, 0, 0, w, 36, COL_PANEL, true, true, false, false)
            draw.SimpleText("SCREEN EFFECTS", FONT_TITLE, 14, 18,
                COL_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("ix_effects_panel", FONT_LABEL, w - 10, 18,
                COL_MUTED, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.RoundedRectEx(6, 0, h - 44, w, 44, COL_PANEL, false, false, true, true)
        end

        -- Кнопка закрытия
        makeButton(self, self:GetWide() - 90, 6, 80, 24, "Закрыть", function()
            self:Remove()
        end)

        -- ── Левая панель: список эффектов ────────────────────────
        local leftW  = 190
        local listBg = vgui.Create("DPanel", self)
        listBg:SetPos(8, 42)
        listBg:SetSize(leftW, 368)
        listBg.Paint = function(_, w, h)
            draw.RoundedRect(4, 0, 0, w, h, COL_PANEL)
        end

        local scroll = vgui.Create("DScrollPanel", listBg)
        scroll:SetPos(4, 4)
        scroll:SetSize(leftW - 8, 360)

        self.effectRows = {}
        local yOff = 0
        for _, name in ipairs(ix.effects.ORDER) do
            local displayName = ix.effects.DISPLAY_NAMES[name] or name
            local row = vgui.Create("DPanel", scroll)
            row:SetSize(leftW - 8, 34)
            row:SetPos(0, yOff)
            row._name     = name
            row._selected = false

            row.Paint = function(r, w, h)
                draw.RoundedRect(4, 0, 0, w, h, r._selected and COL_SEL or COL_ROW)
                local col = ix.effects.IsEnabled(name) and COL_ON or COL_OFF
                draw.RoundedRect(3, w - 10, h/2 - 4, 8, 8, col)
                draw.SimpleText(displayName, FONT_LABEL, 10, h/2,
                    COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            row:SetCursor("hand")
            local panelRef = self
            local effName  = name
            row.OnMousePressed = function()
                panelRef:SelectEffect(effName)
            end

            self.effectRows[name] = row
            yOff = yOff + 36
        end

        -- ── Правая панель: параметры ──────────────────────────────
        local rightX  = leftW + 14
        local rightW  = 680 - rightX - 8
        local rightBg = vgui.Create("DPanel", self)
        rightBg:SetPos(rightX, 42)
        rightBg:SetSize(rightW, 368)
        rightBg.Paint = function(_, w, h)
            draw.RoundedRect(4, 0, 0, w, h, COL_PANEL)
        end
        self.rightBg = rightBg
        self.rightW  = rightW

        -- ── Нижние кнопки ─────────────────────────────────────────
        local bY = 418
        makeButton(self,   8, bY, 100, 30, "Белая вспышка",   function() ix.effects.Flash(Color(255,255,255), 0.5) end)
        makeButton(self, 112, bY, 100, 30, "Красная вспышка", function() ix.effects.Flash(Color(220, 30, 30), 0.6) end)
        makeButton(self, 216, bY, 100, 30, "Синяя вспышка",   function() ix.effects.Flash(Color(30, 60, 220), 0.6) end)
        makeButton(self, 320, bY, 100, 30, "Зелёная вспышка", function() ix.effects.Flash(Color(30, 200, 60), 0.5) end)

        makeButton(self, 680 - 130, bY, 120, 30, "Сбросить всё", function()
            ix.effects.ResetAll()
            for _, row in pairs(self.effectRows) do
                row:InvalidateLayout()
            end
            if self._selectedEffect then
                self:SelectEffect(self._selectedEffect)
            end
        end)

        -- Открыть первый эффект
        self:SelectEffect("colormodify")
    end,

    -- ──────────────────────────────────────────────────────────────
    SelectEffect = function(self, name)
        self._selectedEffect = name

        -- Выделить строку
        for n, row in pairs(self.effectRows) do
            row._selected = (n == name)
        end

        -- Очистить правую панель
        self.rightBg:Clear()

        local meta   = ix.effects.PARAM_META[name]
        local params = ix.effects.GetParams(name)
        local rW     = self.rightW
        local bg     = self.rightBg

        -- Заголовок и переключатель
        local titlePnl = vgui.Create("DPanel", bg)
        titlePnl:SetPos(8, 8)
        titlePnl:SetSize(rW - 16, 38)
        titlePnl.Paint = function(_, w, h)
            draw.RoundedRect(4, 0, 0, w, h, COL_ROW)
            draw.SimpleText(ix.effects.DISPLAY_NAMES[name] or name,
                FONT_TITLE, 12, h/2, COL_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local togBtn = vgui.Create("DButton", titlePnl)
        togBtn:SetPos(titlePnl:GetWide() - 90, 6)
        togBtn:SetSize(84, 26)
        togBtn:SetText("")
        togBtn.Paint = function(s, w, h)
            local on  = ix.effects.IsEnabled(name)
            draw.RoundedRect(4, 0, 0, w, h, on and COL_ON or COL_OFF)
            draw.SimpleText(on and "ВКЛ" or "ВЫКЛ", FONT_SMALL,
                w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        togBtn.DoClick = function()
            ix.effects.Toggle(name)
        end

        -- Подсказка по команде
        local hintLbl = vgui.Create("DLabel", bg)
        hintLbl:SetPos(8, 52)
        hintLbl:SetSize(rW - 16, 18)
        hintLbl:SetFont(FONT_LABEL)
        hintLbl:SetTextColor(COL_MUTED)
        if name == "colormodify" then
            hintLbl:SetText("/ScreenEffect <цель> colormodify <R> <G> <B>  (100=норма, 0-200)")
        else
            hintLbl:SetText("/ScreenEffect <цель> " .. name .. " <0–100>  |  цель: имя / all / range / range:N")
        end

        -- Слайдеры
        if not meta then return end

        local scroll2 = vgui.Create("DScrollPanel", bg)
        scroll2:SetPos(8, 76)
        scroll2:SetSize(rW - 16, bg:GetTall() - 84)

        local sliderY = 0
        for _, m in ipairs(meta) do
            local defaultForKey = (m.key == "intensity") and 0 or 100
            local val     = params[m.key] or defaultForKey
            local effName = name
            local _, rowH = makeSlider(scroll2, sliderY, m, val, function(key, newVal)
                ix.effects.SetParams(effName, { [key] = newVal })
            end)
            sliderY = sliderY + rowH + 2
        end
    end,

}, "DFrame")
