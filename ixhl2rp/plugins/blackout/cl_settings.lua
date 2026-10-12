local PLUGIN=PLUGIN

function PLUGIN:OpenAreaHeight(id,info)
 if IsValid(self.heightEditor) then self.heightEditor:Remove() end
 local frame=vgui.Create("DFrame");self.heightEditor=frame
 frame:SetTitle(id.." — высота зоны");frame:SetSize(560,290)
 frame:SetPos(math.max(16,ScrW()-580),math.max(16,ScrH()*.3));frame:MakePopup()
 local hint=frame:Add("DLabel");hint:Dock(TOP);hint:SetTall(44);hint:SetWrap(true)
 hint:SetText("Меняются только пол и потолок. Z — высота в мире.\nКнопки: шаг 16 ед.; стрелки у числа: 1 ед. Можно ввести точное значение.")
 local function boundary(title,value)
  local row=frame:Add("DPanel");row:Dock(TOP);row:SetTall(40);row:DockMargin(0,4,0,0);row.Paint=nil
  local label=row:Add("DLabel");label:Dock(LEFT);label:SetWide(240);label:SetText(title)
  local input=row:Add("DNumberWang");input:Dock(LEFT);input:SetWide(130)
  input:SetMinMax(-32768,32768);input:SetDecimals(2);input:SetInterval(1);input:SetValue(value)
  for _,step in ipairs({-16,16}) do
   local button=row:Add("DButton");button:Dock(LEFT);button:DockMargin(6,0,0,0);button:SetWide(62)
   button:SetText(step<0 and "−16" or "+16")
   button.DoClick=function() input:SetValue(input:GetValue()+step) end
  end
  return input
 end
 local lower=boundary("Нижняя граница (пол), Z",info.startPosition.z)
 local upper=boundary("Верхняя граница (потолок), Z",info.endPosition.z)
 local status=frame:Add("DLabel");status:Dock(TOP);status:SetTall(40)
 local footer=frame:Add("DPanel");footer:Dock(BOTTOM);footer:SetTall(32);footer.Paint=nil
 local save=footer:Add("DButton");save:Dock(RIGHT);save:SetWide(160);save:SetText("Применить")
 local cancel=footer:Add("DButton");cancel:Dock(RIGHT);cancel:SetWide(110);cancel:DockMargin(0,0,8,0);cancel:SetText("Отмена")
 cancel.DoClick=function() frame:Remove() end
 local function update()
  local low,high=lower:GetValue(),upper:GetValue()
  local valid=low==low and high==high and low>=-32768 and high<=32768 and high-low>=1
  save:SetEnabled(valid)
  status:SetText(valid and string.format("Высота: %.2f ед. · Голубая рамка — предпросмотр.",high-low) or "Потолок должен быть выше пола хотя бы на 1 ед. (Z: −32768…32768).")
  frame.heightPreview=valid and {min=Vector(info.startPosition.x,info.startPosition.y,low),max=Vector(info.endPosition.x,info.endPosition.y,high)} or nil
  return valid,low,high
 end
 lower.OnValueChanged=update;upper.OnValueChanged=update;update()
 save.DoClick=function()
  local valid,low,high=update();if not valid then return end
  net.Start("ixBlackoutHeight");net.WriteString(id);net.WriteFloat(low);net.WriteFloat(high);net.SendToServer()
  frame:Remove()
 end
 local previewColor=Color(90,225,255)
 hook.Add("PostDrawTranslucentRenderables","ixBlackoutHeightPreview",function(depth,sky,sky3d)
  if depth or sky or sky3d or not IsValid(frame) or not ix.area.bEditing or (ix.CCTV and ix.CCTV.rendering) then return end
  local preview=frame.heightPreview
  if preview then render.DrawWireframeBox(vector_origin,angle_zero,preview.min,preview.max,previewColor,true) end
 end)
 frame.OnRemove=function()
  hook.Remove("PostDrawTranslucentRenderables","ixBlackoutHeightPreview")
  if PLUGIN.heightEditor==frame then PLUGIN.heightEditor=nil end
 end
end

function PLUGIN:AreaEditShowOptions(id,info)
 if not info or info.type~="blackout" then return end
 local menu=DermaMenu()
 menu:AddOption("Настроить затемнение",function()
  local frame=vgui.Create("DFrame");frame:SetTitle(id.." — затемнение")
  frame:SetSize(510,220);frame:Center();frame:MakePopup()
  local text=frame:Add("DLabel");text:Dock(TOP);text:SetTall(32)
  text:SetText("0% — без затемнения; 100% — чёрный. Границы зоны сохраняются.")
  local function slider(title,maximum,value)
   local p=frame:Add("DNumSlider");p:Dock(TOP);p:SetTall(46)
   p:SetText(title);p:SetMin(0);p:SetMax(maximum);p:SetDecimals(0);p:SetValue(value)
   return p
  end
  local darkness=slider("Затемнение, %",100,info.properties.blackoutDarkness or 86)
  local softness=slider("Плавная граница, ед.",128,info.properties.blackoutSoftness or 24)
  local save=frame:Add("DButton");save:Dock(BOTTOM);save:SetTall(32);save:SetText("Применить")
  save.DoClick=function()
   net.Start("ixBlackoutAppearance");net.WriteString(id)
   net.WriteUInt(math.Clamp(math.Round(darkness:GetValue()),0,100),7)
   net.WriteUInt(math.Clamp(math.Round(softness:GetValue()),0,128),8);net.SendToServer()
   frame:Remove()
  end
 end):SetIcon("icon16/weather_clouds.png")
 menu:AddOption("Изменить высоту",function()
  self:OpenAreaHeight(id,info)
 end):SetIcon("icon16/arrow_up.png")
 menu:AddOption("Удалить зону",function()
  Derma_Query(L("areaDeleteConfirm",id),L("areaDelete"),L("no"),nil,L("yes"),function()
   net.Start("ixAreaRemove");net.WriteString(id);net.SendToServer()
  end)
 end):SetIcon("icon16/delete.png")
 menu:Open(ScrW()*.5,ScrH()*.5)
 return true
end
