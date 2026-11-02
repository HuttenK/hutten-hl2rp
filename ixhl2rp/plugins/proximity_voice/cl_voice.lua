local PLUGIN = PLUGIN
local V = ix.voice
local speakers = setmetatable({}, {__mode="k"})
function PLUGIN:PlayerStartVoice(client) speakers[client] = true end
function PLUGIN:PlayerEndVoice(client)
 speakers[client] = nil
 if IsValid(client) then client:SetVoiceVolumeScale(1) end
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
