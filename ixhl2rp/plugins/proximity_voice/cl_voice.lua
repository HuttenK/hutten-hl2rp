local PLUGIN = PLUGIN
local V = ix.voice
local speakers = setmetatable({}, {__mode="k"})
function PLUGIN:PlayerStartVoice(client)
 if IsValid(client) then speakers[client] = true end
 return true -- The base gamemode would create a VoiceNotify card with the speaker's name.
end
function PLUGIN:PlayerEndVoice(client)
 if IsValid(client) then
  speakers[client] = nil
  client:SetVoiceVolumeScale(1)
 end
end
function PLUGIN:HUDShouldDraw(name)
 if name == "CHudVoiceSelfStatus" then return false end
end
timer.Create("ixVoiceOcclusion", .2, 0, function()
 local listener = LocalPlayer()
 for talker in pairs(speakers) do
  if not IsValid(talker) then speakers[talker] = nil
  elseif not V.Active(listener) then talker:SetVoiceVolumeScale(1)
  elseif talker ~= listener and not talker:IsMuted() then
   local trace = util.TraceLine({start=listener:EyePos(), endpos=talker:EyePos(), filter={listener,talker}, mask=MASK_SOLID_BRUSHONLY})
   local volume = trace.Hit and ix.config.Get("voiceWallVolume", .3) or 1
   talker:SetVoiceVolumeScale(talker:WaterLevel() == 3 and volume * .5 or volume)
  end
 end
end)
