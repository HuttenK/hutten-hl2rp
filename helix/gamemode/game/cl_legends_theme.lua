-- Native VGUI art direction. No DHTML, remote assets or workshop UI fonts.
ix.Legends = ix.Legends or {}
local U = ix.Legends
U.Scale = ix.Civic.Scale
local S = U.Scale
U.ink = Color(246, 104, 113)
U.muted = Color(181, 151, 155)
U.accent = Color(255, 53, 76)
U.cyan = Color(255, 106, 120)
U.rose = Color(238, 85, 113)
U.line = Color(150, 43, 57, 150)
U.panel = Color(27, 12, 18, 240)
U.dark = Color(12, 8, 12)
-- Retire previous atmosphere hooks on Lua refresh as well as fresh joins.
hook.Remove("PreRender", "LegendsBackgroundFocus")
U.Atmosphere, U.LoadArtwork = nil, nil
if ix.option.stored then ix.option.stored.legendsAtmosphere = nil end
if ix.option.categories and ix.option.categories.appearance then
 ix.option.categories.appearance.legendsAtmosphere = nil
end
function U.T(en, ru) return ix.Locale.lang == "ru" and ru or en end
function U.Fonts()
	for name, size in pairs({Display = 58, Title = 28, Heading = 21, Body = 17, Small = 15, Mono = 13}) do
		surface.CreateFont("legends." .. name, {font = "Consolas",
			size = S(size), weight = (name == "Display" or name == "Heading") and 700 or 400,
			extended = true, antialias = true})
	end
end
U.Fonts()
hook.Add("OnScreenSizeChanged", "LegendsFonts", U.Fonts)
function U.Text(text, font, x, y, color, align)
	draw.SimpleText(tostring(text or ""), "legends." .. font, x, y, color or U.ink, align or TEXT_ALIGN_LEFT)
end
function U.Rect(x, y, w, h, color)
	surface.SetDrawColor(color); surface.DrawRect(x, y, w, h)
end
-- Rectilinear terminal frame: no clipped corners, bevels or moving hitboxes.
function U.Plate(x, y, w, h, color, accent)
 if w < 12 or h < 12 then return end
 local line = accent or U.line
 U.Rect(x, y, w, h, color)
 U.Rect(x, y+h-1, w, 1, Color(line.r,line.g,line.b,65))
 local length = math.min(S(12), w/4, h/3)
 for _, corner in ipairs({{x,y,1,1},{x+w-1,y,-1,1},{x,y+h-1,1,-1},{x+w-1,y+h-1,-1,-1}}) do
  local cx,cy,dx,dy=corner[1],corner[2],corner[3],corner[4]
  U.Rect(dx==1 and cx or cx-length+1,cy,length,1,line)
  U.Rect(cx,dy==1 and cy or cy-length+1,1,length,line)
 end
end
function U.ButtonFace(panel, w, h, primary, selected)
 local disabled = panel:GetDisabled()
 local active = not disabled and (panel:IsHovered() or panel:HasFocus() or selected)
 local pressed = not disabled and panel:IsDown()
 -- Terminal selection is immediate, with no lift, pulse or typing delay.
 local fill = disabled and Color(15,12,14,235) or
  (pressed and Color(105,15,32,255) or (active and Color(66,12,25,255) or Color(15,8,12,242)))
 local line = disabled and Color(66,40,47) or (active and U.accent or U.line)
 U.Plate(0,0,w,h,fill,line)
 local gutter = math.min(S(40), w*0.2)
 U.Rect(gutter, S(8), 1, math.max(1,h-S(16)), Color(line.r,line.g,line.b,95))
 if active or primary then
  -- A narrow illuminated rail replaces the old neon polygon silhouette.
  for i=0,3 do U.Rect(i,1,1,h-2,Color(line.r,line.g,line.b,180-i*42)) end
 end
 if primary then U.Rect(w-S(26),h-S(9),S(16),S(2),line) end
 return 0
end
function U.Label(parent, text, font, color)
	local p = parent:Add("DLabel")
	p:Dock(TOP); p:DockMargin(0, 0, 0, S(14))
	p:SetFont("legends." .. (font or "Body")); p:SetTextColor(color or U.ink)
	p:SetText(text); p:SetWrap(true); p:SetAutoStretchVertical(true)
	return p
end
function U.Button(parent, text, action, primary)
	local p = parent:Add("DButton")
	p:SetText(""); p:SetTall(S(52)); p:SetTooltip(text)
	p.OnCursorEntered = function(this)
		if not this:GetDisabled() then U.HoverSound() end
	end
	p.Paint = function(this, w, h)
		local down = U.ButtonFace(this, w, h, primary)
  U.Text(this:GetDisabled() and "--" or ">_", "Mono", S(10), h/2-S(7), this:GetDisabled() and U.muted or U.accent)
  U.Text(text, "Body", S(52), h/2-S(10)+down, this:GetDisabled() and U.muted or U.ink)
  if this:IsHovered() or this:HasFocus() then U.Rect(w-S(16),h/2-S(6),S(5),S(12),U.accent) end
	end
	p.DoClick = function(this)
		if this:GetDisabled() then return end
		surface.PlaySound("buttons/lightswitch2.wav"); action(this)
	end
	return p
end
function U.HoverSound()
	local now = RealTime()
	if now < (U.nextHoverSound or 0) then return end
	U.nextHoverSound = now + 0.065
	surface.PlaySound("garrysmod/ui_hover.wav")
end
function U.Scroll(parent)
	local p = parent:Add("DScrollPanel")
	p:GetVBar():SetWide(S(3)); p:GetVBar():SetHideButtons(true)
	p:GetVBar().Paint = function() end
	p:GetVBar().btnGrip.Paint = function(_, w, h) U.Rect(0, 0, w, h, U.accent) end
	return p
end
function U.Field(parent, title, value, callback, multiline)
	U.Label(parent, title, "Mono", U.muted)
	local p = parent:Add("DTextEntry")
	p:Dock(TOP); p:DockMargin(0, 0, S(8), S(20)); p:SetTall(S(multiline and 106 or 48))
	p:SetFont("legends.Body"); p:SetMultiline(multiline or false); p:SetUpdateOnType(true)
	p:SetText(value or "")
	p.Paint = function(this, w, h)
		U.Plate(0, 0, w, h, U.panel, this:HasFocus() and U.cyan or U.line)
		this:DrawTextEntryText(U.ink, U.accent, U.ink)
	end
	p.OnValueChange = function(_, text) callback(text) end
	return p
end
function U.Choice(parent, title, entries, selected, callback)
	U.Label(parent, title, "Mono", U.muted)
	local p = parent:Add("DComboBox")
	p:Dock(TOP); p:DockMargin(0, 0, S(8), S(18)); p:SetTall(S(44))
	p:SetFont("legends.Body"); p:SetTextColor(U.ink); p:SetSortItems(false)
	p.Paint = function(this, w, h) U.Plate(0, 0, w, h, U.panel, this:IsHovered() and U.cyan or U.line) end
	for _, entry in ipairs(entries) do p:AddChoice(entry.label, entry.value, entry.value == selected) end
	p.OnSelect = function(_, _, _, value) callback(value) end
	return p
end
-- Menu-local scheduling: no timers or hooks keep running after menus close.
local borderGlitch = {}
function U.BorderGlitch(w, h)
 if ix.option.Get("disableAnimations", false) then
  borderGlitch = {}
  return
 end
 local now = RealTime()
 if not borderGlitch.last or now-borderGlitch.last > 1 then
  borderGlitch.next = now + math.random(12, 25)
  borderGlitch.started = nil
 end
 borderGlitch.last = now
 if now >= borderGlitch.next then
  borderGlitch.started = now
  borderGlitch.next = now + math.random(16, 30)
  borderGlitch.side = math.random(0, 1)
  borderGlitch.position = math.random(20, 65)/100
 end
 local age = borderGlitch.started and now-borderGlitch.started
 if not age or age > 0.22 then return end
 local strength = math.sin(age/0.22*math.pi)
 local band = math.min(S(30), w*0.025)
 local phase = math.floor(age*24)
 -- Fragmented red signal tears remain outside all menu content margins.
 for i = 0, 5 do
  local length = band*(0.35+((i+phase)%4)*0.15)
  local x = borderGlitch.side == 0 and 0 or w-length
  local y = math.min(h-S(8), h*borderGlitch.position + S(i*19 + (phase%2)*3))
  U.Rect(x, y, length, S(2+i%3), Color(240, 38, 65, 110*strength))
  U.Rect(x, y+S(5), length*0.7, 1, Color(215, 159, 167, 65*strength))
 end
end

local terminalBackground = Material("legends/scp/terminal.jpg", "smooth")
function U.Backdrop(w, h)
 U.Rect(0, 0, w, h, Color(12, 10, 13))
 if not terminalBackground:IsError() then
  local ratio = terminalBackground:Width() / math.max(terminalBackground:Height(), 1)
  local view = w / math.max(h, 1)
  local u, v = math.min(1, view/ratio), math.min(1, ratio/view)
  surface.SetMaterial(terminalBackground); surface.SetDrawColor(220, 194, 201, 255)
  surface.DrawTexturedRectUV(0, 0, w, h, (1-u)/2, (1-v)/2, (1+u)/2, (1+v)/2)
 end
 U.Rect(0, 0, w, h, Color(15, 3, 9, 45))
 U.Rect(0, 0, w, S(88), Color(9, 5, 9, 205))
 U.Rect(0, h-S(98), w, S(98), Color(9, 5, 9, 205))
 -- Sparse scan texture; no flicker, camera shake or full-screen flashing.
 for y = S(90), h-S(100), math.max(12,S(16)) do
  U.Rect(0, y, w, 1, Color(230, 70, 90, 4))
 end
 if not ix.option.Get("disableAnimations", false) then
  local y = S(90) + (RealTime()*18 % math.max(1,h-S(190)))
  U.Rect(w*0.06, y, w*0.88, S(2), Color(255, 45, 70, 12))
 end
 U.Rect(w*0.045, S(85), w*0.91, 1, U.line)
 U.BorderGlitch(w, h)
end

local PANEL = {}
function PANEL:Init()
	self:SetFOV(32); self:SetMouseInputEnabled(true)
	self:SetAmbientLight(Color(65, 52, 59)); self:SetDirectionalLight(BOX_FRONT, Color(228, 212, 208))
	self:SetDirectionalLight(BOX_RIGHT, Color(230, 37, 62))
	self:SetDirectionalLight(BOX_LEFT, Color(191, 78, 104)); self.yaw = 12
end
function PANEL:Present(model, skin, groups)
	if not isstring(model) or model == "" then self:SetVisible(false) return end
	self:SetVisible(true); self:SetModel(model)
	local entity = self:GetEntity()
	if not IsValid(entity) then return end
	entity:SetSkin(skin or 0)
	for id, value in pairs(groups or {}) do entity:SetBodygroup(tonumber(id) or 0, tonumber(value) or 0) end
	local low, high = entity:GetRenderBounds()
	local height = math.max(high.z - low.z, 32)
	self.modelFloor, self.modelHeight = low.z, height
	self:SetPortraitFocus(self.faceFocus)
	local sequence = entity:SelectWeightedSequence(ACT_HL2MP_IDLE)
	if sequence < 0 then sequence = entity:SelectWeightedSequence(ACT_IDLE) end
	if sequence >= 0 then entity:ResetSequence(sequence) end
	entity:SetIK(false)
end
function PANEL:SetPortraitFocus(face)
	self.faceFocus = face
	local height, floor = self.modelHeight, self.modelFloor
	if not height then return end
	self:SetLookAt(Vector(0, 0, floor + height * (face and 0.88 or 0.5)))
	self:SetCamPos(Vector(height * (face and 0.55 or 1.85), height * 0.13, floor + height * (face and 0.89 or 0.57)))
end
function PANEL:LayoutEntity(entity)
	if self.dragX then self.yaw = self.startYaw + (gui.MouseX() - self.dragX) * 0.4 end
	entity:SetAngles(Angle(0, self.yaw, 0)); self:RunAnimation()
end
function PANEL:OnMousePressed(code)
	if code == MOUSE_LEFT then self.dragX = gui.MouseX(); self.startYaw = self.yaw; self:MouseCapture(true) end
end
function PANEL:OnMouseReleased()
	self.dragX = nil; self:MouseCapture(false)
end
vgui.Register("legends.portrait", PANEL, "DModelPanel")
