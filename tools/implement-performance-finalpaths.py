from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def edit(name,old,new):
 p=ROOT/name;s=p.read_text(encoding='utf8');assert s.count(old)==1,(name,s.count(old),old[:80]);p.write_text(s.replace(old,new),encoding='utf8')

# Keep exact union membership, cache a cheap broad phase for multi-volume areas.
edit('helix/plugins/area/sh_geometry.lua','function ix.area.Contains(info, position)\n\tfor _, box in ipairs(ix.area.GetVolumes(info)) do',
'''local bounds=setmetatable({}, {__mode="k"})
function ix.area.Contains(info, position)
\tlocal volumes=ix.area.GetVolumes(info)
\tif #volumes>1 then
\t\tlocal broad=bounds[info]
\t\tif not broad or broad.source~=volumes then
\t\t\tlocal first=volumes[1]
\t\t\tbroad={source=volumes,min=Vector(first.min),max=Vector(first.max)}
\t\t\tfor _,box in ipairs(volumes) do for _,axis in ipairs({"x","y","z"}) do
\t\t\t\tbroad.min[axis]=math.min(broad.min[axis],box.min[axis]);broad.max[axis]=math.max(broad.max[axis],box.max[axis])
\t\t\tend end
\t\t\tbounds[info]=broad
\t\tend
\t\tif not position:WithinAABox(broad.min,broad.max) then return false end
\tend
\tfor _, box in ipairs(volumes) do''')
edit('helix/plugins/area/sh_geometry.lua','function ix.area.Measure(info)\n\tlocal size = 0\n\tfor _, box in ipairs(ix.area.GetDisjointVolumes(info) or ix.area.GetVolumes(info)) do',
'''local measures=setmetatable({}, {__mode="k"})
function ix.area.Measure(info)
\tlocal boxes=ix.area.GetDisjointVolumes(info) or ix.area.GetVolumes(info)
\tif measures[boxes] then return measures[boxes] end
\tlocal size = 0
\tfor _, box in ipairs(boxes) do''')
edit('helix/plugins/area/sh_geometry.lua','\treturn size\nend','\tmeasures[boxes]=size\n\treturn size\nend')

# Location-only list once per scan; never collect all overlapping IDs just to use the first.
edit('helix/plugins/area/sv_hooks.lua','function PLUGIN:AreaThink()\n',
'''function PLUGIN:AreaThink()
\tlocal locations={}
\tfor id,info in pairs(ix.area.stored) do
\t\tif not (ix.area.typeOptions[info.type] or {}).nonLocation then locations[#locations+1]={id=id,info=info} end
\tend
''')
edit('helix/plugins/area/sv_hooks.lua','\t\tlocal overlappingBoxes = {}','\t\tlocal selected')
edit('helix/plugins/area/sv_hooks.lua',
'''\t\tfor id, info in pairs(ix.area.stored) do
\t\t\tlocal options = ix.area.typeOptions[info.type] or {}
\t\t\tif (!options.nonLocation and ix.area.Contains(info, position)) then
\t\t\t\toverlappingBoxes[#overlappingBoxes + 1] = id
\t\t\tend
\t\tend

\t\tif (#overlappingBoxes > 0) then''',
'''\t\tfor _,entry in ipairs(locations) do
\t\t\tif ix.area.Contains(entry.info,position) then selected=entry.id break end
\t\tend

\t\tif selected then''')
edit('helix/plugins/area/sv_hooks.lua','local id = overlappingBoxes[1]','local id = selected')

# Cache nearby door candidates by render origin (including separate CCTV views).
edit('helix/plugins/doors/cl_plugin.lua','function PLUGIN:PostDrawTranslucentRenderables(bDepth, bSkybox)',
'''local nearbyDoors,nearbyOrigin,nearbyAt={},nil,0
local doorFrames=setmetatable({}, {__mode="k"})
function PLUGIN:PostDrawTranslucentRenderables(bDepth, bSkybox)''')
edit('helix/plugins/doors/cl_plugin.lua','\tlocal entities = ents.FindInSphere(EyePos(), 256)',
'''\tlocal eye=EyePos()
\tif not nearbyOrigin or nearbyOrigin:DistToSqr(eye)>64^2 or RealTime()>=nearbyAt then
\t\tnearbyAt=RealTime()+.2;nearbyOrigin=Vector(eye);nearbyDoors={}
\t\tfor _,ent in ipairs(ents.FindInSphere(eye,320)) do if IsValid(ent) and ent:IsDoor() then nearbyDoors[#nearbyDoors+1]=ent end end
\tend
\tlocal entities = nearbyDoors''')
edit('helix/plugins/doors/cl_plugin.lua','\t\tlocal width = 0\n\t\tlocal size = maxs - mins',
'''\t\tlocal frame=doorFrames[v]
\t\tlocal pos,ang=v:GetPos(),v:GetAngles()
\t\tif not frame or frame.pos~=pos or frame.ang~=ang or frame.model~=v:GetModel() or frame.mins~=mins or frame.maxs~=maxs or RealTime()>=frame.expires then
\t\tlocal width = 0
\t\tlocal size = maxs - mins''')
edit('helix/plugins/doors/cl_plugin.lua','\t\telseif (size.y < size.x) then','\t\telse')
edit('helix/plugins/doors/cl_plugin.lua',
'\t\tlocal positionOpposite = trace.HitPos + (trace.HitNormal * 2)\n',
'''\t\tlocal positionOpposite = trace.HitPos + (trace.HitNormal * 2)
\t\tframe={pos=pos,ang=ang,model=v:GetModel(),mins=mins,maxs=maxs,expires=RealTime()+1,
\t\t\twidth=width,normal=trace.HitNormal,front=positionFront,back=positionOpposite,angles=angles,opposite=anglesOpposite}
\t\tdoorFrames[v]=frame
\t\tend
\t\tlocal width,angles,anglesOpposite=frame.width,frame.angles,frame.opposite
\t\tlocal positionFront,positionOpposite=frame.front,frame.back
''')
edit('helix/plugins/doors/cl_plugin.lua','if (trace.HitNormal:Dot((clientPosition - position):GetNormalized()) < 0) then',
'if (frame.normal:Dot((clientPosition - position):GetNormalized()) < 0) then')

# Only active contextual actors need frame-rate blending/bone invalidation.
edit('ixhl2rp/plugins/action_animations/cl_actions.lua','hook.Add("Think","ixContextActionActors",function()',
'local nextActorDiscovery=0\nhook.Add("Think","ixContextActionActors",function()')
edit('ixhl2rp/plugins/action_animations/cl_actions.lua',' for _,entity in ipairs(player.GetAll()) do\n  local kind=',
''' local candidates={[viewer]=true}
 for entity in pairs(A.actors) do candidates[entity]=true end
 if RealTime()>=nextActorDiscovery then
  nextActorDiscovery=RealTime()+.1
  for _,entity in ipairs(player.GetAll()) do
   if entity:GetNW2String("ixContextAction","")~="" then candidates[entity]=true end
  end
 end
 for entity in pairs(candidates) do
  if not IsValid(entity) then A.Clear(entity) continue end
  local kind=''')

# Save byte-identical world snapshots only once during periodic reconciliation.
# Explicit edits, shutdown and map cleanup still perform the full authoritative save.
edit('ixhl2rp/plugins/world_persistence/sv_store.lua','function P:SaveData()','function P:SaveData(onlyChanged)')
edit('ixhl2rp/plugins/world_persistence/sv_store.lua',' self:SetData({version=1, nextID=self.nextID, entities=rows})',
''' local snapshot={version=1,nextID=self.nextID,entities=rows}
 local encoded=util.TableToJSON(snapshot)
 if onlyChanged==true and encoded==self.lastSnapshot then return end
 self:SetData(snapshot)
 self.lastSnapshot=encoded''')
edit('ixhl2rp/plugins/world_persistence/sv_store.lua',
' if ix.plugin.list.world_persistence == P and not P.stopping then P:SaveData() end',
' if ix.plugin.list.world_persistence == P and not P.stopping then P:SaveData(true) end')

# Captures name the busiest variables and count shots/active ARC9 bullets.
edit('helix/gamemode/core/sh_networking.lua','\t\tfunction net.WriteNetVar(var, varType, value)\n',
'''\t\tfunction net.WriteNetVar(var, varType, value)
\t\t\tif ix.performance and ix.performance.capture then
\t\t\t\tix.performance.Count("netvar:"..varType..":"..tostring(Net.vars_id[varType][var.index]))
\t\t\tend
''')
edit('ixhl2rp/plugins/performance_monitor/sh_plugin.lua','  population=c.population, expectedTickMs=',
'  population=c.population, settings=c.settings, expectedTickMs=')
edit('ixhl2rp/plugins/performance_monitor/sh_plugin.lua',' P.capture = c\n',
''' c.settings={}
 for _,name in ipairs({"arc9_bullet_physics","arc9_bullet_physics_shotguns","arc9_tpik","arc9_tpik_others"}) do
  local setting=GetConVar(name);c.settings[name]=setting and setting:GetString() or "unavailable"
 end
 P.capture = c
 hook.Add("EntityFireBullets","ixPerformanceShots",function() P.Count("fire_bullets_calls") end)
''')
edit('ixhl2rp/plugins/performance_monitor/sh_plugin.lua',' hook.Remove(event, "ixPerformanceCapture")',
' hook.Remove(event, "ixPerformanceCapture")\n hook.Remove("EntityFireBullets","ixPerformanceShots")')
edit('ixhl2rp/plugins/performance_monitor/sh_plugin.lua','   if SERVER then\n    local sum,maximum=0,0',
'''   row.arc9Bullets=ARC9 and ARC9.PhysBullets and #ARC9.PhysBullets or 0
   if SERVER then
    local sum,maximum=0,0''')
print('Applied final-path optimizations')
