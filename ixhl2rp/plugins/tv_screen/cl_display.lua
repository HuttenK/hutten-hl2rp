local T=ix.TV
T.colors={bg=Color(8,13,19),panel=Color(17,26,36),line=Color(43,65,81),text=Color(228,241,244),muted=Color(146,171,185),accent=Color(70,215,221),red=Color(241,83,99),amber=Color(234,190,98)}
for name,def in pairs({Title={24,700},Body={17,500},Small={13,500},Signal={34,600},SignalSmall={20,500}}) do
 surface.CreateFont("ixTV"..name,{font="Tahoma",size=def[1],weight=def[2],extended=true,antialias=true})
end
T.statuses={
 idle={"ЭФИР НЕ НАЧАТ","Ожидание трансляции оператора","STANDBY"},
 loading={"ПОДКЛЮЧЕНИЕ","Приём сигнала канала","CONNECTING"},
 buffering={"ВОССТАНОВЛЕНИЕ СИГНАЛА","Трансляция временно недоступна","BUFFERING"},
 ended={"ТРАНСЛЯЦИЯ ЗАВЕРШЕНА","Ожидание следующей программы","END OF PROGRAMME"},
 error={"НЕТ СИГНАЛА","Источник недоступен или формат не поддерживается","NO SIGNAL"},
 blocked={"ВОСПРОИЗВЕДЕНИЕ НЕДОСТУПНО","Обратитесь к оператору трансляции","PLAYBACK UNAVAILABLE"},
 missing={"КАНАЛ НЕДОСТУПЕН","Экран ожидает назначения канала","NO CHANNEL"}
}
function T.FitText(text,font,width)
 surface.SetFont(font)
 while surface.GetTextSize(text)>width and text:utf8len()>1 do text=text:utf8sub(1,text:utf8len()-2).."…" end
 return text
end
function T.DrawFailure(w,h,status,channel)
 local C=T.colors;local text=T.statuses[status] or T.statuses.error
 surface.SetDrawColor(C.bg);surface.DrawRect(0,0,w,h)
 local grid=math.max(64,math.ceil(math.max(w,h)/128))
 surface.SetDrawColor(18,34,43);for x=0,w,grid do surface.DrawLine(x,0,x,h) end;for y=0,h,grid do surface.DrawLine(0,y,w,y) end
 local accent=(status=="error" or status=="blocked") and C.amber or C.accent
 surface.SetDrawColor(accent);surface.DrawRect(36,36,72,3);surface.DrawRect(w-108,h-39,72,3)
 local small=w<800 or h<450
 local titleFont=small and "ixTVBody" or "ixTVSignal"
 local smallFont=small and "ixTVSmall" or "ixTVSignalSmall"
 draw.SimpleText("SCiPNET  /  FOUNDATION BROADCAST",smallFont,36,small and 16 or 53,C.muted)
 local size=math.min(160,h*.22);local y=h*.2
 if ix.InterfaceOS and ix.InterfaceOS.Emblem then ix.InterfaceOS.Emblem((w-size)/2,y,size,accent)
 elseif ix.Fieldlink and ix.Fieldlink.DrawSCP then ix.Fieldlink.DrawSCP((w-size)/2,y,size,accent) end
 draw.SimpleText(text[1],titleFont,w/2,y+size+h*.07,C.text,TEXT_ALIGN_CENTER)
 draw.SimpleText(text[2],smallFont,w/2,y+size+h*.17,C.muted,TEXT_ALIGN_CENTER)
 surface.SetFont(smallFont)
 local available=w-100-surface.GetTextSize(text[3])
 draw.SimpleText(T.FitText(channel or "FOUNDATION NETWORK",smallFont,available),smallFont,36,h-25,C.muted)
 draw.SimpleText(text[3],smallFont,w-36,h-25,accent,TEXT_ALIGN_RIGHT)
end

