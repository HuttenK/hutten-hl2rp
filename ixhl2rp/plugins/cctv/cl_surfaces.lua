local P,C=PLUGIN,ix.CCTV
local D=C.Desk;local colors=D.colors
local function label(parent,text,h)
 local p=parent:Add("DLabel");p:Dock(TOP);p:DockMargin(0,0,0,8);p:SetTall(h or 30)
 p:SetFont("ixCCTVBody");p:SetText(text);p:SetTextColor(colors.muted);p:SetWrap(true);return p
end
local function button(parent,text,callback)
 local b=parent:Add("DButton");b:Dock(TOP);b:DockMargin(0,0,0,6);b:SetTall(36);b:SetText("");b:SetTooltip(text)
 b.Paint=function(self,w,h) D.Key(self,w,h,text) end
 b.DoClick=callback;return b
end
function P:OpenSurfaceEditor(id)
 local d=self.devices[id];if not LocalPlayer():IsAdmin() or not d or not d.surface then return end
 self:CloseTerminalUI();self:EndPlacement()
 if IsValid(self.window) then self.window:Remove() end
 local f=vgui.Create("DFrame");self.window=f
 f:SetSize(480,math.min(ScrH()-40,940));f:SetPos(ScrW()-500,20);f:SetTitle("");f:MakePopup();f:DockPadding(18,78,18,18)
 D.Close(f,480)
 f.Paint=function(_,w,h) D.Shell(w,h,"КАЛИБРОВКА ПУЛЬТА","CCTV / МОНТАЖ ЭКРАНА") end
 f.status=label(f,"Изменения видны на prop. Нажмите «Сохранить экран».",48);f.status:Dock(BOTTOM);f.status:DockMargin(0,10,0,0)
 local scroll=f:Add("DScrollPanel");scroll:Dock(FILL)
 local preview={};for k,v in pairs(d) do preview[k]=v end
 preview.config=table.Copy(d.config);preview.preview=true;self.editSurface=preview
 f.OnRemove=function() P.editSurface=nil;P.nextInterest=0 end
 f.OnKeyCodePressed=function(_,key) if key==KEY_ESCAPE then f:Remove() end end
 f.Think=function() if not LocalPlayer():IsAdmin() or not P.devices[id] then f:Remove() end end
 button(scroll,"‹ Все устройства CCTV",function() P:OpenAdminUI(0) end)
 local name=scroll:Add("DTextEntry");name:Dock(TOP);name:SetTall(36);name:DockMargin(0,0,0,10);name:SetFont("ixCCTVBody");name:SetText(d.name)
 D.Entry(name)
 name.OnValueChange=function(_,v) preview.name=v end
 local enabled=scroll:Add("DCheckBoxLabel");enabled:Dock(TOP);enabled:SetTall(30);enabled:SetText("Экран включён");enabled:SetTextColor(colors.text);enabled:SetValue(d.on)
 enabled.OnChange=function(_,v) preview.on=v end
 D.Group(scroll,"КРЕПЛЕНИЕ / ПОЛОЖЕНИЕ И РАЗМЕР")
 local cfg=preview.config;local controls={};local fine=true
 local function limits(key)
  if key=="w" or key=="h" then return 1,1024,2 end
  if key=="p" or key=="yaw" or key=="r" then return -360,360,10 end
  return -4096,4096,2
 end
 local function setRange(slider,value)
  local low,high,radius=limits(slider.cctvField);slider.cctvUpdating=true
  slider:SetMinMax(fine and math.max(low,value-radius) or low,fine and math.min(high,value+radius) or high)
  slider:SetValue(value);slider.cctvUpdating=false
 end
 local function setField(key,value)
  local low,high=limits(key);value=tonumber(value)
  if not value or value~=value or math.abs(value)==math.huge then return end
  cfg[key]=math.Clamp(value,low,high);setRange(controls[key],cfg[key]);P.nextInterest=0
 end
 local precision=scroll:Add("DCheckBoxLabel");precision:Dock(TOP);precision:SetTall(28)
 precision:SetText("Точная настройка");precision:SetTextColor(colors.accent);precision:SetValue(true)
 precision.OnChange=function(_,v) fine=v;for key,slider in pairs(controls) do setRange(slider,cfg[key]) end end
 label(scroll,"Диапазон ±2 ед. / ±10°. Кнопки −/+ : 0,1; с Shift — 0,01. Значения можно вводить вручную.",60)
 button(scroll,"Центрировать диапазоны",function() for key,slider in pairs(controls) do setRange(slider,cfg[key]) end end)
 local names={x="X · вперёд",y="Y · вбок",z="Z · высота",p="Наклон",yaw="Поворот",r="Крен",w="Ширина",h="Высота"}
 for _,key in ipairs(C.surfaceFields) do
  local field=key;local row=scroll:Add("DPanel");row:Dock(TOP);row:SetTall(42);row.Paint=function() end
  for _,n in ipairs({1,-1}) do
   local step=n;local b=row:Add("DButton");b:Dock(RIGHT);b:DockMargin(3,6,0,6);b:SetWide(26);b:SetText(step>0 and "+" or "−")
   b:SetTooltip(names[field]..(step>0 and " +" or " −"))
   b.DoClick=function() setField(field,math.Round(cfg[field]+step*((input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)) and .01 or .1),2)) end
  end
  local slider=row:Add("DNumSlider");slider:Dock(FILL);slider:SetText(names[field]);slider:SetDecimals(2);slider.cctvField=field
  D.Slider(slider);slider.OnValueChanged=function(self,v) if not self.cctvUpdating then cfg[field]=v;P.nextInterest=0 end end
  controls[field]=slider;setRange(slider,cfg[field])
 end
 button(scroll,"Пропорции интерфейса CCTV",function() setField("h",cfg.w*C.terminalHeight/C.terminalWidth) end)
 button(scroll,"Сохранить экран",function() P:Request("configure",{id=id,name=name:GetValue(),on=enabled:GetChecked(),config=cfg}) end)
 button(scroll,"Сохранить размещение для модели",function() P:Request("surfacePreset",{id=id,config=cfg}) end)
 button(scroll,"Загрузить пресет модели",function()
  local preset=P.surfacePresets[d.model]
  if not preset then f.status:SetText("Для этой модели ещё нет пресета.");return end
  for _,key in ipairs(C.surfaceFields) do setField(key,preset[key]) end
 end)
 button(scroll,"Перенести экран на другой prop",function() P:BeginPlacement("terminal",id) end)
 button(scroll,"Добавить ещё один экран",function() P:BeginPlacement("terminal") end)
 button(scroll,"Открыть пульт",function() P:OpenTerminalUI(id) end)
 button(scroll,"Отменить изменения",function() P:OpenSurfaceEditor(id) end)
 button(scroll,"Удалить экран · оставить prop",function()
  Derma_Query("Удалить экран CCTV? Prop останется на месте.","CCTV","Удалить",function() P:Request("remove",{id=id}) end,"Отмена")
 end)
end

function P:UpdateSurfacePlacement(cmd)
 local left,right=cmd:KeyDown(IN_ATTACK),cmd:KeyDown(IN_ATTACK2)
 cmd:RemoveKey(IN_ATTACK);cmd:RemoveKey(IN_ATTACK2);cmd:RemoveKey(IN_RELOAD)
 if input.IsKeyDown(KEY_ESCAPE) or gui.IsGameUIVisible() then self:EndPlacement();return end
 if not left and not right then self.placeArmed=true end
 local reload=input.IsKeyDown(KEY_R)
 if reload and not self.surfaceReload then self.useSurfacePreset=not self.useSurfacePreset end;self.surfaceReload=reload
 local cfg,ent=C.SurfacePlacement(LocalPlayer(),LocalPlayer():GetEyeTrace())
 self.surfacePlacement=nil
 if cfg then
  if self.useSurfacePreset and not ix.PropScreens.Occupied(ent) and self.surfacePresets[ent:GetModel()] then cfg=table.Copy(self.surfacePresets[ent:GetModel()]) end
  self.surfacePlacement={id=self.replaceTerminal or 0,kind="terminal",surface=true,preview=true,on=true,
   model=ent:GetModel(),entity=ent,config=cfg,name="Новый экран CCTV"}
 end
 if not self.placeArmed then return end
 if right then self:EndPlacement();return end
 if left and self.surfacePlacement then
  local id,preset=self.replaceTerminal,self.useSurfacePreset;self:EndPlacement()
  self:Request("placeSurface",{id=id,preset=preset})
 end
end

hook.Add("HUDPaint","ixCCTVSurfaceGuide",function()
 local d=P.surfacePlacement or P.editSurface
 if not d or not IsValid(LocalPlayer()) or not LocalPlayer():IsAdmin() then return end
 local _,_,ent=C.Transform(d);if not IsValid(ent) then return end
 local tv=ix.plugin.list.tv_screen
 if tv and tv.PaintScreenPreview then
  -- Reuse the TV's clipped, two-sided HUD guide without changing TV state.
  local screen={entity=ent,model=d.model,config=d.config}
  tv.PaintScreenPreview({placement=P.surfacePlacement~=nil,placementPreview=screen,tvWindow=P.window,editPreview=screen})
 else
  local center,a,w,h=C.Screen(d);local x,y=a:Forward()*(w/2),a:Right()*(h/2)
  local corners={center-x-y,center+x-y,center+x+y,center-x+y}
  for i,v in ipairs(corners) do
   local first,last=v:ToScreen(),corners[i%4+1]:ToScreen()
   if first.visible and last.visible then surface.SetDrawColor(colors.accent);surface.DrawLine(math.Clamp(first.x,0,ScrW()),math.Clamp(first.y,0,ScrH()),math.Clamp(last.x,0,ScrW()),math.Clamp(last.y,0,ScrH())) end
  end
 end
end)
