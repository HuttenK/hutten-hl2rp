local S=ix.PoseStudio
local token=0
local sitNames={"Сидеть на стуле · 1","Сидеть на стуле · 2","Сидеть на стуле · 3","Сидеть на стуле · 4",
 "Сидеть на стуле · 5","Сидеть на стуле · 6","Сидеть · 7","Сидеть на земле","Сидеть у стены",
 "Сидеть · 8","Сидеть · 9","Осмотреть","Облокотиться · 1","Облокотиться · 2","Лежать · 1","Лежать · 2","Лежать · 3",
 "Под арестом","Стоять · 1","Стоять · 2","Стоять · 3","На земле","На сиденье","Сидеть: руки вперёд"}
local function category(label,children)
 return {label=label,children=#children>0 and children or nil,disabled=#children==0,detail=#children==0 and "Нет доступных для этой модели" or "Выберите анимацию"}
end
function S.OpenWheel(mode,page)
 S.CancelPlacement()
 local p=LocalPlayer()
 if not IsValid(p) or not p:Alive() or not p:GetCharacter() or gui.IsGameUIVisible() or ix.menu.IsOpen() then return end
 if IsValid(ix.gui.charRadial) then ix.gui.charRadial:Remove() end
 token=(token+1)%65536
 local panel=vgui.Create("ixCharRadialMenu")
 panel.character=LocalPlayer():GetCharacter(); panel.personal=true; panel.target=LocalPlayer(); panel.menuEntity=LocalPlayer()
 panel.centerName="АНИМАЦИИ"; panel.fullOptions={{label="Загрузка…",disabled=true}}; panel.page=1; panel:PageOptions()
 panel.poseToken=token; panel.poseRequested=RealTime(); ix.gui.charRadial=panel
 S.InstallWheelPreview(panel)
 S.Request({op="radial",token=token,mode=mode or "root",page=page or 1})
 timer.Simple(5,function()
  if IsValid(panel) and not panel.poseReady then
   panel.fullOptions={{label="Повторить загрузку",callback=function() S.OpenWheel(mode,page) end}}
   panel:PageOptions()
  end
 end)
end
function S.ReceiveRadial(data)
 local panel=ix.gui.charRadial
 if not IsValid(panel) or panel.poseToken~=data.token or LocalPlayer():GetModel()~=data.model then return end
 panel.poseReady=true
 local options={}
 if data.mode=="root" then
  local builtins,sits={},{}
  for _,act in ipairs(data.acts) do
   builtins[#builtins+1]={label=act.label,preview={kind="act",name=act.name,variant=act.variant},callback=function() S.OpenPlacement({kind="act",name=act.name,variant=act.variant},act.label) end}
  end
  for _,id in ipairs(data.sits) do
   sits[#sits+1]={label=sitNames[id] or "Поза "..id,preview={kind="sit",id=id},detail="ЛКМ: разместить / ПКМ: отменить",callback=function()
    S.OpenPlacement({kind="sit",id=id},sitNames[id] or "Поза")
   end}
  end
  options={category("Встроенные анимации",builtins),category("Позы с размещением",sits),
   {label="Мои анимации",callback=function() S.OpenWheel("own",1) end},
   {label="Общая библиотека",callback=function() S.OpenWheel("shared",1) end},
   {label="Редактор",callback=function() ix.command.Send("PoseEditor") end},
   {label="Остановить",callback=function() S.Request({op="stopAll"}) end}}
 else
  panel.centerName=(data.mode=="own" and "МОИ АНИМАЦИИ" or "ОБЩИЕ АНИМАЦИИ").."  "..data.page.."/"..data.pages
  for _,clip in ipairs(data.clips) do
   local available=clip.available~=false
   options[#options+1]={label=clip.name,disabled=not available,
    detail=not available and (clip.reason or "Анимация недоступна") or clip.mask=="upper" and "Верх тела · можно ходить" or clip.portable and "Совместимые гуманоиды · размещение" or "Размещение",
    preview=available and {kind="custom",id=clip.id} or nil,
    callback=function() if available then S.OpenPlacement({kind="custom",id=clip.id},clip.name) end end}
  end
  if #data.clips==0 then options[#options+1]={label="Здесь пока нет анимаций",disabled=true,detail=data.mode=="own" and "Сохраните анимацию в редакторе" or "Нет опубликованных анимаций"} end
  if data.page>1 then options[#options+1]={label="Предыдущие 24",callback=function() S.OpenWheel(data.mode,data.page-1) end} end
  if data.page<data.pages then options[#options+1]={label="Следующие 24",callback=function() S.OpenWheel(data.mode,data.page+1) end} end
  options[#options+1]={label="Главное меню",callback=function() S.OpenWheel("root",1) end}
 end
 panel.fullOptions=options; panel.page=1; panel:PageOptions()
end
concommand.Add("ix_animation_menu",function()
 if not ix.PlayerControls or not ix.PlayerControls.CanUseHotkeys(true) then return end
 if IsValid(ix.gui.charRadial) and ix.gui.charRadial.poseToken then ix.gui.charRadial:Remove(); return end
 S.OpenWheel("root",1)
end)
concommand.Add("+ix_animation_menu",function() RunConsoleCommand("ix_animation_menu") end)
concommand.Add("-ix_animation_menu",function() end)
