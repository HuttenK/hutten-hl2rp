local F=ix.Facility
local H=F.Hardware
local session,window,held,heldAt
local ink,accent=Color(230,243,246),Color(92,229,201)
local verdicts={closed="Цепь есть",open="Обрыв между выбранными точками",wrong="Обрыв на другом участке",spent="Закончились замеры",
 fixed="Этап завершён",burst="Сработал сброс давления",low="Давление ниже допуска",high="Давление выше допуска",near="Близко к допуску",
 below="Давление ниже допуска",belownear="Чуть ниже допуска",above="Давление выше допуска",abovenear="Чуть выше допуска",
 loose="Недостаточное усилие",strip="Сорвана резьба",stripped="Крепёж повреждён: повторите этап",skew="Нарушен порядок. Затягивайте накрест",tight="Болт затянут"}
local function send(kind,a,b)
 if not session then return end
 net.Start("ixFacilityEngineeringInput");net.WriteUInt(session.token,32);net.WriteUInt(session.round,16)
 net.WriteString(kind);net.WriteInt(a or 0,16);net.WriteInt(b or 0,16);net.SendToServer()
end
local function close(cancel)
 if cancel then send("cancel") end
 session=nil;held=nil;heldAt=nil
 local win=window;window=nil
 if IsValid(win) then win.silent=true;win:Remove() end
end
local function label(parent,text,big) return F.Label(parent,text,big) end
function F.OpenEngineering(data)
 if not istable(data) or not F.Number(data.token,1,4294967295) or not F.Number(data.round,1,65535) then return end
 if not istable(data.state) or not F.engineeringNames[data.kind] then return end
 if session and session.token==data.token and data.round<session.round then return end
 if data.result=="cancel" or data.result=="complete" then
  if session and session.token==data.token then close(false) end
  if data.result=="complete" then surface.PlaySound("buttons/button14.wav") end
  return
 end
 if not F.Number(data.stage,1,5) or not isnumber(data.expires) or not isnumber(data.entity) then return end
 local old=session
 if IsValid(window) then window.silent=true;window:Remove() end
 F.CloseRepair(true)
 if IsValid(F.window) then F.window:Remove() end
 if IsValid(F.helpWindow) then F.helpWindow:Remove() end
 session=data;held=nil;heldAt=nil
 if data.kind=="bolts" then return end
 window=vgui.Create("DFrame");local win=window
 win:SetSize(math.min(860,ScrW()-30),math.min(780,ScrH()-30));win:Center();win:SetTitle("SCiPNET / "..F.engineeringNames[data.kind]);win:MakePopup()
 H.Frame(win,data.kind=="probe" and "cabinet" or "generator",data.kind=="probe" and (data.noParts and "ЭЛЕКТРОЩИТ · ПРОВЕРКА ЦЕПИ" or "ЭЛЕКТРИЧЕСКИЙ УЗЕЛ") or "ГИДРАВЛИЧЕСКИЙ УЗЕЛ",data.title)
 win.OnRemove=function(s) if window==s then window=nil end;if not s.silent then close(true) end end
 win.OnKeyCodePressed=function(_,key) if key==KEY_ESCAPE then close(true) end end
 local body=win:Add("DScrollPanel");body:Dock(FILL);body:DockMargin(18,8,18,14)
 H.Stage(body,data.stage,5)
 local feedback=verdicts[data.message] or data.message or ""
 if data.kind~="probe" then label(body,feedback) end
 local state=data.state
 if data.kind=="probe" then
  label(body,"1. Выберите два контакта для замера.  2. Найдите обрыв и нажмите соответствующий провод.")
  local pick
  local points=body:Add("DPanel");points:Dock(TOP);points:SetTall(266);points:DockMargin(0,0,0,14);win.probeBoard=points
  local pointButtons,segments={},{}
  local wireColors={Color(201,107,88),Color(207,178,90),Color(117,163,117),Color(103,155,171)}
  points.Paint=function(_,w,h)
   local c=H.skins.cabinet;H.Plate(w,h,"cabinet")
   -- Cable duct and DIN rail: terminals above, accessible wire runs below.
   surface.SetDrawColor(25,32,30);surface.DrawRect(14,51,w-28,48);surface.DrawRect(14,206,w-28,30)
   for x=22,w-16,14 do surface.SetDrawColor(c.edge);surface.DrawLine(x,211,x,230) end
   surface.SetDrawColor(c.edge);surface.DrawLine(14,58,w-14,58);surface.DrawLine(14,91,w-14,91)
   H.Text("КЛЕММНАЯ КОЛОДКА / НАЖМИТЕ ДВА КОНТАКТА","FacilityPlate",18,17,c.text,w-36)
   H.Text("ПРОВОДА / НАЖМИТЕ НАЙДЕННЫЙ УЧАСТОК","FacilityPlate",18,243,c.muted,w-36)
  end
  points.PerformLayout=function(_,w)
   local left,right=34,w-34;local step=(right-left)/state.count
   local size=math.min(42,step-4)
   for i,button in pairs(pointButtons) do button:SetPos(left+i*step-size*.5,54);button:SetSize(size,42) end
   for i,button in pairs(segments) do button:SetPos(left+(i-1)*step+3,111);button:SetSize(math.max(22,step-6),88) end
  end
  local tester=body:Add("DPanel");tester:Dock(TOP);tester:SetTall(106);tester:DockMargin(0,0,0,14)
  tester.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(29,32,29));surface.SetDrawColor(151,129,57);surface.DrawOutlinedRect(2,2,w-4,h-4)
   H.Text("ПРОЗВОНКА · ОСТАЛОСЬ ЗАМЕРОВ: "..state.budget,"FacilityPlate",18,13,Color(231,201,114),w-36)
   draw.RoundedBox(2,16,38,w-32,53,Color(179,192,150))
   H.Text(feedback~="" and feedback or pick~=nil and ("Щуп на контакте "..pick..". Выберите второй.") or "Подключите щупы к двум контактам.","FacilityText",28,54,Color(36,52,38),w-56)
  end
  for i=0,state.count do
   local n=i;local button=points:Add("DButton");pointButtons[i]=button;button.facilityProbePoint=i;button:SetText("")
   button.Paint=function(s,w,h)
    local selected=pick==n;draw.RoundedBox(3,0,0,w,h,selected and Color(238,197,87) or Color(149,154,137))
    surface.SetDrawColor(Color(44,51,46));surface.DrawOutlinedRect(0,0,w,h);surface.DrawLine(6,7,w-6,7)
    draw.SimpleText(n,"FacilityTitle",w/2,12,Color(34,43,36),TEXT_ALIGN_CENTER)
    if s:IsHovered() then surface.SetDrawColor(color_white);surface.DrawOutlinedRect(1,1,w-2,h-2) end
   end
   button.DoClick=function()
    if pick==nil then pick=n;feedback=""
    elseif pick==n then pick=nil
    else send("probe",math.min(pick,n),math.max(pick,n));pick=nil end
   end
  end
  for i=1,state.count do local n=i
   local b=points:Add("DButton");segments[i]=b;b.facilityProbeSegment=i;b:SetText("")
   b.Paint=function(s,w,h)
    local possible=state.possible[n];local c=possible and wireColors[(n-1)%4+1] or Color(87,100,90)
    surface.SetDrawColor(c)
    for offset=-2,2 do surface.DrawLine(4,4,w*.3+offset,34);surface.DrawLine(w*.3+offset,34,w*.7+offset,34);surface.DrawLine(w*.7+offset,34,w-4,4) end
    draw.RoundedBox(2,0,53,w,29,possible and Color(31,40,34) or Color(59,69,59))
    draw.SimpleText((n-1).."–"..n,"FacilityPlate",w/2,60,possible and Color(241,237,215) or Color(139,158,143),TEXT_ALIGN_CENTER)
    if possible and s:IsHovered() then surface.SetDrawColor(Color(238,197,87));surface.DrawOutlinedRect(0,0,w,h) end
   end
   b.DoClick=function() if state.possible[n] then send("answer",n) end end
   if b.SetTooltip then b:SetTooltip("Указать обрыв: "..(i-1).." → "..i) end
  end
  label(body,"«Цепь есть» исключает проверенные участки. «Обрыв» означает, что неисправность между щупами. Серые провода уже исключены.")
  label(body,"ЖУРНАЛ ЗАМЕРОВ",true)
  if #(state.probes or {})==0 then label(body,"Измерений пока нет.") end
  for _,probe in ipairs(state.probes or {}) do label(body,string.format("%d → %d: %s",probe.a,probe.b,probe.result=="closed" and "цепь есть" or "обрыв")) end
 elseif data.kind=="pressure" then
  label(body,"Поверните вентили: ЛКМ — на шаг вперёд, ПКМ — назад. Проверьте давление и найдите настройки, которые дают показание в допуске.")
  label(body,string.format("ДОПУСК %d–%d · Показание: %s · Проверок: %d",state.lo,state.hi,tostring(state.reading or "—"),state.runs),true)
  if state.hint then label(body,"Вентиль "..tostring(state.hint)..(state.hintUp and " повышает давление." or " понижает давление.")) end
  local values=table.Copy(state.valves)
  local manifold=body:Add("DPanel");manifold:Dock(TOP);manifold:SetTall(240);manifold:DockMargin(0,0,0,14)
  manifold.Paint=function(_,w,h)
   H.Plate(w,h,"generator");local c=H.skins.generator
   surface.SetDrawColor(c.edge);surface.DrawRect(28,39,w-56,7)
   for i=1,3 do surface.DrawRect((i-.5)*w/3-4,41,8,23) end
   H.Text("РЕГУЛИРОВОЧНЫЙ КОЛЛЕКТОР","FacilityPlate",18,17,c.text,w-36)
   H.Text("ДОПУСК "..state.lo.."–"..state.hi.." / ТЕКУЩЕЕ "..tostring(state.reading or "—"),"FacilityText",24,194,c.accent,w-48)
  end
  local valves={};manifold.PerformLayout=function(_,w) for i,b in ipairs(valves) do b:SetPos((i-.5)*w/3-48,48);b:SetSize(96,125) end end
  for i=1,3 do local n=i
   local valve=manifold:Add("DButton");valves[i]=valve;valve.facilityValve=i;valve:SetText("")
   valve.Paint=function(s,w,h)
    local c=H.skins.generator;local a=math.rad(-135+values[n]*67.5)
    draw.RoundedBox(36,12,3,72,72,Color(27,28,24));surface.DrawCircle(48,39,35,c.edge)
    surface.SetDrawColor(s:IsHovered() and c.text or c.accent)
    for offset=-3,3 do surface.DrawLine(48+offset,39,48+math.sin(a)*27+offset,39-math.cos(a)*27) end
    H.Lamp(48,39,true,c.accent)
    draw.SimpleText("ВЕНТИЛЬ "..n,"FacilityPlate",48,83,c.text,TEXT_ALIGN_CENTER)
    draw.SimpleText(values[n].." / 4","FacilityText",48,105,c.accent,TEXT_ALIGN_CENTER)
   end
   valve.DoClick=function() values[n]=math.min(4,values[n]+1) end
   valve.DoRightClick=function() values[n]=math.max(0,values[n]-1) end
  end
  F.Button(body,"Проверить давление",function() send("run",ix.repair.games.pressure.Pack(values)) end)
  for _,row in ipairs(state.history or {}) do label(body,table.concat(row.valves," / ").." → "..row.reading.." · "..(verdicts[row.verdict] or row.verdict)) end
 end
 F.Button(body,data.noParts and "Отменить · отвёртка сохраняется · запчасти не нужны" or "Отменить · сохранить инструменты и запчасти",function() close(true) end)
 if old and old.stage~=data.stage then surface.PlaySound("buttons/button15.wav") end
end
local function aimed()
 if not session or session.kind~="bolts" then return end
 local entity=Entity(session.entity);local points=F.EngineeringBolts(entity,session.state)
 local best,distance
 for i,pos in ipairs(points) do local point=pos:ToScreen()
  local d=(point.x-ScrW()/2)^2+(point.y-ScrH()/2)^2
  if point.visible and d<70^2 and (not distance or d<distance) then best,distance=i,d end
 end
 return best,points
end
hook.Add("HUDPaint","ixFacilityEngineeringBolts",function()
 if not session or session.kind~="bolts" then return end
 local index,points=aimed();local state=session.state
 for i,pos in ipairs(points or {}) do local p=pos:ToScreen()
  if p.visible then
   surface.SetDrawColor(state.tight[i] and accent or i==index and Color(255,208,100) or ink)
   surface.DrawOutlinedRect(p.x-10,p.y-10,20,20,2);draw.SimpleText(i,"FacilityText",p.x,p.y-29,ink,TEXT_ALIGN_CENTER)
  end
 end
 local x,y=ScrW()/2,ScrH()*.8
 draw.SimpleText("КРЕПЁЖ · ЭТАП "..session.stage.." / 5","FacilityTitle",x,y,accent,TEXT_ALIGN_CENTER)
 draw.SimpleText("Наведите на болт. Удерживайте ЛКМ и отпустите в зелёной зоне. Затягивайте накрест.","FacilityText",x,y+28,ink,TEXT_ALIGN_CENTER)
 draw.SimpleText((verdicts[session.message] or session.message or "").." · ПКМ: отмена","FacilityText",x,y+54,ink,TEXT_ALIGN_CENTER)
 local band=(state.band or {})[held or index]
 if band then
  surface.SetDrawColor(20,35,44,240);surface.DrawRect(x-150,y+85,300,18)
  surface.SetDrawColor(accent);surface.DrawRect(x-150+300*band.lo,y+85,300*(band.hi-band.lo),18)
  if heldAt then surface.SetDrawColor(ink);surface.DrawRect(x-150+300*math.Clamp((CurTime()-heldAt)/state.torqueTime,0,1),y+79,3,30) end
 end
end)
hook.Add("PlayerBindPress","ixFacilityEngineeringBolts",function(_,bind,pressed)
 if not session or session.kind~="bolts" then return end
 if bind:find("attack2",1,true) then if pressed then close(true) end;return true end
 if bind:find("attack",1,true) then
  if pressed then local i=aimed();if i and not session.state.tight[i] then held=i;heldAt=CurTime();send("hold",i) end
  elseif held then send("release",held);held=nil;heldAt=nil end
  return true
 end
end)
hook.Add("Think","ixFacilityEngineeringLifetime",function()
 if session and held and not input.IsMouseDown(MOUSE_LEFT) then send("release",held);held=nil;heldAt=nil end
 if session and (not IsValid(Entity(session.entity)) or not LocalPlayer():Alive() or CurTime()>session.expires or gui.IsGameUIVisible()) then close(true) end
end)
hook.Add("ShutDown","ixFacilityEngineeringCleanup",function() close(false) end)
