local P, N = PLUGIN, ix.FoundationNet
if N.FullscreenMapGate then N.FullscreenMapGate.Stop() end
local G = {}
N.FullscreenMapGate = G
local fullscreen, original, stopped
local function blocked() return false end

function G.Apply()
 if stopped then return end
 local current = DynamicMinimap and DynamicMinimap.Fullscreen
 if not current or not isfunction(current.Open) then return end
 if current == fullscreen and current.Open == blocked then return end
 if fullscreen and fullscreen.Open == blocked then fullscreen.Open = original end
 fullscreen, original = current, current.Open
 -- All native entry points (configured key, dm_map and spawnmenu) use Open.
 -- The terminal calls Renderer.DrawScene directly and does not need this UI.
 if isfunction(current.IsOpen) and current.IsOpen() and isfunction(current.Close) then current.Close() end
 current.Open = blocked
end

G.Apply()
hook.Add("InitializedPlugins", "FoundationTerminalMapAccess", G.Apply)
hook.Add("InitPostEntity", "FoundationTerminalMapAccess", G.Apply)
hook.Add("OnReloaded", "FoundationTerminalMapAccess", function()
 timer.Simple(0, G.Apply)
end)

function G.Stop()
 stopped = true
 if fullscreen and fullscreen.Open == blocked then fullscreen.Open = original end
 for _, event in ipairs({"InitializedPlugins", "InitPostEntity", "OnReloaded"}) do
  hook.Remove(event, "FoundationTerminalMapAccess")
 end
end

local previousUnload = P.OnUnload
function P:OnUnload()
 G.Stop()
 if previousUnload then previousUnload(self) end
end
