local P = PLUGIN
P.name = "Manual Music"
P.description = "Administrator-controlled URL music. No automatic soundtrack."
P.author = "Hutten"
-- Replace the former autoplay plugin. Saved ambientToggle values have no effect.
ix.ManualMusic = ix.ManualMusic or {}
local M = ix.ManualMusic
function M.ValidURL(url)
 return isstring(url) and #url <= 2048 and url:match("^https?://[^/%s]+/[^%s]*$") ~= nil
  and not url:find('[%c<>"\']')
end
if SERVER then
 util.AddNetworkString("ixManualMusic")
 function M.Broadcast(client, url)
  if IsValid(client) and not client:IsAdmin() then return false end
  if url ~= "" and not M.ValidURL(url) then
   if IsValid(client) then client:Notify("Use a direct HTTP(S) audio URL, including its path.") end
   return false
  end
  net.Start("ixManualMusic"); net.WriteString(url); net.Broadcast()
  if IsValid(client) then client:Notify(url == "" and "Music stopped for all players." or "Loading music for all players.") end
  return true
 end
 concommand.Add("ix_music_play", function(client, _, args) M.Broadcast(client, args[1]) end)
 concommand.Add("ix_music_stop", function(client) M.Broadcast(client, "") end)
else
 timer.Remove("ixAmbient")
 if P.snd then P.snd:Stop(); P.snd = nil end
 function M.Stop()
  M.request = nil
  if IsValid(M.channel) then M.channel:Stop() end
  M.channel = nil
 end
 M.Stop()
 function M.Play(url)
  M.Stop()
  if url == "" or not M.ValidURL(url) then return end
  local request = {}; M.request = request
  sound.PlayURL(url, "noplay", function(channel, code, message)
   if M.request ~= request then if IsValid(channel) then channel:Stop() end; return end
   if not IsValid(channel) then
    M.request = nil
    print("[Music] Cannot load URL: " .. tostring(code) .. " / " .. tostring(message))
    if ix.util.Notify then ix.util.Notify("Music could not load. Use a direct audio-file URL.") end
    return
   end
   M.channel = channel
   channel:SetVolume(ix.option.Get("manualMusicVolume", .5))
   channel:EnableLooping(false); channel:Play()
  end)
 end
 ix.option.Add("manualMusicVolume", ix.type.number, .5, {category="option.category.music", min=0, max=1, decimals=2,
  OnChanged=function(_, value) if IsValid(M.channel) then M.channel:SetVolume(value) end end})
 net.Receive("ixManualMusic", function() M.Play(net.ReadString()) end)
 hook.Add("ShutDown", "ixManualMusic", M.Stop)
end
ix.command.Add("MusicPlay", {alias="ix_music_play", description="Play a direct audio URL for every connected player.", adminOnly=true, arguments=ix.type.string,
 OnRun=function(_, client, url) if SERVER then M.Broadcast(client, url) end end})
ix.command.Add("MusicStop", {alias="ix_music_stop", description="Stop the server-wide music channel.", adminOnly=true,
 OnRun=function(_, client) if SERVER then M.Broadcast(client, "") end end})
