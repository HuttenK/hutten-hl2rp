local PLUGIN = PLUGIN

-- ─────────────────────────────────────────────
--  Текстуры
-- ─────────────────────────────────────────────
local matVignette = Material("helix/gui/vignette.png", "smooth")

-- ─────────────────────────────────────────────
--  Состояние индикатора попадания
-- ─────────────────────────────────────────────
local HitFlashBright = 0
local HitFlashVig    = 0
local prevHealth     = -1

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
--  HUDPaint — индикатор попадания
-- ─────────────────────────────────────────────
function PLUGIN:HUDPaint()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() then return end
    if client:GetMoveType() == MOVETYPE_NOCLIP then return end

    local ft = FrameTime()
    local hp = client:Health()

    -- Локальное определение урона для мгновенного отклика
    if prevHealth == -1 then prevHealth = hp end
    if hp < prevHealth then
        local dmg      = prevHealth - hp
        local strength = math.Clamp(dmg / 40, 0.4, 1.0)
        HitFlashBright = math.min(HitFlashBright + strength, 1.0)
        HitFlashVig    = math.min(HitFlashVig    + strength, 1.0)
    end
    prevHealth = hp

    HitFlashBright = math.max(0, HitFlashBright - ft * 2.5)
    HitFlashVig    = math.max(0, HitFlashVig    - ft * 0.8)

    local sw, sh = ScrW(), ScrH()

    -- ── Яркая вспышка при попадании ───────
    if HitFlashBright > 0.01 then
        draw.NoTexture()
        surface.SetDrawColor(220, 10, 10, HitFlashBright * 180)
        surface.DrawRect(0, 0, sw, sh)
    end

    -- ── Виньетка после попадания ──────────
    if HitFlashVig > 0.01 then
        DrawVignette(220, 0, 0, HitFlashVig * 255)
    end
end
