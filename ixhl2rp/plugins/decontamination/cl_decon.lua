local D=ix.Decon
local C={ivory=Color(239,236,221),edge=Color(144,151,138),ink=Color(42,57,52),muted=Color(78,94,87),amber=Color(170,104,20),stripe=Color(211,162,48),bad=Color(159,55,40),ready=Color(49,114,87),spray=Color(150,215,240,180)}
surface.CreateFont("DeconLabel",{font="Tahoma",size=19,weight=700,extended=true})
surface.CreateFont("DeconText",{font="Tahoma",size=17,weight=500,extended=true})
surface.CreateFont("DeconSmall",{font="Tahoma",size=14,weight=500,extended=true})
local function clipped(text,font,width)
 surface.SetFont(font)
 if surface.GetTextSize(text)<=width then return text end
 local n=utf8.len(text) or #text
 while n>1 and surface.GetTextSize(text.."…")>width do n=n-1;text=string.utf8sub(text,1,n) end
 return text.."…"
end
function D.Readout(e)
 local powered=e:GetNW2Bool("ixFacilityPowered",false)
 local faulty=e:GetNW2Bool("ixFacilityFault",false)
 local alarm=e:GetNW2Bool("ixDeconAlarm",false)
 local active=IsValid(e:GetNW2Entity("ixDeconUser"))
 local status,detail
 if faulty then status="НЕИСПРАВНО";detail="Требуется обслуживание."
 elseif not powered then status="ПИТАНИЕ ОТКЛЮЧЕНО";detail="Проверьте подключение к сети."
 elseif e.FacilityKind=="decon_sensor" then
  detail=e:GetNW2String("ixDeconStatus","")
  local waiting=not alarm and not detail:find("^УГРОЗ НЕ ОБНАРУЖЕНО")
  status=waiting and "ОЖИДАНИЕ ПОКАЗАНИЙ" or alarm and "ОБНАРУЖЕНА БИОУГРОЗА" or "УГРОЗ НЕ ОБНАРУЖЕНО"
  if waiting then detail="Датчик ещё не передал результаты." end
 elseif active then
  status=e.FacilityKind=="decon_shower" and "ПРОМЫВКА" or "УТИЛИЗАЦИЯ"
  detail="Цикл выполняется. Оставайтесь рядом."
 else
  status="ГОТОВО К РАБОТЕ"
  detail=e.FacilityKind=="decon_shower" and "Промывка после токсического воздействия." or "Только заражённые останки SCP-610 / NPC."
 end
 local key=string.upper(input.LookupBinding("+use") or "E")
 local hint=faulty and (key.." · обслуживание") or not powered and "Питание необходимо для работы" or e.FacilityKind=="decon_sensor" and (key.." · проверить показания") or active and (key.." · остановить свой цикл") or (key.." · начать цикл")
 return status,detail,hint,faulty or alarm or not powered
end
function D.Draw(e)
 e:DrawModel()
 if ix.CCTV and ix.CCTV.rendering or EyePos():DistToSqr(e:GetPos())>500^2 then return end
 local target=e:GetNW2Entity("ixDeconUser")
 if e:GetNW2Bool("ixFacilityPowered",false) and not e:GetNW2Bool("ixFacilityFault",false) and IsValid(target) and e.FacilityKind=="decon_shower" then
  local center=target:GetPos()
  for i=1,12 do
   local angle=i*2.4;local height=(CurTime()*55+i*7)%65
   local point=center+Vector(math.cos(angle)*19,math.sin(angle)*19,72-height)
   render.DrawLine(point,point-Vector(0,0,7),C.spray,true)
  end
 end
end
-- One small contextual hint, with the standard SetAction bar as the only
-- cycle progress indicator. It cannot overlap the old 174px readout card.
function D.Interaction(p,e)
 if not D.kinds[e.FacilityKind] or not ix.Facility or not ix.Facility.Near(p,e,110) then return end
 if e:GetNW2Bool("ixFacilityFault",false) then return end -- facility repair action
 local status,detail,_,warning=D.Readout(e)
 local user=e:GetNW2Entity("ixDeconUser")
 local powered=e:GetNW2Bool("ixFacilityPowered",false)
 local label=e.FacilityKind=="decon_sensor" and "Проверить показания" or IsValid(user) and (user==p and "Остановить цикл" or "Устройство занято") or "Начать цикл"
 return {title=e:GetNW2String("ixFacilityName",e.PrintName),native=true,config=true,duringAction=user==p,
  options={{id="use",label=label,disabled=not powered or IsValid(user) and user~=p,detail=IsValid(user) and "" or (warning and status or detail),warning=warning}}}
end
function PLUGIN:GetEquipmentInteraction(p,e) return D.Interaction(p,e) end
hook.Remove("HUDPaint","ixDeconReadout")
