local W=ix.water
local C={bg=Color(226,232,230),paper=Color(249,250,244),ink=Color(33,56,62),blue=Color(40,112,145),muted=Color(84,103,106),edge=Color(156,173,174),warn=Color(134,77,24)}
local function modelText(value,width)
 surface.SetFont("WaterSmall")
 if surface.GetTextSize(value)<=width then return value end
 while #value>0 and surface.GetTextSize(value.."…")>width do value=value:sub(1,-2) end
 return value.."…"
end
local function label(parent,text,small)
 local p=parent:Add("DLabel");p:Dock(TOP);p:DockMargin(0,0,0,8);p:SetFont(small and "WaterSmall" or "WaterText");p:SetTextColor(C.ink);p:SetWrap(true);p:SetAutoStretchVertical(true);p:SetText(text);return p
end
local function button(parent,text,fn)
 local b=parent:Add("DButton");b:Dock(TOP);b:DockMargin(0,0,0,8);b:SetTall(38);b:SetText("")
 b.Paint=function(s,w,h)
  surface.SetDrawColor(s:IsHovered() and C.edge or C.paper);surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(C.edge);surface.DrawOutlinedRect(0,0,w,h)
  draw.SimpleText(text,"WaterText",12,h/2,C.ink,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 b.DoClick=fn;return b
end
function W.RegistryRequest(action,path,kind)
 net.Start("ixWaterRegistryRequest");net.WriteUInt(action,2)
 if action~=0 then net.WriteString(path or "");net.WriteBool(kind=="toilet") end
 net.SendToServer()
end
function W.OpenAdmin(message)
 if not IsValid(LocalPlayer()) or not LocalPlayer():IsAdmin() then return end
 local draft,kind="","sink"
 if IsValid(W.adminMenu) and IsValid(W.adminMenu.modelEntry) then draft=W.adminMenu.modelEntry:GetValue();kind=W.adminMenu.sourceKind or kind end
 if IsValid(W.adminMenu) then W.adminMenu:Remove() end
 local win=vgui.Create("DFrame");W.adminMenu=win
 win:SetSize(math.min(740,ScrW()-30),math.min(760,ScrH()-30));win:Center();win:SetTitle("");win:ShowCloseButton(false);win:SetDraggable(false);win:DockPadding(20,76,20,18);win:MakePopup()
 win.Paint=function(_,w,h)
  surface.SetDrawColor(C.bg);surface.DrawRect(0,0,w,h);surface.SetDrawColor(C.edge);surface.DrawOutlinedRect(0,0,w,h)
  draw.SimpleText("ВОДОПРОВОД / МОДЕЛИ","WaterTitle",20,15,C.ink)
  draw.SimpleText("РЕЕСТР ОБОРУДОВАНИЯ · АДМИНИСТРАТОР","WaterSmall",21,46,C.muted)
 end
 local close=button(win,"×",function() win:Remove() end);close:Dock(NODOCK);close:SetSize(40,36);close:SetPos(win:GetWide()-56,15)
 win.OnKeyCodePressed=function(s,key) if key==KEY_ESCAPE then s:Remove() end end
 win.OnRemove=function(s) if W.adminMenu==s then W.adminMenu=nil end end
 local think=win.Think
 win.Think=function(s) if think then think(s) end;if not IsValid(LocalPlayer()) or not LocalPlayer():IsAdmin() then s:Remove() end end
 local scroll=win:Add("DScrollPanel");scroll:Dock(FILL)
 label(scroll,message or "Модели действуют на всех картах.")
 label(scroll,"Умывальник: чистая вода. Унитаз: питьё из бачка вызывает радиацию. Набранная в ёмкость вода остаётся обычной.",true)
 local entry=scroll:Add("DTextEntry");win.modelEntry=entry;win.sourceKind=kind
 entry:Dock(TOP);entry:DockMargin(0,0,0,8);entry:SetTall(36);entry:SetFont("WaterText");entry:SetTextColor(C.ink);entry:SetText(draft);entry:SetUpdateOnType(true)
 entry.Paint=function(s,w,h)
  surface.SetDrawColor(C.paper);surface.DrawRect(0,0,w,h);surface.SetDrawColor(C.edge);surface.DrawOutlinedRect(0,0,w,h)
  if s:GetValue()=="" then draw.SimpleText("models/props_c17/example.mdl","WaterSmall",8,h/2,C.muted,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
  s:DrawTextEntryText(C.ink,C.blue,C.ink)
 end
 entry.OnTextChanged=function(s) local text=s:GetValue();if #text>180 then s:SetText(text:sub(1,180)) end end
 local combo=scroll:Add("DComboBox");combo:Dock(TOP);combo:SetTall(36);combo:DockMargin(0,0,0,8);combo:SetText("");combo:AddChoice("Умывальник","sink");combo:AddChoice("Унитаз","toilet")
 combo.Paint=function(_,w,h)
  surface.SetDrawColor(C.paper);surface.DrawRect(0,0,w,h);surface.SetDrawColor(C.edge);surface.DrawOutlinedRect(0,0,w,h)
  draw.SimpleText(kind=="toilet" and "Унитаз" or "Умывальник","WaterText",10,h/2,C.ink,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 combo.OnSelect=function(s,_,_,value) kind=value;win.sourceKind=value;s:SetText("") end
 button(scroll,"Добавить / обновить модель",function() W.RegistryRequest(1,entry:GetValue(),kind) end)
 button(scroll,"Добавить проп перед вами",function() W.RegistryRequest(2,"",kind) end)
 label(scroll,"ЗАРЕГИСТРИРОВАННЫЕ МОДЕЛИ",true)
 for model,source in SortedPairs(W.models) do
  local row=scroll:Add("DPanel");row:Dock(TOP);row:SetTall(104);row:DockMargin(0,0,0,7);row:DockPadding(12,9,110,6)
  row.Paint=function(_,w,h) surface.SetDrawColor(C.paper);surface.DrawRect(0,0,w,h);surface.SetDrawColor(source=="toilet" and C.warn or C.blue);surface.DrawRect(0,0,3,h) end
  label(row,(source=="toilet" and "УНИТАЗ" or "УМЫВАЛЬНИК")..(W.defaults[model] and " · встроенный" or " · добавленный"),true)
  local path=row:Add("DPanel");path:Dock(TOP);path:SetTall(25);path:SetTooltip(model)
  path.Paint=function(_,w,h) draw.SimpleText(modelText(model,w),"WaterSmall",0,h/2,C.ink,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
  if not W.defaults[model] then
   local remove=button(row,"Удалить",function() W.RegistryRequest(3,model,source) end);remove:Dock(NODOCK);remove:SetWide(92)
   row.PerformLayout=function(_,w) remove:SetPos(w-102,20) end
  end
 end
 return win
end
net.Receive("ixWaterModels",function()
 local count=net.ReadUInt(8);if count>W.modelLimit then return end
 local models={}
 for _=1,count do
  local model=net.ReadString();local kind=net.ReadBool() and "toilet" or "sink"
  local path=W.ModelPath(model);if path then models[path]=kind end
 end
 W.ApplyModels(models)
 if IsValid(W.adminMenu) then W.OpenAdmin("Реестр обновлён.") end
end)
net.Receive("ixWaterRegistryAdmin",function() W.OpenAdmin(net.ReadString()) end)
hook.Add("InitPostEntity","ixWaterRegistrySync",function() W.RegistryRequest(0) end)
-- Also refresh after a client plugin reload; the server throttles the request.
timer.Simple(1,function() if IsValid(LocalPlayer()) then W.RegistryRequest(0) end end)
