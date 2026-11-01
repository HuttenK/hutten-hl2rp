PLUGIN.name = "Performance Capture"
PLUGIN.author = "Legends"
PLUGIN.description = "Opt-in frame/tick intervals and optimization counters; no automatic uploads."

ix.performance = ix.performance or {}
local P = ix.performance
if P.capture and P.Stop then P.Stop() end
ix.util.Include("sh_instrument.lua")
local realm = SERVER and "server" or "client"
local event = SERVER and "Tick" or "Think"

function P.Count(name, amount)
 local capture = P.capture
 if capture then capture.counters[name] = (capture.counters[name] or 0) + (amount or 1) end
end

local function Message(client, text)
 text = "[Performance] " .. text
 if SERVER and IsValid(client) then client:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
end

local function Percentile(capture, fraction)
 local keys = {}
 for key in pairs(capture.histogram) do keys[#keys+1] = key end
 table.sort(keys)
 local total = 0
 for _, key in ipairs(keys) do
  total = total + capture.histogram[key]
  if total >= capture.samples*fraction then return key/2 end
 end
 return 0
end

function P.Stop()
 local c = P.capture
 if not c then return end
 P.capture = nil
 if P.RemoveInstrumentation then P.RemoveInstrumentation(c) end
 hook.Remove(event, "ixPerformanceCapture")
 hook.Remove("EntityFireBullets","ixPerformanceShots")
 local report = {
  version=2, realm=realm, map=game.GetMap(), duration=SysTime()-c.started,
  samples=c.samples, intervalMeanMs=c.samples>0 and c.total/c.samples or 0,
  intervalP95Ms=Percentile(c,.95), intervalP99Ms=Percentile(c,.99), intervalMaxMs=c.maximum,
  gapsOver50ms=c.gaps50, gapsOver100ms=c.gaps100, counters=c.counters,
  population=c.population, settings=c.settings, timings=c.timings, network=c.network, database=c.database, expectedTickMs=SERVER and engine.TickInterval()*1000 or nil,
  note="Tick/Think intervals and scoped Lua wall-clock timings. Timings.totalMs includes nested wrapped calls; selfMs subtracts only measured children, not all native work. Profiling adds overhead. Network bytes are Lua net-buffer sizes, recipientBytes an estimate excluding protocol overhead; PVS/PAS recipients are unknown. DB issue time is submission/synchronous work; completion is issue-to-success-callback latency, not DB CPU. Failed async queries or queries still running at stop remain pending. No SQL text, message payloads, player IDs or audio are captured. Percentiles have 0.5 ms precision."
 }
 file.CreateDir("ix_performance")
 local path = "ix_performance/" .. realm .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".json"
 file.Write(path, util.TableToJSON(report, true))
 P.lastReport = report
 Message(c.requester, string.format("%s: mean %.2f ms, p95 %.2f ms, p99 %.2f ms, max %.2f ms; saved data/%s",
  realm,report.intervalMeanMs,report.intervalP95Ms,report.intervalP99Ms,report.intervalMaxMs,path))
 return report
end

function P.Start(duration, requester)
 if P.capture then Message(requester,"A capture is already running.");return false end
 duration = tonumber(duration) or 60
 if duration~=duration then duration=60 end
 duration = math.Clamp(duration,10,300)
 local now = SysTime()
 local c = {started=now,last=now,ends=now+duration,nextPopulation=now,requester=requester,
  samples=0,total=0,maximum=0,gaps50=0,gaps100=0,histogram={},counters={},population={}}
 c.settings={}
 for _,name in ipairs({"arc9_bullet_physics","arc9_bullet_physics_shotguns","arc9_mod_penetration","arc9_ricochet",
  "ix_arc9_indoor_mode","arc9_indoorsound","ix_render_budget","ix_render_budget_arms",
  "arc9_tpik","arc9_tpik_others","arc9_tpik_framerate_local","arc9_tpik_framerate_others","arc9_eft_nontpik_mode",
  "arc9_tpik_helper_bone_force_full_fps"}) do
  local setting=GetConVar(name);c.settings[name]=setting and setting:GetString() or "unavailable"
 end
 P.capture = c
 if P.InstallInstrumentation then
  local ok,err=pcall(P.InstallInstrumentation,c)
  if not ok then
   P.capture=nil;if P.RemoveInstrumentation then P.RemoveInstrumentation(c) end
   Message(requester,"Capture setup failed; wrappers restored: "..tostring(err));return false
  end
 end
 c.started=SysTime();c.last=c.started;c.ends=c.started+duration
 hook.Add("EntityFireBullets","ixPerformanceShots",function() P.Count("fire_bullets_calls") end)
 hook.Add(event,"ixPerformanceCapture",function()
  local at = SysTime()
  local ms = math.max(0,(at-c.last)*1000)
  c.last=at;c.samples=c.samples+1;c.total=c.total+ms;c.maximum=math.max(c.maximum,ms)
  -- Bound histogram size even when the process is paused for a long time.
  local bucket=math.min(20000,math.floor(ms*2+.5))
  c.histogram[bucket]=(c.histogram[bucket] or 0)+1
  if ms>50 then c.gaps50=c.gaps50+1 end
  if ms>100 then c.gaps100=c.gaps100+1 end
  if at>=c.nextPopulation then
   c.nextPopulation=at+1
   local players=player.GetAll()
   local row={at=at-c.started,players=#players,entities=ents.GetCount(),luaKB=collectgarbage("count")}
   row.arc9Bullets=ARC9 and ARC9.PhysBullets and #ARC9.PhysBullets or 0
   if SERVER then
    local sum,maximum=0,0
    for _,p in ipairs(players) do local ping=p:Ping();sum=sum+ping;maximum=math.max(maximum,ping) end
    row.meanPing=#players>0 and sum/#players or 0;row.maxPing=maximum
   end
   c.population[#c.population+1]=row
  end
  if at>=c.ends then P.Stop() end
 end)
 Message(requester,"Recording "..realm.." for "..duration.." seconds.")
 return true
end

concommand.Add("ix_perf_"..realm,function(client,_,args)
 if SERVER and IsValid(client) and not client:IsSuperAdmin() then return end
 if args[1]=="stop" then P.Stop() else P.Start(args[1],client) end
end)
-- A refresh must not leave an old capture callback running against new code.
if P.capture then P.Stop() end

function PLUGIN:OnUnload() if P.capture then P.Stop() end end
