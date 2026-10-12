-- Shared drawing primitives, not a shared device layout. All values are real state.
local F=ix.Facility
F.Hardware={};local H=F.Hardware
H.skins={
 generator={bg=Color(35,33,28),panel=Color(49,47,40),edge=Color(112,103,80),text=Color(247,238,214),muted=Color(192,181,154),accent=Color(239,184,72)},
 battery={bg=Color(23,31,37),panel=Color(34,47,54),edge=Color(88,112,119),text=Color(229,240,235),muted=Color(155,185,179),accent=Color(148,214,134)},
 cabinet={bg=Color(47,53,50),panel=Color(62,70,65),edge=Color(133,145,133),text=Color(242,241,221),muted=Color(197,205,184),accent=Color(238,197,87)},
 comms={bg=Color(30,37,41),panel=Color(43,53,59),edge=Color(96,112,119),text=Color(235,241,241),muted=Color(169,190,196),accent=Color(125,210,181)},
 announcement={bg=Color(34,29,31),panel=Color(51,43,47),edge=Color(111,83,91),text=Color(248,238,231),muted=Color(201,178,180),accent=Color(235,109,95)},
 power={bg=Color(19,28,32),panel=Color(29,44,49),edge=Color(63,101,104),text=Color(226,240,229),muted=Color(151,184,181),accent=Color(182,221,138)},
 workorder={bg=Color(211,204,185),panel=Color(233,227,209),edge=Color(156,150,129),text=Color(40,50,49),muted=Color(76,88,83),accent=Color(69,100,91)},
 clinical={bg=Color(221,233,231),panel=Color(240,247,243),edge=Color(131,163,154),text=Color(29,63,57),muted=Color(63,102,91),accent=Color(19,120,99)},
 wash={bg=Color(229,230,219),panel=Color(248,249,240),edge=Color(153,171,172),text=Color(37,62,70),muted=Color(75,105,113),accent=Color(39,120,145)}
}
H.skins.receiver=H.skins.comms;H.skins.intercom=H.skins.comms;H.skins.workpoint=H.skins.workorder
surface.CreateFont("FacilityPlate",{font="Tahoma",size=14,weight=600,extended=true})
surface.CreateFont("FacilityMeter",{font="Consolas",size=28,weight=700,extended=true})
function H.Skin(parent)
 if isstring(parent) then return H.skins[parent] or H.skins.power end
 while IsValid(parent) do if parent.facilitySkin then return H.skins[parent.facilitySkin] or H.skins.power end;parent=parent:GetParent() end
 return H.skins.power
end
function H.Fit(text,font,width)
 text=tostring(text or "");surface.SetFont(font)
 if surface.GetTextSize(text)<=width then return text end
 while #text>0 and surface.GetTextSize(text.."…")>width do
  local last=utf8.offset(text,-1);text=text:sub(1,(last or #text)-1)
 end
 return text.."…"
end
function H.Text(text,font,x,y,color,width,align)
 draw.SimpleText(H.Fit(text,font,math.max(1,width)),font,x,y,color,align or TEXT_ALIGN_LEFT)
end
function H.Screw(x,y,color)
 surface.DrawCircle(x,y,4,color);surface.SetDrawColor(color);surface.DrawLine(x-2,y-2,x+2,y+2)
end
function H.Lamp(x,y,on,color)
 draw.RoundedBox(8,x-8,y-8,16,16,Color(12,17,16));draw.RoundedBox(5,x-5,y-5,10,10,on and color or Color(71,77,67))
 if on then surface.SetDrawColor(255,255,227,110);surface.DrawRect(x-2,y-3,3,2) end
end
function H.Plate(w,h,skin)
 local c=H.Skin(skin);draw.RoundedBox(5,0,0,w,h,c.bg)
 surface.SetDrawColor(c.edge);surface.DrawOutlinedRect(1,1,w-2,h-2)
 H.Screw(10,10,c.edge);H.Screw(w-10,10,c.edge);H.Screw(10,h-10,c.edge);H.Screw(w-10,h-10,c.edge)
end
function H.Frame(win,kind,title,subtitle)
 win.facilitySkin=kind;win.facilityTitle=title;win:SetTitle("");win:DockPadding(12,80,12,12)
 if win.ShowCloseButton then win:ShowCloseButton(false) end
 local close=win:Add("DButton");close:SetText("");close:SetSize(34,34);close.hardwareClose=true
 close.Paint=function(s,w,h)
  local c=H.Skin(kind);draw.RoundedBox(3,0,0,w,h,s:IsHovered() and c.edge or c.panel)
  surface.SetDrawColor(c.text);surface.DrawLine(11,11,w-11,h-11);surface.DrawLine(w-11,11,11,h-11)
 end
 if close.SetTooltip then close:SetTooltip("Закрыть · Esc") end
 close.DoClick=function() if IsValid(win) then win:Remove() end end
 local baseLayout=win.PerformLayout
 win.PerformLayout=function(s,w,h) if baseLayout then baseLayout(s,w,h) end;close:SetPos(w-48,14) end
 win.Paint=function(_,w,h)
  local c=H.Skin(kind);H.Plate(w,h,kind)
  if kind=="workorder" then
   surface.SetDrawColor(c.edge);surface.DrawRect(24,22,6,34);surface.DrawLine(24,68,w-24,68)
  else
   surface.SetDrawColor(c.accent);surface.DrawRect(24,23,4,30);surface.SetDrawColor(c.edge);surface.DrawLine(24,66,w-24,66)
  end
  H.Text(title,"FacilityTitle",38,17,c.text,w-100);H.Text(subtitle or "","FacilityPlate",38,44,c.muted,w-76)
 end
 win.OnKeyCodePressed=function(s,key) if key==KEY_ESCAPE then s:Remove() end end
end
function H.Gauge(x,y,r,value,label,skin)
 local c=H.Skin(skin);value=math.Clamp(value or 0,0,1)
 draw.RoundedBox(8,x-r-15,y-r-14,r*2+30,r+64,Color(21,23,21))
 for i=0,20 do
  local a=math.rad(180+i*9);local co,si=math.cos(a),math.sin(a)
  surface.SetDrawColor(i<4 and Color(222,109,82) or c.muted)
  surface.DrawLine(x+co*r,y+si*r,x+co*(r-(i%5==0 and 12 or 6)),y+si*(r-(i%5==0 and 12 or 6)))
 end
 local a=math.rad(180+value*180);surface.SetDrawColor(c.accent);surface.DrawLine(x,y,x+math.cos(a)*(r-17),y+math.sin(a)*(r-17))
 H.Lamp(x,y,true,c.accent)
 draw.SimpleText(math.floor(value*100+.5).."%","FacilityMeter",x,y+14,c.text,TEXT_ALIGN_CENTER)
 draw.SimpleText(label or "","FacilityPlate",x,y-r-34,c.muted,TEXT_ALIGN_CENTER)
 draw.SimpleText("0","FacilityPlate",x-r,y+10,c.muted,TEXT_ALIGN_CENTER);draw.SimpleText("100","FacilityPlate",x+r,y+10,c.muted,TEXT_ALIGN_CENTER)
end
function H.Cells(x,y,w,h,value,skin)
 local c=H.Skin(skin);value=math.Clamp(value or 0,0,1);local size=(w-9*5)/10
 for i=1,10 do local px=x+(i-1)*(size+5)
  draw.RoundedBox(3,px,y,size,h,Color(16,26,25));surface.SetDrawColor(c.edge);surface.DrawOutlinedRect(px,y,size,h)
  surface.SetDrawColor(i/10<=value+.001 and c.accent or c.panel);surface.DrawRect(px+4,y+5,math.max(0,size-8),h-10)
 end
end
function H.Socket(x,y,connected,label,skin)
 local c=H.Skin(skin);draw.RoundedBox(18,x-18,y-18,36,36,Color(15,19,19));surface.DrawCircle(x,y,18,c.edge)
 surface.SetDrawColor(c.muted);surface.DrawRect(x-8,y-5,3,9);surface.DrawRect(x+5,y-5,3,9)
 H.Lamp(x+23,y,connected,c.accent);draw.SimpleText(label or "","FacilityPlate",x,y+26,c.text,TEXT_ALIGN_CENTER)
end
function H.Stage(parent,stage,count)
 local bar=parent:Add("DPanel");bar:Dock(TOP);bar:SetTall(38);bar:DockMargin(0,0,0,12)
 bar.Paint=function(s,w,h)
  local c=H.Skin(s);local cell=w/count
  for i=1,count do
   H.Lamp((i-1)*cell+9,14,i<=stage,i<stage and Color(131,207,130) or c.accent)
   H.Text(string.format("%02d",i)..(i==stage and " / ЭТАП" or ""),"FacilityPlate",(i-1)*cell+24,6,c.text,cell-28)
  end
 end
 return bar
end
function H.Header(parent,title,subtitle)
 local card=parent:Add("DPanel");card:Dock(TOP);card:SetTall(92);card:DockMargin(0,0,0,16)
 card.Paint=function(s,w,h)
  local c=H.Skin(s);surface.SetDrawColor(c.panel);surface.DrawRect(0,0,w,h);surface.SetDrawColor(c.edge);surface.DrawOutlinedRect(0,0,w,h)
  H.Text(title,"FacilityTitle",20,16,c.text,w-40);H.Text(subtitle or "","FacilityText",20,51,c.muted,w-40)
 end
 return card
end
function H.DevicePlateGeometry(ent,kind)
 local center,ang,width
 if kind=="generator" and string.lower(ent:GetModel() or "")=="models/props_c17/trappropeller_engine.mdl" then
  -- Stock VVD: the right upper cover is at z=15.74. This small plate fits
  -- within that cover; using OBB max would leave it above the taller cap.
  center=Vector(3.1,-2.4,15.90);ang=Angle(0,0,0);width=6.4
 elseif kind=="generator" and string.lower(ent:GetModel() or "")=="models/props_se/junk/mobile_generator.mdl" then
  -- Tank roof is z=17.266; this patch stays beside the raised filler cap.
  center=Vector(7.3,-.5,17.42);ang=Angle(0,0,0);width=6
 elseif kind=="battery" then
  local low,high=ent:GetModelBounds();center=Vector((low.x+high.x)*.5,(low.y+high.y)*.5,high.z+.15)
  ang=Angle(0,0,0);width=math.min(8,(high.x-low.x)*.6)
 else return end
 local origin,a=LocalToWorld(center,ang,ent:GetPos(),ent:GetAngles());local scale=width/320
 return origin-a:Forward()*160*scale-a:Right()*95*scale,a,scale
end
function H.DrawDevicePlate(ent,kind)
 local origin,ang,scale=H.DevicePlateGeometry(ent,kind);if not origin then return end
 local c=H.Skin(kind);local bad=ent:GetNW2Bool("ixFacilityFault",false)
 local value=kind=="generator" and ent:GetNW2Float("ixFacilityFuel",0)/600 or ent:GetNW2Float("ixFacilityCharge",0)/6000
 cam.Start3D2D(origin,ang,scale)
 H.Plate(320,190,kind)
 H.Text(kind=="generator" and "РЕЗЕРВ / ТОПЛИВО" or "РЕЗЕРВ / ЗАРЯД","FacilityText",22,19,c.text,276)
 H.Cells(22,55,276,48,value,kind)
 draw.SimpleText(math.floor(value*100).."%","FacilityMeter",22,119,c.text)
 local running=ent:GetNW2Bool("ixFacilityRunning",false)
 local status=bad and "НЕИСПРАВНО" or kind=="generator" and (running and "РАБОТАЕТ" or "ОСТАНОВЛЕН") or ent:GetNW2String("ixFacilityState","РЕЗЕРВ")
 H.Lamp(118,140,bad or running or kind=="battery",bad and Color(234,104,84) or c.accent);H.Text(status,"FacilityPlate",136,130,c.text,164)
 cam.End3D2D()
end
