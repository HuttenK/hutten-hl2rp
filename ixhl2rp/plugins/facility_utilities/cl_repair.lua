local F=ix.Facility
local H=F.Hardware
local ink=Color(231,244,246);local muted=Color(158,190,198);local accent=Color(92,229,201)
local amber=Color(255,205,113)
function F.CloseRepair(silent)
 local win=F.repairWindow
 if IsValid(win) then win.silent=silent==true;win:Remove() end
end
function F.RepairPress(win)
 if not IsValid(win) or win.pending or win.finished or CurTime()<win.data.started then return false end
 win.pending=true;win.feedback:SetText("Проверка контакта…")
 net.Start("ixFacilityRepairInput");net.WriteUInt(win.data.token,32);net.WriteUInt(win.data.round,16);net.WriteBool(true);net.SendToServer()
 return true
end
function F.OpenRepair(data)
 if istable(data) and data.engineering and F.OpenEngineering then return F.OpenEngineering(data) end
 if not istable(data) or not F.Number(data.token,1,4294967295) then return end
 local win=F.repairWindow
 if data.result=="cancel" then if IsValid(win) and win.data.token==data.token then F.CloseRepair(true) end;return end
 if data.result=="complete" then
  if not IsValid(win) or win.data.token~=data.token then return end
  win.data=data;win.finished=true;win.pending=false;win.finishAt=RealTime()+1.3
  win.feedback:SetText(data.sabotage and "ГОТОВО · Все пять контактов разомкнуты." or "ГОТОВО · Все пять контактов восстановлены.");win.feedback:SetTextColor(accent)
  surface.PlaySound("buttons/button14.wav");return
 end
 if not F.Number(data.round,1,65535) or not F.Number(data.stage,1,F.repair.contacts) or not F.Number(data.target,.1,.9)
  or not isnumber(data.started) or not F.Number(data.period,1,20) or not F.Number(data.width,.05,.5) or not isstring(data.title) then return end
 if IsValid(win) and win.data.token==data.token then
  if data.round<win.data.round then return end
  win.data=data;win.pending=false
 else
  F.CloseRepair(true)
  if IsValid(F.window) then F.window:Remove() end
  if IsValid(F.helpWindow) then F.helpWindow:Remove() end
  win=vgui.Create("DFrame");F.repairWindow=win;win.data=data
  win:SetSize(math.min(760,ScrW()-40),math.min(610,ScrH()-40));win:Center();win:SetTitle(data.sabotage and "SCiPNET / ОТКЛЮЧЕНИЕ КОНТАКТОВ" or "SCiPNET / ВОССТАНОВЛЕНИЕ КОНТАКТОВ");win:MakePopup()
  H.Frame(win,"cabinet",data.sabotage and "ОТКЛЮЧЕНИЕ КОНТАКТОВ" or "ВОССТАНОВЛЕНИЕ КОНТАКТОВ",data.title)
  local body=win:Add("DScrollPanel");body:Dock(FILL);body:DockMargin(18,10,18,12)
  F.Label(body,"Нажмите ПРОБЕЛ или кнопку, когда бегунок войдёт в отмеченную зону. "..(data.sabotage and "Разомкните 5 контактов." or "Восстановите 5 контактов.").." Каждый этап быстрее, а зона уже.")
  local contacts=body:Add("DPanel");contacts:Dock(TOP);contacts:SetTall(72);contacts:DockMargin(0,4,0,16)
  contacts.Paint=function(_,w,h)
   local stage=win.data.stage;local gap=8;local size=(w-gap*(F.repair.contacts-1))/F.repair.contacts
   for i=1,F.repair.contacts do
    local x=(i-1)*(size+gap);local done=i<stage;local active=i==stage
    draw.RoundedBox(3,x,0,size,h,done and Color(44,75,56) or Color(35,43,36))
    surface.SetDrawColor(done and accent or active and amber or Color(50,77,85));surface.DrawOutlinedRect(x,0,size,h)
    H.Screw(x+8,8,muted);H.Screw(x+size-8,h-8,muted)
    draw.SimpleText("0"..i,"FacilityTitle",x+size/2,12,done and accent or ink,TEXT_ALIGN_CENTER)
    draw.SimpleText(done and "ГОТОВО" or active and "СЕЙЧАС" or "ДАЛЕЕ","FacilityText",x+size/2,43,done and accent or muted,TEXT_ALIGN_CENTER)
   end
  end
  local meter=body:Add("DPanel");meter:Dock(TOP);meter:SetTall(115);meter:DockMargin(0,0,0,12)
  meter.Paint=function(_,w,h)
   local state=win.data;local left,width=14,w-28
   local targetX=left+(state.target-state.width*.5)*width;local targetW=state.width*width
   H.Plate(w,h,"cabinet")
   draw.SimpleText(win.finished and (state.sabotage and "ЦЕПЬ РАЗОМКНУТА" or "ЦЕПЬ ВОССТАНОВЛЕНА") or ("ЭТАП "..state.stage.." / "..F.repair.contacts.." · ЗОНА КОНТАКТА"),"FacilityText",w/2,3,accent,TEXT_ALIGN_CENTER)
   draw.RoundedBox(3,left,38,width,40,Color(18,34,28))
   draw.RoundedBox(4,targetX,38,targetW,40,Color(38,114,94))
   surface.SetDrawColor(accent);surface.DrawOutlinedRect(targetX,38,targetW,40)
   for i=0,20 do surface.SetDrawColor(52,79,88);surface.DrawRect(left+width*i/20,86,1,i%5==0 and 12 or 6) end
   local position=win.finished and state.target or F.RepairPosition(CurTime(),state.started,state.period)
   local x=left+position*width
   surface.SetDrawColor(ink);surface.DrawRect(x-2,29,4,58)
   draw.NoTexture();surface.DrawPoly({{x=x-5,y=24},{x=x+5,y=24},{x=x,y=31}})
  end
  win.feedback=F.Label(body,"",false)
  F.Button(body,data.sabotage and "Разомкнуть контакт · ПРОБЕЛ" or "Замкнуть контакт · ПРОБЕЛ",function() F.RepairPress(win) end)
  F.Button(body,data.noParts and "Отмена · ESC" or "Отмена · ESC · сохранить запчасти",function() win:Remove() end)
  F.Label(body,data.noParts and "Промах повторяет текущий контакт. Отвёртка сохраняется, запчасти не нужны. Оставайтесь рядом с открытым щитком." or "Промах повторяет только текущий контакт. Запчасти расходуются после пятого успеха. Оставайтесь рядом.")
  win.lastSpace=input.IsKeyDown(KEY_SPACE)
  local baseThink=win.Think
  win.Think=function(s)
   if baseThink then baseThink(s) end
   if s.finished then if RealTime()>s.finishAt then F.CloseRepair(true) end;return end
   if gui.IsGameUIVisible() then s:Remove();return end
   local space=input.IsKeyDown(KEY_SPACE);local focus=vgui.GetKeyboardFocus()
   while IsValid(focus) and focus~=s do focus=focus:GetParent() end
   if space and not s.lastSpace and focus==s then F.RepairPress(s) end;s.lastSpace=space
  end
  win.OnKeyCodePressed=function(s,key) if key==KEY_ESCAPE then s:Remove() end end
  win.OnRemove=function(s)
   if not s.silent and not s.finished then
    net.Start("ixFacilityRepairInput");net.WriteUInt(s.data.token,32);net.WriteUInt(s.data.round,16);net.WriteBool(false);net.SendToServer()
   end
   if F.repairWindow==s then F.repairWindow=nil end
  end
 end
 win.feedback:SetText(data.message or "Дождитесь зоны и замкните контакт.")
 win.feedback:SetTextColor(data.result=="miss" and amber or data.result=="hit" and accent or muted)
 if data.result=="hit" then surface.PlaySound("buttons/button15.wav")
 elseif data.result=="miss" then surface.PlaySound("buttons/button10.wav") end
end
net.Receive("ixFacilityRepairState",function()
 local raw=net.ReadString();if #raw>4096 then return end
 F.OpenRepair(util.JSONToTable(raw))
end)
