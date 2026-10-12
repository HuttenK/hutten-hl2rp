local plateColors={cloth=Color(48,52,40),seam=Color(105,111,86),paper=Color(222,215,185),ink=Color(37,42,30),muted=Color(184,184,157),steel=Color(77,88,82),dark=Color(24,30,26),ready=Color(186,202,131),bad=Color(225,148,110)}
surface.CreateFont("PlateTitle",{font="Tahoma",size=24,weight=700,extended=true})
surface.CreateFont("PlateText",{font="Tahoma",size=18,weight=500,extended=true})
surface.CreateFont("PlateSmall",{font="Tahoma",size=15,weight=500,extended=true})
local function plateText(text,font,x,y,color,width)
 surface.SetFont(font)
 if width and surface.GetTextSize(text)>width then
  local n=utf8.len(text) or #text
  repeat n=n-1;text=string.utf8sub(text,1,n) until n<=1 or surface.GetTextSize(text.."…")<=width
  text=text.."…"
 end
 draw.SimpleText(text,font,x,y,color)
end
local function plateShape(x,y,w,h,color)
 draw.NoTexture();surface.SetDrawColor(color)
 surface.DrawPoly({{x=x+w*.22,y=y},{x=x+w*.78,y=y},{x=x+w,y=y+h*.2},{x=x+w,y=y+h*.84},{x=x+w*.83,y=y+h},{x=x+w*.17,y=y+h},{x=x,y=y+h*.84},{x=x,y=y+h*.2}})
end
function ix.field.PaintPlate(row,w,h,index,health)
 local C=plateColors;local good=health>0
 surface.SetDrawColor(C.dark);surface.DrawRect(0,0,w,h)
 surface.SetDrawColor(C.seam);surface.DrawOutlinedRect(0,0,w,h)
 -- An insert silhouette in a stitched carrier pocket, not another app card.
 for x=6,w-6,12 do surface.DrawLine(x,h-5,math.min(x+5,w-6),h-5) end
 plateShape(16,12,62,h-26,health==0 and C.cloth or C.steel)
 if health<0 then
  surface.SetDrawColor(C.bad);surface.DrawLine(45,15,32,45);surface.DrawLine(32,45,57,56);surface.DrawLine(57,56,40,h-17)
 else
  draw.SimpleText(string.format("%02d",index),"PlateTitle",47,h/2,C.paper,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 local available=w-118
 plateText("КАРМАН "..index,"PlateSmall",96,11,C.muted,available)
 plateText(health<0 and "РАЗРУШЕНА" or health==0 and "ПУСТО" or "ПЛАСТИНА УСТАНОВЛЕНА","PlateText",96,33,good and C.ready or health<0 and C.bad or C.paper,available)
 local track=math.max(10,w-(w<500 and 118 or 310))
 surface.SetDrawColor(C.seam);surface.DrawRect(96,67,track,8)
 surface.SetDrawColor(good and C.ready or C.bad);surface.DrawRect(96,67,track*math.Clamp(health,0,1),8)
 plateText(good and (math.ceil(health*100).."% · целостность") or "Требуется пластина","PlateSmall",96,85,C.muted,available)
end
net.Receive("ixPlateInspect",function()
 local id=net.ReadUInt(32); local cap=net.ReadUInt(2); local hp={}
 for i=1,cap do hp[i]=net.ReadFloat() end
 local previous=ix.gui.plateInspect
 local previousX,previousY
 if IsValid(previous) then
  if previous.plateItemID==id then previousX,previousY=previous:GetPos() end
  previous:Remove()
 end
 local C=plateColors
 local frame=vgui.Create("DFrame"); ix.gui.plateInspect=frame
 frame:SetSize(math.min(650,ScrW()-30),math.min(188+cap*125,ScrH()-30))
 frame:Center(); frame:MakePopup(); frame:SetTitle(""); frame:ShowCloseButton(false)
 frame.plateItemID=id
 frame:SetDraggable(true); frame:SetScreenLock(true)
 frame:DockPadding(18,93,18,18)
 if previousX then
  frame:SetPos(math.Clamp(previousX,0,ScrW()-frame:GetWide()),math.Clamp(previousY,0,ScrH()-frame:GetTall()))
 end
 -- Use the full custom header; DFrame's default drag area is only 24 pixels tall.
 frame.OnMousePressed=function(self,button)
  local x,y=self:CursorPos()
  if button==MOUSE_LEFT and y>=0 and y<78 then
   self.Dragging={x,y}
   self:MouseCapture(true)
  end
 end
 local frameThink=frame.Think
 frame.Think=function(self)
  frameThink(self)
  local _,y=self:CursorPos()
  if self.Dragging or (self:IsHovered() and y>=0 and y<78) then self:SetCursor("sizeall") end
 end
 frame.OnKeyCodePressed=function(s,key) if key==KEY_ESCAPE then s:Close() end end
 frame.Paint=function(_,w,h)
  surface.SetDrawColor(C.cloth);surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(C.seam);surface.DrawOutlinedRect(0,0,w,h)
  for x=8,w-8,12 do surface.DrawLine(x,7,math.min(x+5,w-8),7);surface.DrawLine(x,h-7,math.min(x+5,w-8),h-7) end
  surface.SetDrawColor(C.paper);surface.DrawRect(18,18,w-92,56)
  plateText("БРОНЕЖИЛЕТ / ПРОВЕРКА", "PlateTitle",28,23,C.ink,w-115)
  plateText("СЪЁМНЫЕ ЗАЩИТНЫЕ ВСТАВКИ", "PlateSmall",29,53,C.ink,w-115)
 end
 local close=frame:Add("DButton");close:SetText("");close:SetSize(44,44);close:SetPos(frame:GetWide()-62,24)
 close.Paint=function(s,w,h)
  surface.SetDrawColor(s:IsHovered() and C.seam or C.dark);surface.DrawRect(0,0,w,h)
  draw.SimpleText("×","PlateTitle",w/2,h/2,C.paper,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 close.DoClick=function() frame:Close() end
 local scroll=frame:Add("DScrollPanel"); scroll:Dock(FILL)
 local active=0; for _,v in ipairs(hp) do if v>0 then active=active+1 end end
 local summary=scroll:Add("DLabel");summary:Dock(TOP);summary:DockMargin(0,0,0,12);summary:SetFont("PlateText");summary:SetTextColor(C.paper);summary:SetWrap(true);summary:SetAutoStretchVertical(true)
 summary:SetText((cap==0 and "Противоударный жилет / без пластин" or ("Защита "..(active*25).."%  ·  установлено "..active.." из "..cap)).."\nТорс и руки. Голова и ноги не защищены жилетом.")
 for i=1,cap do
  local row=scroll:Add("DPanel"); row:Dock(TOP); row:SetTall(116); row:DockMargin(0,0,0,9)
  row.Paint=function(s,w,h) ix.field.PaintPlate(s,w,h,i,hp[i]) end
  local button=row:Add("DButton");button:SetText("");button:SetSize(168,34)
  button.Paint=function(s,w,h)
   surface.SetDrawColor(s:IsEnabled() and (s:IsHovered() and C.ready or C.paper) or C.seam);surface.DrawRect(0,0,w,h)
   draw.SimpleText(hp[i]>0 and "ИЗВЛЕЧЬ" or "УСТАНОВИТЬ","PlateSmall",w/2,h/2,C.ink,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
  end
  row.PerformLayout=function(s,w,h)
   local narrow=w<500;local height=narrow and 154 or 116
   if s:GetTall()~=height then s:SetTall(height) end
   button:SetPos(narrow and 96 or math.max(96,w-180),height-(narrow and 42 or 51))
  end
  button.DoClick=function(this)
   this:SetDisabled(true)
   net.Start("ixPlateChange"); net.WriteUInt(id,32); net.WriteUInt(i,2); net.WriteBool(hp[i]<=0); net.SendToServer()
  end
 end
end)
local function play(name)
 if VManip and VManip.PlayAnim then return VManip:PlayAnim(name) end
end
net.Receive("ixFieldAnim",function()
 local name=net.ReadString()
 if name~="ix_field_pickup" and IsValid(ix.gui.menu) then ix.gui.menu:Remove() end
 if name:sub(1,6)=="equip:" then
  local kind=name:sub(7)
  timer.Simple(.2,function()
   local p=LocalPlayer(); local id=ArcticNVGs_ShortNameToID and ArcticNVGs_ShortNameToID[kind]
   if IsValid(p) and id and p:GetNWInt("nvg",0)==id and not ArcticNVGs_Enabled then ArcticNVGs_Toggle() end
  end)
 elseif name:sub(1,7)=="remove:" then
  local id=ArcticNVGs_ShortNameToID and ArcticNVGs_ShortNameToID[name:sub(8)]
  local spec=id and ArcticNVGs[id]
  if spec then play(spec.VManipOut) end
  ArcticNVGs_Enabled=false
  if ArcticNVGs_RebuildLamp then ArcticNVGs_RebuildLamp() end
 elseif name=="toggleNVG" then if ArcticNVGs_Toggle then ArcticNVGs_Toggle() end
 else play(name) end
end)
