const r=require('./restored-test-runner.cjs');
const setup=r.source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/plugins/area/sh_geometry.lua'])+`
local V=getmetatable(Vector());function V:WithinAABox(a,b) return self.x>=a.x and self.x<=b.x and self.y>=a.y and self.y<=b.y and self.z>=a.z and self.z<=b.z end
ix.area.stored={};ix.util={Include=function() end};ix.config.Add=function() end
function box(x,y,z,a,b,c) return {min=Vector(x,y,z),max=Vector(a,b,c)} end
local area={type='flood',properties={}}
assert(ix.area.SetVolumes(area,{box(0,0,0,100,40,100),box(0,0,0,40,100,100)}))
ix.area.stored.L=area
`;
r.run('Flood and pump membership exclude the missing wing and overlapping heights use the true water surface',setup+`
PLUGIN.level={L=80};ENT={};ix.plugin.list.flood=PLUGIN
`+r.native('ixhl2rp/plugins/flood/sh_plugin.lua','function PLUGIN:GetAreaBounds','-- Регистрируем тип зоны')+
r.native('ixhl2rp/plugins/flood/entities/entities/ix_flood_pump.lua','function ENT:GetFloodZone()','if (SERVER) then')+`
eq(PLUGIN:WaterLevelAt(Vector(80,80,20)),nil)
eq(PLUGIN:WaterLevelAt(Vector(80,20,20)),80);eq(PLUGIN:WaterLevelAt(Vector(20,80,20)),80)
local p={WorldSpaceCenter=function() return Vector(80,80,20) end};eq(ENT.GetFloodZone(p),nil)
p.WorldSpaceCenter=function() return Vector(20,80,20) end;eq(ENT.GetFloodZone(p),'L')
assert(ix.area.SetVolumes(area,{box(0,0,0,100,100,50),box(0,0,0,40,100,100)}))
eq(PLUGIN:WaterLevelAt(Vector(20,20,20)),80);eq(PLUGIN:WaterLevelAt(Vector(80,20,20)),50)
`);
r.run('Infection ground samples stay in the compound footprint and gas checks both wings without filling the gap',setup+`
area.type='infection';area.properties={zombieMax=0,zombieInterval=1,floraMax=0,floraInterval=1,infestationTotal=1}
PLUGIN.defaults={activeRadius=0,zombieMax=0,zombieInterval=1,floraMax=0,floraInterval=1,infestationTotal=1,despawnDelay=60}
PLUGIN.flora={};PLUGIN.zombies={};PLUGIN.remaining={};PLUGIN.nextSpawn={};PLUGIN.suppressed={}
function countValid() return 0 end
ix.plugin.list.scp610_control={settings={paused=true}}
math.Rand=function(a,b) return (a+b)*.5 end
util.TraceLine=function(t) return {Hit=true,HitPos=Vector(t.start.x,t.start.y,0),HitNormal=Vector(0,0,1)} end
`+r.native('ixhl2rp/plugins/infectionzone/sv_plugin.lua','local function randomGroundPoint(area)','local function spawnZombie(name, area)')+
r.native('ixhl2rp/plugins/infectionzone/sv_plugin.lua','function PLUGIN:InfectionTick()','function PLUGIN:InfectionInit()')+`
for i=1,100 do local point=randomGroundPoint(area);assert(ix.area.Contains(area,point)) end
local p={valid=true,pos=Vector(80,80,20),Alive=function() return true end,GetCharacter=function() return {} end,OBBCenter=function() return Vector() end}
function p:GetPos() return self.pos end;function p:GetNetVar() return self.toxic end;function p:SetNetVar(_,v) self.toxic=v end
PLUGIN.UpdateToxicExposure=function(_,client,v) client.exposure=v end;allPlayers={p}
PLUGIN:InfectionTick();eq(p.exposure,false)
p.pos=Vector(80,20,20);PLUGIN:InfectionTick();eq(p.exposure,true)
p.pos=Vector(20,80,20);PLUGIN:InfectionTick();eq(p.exposure,true)
`);
r.run('Decontamination distance measures actual volume edges rather than the enclosing rectangle',setup+
r.source(['ixhl2rp/plugins/decontamination/sh_plugin.lua'])+`
eq(ix.Decon.ZoneDistance(Vector(80,80,20),area),1600)
eq(ix.Decon.ZoneDistance(Vector(80,20,20),area),0)
eq(ix.Decon.ZoneDistance(Vector(20,80,20),area),0)
`);
r.finish();
