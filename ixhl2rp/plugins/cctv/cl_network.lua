local P,C=PLUGIN,ix.CCTV
if P.CloseTerminalUI then P:CloseTerminalUI() end
if IsValid(P.window) then P.window:Remove() end
if IsValid(P.ghost) then P.ghost:Remove() end
P.devices={};P.feeds={};P.visible={};P.demand={};P.sight={};P.ready=false;P.surfacePresets={}
local function read() return util.JSONToTable(net.ReadString()) end
net.Receive("ixCCTVReset",function()
 local data=read();P.devices={};P.feeds={};P.ready=true;P.nextInterest=0
 P.surfacePresets=istable(data) and istable(data.presets) and data.presets or {}
end)
net.Receive("ixCCTVDevice",function()
 local d=read();if not istable(d) or not C.ID(d.id) then return end
 if d.removed then
  P.devices[d.id]=nil;P.feeds[d.id]=nil
  if P.terminalViews then P.terminalViews[d.id]=nil end
 else P.devices[d.id]=d end
 P.nextInterest=0;P.sight[d.id]=nil
 if IsValid(P.window) then P.window.refresh=true end
end)
net.Receive("ixCCTVOpen",function()
 local v=read();if not istable(v) then return end
 if v.mode=="admin" and LocalPlayer():IsAdmin() then
  if v.kind then P:BeginPlacement(v.kind) else P:OpenAdminUI(v.id) end
 elseif v.mode=="terminal" then P:OpenTerminalUI(v.id) end
end)
net.Receive("ixCCTVReply",function()
 local v=read();if not istable(v) then return end
 if v.ok and C.ID(v.screen) then P:EndPlacement();P:OpenSurfaceEditor(v.screen) end
 if P.terminalUI then
  P.terminalUI.state.message=v.message or "";P.terminalUI.state.messageUntil=RealTime()+4
  return
 end
 if IsValid(P.window) and IsValid(P.window.status) then P.window.status:SetText(v.message or "") end
 if not v.ok or not IsValid(P.window) then LocalPlayer():Notify(v.message or "") end
end)
net.Receive("ixCCTVFeeds",function()
 local values=read();if not istable(values) then return end
 local feeds={}
 for i=1,math.min(C.maxFeeds,#values) do
  local v=values[i]
  if istable(v) and C.ID(v.id) and C.Vector(v.pos) and C.Angle(v.ang) then
   local old=P.feeds[v.id];v.received=RealTime();v.first=old and old.first or RealTime()
   feeds[v.id]=v
  end
 end
 P.feeds=feeds
end)
function P:Request(action,data)
 if (self.nextAction or 0)>RealTime() then return end;self.nextAction=RealTime()+.2
 net.Start("ixCCTVAction");net.WriteString(util.TableToJSON({action=action,data=data}));net.SendToServer()
end
function P:ClientCanUseTerminal(id)
 local p=LocalPlayer();local d=self.devices[id]
 return IsValid(p) and p:Alive() and p:GetCharacter() and d and d.kind=="terminal" and C.Powered(d) and C.TerminalReach(p,d)
end
local nextReady,nextWatch=0,0
hook.Add("Think","ixCCTVClient",function()
 if C.rendering then return end
 local p=LocalPlayer();if not IsValid(p) then return end
 if not P.ready and RealTime()>nextReady then nextReady=RealTime()+3;net.Start("ixCCTVReady");net.SendToServer() end
 P:UpdateInterest()
 if IsValid(P.window) and P.window.terminal and not P:ClientCanUseTerminal(P.window.terminal) then P.window:Remove() end
 if P.terminalUI and not P:ClientCanUseTerminal(P.terminalUI.id) then P:CloseTerminalUI() end
 local monitors,seen={},{}
 local terminal=P.TerminalBodycamPreview and P:TerminalBodycamPreview()
 local count=0
 if terminal then seen[terminal.camera]=true;count=1 end
 local preview=IsValid(P.window) and p:IsAdmin() and P.preview or 0
 preview=preview or 0
 if preview==0 and ix.Facility and ix.Facility.GetPreviewCamera then preview=ix.Facility.GetPreviewCamera() end
 if preview~=0 and not seen[preview] then seen[preview]=true;count=count+1 end
 for _,id in ipairs(P.visible) do
  local d=P.devices[id]
  if d and d.kind=="monitor" and d.camera~=0 and C.Powered(d) and not seen[d.camera] and count<C.maxFeeds then
   monitors[#monitors+1]=id;seen[d.camera]=true;count=count+1
  end
 end
 P.demand=seen
 -- Rebuild interest every Think so leaving a page stops capture immediately.
 -- Network refreshes remain bounded; changed selections are sent as soon as
 -- the server's watch rate limit permits, then refreshed every 0.6 seconds.
 local key=table.concat(monitors,",")..":"..tostring(preview)..":"..(terminal and terminal.id.."/"..terminal.camera or "")
 if RealTime()<nextWatch and (P.lastWatchKey==key or RealTime()<(P.watchSentAt or 0)+.45) then return end
 nextWatch=RealTime()+.6
 if count>0 or P.lastWatchKey~=key then
  net.Start("ixCCTVWatch");net.WriteString(util.TableToJSON({monitors=monitors,preview=preview,terminal=terminal}));net.SendToServer()
  P.watchSentAt=RealTime()
 end
 P.lastWatchKey=key
end)
function P:OnUnload()
 self:CloseTerminalUI()
 if IsValid(self.window) then self.window:Remove() end
 if IsValid(self.ghost) then self.ghost:Remove() end
 self.feeds={};self.demand={};C.rendering=false;C.captureOwner=nil
 for event,name in pairs({Think="ixCCTVClient",PostRender="ixCCTVFeeds",PostDrawTranslucentRenderables="ixCCTVScreens",HUDPaint="ixCCTVPlacement",CreateMove="ixCCTVPlacement"}) do hook.Remove(event,name) end
 hook.Remove("ShouldDrawLocalPlayer","ixCCTVLocalPlayer");hook.Remove("PostDrawTranslucentRenderables","ixCCTVGhost")
 hook.Remove("PrePlayerDraw","ixCCTVHelmetWearer")
 hook.Remove("CreateMove","ixCCTVTerminalInput")
 hook.Remove("HUDPaint","ixCCTVSurfaceGuide")
end
