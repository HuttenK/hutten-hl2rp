local M = ix.GasMask
if M.Stop then M.Stop() end
local state = {alpha = 0}
local owner, character, mask, profile, breath, nextSample, warning, warningUntil
local materials, soundExists = {}, {}
M.State = state

ix.option.Add("gasmaskVisor", ix.type.bool, true, {category = "appearance"})
ix.option.Add("gasmaskBreathing", ix.type.number, 40, {category = "appearance", min = 0, max = 100, decimals = 0})
ix.lang.AddTable("en", {optgasmaskVisor = "Gas mask visor", optgasmaskBreathing = "Gas mask breathing",
    gasmaskFilterLow = "FILTER RUNNING LOW", gasmaskFilterEmpty = "NO ACTIVE FILTER"})
ix.lang.AddTable("ru", {optgasmaskVisor = "Линзы противогаза", optgasmaskBreathing = "Дыхание в противогазе",
    gasmaskFilterLow = "ФИЛЬТР ИЗНОШЕН", gasmaskFilterEmpty = "НЕТ АКТИВНОГО ФИЛЬТРА"})

local function hasSound(path)
    if soundExists[path] == nil then soundExists[path] = file.Exists("sound/" .. path, "GAME") end
    return soundExists[path]
end
local function oneShot(path)
    if hasSound(path) then surface.PlaySound(path) end
end
local function stopBreath()
    if breath then breath:Stop(); breath = nil end
    M.Breathing = false
end
function M.Stop()
    if M.CancelAnimation then M.CancelAnimation() end
    stopBreath()
    owner, character, mask, profile, warning = nil, nil, nil, nil, nil
    state.alpha = 0
    state.visible = false
end
function M.Visible(client)
    if not IsValid(client) or not client:GetCharacter() or not client:Alive() then return false end
    if client:GetViewEntity() ~= client or client:ShouldDrawLocalPlayer() or
        client:GetLocalVar("ragdoll", 0) ~= 0 then return false end
    if client:GetNWBool("GasMaskIsOn") or client:GetNWBool("BA2_GasmaskOn") then return false end
    -- Equipment animation must not depend on the optional film-grain switch.
    if gui and gui.IsGameUIVisible() then return false end
    if ix.gui and (IsValid(ix.gui.fieldlink) or IsValid(ix.gui.menu) or IsValid(ix.gui.characterMenu) or IsValid(ix.gui.levelup)) then return false end
    if ix.infoMenu and ix.infoMenu.open then return false end
    return true
end

function M.Update()
    local client = LocalPlayer()
    if not IsValid(client) or not client:GetCharacter() or not client:Alive() then M.Stop() return end
    local currentCharacter = client:GetCharacter()
    local fresh = owner ~= client or character ~= currentCharacter
    if fresh then
        M.Stop(); owner = client; character = currentCharacter; nextSample = 0
    end
    if RealTime() >= (nextSample or 0) then
        nextSample = RealTime() + 0.15
        local equipped = M.Equipped(client)
        if equipped ~= mask then
            if not fresh and not client:GetNWBool("GasMaskIsOn") and not client:GetNWBool("BA2_GasmaskOn") then
                local soundPath = equipped and "black_ops_1/wep/gasmask/on.wav" or "black_ops_1/wep/gasmask/off.wav"
                if not M.RequestAnimation or not M.RequestAnimation(equipped ~= nil, equipped or mask, soundPath) then
                    oneShot(soundPath)
                end
            end
            stopBreath()
            mask = equipped
            -- Retain the old lens while its removal fades out.
            if mask then profile = M.Profile(mask) end
            warning = nil
        end
        local fraction = M.FilterFraction(client, mask)
        local nextWarning = mask and M.Warning(fraction)
        if nextWarning ~= warning then warningUntil = RealTime() + 6 end
        warning = nextWarning
        state.filter = fraction
    end
    local visible = M.Visible(client)
    if M.UpdateAnimation then M.UpdateAnimation(client, visible) end
    if visible and not state.visible and warning then warningUntil = RealTime() + 6 end
    local worn = mask ~= nil
    if M.AnimationVisor then worn = M.AnimationVisor(worn) end
    local target = visible and worn and profile and profile.visor and ix.option.Get("gasmaskVisor", true) and 1 or 0
    state.alpha = math.Approach(state.alpha, target, FrameTime() / 0.55)
    state.visible = visible
    local volume = math.Clamp(tonumber(ix.option.Get("gasmaskBreathing", 40)) or 0, 0, 100) / 100
    if not visible or not worn or not mask or client:WaterLevel() >= 3 or volume <= 0 or not hasSound(profile.breath) then
        stopBreath(); return
    end
    if not breath then
        breath = CreateSound(client, profile.breath)
        if breath then breath:PlayEx(0, 100) end
    end
    M.Breathing = breath ~= nil
    if breath then
        local maximum = currentCharacter.GetMaxStamina and currentCharacter:GetMaxStamina() or 100
        local effort = 1 - math.Clamp(client:GetLocalVar("stm", 100) / math.max(maximum, 1), 0, 1)
        breath:ChangeVolume(volume * (0.22 + effort * 0.28), 0.5)
        breath:ChangePitch(96 + effort * 10, 0.7)
    end
end

hook.Add("Think", "ixEquipmentGasMask", M.Update)
hook.Add("ShutDown", "ixEquipmentGasMask", M.Stop)
hook.Add("HUDPaintBackground", "ixEquipmentGasMask", function()
    if not state.visible or state.alpha <= 0.001 or not profile then return end
    local mat = materials[profile.overlay]
    if mat == nil then
        mat = Material(profile.overlay, "smooth")
        materials[profile.overlay] = mat
    end
    if mat:IsError() then return end
    surface.SetMaterial(mat)
    surface.SetDrawColor(255, 255, 255, state.alpha * 255)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
end)
hook.Add("HUDPaint", "ixEquipmentGasMaskWarning", function()
    if not state.visible or not mask or not warning or RealTime() > (warningUntil or 0) then return end
    local alpha = math.Clamp((warningUntil - RealTime()) * 255, 0, 220)
    draw.SimpleTextOutlined(L(warning), "DermaDefault", ScrW() * 0.5, ScrH() * 0.86,
        Color(225, 193, 145, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, alpha))
end)
