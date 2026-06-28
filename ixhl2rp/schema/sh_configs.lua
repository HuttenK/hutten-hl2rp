ix.config.language = "russian"

ix.config.SetDefault("scoreboardRecognition", true)
ix.config.SetDefault("music", "music/hl2_song19.mp3")
ix.config.SetDefault("maxAttributes", 60)

ix.config.Add("rationInterval", 300, "How long a person needs to wait in seconds to get their next ration", nil, {
	data = {min = 0, max = 86400},
	category = "economy"
})

-- ColorModify / ColorSaturation были удалены: их обработчик в
-- Schema:RenderScreenspaceEffects отключён (ранний return), поэтому опции в меню
-- настроек ничего не делали. Если захотите цветокоррекцию — снова добавьте опции
-- и уберите ранний return в cl_hooks.lua.
