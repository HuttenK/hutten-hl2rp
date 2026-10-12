local P,T=PLUGIN,ix.TV
-- Visibility controls expensive browser/texture work, not the server's broadcast
-- clock. A listener can still hear a nearby television while looking away.
function P:ResetTVInterest()
 self.tvInterest=nil;self.tvSight={};self.tvTraceAt=0;self.tvTraceBudget=0
end
function P:TVView()
 -- Player view avoids taking the camera from a reflection or another RenderView.
 local v=render.GetViewSetup(false) or {}
 local p=LocalPlayer()
 local angle=v.angles or EyeAngles()
 return {pos=v.origin or EyePos(),forward=angle:Forward(),right=angle:Right(),up=angle:Up(),
  fov=v.fov or (IsValid(p) and p:GetFOV() or 90),aspect=v.aspect or ScrW()/math.max(1,ScrH())}
end
function T.InTVView(center,radius,view)
 local delta=center-view.pos;local depth=delta:Dot(view.forward)
 if depth < -radius then return false end
 local horizontal=math.tan(math.rad(math.Clamp(view.fov,1,175))*.5)
 local vertical=horizontal/math.max(.25,view.aspect)
 -- Sphere against the four view planes, with a small edge margin. This also
 -- handles large screens whose centre is just outside the camera's frustum.
 return math.abs(delta:Dot(view.right)) <= depth*horizontal+radius*math.sqrt(1+horizontal*horizontal)+12
  and math.abs(delta:Dot(view.up)) <= depth*vertical+radius*math.sqrt(1+vertical*vertical)+12
end
function P:TVLineOfSight(s,pos,ang,view,cache)
 local now=RealTime()
 if cache.nextCheck and now<cache.nextCheck and cache.pos:DistToSqr(pos)<1
  and cache.eye:DistToSqr(view.pos)<64*64 and cache.w==s.config.w and cache.h==s.config.h then return cache.visible end
 -- Bound traces even when many screens face the same corridor. Untested
 -- screens are checked oldest-first on subsequent passes, never all at once.
 if self.tvTraceBudget<5 then return cache.visible==true end
 local parent=not s.world and (s.entity or Entity(s.entityIndex or -1))
 local filter={LocalPlayer()};if IsValid(parent) then filter[#filter+1]=parent end
 local right,down=ang:Forward()*(s.config.w*.48),ang:Right()*(s.config.h*.48)
 local points={pos,pos-right-down,pos+right-down,pos+right+down,pos-right+down}
 local visible=false
 for _,point in ipairs(points) do
  self.tvTraceBudget=self.tvTraceBudget-1
  self.tvPerf.traces=self.tvPerf.traces+1
  local tr=util.TraceLine({start=view.pos,endpos=point,mask=MASK_VISIBLE,filter=filter})
  if not tr.Hit then visible=true;break end
 end
 cache.visible=visible;cache.nextCheck=now+(visible and .3 or .6)
 cache.pos=pos;cache.eye=view.pos;cache.w=s.config.w;cache.h=s.config.h
 return visible
end
function P:UpdateTVInterest(force)
 local now=RealTime();local view=self:TVView();local old=self.tvInterest
 local range=math.Clamp(tonumber(ix.option.Get("tvDrawDistance",2000)) or 2000,500,3000)
 if not force and old and now<old.nextScan and old.screens==self.screens and old.range==range
  and not IsValid(self.tvWindow) and old.view.pos:DistToSqr(view.pos)<16*16
  and old.view.forward:Dot(view.forward)>.999 and old.view.fov==view.fov and old.view.aspect==view.aspect then return old end
 self.tvPerf=self.tvPerf or {traces=0,html=0,captures=0,since=now}
 self.tvSight=self.tvSight or {}
 if now>=(self.tvTraceAt or 0) then self.tvTraceAt=now+.1;self.tvTraceBudget=24 end
 local interest={view=view,range=range,nextScan=now+.1,screens=self.screens,visible={},channels={},nearby={},count=0}
 local candidates,existing={},{}
 local listener=LocalPlayer():GetPos()
 for id,saved in pairs(self.screens) do
  interest.count=interest.count+1;existing[id]=true
  local s=self:DisplayScreen(saved)
  local ent=not s.world and (s.entity or Entity(s.entityIndex or -1))
  -- Dormant prop transforms are stale; world-mounted screens use the checks below.
  if s.world or (IsValid(ent) and not ent:IsDormant()) then
   local pos,ang=T.Transform(s)
   if pos then
    local distance=pos:Distance(view.pos);local audioDistance=pos:Distance(listener)
    local c=self.channels[s.channel]
    if c and c.playing and self:ScreenPowered(s) and audioDistance<T.audioMaxDistance then
     local nearest=interest.nearby[s.channel]
     if not nearest or audioDistance<nearest.distance then interest.nearby[s.channel]={screen=s,pos=pos,distance=audioDistance} end
    end
    local radius=math.sqrt(s.config.w*s.config.w+s.config.h*s.config.h)*.5
    if distance<=range+radius and T.InTVView(pos,radius,view) then
     local cache=self.tvSight[id] or {};self.tvSight[id]=cache
     candidates[#candidates+1]={id=id,screen=s,pos=pos,ang=ang,distance=distance,cache=cache}
    end
   end
  end
 end
 for id in pairs(self.tvSight) do if not existing[id] then self.tvSight[id]=nil end end
 table.sort(candidates,function(a,b)
  local at,bt=a.cache.nextCheck or 0,b.cache.nextCheck or 0
  if at==bt then return a.distance<b.distance end;return at<bt
 end)
 for _,v in ipairs(candidates) do
  if self:TVLineOfSight(v.screen,v.pos,v.ang,view,v.cache) then
   interest.visible[#interest.visible+1]=v.id
   if self:ScreenPowered(v.screen) then
    local id=v.screen.channel
    interest.channels[id]=math.min(interest.channels[id] or math.huge,v.distance)
   end
  end
 end
 self.tvInterest=interest
 return interest
end
function P:TVVisualChannels(interest)
 local channels={}
 for id,d in pairs(interest.channels) do channels[id]=d end
 if IsValid(self.tvWindow) and self.previewChannel then channels[self.previewChannel]=0 end
 return channels
end
ix.option.Add("tvFrameRate",ix.type.number,24,{category="option.category.performance",min=10,max=30,decimals=0,phrase="Частота обновления ТВ"})
ix.option.Add("tvDrawDistance",ix.type.number,2000,{category="option.category.performance",min=500,max=3000,decimals=0,phrase="Дальность экранов ТВ"})
concommand.Add("ix_tv_perf",function()
 if not IsValid(LocalPlayer()) then return end
 local interest=P:UpdateTVInterest(true);local perf=P.tvPerf;local seconds=math.max(1,RealTime()-perf.since)
 local active,parked=0,0
 for _,r in pairs(P.players) do if IsValid(r.panel) then if r.suspended then parked=parked+1 else active=active+1 end end end
 print(string.format("[TV] screens=%d visible=%d / browsers active=%d paused=%d / cap=%s FPS, range=%s",
  interest.count,#interest.visible,active,parked,tostring(ix.option.Get("tvFrameRate",24)),tostring(interest.range)))
 print(string.format("[TV] Last %.1fs: HTML updates=%d (%.1f/s), display captures=%d (%.1f/s), visibility traces=%d (%.1f/s)",
  seconds,perf.html,perf.html/seconds,perf.captures,perf.captures/seconds,perf.traces,perf.traces/seconds))
 P.tvPerf={traces=0,html=0,captures=0,since=RealTime()}
end)
