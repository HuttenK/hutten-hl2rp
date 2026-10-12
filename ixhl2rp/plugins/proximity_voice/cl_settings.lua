local V=ix.voice
local function KeyChoices()
 local choices={[0]="Не назначена"}
 for key=1,KEY_LAST-1 do
  local name=input.GetKeyName(key)
  if name and key~=KEY_ESCAPE and key~=KEY_TAB then choices[key]=string.upper(name) end
 end
 return choices
end
ix.lang.AddTable("ru",{
 ["option.radioVoiceKey"]="Кнопка передачи по рации",
 ["option.radioVoiceKey.desc"]="Удерживайте выбранную кнопку для передачи на текущей частоте и рядом с вами. Рация должна быть включена. Не выбирайте кнопку обычного голосового чата.",
 ["option.radioInterference"]="Помехи при приёме рации",
 ["option.radioInterference.desc"]="Шум и колебания сигнала. 0 отключает эффект; голос рядом не изменяется.",
 ["radioVoice"]="Рация"
})
ix.lang.AddTable("en",{
 ["option.radioVoiceKey"]="Radio push-to-talk key",
 ["option.radioVoiceKey.desc"]="Hold to transmit on your selected radio channel and in proximity. Turn on your radio first. Choose a different key from normal voice chat.",
 ["option.radioInterference"]="Radio interference",
 ["option.radioInterference.desc"]="Receiver static and signal fluctuations. Set to 0 to disable. Proximity voice is unchanged.",
 ["radioVoice"]="Radio"
})
ix.option.Add("radioVoiceKey",ix.type.array,0,{category="radioVoice",populate=KeyChoices})
function V.OpenKeySettings()
 if IsValid(V.keyDialog) then V.keyDialog:MakePopup(); return end
 local frame=vgui.Create("DFrame")
 V.keyDialog=frame
 frame:SetTitle("Задать кнопку использования рации")
 frame:SetSize(450,180); frame:Center(); frame:MakePopup()
 local label=frame:Add("DLabel")
 label:Dock(TOP); label:SetTall(48); label:SetWrap(true)
 label:SetText("Нажмите на кнопку ниже, затем нужную клавишу. Удерживайте её для передачи. Выберите отдельную от обычного голосового чата клавишу.")
 local binder=frame:Add("DBinder")
 binder:Dock(TOP); binder:SetTall(36)
 binder:SetValue(ix.option.Get("radioVoiceKey",0))
 binder.OnChange=function(_,key)
  if not KeyChoices()[key] then
   binder:SetValue(ix.option.Get("radioVoiceKey",0))
   LocalPlayer():Notify("Выберите клавишу клавиатуры, кроме TAB и Escape.")
   return
  end
  ix.option.Set("radioVoiceKey",key)
 end
 local clear=frame:Add("DButton")
 clear:Dock(BOTTOM); clear:SetTall(28); clear:SetText("Снять назначение")
 clear.DoClick=function() ix.option.Set("radioVoiceKey",0); binder:SetValue(0) end
end

ix.option.Add("radioInterference",ix.type.number,.35,{category="radioVoice",min=0,max=1,decimals=2})
