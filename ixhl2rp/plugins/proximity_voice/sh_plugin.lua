local PLUGIN=PLUGIN
PLUGIN.name="Proximity and radio voice"
PLUGIN.author="Hutten"
PLUGIN.description="Spatial voice with existing SCiPNet radio channel access."
ix.voice=ix.voice or {}; local V=ix.voice
ix.config.Add("voiceRange",600,"Proximity voice radius in Source units.",nil,{category="Voice",data={min=100,max=3000}})
ix.config.Add("voiceWallVolume",0.3,"Proximity volume through walls.",nil,{category="Voice",data={min=0,max=1}})
function V.Active(p)
 return IsValid(p) and p:GetCharacter() and p:Alive()
end
function V.CanSpeak(p)
 return V.Active(p) and not p:InCriticalState() and not p:GetLocalVar("knocked",false) and not p:GetNetVar("gagged",false)
end
function V.Position(p)
 if IsValid(p.ixRagdoll) then return p.ixRagdoll:GetPos() end
 return p:GetPos()
end
-- Do not run a second, conflicting copy of the supplied standalone addon.
function V.RemoveStandalone()
 hook.Remove("PlayerCanHearPlayersVoice","EPVC Maximum Voice Range")
 hook.Remove("PlayerStartVoice","EPVC ClientVoiceFilterStart")
 hook.Remove("PlayerEndVoice","EPVC ClientVoiceFilterEnd")
 timer.Remove("Update EPVC")
end
V.RemoveStandalone(); hook.Add("InitPostEntity","ixVoiceRemoveStandalone",V.RemoveStandalone)
ix.util.Include("sv_voice.lua")
ix.util.Include("sv_filter.lua")
ix.util.Include("cl_settings.lua")
if SERVER then resource.AddFile("sound/legends/radio/receiver_static.wav") end
ix.util.Include("cl_effects.lua")
ix.util.Include("cl_voice.lua")
