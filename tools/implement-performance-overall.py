"""One-time, assertion-checked edits; pre-edit snapshot is kept outside the checkout."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def edit(name, old, new):
    p=ROOT/name; s=p.read_text(encoding='utf-8')
    assert s.count(old)==1, (name,s.count(old),old[:100])
    p.write_text(s.replace(old,new),encoding='utf-8',newline='')

# Supported ARC9 switches: ordinary bullets become lag-compensated hitscan.
# Explicit ShootEnt/AlwaysPhysBullet special weapons retain their own behavior.
edit('ixhl2rp/plugins/arc9_compat.lua',
'\t\tif setting then setting:SetBool(true) end',
'''\t\tif setting then setting:SetBool(true) end
\t\tfor _, name in ipairs({"arc9_bullet_physics", "arc9_bullet_physics_shotguns"}) do
\t\t\tlocal convar = GetConVar(name)
\t\t\tif convar and convar:GetBool() then convar:SetBool(false) end
\t\tend''')
edit('ixhl2rp/plugins/arc9_compat.lua', '\ttimer.Simple(0, HideWeaponHUD)',
'''\ttimer.Simple(0, HideWeaponHUD)
\t-- server.cfg and addon reloads must not silently restore per-bullet simulation.
\ttimer.Create("ixARC9ServerPolicy", 5, 0, HideWeaponHUD)
\tfunction PLUGIN:OnUnload() timer.Remove("ixARC9ServerPolicy") end''')

# Normalized legacy geometry: invalidate even when a vector is edited in place.
edit('helix/plugins/area/sh_geometry.lua','local cached = setmetatable({}, {__mode = "k"})',
'local cached = setmetatable({}, {__mode = "k"})\nlocal legacy = setmetatable({}, {__mode = "k"})')
edit('helix/plugins/area/sh_geometry.lua',
'''\treturn {{min = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)),
\t\tmax = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))}}''',
'''\tlocal old = legacy[info]
\tif old and old.ax==a.x and old.ay==a.y and old.az==a.z and old.bx==b.x and old.by==b.y and old.bz==b.z then return old.boxes end
\tlocal boxes = {{min = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)),
\t\tmax = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))}}
\tlegacy[info] = {ax=a.x,ay=a.y,az=a.z,bx=b.x,by=b.y,bz=b.z,boxes=boxes}
\treturn boxes''')
edit('helix/plugins/area/sh_geometry.lua',
'''\tlocal a, b = info.startPosition or info.min, info.endPosition or info.max
\tif (old and old.source == info.volumes and old.a == a and old.b == b) then return old.boxes end''',
'''\tlocal source = ix.area.GetVolumes(info)
\tif (old and old.source == source) then return old.boxes end''')
edit('helix/plugins/area/sh_geometry.lua','cached[info] = {source = info.volumes, a = a, b = b, boxes = boxes}',
     'cached[info] = {source = source, boxes = boxes}')

# Per-frame discovery becomes bounded; selected flashlights still move every frame.
edit('ixhl2rp/plugins/flashlight/cl_flashlight.lua','local lamps = {}','local lamps = {}\nlocal candidates, nextCandidates = {}, 0')
edit('ixhl2rp/plugins/flashlight/cl_flashlight.lua','    local candidates = {}',
'''    if RealTime() >= nextCandidates then
    nextCandidates = RealTime() + .1
    candidates = {}''')
edit('ixhl2rp/plugins/flashlight/cl_flashlight.lua',
'    table.sort(candidates, function(a, b) return a.distance < b.distance end)',
'    table.sort(candidates, function(a, b) return a.distance < b.distance end)\n    end')
edit('ixhl2rp/plugins/flashlight/cl_flashlight.lua','        keep[client] = true',
'''        if not IsValid(client) or not client:Alive() or client:IsDormant() or not client:GetNWBool("ixFieldFlashlight", false) then continue end
        keep[client] = true''')

# Lower-pass stencil recovery retains the same endpoint brightness and cone.
edit('ixhl2rp/plugins/blackout/cl_lighting.lua','local levels,sides=64,64','local levels,sides=24,64')

# Avoid repeated static native map renders. Dynamic labels/devices are separate overlays.
edit('ixhl2rp/plugins/foundation_network/cl_map3d.lua',
'..tostring(high)..":"..tostring(sky)',
'..tostring(high)..":"..tostring(sky)..":"..tostring(e.Themes and e.Themes.GetActive().background)')
edit('ixhl2rp/plugins/foundation_network/cl_map3d.lua',
'if current==R.renderKey and R.material and not panel.dirty and RealTime()<(R.nextRefresh or 0) then',
'if current==R.renderKey and R.material and not panel.dirty then')
edit('ixhl2rp/plugins/foundation_network/cl_map3d.lua',' R.nextRefresh=RealTime()+.25\n','')

# Existing equip/death/character hooks remain immediate; fallback reconciliation is 1 Hz.
edit('ixhl2rp/plugins/bodycams/sv_bodycams.lua','self.nextBodycamCheck=CurTime()+.25','self.nextBodycamCheck=CurTime()+1')
edit('ixhl2rp/plugins/npcs/entities/entities/ix_basenpc.lua','self:NextThink(CurTime())','self:NextThink(CurTime()+1)')

edit('ixhl2rp/plugins/waypoints/cl_hooks.lua','\t\tif (LocalPlayer():IsLineOfSightClear(waypoint.pos)) then',
'''\t\tif (waypoint.nextSight or 0) <= CurTime() then
\t\t\twaypoint.nextSight = CurTime() + .1
\t\t\twaypoint.clearSight = LocalPlayer():IsLineOfSightClear(waypoint.pos)
\t\tend
\t\tif (waypoint.clearSight) then''')
edit('ixhl2rp/plugins/sleep/cl_sleep.lua','local fade, menu = 0','local fade, menu = 0\nlocal hintTrace, nextHint = nil, 0')
edit('ixhl2rp/plugins/sleep/cl_sleep.lua',
'  local trace=util.TraceLine({start=origin,endpos=origin+p:GetAimVector()*S.USE_RANGE,filter=p,mask=MASK_SOLID})',
'''  if not hintTrace or RealTime()>=nextHint then
   nextHint=RealTime()+.1
   hintTrace=util.TraceLine({start=origin,endpos=origin+p:GetAimVector()*S.USE_RANGE,filter=p,mask=MASK_SOLID})
  end
  local trace=hintTrace''')
edit('ixhl2rp/plugins/ixcraft/derma/cl_craft_item.lua','function PANEL:Think()\n\tlocal color = self:GetColor()',
'''function PANEL:Think()
\tif (self.nextColorCheck or 0) > RealTime() then return end
\tself.nextColorCheck = RealTime() + .1
\tlocal color = self:GetColor()
\tif self.lastRecipeColor == color then return end
\tself.lastRecipeColor = color''')

# Discovery only; smoke emission retains the existing interval and live NW flag checks.
edit('ixhl2rp/plugins/infectionzone/cl_plugin.lua','local wasteNext = 0',
'local wasteNext = 0\nlocal wasteCandidates, wasteSearchAt = {}, 0')
edit('ixhl2rp/plugins/infectionzone/cl_plugin.lua','\tfor _, e in ipairs(ents.FindInSphere(eye, 1400)) do',
'''\tif CurTime() >= wasteSearchAt then
\t\twasteSearchAt = CurTime()+1
\t\twasteCandidates = ents.FindInSphere(eye, 1600)
\tend
\tfor _, e in ipairs(wasteCandidates) do''')
edit('ixhl2rp/plugins/infectionzone/cl_plugin.lua','\t\tif (!e:GetNWBool("ixInfectWaste", false)) then continue end',
'\t\tif (!e:GetNWBool("ixInfectWaste", false) or e:GetPos():DistToSqr(eye)>1400^2) then continue end')

# Validate each power cable only once per solve; fuel/charge and access remain live.
edit('ixhl2rp/plugins/facility_utilities/sv_power.lua','   d.links=d.links or {}\n',
'   d.links=d.links or {}\n   local cableStates={}\n')
edit('ixhl2rp/plugins/facility_utilities/sv_power.lua','    local valid,e=self:CableValid(d,link)\n',
'    local valid,e=self:CableValid(d,link)\n    cableStates[link]={valid,e}\n')
edit('ixhl2rp/plugins/facility_utilities/sv_power.lua','    if link then valid,e=self:CableValid(d,link) end',
'    if link then local state=cableStates[link];valid,e=state[1],state[2] end')

# Safe producer-level deltas. Leave generic resync, targeted sends and tables untouched.
edit('ixhl2rp/plugins/!healthsystem/sh_health.class.lua','\t\tclient:SetNetVar("isBleeding", bool)',
'\t\tif client:GetNetVar("isBleeding") ~= bool then client:SetNetVar("isBleeding", bool) end')
print('Applied overall performance edits')
