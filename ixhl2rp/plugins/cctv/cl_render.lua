local P,C=PLUGIN,ix.CCTV
local W,H=320,180
-- Reuse a fixed pool. Source RT allocations cannot be freed during a map.
C.slots=C.slots or {}
for _,s in pairs(C.slots) do s.camera=nil;s.updated=nil;s.recognition=nil end
C.rendering=false
local white=Color(255,255,255);local accent=Color(92,229,201)
surface.CreateFont("ixCCTVSmall",{font="Tahoma",size=12,weight=600,extended=true})
surface.CreateFont("ixCCTVTitle",{font="Tahoma",size=21,weight=700,extended=true})
function C.FitText(text,font,width)
 surface.SetFont(font)
 while surface.GetTextSize(text)>width and text:utf8len()>1 do text=text:utf8sub(1,text:utf8len()-2).."…" end
 return text
end
function P:UpdateInterest()
 if (self.nextInterest or 0)>RealTime() then return end;self.nextInterest=RealTime()+.15
 local v=render.GetViewSetup(false) or {};local eye=v.origin or EyePos();local ang=v.angles or EyeAngles()
 local fov=math.Clamp(v.fov or 100,1,175);local tan=math.tan(math.rad(fov*.5));local aspect=v.aspect or ScrW()/ScrH()
 local candidates={}
 for id,saved in pairs(self.devices) do
  local d=self.editSurface and self.editSurface.id==id and self.editSurface or saved
  if d.kind~="camera" then
   local pos,a,w,h,ent=C.Screen(d)
   if pos and IsValid(ent) and not ent:IsDormant() and pos:DistToSqr(eye)<C.viewDistance^2 then
    local delta=pos-eye;local depth=delta:Dot(ang:Forward());local r=math.sqrt(w*w+h*h)*.5
    if depth>-r and math.abs(delta:Dot(ang:Right()))<depth*tan+r*math.sqrt(1+tan*tan)
     and math.abs(delta:Dot(ang:Up()))<depth*tan/aspect+r*math.sqrt(1+(tan/aspect)^2) then
     candidates[#candidates+1]={id=id,pos=pos,ang=a,w=w,h=h,ent=ent,distance=delta:Length()}
    end
   end
  end
 end
 table.sort(candidates,function(a,b)
  local at=(self.sight[a.id] or {}).untilTime or 0;local bt=(self.sight[b.id] or {}).untilTime or 0
  if at==bt then return a.distance<b.distance end;return at<bt
 end)
 local visible={};local traces=0
 for _,v in ipairs(candidates) do
  local cache=self.sight[v.id] or {};self.sight[v.id]=cache
  if (cache.untilTime or 0)<RealTime() and traces<16 then
   local filter={LocalPlayer(),v.ent}
   cache.visible=not util.TraceLine({start=eye,endpos=v.pos,filter=filter,mask=MASK_VISIBLE}).Hit;traces=traces+1
   if not cache.visible and traces<16 then
    cache.visible=not util.TraceLine({start=eye,endpos=v.pos+v.ang:Forward()*v.w*.45,filter=filter,mask=MASK_VISIBLE}).Hit;traces=traces+1
   end
   cache.untilTime=RealTime()+.45
  end
  if cache.visible then visible[#visible+1]=v end
 end
 table.sort(visible,function(a,b) return a.distance<b.distance end)
 self.visible={};for _,v in ipairs(visible) do self.visible[#self.visible+1]=v.id end
end
local function createSlot(index)
 local s=C.slots[index];if s then return s end
 -- Power-of-two backing, low-resolution viewport and explicit UVs. Separate
 -- depth prevents camera rendering from clearing the main view's depth buffer.
 local target=GetRenderTargetEx("ix_cctv_feed_v1_"..index,512,256,RT_SIZE_NO_CHANGE,MATERIAL_RT_DEPTH_SEPARATE,0,0,IMAGE_FORMAT_RGBA8888)
 s={target=target,material=CreateMaterial("ix_cctv_feed_mat_v1_"..index,"UnlitGeneric",{
  ["$basetexture"]=target:GetName(),["$vertexcolor"]="1",["$translucent"]="0",["$nocull"]="1"})}
 C.slots[index]=s;return s
end
function P:FeedSlot(id)
 for _,s in pairs(C.slots) do if s.camera==id then return s end end
end
function P:BodycamOwner(feed)
 local d=feed and self.devices[feed.id]
 if not feed or feed.bodycam~=true or not d or d.bodycam~=true or d.kind~="camera" or d.id~=feed.id then return end
 local owner=Entity(feed.ownerIndex or -1)
 local current=d.entity or Entity(d.entityIndex or -1)
 if IsValid(owner) and owner==current and owner:EntIndex()==feed.ownerIndex and C.Powered(d) then return owner end
end
local function unavailable(slot)
 slot.updated=nil;slot.owner=nil;slot.recognition=nil;slot.unavailable=true;slot.lastTry=RealTime()
end
function P:CaptureFeed(feed,slot)
 local origin,angles=C.Vector(feed.pos),C.Angle(feed.ang)
 local device=self.devices[feed.id];local owner
 if feed.bodycam or (device and device.bodycam) then
  owner=self:BodycamOwner(feed)
  if not owner then unavailable(slot);return end
  -- PVS may still be arriving, or the wearer may have disappeared since the
  -- grant. Never turn old server coordinates into apparently live footage.
  local position,angle=ix.bodycams.Lens(owner)
  origin,angles=C.Vector(position),C.Angle(angle)
  if not origin or not angles then unavailable(slot);return end
 end
 local oldClip=DisableClipping(true);local blend=render.GetBlend();local r,g,b=render.GetColorModulation()
 render.SetBlend(1);render.SetColorModulation(1,1,1)
 render.PushRenderTarget(slot.target,0,0,W,H);render.Clear(0,0,0,255,true,true)
 C.rendering=true;C.captureOwner=owner
 local ok,err=xpcall(function()
  render.RenderView({origin=origin,angles=angles,x=0,y=0,w=W,h=H,
   fov=feed.fov or 75,aspectratio=W/H,znear=2,zfar=10000,drawviewmodel=false,drawhud=false,dopostprocess=false})
  slot.recognition=self.CaptureRecognition and self:CaptureRecognition(feed,origin,angles,owner) or nil
 end,debug.traceback)
 C.rendering=false;C.captureOwner=nil;render.PopRenderTarget();DisableClipping(oldClip)
 render.SetBlend(blend);render.SetColorModulation(r,g,b)
 slot.updated=ok and RealTime() or nil;slot.owner=ok and owner or nil;slot.unavailable=not ok
 slot.error=not ok and err or nil;slot.lastTry=RealTime()
 if not ok then slot.recognition=nil end
 if not ok and slot.lastError~=err then ErrorNoHalt("[CCTV] "..tostring(err).."\n") end;slot.lastError=err
 self.captureCount=(self.captureCount or 0)+1
end
local nextCapture=0
hook.Add("PostRender","ixCCTVFeeds",function()
 if C.rendering or RealTime()<nextCapture or not IsValid(LocalPlayer()) then return end
 -- At most 16 world renders/s TOTAL and 8 per camera. Four active feeds share
 -- the budget, and duplicate monitors use the very same texture.
 local valid={}
 for id,feed in pairs(P.feeds) do
  if P.demand[id] and RealTime()-feed.received<1.5 and RealTime()-feed.first>.2 then valid[id]=feed end
 end
 for _,s in pairs(C.slots) do if not valid[s.camera] then s.camera=nil;s.updated=nil;s.recognition=nil end end
 local selected,chosen,oldest=nil,nil,math.huge
 for id,feed in pairs(valid) do
  local slot=P:FeedSlot(id)
  if not slot then for i=1,C.maxFeeds do local candidate=createSlot(i);if not candidate.camera then slot=candidate;slot.camera=id;slot.updated=nil;slot.lastTry=nil;break end end end
  if slot and RealTime()-(slot.lastTry or -1)>.125 and (slot.lastTry or -1)<oldest then selected=feed;chosen=slot;oldest=slot.lastTry or -1 end
 end
 if selected then nextCapture=RealTime()+1/16;P:CaptureFeed(selected,chosen) end
end)
function P:PaintFeed(id,w,h,caption,x,y)
 x,y=x or 0,y or 0
 local d=self.devices[id];local feed=self.feeds[id];local slot=self:FeedSlot(id)
 local powered=d and C.Powered(d)
 if (d and d.bodycam) or (feed and feed.bodycam) then
  local owner=self:BodycamOwner(feed)
  if not owner or (slot and slot.owner~=owner) then
   if slot then slot.updated=nil;slot.owner=nil;slot.unavailable=true end
   powered=false
  end
 end
 local live=powered and feed and RealTime()-feed.received<1.5 and slot and slot.updated and RealTime()-slot.updated<2
 surface.SetDrawColor(4,13,17,255);surface.DrawRect(x,y,w,h)
 if live then
  surface.SetDrawColor(205,234,222,255);surface.SetMaterial(slot.material)
  -- Letterbox the 16:9 feed inside a 4:3 physical monitor.
  local height=math.min(h,w*H/W);local width=height*W/H
  surface.DrawTexturedRectUV(x+(w-width)/2,y+(h-height)/2,width,height,0,0,W/512,H/256)
  if self.PaintRecognition then self:PaintRecognition(feed,slot,x+(w-width)/2,y+(h-height)/2,width,height) end
 else
  draw.SimpleText(d and (powered and not (slot and slot.unavailable) and "ПОДКЛЮЧЕНИЕ" or "НЕТ СИГНАЛА") or "НЕТ КАМЕРЫ","ixCCTVTitle",x+w/2,y+h/2,accent,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 surface.SetDrawColor(1,9,12,85);for line=0,h,4 do surface.DrawRect(x,y+line,w,1) end
 surface.SetDrawColor(3,12,16,230);surface.DrawRect(x,y,w,22);surface.DrawRect(x,y+h-20,w,20)
 draw.SimpleText(C.FitText(caption or (d and d.name) or "CCTV","ixCCTVSmall",w-16),"ixCCTVSmall",x+8,y+4,accent)
 draw.SimpleText(live and "LIVE  /  320 × 180" or "SCiPNET / CCTV","ixCCTVSmall",x+8,y+h-17,white)
 draw.SimpleText(os.date("%H:%M:%S"),"ixCCTVSmall",x+w-8,y+h-17,accent,TEXT_ALIGN_RIGHT)
end
function P:DrawScreen(d)
 d=self.editSurface and self.editSurface.id==d.id and self.editSurface or d
 local center,a,w,h=C.Screen(d);if not center then return end
 local origin=center-a:Forward()*w/2-a:Right()*h/2
 local width=320
 local clip=DisableClipping(true);local alpha=surface.GetAlphaMultiplier()
 local blend=render.GetBlend();local r,g,b=render.GetColorModulation()
 render.SetBlend(1);render.SetColorModulation(1,1,1);surface.SetAlphaMultiplier(1)
 cam.Start3D2D(origin,a,w/width)
 local height=h/(w/width)
 local ok,err=xpcall(function()
  if not C.Powered(d) then surface.SetDrawColor(0,0,0);surface.DrawRect(0,0,width,height)
  elseif d.kind=="monitor" then self:PaintFeed(d.camera,320,height,d.name.." / "..(self.devices[d.camera] and self.devices[d.camera].name or "—"))
  else surface.SetDrawColor(2,8,12);surface.DrawRect(0,0,width,height)
  end
 end,debug.traceback)
 cam.End3D2D()
 if ok and d.kind=="terminal" and C.Powered(d) then
  local point,angle,scale=C.TerminalGeometry(d)
  if point then
   cam.Start3D2D(point,angle,scale)
   ok,err=xpcall(function() self:PaintTerminal(d,C.terminalWidth,C.terminalHeight) end,debug.traceback)
   cam.End3D2D()
  end
 end
 surface.SetAlphaMultiplier(alpha);DisableClipping(clip)
 render.SetBlend(blend);render.SetColorModulation(r,g,b)
 if not ok and self.screenError~=err then self.screenError=err;ErrorNoHalt(err.."\n") end
end
hook.Add("PostDrawTranslucentRenderables","ixCCTVScreens",function(depth,sky,sky3d)
 if C.rendering or depth or sky or sky3d then return end
 for _,id in ipairs(P.visible) do local d=P.devices[id];if d then P:DrawScreen(d) end end
end)
hook.Add("ShouldDrawLocalPlayer","ixCCTVLocalPlayer",function() if C.rendering then return true end end)
-- Suppress the camera wearer only for this capture, without changing entity
-- NoDraw, bones or main-view state. https://wiki.facepunch.com/gmod/GM:PrePlayerDraw
hook.Add("PrePlayerDraw","ixCCTVHelmetWearer",function(p) if C.rendering and C.captureOwner==p then return true end end)
concommand.Add("ix_cctv_status",function()
 print(string.format("[CCTV] devices=%d visible screens=%d permitted feeds=%d captures=%d / 320x180 / max 16 captures/s total",
  table.Count(P.devices),#P.visible,table.Count(P.feeds),P.captureCount or 0))
end)
