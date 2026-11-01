local P,C=PLUGIN,ix.CCTV
for _,name in ipairs({"ixCCTVReady","ixCCTVReset","ixCCTVDevice","ixCCTVOpen","ixCCTVAction","ixCCTVReply","ixCCTVWatch","ixCCTVFeeds"}) do util.AddNetworkString(name) end
local function send(name,v,p)
 if not IsValid(p) then return end
 net.Start(name);net.WriteString(isstring(v) and v or util.TableToJSON(v));net.Send(p)
end
P.subscribers=setmetatable({}, {__mode="k"})
P.deviceVersions=P.deviceVersions or {}
P.networkSnapshots={}
function P:DevicePayload(d)
 local version=self.deviceVersions[d.id] or 0;local cached=self.networkSnapshots[d.id]
 if not cached or cached.version~=version or cached.record~=d then
  cached={version=version,record=d,payload=util.TableToJSON(self:Snapshot(d))};self.networkSnapshots[d.id]=cached
 end
 return cached.payload
end
function P:WatchRecordAllowed(p,id)
 local watch=self.watchers and self.watchers[p]
 if not watch or watch.expires<=CurTime() then return false end
 for _,grant in ipairs(watch.grants or {}) do
  if grant.camera==id then
   if grant.terminal and self:CanWatchBodycamAtTerminal(p,grant.terminal,id) then return true end
   local monitor=self.devices[grant.monitor]
   if monitor and monitor.camera==id and self:CanWatch(p,monitor.id) then return true end
   if grant.monitor==0 then
    local facility=ix.plugin.list.facility_utilities
    if p:IsAdmin() or (facility and facility:CameraPreviewAllowed(p,id)) then return true end
   end
  end
 end
 return false
end
function P:DeviceInterest(p)
 local wanted={};if not IsValid(p) then return wanted end
 local sub=self.subscribers[p];local full=p:IsAdmin() and sub and (sub.adminUntil or 0)>CurTime()
 local eye=p:GetShootPos();local terminals={};local canUse=p:Alive() and p:GetCharacter()
 for id,d in pairs(self.devices or {}) do
  local pos=C.Transform(d)
  if full or (not d.bodycam and pos and pos:DistToSqr(eye)<(C.viewDistance+256)^2) then wanted[id]=true end
  if canUse and d.kind=="terminal" and pos and pos:DistToSqr(eye)<256^2 and self:CanOperate(p,id) then terminals[id]=true;wanted[id]=true end
 end
 local atTerminal=next(terminals)~=nil
 if sub then sub.terminals=terminals;sub.links={} end
 for id,d in pairs(self.devices or {}) do
  if (atTerminal and d.kind=="camera") or terminals[d.terminal] then wanted[id]=true end
  if wanted[id] and d.kind=="monitor" and self.devices[d.camera] then
   wanted[d.camera]=true
   if sub then sub.links[d.camera]=sub.links[d.camera] or {};sub.links[d.camera][id]=true end
  end
 end
 -- Console previews can be distant without granting the whole registry.
 local watch=self.watchers and self.watchers[p]
 if watch and watch.expires>CurTime() then
  for _,grant in ipairs(watch.grants or {}) do
   if self:WatchRecordAllowed(p,grant.camera) then wanted[grant.camera]=true end
  end
 end
 return wanted
end
function P:RefreshSubscriber(p)
 local sub=self.subscribers[p];if not sub or not IsValid(p) then return end
 local wanted=self:DeviceInterest(p)
 for id in pairs(sub.known) do
  if not wanted[id] or not self.devices[id] then send("ixCCTVDevice",{id=id,removed=true},p);sub.known[id]=nil end
 end
 for id in pairs(wanted) do
  local d=self.devices[id];local version=self.deviceVersions[id] or 0
  if d and sub.known[id]~=version then send("ixCCTVDevice",self:DevicePayload(d),p);sub.known[id]=version end
 end
end
function P:SendDevice(d,p)
 self.deviceVersions[d.id]=(self.deviceVersions[d.id] or 0)+1
 local function update(client,sub)
  if not IsValid(client) then return end
  local allowed=client:IsAdmin() and (sub.adminUntil or 0)>CurTime()
  local pos=C.Transform(d)
  allowed=allowed or (not d.bodycam and pos and pos:DistToSqr(client:GetShootPos())<(C.viewDistance+256)^2)
  if not allowed then
   for terminal in pairs(sub.terminals or {}) do
    if (d.kind=="camera" or d.terminal==terminal) and self:CanOperate(client,terminal) then allowed=true;break end
   end
  end
  if not allowed and d.kind=="camera" then
   for monitor in pairs(sub.links and sub.links[d.id] or {}) do
    local m=self.devices[monitor];local location=m and C.Transform(m)
    if m and m.camera==d.id and location and location:DistToSqr(client:GetShootPos())<(C.viewDistance+256)^2 then allowed=true;break end
   end
   allowed=allowed or self:WatchRecordAllowed(client,d.id)
  end
  if allowed then
   send("ixCCTVDevice",self:DevicePayload(d),client);sub.known[d.id]=self.deviceVersions[d.id]
   -- Switching a nearby monitor needs its newly selected distant camera now.
   local camera=d.kind=="monitor" and self.devices[d.camera]
   if camera then
    sub.links=sub.links or {};sub.links[camera.id]=sub.links[camera.id] or {};sub.links[camera.id][d.id]=true
    if sub.known[camera.id]~=(self.deviceVersions[camera.id] or 0) then send("ixCCTVDevice",self:DevicePayload(camera),client);sub.known[camera.id]=self.deviceVersions[camera.id] or 0 end
   end
  elseif sub.known[d.id] then send("ixCCTVDevice",{id=d.id,removed=true},client);sub.known[d.id]=nil end
 end
 if IsValid(p) then local sub=self.subscribers[p];if sub then update(p,sub) end
 else for client,sub in pairs(self.subscribers) do update(client,sub) end end
end
function P:SendRemoved(id)
 self.deviceVersions[id]=nil
 self.networkSnapshots[id]=nil
 for p,sub in pairs(self.subscribers) do
  if sub.known[id] then send("ixCCTVDevice",{id=id,removed=true},p);sub.known[id]=nil end
 end
end
function P:Sync(p)
 self:Ensure()
 if not IsValid(p) then for client in pairs(self.subscribers) do self:Sync(client) end;return end
 local old=self.subscribers[p]
 self.subscribers[p]={known={},adminUntil=old and old.adminUntil}
 send("ixCCTVReset",{presets=p:IsAdmin() and self.surfacePresets or {}},p)
 self:RefreshSubscriber(p)
end
-- Discovery is bounded and independent of a client claiming visibility. A
-- newly arrived viewer is sent initial state; leaving revokes cached records.
local cursor=0
local function interestTick()
 local clients=player.GetAll();local count=#clients;if count==0 then return end
 for _=1,math.min(4,count) do
  cursor=cursor%count+1;P:RefreshSubscriber(clients[cursor])
 end
end
timer.Create("ixCCTVSubscriptions",.1,0,interestTick)
function P:SendOpen(p,mode,id,kind) send("ixCCTVOpen",{mode=mode,id=id or 0,kind=kind},p) end
function P:OpenAdmin(p,kind,id)
 if not IsValid(p) or not p:IsAdmin() then return end
 self.subscribers[p]=self.subscribers[p] or {known={}};self.subscribers[p].adminUntil=CurTime()+3
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
 local sub=P.subscribers[p]
 if sub then sub.adminUntil=p:IsAdmin() and v.admin==true and CurTime()+2 or nil end
 local feeds,grants=P:ResolveWatch(p,v)
 P.watchers[p]={grants=grants,expires=CurTime()+1.5}
 P:RefreshSubscriber(p)
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
function P:PlayerDisconnected(p) if self.watchers then self.watchers[p]=nil end;self.subscribers[p]=nil end
