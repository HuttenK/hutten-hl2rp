-- Only authoritative item/treatment callbacks emit these actions. Normal /me
-- delivery supplies proximity, character-name recognition and chat formatting.
local body={
 [1]={"свою голову","голову пациента"},
 [2]={"свою грудную клетку","грудную клетку пациента"},
 [3]={"свой живот","живот пациента"},
 [4]={"свою левую руку","левую руку пациента"},
 [5]={"свою правую руку","правую руку пациента"},
 [6]={"свою левую ногу","левую ногу пациента"},
 [7]={"свою правую ногу","правую ногу пациента"}
}
local injectors={morphine="Морфин",epinephrine="Адреналин",eft_propital="Пропитал",eft_etg="eTG-change",eft_l1="L1",eft_tg12="Загустин"}
local tablets={painkiller="Анальгин",eft_augmentin="Аугментин"}

local function itemName(item)
 -- Keep custom names on one chat line and exclude markup delimiters.
 return string.Trim(tostring(item:GetName() or "предмет"):gsub("[%c<>]"," ")):utf8sub(1,100)
end
local function emit(client,text)
 if IsValid(client) and client:GetCharacter() and client:Alive() then
  -- Automatic item actions must not earn conversation XP. Always clear the
  -- marker, even if a third-party chat hook fails during delivery.
  local previous=client.ixContextualEmote
  client.ixContextualEmote=true
  local ok,result=pcall(ix.chat.Send,client,"me",text)
  client.ixContextualEmote=previous
  if ok then return result end
  ErrorNoHalt("[Contextual emotes] "..tostring(result).."\n")
 end
end

hook.Add("MedicalTreatmentStarted","ixContextualMedical",function(client,session)
 if (client.ixNextMedicalEmote or 0)>CurTime() then return end
 local item,target= session.item,session.target
 local own=client==target
 local M=ix.Medicine
 local id=item.uniqueID
 local def=M.Catalog[id]
 local hitgroup=session.hitgroup
 if hitgroup==0 and def and (def.kind=="surgery" or def.kind=="splint") then
  local health=session.patient:Health()
  local injury=M.Injuries(health,def,0)[1]
  local part=injury and health.body.parts[injury.part]
  hitgroup=part and part.hitgroup or 0
 end
 local area=body[hitgroup] and body[hitgroup][own and 1 or 2] or (own and "свои раны" or "раны пациента")
 local text
 if id=="eft_surgery" then
  text="раскрывает хирургический набор CMS, готовит инструменты и начинает обрабатывать "..area.."."
 elseif id=="eft_splint" then
  text="расправляет алюминиевую шину и начинает фиксировать "..area.."."
 elseif id=="bandage" then
  text="достаёт жгут CAT и начинает останавливать кровотечение "..(own and "у себя." or "у пациента.")
 elseif injectors[id] then
  text="подготавливает автоинъектор «"..injectors[id].."» для инъекции "..(own and "себе." or "пациенту.")
 elseif tablets[id] then
  text="открывает упаковку «"..tablets[id].."» и "..(own and "готовится принять таблетку." or "готовит таблетку для пациента.")
 elseif def and def.kind=="kit" then
  text="открывает «"..def.name.."» и начинает обрабатывать "..area.."."
 elseif id=="bloodbag" or id=="ivbag" then
  text="подготавливает пакет "..(id=="bloodbag" and "с кровью" or "с раствором").." и подключает систему "..(own and "для переливания себе." or "для переливания пациенту.")
 elseif id=="bloodbag_empty" then
  text="подготавливает пустой пакет и систему для забора крови "..(own and "у себя." or "у пациента.")
 else
  text="подготавливает «"..itemName(item).."» для оказания помощи "..(own and "себе." or "пациенту.")
 end
 if emit(client,text) then client.ixNextMedicalEmote=CurTime()+2 end
end)

hook.Add("PlayerConsumedItem","ixContextualConsumption",function(client,item,kind,amount,finished)
 if not isnumber(amount) or amount~=amount or amount<=0 or amount==math.huge then return end
 local verb
 if kind=="food" then verb=finished and "съедает" or "ест"
 elseif kind=="drink" then verb=finished and "допивает" or "пьёт"
 else return end
 emit(client,verb.." «"..itemName(item).."».")
end)
