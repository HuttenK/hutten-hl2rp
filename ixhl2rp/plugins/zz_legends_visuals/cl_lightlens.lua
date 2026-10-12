local V = ix.FieldVisuals
local nearRT, wideRT, dirtRT, bufferKey
-- VTF clamp-S (4) and clamp-T (8). TEXTUREFLAGS_* are documentation names,
-- not exported GMod Lua globals: https://wiki.facepunch.com/gmod/Enums/TEXTUREFLAGS
local CLAMP_TEXTURE_FLAGS = 12

local function Quad(mat, width, height)
    cam.Start2D()
        surface.SetMaterial(mat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, width, height)
    cam.End2D()
end

function V.DrawLightLens()
    if not ix.option.Get("fieldCustomShaders", true) then return false end
    local mats = V.lightMaterials or {}
    if not mats.bright or not mats.glow then return false end
    local bloom = ix.option.Get("fieldCinematic", true) and math.Clamp(ix.option.Get("fieldLightBloom", .20), 0, 1) or 0
    local dirt = ix.option.Get("fieldLensDirt", true) and math.Clamp(ix.option.Get("fieldLensDirtStrength", .6), 0, 1) or 0
    if bloom == 0 and dirt == 0 then return false end
    -- Native BlurRenderTarget uses GetBloomTex1 as scratch and preserves the
    -- current viewport, so every target must have exactly that texture's size.
    local scratch = render.GetBloomTex1()
    local width, height = scratch:Width(), scratch:Height()
    if width < 1 or height < 1 then return false end
    local key = width .. "x" .. height
    if key ~= bufferKey then
        local function Buffer(name)
            return GetRenderTargetEx("field_light_v2_" .. name .. "_" .. key,
                width, height, RT_SIZE_LITERAL, MATERIAL_RT_DEPTH_NONE,
                CLAMP_TEXTURE_FLAGS, 0, IMAGE_FORMAT_RGB888)
        end
        nearRT, wideRT, dirtRT, bufferKey = Buffer("near"), Buffer("wide"), Buffer("directed_dirt"), key
    end
    local scene = render.GetScreenEffectTexture()
    render.CopyRenderTargetToTexture(scene)
    mats.bright:SetTexture("$basetexture", scene)
    mats.bright:SetFloat("$c0_x", 0)
    mats.bright:SetFloat("$c0_y", ScrW() / math.max(ScrH(), 1))
    render.PushRenderTarget(nearRT)
        render.Clear(0, 0, 0, 255, false, false)
        Quad(mats.bright, width, height)
        render.CopyRenderTargetToTexture(wideRT)
    -- BlurRenderTarget changes the active target and does not restore it.
    -- Keep both calls inside the saved target/viewport scope, then restore
    -- the caller before submitting the final full-screen composite.
    render.BlurRenderTarget(nearRT, 3, 3, 2)
    render.BlurRenderTarget(wideRT, 18, 18, 3)
    render.PopRenderTarget()
    -- Independent source mask keeps daylight bloom from exposing lens dirt.
    mats.bright:SetFloat("$c0_x", 1)
    render.PushRenderTarget(dirtRT)
        render.Clear(0, 0, 0, 255, false, false)
        Quad(mats.bright, width, height)
        render.BlurRenderTarget(dirtRT, 10, 10, 2)
    render.PopRenderTarget()
    mats.glow:SetTexture("$basetexture", scene)
    mats.glow:SetTexture("$texture1", nearRT)
    mats.glow:SetTexture("$texture2", wideRT)
    mats.glow:SetTexture("$texture3", dirtRT)
    mats.glow:SetFloat("$c0_x", bloom)
    mats.glow:SetFloat("$c0_y", dirt)
    mats.glow:SetFloat("$c0_z", ScrW() / math.max(ScrH(), 1))
    Quad(mats.glow, ScrW(), ScrH())
    V.lastBloomDraw = RealTime()
    return true
end
