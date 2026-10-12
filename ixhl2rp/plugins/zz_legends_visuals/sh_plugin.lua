PLUGIN.name = "Fieldlink visual presentation"
PLUGIN.author = "Legends"
PLUGIN.description = "Restrained colour grading and adaptive night optics."
ix.lang.AddTable("ru", {
    ["option.category.fieldVisuals"] = "Изображение",
    ["option.fieldCustomShaders"] = "Шейдеры Fieldlink",
    ["option.fieldLens"] = "Эффект объектива",
    ["option.fieldLensStrength"] = "Интенсивность эффекта объектива",
    ["option.fieldSunGlare"] = "Солнечные блики",
    ["option.fieldSunGlareStrength"] = "Интенсивность солнечных бликов",
    ["option.fieldCinematic"] = "Кинематографическая цветокоррекция",
    ["option.fieldCinematicStrength"] = "Интенсивность цветокоррекции",
    ["option.fieldLightBloom"] = "Свечение ярких источников света",
    ["option.fieldEdgeShading"] = "Затемнение краёв изображения",
    ["option.fieldFlashlightPolish"] = "Плавный луч фонаря",
    ["option.fieldNVGPolish"] = "Адаптивное изображение ПНВ",
    ["option.fieldNVGGrain"] = "Зерно ПНВ"
})
ix.lang.AddTable("en", {
    ["option.category.fieldVisuals"] = "Visual presentation",
    ["option.fieldCustomShaders"] = "Fieldlink shaders",
    ["option.fieldLens"] = "Camera lens effect",
    ["option.fieldLensStrength"] = "Camera lens intensity",
    ["option.fieldSunGlare"] = "Sun glare",
    ["option.fieldSunGlareStrength"] = "Sun glare strength",
    ["option.fieldCinematic"] = "Cinematic colour grading",
    ["option.fieldCinematicStrength"] = "Colour grading strength",
    ["option.fieldLightBloom"] = "Bright light bloom",
    ["option.fieldEdgeShading"] = "Screen edge shading",
    ["option.fieldFlashlightPolish"] = "Smooth flashlight beam",
    ["option.fieldNVGPolish"] = "Adaptive night vision",
    ["option.fieldNVGGrain"] = "Night vision grain"
})
for _, name in ipairs({"fieldCustomShaders", "fieldCinematic", "fieldLens", "fieldFlashlightPolish", "fieldNVGPolish", "fieldNVGGrain"}) do
    ix.option.Add(name, ix.type.bool, true, {category = "option.category.fieldVisuals"})
end
ix.option.Add("fieldLensStrength", ix.type.number, .4, {
    category = "option.category.fieldVisuals", min = 0, max = 1, decimals = 2
})
ix.option.Add("fieldCinematicStrength", ix.type.number, .5, {
    category = "option.category.fieldVisuals", min = 0, max = 1, decimals = 2
})
ix.option.Add("fieldLightBloom", ix.type.number, .20, {
    category = "option.category.fieldVisuals", min = 0, max = 1, decimals = 2
})
ix.option.Add("fieldEdgeShading", ix.type.number, .35, {
    category = "option.category.fieldVisuals", min = 0, max = 1, decimals = 2
})
ix.util.Include("cl_visuals.lua")
if SERVER then AddCSLuaFile("cl_shader_payload.lua") end
ix.util.Include("cl_shaders.lua")
ix.option.Add("fieldSunGlare", ix.type.bool, true, {category = "option.category.fieldVisuals"})
ix.option.Add("fieldSunGlareStrength", ix.type.number, .65, {
    category = "option.category.fieldVisuals", min = 0, max = 1, decimals = 2
})
ix.util.Include("cl_sun.lua")

ix.lang.AddTable("ru", {["option.fieldLensDirt"] = "Блики на загрязнённом объективе", ["option.fieldLensDirtStrength"] = "Интенсивность бликов объектива"})
ix.lang.AddTable("en", {["option.fieldLensDirt"] = "Light-reactive lens dirt", ["option.fieldLensDirtStrength"] = "Lens dirt intensity"})
ix.option.Add("fieldLensDirt", ix.type.bool, true, {category = "option.category.fieldVisuals"})
ix.option.Add("fieldLensDirtStrength", ix.type.number, .6, {category = "option.category.fieldVisuals", min = 0, max = 1, decimals = 2})
ix.util.Include("cl_lightlens.lua")
