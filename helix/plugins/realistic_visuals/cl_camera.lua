local PLUGIN = PLUGIN

-- ─────────────────────────────────────────────
--  Конфигурация
-- ─────────────────────────────────────────────
local CFG = {
    -- Боббинг
    bobSpeed       = 1.5,
    bobIntensity   = 0.5,

    -- Дыхание
    breathSpeed    = 2.0,
    breathIntensity = 0.08,

    -- Покачивание от мыши (sway)
    swaySmoothing  = 8.0,   -- скорость затухания sway
    swayMaxAngle   = 2.0,   -- максимальный угол сдвига

    -- Приземление
    landSpeedDiv   = 100,   -- делитель для силы удара
    landRollDiv    = 200,
}

-- ─────────────────────────────────────────────
--  Локальное состояние
-- ─────────────────────────────────────────────
local walkTime  = 0
local walkLerp  = 0

-- Sway
local swayPitch = 0
local swayYaw   = 0
local lastAngles = Angle(0, 0, 0)

local lastFrame = 0

-- Оффсеты для текущего кадра
local currentOffsetP = 0
local currentOffsetY = 0
local currentOffsetR = 0

-- ─────────────────────────────────────────────
--  CalcView
-- ─────────────────────────────────────────────
function PLUGIN:CalcView(client, origin, angles, fov)
    if not client:Alive()
    or client:InVehicle()
    or client:GetMoveType() == MOVETYPE_NOCLIP then
        return
    end

    -- Don't run when third person camera is active
    if (client.CanOverrideView and client:CanOverrideView()) then
        return
    end

    -- Пока игрок в рэгдолле (нокдаун/усыпление/крит) не трогаем вид: им займётся
    -- ядро (GM:CalcView следит за глазами рэгдолла). Иначе мы вернули бы вид со
    -- стоячим origin, и камера застряла бы там, где персонаж стоял.
    local ragdoll = Entity(client:GetLocalVar("ragdoll", 0))

    if (IsValid(ragdoll) and ragdoll:IsRagdoll()) then
        return
    end

    local curFrame = FrameNumber()

    -- Обновляем состояние только один раз за кадр, 
    -- чтобы избежать багов при многократном рендере (вода, зеркала, тени)
    if curFrame ~= lastFrame then
        lastFrame = curFrame

        local speed     = client:GetVelocity():Length()
        local frameTime = FrameTime()
        local runSpeed  = client:GetRunSpeed()

        -- ── Боббинг ──────────────────────────────
        local targetLerp = 0
        if client:OnGround() and runSpeed > 0 then
            targetLerp = math.Clamp(speed / runSpeed, 0, 1)
        end

        walkLerp = Lerp(frameTime * (client:OnGround() and 10 or 5), walkLerp, targetLerp)
        walkTime = walkTime + frameTime * walkLerp * 10 * CFG.bobSpeed

        local bobX = math.cos(walkTime)       * walkLerp * CFG.bobIntensity
        local bobY = math.sin(walkTime * 0.5) * walkLerp * CFG.bobIntensity

        -- ── Sway от мыши ─────────────────────────
        -- Считаем дельту углов камеры (надёжнее, чем gui.MouseX/Y)
        local deltaP = math.AngleDifference(angles.p, lastAngles.p)
        local deltaY = math.AngleDifference(angles.y, lastAngles.y)
        lastAngles   = Angle(angles.p, angles.y, angles.r)

        swayPitch = Lerp(frameTime * CFG.swaySmoothing, swayPitch, -deltaP * 0.04)
        swayYaw   = Lerp(frameTime * CFG.swaySmoothing, swayYaw,   -deltaY * 0.04)

        swayPitch = math.Clamp(swayPitch, -CFG.swayMaxAngle, CFG.swayMaxAngle)
        swayYaw   = math.Clamp(swayYaw,   -CFG.swayMaxAngle, CFG.swayMaxAngle)

        -- ── Дыхание ──────────────────────────────
        local breathing = math.sin(CurTime() * CFG.breathSpeed) * CFG.breathIntensity

        currentOffsetP = bobY + breathing + swayPitch
        currentOffsetY = bobX + swayYaw
        currentOffsetR = bobX * 2
    end

    -- ── Суммируем ────────────────────────────
    local newAngles  = Angle(angles.p, angles.y, angles.r)
    newAngles.p = newAngles.p + currentOffsetP
    newAngles.y = newAngles.y + currentOffsetY
    newAngles.r = newAngles.r + currentOffsetR

    return {
        origin = origin,
        angles = newAngles,
        fov    = fov,
    }
end

-- ─────────────────────────────────────────────
--  Удар о землю
-- ─────────────────────────────────────────────
function PLUGIN:OnPlayerHitGround(client, bInWater, bOnFloater, speed)
    -- Файл клиентский, но крюк срабатывает и для других игроков — проверяем
    if client ~= LocalPlayer() then return end
    if speed < 100 then return end  -- мелкие прыжки не трясут камеру

    local factor    = speed / CFG.landSpeedDiv
    local rollRange = speed / CFG.landRollDiv
    local punch     = Angle(factor, 0, math.Rand(-rollRange, rollRange))

    client:ViewPunch(punch)
end
