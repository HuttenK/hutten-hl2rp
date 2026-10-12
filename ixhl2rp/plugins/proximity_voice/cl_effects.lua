local V=ix.voice
local noise, pending, desired, serial = nil, false, 0, 0
local retryAt=0
local affected={}
function V.StopRadioEffects()
 desired=0; serial=serial+1; pending=false
 if IsValid(noise) then noise:Stop() end
 noise=nil
 for p in pairs(affected) do if IsValid(p) then p:SetVoiceVolumeScale(1) end end
 affected={}
end
function V.RadioEffectGain(p,amount,now)
 local phase=now*8+p:EntIndex()*2.17
 local flutter=(math.sin(phase)+1)*.5
 local dip=math.max(0,math.sin(now*3.7+p:EntIndex())-.92)*3
 return math.Clamp(1-amount*(.18+.2*flutter+dip),.45,1)
end
function V.UpdateRadioEffects(listener,speakers,routes)
 if not V.Active(listener) then V.StopRadioEffects(); return end
 local amount=math.Clamp(tonumber(ix.option.Get("radioInterference",.35)) or .35,0,1)
 local receiving=false
 local now=RealTime()
 for p in pairs(affected) do
  local r=routes[p]
  if not speakers[p] or not IsValid(p) or p:IsMuted() or not r or r.mode~=2 or now-r.at>=2 or amount==0 then
   if IsValid(p) then p:SetVoiceVolumeScale(1) end
   affected[p]=nil
  end
 end
 for p in pairs(speakers) do
  local r=routes[p]
  if p~=listener and IsValid(p) and not p:IsMuted() and r and r.mode==2 and now-r.at<2 and amount>0 then
   receiving=true; affected[p]=true
   p:SetVoiceVolumeScale(V.RadioEffectGain(p,amount,now))
  end
 end
 local voiceScale=GetConVar("voice_scale")
 desired=receiving and amount*.12*math.Clamp(voiceScale and voiceScale:GetFloat() or 1,0,1) or 0
 if desired<=0 then
  if IsValid(noise) or pending then
   serial=serial+1; pending=false
   if IsValid(noise) then noise:Stop() end
   noise=nil
  end
  return
 end
 if IsValid(noise) then noise:SetVolume(desired); return end
 if pending or now<retryAt then return end
 pending=true; serial=serial+1
 local request=serial
 sound.PlayFile("sound/legends/radio/receiver_static.wav","noplay",function(channel)
  if request~=serial then if IsValid(channel) then channel:Stop() end; return end
  pending=false
  if not IsValid(channel) then retryAt=RealTime()+10; return end
  if desired<=0 then channel:Stop(); return end
  noise=channel; channel:SetVolume(desired); channel:EnableLooping(true); channel:Play()
 end)
end
hook.Add("ShutDown","ixRadioEffectsStop",V.StopRadioEffects)
