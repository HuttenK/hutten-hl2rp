local PLUGIN = PLUGIN
ix.FieldVisuals = ix.FieldVisuals or {}
local V = ix.FieldVisuals
V.gain, V.light, V.nextSample = 0, 0, 0

function V.Visible()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() or not client:GetCharacter() then return false end
    -- The medical screen owns the unconscious/ragdoll view. Do not composite
    -- world, bloom or lens shaders behind its translucent eyelid fade.
    if client:GetLocalVar("knocked", false) or client:GetLocalVar("ragdoll", 0) ~= 0 then return false end
    if ix.Downed and ix.Downed.Active(client)
        and not (ix.Downed.CrawlWindow and ix.Downed.CrawlWindow(client)) then return false end
    return not gui.IsGameUIVisible()
        and not (ix.gui and (IsValid(ix.gui.characterMenu) or IsValid(ix.gui.menu)))
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
    if not V.Visible() then return end
    local client = LocalPlayer()
    -- Medical and hazardous-area effects own the grade while active.
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

function PLUGIN:OnUnload()
 for _,name in ipairs({"ix_shader_status","ix_lens_toggle","ix_shader_probe","ix_visuals_toggle"}) do concommand.Remove(name) end
 ix.FieldVisuals=nil
end
