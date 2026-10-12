local P=PLUGIN
net.Receive('ix610Control',function()
 local data=net.ReadTable();local revision=net.ReadUInt(31);local growth=net.ReadUInt(16);local npcs=net.ReadUInt(16)
 if not LocalPlayer():IsAdmin() then return end
 if IsValid(P.controlFrame) then P.controlFrame:Remove() end
 local f=vgui.Create('DFrame');P.controlFrame=f;f:SetSize(720,math.min(820,ScrH()-80));f:Center();f:SetTitle('SCP-610 / Контроль заражения');f:MakePopup()
 local info=f:Add('DLabel');info:Dock(TOP);info:SetTall(56);info:SetText('Биомасса: '..growth..' / Подвижные SCP-610: '..npcs..'\nЛимиты останавливают новое размножение. Уже созданные NPC сохраняются.\nАдминистративный спавн вручную разрешён сверх лимита.')
 local save=f:Add('DButton');save:Dock(BOTTOM);save:SetTall(44);save:SetText('Сохранить параметры')
 local scroll=f:Add('DScrollPanel');scroll:Dock(FILL)
 local widgets={}
 for key,rule in SortedPairs(P.settingRules) do
  if isbool(rule[1]) then
   local w=scroll:Add('DCheckBoxLabel');w:Dock(TOP);w:SetTall(34);w:SetText(rule[2]);w:SetValue(data[key] and 1 or 0);widgets[key]=w
  else
   local w=scroll:Add('DNumSlider');w:Dock(TOP);w:SetTall(48);w:SetText(rule[2]);w:SetMin(rule[3]);w:SetMax(rule[4]);w:SetDecimals(key=='fireHealthFraction' and 2 or 0);w:SetValue(data[key]);widgets[key]=w
  end
 end
 save.DoClick=function()
  local values={};for key,w in pairs(widgets) do if isbool(P.settingRules[key][1]) then values[key]=w:GetChecked() else values[key]=w:GetValue() end end
  net.Start('ix610Save');net.WriteString(util.TableToJSON(values));net.WriteUInt(revision,31);net.SendToServer();f:Remove()
 end
end)
