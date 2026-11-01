from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def edit(name,old,new):
 p=ROOT/name;s=p.read_text(encoding='utf8');assert s.count(old)==1,(name,s.count(old),old[:80]);p.write_text(s.replace(old,new),encoding='utf8')

# Registry of switchable lights; rebuilt once after load/cleanup, not every second.
edit('ixhl2rp/plugins/blackout/sv_plugin.lua','function PLUGIN:RefreshLights()\n    for _, ent in ipairs(ents.GetAll()) do',
'''local lights
local function trackLight(ent)
    if lights and IsValid(ent) and LIGHT_CLASSES[ent:GetClass()] then lights[ent]=true end
end
hook.Add("OnEntityCreated", "ixBlackoutLightRegistry", function(ent)
    timer.Simple(0,function() trackLight(ent) end)
end)
hook.Add("EntityRemoved", "ixBlackoutLightRegistry", function(ent) if lights then lights[ent]=nil end end)
hook.Add("PostCleanupMap", "ixBlackoutLightRegistry", function() lights=nil end)
function PLUGIN:RefreshLights()
    if not lights then
        lights=setmetatable({}, {__mode="k"})
        for _,ent in ipairs(ents.GetAll()) do trackLight(ent) end
        for ent in pairs(self.lightStates) do if IsValid(ent) then lights[ent]=true end end
    end
    for ent in pairs(lights) do
        if not IsValid(ent) then lights[ent]=nil continue end''')

# Flood candidate discovery at 5 Hz, exact membership/force each simulation tick.
edit('ixhl2rp/plugins/flood/sv_plugin.lua','function PLUGIN:ApplyBuoyancy(name, area, lvl)',
'''local buoyancyCandidates = setmetatable({}, {__mode="k"})
function PLUGIN:ApplyBuoyancy(name, area, lvl)''')
edit('ixhl2rp/plugins/flood/sv_plugin.lua','\tfor _, ent in ipairs(ents.FindInBox(boxMin, boxMax)) do',
'''\tlocal cache = buoyancyCandidates[area]
\tif not cache or cache.expires <= CurTime() then
\t\tcache={expires=CurTime()+.2,entities={}}
\t\t-- Include nearby moving props; exact union membership is still tested below.
\t\tfor _, ent in ipairs(ents.FindInBox(boxMin-Vector(128,128,128),boxMax+Vector(128,128,128))) do
\t\t\tif IsValid(ent) and isBuoyant(ent) then cache.entities[#cache.entities+1]=ent end
\t\tend
\t\tbuoyancyCandidates[area]=cache
\tend
\tfor _, ent in ipairs(cache.entities) do''')
edit('ixhl2rp/plugins/flood/sv_plugin.lua','\t\tphys:SetDamping(d.linearDamp, d.angularDamp)',
'''\t\tlocal wet=self.wetEnts[ent]
\t\tif not istable(wet) or wet.physics~=phys then
\t\t\tlocal linear,angular=phys:GetDamping()
\t\t\twet={physics=phys,linear=linear,angular=angular}
\t\t\tself.wetEnts[ent]=wet
\t\tend
\t\tif wet.appliedLinear~=d.linearDamp or wet.appliedAngular~=d.angularDamp then
\t\t\tphys:SetDamping(d.linearDamp,d.angularDamp)
\t\t\twet.appliedLinear,wet.appliedAngular=d.linearDamp,d.angularDamp
\t\tend''')
edit('ixhl2rp/plugins/flood/sv_plugin.lua','\t\tself.wetEnts[ent] = true\n','')
edit('ixhl2rp/plugins/flood/sv_plugin.lua','\t\t\tif (IsValid(phys)) then phys:SetDamping(0, 0) end',
'''\t\t\tlocal wet=self.wetEnts[ent]
\t\t\tif IsValid(phys) then
\t\t\t\tif istable(wet) and wet.physics==phys then phys:SetDamping(wet.linear,wet.angular)
\t\t\t\telse phys:SetDamping(0,0) end
\t\t\tend''')

# Routine combat XP messages aggregate; the XP award itself remains immediate.
edit('ixhl2rp/plugins/!!skills/libs/sh_actions.lua','ix.action.list = ix.action.list or {}',
'''ix.action.list = ix.action.list or {}
if SERVER then
    ix.action.pendingAwards = ix.action.pendingAwards or {}
    function ix.action:FlushAwards(player)
        for character,row in pairs(self.pendingAwards) do
            if not player or row.client==player then
                self.pendingAwards[character]=nil
                local message=string.format("%s [%s / character %s]: '%s' x%d, %.2f XP (%s).",row.name,row.steam,row.character,row.action,row.count,row.total,row.skill)
                if row.phase then
                    Msg("[LOG] ",message.."\\n")
                    ix.log.CallHandler("Write",row.client,message,0)
                else ix.log.AddRaw(message) end
            end
        end
    end
    function ix.action:QueueCombatAward(character,action,result)
        local p=character:GetPlayer()
        local row=self.pendingAwards[character]
        if not row then
            row={client=p,name=p:GetName(),steam=p:SteamID(),character=character:GetID(),
                phase=p.phase,action=action.name,skill=action.skill,count=0,total=0}
            self.pendingAwards[character]=row
        end
        row.count=row.count+1;row.total=row.total+result
    end
    timer.Create("ixCombatAwardLogs",2,0,function() ix.action:FlushAwards() end)
    hook.Add("PlayerDisconnected","ixCombatAwardLogs",function(p) ix.action:FlushAwards(p) end)
    hook.Add("PrePlayerLoadedCharacter","ixCombatAwardLogs",function(p) ix.action:FlushAwards(p) end)
    hook.Add("ShutDown","ixCombatAwardLogs",function() ix.action:FlushAwards() end)
end''')
edit('ixhl2rp/plugins/!!skills/libs/sh_actions.lua',
'\t\t\t\t\tix.log.Add(self:GetPlayer(), "skillAction", action.name, result, action.skill)',
'''\t\t\t\t\tif actionID == "shootSuccess" then ix.action:QueueCombatAward(self,action,result)
\t\t\t\t\telse ix.log.Add(self:GetPlayer(), "skillAction", action.name, result, action.skill) end''')

# Subtitle movement is a small position delta; structural snapshots remain full.
name='ixhl2rp/plugins/subtitlepoint/sh_plugin.lua'
edit(name,'\t-- Создать точку\n',
'''\tfunction PLUGIN:SyncSubtitlePoints(target)
\t\tif not target then self.subtitleRevision=(self.subtitleRevision or 0)+1 end
\t\tnetstream.Start(target,"ixSubtitlePointSync",serializePoints(self.subtitlePoints),self.subtitleRevision or 0)
\tend

\t-- Создать точку
''')
p=ROOT/name;s=p.read_text(encoding='utf8')
s=s.replace('netstream.Start(nil, "ixSubtitlePointSync", serializePoints(self.subtitlePoints))','self:SyncSubtitlePoints()')
s=s.replace('netstream.Start(client, "ixSubtitlePointSync", serializePoints(self.subtitlePoints))','self:SyncSubtitlePoints(client)')
s=s.replace('netstream.Start(nil, "ixSubtitlePointSync", serializePoints(PLUGIN.subtitlePoints))','PLUGIN:SyncSubtitlePoints()')
p.write_text(s,encoding='utf8')
edit(name,'\t\tlocal changed = false\n\n\t\tfor _, point in ipairs(PLUGIN.subtitlePoints) do',
'\t\tlocal changed = {}\n\n\t\tfor index, point in ipairs(PLUGIN.subtitlePoints) do')
edit(name,'\t\t\tlocal off    = point.attachOffset', '\t\t\tlocal off    = point.attachOffset or {0,0,0}')
edit(name,'\t\t\t\tchanged   = true','\t\t\t\tchanged[#changed+1] = {index,newPos}')
edit(name,'\t\tif changed then\n\t\t\tPLUGIN:SyncSubtitlePoints()\n\t\tend',
'''\t\tif #changed>0 then
\t\t\tnetstream.Start(nil,"ixSubtitlePointPositions",PLUGIN.subtitleRevision or 0,changed)
\t\tend''')
edit(name,'\tnetstream.Hook("ixSubtitlePointSync", function(points)',
'''\tlocal pointRevision=0
\tnetstream.Hook("ixSubtitlePointPositions",function(revision,changes)
\t\tif revision~=pointRevision then return end
\t\tfor _,change in ipairs(changes) do
\t\t\tlocal point=subtitlePoints[change[1]]
\t\t\tif point and isvector(change[2]) then point.pos=change[2] end
\t\tend
\tend)
\tnetstream.Hook("ixSubtitlePointSync", function(points,revision)
\t\tpointRevision=revision or 0''')

# Preserve mutable tree changes without JSON serialization in every draw call.
edit('ixhl2rp/plugins/arccw_item_atts/cl_display.lua','function A.Get(host, class, tree, rounds)',
'''local function sameTree(a,b)
    if type(a)~=type(b) then return false end
    if not istable(a) then return a==b end
    for key,value in pairs(a) do if not sameTree(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end
function A.Get(host, class, tree, rounds)''')
edit('ixhl2rp/plugins/arccw_item_atts/cl_display.lua',
'''    local signature = class .. ":" .. util.TableToJSON(tree or {}) .. ":" .. tostring(rounds or 0)
    local entry = records[host]
    if entry and entry.signature == signature then''',
'''    local entry = records[host]
    rounds=rounds or 0
    if entry and entry.class==class and entry.rounds==rounds and sameTree(entry.tree,tree or {}) then''')
edit('ixhl2rp/plugins/arccw_item_atts/cl_display.lua',
'    records[host] = {signature = signature, model = model, retry = RealTime() + 5}',
'    records[host] = {class=class,rounds=rounds,tree=table.Copy(tree or {}),model=model,retry=RealTime()+5}')

# Keep security/state checks per listener, but share radio entity discovery.
edit('ixhl2rp/plugins/proximity_voice/sv_voice.lua','function V.RadioListener(listener,info)',
'''local stations
local function trackStation(ent)
 if stations and IsValid(ent) and ent:GetClass()=="ix_stationary_radio" then stations[ent]=true end
end
hook.Add("OnEntityCreated","ixVoiceStationRegistry",function(ent) timer.Simple(0,function() trackStation(ent) end) end)
hook.Add("EntityRemoved","ixVoiceStationRegistry",function(ent) if stations then stations[ent]=nil end end)
hook.Add("PostCleanupMap","ixVoiceStationRegistry",function() stations=nil end)
function V.RadioListener(listener,info)''')
edit('ixhl2rp/plugins/proximity_voice/sv_voice.lua',' for _,radio in ipairs(ents.FindByClass("ix_stationary_radio")) do',
''' if not stations then
  stations=setmetatable({}, {__mode="k"})
  for _,radio in ipairs(ents.FindByClass("ix_stationary_radio")) do trackStation(radio) end
 end
 for radio in pairs(stations) do
  if not IsValid(radio) then stations[radio]=nil continue end''')
print('Applied service optimizations')
