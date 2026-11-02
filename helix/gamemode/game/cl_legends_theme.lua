-- Native Derma presentation. Optional artwork is loaded once; missing content
-- falls back to solid surfaces instead of drawing an error material.
ix.Legends = ix.Legends or {}
local U = ix.Legends
U.Scale = ix.Civic.Scale
local S = U.Scale
U.ink = Color(230, 222, 202)
U.muted = Color(161, 151, 128)
U.accent = Color(182, 151, 91)
U.cyan = Color(213, 187, 130) -- compatibility name used by existing controls
U.rose = Color(156, 69, 54)
U.line = Color(103, 88, 57, 180)
U.panel = Color(18, 18, 16, 244)
U.dark = Color(9, 10, 9)
U.Boot, U.Atmosphere, U.LoadArtwork, U.BorderGlitch = nil, nil, nil, nil
hook.Remove("PreRender", "LegendsBackgroundFocus")
function U.T(en, ru) return ix.Locale.lang == "ru" and ru or en end
local nextSound = 0
function U.PlayUISound(name)
 if name ~= "click" or RealTime() < nextSound then return end
 nextSound = RealTime() + .09
 surface.PlaySound("buttons/lightswitch2.wav")
end
function U.HoverSound() end
function U.Fonts()
 for _, prefix in ipairs({"legends.", "facility."}) do
  for name, size in pairs({Display=62, Title=32, Heading=22, Body=18, Small=15, Mono=14}) do
   surface.CreateFont(prefix..name, {font="Georgia", size=S(size), weight=400, extended=true, antialias=true})
  end
 end
end
U.Fonts()
hook.Add("OnScreenSizeChanged", "LegendsFonts", U.Fonts)
function U.Text(text, font, x, y, color, align)
 draw.SimpleText(tostring(text or ""), "legends."..(font or "Body"), x, y, color or U.ink, align or TEXT_ALIGN_LEFT)
end
function U.Fit(text, font, width)
 text=tostring(text or "")
 surface.SetFont("legends."..(font or "Body"))
 if surface.GetTextSize(text)<=width then return text end
 local count=text:utf8len()
 while count>0 do
  local value=text:utf8sub(1,count).."…"
  if surface.GetTextSize(value)<=width then return value end
  count=count-1
 end
 return ""
end
function U.Rect(x,y,w,h,color)
 surface.SetDrawColor(color); surface.DrawRect(x,y,w,h)
end
-- Original generated artwork stays in the content addon. Only the rails stretch;
-- engraved corners retain their proportions on every screen size.
U.Art = {
 panel={path="panel_v2",u=.08,v=.08},
 button={path="button_v2",u=.05,v=.15},
 slot={path="slot_v2",u=.13,v=.13},
 selected={path="slot_selected_v2",u=.13,v=.13}
}
-- Material paths are relative to garrysmod/materials, with no UI subfolder.
for _,art in pairs(U.Art) do art.material=Material(art.path..".png","smooth") end
local background = Material("hall_v3.png", "smooth noclamp")
local divider = Material("divider_v2.png", "smooth")
local shade = Material("vgui/gradient-l", "smooth")
local function Patch(x,y,w,h,u0,v0,u1,v1)
 if w>0 and h>0 then surface.DrawTexturedRectUV(x,y,w,h,u0,v0,u1,v1) end
end
function U.NineSlice(name,x,y,w,h,corner,color,frameOnly)
 local art=U.Art[name]
 if w<=0 or h<=0 or not art or art.material:IsError() then return false end
 local c=math.max(0,math.min(corner,w/2,h/2))
 local u,v=art.u,art.v
 surface.SetMaterial(art.material);surface.SetDrawColor(color or color_white)
 Patch(x,y,c,c,0,0,u,v)
 Patch(x+c,y,w-c*2,c,u,0,1-u,v)
 Patch(x+w-c,y,c,c,1-u,0,1,v)
 Patch(x,y+c,c,h-c*2,0,v,u,1-v)
 if not frameOnly then Patch(x+c,y+c,w-c*2,h-c*2,u,v,1-u,1-v) end
 Patch(x+w-c,y+c,c,h-c*2,1-u,v,1,1-v)
 Patch(x,y+h-c,c,c,0,1-v,u,1)
 Patch(x+c,y+h-c,w-c*2,c,u,1-v,1-u,1)
 Patch(x+w-c,y+h-c,c,c,1-u,1-v,1,1)
 return true
end
function U.SlotFace(x,y,w,h,selected,frameOnly)
 local name=selected and "selected" or "slot"
 local art=U.Art[name]
 if not frameOnly and not art.material:IsError() then
  surface.SetMaterial(art.material);surface.SetDrawColor(255,255,255)
  surface.DrawTexturedRect(x,y,w,h)
 elseif not U.NineSlice(name,x,y,w,h,math.min(w,h)*.13,nil,frameOnly) and not frameOnly then
  U.Rect(x,y,w,h,U.panel)
 end
end
-- One continuous illustration. Only its quiet left wall expands on ultrawide;
-- the niche retains its aspect ratio and shares its coordinates with the model.
function U.BackdropGeometry(w,h)
 local imageWidth=h*(1672/941)
 local rightWidth=math.min(w*.48,imageWidth*.4)
 return w-rightWidth,rightWidth/.4
end
function U.PortraitBounds(w,h)
 local _,imageWidth=U.BackdropGeometry(w,h)
 return w-imageWidth*.324,h*.15,imageWidth*.274,h*.65
end
function U.Backdrop(w,h)
 U.Rect(0,0,w,h,U.dark)
 if not background:IsError() then
  local seam=U.BackdropGeometry(w,h)
  surface.SetMaterial(background);surface.SetDrawColor(255,255,255)
  Patch(0,0,seam,h,0,0,.6,1)
  Patch(seam,0,w-seam,h,.6,0,1,1)
 end
 surface.SetMaterial(shade);surface.SetDrawColor(3,4,3,38);surface.DrawTexturedRect(0,0,w*.62,h)
end
function U.Plate(x,y,w,h,color,accent)
 if w<=0 or h<=0 then return end
 local tint=Color(255,255,255,color and color.a or 255)
 if not U.NineSlice("panel",x,y,w,h,S(26),tint) then
  U.Rect(x,y,w,h,color or U.panel)
  surface.SetDrawColor(accent or U.line);surface.DrawOutlinedRect(x,y,w,h)
 elseif accent then
  U.NineSlice("panel",x,y,w,h,S(26),accent,true)
 end
end
function U.Rule(x,y,w)
 if divider:IsError() then U.Rect(x,y,w,1,U.line) return end
 -- The transparent source has generous vertical padding around the metalwork.
 surface.SetMaterial(divider);surface.SetDrawColor(255,255,255)
 surface.DrawTexturedRectUV(x,y-S(7),w,S(14),0,.43,1,.56)
end
function U.ButtonFace(p,w,h,primary,selected)
 local active=not p:GetDisabled() and (p:IsHovered() or p:HasFocus() or selected)
 local tint=p:GetDisabled() and Color(130,130,125) or color_white
 if not U.NineSlice("button",0,0,w,h,S(16),tint) then U.Plate(0,0,w,h) end
 if active or primary then
  U.NineSlice("selected",0,0,w,h,S(16),Color(255,240,204,active and 105 or 35))
 end
 return p:IsDown() and 1 or 0
end
function U.Button(parent,text,action,primary)
 local p=parent:Add("DButton");p:SetText("");p:SetTall(S(46));p:SetTooltip(text)
 p.Paint=function(this,w,h)
  local offset=U.ButtonFace(this,w,h,primary)
  local inset=S(18)
  if U.Icon and w>=S(210) then
   U.Icon(U.IconName(text),S(14),h/2-S(13),S(26),this:GetDisabled() and Color(255,255,255,90) or U.ink)
   inset=S(49)
  end
  draw.SimpleText(U.Fit(text,"Body",w-inset-S(18)),"legends.Body",inset,h/2+offset,
   this:GetDisabled() and U.muted or U.ink,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 p.DoClick=function(this) if this:GetDisabled() then return end U.PlayUISound("click");action(this) end
 return p
end
function U.Label(parent,text,font,color)
 local p=parent:Add("DLabel");p:Dock(TOP);p:DockMargin(0,0,0,S(12))
 p:SetFont("legends."..(font or "Body"));p:SetTextColor(color or U.ink)
 p:SetText(text);p:SetWrap(true);p:SetAutoStretchVertical(true)
 return p
end
function U.Scroll(parent)
 local p=parent:Add("DScrollPanel")
 p:GetVBar():SetWide(S(4));p:GetVBar():SetHideButtons(true)
 p:GetVBar().Paint=function() end
 p:GetVBar().btnGrip.Paint=function(_,w,h) U.Rect(0,0,w,h,U.accent) end
 return p
end
function U.Field(parent,title,value,callback,multiline)
 U.Label(parent,title,"Small",U.muted)
 local p=parent:Add("DTextEntry")
 p:Dock(TOP);p:DockMargin(0,0,S(8),S(18));p:SetTall(S(multiline and 106 or 44))
 p:SetFont("legends.Body");p:SetMultiline(multiline or false);p:SetUpdateOnType(true);p:SetText(value or "")
 p.Paint=function(this,w,h)
  U.Plate(0,0,w,h,U.panel,this:HasFocus() and U.cyan or U.line)
  this:DrawTextEntryText(U.ink,U.accent,U.ink)
 end
 p.OnValueChange=function(_,text) callback(text) end
 return p
end
function U.Choice(parent,title,entries,selected,callback)
 U.Label(parent,title,"Small",U.muted)
 local p=parent:Add("DComboBox")
 p:Dock(TOP);p:DockMargin(0,0,S(8),S(18));p:SetTall(S(44))
 p:SetFont("legends.Body");p:SetTextColor(U.ink);p:SetSortItems(false)
 p.Paint=function(this,w,h) U.Plate(0,0,w,h,U.panel,this:IsHovered() and U.cyan or U.line) end
 for _,entry in ipairs(entries) do p:AddChoice(entry.label,entry.value,entry.value==selected) end
 p.OnSelect=function(_,_,_,value) callback(value) end
 return p
end
-- Active characters use the replicated player appearance, not the logout cache.
function U.ApplyCharacterAppearance(entity,character)
 if ix.SDHair then ix.SDHair.Apply(entity, ix.SDHair.Saved(character)) end
 local player=LocalPlayer()
 if IsValid(player) and player:GetCharacter()==character and player:GetModel()==entity:GetModel() then
  entity:SetSkin(player:GetSkin())
  for id=0,entity:GetNumBodyGroups()-1 do entity:SetBodygroup(id,player:GetBodygroup(id)) end
  return
 end
 entity:SetSkin(character:GetData("skin",0))
 for id=0,entity:GetNumBodyGroups()-1 do entity:SetBodygroup(id,0) end
 local groups=character:GetData("bgcache",character:GetData("groups",{}))
 if istable(groups) then
  for key,value in pairs(groups) do
   local id=tonumber(key) or entity:FindBodygroupByName(key)
   if id and id>=0 and id<entity:GetNumBodyGroups() then entity:SetBodygroup(id,tonumber(value) or 0) end
  end
 end
 hook.Run("ApplyCharacterModelIdentity", entity, character)
end

local PANEL = {}
function PANEL:Init()
	self:SetFOV(32); self:SetMouseInputEnabled(true)
	self:SetAmbientLight(Color(65, 61, 55)); self:SetDirectionalLight(BOX_FRONT, Color(185, 174, 151))
	self:SetDirectionalLight(BOX_TOP, Color(105, 95, 77))
	self:SetDirectionalLight(BOX_RIGHT, Color(72, 65, 55))
	self:SetDirectionalLight(BOX_LEFT, Color(150, 135, 110)); self.yaw = 8
end
function PANEL:Present(model, skin, groups)
 self.character=nil
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
function PANEL:PresentCharacter(character)
 self:Present(character:GetModel(),character:GetData("skin",0),{})
 self.character=character
 if IsValid(self:GetEntity()) then U.ApplyCharacterAppearance(self:GetEntity(),character) end
end
function PANEL:SetPortraitFocus(face)
	self.faceFocus = face
	local height, floor = self.modelHeight, self.modelFloor
	if not height then return end
 -- Orthographic portrait: the feet stay at 98% of this transparent viewport,
 -- on the painted pedestal, independent of window aspect or camera distance.
 self.portraitSpan=height/(face and 2.5 or .88)
 local center=floor+(face and height*.87 or self.portraitSpan*.48)
 self:SetLookAt(Vector(0,0,center))
 self:SetCamPos(Vector(height*3,0,center))
end
function PANEL:Paint(w,h)
 if not IsValid(self.Entity) or w<=0 or h<=0 then return end
 self:LayoutEntity(self.Entity)
 if not IsValid(self.Entity) or not self.portraitSpan then return end
 local x,y=self:LocalToScreen(0,0)
 local half=self.portraitSpan*.5
 cam.Start({type="3D",origin=self.vCamPos,angles=Angle(0,180,0),
  x=x,y=y,w=w,h=h,znear=1,zfar=4096,
  ortho={left=-half*w/h,right=half*w/h,top=-half,bottom=half}})
 render.SuppressEngineLighting(true)
 render.SetLightingOrigin(self.Entity:GetPos())
 local light=self.colAmbientLight
 render.ResetModelLighting(light.r/255,light.g/255,light.b/255)
 render.SetColorModulation(self.colColor.r/255,self.colColor.g/255,self.colColor.b/255)
 render.SetBlend((self:GetAlpha()/255)*(self.colColor.a/255))
 for i=0,5 do
  local color=self.DirectionalLight[i]
  if color then render.SetModelLighting(i,color.r/255,color.g/255,color.b/255) end
 end
 -- Retain DModelPanel's clipping and Pre/PostDrawModel extension hooks.
 self:DrawModel()
 render.SetBlend(1);render.SetColorModulation(1,1,1)
 render.SuppressEngineLighting(false);cam.End3D()
 self.LastPaint=RealTime()
end
function PANEL:LayoutEntity(entity)
 if self.character then
  local player=LocalPlayer()
  local model=self.character:GetModel()
  if IsValid(player) and player:GetCharacter()==self.character then model=player:GetModel() end
  if entity:GetModel()~=model then
   local character=self.character
   self:Present(model,0,{})
   self.character=character
   entity=self:GetEntity()
   if not IsValid(entity) then return end
  end
  U.ApplyCharacterAppearance(entity,self.character)
 end
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
