-- Server-only voice packet processing. Never applies listener-wide DSP.
local V = ix.voice
local enabled = CreateConVar("ix_radio_voice_filter", "1", FCVAR_ARCHIVE,
 "Filter radio voice only (requires the eightbit server module).")
local backend
local status = "not initialized"

function V.LoadRadioFilter()
 if backend then
  for _, p in ipairs(player.GetAll()) do backend.ClearPlayer(p:UserID()) end
 end
 backend = nil
 local ok, result = pcall(require, "eightbit")
 local m = eightbit
 if not ok then status = "module unavailable: " .. tostring(result)
 elseif not m or not m.SetReceiverEffect or not m.ClearReceiverEffect or
  not m.ClearPlayer or not m.IsHookAvailable or not m.EFF_RADIO then
  status = "incompatible module: receiver routing API missing"
 elseif not m.IsHookAvailable() then status = "module loaded but engine voice hook unavailable"
 else backend = m; status = "ready: radio-only receiver filtering" end
 print("[ix radio filter] " .. status)
end

function V.ApplyRadioFilter(listener, talker, hear, spatial)
 if not backend then return end
 local radio = enabled:GetBool() and hear and not spatial and listener ~= talker
 if radio then
  backend.SetReceiverEffect(listener:UserID(), talker:UserID(), backend.EFF_RADIO)
 else
  backend.ClearReceiverEffect(listener:UserID(), talker:UserID())
 end
end

function V.ClearRadioFilter(p)
 if backend then backend.ClearPlayer(p:UserID()) end
end

-- Refresh even when the engine is between voice permission polls. This also
-- clears effects after PTT release, lease expiry, unequipping or channel change.
timer.Create("ixRadioFilterRoutes", .1, 0, function()
 if not backend then return end
 local players = player.GetAll()
 for _, talker in ipairs(players) do
  for _, listener in ipairs(players) do
   local hear, spatial = V.Route(listener, talker)
   V.ApplyRadioFilter(listener, talker, hear, spatial)
  end
 end
end)
hook.Add("PlayerDisconnected", "ixRadioFilterCleanup", V.ClearRadioFilter)
hook.Add("PlayerDeath", "ixRadioFilterDeath", V.ClearRadioFilter)
hook.Add("PlayerLoadedCharacter", "ixRadioFilterCharacter", V.ClearRadioFilter)
concommand.Add("ix_radio_filter_status", function(p)
 if IsValid(p) and not p:IsSuperAdmin() then return end
 local message = "[ix radio filter] " .. status .. "; enabled=" .. tostring(enabled:GetBool())
 if IsValid(p) then p:PrintMessage(HUD_PRINTCONSOLE, message) else print(message) end
end)
V.LoadRadioFilter()
