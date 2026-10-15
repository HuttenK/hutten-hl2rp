local P,T,M=PLUGIN,ix.TV,ix.BroadcastMedia
if P.CleanupTV then P:CleanupTV() end
if P.audio then P.audio:Destroy() end
if IsValid(P.htmlPanel) then P.htmlPanel:Remove() end
for _,name in ipairs({"ix_tv_sound_update","ix_tv_html_volume"}) do hook.Remove("Think",name) end
hook.Remove("PostDrawOpaqueRenderables","ix_tv_screen_render")
P.channels={};P.screens={};P.presets={};P.players={};P.audioAnchors={}
-- Scale the full-volume zone and cutoff together to preserve the falloff curve.
T.audioFullDistance=80/3;T.audioMaxDistance=500/3
P.audio=M.NewAudio("TV",T.audioFullDistance,T.audioMaxDistance);P.tvReady=false
P:ClearTVPlayback()
local statusNames={[0]="loading",[1]="ready",[2]="buffering",[3]="ended",[4]="error",[5]="blocked"}
function P:DropPlayer(id)
 local r=self.players[id]
 if r and IsValid(r.panel) then r.panel:Remove() end
 self.players[id]=nil
end
function P:LoadPlayer(c,attempt)
 self:DropPlayer(c.id)
 local r={revision=c.revision,source=c.source,status="loading",created=RealTime(),attempt=attempt or 1,lastUse=RealTime()}
 self.players[c.id]=r
 if not c.source:match("^https?://") then
  r.mat=Material(c.source);r.status=r.mat:IsError() and "error" or "ready";return r
 end
 local panel=vgui.Create("DHTML");r.panel=panel
 panel:SetSize(1024,576);panel:SetPos(-1100,-700)
 panel:SetMouseInputEnabled(false);panel:SetKeyboardInputEnabled(false);panel:SetAllowLua(false)
 panel.OnDocumentReady=function()
  if P.players[c.id]~=r then return end
  panel:AddFunction("ixTV","playback",function(time,active,code)
   if P.players[c.id]~=r or not IsValid(panel) or not T.Number(time,0,1e9) or not statusNames[code] then return end
   r.status=statusNames[code];r.received=RealTime();r.playback={time=time,active=active==true,received=RealTime()}
  end)
  if r.suspended then panel:RunJavascript("if(window.ixMediaSuspend)window.ixMediaSuspend();") end
 end
 panel:SetHTML(self:BuildTVHTML(c.source))
 return r
end
function P:GetChannelStatus(id)
 local c=self.channels[id];local r=self.players[id]
 if not c then return "missing" end
 if not c.playing or c.source=="" then return "idle" end
 return r and r.status or "loading"
end
local function read() return util.JSONToTable(net.ReadString()) end
net.Receive("ixTVResetState",function()
 for id in pairs(P.players) do P:DropPlayer(id) end
 P.channels={};P.screens={};P.presets={};P.tvReady=true;P:ClearTVPlayback()
 P:ResetTVInterest()
end)
net.Receive("ixTVChannel",function()
 local c=read();if not istable(c) or not T.Number(c.id,1,T.maxChannels) then return end
 local old=P.channels[c.id]
 P.tvInterest=nil
 if c.removed then P.channels[c.id]=nil;P:DropPlayer(c.id);return end
 if old and (old.revision~=c.revision or old.source~=c.source) then P:DropPlayer(c.id) end
 c.cues=M.ParseSubtitles(c.subtitles) or {};P.channels[c.id]=c
 if P.RefreshTVLists then P:RefreshTVLists() end
end)
net.Receive("ixTVScreen",function()
 local s=read();if not istable(s) or not isnumber(s.id) then return end
 P.tvInterest=nil;if P.tvSight then P.tvSight[s.id]=nil end
 if s.removed then
  P.screens[s.id]=nil
  if P.editPreview and P.editPreview.id==s.id then
   P.editPreview=nil
   if IsValid(P.tvWindow) and P.OpenTVAdmin then P:OpenTVAdmin("screens") end
  end
 else P.screens[s.id]=s end
 if P.RefreshTVLists then P:RefreshTVLists() end
end)
net.Receive("ixTVPreset",function() local v=read();if istable(v) and T.Model(v.model) and T.Config(v.config) then P.presets[v.model]=v.config end end)
function P:ScreenPowered(s)
 local pos=T.Transform(s);if not pos then return false end
 local ent=s.entity or Entity(s.entityIndex or -1)
 local blackout=ix.plugin.list.blackout
 if blackout and blackout.IsElectronicsOffAt then return s.on and not blackout:IsElectronicsOffAt(pos,ent) end
 if s.on and ix.Facility and ix.Facility.EntityBackup(ent) then return true end
 return s.on and (not blackout or not blackout:IsPosBlackedOut(pos))
end
function P:DisplayScreen(screen)
 local edited=self.editPreview
 if edited and edited.id==screen.id and IsValid(self.tvWindow) then
  local p=LocalPlayer();if IsValid(p) and p:IsAdmin() then return edited end
 end
 return screen
end
local nextRequest,nextTick=0,0
hook.Add("Think","ixTVChannels",function()
 local p=LocalPlayer();if not IsValid(p) then return end
 if not P.tvReady and CurTime()>=nextRequest then nextRequest=CurTime()+5;net.Start("ixTVReady");net.SendToServer() end
 if RealTime()<nextTick then return end;nextTick=RealTime()+.25
 local interest=P:UpdateTVInterest();local visual=P:TVVisualChannels(interest)
 local needed,distances,sources,anchors={},{},{},{}
 local muted=ix.option.Get("tvMute",false)
 local subtitleID,subtitleDistance=nil,T.audioMaxDistance
 for id in pairs(visual) do
  local c=P.channels[id];if c and c.playing and c.source~="" then needed[id]=true end
 end
 -- Only one external audio source per channel: neighbouring televisions must
 -- not create identical BASS streams. Video sound also uses the nearest TV.
 for id,nearby in pairs(interest.nearby) do
  local s,pos,d=nearby.screen,nearby.pos,nearby.distance;local c=P.channels[id]
  if c and c.playing and P:ScreenPowered(s) then
   distances[id]=d
   if d<subtitleDistance then subtitleID,subtitleDistance=id,d end
   if not muted and (c.volume or 1)>0 then
    if c.sound=="" and c.source~="" then needed[id]=true end
    if c.sound~="" then
     local ent=s.entityIndex and Entity(s.entityIndex)
     -- Different channels on one prop need separate audio keys. Keep one
     -- invisible anchor per channel, following that channel's nearest screen.
     if s.world or (IsValid(ent) and table.Count(ix.PropScreens.IDs(ent,"ixTVScreenID"))>1) then
      ent=P.audioAnchors[id]
      if not IsValid(ent) then ent=ClientsideModel("models/hunter/blocks/cube025x025x025.mdl");if IsValid(ent) then ent:SetNoDraw(true);P.audioAnchors[id]=ent end end
      if IsValid(ent) then ent:SetPos(pos);anchors[id]=true end
     end
     if IsValid(ent) then sources[ent]={path=c.sound,start=c.soundStart or c.start,loop=c.soundLoop,volume=M.Volume(d,T.audioFullDistance,T.audioMaxDistance)*(c.volume or 1)} end
    end
   end
  end
 end
 local total=0
 for id,d in pairs(distances) do local c=P.channels[id];if c.sound=="" then total=total+M.Volume(d,T.audioFullDistance,T.audioMaxDistance)*(c.volume or 1) end end
 for id in pairs(needed) do
  local c=P.channels[id];local r=P.players[id]
  if not r then r=P:LoadPlayer(c) end;r.lastUse=RealTime()
  if r.suspended then r.suspended=nil;r.received=RealTime();r.created=RealTime() end
  if IsValid(r.panel) then
   if RealTime()-r.created>15 and (not r.received or RealTime()-r.received>10) then r.status="error" end
   if (r.status=="error" or r.status=="buffering") and r.attempt<3 and RealTime()-r.created>15*r.attempt then r=P:LoadPlayer(c,r.attempt+1) end
   local volume=c.sound=="" and M.Volume(distances[id] or math.huge,T.audioFullDistance,T.audioMaxDistance)*(c.volume or 1)/math.max(1,total) or 0
   if muted then volume=0 end
   r.panel:RunJavascript("if(window.ixMediaUpdate)window.ixMediaUpdate("..T.Elapsed(c)..","..volume..","..tostring(c.loop==true)..");")
  end
 end
 for id,r in pairs(P.players) do
  if not needed[id] then
   local c=P.channels[id]
   if not c or not c.playing or RealTime()-(r.lastUse or r.created or 0)>=3 then P:DropPlayer(id)
   elseif not r.suspended then
    -- Briefly retain a paused decoder so looking away and back does not
    -- repeatedly reload a URL. Resume seeks to the shared channel clock.
    r.suspended=true
    if IsValid(r.panel) then r.panel:RunJavascript("if(window.ixMediaSuspend)window.ixMediaSuspend();") end
   end
  end
 end
 P.audio:Update(sources)
 for id,ent in pairs(P.audioAnchors) do if not anchors[id] then if IsValid(ent) then ent:Remove() end;P.audioAnchors[id]=nil end end
 local r=subtitleID and P.players[subtitleID]
 P.htmlPanel=r and r.panel or nil;P.tvPlayback=r and r.playback or nil
 P.tvSubtitleCues=subtitleID and P.channels[subtitleID].cues or {};P.tvSubtitleNearby=subtitleID~=nil
end)
function P:PaintChannel(id,w,h)
 local c=self.channels[id];local r=self.players[id];local status=self:GetChannelStatus(id)
 if status~="ready" then T.DrawFailure(w,h,status,c and c.name);return end
 local mat=r and r.mat;local u,v=1,1
 if r and IsValid(r.panel) then
  -- Refreshed in PreRender, never inside a world camera or panel Paint.
  mat=r.htmlMat;u=r.u or 1;v=r.v or 1
 end
 if not mat then T.DrawFailure(w,h,"loading",c.name);return end
 surface.SetDrawColor(255,255,255);surface.SetMaterial(mat);surface.DrawTexturedRectUV(0,0,w,h,0,0,u,v)
end
function P:CleanupTV()
 self.tvTestUntil=nil
 if self.ResetTVInterest then self:ResetTVInterest() end
 for id in pairs(self.players or {}) do self:DropPlayer(id) end
 for _,ent in pairs(self.audioAnchors or {}) do if IsValid(ent) then ent:Remove() end end
 if self.audio then self.audio:Destroy() end
 if IsValid(self.tvWindow) then self.tvWindow:Remove() end
 self:ClearTVPlayback()
end
function P:OnUnload()
 self:CleanupTV()
 hook.Remove("Think","ixTVChannels");hook.Remove("Think","ixTVPlacement");hook.Remove("HUDPaint","ixTVPlacementHUD")
 hook.Remove("PostDrawOpaqueRenderables","ixTVScreens")
 hook.Remove("PostDrawTranslucentRenderables","ixTVScreens")
 hook.Remove("PreRender","ixTVDisplayTextures")
 hook.Remove("CreateMove","ixTVPlacementInput")
 hook.Remove("HUDPaint","ix_tv_subtitle_hud")
end
hook.Add("ShutDown","ix_tv_cleanup",function() P:CleanupTV() end)
ix.option.Add("tvMute",ix.type.bool,false,{category="appearance",phrase="Отключить звук телевизоров"})
concommand.Add("ix_tv_status",function()
 for id,c in pairs(P.channels) do print("[TV "..id.."] "..c.name.." / "..P:GetChannelStatus(id)) end;P.audio:Status()
end)

