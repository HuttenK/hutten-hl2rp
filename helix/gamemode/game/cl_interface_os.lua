-- Shared presentation only. Original character/inventory operations remain authoritative.
local O=setmetatable({}, {__index=ix.Legends}); ix.InterfaceOS=O
local S=ix.Legends.Scale
O.ink=Color(240,221,223); O.muted=Color(174,139,147); O.accent=Color(255,53,76)
O.cyan=Color(255,106,120); O.line=Color(150,43,57,100); O.panel=Color(27,9,16,190)
local function Fonts()
 for name,def in pairs({Display={68,800},Title={30,700},Heading={21,600},Body={17,500},Small={14,400},Mono={12,500}}) do
  surface.CreateFont("facility."..name,{font=name=="Mono" and "Consolas" or "Roboto",size=S(def[1]),weight=def[2],extended=true,antialias=true})
 end
end
Fonts(); hook.Add("OnScreenSizeChanged","FacilityOSFonts",Fonts)
function O.Text(text,font,x,y,color,align)
 draw.SimpleText(tostring(text or ""),"facility."..font,x,y,color or O.ink,align or TEXT_ALIGN_LEFT)
end
function O.Label(parent,text,font,color)
 local p=ix.Legends.Label(parent,text,font,color or O.ink); p:SetFont("facility."..(font or "Body")); return p
end
function O.Plate(x,y,w,h,color,line)
 local cut=math.min(S(12),w*.1,h*.25)
 draw.NoTexture(); surface.SetDrawColor(color or O.panel)
 surface.DrawPoly({{x=x,y=y},{x=x+w-cut,y=y},{x=x+w,y=y+cut},{x=x+w,y=y+h},{x=x+cut,y=y+h},{x=x,y=y+h-cut}})
 if line then O.Rect(x+S(12),y+h-1,math.max(0,w-S(24)),1,line) end
end
function O.ButtonFace(p,w,h,primary,selected)
 local active=not p:GetDisabled() and (p:IsHovered() or p:HasFocus() or selected)
 local target=active and 1 or 0
 p.osHover=ix.option.Get("disableAnimations",false) and target or Lerp(1-math.exp(-FrameTime()*20),p.osHover or 0,target)
 local f=p.osHover
 O.Plate(0,0,w,h,primary and Color(94+f*50,10+f*8,27+f*12,220) or Color(24+f*45,7+f*6,14+f*12,185+f*45))
 if f>0 then
  O.Rect(S(12),h-S(2),(w-S(24))*f,1,O.accent)
  O.Rect(0,S(8),S(3),h-S(16),Color(255,53,76,220*f))
 end
 if selected then O.Rect(S(2),S(12),S(3),h-S(24),O.cyan) end
 return p:IsDown() and 1 or 0
end
function O.Button(parent,text,action,primary)
 local p=parent:Add("DButton"); p:SetText(""); p:SetTall(S(48)); p:SetTooltip(text)
 p.Paint=function(this,w,h)
  local y=O.ButtonFace(this,w,h,primary)
  draw.SimpleText(text,"facility.Body",S(18),h/2+y,this:GetDisabled() and O.muted or O.ink,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  O.Text("›","Heading",w-S(24),h/2-S(12),primary and O.ink or O.cyan)
 end
 p.OnCursorEntered=function() if (O.nextHover or 0)<RealTime() then O.nextHover=RealTime()+.09; ix.Legends.PlayUISound("hover") end end
 p.DoClick=function(this) if this:GetDisabled() then return end this.osPressedAt=RealTime(); ix.Legends.PlayUISound("click"); action(this) end
 return p
end
function O.Field(parent,title,value,callback,multiline)
 local e=ix.Legends.Field(parent,title,value,callback,multiline); e:SetFont("facility.Body")
 e.Paint=function(this,w,h) O.Plate(0,0,w,h,O.panel,this:HasFocus() and O.cyan or O.line); this:DrawTextEntryText(O.ink,O.cyan,O.ink) end
 return e
end
function O.Scroll(parent)
 local p=ix.Legends.Scroll(parent)
 p:GetVBar().btnGrip.Paint=function(_,w,h) draw.RoundedBox(2,0,0,w,h,O.muted) end
 return p
end
local glyphs={
 launcher={{2,2,8,2},{8,2,8,8},{8,8,2,8},{2,8,2,2},{14,2,20,2},{20,2,20,8},{20,8,14,8},{14,8,14,2},{2,14,8,14},{8,14,8,20},{8,20,2,20},{2,20,2,14},{14,14,20,14},{20,14,20,20},{20,20,14,20},{14,20,14,14}},
 identity={{7,2,15,2},{15,2,15,10},{15,10,7,10},{7,10,7,2},{4,21,4,15},{4,15,11,12},{11,12,18,15},{18,15,18,21},{4,21,18,21}},
 equipment={{6,7,16,7},{16,7,19,20},{19,20,3,20},{3,20,6,7},{7,7,7,3},{7,3,15,3},{15,3,15,7},{7,12,15,12}},
 craft={{3,4,8,2},{8,2,8,7},{8,7,12,10},{12,10,20,18},{20,18,18,21},{18,21,9,12},{9,12,3,9},{3,9,3,4}},
 assignments={{5,3,19,3},{19,3,19,21},{19,21,5,21},{5,21,5,3},{8,8,16,8},{8,12,16,12},{8,16,14,16}},
 journal={{2,3,10,5},{10,5,12,5},{12,5,20,3},{20,3,20,19},{20,19,12,21},{12,21,10,21},{10,21,2,19},{2,19,2,3},{11,5,11,21}},
 system={{11,1,11,5},{11,17,11,22},{1,11,5,11},{17,11,22,11},{4,4,7,7},{16,16,19,19},{4,19,7,16},{16,7,19,4},{8,8,14,8},{14,8,14,14},{14,14,8,14},{8,14,8,8}}
}
function O.Icon(name,x,y,size,color)
 surface.SetDrawColor(color or O.cyan)
 for _,v in ipairs(glyphs[name] or glyphs.launcher) do surface.DrawLine(x+v[1]*size/24,y+v[2]*size/24,x+v[3]*size/24,y+v[4]*size/24) end
end
function O.Emblem(x,y,size,color)
 if ix.Fieldlink and ix.Fieldlink.DrawSCP then ix.Fieldlink.DrawSCP(x,y,size,color); return end
 -- Vector fallback when the physical PDA plugin is disabled.
 draw.NoTexture(); surface.SetDrawColor(color)
 local function point(a,r) return {x=x+size*(.5+math.cos(a)*r),y=y+size*(.5+math.sin(a)*r)} end
 for i=0,95 do
  local a,b=i*math.pi/48,(i+1)*math.pi/48
  surface.DrawPoly({point(a,.44),point(b,.44),point(b,.405),point(a,.405)})
  surface.DrawPoly({point(a,.31),point(b,.31),point(b,.285),point(a,.285)})
 end
 for i=0,2 do
  local a=-math.pi/2+i*math.pi*2/3
  surface.DrawPoly({point(a-.16,.48),point(a+.16,.48),point(a+.16,.32),point(a+.30,.32),point(a,.15),point(a-.30,.32),point(a-.16,.32)})
 end
end
-- Staggered opaque shutters expose the real menu underneath. No screenshot,
-- render target or global fade: input stays captured until every band clears.
function O.DrawTerminalReveal(w,h,t)
 local bands=14
 for i=0,bands-1 do
  local delay=((i*5)%bands)/bands*.17
  local progress=math.Clamp((t-delay)/.76,0,1)
  local remaining=w*(1-progress)^3
  local y=math.floor(i*h/bands); local bottom=math.ceil((i+1)*h/bands)
  if remaining>0 then
   local x=i%2==0 and 0 or w-remaining
   O.Rect(x,y,remaining,bottom-y,Color(10,3,8))
   if progress>0 and progress<1 then
    local edge=i%2==0 and remaining or x
    O.Rect(math.Clamp(edge-1,0,w-2),y,2,bottom-y,Color(255,53,76,150))
    O.Rect(math.Clamp(edge-S(14),0,math.max(0,w-S(28))),y+2,math.min(w,S(28)),1,Color(255,132,146,130))
   end
  end
 end
 -- Short, localized packet tears during acquisition; deterministic per band.
 if t>.06 and t<.38 then
  local tick=math.floor(t*36)
  for i=1,4 do
   local x=((i*173+tick*31)%997)/997*w*.8
   local y=((i*211+tick*19)%683)/683*h
   O.Rect(x,y,w*(.04+i*.012),S(2),Color(255,49,85,65))
  end
 end
 if t<.32 then
  local alpha=255*math.Clamp(1-t/.32,0,1)
  O.Text("SCiPNET / ПЕРЕДАЧА УПРАВЛЕНИЯ","Mono",w/2,h*.5,Color(241,192,202,alpha),TEXT_ALIGN_CENTER)
 end
 -- Brackets settle at the screen margins as the last shutters clear.
 local settle=math.Clamp((t-.55)/.45,0,1)
 if settle>0 and settle<1 then
  local inset=S(40)+(1-settle)*S(24); local length=S(45)
  local color=Color(255,80,105,170*(1-settle))
  for _,v in ipairs({{inset,inset,1,1},{w-inset,inset,-1,1},{inset,h-inset,1,-1},{w-inset,h-inset,-1,-1}}) do
   surface.SetDrawColor(color)
   surface.DrawLine(v[1],v[2],v[1]+length*v[3],v[2])
   surface.DrawLine(v[1],v[2],v[1],v[2]+length*v[4])
  end
 end
end

-- Introduction is user-driven. No automatic dismissal and no input reaches
-- the underlying menu until the reveal is complete.
function O.Boot(parent)
 if IsValid(parent.terminalIntro) then return end
 local p=parent:Add("EditablePanel"); parent.terminalIntro=p
 p:SetZPos(32767); p:Dock(FILL); p:SetMouseInputEnabled(true); p:SetKeyboardInputEnabled(true)
 p.createdAt=RealTime(); p.phase="intro"; p.opacity=1
 local button=O.Button(p,"Терминал SCiPNet",function() p:BeginLoading() end,true)
 p.button=button
 button.DoClick=function() p:BeginLoading() end
 function p:BeginLoading()
  if self.phase~="intro" then return end
  self.phase="loading"; self.startedAt=RealTime()
  button:SetVisible(false)
  ix.Legends.PlayUISound("click")
 end
 function p:OnKeyCodePressed(key)
  if key==KEY_ENTER or key==KEY_SPACE then self:BeginLoading() end
 end
 function p:PerformLayout(w,h)
  local bw=math.min(S(340),w-S(48))
  button:SetSize(bw,S(56)); button:SetPos((w-bw)/2,h*.56+S(42))
 end
 function p:Think()
  if self.phase=="intro" then return end
  local reduced=ix.option.Get("disableAnimations",false)
  local age=RealTime()-self.startedAt
  if self.phase=="loading" and parent.playerReady and (reduced or age>=1.65) then
   self.phase="reveal"; self.revealAt=RealTime()
   if not reduced then surface.PlaySound("buttons/button14.wav") end
  end
  if self.phase=="reveal" then
   local t=reduced and 1 or math.Clamp((RealTime()-self.revealAt)/.9,0,1)
   self.revealProgress=t
   if t>=1 then self:Remove() end
  end
 end
 function p:Paint(w,h)
  if self.phase=="reveal" then O.DrawTerminalReveal(w,h,self.revealProgress or 0); return end
  local alpha=self.opacity or 1
  O.Rect(0,0,w,h,Color(10,3,8,255*alpha))
  local reduced=ix.option.Get("disableAnimations",false)
  local entrance=reduced and 1 or math.Clamp((RealTime()-self.createdAt)/.8,0,1)
  entrance=1-(1-entrance)^3
  local size=math.min(S(200),h*.27)
  local y=h*.38-size/2+(1-entrance)*S(12)
  O.TransmissionLogo((w-size)/2,y,size,Color(241,192,202,255*entrance*alpha))
  O.Text("S C P   F O U N D A T I O N","Mono",w/2,y+size+S(27),Color(174,139,147,230*entrance*alpha),TEXT_ALIGN_CENTER)
  if self.phase~="intro" then
   local age=RealTime()-self.startedAt
   local progress=math.min(age/1.65,parent.playerReady and 1 or .88)
   local bw=math.min(S(340),w-S(48)); local by=h*.56+S(61)
   O.Rect((w-bw)/2,by,bw,2,Color(112,30,50,80*alpha))
   O.Rect((w-bw)/2,by,bw*progress,2,Color(255,106,120,255*alpha))
   local label=not parent.playerReady and "ОЖИДАНИЕ АРХИВА ПЕРСОНАЖЕЙ" or
    (progress<.45 and "ЗАПУСК ТЕРМИНАЛА" or progress<1 and "ПОДГОТОВКА ИНТЕРФЕЙСА" or "ТЕРМИНАЛ ГОТОВ")
   O.Text(label,"Mono",w/2,by+S(23),Color(174,139,147,255*alpha),TEXT_ALIGN_CENTER)
  else
   O.Text("ENTER / SPACE","Mono",w/2,h*.56+S(114),Color(174,139,147,160*alpha),TEXT_ALIGN_CENTER)
  end
  O.Rect(S(42),h-S(68),w-S(84),1,Color(150,43,57,35*alpha))
  O.Text("SECURE. CONTAIN. PROTECT.","Mono",w/2,h-S(43),Color(174,139,147,150*alpha),TEXT_ALIGN_CENTER)
 end
 button.Paint=function(this,w,h)
  local hover=this:IsHovered() or this:HasFocus()
  this.glow=ix.option.Get("disableAnimations",false) and (hover and 1 or 0) or Lerp(1-math.exp(-FrameTime()*12),this.glow or 0,hover and 1 or 0)
  O.Plate(0,0,w,h,Color(34+this.glow*25,8+this.glow*7,18+this.glow*13,235))
  O.Rect(S(16),h-1,w-S(32),1,Color(255,106,120,100+this.glow*120))
  draw.SimpleText("Терминал SCiPNet","facility.Heading",w/2,h/2,O.ink,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 -- The overlay owns keyboard focus; Enter/Space cannot select a character.
 p:RequestFocus()
end

-- Low-frequency localized interference, never a full-screen flash.
function O.Signal(w,h,subtle)
 local moving=not ix.option.Get("disableAnimations",false)
 local t=moving and RealTime() or 0
 local alpha=subtle and 8 or 15
 for y=0,h,math.max(4,S(5)) do O.Rect(0,y,w,1,Color(172,35,62,alpha)) end
 for i=1,7 do
  local y=(i*h*.139+(moving and t*(8+i*3) or 0))%h
  local x=(i*197)%math.max(1,w*.8)
  O.Rect(x,y,w*(.035+i*.008),1,Color(255,69,96,subtle and 24 or 55))
 end
end
function O.TransmissionLogo(x,y,size,color)
 O.Emblem(x,y,size,color)
 if ix.option.Get("disableAnimations",false) then return end
 local t=RealTime(); local phase=t%6.8
 if phase>.18 then return end
 -- No moving coordinates passed to the emblem cache: draw offset through a
 -- transform, keeping the mesh cache bounded across every animated frame.
 local matrix=Matrix(); matrix:Translate(Vector(S(math.floor(phase*40)%2==0 and 7 or -5),0,0))
 cam.PushModelMatrix(matrix,true)
 O.Emblem(x,y,size,Color(255,30,67,95))
 cam.PopModelMatrix()
 O.Rect(x,y+size*.38,size,S(2),Color(255,130,144,120))
 O.Rect(x+size*.13,y+size*.66,size*.71,S(3),Color(18,2,9,220))
end
