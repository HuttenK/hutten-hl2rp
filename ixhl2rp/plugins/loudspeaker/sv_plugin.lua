local PLUGIN = PLUGIN
util.AddNetworkString("ix_ls_state2")
util.AddNetworkString("ix_ls_ready2")
function PLUGIN:Initialize()
 self.path = ix.data.Get("ls_sound", "")
 if not ix.BroadcastMedia.ValidSource(self.path, true) then self.path = "" end
 self.loop = ix.data.Get("ls_loop", true)
 self.started = CurTime() -- saved tracks restart; never reuse a previous session's CurTime
end
function PLUGIN:Sync(client)
 net.Start("ix_ls_state2")
 net.WriteString(self.path or "")
 net.WriteDouble(self.started or CurTime())
 net.WriteBool(self.loop ~= false)
 if IsValid(client) then net.Send(client) else net.Broadcast() end
end
net.Receive("ix_ls_ready2", function(_, client)
 if (client.ixLSReadyAt or 0) > CurTime() then return end
 client.ixLSReadyAt = CurTime() + 2
 PLUGIN:Sync(client)
end)
