local P = PLUGIN
-- This is a quality mode, not a sound-disable switch: mode 0 still selects
-- indoor/outdoor recordings, using one upward trace every quarter-second.
local mode = CreateConVar("ix_arc9_indoor_mode", "0", FCVAR_ARCHIVE,
 "ARC9 indoor sound quality: 0 = one trace/0.25s, 1 = three/0.1s, 2 = eight/0.02s.", 0, 2)
local function apply()
 local setting = GetConVar("arc9_indoorsound")
 if setting and setting:GetInt() ~= mode:GetInt() then setting:SetInt(mode:GetInt()) end
end
timer.Simple(0, apply)
timer.Create("ixARC9IndoorPolicy", 5, 0, apply)
concommand.Add("ix_arc9_sound_mode", function(client, _, args)
 if IsValid(client) and not client:IsSuperAdmin() then return end
 local value = args[1]
 local modes = {optimized = 0, baseline = 1, detailed = 2}
 local selected = modes[value] or tonumber(value)
 if selected and selected >= 0 and selected <= 2 and selected == math.floor(selected) then
  mode:SetInt(selected); apply()
 end
 local message = "[ARC9 audio] Indoor mode " .. mode:GetInt() ..
  ". 0/optimized: 1 trace/0.25s; 1/baseline: 3/0.1s; 2/detailed: 8/0.02s. Gunshots remain audible."
 if IsValid(client) then client:PrintMessage(HUD_PRINTCONSOLE, message) else print(message) end
end)
local oldUnload = P.OnUnload
function P:OnUnload()
 timer.Remove("ixARC9IndoorPolicy")
 concommand.Remove("ix_arc9_sound_mode")
 if oldUnload then oldUnload(self) end
end
