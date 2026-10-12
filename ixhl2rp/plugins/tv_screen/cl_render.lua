local P,T=PLUGIN,ix.TV
local W,H=1024,576
-- Materials/RTs live until map shutdown. Reuse a bounded slot per channel,
-- including a black powered-off slot and a local diagnostic test card.
T.displays=T.displays or {}
local slots=T.displays
for _,slot in pairs(slots) do slot.frame=nil;slot.ready=false;slot.signature=nil end
hook.Remove("PostDrawOpaqueRenderables","ixTVScreens")
local errors={}
local function report(key,err)
 if err and errors[key]~=err then ErrorNoHalt("[TV display] "..tostring(err).."\n") end
 errors[key]=err
end
function P:TVRefreshInterval(distance)
 local fps=math.Clamp(tonumber(ix.option.Get("tvFrameRate",24)) or 24,10,30)
 if distance>900 then fps=math.min(fps,10) elseif distance>400 then fps=math.min(fps,15) end
 return 1/fps
end
function P:PrepareTVMedia(channels)
 channels=channels or self:TVVisualChannels(self:UpdateTVInterest())
 for id,distance in pairs(channels) do
  local r=self.players[id];local c=self.channels[id]
  local terminal=r and (r.status=="ended" or r.status=="error" or r.status=="blocked")
  if c and c.playing and r and not terminal and not r.suspended and IsValid(r.panel) and r.frame~=FrameNumber() and RealTime()>=(r.nextTexture or 0) then
   r.frame=FrameNumber()
   r.nextTexture=RealTime()+self:TVRefreshInterval(distance)
   self.tvPerf.html=self.tvPerf.html+1
   local ok,err=xpcall(function()
    -- Updating an HTML panel can change render state. Do it before entering
    -- any screen camera/RT. https://wiki.facepunch.com/gmod/Panel:UpdateHTMLTexture
    r.panel:UpdateHTMLTexture()
    r.htmlMat=r.panel:GetHTMLMaterial()
    local texture=r.htmlMat and r.htmlMat:GetTexture("$basetexture")
    if texture and texture:Width()>0 and texture:Height()>0 then
     r.u=math.min(1,W/texture:Width());r.v=math.min(1,H/texture:Height());r.textureAt=RealTime()
    else r.htmlMat=nil end
   end,debug.traceback)
   if not ok then r.htmlMat=nil end
   r.textureSerial=(r.textureSerial or 0)+1
   report("html"..id,not ok and err or nil)
  end
 end
end
local function getSlot(id)
 if slots[id] then return slots[id] end
 local name="ix_tv_display_v4_"..id
 local rt=GetRenderTargetEx(name,W,H,RT_SIZE_NO_CHANGE,MATERIAL_RT_DEPTH_NONE,0,0,IMAGE_FORMAT_RGBA8888)
 local mat=CreateMaterial(name.."_material","UnlitGeneric",{
  ["$basetexture"]=rt:GetName(),["$translucent"]="0",["$vertexcolor"]="1",
  ["$vertexalpha"]="0",["$nocull"]="1",["$ignorez"]="0"
 })
 local slot={target=rt,material=mat};slots[id]=slot;return slot
end
local bars={Color(235,235,235),Color(235,220,40),Color(40,220,220),Color(40,220,70),Color(220,40,220),Color(220,40,40),Color(40,70,220)}
local function testCard()
 for i,color in ipairs(bars) do surface.SetDrawColor(color);surface.DrawRect((i-1)*W/#bars,0,W/#bars+1,H) end
 surface.SetDrawColor(8,13,19,255);surface.DrawRect(0,H*.65,W,H*.35)
 draw.SimpleText("SCiPNET / DISPLAY TEST","ixTVSignal",W/2,H*.72,T.colors.text,TEXT_ALIGN_CENTER)
 draw.SimpleText("ПРОВЕРКА ИЗОБРАЖЕНИЯ","ixTVSignalSmall",W/2,H*.84,T.colors.accent,TEXT_ALIGN_CENTER)
end
function P:TVDisplayKey(screen)
 if (self.tvTestUntil or 0)>RealTime() and LocalPlayer():IsAdmin() then return T.maxChannels+1 end
 if not self:ScreenPowered(screen) then return 0 end
 return T.Number(screen.channel,1,T.maxChannels) and screen.channel or 1
end
function P:PrepareTVDisplay(id)
 local slot=getSlot(id)
 local c=self.channels[id];local r=self.players[id]
 local status=self:GetChannelStatus(id)
 local signature=id==0 and "off" or (id==T.maxChannels+1 and "test" or
  table.concat({status,c and c.name or "",c and c.source or "",tostring(c and c.revision),
   tostring(status=="ready" and r and (r.mat or r.htmlMat)),
   tostring(status=="ready" and r and not r.mat and r.textureSerial or 0)},":"))
 -- Static standby/error/test pages are captured once. Video captures only
 -- follow a new HTML texture, independently of the game's frame rate.
 if slot.ready and slot.signature==signature then return slot end
 slot.signature=signature
 slot.frame=FrameNumber()
 self.tvPerf.captures=self.tvPerf.captures+1
 local clip=DisableClipping(true);local alpha=surface.GetAlphaMultiplier()
 local red,green,blue=render.GetColorModulation();local blend=render.GetBlend()
 render.SetColorModulation(1,1,1);render.SetBlend(1)
 render.PushRenderTarget(slot.target)
 render.Clear(0,0,0,255,false,false)
 cam.Start2D();surface.SetAlphaMultiplier(1)
 local ok,err=xpcall(function()
  if id==T.maxChannels+1 then testCard()
  elseif id>0 then self:PaintChannel(id,W,H) end
 end,debug.traceback)
 if not ok then pcall(T.DrawFailure,W,H,"error","FOUNDATION NETWORK") end
 surface.SetAlphaMultiplier(alpha);cam.End2D()
 render.PopRenderTarget();DisableClipping(clip)
 render.SetColorModulation(red,green,blue);render.SetBlend(blend)
 slot.ready=true;slot.updated=RealTime();slot.error=not ok and err or nil
 report("display"..id,slot.error)
 return slot
end
hook.Add("PreRender","ixTVDisplayTextures",function()
 if ix.CCTV and ix.CCTV.rendering then return end
 if not IsValid(LocalPlayer()) then return end
 local interest=P:UpdateTVInterest()
 P:PrepareTVMedia(P:TVVisualChannels(interest))
 for _,id in ipairs(interest.visible) do
  local saved=P.screens[id]
  if saved then P:PrepareTVDisplay(P:TVDisplayKey(P:DisplayScreen(saved))) end
 end
end)
hook.Add("PostDrawTranslucentRenderables","ixTVScreens",function(depth,sky,sky3d)
 if depth or sky or sky3d then return end
 local red,green,blue=render.GetColorModulation();local blend=render.GetBlend()
 render.SetColorModulation(1,1,1);render.SetBlend(1)
 local ok,err=xpcall(function()
  for _,id in ipairs(P.tvInterest and P.tvInterest.visible or {}) do
   local saved=P.screens[id]
   if saved then
    local s=P:DisplayScreen(saved);local origin,ang,scale,height=T.ScreenPlane(s)
    if origin then
     local slot=slots[P:TVDisplayKey(s)]
     if slot and slot.ready then
      local right,down=ang:Forward()*(1024*scale),ang:Right()*(height*scale)
      render.SetMaterial(slot.material)
      -- An opaque, unlit world quad; no VGUI clipping, browser alpha or nested
      -- HTML updates. Normal depth testing still hides TVs behind walls.
      render.DrawQuad(origin,origin+right,origin+right+down,origin+down,Color(255,255,255))
      P.tvLastWorldDraw=RealTime()
     end
    end
   end
  end
 end,debug.traceback)
 render.SetColorModulation(red,green,blue);render.SetBlend(blend)
 report("world",not ok and err or nil)
end)
concommand.Add("ix_tv_testpattern",function()
 local p=LocalPlayer();if not IsValid(p) or not p:IsAdmin() then return end
 P.tvTestUntil=RealTime()+15
 print("[TV] Local display test for 15 seconds. Server playback/settings are unchanged.")
end)
concommand.Add("ix_tv_diagnose",function()
 local p=LocalPlayer();if not IsValid(p) then return end
 print("[TV] Renderer world-rt-v5 (visibility + capped updates) / last draw: "..tostring(P.tvLastWorldDraw))
 for id,saved in pairs(P.screens) do
  local s=P:DisplayScreen(saved);local pos=T.Transform(s)
  local r=P.players[s.channel];local slot=slots[P:TVDisplayKey(s)]
  local blocked="unbound"
  if pos then
   local tr=util.TraceLine({start=EyePos(),endpos=pos,filter=p,mask=MASK_SOLID})
   blocked=tr.Hit and (tr.HitWorld and "world" or (IsValid(tr.Entity) and tr.Entity:GetModel() or "entity")) or "clear"
  end
  print(string.format("[TV screen %s] channel=%s power=%s position=%s trace=%s media=%s html=%s display=%s error=%s",
   id,tostring(s.channel),tostring(P:ScreenPowered(s)),tostring(pos),blocked,P:GetChannelStatus(s.channel),
   tostring(r and r.htmlMat~=nil),tostring(slot and slot.updated),tostring(slot and slot.error)))
 end
end)
