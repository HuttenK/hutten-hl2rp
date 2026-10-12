local P=PLUGIN
ix.command.Add("TVAdmin",{adminOnly=true,description="Пульт каналов и экранов Фонда.",OnRun=function(_,p)
 if SERVER and IsValid(p) and p:IsAdmin() then P:OpenControls(p) end
end})
ix.command.Add("TVPlace",{adminOnly=true,description="Разместить экран на стене или модели.",OnRun=function(_,p)
 if SERVER and IsValid(p) and p:IsAdmin() then P:OpenControls(p,true) end
end})
ix.command.Add("TVChannel",{adminOnly=true,arguments={ix.type.number},description="Выбрать канал для команд TVSet / TVSound.",OnRun=function(_,p,id)
 if SERVER and IsValid(p) and p:IsAdmin() then
  P:Initialize()
  if P.channels[id] then p.ixTVSelectedChannel=id;return "Выбран канал: "..P.channels[id].name end
  return "Канал не найден."
 end
end})
local function action(p,what,data)
 if not SERVER or not IsValid(p) or not p:IsAdmin() then return end
 data=data or {};data.channel=p.ixTVSelectedChannel or 1
 local ok,message=P:Action(p,what,data);return message
end
ix.command.Add("TVSet",{adminOnly=true,arguments={ix.type.string},description="Прямой URL видео/изображения или материал на выбранном канале.",OnRun=function(_,p,path) return action(p,"play",{source=path}) end})
ix.command.Add("TVReset",{adminOnly=true,description="Остановить выбранный канал.",OnRun=function(_,p) return action(p,"stop") end})
ix.command.Add("TVLoop",{adminOnly=true,arguments={ix.type.string},description="Повтор выбранного канала: on / off.",OnRun=function(_,p,v)
 if v~="on" and v~="off" then return "Укажите on или off." end
 return action(p,"loop",{value=v=="on"})
end})
ix.command.Add("TVSubtitles",{adminOnly=true,arguments={ix.type.string},description="SRT/VTT из data/ix_tv_subtitles/ или off.",OnRun=function(_,p,name) return action(p,"captions",{file=name}) end})
for _,def in ipairs({{"TVSound",true},{"TVSoundOnce",false}}) do
 local loop=def[2]
 ix.command.Add(def[1],{adminOnly=true,arguments={ix.type.string},description="Звук выбранного канала.",OnRun=function(_,p,path) return action(p,"sound",{source=path,loop=loop}) end})
end
ix.command.Add("TVSoundStop",{adminOnly=true,description="Остановить отдельную звуковую дорожку.",OnRun=function(_,p) return action(p,"sound",{source=""}) end})

