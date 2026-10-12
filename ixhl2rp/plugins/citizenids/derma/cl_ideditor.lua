local PANEL={}
function PANEL:Init()
 local data=ix.gui.idEditorItem or {}
 local card=ix.gui.idEditorKeycard
 local U=ix.Legends
 self:SetSize(math.min(540,ScrW()-32),math.min(750,ScrH()-32)); self:Center(); self:MakePopup()
 self:SetTitle(""); self:ShowCloseButton(false); self:SetScreenLock(true)
 self:DockPadding(24,92,24,24)
 self.Paint=function(_,w,h)
  U.Plate(0,0,w,h,U.panel,U.accent)
  U.Text("REGISTRY / ADMINISTRATION","Mono",24,20,U.muted)
  U.Text(card and "РЕЕСТР ДОПУСКА" or "ЛИЧНЫЕ ДАННЫЕ","Title",24,43)
 end
 local close=U.Button(self,"X",function() self:Close() end); close:SetSize(40,30); close:SetPos(self:GetWide()-64,20)
 local save=U.Button(self,"СОХРАНИТЬ ИЗМЕНЕНИЯ",function()
  local out={}
  for key,entry in pairs(self.fields) do out[key]=entry:GetValue() end
  netstream.Start("ixCitizenIDEdit",ix.gui.idEditorItemID,out); self:Close()
 end); save:Dock(BOTTOM); save:SetTall(44)
 local scroll=U.Scroll(self); scroll:Dock(FILL); scroll:DockMargin(0,0,0,14)
 U.Label(scroll,"Серийный номер: "..(data.number or "—"),"Mono",U.muted)
 local photoRow=scroll:Add("DPanel"); photoRow:Dock(TOP); photoRow:SetTall(190); photoRow:DockMargin(0,0,0,16); photoRow.Paint=function() end
 local portrait=photoRow:Add("ixCredentialPortrait"); portrait:Dock(LEFT); portrait:SetWide(140); portrait:DockMargin(0,0,16,0); portrait:SetPortrait(data.portrait)
 local note=photoRow:Add("DPanel"); note:Dock(FILL); note.Paint=function() end
 U.Label(note,"ФОТО ПРИ РЕГИСТРАЦИИ","Mono",U.muted)
 U.Label(note,"Редактирование текста не меняет фотографию. Для нового снимка перерегистрируйте документ или ключ-карту.","Small",U.muted)
 local fields=card and {{"name","ФИО сотрудника"},{"cid","Табельный номер"},{"position","Должность / звание"},{"site","Объект / подразделение"},{"callsign","Позывной"},{"issued","Выдана"},{"expires","Действительна до"},{"authority","Орган выдачи"},{"restrictions","Ограничения доступа"}} or
 {{"name","Фамилия и имя"},{"birthDate","Дата рождения (ДД.ММ.ГГГГ)"},{"nationality","Гражданство"},{"sex","Пол"},{"issued","Дата выдачи"},{"expires","Действителен до"},{"authority","Кем выдан"}}
 self.fields={}
 for _,field in ipairs(fields) do
  U.Label(scroll,field[2],"Small",U.muted)
  local entry=scroll:Add("DTextEntry"); entry:Dock(TOP); entry:SetTall(34); entry:DockMargin(0,0,0,12)
  entry:SetText(data[field[1]] or ""); self.fields[field[1]]=entry
 end
end
vgui.Register("ixIDEditor",PANEL,"DFrame")
