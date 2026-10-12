-- Companion only: requires the original SD Citizens pack. No model replacements.
if SERVER then
    AddCSLuaFile()
    local function sendMaterials(path)
        local files, directories = file.Find(path .. "/*", "GAME")
        for _, name in ipairs(files) do resource.AddFile(path .. "/" .. name) end
        for _, name in ipairs(directories) do sendMaterials(path .. "/" .. name) end
    end
    sendMaterials("materials/sd_dclass_companion")
    include("sd_dclass_companion/resources.lua")
    return
end

SDDClass = SDDClass or {}
local D = SDDClass
local definitions = {
    jacket = {source = "models/sectorialdistrict/citizens/city_top3", group = "torso", value = 11,
        rect = {0, 0, 1 / 3, 1 / 3}},
    pants = {source = "models/sectorialdistrict/citizens/city_top", group = "legs", value = 4,
        rect = {0, 2 / 3, 1, 1 / 3}}
}
-- These materials depended on missing maps/proxies to restrain their specular.
definitions.securityArmor = {source = "models/sectorialdistrict/citizens/hlvr_armor_security", armor = true}
definitions.bodyArmor = {source = "models/sectorialdistrict/citizens/combine_captain_body_gear", armor = true}
definitions.legArmor = {source = "models/sectorialdistrict/citizens/combine_captain_legs_gear", armor = true}
definitions.policeArmor = {source = "models/sectorialdistrict/citizens/metropolice_body", armor = true}
local ready = false
local owned = setmetatable({}, {__mode = "k"})
local modelCache = {}

-- Crisp, original stencil geometry. The back UV island is mirrored.
local function markD(size, ink)
    local x, y, w, h = size * 0.197, size * 0.207, size * 0.042, size * 0.060
    local t = w * 0.20
    -- Sample the same cloth luminance inside the lettering: folds and weave
    -- continue through the ink instead of being covered by a flat black decal.
    surface.SetMaterial(ink)
    surface.SetDrawColor(42, 35, 28, 255)
    surface.DrawTexturedRectUV(x + w - t, y, t, h,
        (x + w - t) / size, y / size, (x + w) / size, (y + h) / size)
    local cx, cy, rx, ry = x + w - t, y + h / 2, w - t, h / 2
    for i = 0, 47 do
        local a, b = math.pi / 2 + math.pi * i / 48, math.pi / 2 + math.pi * (i + 1) / 48
        if math.abs(math.sin((a + b) / 2)) > 0.025 then
            local vertices = {
                {x = cx + math.cos(a) * rx, y = cy + math.sin(a) * ry},
                {x = cx + math.cos(b) * rx, y = cy + math.sin(b) * ry},
                {x = cx + math.cos(b) * (rx - t), y = cy + math.sin(b) * (ry - t)},
                {x = cx + math.cos(a) * (rx - t), y = cy + math.sin(a) * (ry - t)}
            }
            for _, vertex in ipairs(vertices) do
                vertex.u = vertex.x / size; vertex.v = vertex.y / size
            end
            surface.DrawPoly(vertices)
        end
    end
end

-- Compose only on the client, using the user's installed SD diffuse as the base.
-- It is never saved, exported or included in this addon.
local function build(kind, definition)
    local original = Material(definition.source)
    if original:IsError() then return false end
    if definition.armor then
        local diffuse = original:GetTexture("$basetexture")
        if not diffuse or diffuse:IsError() then return false end
        -- CreateMaterial cannot accept the ITexture objects from GetKeyValues.
        -- Use explicit paths, then bind the installed textures themselves.
        local values = {
            ["$basetexture"] = diffuse:GetName(), ["$model"] = "1",
            ["$nocull"] = "1", ["$phong"] = "1", ["$phongboost"] = "0.18",
            ["$phongexponent"] = "12", ["$phongfresnelranges"] = "[0.05 0.15 0.35]",
            ["$phongtint"] = "[1 1 1]", ["$envmaptint"] = "[0 0 0]"
        }
        local textures = {["$basetexture"] = diffuse}
        for _, key in ipairs({"$bumpmap", "$detail"}) do
            local texture = original:GetTexture(key)
            if texture and not texture:IsError() then
                textures[key] = texture
                values[key] = texture:GetName()
            end
        end
        for _, key in ipairs({"$detailscale", "$detailblendfactor", "$detailblendmode"}) do
            values[key] = tostring(original:GetFloat(key) or 0)
        end
        definition.material = "sd_dclass_armor_v2_" .. kind
        definition.object = CreateMaterial(definition.material, "VertexLitGeneric", values)
        for key, texture in pairs(textures) do definition.object:SetTexture(key, texture) end
        return true
    end
    local texture = original:GetTexture("$basetexture")
    if not texture then return false end
    local size = math.Clamp(texture:Width(), 2048, 4096)
    -- Retain the installed atlas resolution, seams, buttons and matching normal map.
    -- A private shader samples the original texture, never the player's framebuffer.
    local gray = GetRenderTargetEx("sd_dclass_luminance_v3_" .. size, size, size,
        RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, 0, 0, IMAGE_FORMAT_RGBA8888)
    local recolor = CreateMaterial("sd_dclass_grayscale_v3_" .. kind, "g_colourmodify", {
        ["$fbtexture"] = texture:GetName(), ["$pp_colour_colour"] = "0",
        ["$pp_colour_brightness"] = "0.015", ["$pp_colour_contrast"] = "1.08",
        ["$pp_colour_addr"] = "0", ["$pp_colour_addg"] = "0", ["$pp_colour_addb"] = "0",
        ["$pp_colour_mulr"] = "0", ["$pp_colour_mulg"] = "0", ["$pp_colour_mulb"] = "0",
        ["$pp_colour_inv"] = "0"
    })
    recolor:SetTexture("$fbtexture", texture)
    render.PushRenderTarget(gray)
    render.SetMaterial(recolor)
    render.DrawScreenQuad()
    render.PopRenderTarget()
    local overlay = CreateMaterial("sd_dclass_tint_v3_" .. kind, "UnlitGeneric", {
        ["$basetexture"] = gray:GetName(), ["$vertexcolor"] = "1", ["$ignorez"] = "1"
    })
    local target = GetRenderTargetEx("sd_dclass_companion_v3_" .. kind, size, size,
        RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, 0, 0, IMAGE_FORMAT_RGBA8888)
    local background = CreateMaterial("sd_dclass_companion_base_v3_" .. kind, "UnlitGeneric", {
        ["$basetexture"] = texture:GetName(), ["$ignorez"] = "1"
    })
    render.PushRenderTarget(target)
    render.Clear(0, 0, 0, 255, false, false)
    cam.Start2D()
    local clipped = DisableClipping(true)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(background)
    surface.DrawTexturedRect(0, 0, size, size)
    local r = definition.rect
    surface.SetDrawColor(245, 153, 67, 255)
    surface.SetMaterial(overlay)
    surface.DrawTexturedRectUV(r[1] * size, r[2] * size, r[3] * size, r[4] * size,
        r[1], r[2], r[1] + r[3], r[2] + r[4])
    if kind == "jacket" then
        markD(size, overlay)
    else
        -- Shoes share this atlas, but should retain their installed original finish.
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(background)
        surface.DrawTexturedRectUV(0, size * 0.85, size * 0.16, size * 0.15, 0, 0.85, 0.16, 1)
    end
    DisableClipping(clipped)
    cam.End2D()
    render.PopRenderTarget()
    local values = table.Copy(original:GetKeyValues())
    values["$basetexture"] = target:GetName()
    definition.material = "sd_dclass_companion_worn_v3_" .. kind
    definition.object = CreateMaterial(definition.material, original:GetShader(), values)
    definition.object:SetTexture("$basetexture", target)
    return true
end

local nextBuild = 0
hook.Add("PreRender", "SDDClass.Build", function()
    if ready or RealTime() < nextBuild then return end
    nextBuild = RealTime() + 5
    local complete = true
    for kind, definition in pairs(definitions) do
        if not definition.object and not build(kind, definition) then complete = false end
    end
    ready = complete
end)

local function profile(entity, model)
    if modelCache[model] then return modelCache[model] end
    local result = {groups = {}, slots = {}}
    for _, group in ipairs(entity:GetBodyGroups()) do
        result.groups[string.lower(group.name)] = group.id
    end
    for index, material in ipairs(entity:GetMaterials()) do
        result.slots[string.lower(material:gsub("\\", "/"))] = index - 1
    end
    modelCache[model] = result
    return result
end

function D.Apply(entity)
    if not ready or not IsValid(entity) then return end
    local model = string.lower(entity:GetModel() or "")
    local state = owned[entity]
    local supported = model:match("^models/sd/citizens/citizen_male_") or
        model:match("^models/sd/citizens/citizen_female_")
    if state and state.model ~= model then
        for slot, previous in pairs(state.slots) do
            if entity:GetSubMaterial(slot) == previous.applied then entity:SetSubMaterial(slot, "") end
        end
        owned[entity] = nil
        state = nil
    end
    if not supported then return end
    local info = profile(entity, model)
    state = state or {model = model, slots = {}}
    owned[entity] = state
    for _, definition in pairs(definitions) do
        local slot, group = info.slots[definition.source], info.groups[definition.group]
        if slot and (group or definition.armor) then
            local previous = state.slots[slot]
            if definition.armor or entity:GetBodygroup(group) == definition.value then
                local applied = "!" .. definition.material
                if not previous then
                    state.slots[slot] = {saved = entity:GetSubMaterial(slot), applied = applied}
                elseif entity:GetSubMaterial(slot) ~= previous.applied then
                    previous.saved = entity:GetSubMaterial(slot)
                end
                entity:SetSubMaterial(slot, applied)
            elseif previous then
                if entity:GetSubMaterial(slot) == previous.applied then
                    entity:SetSubMaterial(slot, previous.saved)
                end
                state.slots[slot] = nil
            end
        end
    end
end

hook.Add("PrePlayerDraw", "SDDClass.Apply", function(player) D.Apply(player) end)
hook.Add("SDDClassApply", "SDDClass.Apply", function(entity) D.Apply(entity) end)
-- Includes ragdolls, props and ordinary client models. Player draws update immediately.
timer.Create("SDDClass.Entities", 0.25, 0, function()
    if not ready then return end
    for _, entity in ipairs(ents.GetAll()) do D.Apply(entity) end
end)

-- Runtime fallbacks for the two absent original diffuse/iris assets. These refer
-- to textures already installed with SD; no original texture is redistributed.
hook.Add("InitPostEntity", "SDDClass.MissingDiffuse", function()
    local suit = Material("models/sectorialdistrict/citizens/city_suit"):GetTexture("$basetexture")
    local apf = Material("models/sectorialdistrict/citizens/combine_soldier_apf")
    if suit and not apf:IsError() and not file.Exists("materials/models/sectorialdistrict/overwatch/apf/combine_soldier_apf_color.vtf", "GAME") then
        apf:SetTexture("$basetexture", suit)
    end
end)
