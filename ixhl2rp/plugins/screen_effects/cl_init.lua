if SERVER then return end

-- ================================================================
--  cl_init.lua — клиентские эффекты экрана
--  Эффекты: colormodify, bloom, sharpen, noise, chromatic
-- ================================================================

ix = ix or {}
ix.effects = ix.effects or {}

-- ================================================================
-- Конфигурация
-- ================================================================

ix.effects.ORDER = {
    "colormodify",
    "bloom",
    "sharpen",
    "noise",
    "chromatic",
}

ix.effects.DISPLAY_NAMES = {
    colormodify = "Color Modify (RGB)",
    bloom       = "Bloom",
    sharpen     = "Sharpen",
    noise       = "Noise / Static",
    chromatic   = "Chromatic Aberration",
}

-- Значения по умолчанию
-- colormodify: r/g/b в диапазоне 0-200, где 100 = нейтрально
-- остальные: intensity 0-100, где 0 = выкл, 100 = максимум
local DEFAULTS = {
    colormodify = { r = 100, g = 100, b = 100 },
    bloom       = { intensity = 0 },
    sharpen     = { intensity = 0 },
    noise       = { intensity = 0 },
    chromatic   = { intensity = 0 },
}

-- Метаданные для UI-слайдеров
ix.effects.PARAM_META = {
    colormodify = {
        { key = "r", label = "Red   (100 = норма)", min = 0, max = 200, isInt = true },
        { key = "g", label = "Green (100 = норма)", min = 0, max = 200, isInt = true },
        { key = "b", label = "Blue  (100 = норма)", min = 0, max = 200, isInt = true },
    },
    bloom     = {{ key = "intensity", label = "Интенсивность (0–100)", min = 0, max = 100, isInt = true }},
    sharpen   = {{ key = "intensity", label = "Интенсивность (0–100)", min = 0, max = 100, isInt = true }},
    noise     = {{ key = "intensity", label = "Интенсивность (0–100)", min = 0, max = 100, isInt = true }},
    chromatic = {{ key = "intensity", label = "Интенсивность (0–100)", min = 0, max = 100, isInt = true }},
}

-- ================================================================
-- Состояние
-- ================================================================

local _state   = {}
local _enabled = {}

local function getState(name)
    if not _state[name] then
        _state[name] = table.Copy(DEFAULTS[name] or {})
    end
    return _state[name]
end

-- ================================================================
-- Публичный API
-- ================================================================

function ix.effects.IsEnabled(name)
    return _enabled[name] == true
end

function ix.effects.Enable(name, bool)
    _enabled[name] = bool == true
end

function ix.effects.Toggle(name)
    _enabled[name] = not (_enabled[name] == true)
end

--- Установить параметры и автоматически включить эффект
function ix.effects.SetParams(name, params)
    local s = getState(name)
    for k, v in pairs(params) do
        s[k] = v
    end
    _enabled[name] = true
end

function ix.effects.GetParams(name)
    return table.Copy(getState(name))
end

function ix.effects.Reset(name)
    _state[name]   = table.Copy(DEFAULTS[name] or {})
    _enabled[name] = false
end

function ix.effects.ResetAll()
    for _, name in ipairs(ix.effects.ORDER) do
        ix.effects.Reset(name)
    end
    ix.effects.activeFlashes = {}
end

-- ================================================================
-- Вспышки
-- ================================================================

ix.effects.activeFlashes = {}

function ix.effects.Flash(color, duration, fadeIn, fadeOut)
    duration = duration or 0.5
    fadeIn   = fadeIn   or 0.05
    fadeOut  = fadeOut  or duration * 0.7
    table.insert(ix.effects.activeFlashes, {
        color    = color or Color(255, 255, 255),
        start    = CurTime(),
        duration = duration,
        fadeIn   = fadeIn,
        fadeOut  = fadeOut,
    })
end

-- ================================================================
-- Net receivers (формат: name, enabled, paramsJSON)
-- ================================================================

net.Receive("ix.screeneffect.set", function()
    local name    = net.ReadString()
    local enabled = net.ReadBool()
    local params  = util.JSONToTable(net.ReadString()) or {}

    if enabled then
        ix.effects.SetParams(name, params)
    else
        ix.effects.Enable(name, false)
    end
end)

net.Receive("ix.screeneffect.flash", function()
    local r  = net.ReadUInt(8)
    local g  = net.ReadUInt(8)
    local b  = net.ReadUInt(8)
    local d  = net.ReadFloat()
    local fi = net.ReadFloat()
    local fo = net.ReadFloat()
    ix.effects.Flash(Color(r, g, b), d, fi, fo)
end)

net.Receive("ix.screeneffect.reset", function()
    ix.effects.ResetAll()
end)

-- ================================================================
-- PP эффекты (RenderScreenspaceEffects)
-- ================================================================

hook.Add("RenderScreenspaceEffects", "ix.screeneffects", function()

    -- ── Color Modify ─────────────────────────────────────────────
    if ix.effects.IsEnabled("colormodify") then
        local s = getState("colormodify")
        -- r/g/b: 0–200 → mulR/G/B: 0.0–2.0 (100 = 1.0 = без изменений)
        DrawColorModify({
            ["$pp_colour_addr"]       = 0,
            ["$pp_colour_addg"]       = 0,
            ["$pp_colour_addb"]       = 0,
            ["$pp_colour_brightness"] = 0,
            ["$pp_colour_contrast"]   = 1,
            ["$pp_colour_colour"]     = 1,
            ["$pp_colour_mulr"]       = math.Clamp((s.r or 100) / 100, 0, 2),
            ["$pp_colour_mulg"]       = math.Clamp((s.g or 100) / 100, 0, 2),
            ["$pp_colour_mulb"]       = math.Clamp((s.b or 100) / 100, 0, 2),
        })
    end

    -- ── Bloom ────────────────────────────────────────────────────
    if ix.effects.IsEnabled("bloom") then
        local t = math.Clamp((getState("bloom").intensity or 0) / 100, 0, 1)
        if t > 0 then
            -- DrawBloom(Subtract, Multiply, SizeX, SizeY, Passes, ColorMul, R, G, B)
            local subtract  = math.max(0, 1 - t * 0.92)
            local multiply  = 1 + t * 2.5
            DrawBloom(subtract, multiply, 4, 4, 2, 1, 1, 1, 1)
        end
    end

    -- ── Sharpen ──────────────────────────────────────────────────
    if ix.effects.IsEnabled("sharpen") then
        local t = math.Clamp((getState("sharpen").intensity or 0) / 100, 0, 1)
        if t > 0 then
            -- DrawSharpen(contrast, distance)
            DrawSharpen(t * 4, t * 3)
        end
    end
end)

-- ================================================================
-- 2D эффекты (HUDPaint)
-- ================================================================

local _noisePixels   = {}
local _noiseTimer    = 0
local NOISE_INTERVAL = 0.04

local gradMat = {
    r = Material("vgui/gradient-r"),
    l = Material("vgui/gradient-l"),
    d = Material("vgui/gradient-d"),
    u = Material("vgui/gradient-u"),
}

hook.Add("HUDPaint", "ix.screeneffects", function()
    local now    = CurTime()
    local sw, sh = ScrW(), ScrH()

    -- ── Noise / Static ───────────────────────────────────────────
    if ix.effects.IsEnabled("noise") then
        local t     = math.Clamp((getState("noise").intensity or 0) / 100, 0, 1)
        local count = math.floor(t * 3500)

        if count > 0 then
            if (now - _noiseTimer) > NOISE_INTERVAL then
                _noiseTimer  = now
                _noisePixels = {}
                for i = 1, count do
                    local bri = math.random(0, 255)
                    _noisePixels[i] = {
                        x = math.random(0, sw - 2),
                        y = math.random(0, sh - 2),
                        a = math.random(100, 220),
                        v = bri,
                    }
                end
            end
            for _, p in ipairs(_noisePixels) do
                surface.SetDrawColor(p.v, p.v, p.v, p.a)
                surface.DrawRect(p.x, p.y, 2, 2)
            end
        end
    end

    -- ── Chromatic Aberration ────────────────────────────────────
    if ix.effects.IsEnabled("chromatic") then
        local t     = math.Clamp((getState("chromatic").intensity or 0) / 100, 0, 1)
        local alpha = math.floor(t * 100)
        local band  = math.floor(sw * 0.28 * t)

        if band > 0 and alpha > 0 then
            -- Левый край: красный
            surface.SetMaterial(gradMat.r)
            surface.SetDrawColor(255, 0, 0, alpha)
            surface.DrawTexturedRect(0, 0, band, sh)

            -- Правый край: синий
            surface.SetMaterial(gradMat.l)
            surface.SetDrawColor(0, 0, 255, alpha)
            surface.DrawTexturedRect(sw - band, 0, band, sh)

            -- Верхний край: зелёный (слабее)
            local gband = math.floor(sh * 0.15 * t)
            if gband > 0 then
                surface.SetMaterial(gradMat.d)
                surface.SetDrawColor(0, 200, 0, math.floor(alpha * 0.35))
                surface.DrawTexturedRect(0, 0, sw, gband)
            end
        end
    end

    -- ── Вспышки ──────────────────────────────────────────────────
    local toRemove = {}
    for i, f in ipairs(ix.effects.activeFlashes) do
        local elapsed = now - f.start
        if elapsed >= f.duration then
            table.insert(toRemove, i)
        else
            local alpha
            if elapsed < f.fadeIn then
                alpha = (elapsed / math.max(f.fadeIn, 0.001)) * 255
            elseif elapsed > (f.duration - f.fadeOut) then
                alpha = ((f.duration - elapsed) / math.max(f.fadeOut, 0.001)) * 255
            else
                alpha = 255
            end
            surface.SetDrawColor(f.color.r, f.color.g, f.color.b,
                math.Clamp(math.floor(alpha), 0, 255))
            surface.DrawRect(0, 0, sw, sh)
        end
    end
    for i = #toRemove, 1, -1 do
        table.remove(ix.effects.activeFlashes, toRemove[i])
    end
end)

-- ================================================================
-- Консольная команда открытия панели
-- ================================================================

concommand.Add("ix_effects_panel", function()
    if IsValid(ix.effects._panel) then
        ix.effects._panel:Remove()
    end
    local pnl = vgui.Create("ix_EffectsPanel")
    if IsValid(pnl) then
        ix.effects._panel = pnl
        pnl:MakePopup()
    end
end)
