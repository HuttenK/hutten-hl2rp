ix.PlayerControls=ix.PlayerControls or {}
local K=ix.PlayerControls
K.actions={
 {key="animationMenuKey",default=KEY_J,command="ix_animation_menu"},
 {key="quickActionsKey",default=KEY_H,command="ix_radial"},
 {key="autoWalkKey",default=KEY_N,command="ix_autowalk"}
}
K.down={}
ix.lang.AddTable("ru",{
 ["playerControls"]="Управление / клавиши",
 ["option.animationMenuKey"]="Меню анимаций",
 ["option.quickActionsKey"]="Меню быстрых действий",
 ["option.autoWalkKey"]="Автоматическая ходьба",
 ["option.animationMenuKey.desc"]="Нажмите кнопку и нужную клавишу. Открывает все доступные позы и анимации. По умолчанию J.",
 ["option.quickActionsKey.desc"]="Нажмите кнопку и нужную клавишу. Радиальное меню предметов и взаимодействий. По умолчанию H.",
 ["option.autoWalkKey.desc"]="Нажмите кнопку и нужную клавишу. Включает/выключает ходьбу. Ручное движение останавливает её. По умолчанию N."
})
ix.lang.AddTable("en",{
 ["playerControls"]="Controls / key bindings",
 ["option.animationMenuKey"]="Animation menu",
 ["option.quickActionsKey"]="Quick actions menu",
 ["option.autoWalkKey"]="Automatic walking",
 ["option.animationMenuKey.desc"]="Click, then press a key. Opens available poses and animations. Default: J.",
 ["option.quickActionsKey.desc"]="Click, then press a key. Opens equipment and interaction actions. Default: H.",
 ["option.autoWalkKey.desc"]="Click, then press a key. Toggles automatic walking; manual movement cancels it. Default: N."
})
function K.ValidKey(key)
 return isnumber(key) and key==math.floor(key) and (key==0 or
  (key>0 and key<KEY_LAST and key~=KEY_ESCAPE and key~=KEY_TAB) or (key>=MOUSE_LEFT and key<=MOUSE_5))
end
function K.Down(key)
 if not K.ValidKey(key) or key==0 then return false end
 return key>=MOUSE_LEFT and input.IsMouseDown(key) or key<MOUSE_LEFT and input.IsKeyDown(key)
end
function K.CanUseHotkeys(allowRadial)
 local p=LocalPlayer()
 if not IsValid(p) or not p:Alive() or not p:GetCharacter() or gui.IsGameUIVisible() or input.IsKeyTrapping() then return false end
 if ix.menu.IsOpen() then return false end
 local focus=vgui.GetKeyboardFocus()
 if IsValid(focus) and (focus:GetClassName()=="TextEntry" or focus:GetName()=="DTextEntry" or focus:GetClassName()=="DTextEntry") then return false end
 if vgui.CursorVisible() and not (allowRadial and IsValid(ix.gui.charRadial)) then return false end
 return true
end
for _,spec in ipairs(K.actions) do
 ix.option.Add(spec.key,ix.type.number,spec.default,{category="playerControls",min=0,max=MOUSE_5,decimals=0,keybind=true,
  OnChanged=function(_,value)
   if not K.ValidKey(value) then ix.option.Set(spec.key,0); return end
   K.down[spec.key]=K.Down(value)
   if value~=0 then
    for _,other in ipairs(K.actions) do
     if other.key~=spec.key and ix.option.Get(other.key)==value then ix.option.Set(other.key,0) end
    end
   end
   if ix.StopAutoWalk then ix.StopAutoWalk() end
  end})
end
hook.Remove("Think","ixRadialHotkey")
hook.Add("Think","ixPlayerControlKeys",function()
 for _,spec in ipairs(K.actions) do
  local key=ix.option.Get(spec.key,spec.default)
  local down=K.Down(key); local pressed=down and not K.down[spec.key]; K.down[spec.key]=down
  if pressed and K.CanUseHotkeys(spec.command~="ix_autowalk") then
   -- A console bind already runs its command; never toggle twice on that press.
   local binding=input.LookupKeyBinding and input.LookupKeyBinding(key)
   if not binding or not binding:find(spec.command,1,true) then RunConsoleCommand(spec.command) end
  end
 end
end)
hook.Add("InitPostEntity","ixMigrateRadialKey",function()
 local legacy=GetConVar("ix_radial_default_h")
 if legacy and not legacy:GetBool() and ix.option.client.quickActionsKey==nil then ix.option.Set("quickActionsKey",0) end
end)

local ROW={}
function ROW:Init()
 self.setting=self:Add("DBinder"); self.setting:Dock(RIGHT); self.setting:SetWide(155)
 self.setting:SetFont("ixMenuButtonFont")
 self.setting.OnChange=function(_,key)
  if self.updating then return end
  if not K.ValidKey(key) then
   self:SetValue(ix.option.Get(self.key),true)
   LocalPlayer():Notify("Выберите клавишу или кнопку мыши; TAB и Escape зарезервированы.")
   return
  end
  self:OnValueChanged(key)
 end
 self.clear=self:Add("DButton"); self.clear:Dock(RIGHT); self.clear:SetWide(26); self.clear:DockMargin(4,0,4,0); self.clear:SetText("×")
 self.clear:SetTooltip("Снять назначение")
 self.clear.DoClick=function() self:SetValue(0); self:OnValueChanged(0) end
end
function ROW:Populate(key,info) self.key=key; self.setting:SetDefaultNumber(info.default) end
function ROW:SetValue(value)
 self.updating=true; self.setting:SetValue(value); self.updating=false
end
function ROW:GetValue() return self.setting:GetValue() end
function ROW:SetMin() end
function ROW:SetMax() end
function ROW:SetDecimals() end
function ROW:Think()
 if self.key and not self.setting.Trapping then
  local value=ix.option.Get(self.key)
  if value~=self:GetValue() then self:SetValue(value); self:SetShowReset(value~=ix.option.stored[self.key].default,self.key,ix.option.stored[self.key].default) end
 end
end
vgui.Register("ixSettingsRowKey",ROW,"ixSettingsRow")
