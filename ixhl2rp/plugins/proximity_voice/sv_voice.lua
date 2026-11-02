local PLUGIN = PLUGIN
local V = ix.voice
function PLUGIN:PlayerCanHearPlayersVoice(listener, talker)
 if not V.Active(listener) or not V.CanSpeak(talker) then return false, false end
 return V.Position(listener):DistToSqr(V.Position(talker)) <= ix.config.Get("voiceRange", 600)^2, true
end
