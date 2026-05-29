local PLUGIN = PLUGIN

-- ─────────────────────────────────────────────
--  Текстуры
-- ─────────────────────────────────────────────
local matVignette = Material("helix/gui/vignette.png", "smooth")

-- ─────────────────────────────────────────────
--  Кровь на модели через util.DecalEx
-- ─────────────────────────────────────────────

-- Ленивая инициализация: DecalMaterial при загрузке файла может вернуть nil,
-- поэтому вызываем её при первом реальном использовании.
local bloodDecalMat

local function ApplyBloodOnModel(entity, hitPos, dmgAmount)
    if not IsValid(entity) then return end

    if not bloodDecalMat then
        bloodDecalMat = Material("decals/blood1")
        if not bloodDecalMat or bloodDecalMat:IsError() then return end
    end

    -- Нормаль: от центра модели к точке попадания (проекция снаружи)
    local center = entity:GetPos() + Vector(0, 0, entity:OBBCenter().z)
    local normal = (hitPos - center):GetNormalized()
    if normal:IsZero() then normal = -entity:GetForward() end

    -- Количество пятен зависит от урона
    local count = math.Clamp(math.floor(dmgAmount / 15), 1, 3)
    for i = 1, count do
        local scatter = Vector(math.Rand(-4, 4), math.Rand(-4, 4), math.Rand(-4, 4))
        util.DecalEx(
            bloodDecalMat,
            entity,
            hitPos + scatter,
            normal,
            color_white,
            math.Rand(6, 12),   -- ширина в юнитах (не 0.8–1.5, иначе пятно невидимо)
            math.Rand(6, 12)    -- высота
        )
    end
end

-- ─────────────────────────────────────────────
--  Состояние экранных эффектов
-- ─────────────────────────────────────────────
local HitFlashBright   = 0
local HitFlashVig      = 0
local ConsciousnessAmt = 1
local O2Amount         = 1
local prevHealth       = -1

-- ─────────────────────────────────────────────
--  Вспомогательные функции
-- ─────────────────────────────────────────────
local function DrawVignette(r, g, b, alpha)
    if alpha <= 0 then return end
    surface.SetMaterial(matVignette)
    surface.SetDrawColor(r, g, b, math.Clamp(alpha, 0, 255))
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end

-- ─────────────────────────────────────────────
--  Сетевой приёмник
-- ─────────────────────────────────────────────
net.Receive("ixRealisticBlood", function()
    local entity    = net.ReadEntity()
    local _         = net.ReadUInt(32)
    local dmgAmount = net.ReadFloat()
    local hitPos    = net.ReadVector()

    if not IsValid(entity) then return end

    if entity == LocalPlayer() then
        local strength = math.Clamp(dmgAmount / 40, 0.3, 1.0)
        HitFlashBright = math.min(HitFlashBright + strength, 1.0)
        HitFlashVig    = math.min(HitFlashVig    + strength, 1.0)
    end

    ApplyBloodOnModel(entity, hitPos, dmgAmount)
end)

-- ─────────────────────────────────────────────
--  HUDPaint — экранные эффекты
-- ─────────────────────────────────────────────
function PLUGIN:HUDPaint()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() then return end
    if client:GetMoveType() == MOVETYPE_NOCLIP then return end

    local ft  = FrameTime()
    local hp  = client:Health()
    local mhp = math.max(client:GetMaxHealth(), 1)
    local hr  = math.Clamp(hp / mhp, 0, 1)

    -- Локальное определение урона для мгновенного отклика
    if prevHealth == -1 then prevHealth = hp end
    if hp < prevHealth then
        local dmg = prevHealth - hp
        local strength = math.Clamp(dmg / 40, 0.4, 1.0)
        HitFlashBright = math.min(HitFlashBright + strength, 1.0)
        HitFlashVig    = math.min(HitFlashVig    + strength, 1.0)
    end
    prevHealth = hp

    HitFlashBright = math.max(0, HitFlashBright - ft * 2.5)
    HitFlashVig    = math.max(0, HitFlashVig    - ft * 0.8)

    ConsciousnessAmt = Lerp(ft * 0.4, ConsciousnessAmt, hr)
    local underwater = client:WaterLevel() >= 3
    O2Amount = Lerp(ft * (underwater and 0.2 or 1.2), O2Amount, underwater and 0 or 1)

    local sw, sh = ScrW(), ScrH()

    -- ── 1. Яркая вспышка при попадании ───────
    if HitFlashBright > 0.01 then
        draw.NoTexture()
        surface.SetDrawColor(220, 10, 10, HitFlashBright * 180)
        surface.DrawRect(0, 0, sw, sh)
    end

    -- ── 2. Виньетка после попадания ──────────
    if HitFlashVig > 0.01 then
        DrawVignette(220, 0, 0, HitFlashVig * 255)
    end

    -- ── 3. Потеря сознания ────────────────────
    if ConsciousnessAmt < 0.85 then
        local intensity = 1 - ConsciousnessAmt

        draw.NoTexture()
        surface.SetDrawColor(30, 30, 30, intensity * 220)
        surface.DrawRect(0, 0, sw, sh)

        DrawVignette(0, 0, 0, intensity * 255)

        if ConsciousnessAmt < 0.3 then
            local blink = math.sin(CurTime() * 8) * 0.5 + 0.5
            draw.NoTexture()
            surface.SetDrawColor(0, 0, 0, blink * intensity * 255)
            surface.DrawRect(0, 0, sw, sh)
        end
    end

    -- ── 4. Нехватка кислорода ─────────────────
    if O2Amount < 0.95 then
        local o2i   = 1 - O2Amount
        local pulse = math.abs(math.sin(CurTime() * (1.5 + o2i * 4)))

        draw.NoTexture()
        surface.SetDrawColor(0, 20, 80, o2i * pulse * 120)
        surface.DrawRect(0, 0, sw, sh)

        DrawVignette(0, 30, 150, o2i * (100 + pulse * 120))

        if O2Amount < 0.2 then
            draw.NoTexture()
            surface.SetDrawColor(0, 0, 0, (1 - O2Amount * 5) * 255)
            surface.DrawRect(0, 0, sw, sh)
        end
    end
end

-- ─────────────────────────────────────────────
--  RenderScreenspaceEffects — десатурация
-- ─────────────────────────────────────────────
function PLUGIN:RenderScreenspaceEffects()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() then return end
    if client:GetMoveType() == MOVETYPE_NOCLIP then return end

    if ConsciousnessAmt < 0.95 then
        DrawColorModify({
            ["$pp_colour_brightness"] = 0,
            ["$pp_colour_contrast"]   = 1,
            ["$pp_colour_colour"]     = math.Clamp(ConsciousnessAmt / 0.95, 0, 1),
            ["$pp_colour_addr"]       = 0,
            ["$pp_colour_addg"]       = 0,
            ["$pp_colour_addb"]       = 0,
            ["$pp_colour_mulr"]       = 0,
            ["$pp_colour_mulg"]       = 0,
            ["$pp_colour_mulb"]       = 0,
        })
    end

    if O2Amount < 0.9 then
        local o2i = 1 - O2Amount
        DrawColorModify({
            ["$pp_colour_brightness"] = -o2i * 0.08,
            ["$pp_colour_contrast"]   = 1,
            ["$pp_colour_colour"]     = 1,
            ["$pp_colour_addr"]       = 0,
            ["$pp_colour_addg"]       = 0,
            ["$pp_colour_addb"]       = o2i * 0.12,
            ["$pp_colour_mulr"]       = 0,
            ["$pp_colour_mulg"]       = 0,
            ["$pp_colour_mulb"]       = 0,
        })
    end
end
