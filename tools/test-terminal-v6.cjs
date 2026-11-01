const fs=require('fs'),path=require('path');
module.exports=function(suite){
const geometry=fs.readFileSync(path.join(__dirname,'geometry-fixture.lua'),'utf8');
const rig=JSON.parse(fs.readFileSync(path.join(__dirname,'sectorial-hand-rig.json'),'utf8')).bones;
const rigSetup='rig={}\n'+rig.map(b=>`rig[${b.id}]={name=${JSON.stringify(b.name)},parent=${b.parent},pos=Vector(${b.position}),rotation=Vector(${b.rotation})}`).join('\n');
const {normalize}=require('./glua.cjs');
const hooks=fs.readFileSync(path.join(__dirname,'../helix/gamemode/core/hooks/sh_hooks.lua'),'utf8');
const translate='function GM:TranslateActivity'+hooks.split('function GM:TranslateActivity')[1].split('\nif SERVER then')[0];
const resolver='function ix.anim.ResolveMainSequence'+fs.readFileSync(path.join(__dirname,'../helix/gamemode/core/libs/sh_arc9poses.lua'),'utf8').split('function ix.anim.ResolveMainSequence')[1];
suite('PDA integrates with Helix activity translation without raised/combat replacement', ['ixhl2rp/plugins/site_pda/sh_pose.lua'],`
 local p={GetTable=function(s) return s end,IsWepRaised=function() return raised end,OnGround=function() return true end,InVehicle=function() return false end,
 GetActiveWeapon=function() return weapon end,GetNetVar=function() end,GetLocalVar=function(_,k,d) return d end,LookupSequence=function() return sequence end,
 SelectWeightedSequence=function() error('Neutral named sequence must not use random combat activity') end}
 for _,value in ipairs({false,true}) do
  raised=value
  for _,class in ipairs({'player','cellarMale','citizen_male'}) do
   p.ixAnimModelClass=class;sequence=42
   eq(GM:TranslateActivity(p,ACT_MP_STAND_IDLE),nil);eq(ix.anim.ResolveMainSequence(p,nil,p.CalcSeqOverride),42)
   sequence=0;GM:TranslateActivity(p,ACT_MP_STAND_IDLE);eq(ix.anim.ResolveMainSequence(p,nil,p.CalcSeqOverride),0)
  end
 end
 `,`GM={};ix.anim={};ix.Fieldlink={class='pdaremake1'};ACT_MP_STAND_IDLE=1;ACT_MP_WALK=2;ACT_MP_RUN=3;ACT_MP_CROUCH_IDLE=4;ACT_MP_CROUCHWALK=5
 weapon={valid=true,GetClass=function() return 'pdaremake1' end};`+normalize(translate)+normalize(resolver));
suite('Manual music denies non-admins, rejects invalid URLs, and broadcasts only explicit play/stop', ['ixhl2rp/plugins/ambientmusic/sh_plugin.lua'],`
 local M=ix.ManualMusic
 local user={valid=true,IsAdmin=function() return false end,Notify=function() end}
 eq(M.Broadcast(user,'https://example.com/song.mp3'),false);eq(sent,0)
 user.IsAdmin=function() return true end
 for _,url in ipairs({'ftp://host/song','https://host/a b','https://host/a\\n','file:///secret'}) do eq(M.Broadcast(user,url),false) end
 assert(M.Broadcast(user,'https://example.com/song.mp3?token=abc%20x'));eq(sent,1)
 assert(M.Broadcast(user,''));eq(sent,2);eq(payload,'')
 assert(commands.MusicPlay.adminOnly and commands.MusicStop.adminOnly)
 eq(commands.MusicPlay.alias,'ix_music_play');eq(commands.MusicStop.alias,'ix_music_stop')
 user.IsAdmin=function() return false end
 commands.MusicPlay:OnRun(user,'https://example.com/song.mp3');eq(sent,2)
 user.IsAdmin=function() return true end
 commands.MusicPlay:OnRun(user,'https://example.com/song.mp3');eq(sent,3)
 commands.MusicStop:OnRun(user);eq(sent,4);eq(payload,'')
 `,`commands={};ix.command={Add=function(n,v) commands[n]=v end};ix.type={string=1};concommand={Add=function() end};sent=0;net.Start=function() end;net.WriteString=function(v) payload=v end;net.Broadcast=function() sent=sent+1 end`);
suite('Manual music cancels stale asynchronous loads, never loops, and stops only its channel', ['ixhl2rp/plugins/ambientmusic/sh_plugin.lua'],`
 local M=ix.ManualMusic
 eq(#loads,0);M.Play('https://host/a.mp3');M.Play('https://host/b.ogg');eq(#loads,2)
 local stale=channel();loads[1](stale);assert(stale.stopped);eq(stale.played,nil)
 local live=channel();loads[2](live);assert(live.played);eq(live.loop,false);eq(live.volume,.5)
 M.Stop();assert(live.stopped);eq(M.channel,nil)
 M.Play('https://host/c.mp3');M.Stop();local late=channel();loads[3](late);assert(late.stopped)
 `,`SERVER=false;CLIENT=true;loads={};sound={PlayURL=function(url,flags,fn) eq(flags,'noplay');loads[#loads+1]=fn end};concommand={Add=function() end};ix.command={Add=function() end};ix.type={string=1,number=2};ix.option={Add=function() end,Get=function() return .5 end};hook.Add=function() end
 function channel() return {valid=true,Stop=function(s) s.stopped=true end,Play=function(s) s.played=true end,EnableLooping=function(s,v) s.loop=v end,SetVolume=function(s,v) s.volume=v end} end`);
suite('Menu theme fades in, stops on close, cancels late loads and leaves manual gameplay music untouched', [
 'ixhl2rp/plugins/zz_legends_interface/cl_menu.lua','ixhl2rp/plugins/ambientmusic/sh_plugin.lua'],`
 eq(#loads,0)
 local manual=channel();ix.ManualMusic.channel=manual
 local function panel()
  local p=setmetatable({valid=true},{__index=registered})
  p.CreateAnimation=function(s,duration,animation) eq(duration,2);s.fade=animation end
  p.Remove=function(s) s:OnRemove();s.valid=false end
  return p
 end
 local menu=panel();ix.gui.characterMenu=menu
 menu:PlayMusic();menu:PlayMusic();eq(#loads,1);eq(loads[1].path,'sound/maintheme.mp3')
 local playing=channel();loads[1].fn(playing);eq(menu.channel,playing);eq(playing.volume,0);eq(playing.loop,true);eq(playing.played,true)
 menu.volume=menu.fade.target.volume;menu.fade.Think(nil,menu);eq(playing.volume,.25)
 menu:PlayMusic();eq(#loads,1)
 menu:Close();eq(playing.stopped,true);eq(menu.channel,nil);eq(manual.stopped,nil)
 menu:PlayMusic();eq(#loads,1)
 local pending=panel();pending:PlayMusic();pending:Close()
 local late=channel();loads[2].fn(late);eq(late.stopped,true);eq(late.played,nil)
 fallback=true;local nextMenu=panel();nextMenu:PlayMusic();eq(loads[3].path,'sound/music/maintheme.mp3')
 loads[3].fn(nil);eq(nextMenu.musicRequest,nil);nextMenu:PlayMusic();eq(#loads,4)
 local nextChannel=channel();loads[4].fn(nextChannel);nextMenu:OnRemove();eq(nextChannel.stopped,true)
 eq(ix.ManualMusic.channel,manual);eq(manual.stopped,nil)
 `,`SERVER=false;CLIENT=true;loads={};fallback=false
 ix.gui={};ix.Legends={Scale=function(n) return n end,T=function(en) return en end}
 vgui={Register=function(_,panel) registered=panel end};gui={EnableScreenClicker=function() end}
 file={Exists=function(p) return fallback and p=='sound/music/maintheme.mp3' or not fallback and p=='sound/maintheme.mp3' end}
 sound={PlayFile=function(path,flags,fn) eq(flags,'noplay');loads[#loads+1]={path=path,fn=fn} end,PlayURL=function() error('No automatic URL music') end}
 ix.config.Get=function() error('Old saved HL2 theme must not replace the menu soundtrack') end
 concommand={Add=function() end};ix.command={Add=function() end};ix.type={string=1,number=2}
 ix.option={Add=function() end,Get=function() return .5 end};hook.Add=function() end
 function channel() return {valid=true,Stop=function(s) s.stopped=true end,Play=function(s) s.played=true end,EnableLooping=function(s,v) s.loop=v end,SetVolume=function(s,v) s.volume=v end} end
 `);
suite('PDA neutral sequence selection bypasses random/combat idles and preserves forced/crawl/vehicle poses', ['ixhl2rp/plugins/site_pda/sh_pose.lua'],`
 local p={OnGround=function() return true end,InVehicle=function() return vehicle end,GetActiveWeapon=function() return weapon end,GetLocalVar=function(_,k,d) return d end,GetNetVar=function() return forced end,LookupSequence=function(_,name) return name=='idle_all_01' and 42 or -1 end}
 eq(ix.Fieldlink.PDABaseSequence(p,ACT_MP_STAND_IDLE),42)
 forced=true;eq(ix.Fieldlink.PDABaseSequence(p,ACT_MP_STAND_IDLE),nil);forced=nil
 vehicle=true;eq(ix.Fieldlink.PDABaseSequence(p,ACT_MP_STAND_IDLE),nil);vehicle=false
 crawling=true;eq(ix.Fieldlink.PDABaseSequence(p,ACT_MP_STAND_IDLE),nil)
 `,`ACT_MP_STAND_IDLE=1;ACT_MP_WALK=2;ACT_MP_RUN=3;ACT_MP_CROUCH_IDLE=4;ACT_MP_CROUCHWALK=5
 ix.Fieldlink={class='pdaremake1'};ix.Downed={Crawling=function() return crawling end};weapon={valid=true,GetClass=function() return 'pdaremake1' end}`);
suite('PDA full bone build uses the actual SD skeleton: palm facing, limb lengths, finger lengths and parent transforms', ['ixhl2rp/plugins/site_pda/cl_holding.lua'],`
 local F=ix.Fieldlink;local bones={},{};local ids={}
 for i=0,#rig do
  local b=rig[i];ids[b.name]=i;local m=Matrix()
  m:SetAngles(Angle(math.deg(b.rotation.y),math.deg(b.rotation.z),math.deg(b.rotation.x)));m:SetTranslation(b.pos)
  bones[i]=b.parent>=0 and bones[b.parent]*m or m
 end
 -- Decompiled SMD faces -Y; studiomdl's default compile orientation faces +X.
 local compile=Matrix();compile:SetAngles(Angle(0,90,0))
 for id,m in pairs(bones) do bones[id]=compile*m end
 local original={};for id,m in pairs(bones) do original[id]=Matrix(m:ToTable()) end
 local p={valid=true,Alive=function() return true end,InVehicle=function() return false end,
  GetLocalVar=function(_,k,d) return d end,GetNetVar=function() end,GetModel=function() return 'sectorialdistrict/citizen_male_04_hair4.mdl' end,
  GetActiveWeapon=function() return weapon end,GetRenderAngles=function() return Angle(0,0,0) end,
  GetBoneCount=function() return #rig+1 end,GetBoneName=function(_,id) return rig[id].name end,GetBoneParent=function(_,id) return rig[id].parent end,
  LookupBone=function(_,name) return ids[name] end,GetBoneMatrix=function(_,id) return bones[id] end,SetBoneMatrix=function(_,id,m) bones[id]=m end,
  AddCallback=function(_,event,fn) boneCallback=fn;return 7 end,RemoveCallback=function() removed=true end}
 player.GetAll=function() return {p} end;callbacks.Think();assert(F.holdingStates[p]);boneCallback(p)
 local angle=F.PDAReadingAngle(p);local prefix='ValveBiped.Bip01_'
 for _,side in ipairs({'R','L'}) do
  local u,e,h=ids[prefix..side..'_UpperArm'],ids[prefix..side..'_Forearm'],ids[prefix..side..'_Hand']
  near(bones[u]:GetTranslation():Distance(bones[e]:GetTranslation()),original[u]:GetTranslation():Distance(original[e]:GetTranslation()))
  near(bones[e]:GetTranslation():Distance(bones[h]:GetTranslation()),original[e]:GetTranslation():Distance(original[h]:GetTranslation()))
  -- The transformed local elbow actually meets the solved elbow; copying Euler
  -- roll cannot satisfy this for rigs whose bone X axes differ from the segment.
  local localElbow=original[u]:GetInverse()*original[e]:GetTranslation()
  near((bones[u]*localElbow):Distance(bones[e]:GetTranslation()),0)
  local f,_,n=F.PDAPalmBasis(bones[h]:GetTranslation(),bones[ids[prefix..side..'_Finger1']]:GetTranslation(),bones[ids[prefix..side..'_Finger2']]:GetTranslation(),bones[ids[prefix..side..'_Finger4']]:GetTranslation())
  if side=='R' then n=-n end
  assert(n:Dot(angle:Up()*(side=='R' and 1 or -1))>.999)
  for finger=0,4 do
   local a,b,c=ids[prefix..side..'_Finger'..finger],ids[prefix..side..'_Finger'..finger..'1'],ids[prefix..side..'_Finger'..finger..'2']
   near(bones[a]:GetTranslation():Distance(bones[b]:GetTranslation()),original[a]:GetTranslation():Distance(original[b]:GetTranslation()))
   near(bones[b]:GetTranslation():Distance(bones[c]:GetTranslation()),original[b]:GetTranslation():Distance(original[c]:GetTranslation()))
  end
 end
 -- No torso/leg rewrites and no stale callback when leaving the pose.
 for _,name in ipairs({'Pelvis','Spine','Spine1','Spine2','R_Thigh','L_Calf'}) do local id=ids[prefix..name];near(bones[id]:GetTranslation():Distance(original[id]:GetTranslation()),0);near(bones[id]:GetForward():Distance(original[id]:GetForward()),0);near(bones[id]:GetUp():Distance(original[id]:GetUp()),0) end
 weapon.GetClass=function() return 'gun' end;callbacks.Think();assert(removed);eq(F.holdingStates[p],nil)
 -- Degenerate and unreachable IK targets remain finite with exact bone lengths.
 for _,goal in ipairs({Vector(),Vector(100,0,0),Vector(0,0,18)}) do local e,h=F.SolvePDAArm(Vector(),goal,Vector(0,0,1),10,9);near(e:Length(),10);near(e:Distance(h),9) end
 `,geometry+rigSetup+`
 CLIENT=true;SERVER=false;callbacks={};hook.Add=function(n,k,fn) callbacks[n]=fn end
 ix.Fieldlink={class='pdaremake1'};concommand={Add=function() end}
 weapon={valid=true,GetClass=function() return 'pdaremake1' end,GetPDAFraction=function() return 1 end,GetNW2Float=function() return 0 end}
 `);
suite('BSP sections preserve rooms; map preparation is CPU-only and opaque strokes paint directly in VGUI', ['ixhl2rp/plugins/foundation_network/cl_map.lua'],`
 local N=ix.FoundationNet
 local v={Vector(0,0,0),Vector(100,0,0),Vector(100,0,100),Vector(0,0,100)}
 local a,b=N.MapSection(v,48);near(a.z,48);near(b.z,48);near(a:Distance(b),100)
 eq(N.MapSection(v,101),nil)
 local ca,cb=N.MapClipHeight(Vector(0,0,-100),Vector(0,0,200),0,48);near(ca.z,0);near(cb.z,48)
 eq(N.MapClipHeight(Vector(0,0,100),Vector(20,0,100),0,48),nil)
 local x1,y1,x2,y2=N.MapClipLine(-100,50,200,50,100,100);near(x1,0);near(x2,100)
 eq(N.MapClipLine(-20,-20,-10,-10,100,100),nil)
 local face={GetMaterial=function() return {GetName=function() return 'brick/wall' end} end,GetVertices=function() return v end}
 surfaces={};for i=1,300 do surfaces[i]=face end
 local g=N.BeginMapGeometry();N.StepMapGeometry(g);eq(g.next,129);assert(not g.ready)
 N.StepMapGeometry(g);N.StepMapGeometry(g);assert(g.ready);eq(#g.faces,300);eq(#g.edges,4)
 local p=setmetatable({valid=true,SetTall=function() end,GetTall=function() return 620 end,GetWide=function() return 1724 end},{__index=mapPanel})
 p:Init();p:SetData({origin={0,0,0},name='fixture',zones={},terminals={}});assert(not p.threeD and p.cutaway)
 local before=p.center;p:OnSurfaceDrag(100,30,1);assert(p.center:Distance(before)>1)
 p:Home();p:Floor(1);eq(p.center.z,128);p:Floor(-1)
 N.RenderMap(p);assert(p.mapReady);eq(lines,0);eq(p.mapView.width,1724);eq(p.mapView.height,550)
 eq(N.mapRT,nil);eq(N.mapMaterial,nil)
 local view=p.mapView;N.RenderMap(p);eq(p.mapView,view)
 inPaint=true;N.PaintMap(p,1724,620);inPaint=false
 assert(lines>0 and brightStrokes>0);assert(background);eq(background.r,5);eq(background.g,13);eq(background.b,20);eq(background.a,255)
 -- A faded paint cannot permanently darken cached strokes; the next Paint uses
 -- the same opaque vertex colours without a texture or a geometry rebuild.
 brightStrokes=0;inPaint=true;N.PaintMap(p,1724,620);inPaint=false;assert(brightStrokes>0);eq(p.mapView,view)
 local project=N.MapProject;N.MapProject=function() error('projection fixture failure') end
 clock=clock+1;p.dirty=true;N.RenderMap(p);assert(p.renderError);assert(p.dirty);eq(p.mapView,view)
 N.MapProject=project;clock=clock+1;N.RenderMap(p);assert(p.mapReady);eq(p.renderError,nil)
 for _,mode in ipairs({false,true}) do
  p.threeD=mode;p.cutaway=false;p.orbitZoom=32;p:OnSurfaceDrag(40,20,2);clock=clock+1
  N.RenderMap(p);assert(p.mapReady)
  for _,g in ipairs(p.mapView.groups) do for i,v in ipairs(g.quads) do assert(v>=0 and v<=(i%2==1 and 1724 or 550)) end end
 end
 `,geometry+`
 CLIENT=true;SERVER=false;ix.FoundationNet={mapRT={},mapMaterial={}};surface={};lines=0;brightStrokes=0
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end;function RealTime() return clock end;function SysTime() return clock end
 vgui={Register=function(_,p) mapPanel=p end};game={GetMap=function() return 'fixture' end,GetWorld=function() return {GetBrushSurfaces=function() return surfaces end} end}
 local function noTexturePass() error('Map must not create or sample an intermediate render target') end
 GetRenderTarget=noTexturePass;CreateMaterial=noTexturePass
 render={PushRenderTarget=noTexturePass,PopRenderTarget=noTexturePass,Clear=noTexturePass}
 cam={Start2D=noTexturePass,End2D=noTexturePass};surface.SetMaterial=noTexturePass;surface.DrawTexturedRectUV=noTexturePass
 surface.SetDrawColor=function(r,g,b,a) assert(inPaint);ink=type(r)=='table' and r or Color(r,g,b,a) end
 surface.DrawRect=function(x,y,w,h) assert(inPaint);if w==1724 and h==620 then background=ink end end
 surface.DrawLine=function() assert(inPaint);lines=lines+1 end
 surface.DrawPoly=function(points) assert(inPaint);lines=lines+1;eq(#points,4);if ink.r>=193 and ink.a==255 then brightStrokes=brightStrokes+1 end end
 draw={SimpleText=function() assert(inPaint) end,NoTexture=function() assert(inPaint) end};MOUSE_LEFT=1;MOUSE_RIGHT=2
 `);
};
