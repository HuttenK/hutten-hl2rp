local PLUGIN = PLUGIN

-- Two Source units are approximately five centimetres. Applied once, on creation.
PLUGIN.areaMargin = 2

ix.lang.AddTable("ru", {
    blackout = "Зона электроснабжения",
    blackoutMargin = "Запас границ (ед.; 2 ≈ 5 см)",
    blackoutStartOff = "Обесточить при создании",
    blackoutDarkness = "Затемнение (0–100%%)",
    blackoutSoftness = "Плавная граница (0–128 ед.)"
})
ix.lang.AddTable("en", {
    blackout = "Power zone",
    blackoutMargin = "Boundary margin (units; 2 ≈ 5 cm)",
    blackoutStartOff = "Start with power off",
    blackoutDarkness = "Darkness (0–100%%)",
    blackoutSoftness = "Edge fade (0–128 units)"
})

function PLUGIN:SetupAreaProperties()
    if not ix.area or not ix.area.AddType then return end
    ix.area.AddType("blackout", "blackout", {
        nonLocation = true,
        allowedProperties = {color = true, blackoutMargin = true, blackoutStartOff = true, blackoutDarkness = true, blackoutSoftness = true}
    })
    ix.area.AddProperty("blackoutMargin", ix.type.number, self.areaMargin, {areaType = "blackout"})
    ix.area.AddProperty("blackoutDarkness", ix.type.number, 86, {areaType = "blackout"})
    ix.area.AddProperty("blackoutSoftness", ix.type.number, 24, {areaType = "blackout"})
    ix.area.AddProperty("blackoutStartOff", ix.type.bool, false, {areaType = "blackout"})
end

PLUGIN:SetupAreaProperties()
