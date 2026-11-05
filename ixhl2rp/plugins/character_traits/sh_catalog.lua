ix.Traits = ix.Traits or {}
local T = ix.Traits
T.list, T.byID = {}, {}
local function Add(id, name, points, description, group, effects, physical, icon)
 local t = {id=id, name=name, points=points, description=description, group=group, effects=effects or {}, physical=physical,
  icon="ck3_trait_"..(icon or id)..".png"}
 T.list[#T.list+1], T.byID[id] = t, t
end
Add("stuttering", "Заикание", 1, "Мысль уже готова, а язык всё мнётся на первом слоге. Порой приходится начинать слово снова, прежде чем оно наконец сорвётся с губ.", nil)
Add("lisping", "Шепелявость", 1, "Язык не желает слушаться: там, где должен звучать свист, выходит мягкое шипение. Такова ваша речь и в тихой беседе, и в громком споре.", nil)
Add("dwarf", "Карликовость", 1, "Ростом вы куда ниже большинства людей. Одежду приходится подгонять у портного, а за высоким столом невольно вспоминаешь о скамейке под ноги.", "height", {}, "Необычайно низкий рост")
Add("giant", "Гигантизм", 1, "В иных дверях вам приходится склонять голову, а за трапезой редко хватает одной миски. Великий рост дарован от рождения, богатырская сила — не обязательно.", "height", {hunger=1.15}, "Необычайно высокий рост")
Add("wheezing", "Одышка", 1, "Стоит припустить бегом, как грудь теснит, а дыхание становится тяжёлым и свистящим. Ногам ещё идти бы да идти, но приходится переводить дух.", nil, {stamina=.85})
Add("bleeder", "Плохая свёртываемость", 1, "Даже неглубокий порез долго сочится кровью. Чистое полотно и крепкая повязка для вас дороже иных снадобий.", nil, {bleeding=1.25})
Add("clubfooted", "Косолапость", 1, "Ступни подворачиваются, и ровный шаг даётся с трудом. В погоне приходится тратить больше сил, чтобы поспевать за остальными.", nil, {sprint=.9, sprintDrain=1.1}, "Косолапость")
Add("spindly", "Тонкие конечности", 1, "Тонкие руки и ноги словно собраны из прутьев. Там, где чужая кость выдержит удар, вашей лучше поберечься.", nil, {limbHealth=.9}, "Тонкие руки и ноги")
Add("hunchbacked", "Горбатость", 1, "Спина согнулась горбом, и расправить плечи во всю ширь уже не выходит. Торопливый бег даётся вам тяжелее размеренного шага.", nil, {sprint=.95}, "Заметный горб")
Add("albino", "Альбинизм", 1, "Кожа бледна, а волосы белы с юных лет, словно зима коснулась вас ещё в колыбели. Суеверный человек мог бы усмотреть в этом особый знак.", nil, {}, "Очень светлая кожа и белые волосы")
Add("weak", "Слабость", 1, "Тяжёлый двуручник не слушается рук, а тетива длинного лука не поддаётся. В бою приходится полагаться на оружие полегче.", "strength")
Add("strong", "Сила", -1, "Сильные руки легко ведут клинок и быстро возвращают его для нового замаха. Оружие слушается вас без лишнего усилия.", "strength", {attackSpeed=1.08})
Add("dull", "Тугодумие", 1, "Чужие речи иногда спутываются у вас в голове: собеседник толкует о деле, а вам чудятся самые нелепые слова.", "insight")
Add("shrewd", "Сметливость", -1, "Глаз быстро замечает, как устроена вещь, а руки находят короткий путь к её изготовлению. Где другой долго прикидывает, вы уже принялись за дело.", "insight", {craft=.9})
Add("one_eyed", "Одноглазость", 1, "Один глаз утрачен, и лишь вам ведомо, какая история за этим стоит. Рана может затянуться, но ни травник, ни костоправ не вернут потерянного.", nil)
Add("one_legged", "Одноногость", 1, "Одной ноги больше нет. Каждый переход требует терпения, а привычная прежде дорога теперь кажется куда длиннее.", nil)
Add("eunuch", "Евнух", 1, "Продолжить свой род вам не суждено. Обстоятельства этой утраты — часть вашей истории, которой вы вольны делиться или о которой можете молчать.", nil)
local tiers = {
 {"physique", 1, {"delicate","frail","feeble"}, {"Хрупкое телосложение","Слабое телосложение","Немощное телосложение"}, {
  "Тело сложено тонко и нежно. Удар, от которого другой лишь поморщится, способен оставить на вас немалый след.",
  "Плоть и кости не отличаются крепостью. В драке лучше не надеяться, что тело вынесет всё, на что решится сердце.",
  "С рождения тело держится словно на тонкой нити. Даже рана, которую иной счёл бы пустяком, для вас может обернуться тяжёлым испытанием."
 }, "health"},
 {"physique", -1, {"hale","robust","herculean"}, {"Крепкое телосложение","Могучее телосложение","Богатырское телосложение"}, {
  "Вы крепко сложены от природы. Плоть и кости хорошо держат удар, словно тело само приготовлено к суровой доле.",
  "Под кожей — плотные мышцы и крепкие кости. Такое тело непросто сокрушить даже в жестокой схватке.",
  "Вы сложены на диво могуче, словно богатыри из старых сказаний. Там, где другого уже сломили бы раны, ваше тело ещё держится."
 }, "health"},
 {"intellect", 1, {"slow","stupid","imbecile"}, {"Медлительность ума","Неразумность","Слабоумие"}, {
  "Мысль движется неспешно. Прежде чем взяться за ремесло, вам нужно ещё раз припомнить, что за чем следует.",
  "Ремесленные хитрости даются нелегко: объяснение приходится повторять, а работу — долго сверять с образцом.",
  "Даже простое ремесло требует от вас долгого сосредоточения. Не сразу удаётся связать отдельные наставления в понятный порядок."
 }, "craft"},
 {"intellect", -1, {"quick","intelligent","genius"}, {"Сообразительность","Ум","Гениальность"}, {
  "Достаточно толкового объяснения, чтобы ухватить суть работы. Пока другой вспоминает наставления, вы уже знаете, с чего начать.",
  "Ясный ум легко раскладывает сложное ремесло на простые приёмы. Вы редко тратите время на лишние движения и сомнения.",
  "Самые хитрые замыслы складываются в вашей голове с удивительной лёгкостью. Порой решение уже найдено, прежде чем мастер закончит объяснение."
 }, "craft"},
 {"beauty", 1, {"homely","ugly","hideous"}, {"Невзрачность","Некрасивость","Безобразность"}, {
  "Простое, непримечательное лицо, какое легко затеряется среди десятка других. Писаной красотой судьба вас не наделила.",
  "Черты лица грубы и нескладны. Придворному живописцу пришлось бы немало польстить вам, чтобы получить пригожий портрет.",
  "Резкие, несоразмерные черты далеки от всего, что воспевают поэты. Зеркало никогда не было для вас щедрым льстецом."
 }},
 {"beauty", -1, {"comely","handsome","beautiful"}, {"Привлекательность","Красота","Неземная красота"}, {
  "Лицо ладно, черты приятны. Даже без дорогого наряда в вашей наружности есть своя неброская прелесть.",
  "Природа щедро одарила вас красотой. Такое лицо достойно и тонкой кисти живописца, и строки в любовной балладе.",
  "Ваша красота кажется почти неправдоподобной, словно с образа в старинной книге. Поэт мог бы долго искать слова, чтобы передать её."
 }}
}
for _, family in ipairs(tiers) do
 for level=1,3 do
  local effect = {}
  if family[6] then effect[family[6]] = 1 + (family[6]=="health" and -1 or 1)*family[2]*level*.05 end
  Add(family[3][level], family[4][level], family[2]*level,
   family[5][level], family[1], effect,
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
