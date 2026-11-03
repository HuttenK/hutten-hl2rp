local T=ix.Traits
local spoken={ic=true,w=true,y=true}
local words="[%a\128-\255]+"
local lisp={['с']='ш',['С']='Ш',['з']='ж',['З']='Ж',s='sh',S='Sh',z='zh',Z='Zh'}
local nonsense={"кочерыжка","шуршун","кривуля","бубенцы","хрямзик","пустяковина"}
function T.Speech(character,kind,text,random)
 if not spoken[kind] or not character then return text end
 random=random or math.random
 if T.Has(character,"lisping") then
  text=text:gsub("[%z\1-\127\194-\244][\128-\191]*",function(c) return lisp[c] or c end)
 end
 if T.Has(character,"stuttering") then
  local changed=0
  text=text:gsub(words,function(word)
   if changed>=3 or word:utf8len()<2 or random(1,100)>18 then return word end
   changed=changed+1
   return word:utf8sub(1,1).."-"..word
  end)
 end
 return text
end
function T.Hear(listener,speaker,kind,text,random)
 if not spoken[kind] or listener==speaker or not IsValid(listener) or not IsValid(speaker) then return text end
 if not T.Has(listener:GetCharacter(),"dull") then return text end
 local changed=0
 random=random or math.random
 return text:gsub(words,function(word)
  if changed>=2 or word:utf8len()<3 or random(1,100)>10 then return word end
  changed=changed+1
  return nonsense[random(1,#nonsense)]
 end)
end
