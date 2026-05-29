-- ================================================================
--  sh_commands.lua — команды эффектов экрана
--
--  СИНТАКСИС:
--    /ScreenEffect <цель> <эффект> <значение> [значение2] [значение3]
--
--  Цель:
--    Джек            — конкретный игрок (частичное совпадение имени)
--    all             — все игроки на сервере
--    range           — игроки в радиусе 1000 единиц от администратора
--    range:500       — игроки в радиусе 500 единиц
--
--  Эффекты:
--    bloom    0-100  — свечение/гало
--    sharpen  0-100  — резкость
--    noise    0-100  — шум / помехи
--    chromatic 0-100 — хроматическая аберрация
--    colormodify R G B  — коррекция цвета (0-200, 100 = норма)
--
--  Примеры:
--    /ScreenEffect Джек sharpen 80
--    /ScreenEffect all bloom 50
--    /ScreenEffect range noise 60
--    /ScreenEffect range:800 chromatic 40
--    /ScreenEffect Джек colormodify 100 60 160
--    /ScreenEffect all colormodify 80 80 80
--    /ScreenReset Джек
--    /ScreenReset all
--    /ScreenFlash Джек 255 0 0 0.5
-- ================================================================

local VALID_EFFECTS = {
    colormodify = true,
    bloom       = true,
    sharpen     = true,
    noise       = true,
    chromatic   = true,
}

-- ----------------------------------------------------------------
-- Найти список игроков по строке-цели
-- Возвращает: targets (table|nil), label (string)
-- ----------------------------------------------------------------
local function resolveTargets(caller, targetStr)
    local s = targetStr:lower()

    -- all
    if s == "all" then
        return player.GetAll(), "всем игрокам"
    end

    -- range или range:N
    local customRadius = s:match("^range:(%d+)$")
    if customRadius or s == "range" then
        local radius    = tonumber(customRadius) or 1000
        local callerPos = caller:GetPos()
        local found     = {}
        for _, ply in ipairs(player.GetAll()) do
            if ply:GetPos():Distance(callerPos) <= radius then
                table.insert(found, ply)
            end
        end
        if #found == 0 then
            return nil, "никого в радиусе " .. radius .. " ед."
        end
        return found, "игрокам в радиусе " .. radius .. " ед. (" .. #found .. " чел.)"
    end

    -- Точное совпадение имени (без учёта регистра)
    for _, ply in ipairs(player.GetAll()) do
        if ply:Nick():lower() == s then
            return { ply }, ply:Nick()
        end
    end
    -- Частичное совпадение
    for _, ply in ipairs(player.GetAll()) do
        if ply:Nick():lower():find(s, 1, true) then
            return { ply }, ply:Nick()
        end
    end

    return nil, "игрок не найден: «" .. targetStr .. "»"
end

-- ----------------------------------------------------------------
-- Отправить состояние эффекта игрокам
-- ----------------------------------------------------------------
local function sendEffect(targets, name, enabled, params)
    net.Start("ix.screeneffect.set")
        net.WriteString(name)
        net.WriteBool(enabled)
        net.WriteString(util.TableToJSON(params or {}))
    net.Send(targets)
end

-- ----------------------------------------------------------------
-- Отправить сброс игрокам
-- ----------------------------------------------------------------
local function sendReset(targets)
    net.Start("ix.screeneffect.reset")
    net.Send(targets)
end

-- ================================================================
-- /ScreenEffect <цель> <эффект> <значение> [G] [B]
-- ================================================================
ix.command.Add("ScreenEffect", {
    description = "Применить эффект экрана. Синтаксис: /ScreenEffect цель эффект значение [G B]. Цель: имя, all, range, range:N",
    adminOnly   = true,
    arguments   = {
        ix.type.string,   -- target
        ix.type.string,   -- effect name
        ix.type.string,   -- value1 (intensity или R)
        bit.bor(ix.type.string, ix.type.optional),  -- value2 (G для colormodify)
        bit.bor(ix.type.string, ix.type.optional),  -- value3 (B для colormodify)
    },
    OnRun = function(self, caller, targetStr, effectName, v1, v2, v3)
        effectName = effectName:lower()

        if not VALID_EFFECTS[effectName] then
            caller:ChatPrint("[Screen Effects] Неизвестный эффект: «" .. effectName ..
                "». Доступные: colormodify, bloom, sharpen, noise, chromatic")
            return
        end

        local targets, label = resolveTargets(caller, targetStr)
        if not targets then
            caller:ChatPrint("[Screen Effects] " .. label)
            return
        end

        if effectName == "colormodify" then
            -- Принимает R G B в диапазоне 0-200 (100 = нейтрально)
            local r = math.Clamp(tonumber(v1) or 100, 0, 200)
            local g = math.Clamp(tonumber(v2) or 100, 0, 200)
            local b = math.Clamp(tonumber(v3) or 100, 0, 200)
            sendEffect(targets, "colormodify", true, { r = r, g = g, b = b })
            caller:ChatPrint("[Screen Effects] colormodify RGB(" ..
                r .. ", " .. g .. ", " .. b .. ") → " .. label)
        else
            -- Принимает intensity 0-100 (0 = выключить)
            local intensity = math.Clamp(tonumber(v1) or 0, 0, 100)
            if intensity == 0 then
                sendEffect(targets, effectName, false, {})
                caller:ChatPrint("[Screen Effects] " .. effectName .. " ВЫКЛ → " .. label)
            else
                sendEffect(targets, effectName, true, { intensity = intensity })
                caller:ChatPrint("[Screen Effects] " .. effectName ..
                    " " .. intensity .. "% → " .. label)
            end
        end
    end,
})

-- ================================================================
-- /ScreenReset <цель>
--   /ScreenReset Джек
--   /ScreenReset all
--   /ScreenReset range:500
-- ================================================================
ix.command.Add("ScreenReset", {
    description = "Сбросить все эффекты экрана. Цель: имя игрока, all, range, range:N",
    adminOnly   = true,
    arguments   = { ix.type.string },
    OnRun = function(self, caller, targetStr)
        local targets, label = resolveTargets(caller, targetStr)
        if not targets then
            caller:ChatPrint("[Screen Effects] " .. label)
            return
        end
        sendReset(targets)
        caller:ChatPrint("[Screen Effects] Сброс эффектов → " .. label)
    end,
})

-- ================================================================
-- /ScreenFlash <цель> <R> <G> <B> <длительность>
--   /ScreenFlash Джек 255 0 0 0.5
--   /ScreenFlash all 255 255 255 1
-- ================================================================
ix.command.Add("ScreenFlash", {
    description = "Цветовая вспышка. /ScreenFlash цель R G B длительность. Цель: имя, all, range, range:N",
    adminOnly   = true,
    arguments   = {
        ix.type.string,
        ix.type.number,
        ix.type.number,
        ix.type.number,
        ix.type.number,
    },
    OnRun = function(self, caller, targetStr, r, g, b, duration)
        local targets, label = resolveTargets(caller, targetStr)
        if not targets then
            caller:ChatPrint("[Screen Effects] " .. label)
            return
        end
        duration = math.Clamp(duration, 0.05, 10)
        net.Start("ix.screeneffect.flash")
            net.WriteUInt(math.Clamp(math.Round(r), 0, 255), 8)
            net.WriteUInt(math.Clamp(math.Round(g), 0, 255), 8)
            net.WriteUInt(math.Clamp(math.Round(b), 0, 255), 8)
            net.WriteFloat(duration)
            net.WriteFloat(0.05)
            net.WriteFloat(duration * 0.7)
        net.Send(targets)
        caller:ChatPrint("[Screen Effects] Вспышка RGB(" ..
            math.Round(r) .. "," .. math.Round(g) .. "," .. math.Round(b) ..
            ") " .. duration .. "с → " .. label)
    end,
})
