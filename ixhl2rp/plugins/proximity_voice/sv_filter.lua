-- Server-only voice packet processing. Never applies listener-wide DSP.
local V = ix.voice
local enabled = CreateConVar("ix_radio_voice_filter", "1", FCVAR_ARCHIVE,
 "Filter radio voice only (requires the eightbit server module).")
local backend
local status = "not initialized"
local paEffect
local paStatus = "not initialized"
local paFile = "ix_facility_pa.gvox"
local paSpeakers = {}
-- Cache only native filter assignments, never voice authorization decisions.
local filterRoutes = {}
-- The module's normal radio preset, with a longer, audible echo.
-- This is processed per receiver, so it never changes world/game audio.
local paPreset = [[version=1
key=ix_facility_pa
name=Foundation PA
description=Facility announcement radio filter with speaker echo
gain=1.0
highpass_hz=650
lowpass_hz=3500
drive=1.35
clip=0.82
pitch=1.0
ring_frequency_hz=0
ring_mix=0
echo_delay_ms=170
echo_mix=0.38
noise=0.008
quantize=320
downsample=2
soft_clip=false
]]

local function LoadPAFilter(m)
 paEffect=nil
 if not m.WritePresetFile or not m.ReloadPresets or not m.GetPresets then
  paStatus="custom preset API unavailable; using radio without echo"
  return
 end
 local ok,result=pcall(function()
  local written,reason=m.WritePresetFile(paFile,paPreset)
  if not written then error(tostring(reason)) end
  -- Load via GMod DATA paths, not the Linux server's working directory.
  -- Keep every other custom preset when refreshing the module's registry.
  local presets={}
  for _,name in ipairs(file.Find("gvox/presets/*.gvox","DATA") or {}) do
   local content=file.Read("gvox/presets/"..name,"DATA")
   if content then presets[name]=content end
  end
  presets[paFile]=paPreset
  m.ReloadPresets(presets)
  for _,preset in ipairs(m.GetPresets() or {}) do
   if preset.key=="ix_facility_pa" and preset.file==paFile and isnumber(preset.id) then return preset.id end
  end
  error("PA preset was not registered")
 end)
 if ok then paEffect=result;paStatus="ready: radio + 170 ms echo"
 else paStatus="preset failed: "..tostring(result).."; using radio without echo" end
end

function V.LoadRadioFilter()
 if backend then
  for _, p in ipairs(player.GetAll()) do backend.ClearPlayer(p:UserID()) end
 end
 backend = nil;paEffect=nil;paStatus="module unavailable";paSpeakers={};filterRoutes={}
 local ok, result = pcall(require, "eightbit")
 local m = eightbit
 if not ok then status = "module unavailable: " .. tostring(result)
 elseif not m or not m.SetReceiverEffect or not m.ClearReceiverEffect or
  not m.ClearPlayer or not m.IsHookAvailable or not m.EFF_RADIO then
  status = "incompatible module: receiver routing API missing"
 elseif not m.IsHookAvailable() then status = "module loaded but engine voice hook unavailable"
 else
  backend = m
  -- Also clear native state left by a Lua refresh of this file.
  for _, p in ipairs(player.GetAll()) do backend.ClearPlayer(p:UserID()) end
  status = "ready: per-receiver voice filtering";LoadPAFilter(m)
 end
 print("[ix radio filter] " .. status .. "; PA=" .. paStatus)
end

function V.ApplyRadioFilter(listener, talker, hear, spatial, effect)
 if not backend then return end
 local radio = enabled:GetBool() and hear and not spatial and listener ~= talker
 local routes = filterRoutes[talker]
 if radio then
  local desired = effect=="pa" and paEffect or backend.EFF_RADIO
  if not routes then routes={};filterRoutes[talker]=routes end
  if routes[listener]~=desired then
   backend.SetReceiverEffect(listener:UserID(), talker:UserID(), desired)
   if ix.performance then ix.performance.Count("voice_filter_assignments") end
   routes[listener]=desired
  end
  if effect=="pa" and paEffect and talker.IsSpeaking and talker:IsSpeaking() then
   paSpeakers[talker]=CurTime()
  end
 elseif routes and routes[listener] then
  backend.ClearReceiverEffect(listener:UserID(), talker:UserID())
  routes[listener]=nil
  if not next(routes) then filterRoutes[talker]=nil end
 end
end

function V.ClearRadioFilter(p)
 paSpeakers[p]=nil
 filterRoutes[p]=nil
 for talker,routes in pairs(filterRoutes) do
  routes[p]=nil
  if not next(routes) then filterRoutes[talker]=nil end
 end
 if backend then backend.ClearPlayer(p:UserID()) end
end

-- Refresh even when the engine is between voice permission polls. This also
-- clears effects after PTT release, lease expiry, unequipping or channel change.
timer.Create("ixRadioFilterRoutes", .1, 0, function()
 if not backend then return end
 local players = player.GetAll()
 local now=CurTime()
 local checked=0
 -- The module retains delay samples between voice packets. Discard them after
 -- an announcement ends so its final syllable cannot replay in the next one.
 -- Clear first: ClearPlayer also removes receiver routes, rebuilt below.
 for talker,lastSpoke in pairs(paSpeakers) do
  if not IsValid(talker) then paSpeakers[talker]=nil
  elseif talker:IsSpeaking() then paSpeakers[talker]=now
  elseif now-lastSpoke>.5 then V.ClearRadioFilter(talker) end
 end
 for _, talker in ipairs(players) do
  local held=talker.ixRadioVoice
  local active=(talker.IsSpeaking and talker:IsSpeaking()) or paSpeakers[talker] or
   (held and held.expires>now and held.character==talker:GetCharacter())
  if active and enabled:GetBool() then
   local context={}
   for _, listener in ipairs(players) do
    local hear, spatial, label, gain, effect = V.Route(listener, talker, context)
    checked=checked+1
    V.ApplyRadioFilter(listener, talker, hear, spatial, effect)
   end
  else
   -- Idle players need no all-listener route calculation. Clear any previous
   -- outgoing filters once; a voice permission poll installs new ones on demand.
   local routes=filterRoutes[talker]
   if routes then
    for listener in pairs(routes) do
     if IsValid(listener) then backend.ClearReceiverEffect(listener:UserID(),talker:UserID()) end
    end
    filterRoutes[talker]=nil
   end
  end
 end
 if ix.performance then ix.performance.Count("voice_refresh_pair_checks",checked) end
end)
hook.Add("PlayerDisconnected", "ixRadioFilterCleanup", V.ClearRadioFilter)
hook.Add("PlayerDeath", "ixRadioFilterDeath", V.ClearRadioFilter)
hook.Add("PlayerLoadedCharacter", "ixRadioFilterCharacter", V.ClearRadioFilter)
concommand.Add("ix_radio_filter_status", function(p)
 if IsValid(p) and not p:IsSuperAdmin() then return end
 local message = "[ix radio filter] " .. status .. "; enabled=" .. tostring(enabled:GetBool()) .. "; PA=" .. paStatus
 if IsValid(p) then p:PrintMessage(HUD_PRINTCONSOLE, message) else print(message) end
end)
V.LoadRadioFilter()
