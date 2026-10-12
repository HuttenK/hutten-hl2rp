local P,C=PLUGIN,ix.CCTV
for _,name in ipairs({"ixCCTVReady","ixCCTVReset","ixCCTVDevice","ixCCTVOpen","ixCCTVAction","ixCCTVReply","ixCCTVWatch","ixCCTVFeeds"}) do util.AddNetworkString(name) end
local function send(name,v,p)
 net.Start(name);net.WriteString(util.TableToJSON(v))
 if IsValid(p) then net.Send(p) else net.Broadcast() end
end
function P:SendDevice(d,p) send("ixCCTVDevice",self:Snapshot(d),p) end
function P:SendRemoved(id) send("ixCCTVDevice",{id=id,removed=true}) end
function P:Sync(p)
 self:Ensure();send("ixCCTVReset",{presets=self.surfacePresets or {}},p)
 for _,d in pairs(self.devices) do self:SendDevice(d,p) end
end
function P:SendOpen(p,mode,id,kind) send("ixCCTVOpen",{mode=mode,id=id or 0,kind=kind},p) end
function P:OpenAdmin(p,kind,id)
 if not IsValid(p) or not p:IsAdmin() then return end
 self:Sync(p);self:SendOpen(p,"admin",id,kind)
end
local function limited(p,key,delay)
 local now=CurTime();if (p[key] or 0)>now then return true end;p[key]=now+delay
end
net.Receive("ixCCTVReady",function(_,p) if not limited(p,"ixCCTVReadyAt",3) then P:Sync(p) end end)
net.Receive("ixCCTVAction",function(bits,p)
 if bits>4096*8 or limited(p,"ixCCTVActionAt",.15) then return end
 local raw=util.JSONToTable(net.ReadString());if not istable(raw) then return end
 local ok,message,id=P:Action(p,raw.action,raw.data)
 send("ixCCTVReply",{ok=ok==true,message=message,screen=id},p)
end)
function P:CanWatch(p,id)
 local d=self.devices[id]
 if not d or d.kind~="monitor" or not IsValid(d.entity) or not C.Powered(d) then return false end
 local pos,ang,width=C.Screen(d)
 if not pos or pos:DistToSqr(p:GetShootPos())>C.viewDistance^2 then return false end
 return C.Visible(p,pos,d.entity) or C.Visible(p,pos+ang:Forward()*width*.45,d.entity)
end
function P:CanWatchBodycamAtTerminal(p,terminal,id)
 if not C.ID(terminal) or not C.ID(id) or not self:CanOperate(p,terminal) then return false end
 local camera=self.devices[id]
 return camera and camera.kind=="camera" and camera.bodycam==true and IsValid(camera.entity) and C.Powered(camera)==true
end
function P:ResolveWatch(p,v)
 self:Ensure();local feeds,grants,seen={},{},{}
 if not p:Alive() or not p:GetCharacter() then return feeds,grants end
 local function add(id,monitor,terminal)
  local camera=self.devices[id]
  if seen[id] or #feeds>=C.maxFeeds or not camera or camera.kind~="camera" or not C.Powered(camera) or not IsValid(camera.entity) then return end
  local pos,ang=C.Lens(camera);if not pos or not util.IsInWorld(pos) then return end
  seen[id]=true;grants[#grants+1]={camera=id,monitor=monitor,terminal=terminal}
  feeds[#feeds+1]={id=id,pos={x=pos.x,y=pos.y,z=pos.z},ang={p=ang.p,y=ang.y,r=ang.r},fov=camera.fov,name=camera.name,
   bodycam=camera.bodycam==true,ownerIndex=camera.bodycam and camera.entity:EntIndex() or nil,
   recognition=self.RecognitionSnapshot and self:RecognitionSnapshot(camera,pos,ang,camera.fov) or nil}
 end
 -- This grant belongs to a physically accessible control terminal, not to
 -- the administrator preview path. Recheck it on every PVS pass below.
 local terminal=istable(v.terminal) and v.terminal
 if terminal and self:CanWatchBodycamAtTerminal(p,terminal.id,terminal.camera) then add(terminal.camera,nil,terminal.id) end
 -- A door console grants only its selected linked camera for a short session.
 local facility=ix.plugin.list.facility_utilities
 if C.ID(v.preview) and (p:IsAdmin() or (facility and facility:CameraPreviewAllowed(p,v.preview))) then add(v.preview,0) end
 for i=1,math.min(C.maxFeeds,istable(v.monitors) and #v.monitors or 0) do
  local id=v.monitors[i];if C.ID(id) and self:CanWatch(p,id) then add(self.devices[id].camera,id) end
 end
 return feeds,grants
end
net.Receive("ixCCTVWatch",function(bits,p)
 if bits>2048*8 or limited(p,"ixCCTVWatchAt",.4) then return end
 local v=util.JSONToTable(net.ReadString());if not istable(v) then return end
 local feeds,grants=P:ResolveWatch(p,v)
 P.watchers[p]={grants=grants,expires=CurTime()+1.5}
 send("ixCCTVFeeds",feeds,p)
end)
function P:SetupPlayerVisibility(p)
 self:Ensure();local watch=self.watchers[p]
 if not watch or watch.expires<CurTime() or not p:Alive() or not p:GetCharacter() then return end
 for _,grant in ipairs(watch.grants) do
  local camera=self.devices[grant.camera];local monitor=self.devices[grant.monitor]
  local facility=ix.plugin.list.facility_utilities
  local allowed=grant.monitor==0 and (p:IsAdmin() or (facility and facility:CameraPreviewAllowed(p,grant.camera)))
  if grant.terminal then allowed=self:CanWatchBodycamAtTerminal(p,grant.terminal,grant.camera) end
  if monitor and monitor.camera==grant.camera and C.Powered(monitor) and IsValid(monitor.entity) then
   allowed=self:CanWatch(p,monitor.id)
  end
  if allowed and camera and IsValid(camera.entity) and C.Powered(camera) then
   local pos=C.Lens(camera);if pos and util.IsInWorld(pos) then AddOriginToPVS(pos) end
  end
 end
end
function P:PlayerDisconnected(p) if self.watchers then self.watchers[p]=nil end end
