local F=ix.Fieldlink
function F.BuildMediaPage(panel,d,U)
 local Label,Field,Action,Row,Scale,C=U.Label,U.Field,U.Action,U.Row,U.Scale,U.C
 local body=panel.body
 local function image(id)
  local box=Row(body,360)
  box.Paint=function(_,w,h)
   local material=F.PhotoMaterial(id)
   surface.SetDrawColor(5,5,5,255); surface.DrawRect(0,0,w,h)
   if material then
    local iw=math.min(w,h*640/360); local ih=iw*360/640
    surface.SetDrawColor(255,255,255,255); surface.SetMaterial(material); surface.DrawTexturedRect((w-iw)/2,(h-ih)/2,iw,ih)
   else draw.SimpleText("ПОЛУЧЕНИЕ СНИМКА…","FieldlinkMono",w/2,h/2,C.muted,TEXT_ALIGN_CENTER) end
  end
 end
 if panel.page=="camera" then
  panel:Header("OPTICS / MONOCHROME","Полевая камера","Снимки и распознавание предъявленного CID.")
  Label(body,"ЛКМ — сделать снимок. ПКМ — вернуться в приложения. В режиме съёмки можно свободно осматриваться и двигаться.","Heading",C.text)
  Label(body,"Распознавание: наведите центр кадра на человека рядом. Считывается только экипированная действующая CID-карта; скрытая личность персонажа не раскрывается.","Body",C.muted)
  Label(body,#(d.photos or {}).." / "..F.photoLimit.." снимков на устройстве","Mono",C.muted)
  Action(body,"Включить камеру",function() F.SetCamera(true) end)
  Action(body,"Открыть галерею",function() panel:Navigate("gallery") end)
 elseif panel.page=="gallery" then
  panel:Header("LOCAL / PHOTO STORAGE","Галерея",#(d.photos or {}).." / "..F.photoLimit.." снимков. Сохранённые фотографии передаются вместе с КПК.")
  Action(body,"Новый снимок",function() F.SetCamera(true) end)
  if #(d.photos or {})==0 then Label(body,"Альбом пуст.","Body",C.muted) end
  for _,photo in ipairs(d.photos or {}) do
   local p=photo
   Action(body,os.date("%d.%m / %H:%M:%S",p.time).." — "..p.name,function() panel.photo=p.id; panel:Navigate("photo") end)
  end
 elseif panel.page=="photo" then
  panel:Header("PHOTO / MONO","Просмотр снимка")
  if not panel.photo then panel:Navigate("gallery"); return true end
  image(panel.photo)
  Action(body,"Поделиться снимком",function() panel.compose={photo=panel.photo}; panel:Navigate("compose") end)
  local inAlbum=false
  for _,photo in ipairs(d.photos or {}) do if photo.id==panel.photo then inAlbum=true end end
  if inAlbum then Action(body,"Удалить из альбома",function() if F.Request("deletePhoto",{id=panel.photo}) then panel:Navigate("gallery") end end) end
  Action(body,"В галерею",function() panel:Navigate("gallery") end)
 elseif panel.page=="messenger" then
  panel:Header("COMMS / STORE & FORWARD","Связь","Ваш адрес: FL-"..d.device.." / "..d.name)
  Action(body,"Написать сообщение",function() panel.compose={}; panel:Navigate("compose") end)
  Label(body,"Сообщения доставляются на устройство, даже если владелец не в сети. История: последние 40 входящих и исходящих записей.","Small",C.muted)
  for _,message in ipairs(d.messages or {}) do
   local m=message; local outgoing=m.from==d.device
   Action(body,(outgoing and "→ "..m.recipient or "← "..m.name).." / "..os.date("%d.%m %H:%M",m.time)..(m.photo and "  [ФОТО]" or ""),function() panel.message=m.id; panel:Navigate("message") end)
  end
  if #(d.messages or {})==0 then Label(body,"Сообщений пока нет.","Body",C.muted) end
 elseif panel.page=="message" then
  local message
  for _,m in ipairs(d.messages or {}) do if m.id==panel.message then message=m end end
  if not message then panel:Navigate("messenger"); return true end
  panel:Header("MESSAGE / "..message.id,message.name.." → "..message.recipient,"FL-"..message.from.." → FL-"..message.to.." / "..os.date("%d.%m %H:%M",message.time))
  Label(body,message.text,"Body",C.text)
  if message.photo then
   image(message.photo)
   Action(body,"Сохранить фото в галерею",function() F.Request("savePhoto",{id=message.photo}) end)
   Action(body,"Переслать фото",function() panel.compose={photo=message.photo}; panel:Navigate("compose") end)
  end
  Action(body,"Ответить",function() panel.compose={target=tostring(message.from==d.device and message.to or message.from)}; panel:Navigate("compose") end)
  Action(body,"Удалить сообщение",function() if F.Request("deleteMessage",{id=message.id}) then panel:Navigate("messenger") end end)
 elseif panel.page=="compose" then
  panel.compose=panel.compose or {}; local draft=panel.compose
  panel:Header("COMMS / OUTGOING","Новое сообщение","Отправитель: "..d.name.." / FL-"..d.device)
  local target=Field(body,"АДРЕС КПК / ЧИСЛО ПОСЛЕ FL-","Например: 101",false,draft.target or "")
  target.OnValueChange=function(_,v) draft.target=v end
  local text=Field(body,"СООБЩЕНИЕ / ДО 600 СИМВОЛОВ","",true,draft.text or "")
  text.OnValueChange=function(_,v) draft.text=v end
  Label(body,draft.photo and "Вложение: монохромный снимок" or "Вложения нет","Mono",C.muted)
  Action(body,"Выбрать фото из галереи",function() panel:Navigate("attach") end)
  if draft.photo then Action(body,"Убрать вложение",function() draft.photo=nil; panel:BuildPage() end) end
  Action(body,"Отправить",function()
   if not tonumber(draft.target) or (not F.Text(draft.text or "",600) and not draft.photo) then panel.toast="Укажите адрес и текст или снимок."; F.Sound("error"); return end
   if F.Request("message",{target=tonumber(draft.target),text=draft.text or "",photo=draft.photo}) then panel.toast="Отправка…" end
  end)
  Label(body,"Устройства в сети","Heading",C.text)
  for _,contact in ipairs(d.contacts or {}) do local c=contact
   Action(body,c.name.." / CID "..c.cid.." / FL-"..c.device,function() draft.target=tostring(c.device); panel:BuildPage() end)
  end
 elseif panel.page=="attach" then
  panel:Header("COMMS / ATTACHMENT","Выбор снимка")
  for _,photo in ipairs(d.photos or {}) do local p=photo
   Action(body,os.date("%d.%m %H:%M:%S",p.time),function() panel.compose=panel.compose or {}; panel.compose.photo=p.id; panel:Navigate("compose") end)
  end
  Action(body,"Назад к сообщению",function() panel:Navigate("compose") end)
 else return false end
 return true
end
