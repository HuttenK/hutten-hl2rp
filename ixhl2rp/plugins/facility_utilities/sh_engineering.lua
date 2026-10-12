local F=ix.Facility
F.engineeringNames={probe="Поиск обрыва",pressure="Регулировка давления",bolts="Затяжка крепежа"}
ix.config.Add("facilityRepairGame","auto","Мини-игра ремонта: auto, contacts, probe, pressure или bolts.",nil,{category="Инфраструктура"})
function F.EngineeringStage(kind,stage,skill)
 local state=ix.repair.NewGame(kind,{hard=stage>=3,skill=skill or 0})
 if not state then return end
 if kind=="probe" then
  state.count=stage+3;state.broken=math.random(1,state.count);state.possible={}
  for i=1,state.count do state.possible[i]=true end
  state.budget=math.ceil(math.log(state.count)/math.log(2))+math.max(1,4-stage)
 elseif kind=="bolts" then
  state.showBand=true
  for i=1,state.count do state.hi[i]=state.lo[i]+.30-stage*.028 end
 elseif kind=="pressure" then
  -- Anchor each narrower band to an actual solution, keeping diagnostics solvable.
  local target
  for code=0,124 do
   local valves=ix.repair.games.pressure.Unpack(code);local value=state.base
   for i=1,3 do value=value+valves[i]*state.weights[i] end
   if value>=state.lo and value<=state.hi then target=value;break end
  end
  if not target then return end
  local width=12-stage*2
  if target>state.reading then
   state.lo=math.max(state.reading+1,target-math.floor(width/2));state.hi=state.lo+width
   if state.hi>state.limit then state.hi=state.limit;state.lo=state.hi-width end
  else state.hi=math.min(state.reading-1,target+math.ceil(width/2));state.lo=state.hi-width end
  state.runs=math.max(4,8-stage)
 end
 return state
end
function F.EngineeringBolts(entity,state)
 if not IsValid(entity) or not state or not state.anchor then return {} end
 local a=state.anchor;local pos=entity:LocalToWorld(Vector(unpack(a.pos)))
 local ang=entity:LocalToWorldAngles(Angle(unpack(a.ang)));local points={}
 for i=1,state.count do
  local phi=math.rad(-90+(i-1)*360/state.count)
  points[i]=pos+ang:Right()*math.cos(phi)*a.radius+ang:Up()*math.sin(phi)*a.radius
 end
 return points
end
