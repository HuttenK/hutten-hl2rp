local V = ix.FieldVisuals
local bundle = include("cl_shader_payload.lua")
local materials = {}
V.shaderStatus = "not loaded"

local function LoadShaders()
    if render.GetDXLevel() < 95 then V.shaderStatus = "requires DX9 SM2.0b; using fallback" return end
    local bytes = util.Base64Decode(bundle.payload)
    if not bytes or #bytes == 0 then V.shaderStatus = "invalid bundle; using fallback" return end
    -- MountGMA exposes compiled shaders through a supported engine search path.
    -- Embed with client Lua so dedicated servers need no binary module/FastDL setup.
    local filename = bundle.stem .. ".gma"
    if file.Read(filename, "DATA") ~= bytes then file.Write(filename, bytes) end
    local ok = game.MountGMA("data/" .. filename)
    if not ok then V.shaderStatus = "mount failed; using fallback" return end
    for _, name in ipairs({"world", "nvg", "lens", "bright", "glow"}) do
        -- Version the material as well: CreateMaterial reuses an existing name
        -- after Lua refresh, even when its vertex flags have changed.
        local mat = CreateMaterial(bundle.stem .. "_surface_v3_" .. name, "screenspace_general", {
            ["$pixshader"] = bundle.stem .. "_" .. name .. "_ps20",
            ["$basetexture"] = "_rt_FullFrameFB",
            ["$ignorez"] = "1", ["$depthtest"] = "0", ["$writealpha"] = "0",
            -- DrawScreenQuad supplies screen-space vertices. The default
            -- untransformed shader treats them as clip-space positions.
            ["$vertextransform"] = "1",
            ["$vertexcolor"] = "1",
            ["$linearread_basetexture"] = "1", ["$linearwrite"] = "1",
            ["$texture1"] = "_rt_FullFrameFB", ["$texture2"] = "_rt_FullFrameFB",
            ["$texture3"] = "_rt_FullFrameFB", ["$linearread_texture3"] = "1",
            ["$linearread_texture1"] = "1", ["$linearread_texture2"] = "1",
            ["$alpha_blend"] = "0", ["$copyalpha"] = "0"
        })
        if mat:IsError() then V.shaderStatus = "material failed; using fallback" materials = {} return end
        materials[name] = mat
    end
    V.shaderStatus = "bundle mounted / materials created (GPU output needs visual verification)"
end
LoadShaders()
V.lightMaterials = materials

function V.DrawShader(name, a, b, c, d)
    if not ix.option.Get("fieldCustomShaders", true) then return false end
    local mat = materials[name]
    if not mat then return false end
    local width, height = ScrW(), ScrH()
    if width < 1 or height < 1 then return false end
    mat:SetFloat("$c0_x", a); mat:SetFloat("$c0_y", b)
    mat:SetFloat("$c0_z", name == "world" and 1 / width or c)
    mat:SetFloat("$c0_w", name == "world" and 1 / height or d)
    mat:SetFloat("$c1_x", 1 / width); mat:SetFloat("$c1_y", 1 / height)
    local input = render.GetScreenEffectTexture()
    -- Capture the current target explicitly, as native DrawBloom does, so each
    -- pass consumes the preceding pass rather than an earlier screen snapshot.
    render.CopyRenderTargetToTexture(input)
    mat:SetTexture("$basetexture", input)
    -- Own the orthographic context; neither the world nor NVG caller should
    -- leave this quad dependent on a previous addon's camera matrices.
    cam.Start2D()
        -- Explicit pixel geometry matches VERTEXTRANSFORM's 2D projection,
        -- using the same material path as the existing working UI shaders.
        surface.SetMaterial(mat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, width, height)
    cam.End2D()
    if name == "lens" then V.lastLensDraw = RealTime() end
    if name == "world" then V.lastWorldDraw = RealTime() end
    return true
end

concommand.Add("ix_shader_probe", function()
    V.lensProbeUntil = RealTime() + 10
    print("[Fieldlink probe] Close the console: a coloured gradient should replace the scene for 10 seconds. Settings are unchanged.")
end)

concommand.Add("ix_lens_toggle", function()
    local enabled = not ix.option.Get("fieldLens", true)
    ix.option.Set("fieldLens", enabled)
    print("[Fieldlink lens] " .. (enabled and "ON" or "OFF")
        .. "; intensity=" .. tostring(ix.option.Get("fieldLensStrength", .4))
        .. "; custom shaders=" .. tostring(ix.option.Get("fieldCustomShaders", true)))
end)

concommand.Add("ix_shader_status", function()
    print("[Fieldlink shaders] " .. bundle.version .. ": " .. V.shaderStatus)
    print("[Fieldlink shaders] enabled=" .. tostring(ix.option.Get("fieldCustomShaders", true))
        .. "; DX=" .. render.GetDXLevel())
    print("[Fieldlink world] enabled=" .. tostring(ix.option.Get("fieldCinematic", true))
        .. "; strength=" .. tostring(ix.option.Get("fieldCinematicStrength", .5))
        .. "; bloom=" .. tostring(ix.option.Get("fieldLightBloom", .20))
        .. "; last world draw=" .. (V.lastWorldDraw and string.format("%.1fs ago", RealTime() - V.lastWorldDraw) or "never")
        .. "; last bloom=" .. (V.lastBloomDraw and string.format("%.1fs ago", RealTime() - V.lastBloomDraw) or "never"))
    print("[Fieldlink light lens] dirt=" .. tostring(ix.option.Get("fieldLensDirt", true))
        .. "; strength=" .. tostring(ix.option.Get("fieldLensDirtStrength", .6)))
    print("[Fieldlink lens] enabled=" .. tostring(ix.option.Get("fieldLens", true))
        .. "; intensity=" .. tostring(ix.option.Get("fieldLensStrength", .4))
        .. "; last draw submitted=" .. (V.lastLensDraw and string.format("%.1fs ago", RealTime() - V.lastLensDraw) or "never"))
end)

concommand.Add("ix_visuals_toggle", function()
    local enabled = not ix.option.Get("fieldCinematic", true)
    ix.option.Set("fieldCinematic", enabled)
    print("[Fieldlink grading/bloom/edge shading] " .. (enabled and "ON" or "OFF") .. "; lens unchanged")
end)
