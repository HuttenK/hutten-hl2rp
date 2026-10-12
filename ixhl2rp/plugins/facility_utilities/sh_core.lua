ix.Facility=ix.Facility or {}
local F=ix.Facility
F.cableLength=600;F.cablePorts=8
function F.CablePoints(a,b,groundTrace)
 local delta=b-a;local length=delta:Length()
 local steps=math.Clamp(math.ceil(length/35),8,20)
 local sag=math.min(90,math.sqrt(delta.x*delta.x+delta.y*delta.y)*.22)
 local points={a}
 for i=1,steps-1 do
  local t=i/steps;local straight=a+delta*t
  local point=straight-Vector(0,0,4*sag*t*(1-t))
  if groundTrace and sag>0 then
   local hit=groundTrace(straight,point)
   if hit and hit.Hit then point=hit.HitPos+hit.HitNormal*.8 end
  end
  points[#points+1]=point
 end
 points[#points+1]=b
 return points
end
-- Measured from the requested generator VVD: front socket on the electrical panel.
F.generatorSocket=Vector(-9.58,-19.23,5.35)
F.generatorGeometryVersion=2
F.generatorFloor=-9.945116
function F.MigrateGeneratorGeometry(d)
 if d.kind~="generator" or (d.generatorGeometry or 1)>=F.generatorGeometryVersion then return false end
 local pos,ang=F.Vector(d.pos),F.Angle(d.ang)
 if not pos or not ang then return false end
 -- Legacy engine floor: -17.07115, new frame floor: -9.945116 (MDL/PHY).
 -- Move along local up so tilted admin placements retain their contact plane.
 d.pos=pos+ang:Up()*(-17.07115-F.generatorFloor)
 d.generatorGeometry=F.generatorGeometryVersion
 return true
end
function F.GeneratorSocket(e)
 if string.lower(e:GetModel() or "")=="models/props_se/junk/mobile_generator.mdl" then return e:LocalToWorld(F.generatorSocket) end
 return e:WorldSpaceCenter()
end
function F.CableStart(e,point)
 local localPoint=F.Vector(point)
 return localPoint and e:LocalToWorld(localPoint) or F.GeneratorSocket(e)
end
function F.EntityBackup(e)
 return IsValid(e) and e:GetNW2Bool("ixGeneratorPower",false)==true
end
function F.GeneratorPlacement(p,tr,yaw,model)
 if not tr.Hit or not tr.HitWorld or tr.HitSky or not F.Vector(tr.HitPos) or tr.HitNormal.z<.96 or tr.HitPos:DistToSqr(p:GetShootPos())>180^2 then return end
 if not IsValid(model) then return end
 local low,high=model:GetModelBounds();local r=math.rad(yaw);local co,si=math.cos(r),math.sin(r)
 local mins,maxs=Vector(1e6,1e6,0),Vector(-1e6,-1e6,high.z-low.z)
 for _,x in ipairs({low.x,high.x}) do for _,y in ipairs({low.y,high.y}) do
  local a,b=x*co-y*si,x*si+y*co
  mins.x=math.min(mins.x,a);mins.y=math.min(mins.y,b);maxs.x=math.max(maxs.x,a);maxs.y=math.max(maxs.y,b)
  local support=util.TraceLine({start=tr.HitPos+Vector(a,b,4),endpos=tr.HitPos+Vector(a,b,-8),filter={p,model},mask=MASK_SOLID})
  if not support.Hit or not support.HitWorld or support.HitNormal.z<.96 then return end
 end end
 local base=tr.HitPos+Vector(0,0,2)
 local hull=util.TraceHull({start=base,endpos=base,mins=mins,maxs=maxs,filter={p,model},mask=MASK_SOLID})
 if hull.Hit or hull.StartSolid then return end
 return base-Vector(0,0,low.z)
end
F.kinds={speaker={name="Громкоговоритель",model="models/props_wasteland/speakercluster01a.mdl"},
 intercom={name="Интерком — вызов помощи",model="models/props_lab/citizenradio.mdl"},
 receiver={name="Интерком — приём вызовов",model="models/props_lab/citizenradio.mdl"},
 announcement={name="Интерком — общий эфир",model="models/props_lab/citizenradio.mdl"},
 generator={name="Резервный генератор",model="models/props_se/junk/mobile_generator.mdl"},
 battery={name="Аккумуляторный блок",model="models/items/car_battery01.mdl"},
 workpoint={name="Пост обслуживания",model="models/props_lab/reciever01b.mdl"},
 panel={name="Экран на prop",model="models/hunter/plates/plate025x025.mdl",screen=true,page="comms"},
 terminal={name="Терминал инфраструктуры",model="models/props/cs_office/TV_plasma.mdl",screen=true,page="comms"},
 doorconsole={name="Пульт управления дверями",model="models/props/cs_office/TV_plasma.mdl",screen=true,page="doors"},
 powerconsole={name="Пульт энергоснабжения",model="models/props/cs_office/TV_plasma.mdl",screen=true,page="power"}}
F.entityCategory="Foundation / Инфраструктура"
function F.Time(seconds) seconds=math.max(0,math.floor(seconds or 0));return string.format("%d:%02d",math.floor(seconds/60),seconds%60) end
F.help={intercom="E — вызвать диспетчера. После ответа говорите обычной кнопкой голосового чата.",
 receiver="E — ответить на самый ранний вызов. E ещё раз — завершить. Нужна карта L2.",
 announcement="E — включить общий эфир. Говорите кнопкой голосового чата. E ещё раз — выключить. Нужна L2.",
 generator="Выбросьте из инвентаря. Резерв при blackout: E → подключить кабель (1 предмет) → заправить → запустить. При свете кабели не нужны. Канистра: 5 минут; бак: 10 минут.",
 battery="Выбросьте из инвентаря. При свете заряжается от сети на месте. При blackout: E → кабель к устройству или щитку. Генератор может зарядить по кабелю.",
 workpoint="E — начать обслуживание участка. Обычно занимает 15 секунд, без инструментов.",
 speaker="Воспроизводит объявления своего сектора. Для общего эфира громкоговорители не обязательны."}
function F.EntityKind(ent)
 if not IsValid(ent) then return end
 local kind=ent:GetClass():match("^ix_facility_(.+)$")
 if F.kinds[kind] then return kind end
end
function F.IsScreen(ent) local kind=F.EntityKind(ent);return kind and F.kinds[kind].screen==true or false end
function F.StartPage(ent) local kind=F.EntityKind(ent);return kind and F.kinds[kind].page end
F.pages={comms="Связь",doors="Двери",power="Энергосеть",jobs="Обслуживание"}
F.departments={"","security","military","science"}
function F.Number(v,a,b) return isnumber(v) and v==v and v>=a and v<=b end
function F.ID(v) return F.Number(v,1,1000000) and v%1==0 end
function F.Text(v,n)
 if not isstring(v) or #v>n*4 or v:find("[%c]") then return end
 v=string.Trim(v);if v=="" or (utf8.len(v) or n+1)>n then return end;return v
end
function F.Vector(v)
 if (istable(v) or isvector(v)) and F.Number(v.x,-32768,32768) and F.Number(v.y,-32768,32768) and F.Number(v.z,-32768,32768) then return Vector(v.x,v.y,v.z) end
end
function F.Angle(v)
 if (istable(v) or isangle(v)) and F.Number(v.p,-360,360) and F.Number(v.y,-360,360) and F.Number(v.r,-360,360) then return Angle(v.p,v.y,v.r) end
end
function F.Active(p)
 return IsValid(p) and p:IsPlayer() and p:Alive() and p:GetCharacter() and not p:InVehicle()
  and not p:IsRestricted() and p:GetLocalVar("ragdoll",0)==0 and not p:GetLocalVar("knocked",false)
end
function F.Access(p,level,department)
 if not F.Active(p) then return false end
 if p:IsAdmin() then return true end
 if (level or 0)==0 and (not department or department=="") then return true end
 local card=p.GetIDCard and p:GetIDCard()
 if not card or not ix.Fieldlink or not ix.Fieldlink.CardIdentity(card) then return false end
 return (card.clearanceLevel or 0)>=(level or 1) and (not department or department=="" or card.department==department)
end
function F.Near(p,ent,distance)
 if not F.Active(p) or not IsValid(ent) or p:GetShootPos():DistToSqr(ent:WorldSpaceCenter())>(distance or 140)^2 then return false end
 local filter={p,ent};local parent=ent:GetParent();if IsValid(parent) then filter[#filter+1]=parent end
 return not util.TraceLine({start=p:GetShootPos(),endpos=ent:WorldSpaceCenter(),filter=filter,mask=MASK_VISIBLE}).Hit
end
function F.Door(ent)
 if not IsValid(ent) then return false end
 local c=ent:GetClass();return c=="prop_door_rotating" or c=="func_door" or c=="func_door_rotating"
end
-- Stable priority allocation: each circuit is either supplied or shed in full.
function F.Allocate(circuits,capacity)
 local ordered={};for _,c in pairs(circuits) do ordered[#ordered+1]=c end
 table.sort(ordered,function(a,b) if a.priority==b.priority then return a.id<b.id end;return a.priority<b.priority end)
 local out,used={},0
 for _,c in ipairs(ordered) do if c.load<=capacity-used then out[c.id]=true;used=used+c.load end end
 return out,used
end
function F.PanelGeometry(ent)
 if F.IsScreen(ent) and F.EntityKind(ent)~="panel" then
  -- Same plasma model and surface as the existing Foundation terminal.
  local a=ent:GetAngles();a:RotateAroundAxis(ent:GetUp(),90);a:RotateAroundAxis(ent:GetRight(),-90)
  return ent:GetPos()+ent:GetRight()*28+ent:GetUp()*35.2+ent:GetForward()*6.12,a,56/1920
 end
 local w=ent:GetNW2Float("ixFacilityWidth",32);local a=ent:GetAngles();local scale=w/1920
 local pos=ent:GetPos();local preview=CLIENT and F.panelPreview
 if preview and preview.id==ent:GetNW2Int("ixFacilityID",0) and IsValid(ent:GetParent()) then
  pos,a=LocalToWorld(preview.pos,preview.ang,ent:GetParent():GetPos(),ent:GetParent():GetAngles());w=preview.width;scale=w/1920
 end
 return pos-a:Forward()*w*.5-a:Right()*(1120*scale*.5),a,scale
end
