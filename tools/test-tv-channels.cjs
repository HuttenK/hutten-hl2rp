const fs=require('fs');
const {normalize}=require('./glua.cjs');
module.exports=runSuite=>{
 // include() returns only from that Lua file. A plain do/end wrapper lets
 // realm guards return from the entire test before any assertions execute.
 const suite=(name,files,assertions,setup='')=>{
  const includes=files.map(file=>'do local function includeFile()\n'+normalize(fs.readFileSync(file,'utf8'))+'\nend; includeFile() end').join('\n');
  runSuite(name,[],includes+'\n'+assertions,setup);
 };
 const basics=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','helix/gamemode/core/libs/sh_broadcastmedia.lua','ixhl2rp/plugins/tv_screen/sh_state.lua'];
 const server=[...basics,'ixhl2rp/plugins/tv_screen/sv_plugin.lua'];
 suite('TV channels migrate media without autoplay, isolate changes, validate access and retain programme state',server,`
  local P,T=PLUGIN,ix.TV
  stored.tv_material='https://example.com/old.webm';stored.tv_sound='music/old.mp3'
  P:Initialize();eq(table.Count(P.channels),4);eq(P.channels[1].playing,false)
  eq(P.channels[1].source,stored.tv_material);eq(P.channels[1].start,10)
  local p=admin();p.admin=false
  eq(P:Action(p,'play',{channel=2,source='https://example.com/test.webm'}),false)
  p.admin=true
  eq(P:Action(p,'play',{channel=2,source='https://youtube.com/watch?v=123'}),false)
  eq(P:Action(p,'play',{channel=2,source='javascript:alert(1)'}),false)
  assert(P:Action(p,'play',{channel=2,source='https://example.com/test.webm'}))
  eq(P.channels[1].playing,false);eq(P.channels[2].playing,true)
  local start=P.channels[2].start
  assert(P:Action(p,'play',{channel=2,source='https://example.com/test.webm'}));assert(P.channels[2].start>start)
  assert(P:Action(p,'loop',{channel=2,value=true}));eq(P.channels[1].loop,false)
  eq(P:Action(p,'volume',{channel=2,value=0/0}),false)
  eq(P:Action(p,'volume',{channel=2,value=math.huge}),false)
  assert(P:Action(p,'volume',{channel=2,value=.3}));eq(P.channels[2].volume,.3)
  assert(P:Action(p,'sound',{channel=3,source='https://example.com/sound.mp3',loop=true}))
  eq(P.channels[3].playing,true);eq(P.channels[2].sound,'')
  assert(P:Action(p,'stop',{channel=2}));eq(P.channels[3].playing,true)
  P.tvInitialized=false;clock=100;P:Initialize()
  eq(P.channels[3].playing,false);eq(P.channels[2].volume,.3);eq(P.channels[2].loop,true)
  eq(P.channels[2].source,'https://example.com/test.webm')
  local old=#net.packets;net.handlers.ixTVReady(0,p);assert(#net.packets>old);old=#net.packets
  net.handlers.ixTVReady(0,p);eq(#net.packets,old)
 `);
 suite('TV placement uses authoritative traces, centres the plane, preserves model presets and restores bindings',server,`
  local P,T=PLUGIN,ix.TV;P:Initialize()
  local p=admin();p.trace={Hit=true,HitWorld=true,HitPos=Vector(100,0,64),HitNormal=Vector(-1,0,0)}
  local ok,_,id=P:Action(p,'place',{channel=2,preset=true});assert(ok)
  local s=P.screens[id];assert(s.world);eq(s.channel,2)
  local pos,ang=T.Transform(s);vectorNear(pos,Vector(99.65,0,64));vectorNear(ang:Up(),Vector(-1,0,0))
  eq(T.AimScreen(p,P.screens,220),s)
  p.dir=Vector(0,1,0);eq(T.AimScreen(p,P.screens,220),nil);p.dir=Vector(1,0,0)
  local prop=entity(4,'models/props_c17/tv_monitor01.mdl',Vector(30,20,0),Angle(0,35,0))
  p.trace={Hit=true,HitPos=Vector(35,20,30),HitNormal=Vector(1,0,0),Entity=prop}
  local ok,_,sid=P:Action(p,'place',{channel=3,preset=true});assert(ok)
  local attached=P.screens[sid];eq(attached.entity,prop);eq(attached.config.w,14.5)
  local config=table.Copy(attached.config);config.w=30;config.h=20;config.x=7
  assert(P:Action(p,'preset',{screen=sid,config=config}));eq(lastIgnoreMap,true)
  eq(attached.config.w,14.5);eq(P.presets[prop.model].w,30)
  local ok,_,same=P:Action(p,'place',{channel=3,preset=true});assert(ok);assert(same~=sid);eq(attached.config.w,14.5);eq(P.screens[same].config.w,48)
  config.w=0;eq(P:Action(p,'screen',{screen=sid,config=config,name='Bad',channel=1,on=true}),false)
  config.w=30
  assert(P:Action(p,'screen',{screen=sid,config=config,name='Briefing',channel=4,on=false}))
  eq(attached.on,false);eq(attached.channel,4)
  P:SaveTV();P.tvInitialized=false;P:LoadData();P:PostLoadData();eq(P.screens[sid].entity,prop)
  eq(P.screens[sid].on,false);eq(P.screens[id].world,true);eq(P.screens[id].origin.x,99.65)
  eq(P:Action(p,'preset',{screen=id,config=config}),false)
  prop.valid=false;P:SaveTV();P.tvInitialized=false;P:LoadData();P:PostLoadData()
  assert(P.screens[sid]);assert(stored.tv_network_v3.screens[sid])
  eq(P:Action(p,'removeScreen',{screen=sid}),true)
 `);
 suite('TV screens on one prop keep independent channels, placement, interaction, quotas and persisted membership',server,`
  local P,T,S=PLUGIN,ix.TV,ix.PropScreens;P:Initialize();local p=admin()
  local host=entity(701,'models/test.mdl',Vector(50,0,64));host:SetNW2Int('ixCCTVSurfaceID',25)
  local ids={}
  for i=1,2 do
   p.trace={Hit=true,Entity=host,HitPos=Vector(45,(i-1)*60,64),HitNormal=Vector(-1,0,0)}
   local ok,_,id=P:Action(p,'place',{channel=i,preset=true});assert(ok);ids[i]=id
   if i==1 then assert(P:Action(p,'preset',{screen=id,config=P.screens[id].config})) end
   assert(S.Has(host,'ixTVScreenID',id));near(T.Transform(P.screens[id]).y,(i-1)*60)
  end
  p.admin=false;p.pos=Vector(0,60,64);P:KeyPress(p,IN_USE);eq(P.screens[ids[1]].on,true);eq(P.screens[ids[2]].on,false)
  p.admin=true;local maximum=T.maxScreens;T.maxScreens=2
  eq(P:Action(p,'place',{channel=3}),false);eq(P.screens[ids[2]].channel,2);T.maxScreens=maximum
  P:SaveTV();P.tvInitialized=false;P:LoadData();P:PostLoadData()
  for i,id in ipairs(ids) do eq(P.screens[id].entity,host);eq(P.screens[id].channel,i);assert(S.Has(host,'ixTVScreenID',id)) end
  CLIENT=true;SERVER=false
  for _,id in ipairs(ids) do local s=P.screens[id];s.entityIndex=host:EntIndex();assert(T.Transform(s)) end
  CLIENT=false;SERVER=true
  assert(P:Action(p,'removeScreen',{screen=ids[1]}));assert(S.Has(host,'ixTVScreenID',ids[2]));eq(host:GetNW2Int('ixTVScreenID'),ids[2])
  eq(P.screens[ids[2]].on,false);eq(host:GetNW2Int('ixCCTVSurfaceID'),25)
  P:EntityRemoved(host);eq(P.screens[ids[2]],nil)
 `);
 suite('TV prop removal broadcasts and persists screen deletion without removing its channel, presets or wall screens',server,`
  local P,T=PLUGIN,ix.TV;P:LoadData();P:PostLoadData()
  local e=entity(3,T.defaultModel,Vector(50,0,20))
  local s=P:AddScreen({entity=e,model=e.model,config=table.Copy(T.defaultConfig),channel=2,on=true,world=false,name='TV'})
  local wall=P:AddScreen({world=true,origin=Vector(),config=table.Copy(T.defaultConfig),channel=2,on=true,name='Wall'})
  P.channels[2].playing=true;P:SaveTV();local packets=#net.packets
  P:EntityRemoved(entity(9,'models/other.mdl'));eq(#net.packets,packets)
  -- The engine can fire before IsValid becomes false; compare the bound entity itself.
  P:EntityRemoved(e);eq(P.screens[s.id],nil);eq(e:GetNW2Int('ixTVScreenID',0),0)
  local packet=net.packets[#net.packets];eq(packet.name,'ixTVScreen');eq(packet.target,'all')
  local removed=util.JSONToTable(packet.value);eq(removed.id,s.id);eq(removed.removed,true)
  eq(stored.tv_network_v3.screens[s.id],nil);assert(P.screens[wall.id]);assert(P.presets[e.model]);eq(P.channels[2].playing,true)
  local count=#net.packets;e.valid=false;P:EntityRemoved(e);eq(#net.packets,count)
  P.tvInitialized=false;P:LoadData();P:PostLoadData();eq(P.screens[s.id],nil);assert(P.screens[wall.id])
 `);
 suite('TV cleanup preserves unresolved bindings until props finish restoring, including delayed restores',server,`
  local P,T=PLUGIN,ix.TV;P:LoadData();P:PostLoadData()
  local e=entity(4,T.defaultModel,Vector(50,0,20));e.mapid=-1
  local s=P:AddScreen({entity=e,model=e.model,config=table.Copy(T.defaultConfig),channel=1,on=true,world=false,name='Restored TV'})
  local gone=entity(5,T.defaultModel,Vector(100,0,20));gone.mapid=-1
  local missing=P:AddScreen({entity=gone,model=gone.model,config=table.Copy(T.defaultConfig),channel=1,on=true,world=false,name='Gone TV'})
  P:PreCleanupMap();e.valid=false;gone.valid=false;P:EntityRemoved(e);P:EntityRemoved(gone)
  assert(P.screens[s.id]);assert(stored.tv_network_v3.screens[s.id]);P:LoadData();P:Sync(admin())
  assert(P.screens[s.id]);assert(P.screens[missing.id])
  local replacement=entity(8,T.defaultModel,Vector(50,0,20));replacement.mapid=-1
  P:PostLoadData();eq(P.screens[s.id].entity,replacement);eq(replacement:GetNW2Int('ixTVScreenID',0),s.id)
  assert(P.screens[missing.id]);assert(stored.tv_network_v3.screens[missing.id])
  clock=clock+90;P:Think();P:SaveTV();assert(stored.tv_network_v3.screens[missing.id])
  local delayed=entity(9,T.defaultModel,Vector(100,0,20));delayed.mapid=-1
  clock=clock+3;P:Think();eq(P.screens[missing.id].entity,delayed);eq(delayed:GetNW2Int('ixTVScreenID',0),missing.id)
  P:SaveTV();P:ShutDown();replacement.valid=false;P:EntityRemoved(replacement);P:Sync(admin())
  assert(P.screens[s.id]);assert(stored.tv_network_v3.screens[s.id])
 `);
 suite('TV stable host identity survives a moved prop, unrelated same-model props and a fresh restart',server,`
  local P,T=PLUGIN,ix.TV;P:LoadData();P:PostLoadData()
  local host=entity(81,T.defaultModel,Vector(50,0,20));host.mapid=-1
  local s=P:AddScreen({entity=host,model=host.model,config=table.Copy(T.defaultConfig),channel=3,on=false,world=false,name='Named TV'})
  P:SaveTV();local identity=host.ixPropScreenHostID;assert(identity)
  host.valid=false;P.tvInitialized=false;P:LoadData();P:PostLoadData();P:SaveTV()
  eq(P.screens[s.id].pending,true);eq(P.screens[s.id].channel,3);eq(P.screens[s.id].on,false)
  local wrong=entity(82,T.defaultModel,Vector(50,0,20));wrong.mapid=-1;wrong.ixPropScreenHostID='another_host'
  clock=clock+3;P:Think();eq(P.screens[s.id].entity,nil)
  local restored=entity(83,T.defaultModel,Vector(90,0,20));restored.mapid=-1;restored.ixPropScreenHostID=identity
  clock=clock+3;P:Think();eq(P.screens[s.id].entity,restored);eq(P.screens[s.id].name,'Named TV')
  eq(stored.tv_network_v3.screens[s.id].binding.pos.x,90)
  P:EntityRemoved(restored);eq(P.screens[s.id],nil);eq(stored.tv_network_v3.screens[s.id],nil)
 `);
 suite('TV quotas, ray distance, invalid targets, subtitle bounds and channel deletion enforce server limits',server,`
  local P,T=PLUGIN,ix.TV;P:Initialize();local p=admin()
  for i=5,8 do assert(P:Action(p,'createChannel',{name='Channel '..i})) end
  eq(P:Action(p,'createChannel',{name='Overflow'}),false)
  eq(P:Action(p,'deleteChannel',{channel=1}),false)
  p.trace={Hit=true,HitWorld=true,HitPos=Vector(9999,0,0),HitNormal=Vector(1,0,0)}
  eq(P:Action(p,'place',{channel=2}),false);eq(table.Count(P.screens),0)
  p.trace.HitPos=Vector(100,0,64);assert(P:Action(p,'place',{channel=2}))
  eq(P:Action(p,'deleteChannel',{channel=2}),false)
  eq(P:Action(p,'captions',{channel=2,file='../secret.srt'}),false)
  subtitleFile='1\\n00:00:00,000 --> 00:00:02,000\\nHello\\n\\n'
  assert(P:Action(p,'captions',{channel=2,file='test.srt'}));eq(P.channels[2].subtitles,subtitleFile)
  assert(P:Action(p,'play',{channel=2,source='https://example.com/new.webm'}));eq(P.channels[2].subtitles,'')
  subtitleFile=string.rep('x',48001);eq(P:Action(p,'captions',{channel=2,file='test.srt'}),false)
  for i=2,T.maxScreens do P:AddScreen({config=table.Copy(T.defaultConfig),world=true,origin=Vector(),name='Screen',channel=2}) end
  eq(P:Action(p,'place',{channel=2}),false);eq(table.Count(P.screens),128)
  local reads=0;net.ReadString=function() reads=reads+1;return '' end
  p.admin=false;net.handlers.ixTVAction(40,p);eq(reads,0)
  p.admin=true;net.handlers.ixTVAction(80000,p);eq(reads,0)
  for i=1,63 do P.presets['models/test/preset'..i..'.mdl']=table.Copy(T.defaultConfig) end
  P:SaveTV();P.tvInitialized=false;P:Initialize();eq(table.Count(P.presets),64)
 `);
 suite('TV screen transform matches legacy calibration and excludes recycled entity indexes',basics,`
  local T=ix.TV;local c=T.defaultConfig
  local old=Angle();old:RotateAroundAxis(old:Right(),270);old:RotateAroundAxis(old:Up(),90)
  local a=Angle(c.p,c.yaw,c.r);vectorNear(a:Forward(),old:Forward());vectorNear(a:Up(),old:Up())
  for _,normal in ipairs({Vector(1,0,0),Vector(-1,0,0),Vector(0,1,0),Vector(0,-1,0),Vector(0,0,1),Vector(0,0,-1)}) do
   local cfg=T.SurfaceConfig({Hit=true,HitWorld=true,HitPos=Vector(),HitNormal=normal})
   vectorNear(Angle(cfg.p,cfg.yaw,cfg.r):Up(),normal)
  end
  local e=entity(7,T.defaultModel);CLIENT=true;SERVER=false
  local s={id=9,entityIndex=7,model=e.model,config=c}
  eq(T.Transform(s),nil);e:SetNW2Int('ixTVScreenID',9);assert(T.Transform(s))
  e:SetNW2Int('ixTVScreenID',0);eq(T.Transform(s),nil)
 `);
 const client=[...basics,'tools/fixtures/tv-client.lua','helix/gamemode/core/libs/sh_broadcastmedia.lua','ixhl2rp/plugins/tv_screen/cl_html.lua','ixhl2rp/plugins/tv_screen/cl_subtitles.lua','ixhl2rp/plugins/tv_screen/cl_plugin.lua','ixhl2rp/plugins/tv_screen/cl_interest.lua','ixhl2rp/plugins/tv_screen/cl_render.lua'];
 suite('TV stock preset migration moves embedded default screens outward without changing custom placements',server,`
  local P,T=PLUGIN,ix.TV
  local old=table.Copy(T.defaultConfig);old.x=6;old.p=.00001;old.r=89.99999
  stored.tv_model_presets_v3={[T.defaultModel]=table.Copy(old)}
  local custom=table.Copy(old);custom.w=16.5;custom.x=7.76
  stored.tv_network_v3={channels={},screens={
   [1]={id=1,model=T.defaultModel,config=table.Copy(old),channel=1,on=true},
   [2]={id=2,model=T.defaultModel,config=table.Copy(custom),channel=1,on=true},
   [3]={id=3,world=true,model=T.defaultModel,origin=Vector(),config=table.Copy(old),channel=1,on=true},
   [4]={id=4,model='models/other.mdl',config=table.Copy(old),channel=1,on=true}
  }}
  P:Initialize();near(P.presets[T.defaultModel].x,7.65);near(P.screens[1].config.x,7.65)
  near(P.screens[1].config.y,old.y);near(P.screens[1].config.w,old.w)
  near(P.screens[2].config.x,7.76);near(P.screens[2].config.w,16.5)
  near(P.screens[3].config.x,6);near(P.screens[4].config.x,6);near(old.x,6)
  P:SaveTV();P.tvInitialized=false;P:Initialize();near(P.screens[1].config.x,7.65)
 `);
 suite('TV client shares one player per channel, isolates failures/restarts, and releases distant streams',client,`
  local P,T=PLUGIN,ix.TV
  P.audio.Update=function(_,sources) lastSources=sources end
  local function channel(id,url) local c=T.Channel(id,'Channel '..id);c.source=url;c.playing=true;P.channels[id]=c;return c end
  channel(1,'https://example.com/a.webm');channel(2,'https://example.com/b.webm')
  for i=1,3 do P.screens[i]={id=i,world=true,origin=Vector(i*20,0,0),config=T.defaultConfig,channel=i==3 and 2 or 1,on=true} end
  hooks.Think.ixTVChannels();eq(table.Count(P.players),2);eq(panelsCreated,2)
  local first,second=P.players[1],P.players[2]
  first.panel.callback(2,true,1);eq(P:GetChannelStatus(1),'ready')
  second.panel.callback(0,false,4);eq(P:GetChannelStatus(2),'error');eq(P:GetChannelStatus(1),'ready')
  local c=table.Copy(P.channels[2]);c.revision=2;net.ReadString=function() return util.TableToJSON(c) end
  net.handlers.ixTVChannel();eq(P.players[2],nil);eq(P.players[1],first)
  clock=clock+1;hooks.Think.ixTVChannels();eq(panelsCreated,3)
  second.panel.callback(9,true,1);eq(P:GetChannelStatus(2),'loading')
  client.pos=Vector(8000,0,0);clock=clock+1;hooks.Think.ixTVChannels()
  eq(first.suspended,true);eq(second.suspended,nil)
  clock=clock+3;hooks.Think.ixTVChannels()
  eq(table.Count(P.players),0);eq(first.panel.valid,false)
  client.pos=Vector();clock=clock+1;hooks.Think.ixTVChannels();eq(table.Count(P.players),2)
  P.channels[1].playing=false;clock=clock+1;hooks.Think.ixTVChannels()
  eq(P:GetChannelStatus(1),'idle');eq(P.players[1],nil);assert(P.players[2])
  P:CleanupTV();eq(table.Count(P.players),0)
 `);
 suite('Multiple TV channels on one prop retain separate audio without duplicating a shared channel',client,`
  local P,T,S=PLUGIN,ix.TV,ix.PropScreens;P.audio.Update=function(_,sources) lastSources=sources end
  local created=0
  function ClientsideModel(model)
   created=created+1;local e=entity(100+created,model)
   function e:SetNoDraw() end;function e:SetPos(pos) self.pos=pos end;function e:Remove() self.valid=false end
   return e
  end
  local host=entity(50,T.defaultModel)
  for i=1,3 do
   local channel=i==3 and 1 or i
   if not P.channels[channel] then local c=T.Channel(channel,'Channel '..channel);c.sound='https://example.com/'..channel..'.mp3';c.playing=true;P.channels[channel]=c end
   local cfg=table.Copy(T.defaultConfig);cfg.y=(i-1)*20
   P.screens[i]={id=i,entityIndex=50,model=host.model,config=cfg,channel=channel,on=true};S.Bind(host,'ixTVScreenID',i)
  end
  hooks.Think.ixTVChannels();eq(table.Count(lastSources),2);eq(created,2)
  local a,b=P.audioAnchors[1],P.audioAnchors[2];assert(a~=b)
  eq(lastSources[a].path,'https://example.com/1.mp3');eq(lastSources[b].path,'https://example.com/2.mp3')
  local previous=b:GetPos();host.pos=host.pos+Vector(10,0,0);clock=clock+1;hooks.Think.ixTVChannels();eq(created,2);vectorNear(b:GetPos(),previous+Vector(10,0,0))
  P.screens[2].on=false;clock=clock+1;hooks.Think.ixTVChannels();eq(table.Count(lastSources),1);eq(b.valid,false);assert(IsValid(a))
  P:CleanupTV();eq(a.valid,false)
 `);
 suite('TV client detects missing telemetry, bounds retries and respects blackout/mute',client,`
  local P,T=PLUGIN,ix.TV;P.audio.Update=function(_,sources) lastSources=sources end
  local c=T.Channel(1,'Main');c.source='https://example.com/a.webm';c.playing=true;P.channels[1]=c
  local e=entity(1,T.defaultModel);e:SetNW2Int('ixTVScreenID',1)
  P.screens[1]={id=1,entityIndex=1,model=e.model,config=T.defaultConfig,channel=1,on=true}
  hooks.Think.ixTVChannels();eq(P.players[1].attempt,1)
  clock=clock+16;hooks.Think.ixTVChannels();eq(P.players[1].attempt,2)
  clock=clock+31;hooks.Think.ixTVChannels();eq(P.players[1].attempt,3)
  clock=clock+46;hooks.Think.ixTVChannels();eq(P:GetChannelStatus(1),'error');eq(panelsCreated,3)
  c.sound='https://example.com/a.mp3';clock=clock+1;hooks.Think.ixTVChannels();assert(lastSources[e])
  muted=true;clock=clock+1;hooks.Think.ixTVChannels();eq(next(lastSources),nil)
  ix.plugin.list.blackout={IsPosBlackedOut=function() return true end};clock=clock+4;hooks.Think.ixTVChannels()
  eq(P.players[1],nil);eq(P.tvSubtitleNearby,false)
 `);
 suite('TV migration imports existing televisions once and keeps deletions/IDs across restart',server,`
  local P,T=PLUGIN,ix.TV;local p=admin()
  local e=entity(1,T.defaultModel,Vector(50,0,64))
  local cctv=entity(2,T.defaultModel,Vector(60,0,64));cctv.CCTVKind='monitor'
  local control=entity(3,T.defaultModel,Vector(70,0,64));control:SetNW2Int('ixCCTVSurfaceID',25)
  P:LoadData();P:PostLoadData();eq(table.Count(P.screens),1);eq(P.screens[1].entity,e)
  assert(P:Action(p,'removeScreen',{screen=1}));eq(e:GetNW2Int('ixTVScreenID',0),0)
  P.tvInitialized=false;P:LoadData();P:PostLoadData();eq(table.Count(P.screens),0);eq(P.nextScreen,2)
  p.trace={Hit=true,HitPos=Vector(50,0,64),HitNormal=Vector(-1,0,0),Entity=e}
  local ok,_,id=P:Action(p,'place',{channel=1,preset=true});assert(ok);eq(id,2)
  P:SaveTV();assert(not isvector(stored.tv_network_v3.screens[id].binding.pos))
  P.tvInitialized=false;P:LoadData();P:PostLoadData();eq(P.screens[id].entity,e)
  local saved=P.screens[id].config;local pos=T.Transform(P.screens[id])
  p.pos=pos+Vector(20,0,0);p.dir=(pos-p.pos):GetNormalized();p.admin=false
  P:KeyPress(p,IN_USE);eq(P.screens[id].on,false)
  P:KeyPress(p,IN_USE);eq(P.screens[id].on,false)
  clock=clock+1;P:KeyPress(p,IN_USE);eq(P.screens[id].on,true)
 `);
 const controls=[...client,'tools/fixtures/tv-controls.lua','ixhl2rp/plugins/tv_screen/cl_display.lua','ixhl2rp/plugins/tv_screen/cl_preview.lua','ixhl2rp/plugins/tv_screen/cl_controls.lua'];
 suite('TV removal notification refreshes the admin list and exits an editor for the deleted prop',controls,`
  local P,T=PLUGIN,ix.TV;P.channels[1]=T.Channel(1,'Main')
  P.screens[1]={id=1,name='Removed TV',world=true,origin=Vector(),config=table.Copy(T.defaultConfig),channel=1,on=true}
  P.screens[2]={id=2,name='Other TV',world=true,origin=Vector(),config=table.Copy(T.defaultConfig),channel=1,on=true}
  P:OpenScreenEditor(1);local editor=P.tvWindow;assert(P.editPreview)
  local raw=util.TableToJSON({id=1,removed=true});net.ReadString=function() return raw end
  net.handlers.ixTVScreen();eq(P.screens[1],nil);assert(P.screens[2]);eq(P.editPreview,nil)
  eq(editor.valid,false);eq(P.tvMode,'screens');assert(IsValid(P.tvWindow));assert(uiFind('DButton','002  Other TV'))
  for _,panel in ipairs(uiPanels) do assert(not (panel.valid and panel.initialTooltip=='001  Removed TV')) end
 `);
 suite('TV controls build channel/screen pages, send scoped actions, preview edits and cancel safely',controls,`
  local P,T=PLUGIN,ix.TV
  P.channels[1]=T.Channel(1,'Main');P.channels[2]=T.Channel(2,'Briefing')
  P:OpenTVAdmin('channels',2);eq(P.previewChannel,2);assert(IsValid(P.tvWindow))
  uiFind('DButton','▶  Запустить на этом канале'):DoClick()
  eq(net.packets[#net.packets].name,'ixTVAction')
  local request=util.JSONToTable(net.packets[#net.packets].value);eq(request.channel,2)
  eq(P.pending.action,'play');local count=#net.packets
  uiFind('DButton','■  Остановить эфир'):DoClick();eq(#net.packets,count)
  P.pending=nil;clock=clock+1
  uiFind('DButton','+  Создать канал'):DoClick();prompt('New channel');eq(P.pending.action,'createChannel')
  P.pending=nil;clock=clock+1
  P.screens[1]={id=1,world=true,origin=Vector(),config=table.Copy(T.defaultConfig),channel=2,on=true,name='Wall'}
  P:OpenScreenEditor(1);eq(P.previewChannel,nil);assert(P.editPreview)
  eq(uiFind('DButton','Сохранить размещение для модели').enabled,false)
  uiFind('DCheckBoxLabel','Точная настройка'):OnChange(false)
  uiFind('DNumSlider','Ширина'):SetValue(120);eq(P.editPreview.config.w,120);eq(P.screens[1].config.w,14.5)
  uiFind('DButton','Сохранить экран'):DoClick();eq(P.pending.action,'screen')
  request=util.JSONToTable(net.packets[#net.packets].value);eq(request.config.w,120);eq(request.screen,1);eq(request.channel,2)
  P.tvWindow:Remove();eq(P.editPreview,nil)
  P:OpenTVAdmin('screens');uiFind('DButton','001  Wall'):Paint(180,38)
  P.tvWindow:Remove();client.admin=false;P:OpenTVAdmin('channels');assert(not IsValid(P.tvWindow))
 `);
 suite('TV placement input previews target, toggles presets, dispatches on click and cancels',controls,`
  local P,T=PLUGIN,ix.TV;P.channels[1]=T.Channel(1,'Main')
  client.trace={Hit=true,HitWorld=true,HitPos=Vector(50,0,64),HitNormal=Vector(-1,0,0)}
  P:BeginPlacement(1);hooks.Think.ixTVPlacement();assert(P.placementPreview.world)
  keys[KEY_R]=true;hooks.Think.ixTVPlacement();eq(P.placement.preset,false)
  mouse[MOUSE_LEFT]=true;hooks.Think.ixTVPlacement();eq(P.pending.action,'place')
  mouse[MOUSE_RIGHT]=true;hooks.Think.ixTVPlacement();eq(P.placement,nil);eq(P.placementPreview,nil);eq(P.tvMode,'screens')
  P:BeginPlacement(1);keys[KEY_ESCAPE]=true;hooks.Think.ixTVPlacement();eq(P.placement,nil)
 `);
 suite('TV precision sliders preserve calibration, allow hundredth-unit nudges and recenter after presets',controls,`
  local P,T=PLUGIN,ix.TV;P.channels[1]=T.Channel(1,'Main')
  local cfg=table.Copy(T.defaultConfig);cfg.x=3000;cfg.yaw=270;cfg.w=900
  P.screens[1]={id=1,model=T.defaultModel,world=false,config=cfg,channel=1,on=true,name='Large'}
  P.presets={[T.defaultModel]={x=-2500,y=3,z=0,p=-270,yaw=180,r=30,w=400,h=200}}
  P:OpenScreenEditor(1)
  local x=uiFind('DNumSlider','X · вперёд');local w=uiFind('DNumSlider','Ширина');local angle=uiFind('DNumSlider','Поворот')
  near(x:GetMin(),2998);near(x:GetMax(),3002);near(w:GetMin(),898);near(w:GetMax(),902)
  near(angle:GetMin(),260);near(angle:GetMax(),280);near(P.editPreview.config.x,3000);near(P.editPreview.config.yaw,270)
  local plus=uiFind('DButton','X · вперёд +');plus:DoClick();near(P.editPreview.config.x,3000.1)
  keys[KEY_LSHIFT]=true;plus:DoClick();near(P.editPreview.config.x,3000.11)
  uiFind('DButton','X · вперёд −'):DoClick();near(P.editPreview.config.x,3000.10);keys[KEY_LSHIFT]=false
  local before=#net.packets;uiFind('DButton','Загрузить пресет модели'):DoClick()
  near(P.editPreview.config.x,-2500);near(x:GetMin(),-2502);near(P.editPreview.config.w,400);eq(#net.packets,before)
  uiFind('DButton','Пропорции 16:9'):DoClick();near(P.editPreview.config.h,225)
  near(uiFind('DNumSlider','Высота'):GetMin(),223)
  local precise=uiFind('DCheckBoxLabel','Точная настройка');precise:OnChange(false)
  near(x:GetMin(),-4096);near(x:GetMax(),4096);near(P.editPreview.config.x,-2500)
  x:SetValue(-4096);precise:OnChange(true);near(x:GetMin(),-4096);near(x:GetMax(),-4094)
  uiFind('DButton','X · вперёд −'):DoClick();near(P.editPreview.config.x,-4096)
  w:SetValue(402);uiFind('DButton','Центрировать диапазоны на текущих значениях'):DoClick();near(w:GetMin(),400);near(w:GetMax(),404)
  near(P.screens[1].config.x,3000);near(P.screens[1].config.w,900);assert(T.Config(P.editPreview.config))
  P.tvWindow:Remove();eq(P.editPreview,nil)
 `);
 const preview=[...controls,'tools/fixtures/tv-preview.lua'];
 suite('TV interest excludes distant, behind-camera, dormant and occluded screens while respecting wide FOV and partial visibility',preview,`
  local P,T=PLUGIN,ix.TV;client.pos=Vector();viewAngle=Angle();viewFOV=90
  P.channels[1]=T.Channel(1,'Main')
  local cfg={x=0,y=0,z=0,p=0,yaw=90,r=90,w=20,h=12}
  local function screen(id,pos) P.screens[id]={id=id,world=true,origin=pos,config=cfg,on=true,channel=1} end
  screen(1,Vector(600,0,0));screen(2,Vector(-600,0,0));screen(3,Vector(4000,0,0));screen(4,Vector(600,1300,0))
  local e=entity(5,T.defaultModel,Vector(600,0,0));e.dormant=true;e:SetNW2Int('ixTVScreenID',5)
  P.screens[5]={id=5,entityIndex=5,model=e.model,config=cfg,on=true,channel=1}
  local calls=0
  util.TraceLine=function(t) calls=calls+1;eq(t.mask,MASK_VISIBLE);return {Hit=true,Fraction=.5} end
  local i=P:UpdateTVInterest();eq(#i.visible,0);eq(calls,5)
  viewFOV=150;clock=clock+.7;util.TraceLine=function(t) calls=calls+1;return {Hit=t.endpos.y<1000} end
  i=P:UpdateTVInterest(true);eq(#i.visible,1);eq(i.visible[1],4)
  viewFOV=90;clock=clock+.7
  -- Center is behind a pillar but one edge is visible.
  util.TraceLine=function(t) calls=calls+1;return {Hit=math.abs(t.endpos.y)<1} end
  i=P:UpdateTVInterest(true);eq(#i.visible,1);eq(i.visible[1],1)
  local before=calls;P:UpdateTVInterest(true);eq(calls,before)
  viewAngle=Angle(0,180,0);clock=clock+.1;util.TraceLine=function() return {Hit=false} end
  i=P:UpdateTVInterest(true);eq(#i.visible,1);eq(i.visible[1],2)
 `);
 suite('TV video refresh is capped independently of game FPS, shared by visible screens, and standby pages are cached',preview,`
  local P,T=PLUGIN,ix.TV;client.pos=Vector();viewAngle=Angle()
  local mat,html=readyTVChannel(1);local hiddenMat,hidden=readyTVChannel(2)
  for n=1,2 do P.screens[n]={id=n,world=true,origin=Vector(100,n*5,0),config=T.defaultConfig,channel=1,on=true} end
  P.screens[3]={id=3,world=true,origin=Vector(-600,0,0),config=T.defaultConfig,channel=2,on=true}
  for n=1,120 do clock=clock+1/120;hooks.PreRender.ixTVDisplayTextures() end
  assert(html.updates>=19 and html.updates<=24);eq(hidden.updates,0);eq(rtAllocations,1)
  eq(P.tvPerf.html,html.updates);eq(P.tvPerf.captures,html.updates)
  tvOptions.tvFrameRate=10;local before=html.updates
  for n=1,120 do clock=clock+1/120;hooks.PreRender.ixTVDisplayTextures() end
  assert(html.updates-before<=11)
  P.players[1].status='ended';clock=clock+.2;hooks.PreRender.ixTVDisplayTextures();before=html.updates
  local stoppedCaptures=P.tvPerf.captures
  for n=1,60 do clock=clock+1/60;hooks.PreRender.ixTVDisplayTextures() end
  eq(html.updates,before);eq(P.tvPerf.captures,stoppedCaptures)
  P.channels[1].playing=false;P:DropPlayer(1);renderTVFrame();local captures=P.tvPerf.captures
  for n=1,120 do clock=clock+1/120;hooks.PreRender.ixTVDisplayTextures() end
  eq(P.tvPerf.captures,captures)
  P.channels[1].name='Renamed';renderTVFrame();eq(P.tvPerf.captures,captures+1)
  P.channels[1].playing=true;renderTVFrame();eq(P.tvPerf.captures,captures+2)
  concommands.ix_tv_perf();eq(P.tvPerf.captures,0)
 `);
 suite('TV keeps nearby audio without texture work, pauses muted unseen playback, resumes without reloading and releases unused players',preview,`
  local P,T=PLUGIN,ix.TV;client.pos=Vector();viewAngle=Angle();P.audio.Update=function() end
  local _,html=readyTVChannel(1);local original=P.players[1]
  P.screens[1]={id=1,world=true,origin=Vector(-100,0,0),config=T.defaultConfig,channel=1,on=true}
  hooks.Think.ixTVChannels();renderTVFrame();eq(html.updates,0);eq(P.players[1],original);eq(original.suspended,nil)
  assert(html.scripts[#html.scripts]:find('ixMediaUpdate',1,true));eq(table.Count(T.displays),0)
  muted=true;clock=clock+.3;hooks.Think.ixTVChannels();eq(original.suspended,true)
  assert(html.scripts[#html.scripts]:find('ixMediaSuspend',1,true));renderTVFrame();eq(html.updates,0)
  viewAngle=Angle(0,180,0);clock=clock+.3;hooks.Think.ixTVChannels();renderTVFrame()
  eq(P.players[1],original);eq(original.suspended,nil);eq(html.updates,1)
  client.pos=Vector(9000,0,0);clock=clock+.3;hooks.Think.ixTVChannels();eq(original.suspended,true)
  clock=clock+3.1;hooks.Think.ixTVChannels();eq(P.players[1],nil);eq(html.valid,false)
 `);
 suite('TV handles 128 remote screens with bounded visibility traces and no remote video players',preview,`
  local P,T=PLUGIN,ix.TV;client.pos=Vector();viewAngle=Angle();P.audio.Update=function() end
  for id=1,8 do local c=T.Channel(id,'Channel '..id);c.playing=true;c.source='https://example.com/'..id..'.webm';P.channels[id]=c end
  for id=1,128 do P.screens[id]={id=id,world=true,origin=Vector(700+id*3,0,0),config=T.defaultConfig,channel=id%8+1,on=true} end
  util.TraceLine=function() return {Hit=true,Fraction=.5} end
  local previous=0
  for n=1,40 do
   clock=clock+.11;hooks.Think.ixTVChannels();hooks.PreRender.ixTVDisplayTextures()
   assert(P.tvPerf.traces-previous<=24);previous=P.tvPerf.traces
  end
  local checked=0;for _,cache in pairs(P.tvSight) do if cache.nextCheck then checked=checked+1 end end
  eq(checked,128);eq(panelsCreated,0);eq(table.Count(P.players),0);eq(P.tvPerf.html,0);eq(P.tvPerf.captures,0)
  -- Moving away rejects all 128 before tracing at all.
  local before=P.tvPerf.traces;client.pos=Vector(6000,0,0);clock=clock+.2;P:UpdateTVInterest(true);eq(P.tvPerf.traces,before)
 `);
 suite('TV external audio is shared per channel and an administrator can preview a remote channel',preview,`
  local P,T=PLUGIN,ix.TV;client.pos=Vector();viewAngle=Angle();P.audio.Update=function(_,v) lastSources=v end
  local c=T.Channel(1,'Main');c.playing=true;c.source='https://example.com/a.webm';c.sound='https://example.com/a.mp3';P.channels[1]=c
  for id=1,10 do
   local e=entity(id,T.defaultModel,Vector(-100-id*10,0,0));e:SetNW2Int('ixTVScreenID',id)
   P.screens[id]={id=id,entityIndex=id,model=e.model,config=T.defaultConfig,channel=1,on=true}
  end
  hooks.Think.ixTVChannels();eq(table.Count(lastSources),1);assert(lastSources[Entity(1)]);eq(table.Count(P.players),0)
  P.tvWindow={valid=true};P.previewChannel=1;clock=clock+.3;hooks.Think.ixTVChannels();assert(P.players[1])
  local r=P.players[1];r.status='ready';r.panel.UpdateHTMLTexture=function(self) self.updated=true end
  r.panel.GetHTMLMaterial=function() return nil end
  hooks.PreRender.ixTVDisplayTextures();eq(r.panel.updated,true);eq(rtAllocations,0)
  P.tvWindow.valid=false;clock=clock+4;hooks.Think.ixTVChannels();eq(P.players[1],nil);eq(table.Count(lastSources),1)
 `);
 suite('TV placement HUD paints exact screen bounds on floors, walls and models without the world TV rendering pass',preview,`
  local P,T=PLUGIN,ix.TV;P.channels[1]=T.Channel(1,'Main')
  local normals={Vector(0,0,1),Vector(0,0,-1),Vector(1,0,0),Vector(-1,0,0),Vector(0,1,0),Vector(0,-1,0)}
  for _,normal in ipairs(normals) do
   client.trace={Hit=true,HitWorld=true,HitPos=Vector(60,40,20),HitNormal=normal}
   P:BeginPlacement(1);hooks.Think.ixTVPlacement();assert(P.placementPreview)
   local center,quad=T.PreviewCorners(P.placementPreview);local pos,angle=T.Transform(P.placementPreview)
   vectorNear(center,pos);vectorNear((quad[1]+quad[3])*.5,center)
   near((quad[2]-quad[1]):Length(),48);near((quad[4]-quad[1]):Length(),27)
   projectionOrigin=pos;projectionRight=angle:Forward();projectionUp=angle:Right()
   previewLines={};previewPolys={};hooks.HUDPaint.ixTVPlacementHUD()
   assert(#previewLines>40);eq(#previewPolys,1);eq(cameraDepth,0)
   projectionRight=-projectionRight;previewPolys={};hooks.HUDPaint.ixTVPlacementHUD();eq(#previewPolys,1)
  end
  local ent=entity(7,T.defaultModel,Vector(150,50,20),Angle(0,65,0))
  P.presets[ent.model]=table.Copy(T.defaultConfig)
  client.trace={Hit=true,Entity=ent,HitPos=Vector(150,50,30),HitNormal=Vector(0,1,0)}
  P:BeginPlacement(1);hooks.Think.ixTVPlacement();local s=P.placementPreview
  local pos,a=T.Transform(s);vectorNear(pos,LocalToWorld(Vector(T.defaultConfig.x,-2,.75),Angle(),ent.pos,ent.ang))
  projectionOrigin=pos;projectionRight=a:Forward();projectionUp=a:Right()
  previewLines={};hooks.HUDPaint.ixTVPlacementHUD();assert(#previewLines>40)
  -- A moved prop and a preset toggle must immediately move the visible guide.
  ent.pos=ent.pos+Vector(20,0,0);local moved=T.PreviewCorners(s);vectorNear(moved,pos+Vector(20,0,0))
  client.trace.Hit=false;hooks.Think.ixTVPlacement();previewLines={};hooks.HUDPaint.ixTVPlacementHUD();eq(#previewLines,0)
 `);
 suite('TV preview follows precision edits, survives power-off, clips large projections and clears on close or lost access',preview,`
  local P,T=PLUGIN,ix.TV;P.channels[1]=T.Channel(1,'Main')
  P.screens[1]={id=1,world=true,origin=Vector(),config=table.Copy(T.defaultConfig),on=false,channel=1,name='Screen'}
  P:OpenScreenEditor(1);local pos,a=T.Transform(P.editPreview)
  projectionOrigin=pos;projectionRight=a:Forward();projectionUp=a:Right()
  previewLines={};hooks.HUDPaint.ixTVPlacementHUD();assert(#previewLines>40)
  local before=T.PreviewCorners(P.editPreview);uiFind('DButton','X · вперёд +'):DoClick()
  local after=T.PreviewCorners(P.editPreview);near(after.x-before.x,.1)
  keys[KEY_LSHIFT]=true;uiFind('DButton','X · вперёд +'):DoClick();after=T.PreviewCorners(P.editPreview);near(after.x-before.x,.11)
  previewScale=100000;previewLines={};previewPolys={};P:PaintScreenPreview();eq(#previewPolys,0)
  P.placement={};P.placementPreview=P.editPreview;P:PaintScreenPreview();eq(#previewPolys,1)
  for _,poly in ipairs(previewPolys) do for _,v in ipairs(poly) do assert(v.x>=-.0001 and v.x<=ScrW()+.0001 and v.y>=-.0001 and v.y<=ScrH()+.0001) end end
  P.placement=nil;P.placementPreview=nil
  projectionVisible=false;previewLines={};previewPolys={};P:PaintScreenPreview();eq(#previewLines,0);eq(#previewPolys,0)
  projectionVisible=true;client.admin=false;P:PaintScreenPreview();eq(#previewLines,0)
  client.admin=true;P.tvWindow:Remove();P:PaintScreenPreview();eq(#previewLines,0);eq(P.editPreview,nil)
 `);
 suite('TV display capture restores render target and camera state after a channel draw failure',preview,`
  local P,T=PLUGIN,ix.TV;local draws=0
  P.screens[1]={id=1,world=true,origin=Vector(),config=table.Copy(T.defaultConfig),on=true,channel=1}
  P.screens[2]={id=2,world=true,origin=Vector(30,0,0),config=table.Copy(T.defaultConfig),on=true,channel=2}
  function P:PaintChannel(id) if id==1 then error('injected TV material failure') end;draws=draws+1 end
  renderTVFrame();eq(cameraDepth,0);eq(camera2DDepth,0);eq(rtDepth,0);eq(draws,1);eq(#previewErrors,1)
  hooks.PostDrawTranslucentRenderables.ixTVScreens(false,false,true);eq(draws,1)
  P:BeginPlacement(1);client.trace={Hit=true,HitWorld=true,HitPos=Vector(50,0,0),HitNormal=Vector(0,0,1)}
  hooks.Think.ixTVPlacement();local pos,a=T.Transform(P.placementPreview)
  projectionOrigin=pos;projectionRight=a:Forward();projectionUp=a:Right()
  previewLines={};hooks.HUDPaint.ixTVPlacementHUD();assert(#previewLines>40);eq(cameraDepth,0)
 `);
 suite('TV world video pixels match the preview corners using the actual 3D2D matrix convention',preview,`
  local P,T=PLUGIN,ix.TV;local mat=readyTVChannel(1)
  local configurations={}
  for _,normal in ipairs({Vector(0,0,1),Vector(0,0,-1),Vector(1,0,0),Vector(-1,0,0),Vector(0,1,0),Vector(0,-1,0)}) do
   local trace={Hit=true,HitWorld=true,HitPos=Vector(60,30,20),HitNormal=normal}
   local cfg=T.SurfaceConfig(trace)
   configurations[#configurations+1]={id=1,world=true,origin=trace.HitPos+normal*.35,config=cfg,on=true,channel=1}
  end
  local ent=entity(12,T.defaultModel,Vector(80,50,10),Angle(15,55,8));ent:SetNW2Int('ixTVScreenID',1)
  configurations[#configurations+1]={id=1,entityIndex=12,model=ent.model,config=table.Copy(T.defaultConfig),on=true,channel=1}
  for _,s in ipairs(configurations) do
   P.screens={[1]=s};worldDraws={};renderTVFrame()
   eq(#worldDraws,1);local call=worldDraws[1];eq(call.sourceMaterial,mat)
   local center,quad=T.PreviewCorners(s);vectorNear((call.corners[1]+call.corners[3])*.5,center)
   for _,expected in ipairs(quad) do
    local found=false;for _,actual in ipairs(call.corners) do if actual:DistToSqr(expected)<.0001 then found=true end end
    assert(found,'Rendered video rectangle differs from placement guide')
   end
   local _,angle=T.Transform(s)
   vectorNear(call.corners[2]-call.corners[1],angle:Forward()*s.config.w)
   vectorNear(call.corners[4]-call.corners[1],angle:Right()*s.config.h)
   near(call.u2,.5);near(call.v2,.5625);eq(cameraDepth,0)
  end
 `);
 suite('TV world playback stays visible during editing and after closing the channel menu, with local channel/power previews',preview,`
  local P,T=PLUGIN,ix.TV;local mat1,html1=readyTVChannel(1);local mat2,html2=readyTVChannel(2)
  P.screens[1]={id=1,world=true,origin=Vector(30,0,0),config=table.Copy(T.defaultConfig),on=true,channel=1,name='Video screen'}
  P:PrepareTVMedia();P:PaintChannel(1,640,360);eq(worldDraws[#worldDraws].material,mat1)
  P:OpenScreenEditor(1);worldDraws={};renderTVFrame()
  eq(#worldDraws,1);eq(worldDraws[1].sourceMaterial,mat1)
  uiFind('DButton','Z · высота +'):DoClick();worldDraws={};renderTVFrame()
  local center=T.Transform(P.editPreview);vectorNear((worldDraws[1].corners[1]+worldDraws[1].corners[3])*.5,center)
  for _,element in ipairs(uiPanels) do if element.valid and element.kind=='DComboBox' then element:OnSelect(2,'Second',2) end end
  worldDraws={};renderTVFrame();eq(worldDraws[1].sourceMaterial,mat2);eq(P.screens[1].channel,1)
  uiFind('DCheckBoxLabel','Экран включён'):OnChange(false)
  worldDraws={};renderTVFrame();eq(#worldDraws,1);eq(worldDraws[1].sourceMaterial,nil);eq(P.screens[1].on,true)
  uiFind('DCheckBoxLabel','Экран включён'):OnChange(true)
  P.tvWindow:Remove();worldDraws={};renderTVFrame();eq(worldDraws[1].sourceMaterial,mat1)
  -- Browsing the channel menu must not be required to keep a nearby TV alive.
  P:OpenTVAdmin('channels',1);P.tvWindow:Remove();clock=clock+4;hooks.Think.ixTVChannels()
  eq(P.players[1].panel,html1);assert(#html1.scripts>0);eq(P.players[2],nil)
  worldDraws={};renderTVFrame();eq(worldDraws[1].sourceMaterial,mat1)
 `);
 suite('TV display textures update before world drawing, share one slot per channel and keep standby visible without a browser',preview,`
  local P,T=PLUGIN,ix.TV;local mat,html=readyTVChannel(1)
  for i=1,2 do P.screens[i]={id=i,world=true,origin=Vector(i*30,0,0),config=table.Copy(T.defaultConfig),channel=1,on=true} end
  local failures={};local original=T.DrawFailure
  T.DrawFailure=function(w,h,status,name) failures[#failures+1]=status;original(w,h,status,name) end
  surface.SetAlphaMultiplier(.2)
  hooks.PreRender.ixTVDisplayTextures();eq(html.updates,1);eq(rtAllocations,1)
  hooks.PreRender.ixTVDisplayTextures();eq(html.updates,1);eq(rtAllocations,1)
  near(surface.GetAlphaMultiplier(),.2);eq(DisableClipping(false),false)
  worldDraws={};hooks.PostDrawTranslucentRenderables.ixTVScreens(false,false,false)
  eq(#worldDraws,2);eq(worldDraws[1].sourceMaterial,mat);eq(worldDraws[2].sourceMaterial,mat)
  near(render.GetBlend(),.3);local red,green,blue=render.GetColorModulation();near(red,.4);near(green,.5);near(blue,.6)
  eq(cameraDepth,0);eq(camera2DDepth,0);eq(rtDepth,0);eq(#failures,0)
  local before=html.updates
  P:PaintChannel(1,640,360);eq(html.updates,before)
  P.channels[1].playing=false;P:DropPlayer(1);worldDraws={};renderTVFrame()
  eq(#worldDraws,2);eq(failures[#failures],'idle');assert(worldDraws[1].rectangles>0);eq(worldDraws[1].sourceMaterial,nil)
  P.channels[1]=nil;worldDraws={};renderTVFrame();eq(failures[#failures],'missing');eq(#worldDraws,2)
  client.pos=Vector(5000,0,0);worldDraws={};renderTVFrame();eq(#worldDraws,0);eq(rtAllocations,1)
  P:OnUnload();eq(hooks.PreRender.ixTVDisplayTextures,nil);eq(hooks.PostDrawTranslucentRenderables.ixTVScreens,nil)
 `);
 suite('TV display test is local, admin-only, expires automatically and does not alter channel settings',preview,`
  local P,T=PLUGIN,ix.TV;local mat=readyTVChannel(1)
  P.screens[1]={id=1,world=true,origin=Vector(30,0,0),config=table.Copy(T.defaultConfig),channel=1,on=true}
  client.admin=false;concommands.ix_tv_testpattern();eq(P.tvTestUntil,nil)
  client.admin=true;concommands.ix_tv_testpattern();assert(P.tvTestUntil>clock)
  worldDraws={};renderTVFrame();eq(#worldDraws,1);eq(worldDraws[1].sourceMaterial,nil);assert(worldDraws[1].rectangles>=8)
  eq(P.channels[1].source,'https://example.com/video.webm');eq(P.channels[1].playing,true);eq(P.screens[1].on,true)
  clock=clock+16;worldDraws={};renderTVFrame();eq(worldDraws[1].sourceMaterial,mat);eq(rtAllocations,2)
 `);
};
if(require.main===module){
 const f=require('fengari'),{normalize}=require('./glua.cjs');
 module.exports((name,files,assertions,setup='')=>{
  const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
  const source=[fs.readFileSync('tools/fixture.lua','utf8'),setup,...files.map(p=>'do\n'+normalize(fs.readFileSync(p,'utf8'))+'\nend'),assertions].join('\n');
  const status=f.lauxlib.luaL_dostring(L,f.to_luastring(source));
  if(status!==f.lua.LUA_OK){fs.writeFileSync('docs/tv-client-test-expanded.lua',source);throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));}
  console.log('PASS '+name);
 });
}

