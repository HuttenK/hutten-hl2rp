local thermalMat = Material("pp/texturize/plain.png")

-- also:
-- NoFade
-- EquipSound
-- UnequipSound
-- EquipDelay
-- UnequipDelay
ArcticNVGs = {
    {
        ShortName = "nvg_gpnvg",
        VManipIn = "nvg_gpnvg_in",
        VManipOut = "nvg_gpnvg_out",
        Model = "models/arctic_nvgs/nvg_gpnvg.mdl",
        FullColor = false,
        EquipDelay = 1.325,
        ColorCorrectSettings = {
            ["$pp_colour_addr"] = -1,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = -1,
            ["$pp_colour_brightness"] = 0.01,
            ["$pp_colour_contrast"] = 4.5,
            ["$pp_colour_colour"] = 1,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        },
        EquipSound = "arctic_nvgs/nvg_on_1.wav",
        UnequipSound = "arctic_nvgs/nvg_off_1.wav",
        BloomSettings = {
            darken = 0,
            multiply = 1,
            sizex = 4,
            sizey = 4,
            passes = 1,
            colormultiply = 1,
            red = 1,
            green = 1,
            blue = 1,
        },
        ActiveLight = false,
        EffectFunction = nil,
        Overlay = Material("arctic_nvg/faint.png", "mips"),
        -- ScaleToSquare = false,
        Entity = "arctic_nvg_gpnvg",
        Offset = Vector(0, 0, 0),
        OffsetAngle = Angle(0, 0, 0)
    },
    {
        ShortName = "nvg_pnv10t",
        VManipIn = "nvg_pnv_in",
        VManipOut = "nvg_pnv_out",
        EquipDelay = 1.325,
        Model = "models/arctic_nvgs/nvg_pnv.mdl",
        FullColor = false,
        ColorCorrectSettings = {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = -1,
            ["$pp_colour_addb"] = -1,
            ["$pp_colour_brightness"] = 0.01,
            ["$pp_colour_contrast"] = 4,
            ["$pp_colour_colour"] = 1,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        },
        EquipSound = "arctic_nvgs/nvg_on_2.wav",
        UnequipSound = "arctic_nvgs/nvg_off_2.wav",
        BloomSettings = {
            darken = 0,
            multiply = 1.5,
            sizex = 32,
            sizey = 4,
            passes = 1,
            colormultiply = 1,
            red = 1,
            green = 1,
            blue = 1,
        },
        ActiveLight = false,
        EffectFunction = nil,
        Overlay = Material("arctic_nvg/binocular.png", "mips"),
        ScaleToSquare = false,
        Entity = "arctic_nvg_pnv10",
        Offset = Vector(0, 0, 0),
        OffsetAngle = Angle(0, 0, 0)
    },
    {
        ShortName = "nvg_n15",
        VManipIn = "nvg_n15_in",
        VManipOut = "nvg_n15_out",
        EquipDelay = 1.325,
        Model = "models/arctic_nvgs/nvg_n15.mdl",
        FullColor = false,
        ColorCorrectSettings = {
            ["$pp_colour_addr"] = -1,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.01,
            ["$pp_colour_contrast"] = 4,
            ["$pp_colour_colour"] = 1,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        },
        EquipSound = "arctic_nvgs/nvg_on_1.wav",
        UnequipSound = "arctic_nvgs/nvg_off_1.wav",
        BloomSettings = {
            darken = 0,
            multiply = 1.25,
            sizex = 4,
            sizey = 2,
            passes = 1,
            colormultiply = 1,
            red = 1,
            green = 1,
            blue = 1,
        },
        EffectFunction = nil,
        Overlay = Material("arctic_nvg/binocular.png", "mips"),
        ScaleToSquare = false,
        Entity = "arctic_nvg_n15",
        Offset = Vector(0, 0, 0),
        OffsetAngle = Angle(0, 0, 0)
    },
    {
        ShortName = "nvg_pvs14",
        VManipIn = "nvg_pvs14_in",
        VManipOut = "nvg_pvs14_out",
        EquipDelay = 1.325,
        Model = "models/arctic_nvgs/nvg_pvs14.mdl",
        FullColor = true,
        ColorCorrectSettings = {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.01,
            ["$pp_colour_contrast"] = 4,
            ["$pp_colour_colour"] = 0.75,
            ["$pp_colour_mulr"] = 50,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        },
        EquipSound = "arctic_nvgs/nvg_on_2.wav",
        UnequipSound = "arctic_nvgs/nvg_off_2.wav",
        BloomSettings = {
            darken = 0,
            multiply = 2,
            sizex = 2,
            sizey = 2,
            passes = 1,
            colormultiply = 1,
            red = 1,
            green = 1,
            blue = 1,
        },
        ActiveLight = false,
        EffectFunction = nil,
        Overlay = Material("arctic_nvg/narrow.png", "mips"),
        ScaleToSquare = true,
        Entity = "arctic_nvg_pvs14",
        Offset = Vector(0, 0, 0),
        OffsetAngle = Angle(0, 0, 0)
    },
    {
        ShortName = "nvg_t7",
        VManipIn = "nvg_t7_in",
        VManipOut = "nvg_t7_out",
        EquipDelay = 1.325,
        Model = "models/arctic_nvgs/nvg_t7.mdl",
        FullColor = true,
        ColorCorrectSettings = {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.05,
            ["$pp_colour_contrast"] = 0.5,
            ["$pp_colour_colour"] = 0,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        },
        EquipSound = "arctic_nvgs/nvg_on_1.wav",
        UnequipSound = "arctic_nvgs/nvg_off_1.wav",
        BloomSettings = {
            darken = 0,
            multiply = 1,
            sizex = 4,
            sizey = 4,
            passes = 1,
            colormultiply = 1,
            red = 1,
            green = 1,
            blue = 1,
        },
        ThermalVision = true,
        ThermalHighlight = Color(255, 0, 0),
        ActiveLight = false,
        EffectFunction = function()
            DrawTexturize(1, thermalMat)
        end,
        Overlay = Material("arctic_nvg/binocular.png", "mips"),
        ScaleToSquare = false,
        Entity = "arctic_nvg_t7",
        Offset = Vector(0, 0, 0),
        OffsetAngle = Angle(0, 0, 0)
    },
    {
        ShortName = "shades",
        VManipIn = "nvg_aviators_in",
        VManipOut = "nvg_aviators_out",
        EquipDelay = 1.41,
        UnequipDelay = 0.25,
        NoBrightenWorld = true,
        Model = "models/arctic_nvgs/aviators.mdl",
        FullColor = true,
        NoFade = true,
        ColorCorrectSettings = {
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -0.05,
            ["$pp_colour_contrast"] = 1,
            ["$pp_colour_colour"] = 1,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0,
        },
        EquipSound = "",
        UnequipSound = "",
        Overlay = Material("arctic_nvg/shades.png"),
        ScaleToSquare = false,
        Entity = "arctic_nvg_shades",
        Offset = Vector(-0.5, 0, 0),
        OffsetAngle = Angle(0, 0, 0)
    },
}

ArcticNVGs_ShortNameToID = {}

for i, k in pairs(ArcticNVGs) do
    ArcticNVGs_ShortNameToID[k.ShortName or ""] = i
end

CreateConVar("sh_arctic_nvg_losegoggles", "1", FCVAR_REPLICATED + FCVAR_ARCHIVE, "")

function ArcticNVGs_GetPlayerGoggles(ply)
    local goggles = ply:GetNWInt("nvg", 0)
    if goggles == 0 then return end

    return ArcticNVGs[goggles]
end