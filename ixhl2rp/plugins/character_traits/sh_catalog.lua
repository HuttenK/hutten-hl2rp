ix.Traits = ix.Traits or {}
local T = ix.Traits
T.list, T.byID = {}, {}
local function Add(id, name, points, description, group, effects, physical, icon)
 local t = {id=id, name=name, points=points, description=description, group=group, effects=effects or {}, physical=physical,
  icon="ck3_trait_"..(icon or id)..".png"}
 T.list[#T.list+1], T.byID[id] = t, t
end
Add("stuttering", "Заикание", 1, "В ролевой речи иногда повторяются первые звуки слов.", nil)
Add("lisping", "Шепелявость", 1, "Свистящие звуки в ролевой речи заменяются шипящими.", nil)
Add("dwarf", "Карликовость", 1, "Рост 125–145 см. Меняются размер тела, камера и размеры столкновения.", "height", {}, "Необычайно низкий рост")
Add("giant", "Гигантизм", 1, "Рост 195–215 см. Голод нарастает на 15% быстрее. Сила сама по себе не увеличивается.", "height", {hunger=1.15}, "Необычайно высокий рост")
Add("wheezing", "Одышка", 1, "Запас выносливости меньше на 15%. При изнурительном беге слышно тяжёлое дыхание.", nil, {stamina=.85})
Add("bleeder", "Плохая свёртываемость", 1, "Неперевязанные раны теряют на 25% больше крови. Бинт по-прежнему полностью останавливает кровотечение.", nil, {bleeding=1.25})
Add("clubfooted", "Косолапость", 1, "Бег медленнее на 10%, расход выносливости при беге выше на 10%.", nil, {sprint=.9, sprintDrain=1.1}, "Косолапость")
Add("spindly", "Тонкие конечности", 1, "Максимальное здоровье рук и ног меньше на 10%.", nil, {limbHealth=.9}, "Тонкие руки и ноги")
Add("hunchbacked", "Горбатость", 1, "Бег медленнее на 5%. Особенность указана во внешности; скелет модели не деформируется.", nil, {sprint=.95}, "Заметный горб")
Add("albino", "Альбинизм", 1, "Ролевая особенность: очень светлые волосы и кожа в описании. SD-волосы становятся белыми; остальные модели сохраняют свою текстуру.", nil, {}, "Очень светлая кожа и белые волосы")
Add("weak", "Слабость", 1, "Нельзя экипировать тяжёлое двуручное оружие и длинный лук. Носить их в сумке можно. Меч со щитом и парные кинжалы разрешены.", "strength")
Add("strong", "Сила", -1, "Атаки холодным оружием Age of Chivalry быстрее на 8%. Урон и дальность не меняются.", "strength", {attackSpeed=1.08})
Add("dull", "Тугодумие", 1, "В услышанной ролевой речи около 10% слов воспринимаются как несуразица, не более двух слов за сообщение. Собственная речь не меняется.", "insight")
Add("shrewd", "Сметливость", -1, "Изготовление предметов быстрее на 10%. С умственными способностями действует только больший бонус.", "insight", {craft=.9})
Add("one_eyed", "Одноглазость", 1, "Утрата выбранного глаза отмечена во внешности. Также может появиться с шансом 2% после серьёзной травмы головы. Лечение ран не возвращает глаз.", nil)
Add("one_legged", "Одноногость", 1, "Отсутствует выбранная нога. Действуют обычные штрафы системы ампутации, без повторного штрафа от черты.", nil)
Add("eunuch", "Евнух", 1, "Ролевая особенность биографии, указанная в списке черт персонажа. Не изменяет боевые параметры.", nil)
local tiers = {
 {"physique", 1, {"delicate","frail","feeble"}, {"Хрупкое телосложение","Слабое телосложение","Немощное телосложение"}, "Максимальное здоровье всех частей тела меньше на %d%%.", "health"},
 {"physique", -1, {"hale","robust","herculean"}, {"Крепкое телосложение","Могучее телосложение","Богатырское телосложение"}, "Максимальное здоровье всех частей тела больше на %d%%.", "health"},
 {"intellect", 1, {"slow","stupid","imbecile"}, {"Медлительность ума","Неразумность","Слабоумие"}, "Изготовление предметов медленнее на %d%%.", "craft"},
 {"intellect", -1, {"quick","intelligent","genius"}, {"Сообразительность","Ум","Гениальность"}, "Изготовление предметов быстрее на %d%%. Со сметливостью действует только больший бонус.", "craft"},
 {"beauty", 1, {"homely","ugly","hideous"}, {"Невзрачность","Некрасивость","Безобразность"}, "Ролевая особенность внешности. Не заставляет других игроков относиться к вам определённым образом."},
 {"beauty", -1, {"comely","handsome","beautiful"}, {"Привлекательность","Красота","Неземная красота"}, "Ролевая особенность внешности. Не меняет лицо модели или отношение других игроков."}
}
for _, family in ipairs(tiers) do
 for level=1,3 do
  local effect = {}
  if family[6] then effect[family[6]] = 1 + (family[6]=="health" and -1 or 1)*family[2]*level*.05 end
  Add(family[3][level], family[4][level], family[2]*level,
   family[6] and string.format(family[5],level*5) or family[5], family[1], effect,
   family[1]~="intellect" and family[4][level] or nil, family[1]..(family[2]>0 and "_bad_" or "_good_")..level)
 end
end

local empty={}
function T.Selection(character)
 return character and character.GetTraits and character:GetTraits(empty) or empty
end
function T.Has(character, id) return T.Selection(character)[id] ~= nil end
function T.Balance(selection)
 local points=0
 for id in pairs(selection or {}) do local t=T.byID[id]; if t then points=points+t.points end end
 return points
end
function T.Conflict(selection, id)
 local chosen=T.byID[id]
 if not chosen then return true end
 for key in pairs(selection) do
  local other=T.byID[key]
  if key~=id and other and chosen.group and other.group==chosen.group then return key end
 end
end
function T.Validate(value)
 if value==nil then return {} end
 if not istable(value) then return false,"Неверный список черт." end
 local count,clean=0,{}
 for id,selected in pairs(value) do
  count=count+1
  if count>#T.list or not isstring(id) or not T.byID[id] then return false,"Неизвестная черта." end
  if id=="one_eyed" or id=="one_legged" then
   if selected~="left" and selected~="right" then return false,"Выберите сторону утраты." end
  elseif selected~=true then return false,"Неверное значение черты." end
  if T.Conflict(clean,id) then return false,"Выбраны несовместимые черты." end
  clean[id]=selected
 end
 if T.Balance(clean)<0 then return false,"Не хватает очков: добавьте отрицательные черты или уберите положительные." end
 return clean
end
function T.HeightRange(selection)
 if not istable(selection) then return 155,190 end
 if selection and selection.dwarf then return 125,145 end
 if selection and selection.giant then return 195,215 end
 return 155,190
end
function T.ClampHeight(height, selection)
 local low,high=T.HeightRange(selection)
 height=tonumber(height)
 if not height or height~=height or math.abs(height)==math.huge then height=180 end
 return math.Clamp(math.Round(height),low,high)
end
function T.Modifier(character, key)
 local value=1
 for id in pairs(T.Selection(character)) do
  local t=T.byID[id];local n=t and t.effects[key]
  if n then value=value*n end
 end
 -- Resolve craft bonuses independently of table iteration order.
 if key=="craft" then
  local bonus,penalty=1,1
  for id in pairs(T.Selection(character)) do
   local t=T.byID[id];local n=t and t.effects.craft
   if n then if n<1 then bonus=math.min(bonus,n) else penalty=penalty*n end end
  end
  return bonus*penalty
 end
 return value
end
function T.HealthMultiplier(character,hitgroup)
 local n=T.Modifier(character,"health")
 if hitgroup and hitgroup>=4 and hitgroup<=7 then n=n*T.Modifier(character,"limbHealth") end
 return n
end
function T.Description(character)
 local result={}
 local selected=T.Selection(character)
 for _,t in ipairs(T.list) do
  if selected[t.id] then
   if t.physical then result[#result+1]=t.physical
   elseif t.id=="one_eyed" then result[#result+1]=selected[t.id]=="right" and "Нет правого глаза" or "Нет левого глаза" end
  end
 end
 return table.concat(result," · ")
end
