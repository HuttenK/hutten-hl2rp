local V = ix.FieldVisuals
local glow = Material("sprites/light_glow02_add")
local opacity = 0

local function Sprite(x, y, w, h, r, g, b, a)
    surface.SetMaterial(glow)
    -- This stock additive sprite cannot be relied on to honor vertex alpha.
    -- Fade its emitted RGB instead: black adds nothing, including on renderers
    -- where the material ignores alpha. Keep alpha full to avoid double fading.
    local intensity = math.Clamp(a / 255, 0, 1)
    surface.SetDrawColor(r * intensity, g * intensity, b * intensity, 255)
    surface.DrawTexturedRect(x - w / 2, y - h / 2, w, h)
end

function V.DrawSun()
    if not V.Visible() or ArcticNVGs_Enabled or not ix.option.Get("fieldSunGlare", true)
        or glow:IsError() then opacity = 0 return end
    local strength = math.Clamp(ix.option.Get("fieldSunGlareStrength", .65), 0, 1)
    if strength == 0 then opacity = 0 return end
    -- Use the engine's actual sun, never a guessed world direction.
    local sun = util.GetSunInfo()
    if not sun or not sun.direction then opacity = 0 return end
    local dir = sun.direction:GetNormalized()
    local facing = math.Clamp((dir:Dot(EyeVector()) - .65) / .35, 0, 1)
    if dir:Dot(EyeVector()) <= 0 then opacity = 0 return end
    local eye = EyePos()
    local trace = util.TraceLine({start = eye, endpos = eye + dir * 32768,
        mask = MASK_VISIBLE, filter = LocalPlayer()})
    -- No residual glow through walls, including when stepping indoors.
    if trace.StartSolid or (trace.Hit and not trace.HitSky) then opacity = 0 return end
    local pos = (eye + dir * 8192):ToScreen()
    local w, h = ScrW(), ScrH()
    -- Feather the screen boundary so a sun entering/leaving the viewport
    -- cannot suddenly reveal a large halo or its distant lens ghosts.
    local edge = math.Clamp(math.min(pos.x, w-pos.x, pos.y, h-pos.y) / (h*.18), 0, 1)
    edge = edge * edge * (3 - 2 * edge)
    local target = strength * facing * facing * math.Clamp(sun.obstruction or 0, 0, 1) * edge
    if not pos.visible then target = 0 end
    -- Exponential smoothing is frame-rate independent. Cap a stalled frame's
    -- contribution so returning from a hitch doesn't jump straight to full glare.
    local rate = target > opacity and 2.8 or 4
    opacity = Lerp(1 - math.exp(-math.Clamp(FrameTime(), 0, .05) * rate), opacity, target)
    local alpha = opacity * edge
    if not pos.visible or alpha < .002 then return end
    local size = math.min(w, h)
    -- Additive warm halo with narrow optical streaks, drawn below the HUD.
    Sprite(pos.x, pos.y, size*.40, size*.40, 255, 205, 145, 115*alpha)
    Sprite(pos.x, pos.y, size*.11, size*.11, 255, 245, 220, 220*alpha)
    Sprite(pos.x, pos.y, size*.60, size*.016, 255, 220, 170, 110*alpha)
    Sprite(pos.x, pos.y, size*.014, size*.30, 210, 225, 255, 65*alpha)
    local dx, dy = w*.5-pos.x, h*.5-pos.y
    for i, factor in ipairs({.65, 1.3, 1.9}) do
        local radius = size*(.018+i*.009)
        local x, y = pos.x+dx*factor, pos.y+dy*factor
        -- Each ghost can cross a different viewport edge from the sun itself.
        local ghostEdge = math.Clamp(math.min(x, w-x, y, h-y) / (radius*3), 0, 1)
        ghostEdge = ghostEdge * ghostEdge * (3 - 2 * ghostEdge)
        Sprite(x, y, radius*2, radius*2,
            140+i*28, 190, 255-i*25, 110*alpha*ghostEdge)
    end
    -- Faint spectral ring. Procedural geometry avoids external lens textures.
    local radius = size*.19
    for band = 1, 3 do
        surface.SetDrawColor(255-band*30, 145+band*25, 125+band*35, 18*alpha)
        local r = radius + band*2
        for segment = 0, 95 do
            local a, b = segment*math.pi/48, (segment+1)*math.pi/48
            surface.DrawLine(pos.x+math.cos(a)*r, pos.y+math.sin(a)*r,
                pos.x+math.cos(b)*r, pos.y+math.sin(b)*r)
        end
    end
end
