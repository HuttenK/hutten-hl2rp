-- A private transport with the live /it renderer. With no explicit recipient
-- list it reaches nobody, even if another addon calls ix.chat.Send directly.
ix.chat.Register("itpm", {
 font="ixChatFontMe",
 deadCanChat=true,
 CanSay=function(_,speaker) return IsValid(speaker) and speaker:IsPlayer() and speaker:IsAdmin() end,
 CanHear=function() return false end,
 OnChatAdd=function(_,speaker,text,anonymous,data)
  local class=ix.chat.classes.it
  if class then return class:OnChatAdd(speaker,text,anonymous,data) end
  chat.AddText(Color(150,255,150),"** ",text)
 end
})

ix.command.Add("ItPM", {
 description="Отправить описание окружения только выбранному игроку.",
 adminOnly=true,
 bNoIndicator=true,
 arguments={ix.type.player,ix.type.text},
 argumentNames={"игрок","текст"},
 OnRun=function(_,client,target,text)
  if not SERVER then return end
  -- Enforce admin status at execution too, independent of CAMI overrides.
  if not IsValid(client) or not client:IsPlayer() or not client:IsAdmin() then return "Команда доступна только администраторам." end
  if not IsValid(target) or not target:IsPlayer() or not target:GetCharacter() then return "У выбранного игрока нет активного персонажа." end
  if not isstring(text) then return "Укажите текст описания." end
  text=string.Trim(text:gsub("[%c]"," "))
  if text=="" then return "Укажите текст описания." end
  if not ix.chat.Send(client,"itpm",text,true,{target}) then return "Сообщение не отправлено." end
  client:Notify("Описание окружения отправлено: "..target:Name()..".")
 end
})
