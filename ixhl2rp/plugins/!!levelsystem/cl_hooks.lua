local PLUGIN = PLUGIN

local function levelTooltip(tooltip)
	local character = LocalPlayer():GetCharacter()

	if character then
		local tooltip = tooltip:AddRow("description")
		tooltip:SetText(L("tooltip.levelXP", math.Round(character:GetLevelXP()), math.Round(PLUGIN:GetRequiredLevelXP(character:GetLevel()))))
		tooltip:SizeToContents()
	end
end

function PLUGIN:CreateCharacterInfo(panel)
	if IsValid(panel) then
		panel.level = panel:Add("ixListRow")
		panel.level:SetList(panel.list)
		panel.level:Dock(TOP)
		panel.level:SizeToContents()

		panel.level.text:SetHelixTooltip(levelTooltip)
		panel.level.label:SetHelixTooltip(levelTooltip)
	end
end

function PLUGIN:UpdateCharacterInfo(panel, character)
	if panel and panel.level then
		panel.level:SetLabelText(L("tooltip.level"))
		panel.level:SetText(character:GetLevel())
		panel.level:SizeToContents()
	end
end

local yel = Color(255, 210, 0)
local lvl_colors = {
	[1] = color_white,
	[2] = color_white,
	[3] = yel,
	[4] = yel,
	[5] = yel,
	[6] = Color(255, 92, 80),
	[7] = Color(255, 92, 80),
	[8] = Color(255, 92, 80),
	[9] = Color(42, 237, 255),
	[10] = Color(42, 237, 255),
}

local function DrawLevelXP(x, y, w, h, delta, clr)
	surface.SetDrawColor(ColorAlpha(clr, 200))
	surface.DrawRect(x + 2, y + 2, (w - 4) * delta, h - 4)

	surface.SetDrawColor(ColorAlpha(clr, 128))
	surface.DrawOutlinedRect(x, y, w, h)

	local offset = 2
	surface.SetDrawColor(ColorAlpha(clr, 48))
	surface.DrawOutlinedRect(x + offset, y + offset, w - offset * 2, h - offset * 2)
end

function PLUGIN:HUDPaint()
	local client = LocalPlayer()
	local character = client:GetCharacter()

	if not character then return end
	if not client:Alive() then return end
	if IsValid(ix.gui.characterMenu) and not ix.gui.characterMenu:IsClosing() then return end
	if IsValid(ix.gui.menu) then return end

	local Scale = ix.UI and ix.UI.Scale or function(val) return val * (ScrW() / 1920) end

	local level = character:GetLevel()
	local xp = character:GetLevelXP()
	local xp_max = self:GetRequiredLevelXP(level)
	local xp_delta = xp_max > 0 and math.Clamp(xp / xp_max, 0, 1) or 1
	
	local level_padding, level_bar_h, level_bar_w = Scale(32), math.max(8, Scale(14)), Scale(300)
	local x, y = level_padding, level_padding

	surface.SetFont("ui.tabmenu.level")
	local level_w, level_h = surface.GetTextSize(tostring(level))
	local level_clr = lvl_colors[level] or lvl_colors[1]

	draw.SimpleText(L("tab_level"), "ui.tabmenu.leveltext", x + level_w + 8, y, level_clr, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText(tostring(level), "ui.tabmenu.level", x, y, level_clr, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	local barX = x + level_w + 8
	local barY = y + (level_h * 0.5) - (level_bar_h * 0.5) + 1

	DrawLevelXP(barX, barY, level_bar_w, level_bar_h, xp_delta, level_clr)

	barY = barY + level_bar_h

	DisableClipping(true)
		local xp_remaining = xp_max > 0 and math.Round(xp_max - xp) or 0
		draw.SimpleText(L("tab_xp_until", xp_remaining), "ui.tabmenu.levelmini", barX + level_bar_w, barY, level_clr, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
	DisableClipping(false)
end