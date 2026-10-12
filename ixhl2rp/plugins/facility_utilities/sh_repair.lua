local F=ix.Facility
F.repair={contacts=5,period=7.2,width=.20,timeout=90}
local stages={{period=7.2,width=.20},{period=6.3,width=.18},{period=5.4,width=.16},
 {period=4.5,width=.145},{period=3.8,width=.13}}
function F.RepairStage(stage)
 return stages[math.Clamp(math.floor(stage),1,F.repair.contacts)]
end
-- A smooth constant-speed sweep. Shared rendering math; only the server scores it.
function F.RepairPosition(now,started,period)
 local t=math.max(0,now-started)/(period*.5)%2
 return t<=1 and t or 2-t
end
