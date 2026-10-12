local PLUGIN = PLUGIN
ix.FieldVisuals = ix.FieldVisuals or {}
local V = ix.FieldVisuals
V.gain, V.light, V.nextSample = 0, 0, 0

function V.Visible()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() or not client:GetCharacter() then return false end
    -- The medical screen owns the unconscious/ragdoll view. Do not composite
    -- world, bloom, lens or NVG shaders behind its translucent eyelid fade.
    if client:GetLocalVar("knocked", false) or client:GetLocalVar("ragdoll", 0) ~= 0 then return false end
    if ix.Downed and ix.Downed.Active(client)
        and not (ix.Downed.CrawlWindow and ix.Downed.CrawlWindow(client)) then return false end
    return not gui.IsGameUIVisible()
        and not (ix.gui and (IsValid(ix.gui.characterMenu) or IsValid(ix.gui.menu) or IsValid(ix.gui.fieldlink)))
end

local function DrawLens()
    if V.DrawLightLens then V.DrawLightLens() end
    if V.lensProbeUntil and RealTime() < V.lensProbeUntil and V.DrawShader then
        V.DrawShader("lens", 1, 1, 0, 0)
        return
    end
    if ix.option.Get("fieldLens", true) and V.DrawShader then
        local lens = math.Clamp(ix.option.Get("fieldLensStrength", .4), 0, 1)
        if lens > 0 then V.DrawShader("lens", lens, 0, 0, 0) end
    end
end

function PLUGIN:RenderScreenspaceEffects()
    if not V.Visible() or ArcticNVGs_Enabled then return end
    local client = LocalPlayer()
    -- Medical and hazardous-area effects own the grade while active.
    if client:GetNWFloat("ixToxicLevel", 0) > .01 or client:GetNetVar("ixInToxicZone", false) then return end
    if not ix.option.Get("fieldCinematic", true) then DrawLens() return end
    local strength = math.Clamp(ix.option.Get("fieldCinematicStrength", .5), 0, 1)
    if strength == 0 then DrawLens() return end
    if not (V.DrawShader and V.DrawShader("world", strength, .20, 0, 0)) then
    DrawColorModify({
        ["$pp_colour_addr"] = 0,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = 0,
        ["$pp_colour_contrast"] = 1 + .045 * strength,
        ["$pp_colour_colour"] = 1 - .14 * strength,
        ["$pp_colour_mulr"] = 0,
        ["$pp_colour_mulg"] = .015 * strength,
        ["$pp_colour_mulb"] = .045 * strength
    })
    end
    local bloom = math.Clamp(ix.option.Get("fieldLightBloom", .20), 0, 1)
    if bloom > 0 and (not V.DrawLightLens or not ix.option.Get("fieldCustomShaders", true)) then
        -- A high threshold confines spill to bright pixels. No whole-screen haze.
        DrawBloom(.75, bloom * strength * .6, 4, 4, 1, 1, 1, 1, 1)
        V.lastBloomDraw = RealTime()
    end
    DrawLens()
end

-- Called from the existing NVG render path, replacing (not stacking on) its
-- very strong colour and bloom passes. Thermal and sunglasses keep their own effects.
function V.DrawNVG(spec, id)
    if not ix.option.Get("fieldNVGPolish", true) or id < 1 or id > 4 then
        if V.enhanced and ArcticNVGs_RebuildLamp then ArcticNVGs_RebuildLamp() end
        V.enhanced = false
        return false
    end
    if V.lastID ~= id then V.gain, V.nextSample = 0, 0; V.lastID = id end
    V.enhanced = true
    if not V.Visible() then
        if ArcticNVGs_Lamp then ArcticNVGs_Lamp:SetBrightness(0); ArcticNVGs_Lamp:Update() end
        return true
    end
    if CurTime() >= V.nextSample then
        V.nextSample = CurTime() + .1
        local light = render.GetLightColor(EyePos())
        V.light = math.Clamp(light.x * .2126 + light.y * .7152 + light.z * .0722, 0, 1)
    end
    -- Auto-gating responds quickly to bright areas and opens more slowly in darkness.
    local target = 1 - V.light
    local rate = target < V.gain and 5 or 1.8
    V.gain = Lerp(math.Clamp(FrameTime() * rate, 0, 1), V.gain, target)
    if ArcticNVGs_Lamp then
        ArcticNVGs_Lamp:SetBrightness(.04 + V.gain * .28)
        ArcticNVGs_Lamp:SetEnableShadows(true)
        ArcticNVGs_Lamp:Update()
    end
    local white = id == 1 or id == 3
    local phase = ix.option.Get("disableAnimations", false) and 0 or math.floor(CurTime() * 24) % 256
    -- Visible sensor grain: dark/high-gain areas get more noise, highlights less.
    local noise = ix.option.Get("fieldNVGGrain", true) and (.06 + V.gain * .10) or 0
    V.nvgShader = V.DrawShader and V.DrawShader("nvg", V.gain, white and 1 or 0, noise, phase)
    if V.nvgShader then return true end
    DrawColorModify({
        ["$pp_colour_addr"] = white and .005 or -.025,
        ["$pp_colour_addg"] = white and .014 or .035,
        ["$pp_colour_addb"] = white and .02 or -.018,
        ["$pp_colour_brightness"] = .01 + .025 * V.gain,
        ["$pp_colour_contrast"] = 1.2 + .4 * V.gain,
        ["$pp_colour_colour"] = 0,
        ["$pp_colour_mulr"] = white and .04 or 0,
        ["$pp_colour_mulg"] = white and .09 or .4,
        ["$pp_colour_mulb"] = white and .13 or .02
    })
    -- High threshold: only highlights bleed, not the whole image.
    DrawBloom(.82, .12, 2, 2, 1, 1, .8, 1, white and 1 or .65)
    return true
end

function PLUGIN:HUDPaintBackground()
    if V.DrawSun then V.DrawSun() end
    if V.nvgShader and ix.option.Get("fieldCustomShaders", true) then return end
    if not V.Visible() or not ArcticNVGs_Enabled or ArcticNVGs_Inactive
        or not ix.option.Get("fieldNVGPolish", true) or not ix.option.Get("fieldNVGGrain", true) then return end
    local id = LocalPlayer():GetNWInt("nvg", 0)
    if id < 1 or id > 4 then return end
    -- Small bounded sensor noise; no custom materials or missing-texture risk.
    draw.NoTexture()
    surface.SetDrawColor(200, 225, 210, 4 + V.gain * 5)
    local frame = ix.option.Get("disableAnimations", false) and 0 or math.floor(CurTime() * 18)
    for i = 1, 85 do
        local x = ((i * 7919 + frame * 101) % 65521) / 65521
        local y = ((i * 3253 + frame * 211) % 32749) / 32749
        surface.DrawRect(x * ScrW(), y * ScrH(), 1, 1)
    end
end

function PLUGIN:OnUnload()
    concommand.Remove("ix_shader_status")
    concommand.Remove("ix_lens_toggle")
    concommand.Remove("ix_shader_probe")
    concommand.Remove("ix_visuals_toggle")
    ix.FieldVisuals = nil
    if ArcticNVGs_Enabled and ArcticNVGs_RebuildLamp then ArcticNVGs_RebuildLamp() end
end
