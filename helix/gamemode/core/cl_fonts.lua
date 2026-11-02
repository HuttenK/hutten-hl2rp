function GM:LoadFonts(font, genericFont)
	surface.CreateFont("ix3D2DFont", {
		font = font,
		size = 128,
		extended = true,
		weight = 100
	})

	surface.CreateFont("ix3D2DMediumFont", {
		font = font,
		size = 48,
		extended = true,
		weight = 100
	})

	surface.CreateFont("ix3D2DSmallFont", {
		font = font,
		size = 24,
		extended = true,
		weight = 400
	})

	surface.CreateFont("ixTitleFont", {
		font = font,
		size = ScreenScale(30),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixSubTitleFont", {
		font = font,
		size = ScreenScale(16),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixMenuMiniFont", {
		font = "Georgia",
		size = math.max(ScreenScale(4), 18),
		weight = 300,
	})

	surface.CreateFont("ixMenuButtonFont", {
		font = "Georgia",
		size = ix.UI.Scale(20),
		extended = true,
		weight = 500
	})

	surface.CreateFont("ixMenuButtonFontSmall", {
		font = "Georgia",
		size = ScreenScale(10),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixMenuButtonFontThick", {
		font = "Georgia",
		size = ScreenScale(14),
		extended = true,
		weight = 300
	})

	surface.CreateFont("ixMenuButtonLabelFont", {
		font = "Georgia",
		size = 28,
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixMenuButtonHugeFont", {
		font = "Georgia",
		size = ScreenScale(24),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixToolTipText", {
		font = font,
		size = 20,
		extended = true,
		weight = 500
	})

	surface.CreateFont("ixMonoSmallFont", {
		font = "Georgia",
		size = 12,
		extended = true,
		weight = 800
	})

	surface.CreateFont("ixMonoMediumFont", {
		font = "Georgia",
		size = 22,
		extended = true,
		weight = 800
	})

	-- The more readable font.
	font = genericFont

	surface.CreateFont("ixBigFont", {
		font = font,
		size = 36,
		extended = true,
		weight = 1000
	})

	surface.CreateFont("ixMediumFont", {
		font = font,
		size = 25,
		extended = true,
		weight = 1000
	})

	surface.CreateFont("ixNoticeFont", {
		font = font,
		size = math.max(ScreenScale(8), 18),
		weight = 100,
		extended = true,
		antialias = true
	})

	surface.CreateFont("ixMediumLightFont", {
		font = font,
		size = 25,
		extended = true,
		weight = 200
	})

	surface.CreateFont("ixMediumLightBlurFont", {
		font = font,
		size = 25,
		extended = true,
		weight = 200,
		blursize = 4
	})

	surface.CreateFont("ixGenericFont", {
		font = font,
		size = 20,
		extended = true,
		weight = 1000
	})

	surface.CreateFont("ixChatFont", {
		font = "Georgia",
		size = math.max(ScreenScale(7), 17) * ix.option.Get("chatFontScale", 1),
		extended = true,
		//weight = 600,
		antialias = true
	})

	surface.CreateFont("ixChatFontItalics", {
		font = "Georgia",
		size = math.max(ScreenScale(7), 17) * ix.option.Get("chatFontScale", 1),
		extended = true,
		//weight = 600,
		antialias = true,
		italic = true
	})

	surface.CreateFont("ixSmallTitleFont", {
		font = "Georgia",
		size = math.max(ScreenScale(12), 24),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixMinimalTitleFont", {
		font = "Georgia",
		size = math.max(ScreenScale(8), 22),
		extended = true,
		weight = 800
	})

	surface.CreateFont("ixSmallFont", {
		font = font,
		size = math.max(ScreenScale(6), 17),
		extended = true,
		weight = 500
	})

	surface.CreateFont("ixItemDescFont", {
		font = font,
		size = math.max(ScreenScale(6), 17),
		extended = true,
		shadow = true,
		weight = 500
	})

	surface.CreateFont("ixSmallBoldFont", {
		font = font,
		size = math.max(ScreenScale(8), 20),
		extended = true,
		weight = 800
	})

	surface.CreateFont("ixItemBoldFont", {
		font = font,
		shadow = true,
		size = math.max(ScreenScale(8), 20),
		extended = true,
		weight = 800
	})

	-- Introduction fancy font.
	font = "Georgia"

	surface.CreateFont("ixIntroTitleFont", {
		font = font,
		size = math.min(ScreenScale(128), 128),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixIntroTitleBlurFont", {
		font = font,
		size = math.min(ScreenScale(128), 128),
		extended = true,
		weight = 100,
		blursize = 4
	})

	surface.CreateFont("ixIntroSubtitleFont", {
		font = font,
		size = ScreenScale(24),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixIntroSmallFont", {
		font = font,
		size = ScreenScale(14),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixIconsSmall", {
		font = "fontello",
		size = 22,
		extended = true,
		weight = 500
	})

	surface.CreateFont("ixSmallTitleIcons", {
		font = "fontello",
		size = math.max(ScreenScale(11), 23),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixIconsMedium", {
		font = "fontello",
		extended = true,
		size = 28,
		weight = 500
	})

	surface.CreateFont("ixIconsMenuButton", {
		font = "fontello",
		size = ScreenScale(14),
		extended = true,
		weight = 100
	})

	surface.CreateFont("ixIconsBig", {
		font = "fontello",
		extended = true,
		size = 48,
		weight = 500
	})

	surface.CreateFont("autonomous.hud.lvl", {
		font = "Georgia",
		extended = true,
		size = ix.UI.Scale(28),
		weight = 500,
		blursize = 0,
		scanlines = 0,
		antialias = true,
	})

	surface.CreateFont("autonomous.hud.lvltext", {
		font = "Georgia",
		extended = true,
		size = ix.UI.Scale(12),
		weight = 500,
		blursize = 0,
		scanlines = 0,
		antialias = true,
	})

	surface.CreateFont("item.contraband", {
		font = "Georgia",
		size = math.max(ix.UI.Scale(15), 14),
		extended = true,
		weight = 500
	})

	surface.CreateFont("char.create.button", {
		font = "Georgia",
		extended = true,
		size = ix.UI.Scale(30),
		weight = 500,
		antialias = true,
	})
end