local PLUGIN = PLUGIN
local M = ix.BroadcastMedia
if PLUGIN.audio then PLUGIN.audio:Destroy() end
for _, channel in pairs(PLUGIN.lsChannels or {}) do if IsValid(channel) then channel:Stop() end end
PLUGIN.lsChannels = nil
PLUGIN.audio = M.NewAudio("Loudspeaker", 400, 2100)
local cache, refresh, ready, requestAt = {}, 0, false, 0
local path, started, loop = "", 0, true
net.Receive("ix_ls_state2", function()
 path, started, loop = net.ReadString(), net.ReadDouble(), net.ReadBool()
 ready = true
end)
hook.Add("Think", "ix_ls_sound_update", function()
 if not ready and IsValid(LocalPlayer()) and CurTime() >= requestAt then
  requestAt = CurTime() + 5; net.Start("ix_ls_ready2"); net.SendToServer()
 end
 if CurTime() >= refresh then cache = ents.FindByModel(PLUGIN.speakerModel); refresh = CurTime() + 2 end
 local sources = {}
 if IsValid(LocalPlayer()) and path ~= "" then
  for _, ent in ipairs(cache) do
   if M.Powered(ent) then
    sources[ent] = {path=path, start=started, loop=loop,
     volume=M.Volume(LocalPlayer():GetPos():Distance(ent:GetPos()),400,2100)}
   end
  end
 end
 PLUGIN.audio:Update(sources)
end)
function PLUGIN:OnUnload()
 self.audio:Destroy(); hook.Remove("Think", "ix_ls_sound_update")
 net.Receive("ix_ls_state2", function() end)
end
hook.Add("ShutDown", "ix_ls_cleanup", function() PLUGIN.audio:Destroy() end)
concommand.Add("ix_loudspeaker_status", function() print("[Loudspeaker] received="..tostring(ready)); PLUGIN.audio:Status() end)
