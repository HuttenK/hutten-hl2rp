local PLUGIN = PLUGIN

function PLUGIN:LoadFonts()
	surface.CreateFont("dlgTitle", {
		font = "Georgia",
		size = math.max(ScreenScale(11), 18),
		weight = 300,
		extended = true,
		antialias = true
	})

	surface.CreateFont("dlgText", {
		font = "Georgia",
		size = math.max(ScreenScale(8), 14),
		weight = 300,
		extended = true,
		antialias = true,
		italic = true
	})

	surface.CreateFont("dlgButton", {
		font = "Georgia",
		size = math.max(ScreenScale(8), 16),
		weight = 300,
		extended = true,
		antialias = true
	})
end