-- Theme the actual Helix skin, including nested Derma confirmations and menus.
-- Actions, input handlers, ownership checks and network messages stay unchanged.
local U=ix.Legends
local skin=derma.SkinList.helix
local ink,muted,accent=U.ink,U.muted,U.accent
skin.Colours.Window.TitleActive=ink
skin.Colours.Window.TitleInactive=muted
skin.Colours.Label.Default=ink
skin.Colours.Button.Normal=ink
skin.Colours.Button.Hover=Color(246,232,197)
skin.Colours.Button.Down=accent
skin.Colours.Button.Disabled=Color(112,105,88)
skin.Colours.MenuLabel=ink
skin.Colours.Info=accent
skin.Colours.Success=Color(139,157,107)
skin.Colours.Error=U.rose
skin.Colours.Warning=Color(193,152,78)
skin.Colours.SegmentedProgress.Bar=accent
skin.Colours.SegmentedProgress.Text=ink
local function font(panel)
 if not panel.medievalFont and panel.SetFont then
  panel:SetFont("legends.Small"); panel.medievalFont=true
 end
end
function skin:PaintFrame(panel)
 local w,h=panel:GetSize()
 U.Plate(0,0,w,h,U.panel,accent)
 if IsValid(panel.lblTitle) then font(panel.lblTitle);panel.lblTitle:SetTextColor(ink) end
 U.Rect(8,27,w-16,1,U.line)
end
function skin:PaintBaseFrame(panel,w,h) U.Plate(0,0,w,h) end
function skin:PaintButton(panel)
 font(panel)
 if panel.m_bBackground then U.ButtonFace(panel,panel:GetWide(),panel:GetTall()) end
end
function skin:PaintWindowCloseButton(panel,w,h)
 U.Icon("close",w/2-7,h/2-7,14,panel:IsHovered() and ink or muted)
end
function skin:PaintMenu(panel,w,h) U.Plate(0,0,w,h) end
function skin:PaintMenuOption(panel,w,h)
 font(panel)
 if panel.Hovered or panel.Highlight then
  U.Rect(1,1,w-2,h-2,Color(66,54,31,210))
  U.Rect(1,h-1,w-2,1,accent)
 end
end
function skin:PaintMenuSpacer(panel,w,h) U.Rect(5,0,w-10,1,U.line) end
function skin:PaintMenuRightArrow(panel,w,h) U.Icon("next",w/2-6,h/2-6,12,accent) end
function skin:PaintComboBox(panel,w,h)
 font(panel);U.Plate(0,0,w,h,U.panel,panel:IsHovered() and accent or U.line)
end
function skin:PaintComboDownArrow(panel,w,h) U.Icon("down",w/2-6,h/2-6,12,accent) end
function skin:PaintTextEntry(panel,w,h)
 font(panel)
 if panel.m_bBackground then U.Plate(0,0,w,h,U.panel,panel:HasFocus() and accent or U.line) end
 local placeholder=panel.GetPlaceholderText and panel:GetPlaceholderText()
 if panel:GetText()=="" and placeholder and not panel:HasFocus() then
  draw.SimpleText(language.GetPhrase(placeholder),panel:GetFont(),4,h/2,muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  return
 end
 panel:DrawTextEntryText(ink,Color(99,79,43),ink)
end
function skin:PaintCheckBox(panel,w,h)
 U.Plate(0,0,w,h,U.dark,panel:GetDisabled() and U.line or accent)
 if panel:GetChecked() then U.Icon("check",1,1,math.min(w,h)-2,ink) end
end
function skin:PaintScrollBarGrip(panel,w,h) U.Plate(1,0,math.max(1,w-2),h,Color(78,65,42),accent) end
function skin:PaintVScrollBar(panel,w,h) U.Rect(w/2,0,1,h,U.line) end
function skin:PaintButtonUp(panel,w,h)
 surface.SetDrawColor(accent); surface.DrawLine(w*.3,h*.6,w*.5,h*.4);surface.DrawLine(w*.5,h*.4,w*.7,h*.6)
end
function skin:PaintButtonDown(panel,w,h) U.Icon("down",w/2-5,h/2-5,10,accent) end
function skin:PaintHelixSlider(panel,w,h)
 U.Rect(0,0,w,h,U.dark);U.Rect(0,0,panel:GetVisualFraction()*w,h,accent)
end
function skin:PaintTooltip(panel,w,h) U.Plate(0,0,w,h,U.panel,accent) end
function skin:PaintTooltipBackground(panel,w,h) U.Plate(0,0,w,h,U.panel,accent) end
function skin:PaintSliderKnob(panel,w,h)
 U.Plate(2,2,w-4,h-4,panel:IsHovered() and Color(107,88,52) or Color(66,55,36),accent)
end
function skin:PaintNumSlider(panel,w,h)
 U.Rect(8,h/2,w-16,1,U.line)
end
function skin:PaintListView(panel,w,h) U.Plate(0,0,w,h) end
function skin:PaintListViewLine(panel,w,h)
 if panel:IsSelected() then U.Rect(0,0,w,h,Color(74,61,36,230))
 elseif panel.Hovered then U.Rect(0,0,w,h,Color(50,43,29,210)) end
 U.Rect(0,h-1,w,1,U.line)
end
skin.PaintNumberUp=skin.PaintButtonUp
skin.PaintNumberDown=skin.PaintButtonDown
skin.PaintRadioButton=skin.PaintCheckBox
derma.RefreshSkins()
