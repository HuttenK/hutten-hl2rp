local PLUGIN = PLUGIN
local V = ix.voice
function PLUGIN:PlayerCanHearPlayersVoice(listener, talker)
 if not V.Active(listener) or not V.CanSpeak(talker) then return false, false end
 return V.Position(listener):DistToSqr(V.Position(talker)) <= ix.config.Get("voiceRange", 600)^2, true
end

-- The engine draws the overhead icon separately from the client's voice HUD.
local function hideOverheadIcons()
 local icons = GetConVar("mp_show_voice_icons")
 if icons and icons:GetBool() then RunConsoleCommand("mp_show_voice_icons", "0") end
end
hook.Add("InitPostEntity", "ixVoiceHideEngineIcons", hideOverheadIcons)
timer.Create("ixVoiceHideEngineIcons", 2, 0, hideOverheadIcons)
