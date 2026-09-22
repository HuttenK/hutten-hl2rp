-- Setting-independent gameplay presentation. No new network messages or gameplay state.
if ix.GameplayHUD then
 for _, panel in ipairs(ix.GameplayHUD.notices or {}) do if IsValid(panel) then panel:Remove() end end
end
local H = {}
ix.GameplayHUD = H
local U = ix.Legends
local function S(n) return math.floor(n * math.Clamp(ScrH()/1080, 0.7, 1.5)) end
local function T(en, ru) return U.T(en, ru) end
local ink, muted = Color(232,228,224), Color(164,159,164)
H.ManagedBars = {hunger=true, thirst=true}
H.notices = {}

ix.lang.AddTable("en", {optCinematicHUD="Cinematic gameplay HUD",optdCinematicHUD="Compact vitals, compass, action feedback and notifications."})
ix.lang.AddTable("ru", {optCinematicHUD="Кинематографичный интерфейс",optdCinematicHUD="Компактные показатели, компас, действия и уведомления."})
ix.option.Add("cinematicHUD", ix.type.bool, true, {category="appearance"})
function H.Enabled() return ix.option.Get("cinematicHUD", true) end
function H.Visible()
 local p=LocalPlayer()
 return H.Enabled() and IsValid(p) and p:GetCharacter() and p:Alive() and
  not p:GetNetVar("crit") and
  not (IsValid(ix.gui.characterMenu) and not ix.gui.characterMenu:IsClosing()) and
  not IsValid(ix.gui.fieldlink) and not IsValid(ix.gui.menu) and not (ix.infoMenu and ix.infoMenu.open) and not gui.IsGameUIVisible() and GetConVar("cl_drawhud"):GetBool()
end
function H.Ratio(value, maximum)
 value,maximum=tonumber(value),tonumber(maximum)
 if not value or not maximum or value~=value or maximum~=maximum or math.abs(value)==math.huge or math.abs(maximum)==math.huge or maximum<=0 then return 0 end
 return math.Clamp(value/maximum,0,1)
end
local function Fonts()
 for name,size in pairs({Label=16,Body=20}) do
  surface.CreateFont("cinematic."..name,{font=name=="Label" and "Consolas" or "Roboto",size=S(size),weight=name=="Hero" and 700 or 500,extended=true,antialias=true})
 end
end
Fonts()
hook.Add("OnScreenSizeChanged","CinematicHUDFonts",Fonts)
local function Text(text,font,x,y,color,align)
 local face="cinematic."..font
 draw.SimpleText(text,face,x+1,y+S(2),Color(0,0,0,math.min(210,(color and color.a) or 255)),align or TEXT_ALIGN_LEFT)
 draw.SimpleText(text,face,x,y,color or ink,align or TEXT_ALIGN_LEFT)
end
local hudShade = Material("vgui/gradient-l", "smooth")
local function Panel(x,y,w,h)
 -- A single filtered gradient avoids fractional strip edges and alpha seams.
 surface.SetMaterial(hudShade)
 surface.SetDrawColor(7,9,14,145)
 surface.DrawTexturedRect(x,y,w,h)
end
-- Continuous, unnumbered readings: no dial, segments or enclosing HUD panel.
local shadow = Color(0,0,0,185)
local track = Color(160,160,156,65)
local icons = {
 blood={ {8,1,2,10}, {2,10,3,15}, {3,15,8,18}, {8,18,13,15}, {13,15,14,10}, {14,10,8,1}, {5,11,5,14} },
 stamina={ {10,1,4,9}, {4,9,10,9}, {10,9,6,16} },
 food={ {3,1,3,6}, {6,1,6,6}, {9,1,9,6}, {3,6,9,6}, {6,6,6,16}, {14,1,14,16} },
 thirst={ {8,1,3,8}, {3,8,2,11}, {2,11,4,15}, {4,15,8,17}, {8,17,12,15}, {12,15,14,11}, {14,11,13,8}, {13,8,8,1} }
}
local function Icon(name,x,y,color)
 for _,line in ipairs(icons[name]) do
  surface.SetDrawColor(shadow)
  surface.DrawLine(x+S(line[1])+1,y+S(line[2])+1,x+S(line[3])+1,y+S(line[4])+1)
  surface.SetDrawColor(color)
  surface.DrawLine(x+S(line[1]),y+S(line[2]),x+S(line[3]),y+S(line[4]))
 end
end
local function Meter(name,x,y,w,value)
 local color=value<0.25 and U.accent or ink
 Icon(name,x,y-S(7),name=="blood" and Color(235,65,82) or name=="stamina" and Color(238,199,78) or color)
 local bx=x+S(29); local thickness=name=="blood" and S(4) or S(2)
 U.Rect(bx-1,y-1,w+2,thickness+2,shadow)
 U.Rect(bx,y,w,thickness,track)
 if value>0 then U.Rect(bx,y,w*value,thickness,color) end
end
local function Fit(text,width)
 surface.SetFont("cinematic.Body")
 text=tostring(text or "")
 if surface.GetTextSize(text)<=width then return text end
 while #text>0 and surface.GetTextSize(text.."…")>width do text=text:utf8sub(1,text:utf8len()-1) end
 return text.."…"
end
function H.Action()
 if not H.Visible() then return end
 local start,finish=ix.bar.actionStart,ix.bar.actionEnd
 local now=CurTime()
 if finish<=now or finish<=start then return end
 local w=S(440); local x,y=(ScrW()-w)/2,ScrH()*0.72
 Panel(x,y,w,S(63))
 Text(Fit(ix.bar.actionText,w-S(64)),"Body",x+S(14),y+S(10))
 Text(string.format("%.1fs",math.max(0,finish-now)),"Label",x+w-S(12),y+S(14),muted,TEXT_ALIGN_RIGHT)
 U.Rect(x+S(14),y+S(48),w-S(28),S(3),Color(65,48,54))
 U.Rect(x+S(14),y+S(48),(w-S(28))*H.Ratio(now-start,finish-start),S(2),U.accent)
end
function H.Pickup()
 if not H.Visible() then return end
 local p=LocalPlayer(); local target=p.ixInteractionTarget; local start=p.ixInteractionStartTime
 local duration=ix.config.Get("itemPickupTime",0.5)
 if not IsValid(target) or not start or duration<=0 then return end
 if SysTime()>=start+duration or p:GetEyeTrace().Entity~=target then
  p.ixInteractionTarget=nil; p.ixInteractionStartTime=nil; return
 end
 local x,y=ScrW()/2,ScrH()/2+S(48)
 local key=string.upper(input.LookupBinding("+use") or "?")
 Text("["..key.."]  "..T("HOLD","УДЕРЖИВАЙТЕ"),"Label",x,y,ink,TEXT_ALIGN_CENTER)
 U.Rect(x-S(45),y+S(20),S(90),S(2),Color(65,48,54))
 U.Rect(x-S(45),y+S(20),S(90)*H.Ratio(SysTime()-start,duration),S(2),U.accent)
end
function H.Notify(message)
 -- Real labels wrap through a panel; do not truncate messages or create another queue.
 local p=vgui.Create("DPanel")
 p:SetSize(math.min(S(370),ScrW()*0.4),S(60)); p:SetMouseInputEnabled(false); p:SetKeyboardInputEnabled(false)
 local label=p:Add("DLabel"); label:SetFont("cinematic.Body"); label:SetTextColor(ink)
 label:SetPos(S(16),S(24)); label:SetWide(p:GetWide()-S(32)); label:SetWrap(true); label:SetAutoStretchVertical(true)
 label:SetText(tostring(message))
 p.started=RealTime(); p.duration=math.Clamp(#tostring(message)/16,5,14)
 p.Paint=function(this,w,h)
  Panel(0,0,w,h)
  Text(T("UPDATE","СООБЩЕНИЕ"),"Label",S(16),S(6),U.accent)
  U.Rect(S(16),h-S(5),(w-S(32))*math.Clamp(1-(RealTime()-this.started)/this.duration,0,1),1,U.line)
 end
 p.Think=function(this)
  local age=RealTime()-this.started
  if age>this.duration then this:Remove() return end
  local fade=ix.option.Get("disableAnimations",false) and 1 or math.min(math.Clamp(age/0.15,0,1),math.Clamp((this.duration-age)/0.4,0,1))
  this:SetAlpha(255*fade)
  this:SetTall(math.max(S(60),label:GetTall()+S(37)))
  local y=S(130)
  for _,other in ipairs(H.notices) do if other==this then break end if IsValid(other) then y=y+other:GetTall()+S(8) end end
  this:SetPos(ScrW()-this:GetWide()-S(32),y)
 end
 for i=#H.notices,1,-1 do if not IsValid(H.notices[i]) then table.remove(H.notices,i) end end
 if #H.notices>=4 then local old=table.remove(H.notices,1); if IsValid(old) then old:Remove() end end
 H.notices[#H.notices+1]=p
end
-- Keep the data adapter separate from presentation; missing optional systems stay hidden.
function H.ReadVitals(p,char)
 local anatomy=ix.Anatomy and ix.Anatomy.Read(char)
 local values={blood=anatomy and anatomy.blood,anatomy=anatomy}
 local stamina=p:GetLocalVar("stm")
 if stamina~=nil and char.GetMaxStamina then values.stamina=H.Ratio(stamina,char:GetMaxStamina()) end
 local faction=ix.faction.indices[char:GetFaction()]
 if not (faction and faction.dontNeedFood) then
  if char.GetHunger then values.food=H.Ratio(char:GetHunger(),100) end
  if char.GetThirst then values.thirst=H.Ratio(char:GetThirst(),100) end
 end
 return values
end
function H.Draw()
 if not H.Visible() then return end
 local p=LocalPlayer(); local values=H.ReadVitals(p,p:GetCharacter())
 -- A small open composition at the safe edge leaves the world unobstructed.
 local x,y=S(128),S(66)
 if values.anatomy then ix.Anatomy.Draw(S(40),S(38),S(66),S(158),values.anatomy) end
 if values.blood then Meter("blood",x,y,S(210),values.blood) end
 if values.stamina then Meter("stamina",x,y+S(25),S(210),values.stamina) end
 if values.food then Meter("food",x,y+S(59),S(65),values.food) end
 if values.thirst then Meter("thirst",x+S(145),y+S(59),S(65),values.thirst) end
 -- Directions glide through a soft edge fade; no bearing numbers or backing plate.
 local heading=(-p:EyeAngles().y)%360
 local cx,cy=ScrW()/2,S(35)
 local span=math.min(S(320),ScrW()*0.30)
 local names={[0]="N",[45]="NE",[90]="E",[135]="SE",[180]="S",[225]="SW",[270]="W",[315]="NW"}
 for i=-6,6 do
  local degree=(math.floor(heading/15)+i)*15
  local delta=math.AngleDifference(degree,heading)
  if math.abs(delta)<80 then
   local xx=cx+delta/80*span/2
   local alpha=math.floor(210*(1-math.abs(delta)/80))
   local name=names[degree%360]
   if name then Text(name,"Label",xx,cy,Color(232,228,224,alpha),TEXT_ALIGN_CENTER) end
   surface.SetDrawColor(0,0,0,alpha)
   surface.DrawLine(xx+1,cy+S(24)+1,xx+1,cy+S(name and 29 or 26)+1)
   surface.SetDrawColor(232,228,224,alpha)
   surface.DrawLine(xx,cy+S(24),xx,cy+S(name and 29 or 26))
  end
 end
 U.Rect(cx-1,cy+S(34),2,S(4),ink)
end
hook.Add("HUDPaint","CinematicGameplayHUD",H.Draw)
