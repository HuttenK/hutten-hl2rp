module.exports=suite=>{
 const files=['ixhl2rp/plugins/proximity_voice/sh_plugin.lua','ixhl2rp/plugins/proximity_voice/sv_voice.lua'];
 const setup=`
 SERVER=true; CLIENT=false; PLUGIN={}; resource={AddFile=function() end}; net.Start=function() end
 voiceHooks={};hook.Add=function(event,id,fn) voiceHooks[id..event]=fn end; hook.Remove=function() end; hook.Run=function() end
 timer.Create=function() end; timer.Remove=function() end; ix.util={Include=function() end}
 ix.config={Add=function() end,Get=function(_,default) return default end}
 ix.Item={instances={}}; ix.faction={indices={}}; ix.class={list={}}
 ix.radio={channels={a={name='100.0',subChannels=1},b={name='200.0',subChannels=1},tac={name='Tac',subChannels=3},all={name='All',global=true,targetChannels={tac='all'}}}}
 function ix.radio:HasPlayerChannel(p,id,n)
  local c=self.channels[id]; if not c then return false end
  if c.global then return p.globalChannels[id] end
  local v=p.listenChannels[id]; return v and (type(n)~='number' or n==v)
 end
 function pos(n) return {n=n,DistToSqr=function(self,other) return (self.n-other.n)^2 end} end
 stations={}; ents={FindByClass=function() return stations end}
 function person(n,id)
  local c={}; function c:GetFaction() return 1 end; function c:GetClass() return 1 end; function c:GetRadioChannels() return {} end
  local p={valid=true,character=c,where=pos(n),listenChannels={},globalChannels={},tempChannels={},channel=id,radioID=n+1}
  if id then p.listenChannels[id]=1 end
  function p:GetCharacter() return self.character end; function p:Alive() return not self.dead end
  function p:InCriticalState() return self.critical end; function p:GetLocalVar() return false end
  function p:GetNetVar(k) if k=='radioChannel' then return self.channel end end
  function p:GetPos() return self.where end; p.GetShootPos=p.GetPos
  function p:GetEyeTraceNoCursor() return {Entity=self.station} end
  function p:IsRestricted() return self.restricted end
  function p:GetFirstAtSlot() return self.radioID end; function p:Team() return 1 end
  ix.Item.instances[p.radioID]={IsOn=function(self) return not self.off end,GetFrequencyID=function() return id end}
  return p
 end
 `;
 suite('One transmission lookup per synchronous voice sweep retains live listener permissions and next-sweep tuning',files,`
 local V=ix.voice;local a=person(0,'a');local b=person(2000,'a');local c=person(2100,'a')
 a.ixRadioVoice={character=a.character,channel='a',expires=CurTime()+2}
 local calls=0;local original=V.Transmission
 V.Transmission=function(p) calls=calls+1;return original(p) end
 local context={};eq(V.Route(b,a,context),true);eq(V.Route(c,a,context),true);eq(calls,1)
 ix.Item.instances[c.radioID].off=true;eq(V.Route(c,a,context),false);eq(calls,1)
 a.channel='b';eq(V.Route(b,a,{}),false);eq(calls,2)
 `,setup);
 suite('Proximity, radio union, live radio switch-off, tuning and unconscious/dead isolation',files,`
 local iconsOn=true; local writes=0
 GetConVar=function() return {GetBool=function() return iconsOn end,SetBool=function() error('engine ConVar rejects Lua setters') end} end
 RunConsoleCommand=function(name,value) eq(name,'mp_show_voice_icons'); eq(value,'0'); iconsOn=false; writes=writes+1 end
 ix.voice.HideEngineIcons(); eq(iconsOn,false); eq(writes,1)
 ix.voice.HideEngineIcons(); eq(writes,1)
 iconsOn=true; ix.voice.HideEngineIcons(); eq(iconsOn,false); eq(writes,2)
 local V=ix.voice; local talker=person(0,'a'); local same=person(2000,'a'); local wrong=person(2100,'b'); local near=person(100,'b')
 eq(V.Route(same,talker),false); local hear,spatial=V.Route(near,talker); eq(hear,true); eq(spatial,true)
 talker.ixRadioVoice={character=talker.character,channel='a',expires=CurTime()+2}
 hear,spatial=V.Route(same,talker); eq(hear,true); eq(spatial,false)
 eq(V.Route(wrong,talker),false); hear,spatial=V.Route(near,talker); eq(hear,true); eq(spatial,true)
 ix.Item.instances[same.radioID].off=true; eq(V.Route(same,talker),false)
 ix.Item.instances[same.radioID].off=false; talker.channel='b'; eq(V.Route(same,talker),false)
 talker.channel='a'; talker.critical=true; eq(V.Route(near,talker),false)
 talker.critical=false; same.dead=true; eq(V.Route(same,talker),false)
 same.dead=false; talker.ixRadioVoice.expires=CurTime()-1; eq(V.Route(same,talker),false)
 talker.ixRadioVoice.expires=CurTime()+2; talker.ixRadioVoice.character={}; eq(V.Route(same,talker),false)
 `,setup);
 suite('Radio voice uses subchannel/global permissions and nearby powered stationary radios',files,`
 local V=ix.voice; local a=person(0,'tac'); local b=person(2000,'tac')
 a.listenChannels.tac=2; b.listenChannels.tac=3
 a.ixRadioVoice={character=a.character,channel='tac',expires=CurTime()+2}
 eq(V.Route(b,a),false); b.listenChannels.tac=2; eq(V.Route(b,a),true)
 a.channel='all'; a.globalChannels.all=1; a.tempChannels.all=1; a.ixRadioVoice.channel='all'; eq(V.Route(b,a),true)
 local station={valid=true,IsOn=function(self) return not self.off end,GetClass=function() return 'ix_stationary_radio' end,GetFrequency=function() return 'a' end,GetPos=function() return pos(2050) end}
 stations={station};PLUGIN:OnEntityCreated(station); local c=person(0,'a'); local d=person(2100,nil)
 c.ixRadioVoice={character=c.character,channel='a',expires=CurTime()+2}; eq(V.Route(d,c),true)
 station.off=true; eq(V.Route(d,c),false); station.off=false
 local operator=person(2040,nil); operator.station=station; eq(V.Transmission(operator).data.channelID,'a')
 operator.where=pos(0); eq(V.Transmission(operator),nil)
 `,setup);
 suite('Radio PTT validates server access and release clears even during request cooldown',files,`
 local p=person(0,'a'); local receive=net.handlers.ixRadioVoicePTT
 requested=true; receive(1,p); assert(p.ixRadioVoice); eq(ack,true)
 requested=false; receive(1,p); eq(p.ixRadioVoice,nil)
 local denied=person(10,nil); requested=true; receive(1,denied); eq(denied.ixRadioVoice,nil); eq(ack,false)
 local restricted=person(20,'a'); restricted.restricted=true; receive(1,restricted); eq(ack,false)
 `,setup+`net.ReadBool=function() return requested end; net.WriteBool=function(v) ack=v end; net.Send=function() end`);
 suite('Facility voice profile survives routing, receiver filtering and notification while radio keeps priority',files,`
 local V=ix.voice;local listener=person(10000,'a');local talker=person(0,'a');local effect='pa';local enabled=true
 ix.plugin.list.facility_utilities={VoiceRoute=function() if enabled then return true,false,'Facility',.6,effect end end}
 local filter,packet={},{};V.ApplyRadioFilter=function(_,_,hear,spatial,kind) filter={hear=hear,spatial=spatial,effect=kind} end
 net.WriteEntity=function() end;net.WriteUInt=function(v) packet.mode=v end;net.WriteString=function(v) packet.label=v end
 net.WriteFloat=function(v) packet.gain=v end;net.WriteBool=function(v) packet.pa=v end;net.Send=function() packet.sent=(packet.sent or 0)+1 end
 PLUGIN:PlayerCanHearPlayersVoice(listener,talker);eq(filter.effect,'pa');eq(packet.pa,true);eq(packet.mode,3);eq(packet.gain,.6)
 effect='radio';PLUGIN:PlayerCanHearPlayersVoice(listener,talker);eq(packet.sent,2);eq(packet.pa,false);eq(filter.effect,'radio')
 talker.ixRadioVoice={character=talker.character,channel='a',expires=CurTime()+2}
 eq(select(5,V.Route(listener,talker)),'radio');PLUGIN:PlayerCanHearPlayersVoice(listener,talker);eq(packet.mode,2)
 talker.ixRadioVoice=nil;enabled=false;PLUGIN:PlayerCanHearPlayersVoice(listener,talker);eq(filter.hear,false);eq(packet.mode,0)
 `,setup);
 suite('Client radio PTT only activates microphone after acknowledgement and stops on release',
 ['ixhl2rp/plugins/proximity_voice/sh_plugin.lua','ixhl2rp/plugins/proximity_voice/cl_voice.lua'],`
 local talker={valid=true,GetCharacter=function() return {GetID=function() return 91 end} end,
 GetNetVar=function(self) return self.hidden and 91 or 0 end}
 eq(ix.voice.RadioSpeakerName(localPlayer,talker),'Неизвестный')
 localPlayer.recognize={[91]='Remembered Alias'}
 eq(ix.voice.RadioSpeakerName(localPlayer,talker),'Remembered Alias')
 talker.hidden=true; eq(ix.voice.RadioSpeakerName(localPlayer,talker),'Неизвестный')
 talker.hidden=false; localPlayer.recognize={}; eq(ix.voice.RadioSpeakerName(localPlayer,talker),'Неизвестный')
 commands['+ix_radio_voice'](); eq(#mic,0); eq(lastSent,true)
 accepted=true; net.handlers.ixRadioVoiceAck(); eq(mic[1],true)
 eq(clicks,1); net.handlers.ixRadioVoiceAck(); eq(clicks,1)
 commands['-ix_radio_voice'](); eq(mic[2],false); eq(lastSent,false)
 net.handlers.ixRadioVoiceAck(); eq(#mic,2)
 commands['+ix_radio_voice'](); accepted=false; net.handlers.ixRadioVoiceAck(); eq(#mic,2)
 selectedKey=12; PLUGIN:Think(); keyDown=true; PLUGIN:Think(); eq(lastSent,true)
 accepted=true; net.handlers.ixRadioVoiceAck(); eq(mic[3],true)
 keyDown=false; PLUGIN:Think(); eq(mic[4],false)
 ix.gui.menu={valid=true}; keyDown=true; PLUGIN:Think(); eq(lastSent,false)
 ix.gui.menu=nil; PLUGIN:Think(); eq(lastSent,false)
 keyDown=false; PLUGIN:Think(); keyDown=true; PLUGIN:Think(); eq(lastSent,true)
 net.handlers.ixRadioVoiceAck(); selectedKey=13; PLUGIN:Think(); eq(lastSent,false)
 PLUGIN:Think(); eq(lastSent,false)
 -- Normal voice press has no release callback. A later radio press must still open the mic.
 keyDown=true; PLUGIN:PlayerBindPress(localPlayer,'+voicerecord',true,12)
 keyDown=false; PLUGIN:Think()
 local before=#mic
 commands['+ix_radio_voice'](); accepted=true; net.handlers.ixRadioVoiceAck()
 eq(mic[before+1],true)
 commands['-ix_radio_voice'](); eq(mic[before+2],false)
 -- Repeated transmissions must acquire and release the microphone each time.
 for i=1,3 do
  before=#mic; commands['+ix_radio_voice'](); net.handlers.ixRadioVoiceAck()
  eq(mic[before+1],true); commands['-ix_radio_voice'](); eq(mic[before+2],false)
 end
 -- The occlusion timer must preserve PA gain without overwriting intercom flutter.
 function talker:IsMuted() return false end;function talker:SetVoiceVolumeScale(v) self.scale=v end
 net.ReadEntity=function() return talker end;net.ReadUInt=function() return 3 end
 net.ReadString=function() return 'Facility' end;net.ReadFloat=function() return .6 end
 local currentRoute
 ix.voice.UpdateRadioEffects=function(_,_,routes) currentRoute=routes[talker];talker:SetVoiceVolumeScale(.25) end
 PLUGIN:PlayerStartVoice(talker);accepted=true;net.handlers.ixVoiceRoute();timers.ixVoiceOcclusion()
 eq(currentRoute.effect,'pa');eq(talker.scale,.6)
 accepted=false;net.handlers.ixVoiceRoute();timers.ixVoiceOcclusion();eq(currentRoute.effect,'radio');eq(talker.scale,.25)
 selectedKey=0;timers.ixVoiceOcclusion();eq(talker.scale,.6)
 PLUGIN:PlayerEndVoice(talker);eq(currentRoute,nil);eq(talker.scale,1)
 `,setup+`
 RealTime=CurTime; SERVER=false; CLIENT=true; localPlayer=person(0,'a'); function LocalPlayer() return localPlayer end
 function localPlayer:Notify() end
 clicks=0; function localPlayer:EmitSound() clicks=clicks+1 end
 commands={}; concommand={Add=function(n,fn) commands[n]=fn end}
 mic={}; permissions={EnableVoiceChat=function(v) mic[#mic+1]=v end}
 gui={IsGameUIVisible=function() return false end}; vgui={GetKeyboardFocus=function() return nil end}
 system={HasFocus=function() return true end}
 ix.gui={}; selectedKey=0; keyDown=false; KEY_LAST=107; MOUSE_FIRST=107; MOUSE_LAST=113
 ix.option={Get=function() return selectedKey end}
 input={IsKeyDown=function() return keyDown end}
 timers={};timer.Create=function(name,_,_,fn) timers[name]=fn end; surface={CreateFont=function() end}; function ScrH() return 1080 end
 net.WriteBool=function(v) lastSent=v end; net.SendToServer=function() end
 net.ReadBool=function() return accepted end
 `);

 suite('Radio effects isolate receivers, obey mute/volume, expire routes and cancel late audio callbacks',
 ['ixhl2rp/plugins/proximity_voice/cl_effects.lua'], `
 local V=ix.voice; local listener={valid=true}; local p={valid=true}
 function p:EntIndex() return 4 end
 function p:IsMuted() return self.muted end
 function p:SetVoiceVolumeScale(v) self.scale=v end
 local speakers={[p]=true}; local routes={[p]={mode=1,at=now}}
 V.UpdateRadioEffects(listener,speakers,routes); eq(#requests,0)
 routes[p].mode=2; V.UpdateRadioEffects(listener,speakers,routes); eq(#requests,1)
 assert(p.scale<1 and p.scale>.45)
 routes[p].mode=1; V.UpdateRadioEffects(listener,speakers,routes); eq(p.scale,1)
 local late=channel(); requests[1](late); eq(late.stopped,true); eq(late.played,nil)
 routes[p].mode=2; V.UpdateRadioEffects(listener,speakers,routes)
 local audio=channel(); requests[2](audio); eq(audio.played,true); eq(audio.looped,true)
 p.muted=true; V.UpdateRadioEffects(listener,speakers,routes); eq(audio.stopped,true); eq(p.scale,1)
 p.muted=false; intensity=0; V.UpdateRadioEffects(listener,speakers,routes); eq(#requests,2)
 intensity=.35; now=3; V.UpdateRadioEffects(listener,speakers,routes); eq(#requests,2)
 routes[p].at=now; master=0; V.UpdateRadioEffects(listener,speakers,routes); eq(#requests,2)
 master=1; V.UpdateRadioEffects(listener,speakers,routes); eq(#requests,3)
 local active=channel(); requests[3](active)
 routes[p].mode=3;routes[p].effect='radio';routes[p].gain=.4
 V.UpdateRadioEffects(listener,speakers,routes);assert(math.abs(p.scale-.4*V.RadioEffectGain(p,intensity,now))<.00001)
 routes[p].effect='pa';V.UpdateRadioEffects(listener,speakers,routes);eq(active.stopped,true);eq(p.scale,1);eq(#requests,3)
 V.Active=function() return false end; V.UpdateRadioEffects(listener,speakers,routes)
 eq(active.stopped,true); eq(p.scale,1)
 `, `
 ix.voice={Active=function() return true end}; now=0; RealTime=function() return now end
 intensity=.35; master=1; ix.option={Get=function() return intensity end}
 GetConVar=function() return {GetFloat=function() return master end} end
 hook.Add=function() end; requests={}; sound={PlayFile=function(_,_,fn) requests[#requests+1]=fn end}
 function channel()
  return {valid=true,SetVolume=function(self,v) self.volume=v end,
   EnableLooping=function(self,v) self.looped=v end,Play=function(self) self.played=true end,
   Stop=function(self) self.stopped=true end}
 end
 `);


 suite('Radio packet effects isolate recipients and clear on release, disable and disconnect',
 ['ixhl2rp/plugins/proximity_voice/sv_filter.lua'], `
 local V=ix.voice
 local a={UserID=function() return 11 end}; local b={UserID=function() return 22 end}
 V.ApplyRadioFilter(a,b,true,false); eq(routes['11:22'],5)
 V.ApplyRadioFilter(b,a,true,true); eq(routes['22:11'],nil)
 V.ApplyRadioFilter(a,b,false,false); eq(routes['11:22'],nil)
 V.ApplyRadioFilter(a,b,true,false); enabled=false
 V.ApplyRadioFilter(a,b,true,false); eq(routes['11:22'],nil)
 enabled=true; V.ApplyRadioFilter(a,a,true,false); eq(routes['11:11'],nil)
 V.ClearRadioFilter(b); eq(cleared,22)
 eightbit=nil; require=function() error('missing binary') end
 V.LoadRadioFilter(); V.ApplyRadioFilter(a,b,true,false); eq(routes['11:22'],nil)
 `, `
 ix.voice={}; enabled=true; routes={}; player={GetAll=function() return {} end}
 CreateConVar=function() return {GetBool=function() return enabled end} end
 timer.Create=function() end; hook.Add=function() end
 concommand={Add=function() end}
 eightbit={EFF_RADIO=5,IsHookAvailable=function() return true end,
 SetReceiverEffect=function(a,b,e) routes[a..':'..b]=e end,
 ClearReceiverEffect=function(a,b) routes[a..':'..b]=nil end,
 ClearPlayer=function(p) cleared=p end}
 require=function() end
 `);

 suite('Global PA registers echo through the existing module and keeps radio/proximity recipients isolated',
 ['ixhl2rp/plugins/proximity_voice/sv_filter.lua'],`
 local V=ix.voice;local a={UserID=function() return 11 end};local b={UserID=function() return 22 end}
 assert(presetText:find('echo_delay_ms=170',1,true));assert(presetText:find('highpass_hz=650',1,true))
 eq(reloaded['custom.gvox'],'version=1');eq(reloaded['ix_facility_pa.gvox'],presetText)
 V.ApplyRadioFilter(a,b,true,false,'pa');eq(routes['11:22'],2030)
 V.ApplyRadioFilter(b,a,true,false,'radio');eq(routes['22:11'],5)
 V.ApplyRadioFilter(a,b,true,false,'radio');eq(routes['11:22'],5)
 V.ApplyRadioFilter(a,b,true,true,'pa');eq(routes['11:22'],nil)
 a.valid=true;b.valid=true;b.speaking=true
 function a:IsSpeaking() return self.speaking end
 function b:IsSpeaking() return self.speaking end
 player.GetAll=function() return {a,b} end;V.Route=function() return true,false,'PA',1,'pa' end
 timers.ixRadioFilterRoutes();eq(routes['11:22'],2030);eq(routes['11:11'],nil)
 -- Old echo samples are discarded after speech; only active speakers get routes.
 a.valid=true;b.valid=true;a.speaking=true
 function a:IsSpeaking() return self.speaking end
 timers.ixRadioFilterRoutes();eq(clearCount,0)
 a.speaking=false;now=.3;timers.ixRadioFilterRoutes();eq(clearCount,0)
 now=.6;timers.ixRadioFilterRoutes();eq(clearCount,1);eq(routes['11:22'],2030);eq(routes['22:11'],nil)
 now=2;timers.ixRadioFilterRoutes();eq(clearCount,1)
 V.Route=function() return false,false,'' end;timers.ixRadioFilterRoutes();eq(routes['11:22'],nil)
 writeOK=false;V.LoadRadioFilter();V.ApplyRadioFilter(a,b,true,false,'pa');eq(routes['11:22'],5)
 eightbit.WritePresetFile=nil;V.LoadRadioFilter();V.ApplyRadioFilter(a,b,true,false,'pa');eq(routes['11:22'],5)
 `,`
 ix.voice={};enabled=true;routes={};timers={};writeOK=true;now=0;clearCount=0;CurTime=function() return now end
 player.GetAll=function() return {} end;CreateConVar=function() return {GetBool=function() return enabled end} end
 timer.Create=function(n,_,_,fn) timers[n]=fn end;hook.Add=function() end;concommand={Add=function() end}
 file={Find=function() return {'custom.gvox'} end,Read=function() return 'version=1' end}
 eightbit={EFF_RADIO=5,IsHookAvailable=function() return true end,
 SetReceiverEffect=function(a,b,e) routes[a..':'..b]=e end,ClearReceiverEffect=function(a,b) routes[a..':'..b]=nil end,
 ClearPlayer=function(id)
  for key in pairs(routes) do if key:match('^'..id..':') or key:match(':'..id..'$') then routes[key]=nil end end
  clearCount=clearCount+1
 end,
 WritePresetFile=function(name,content) eq(name,'ix_facility_pa.gvox');presetText=content;return writeOK,'test disk error' end,
 ReloadPresets=function(rows) reloaded=rows end,GetPresets=function() return {{key='ix_facility_pa',file='ix_facility_pa.gvox',id=2030}} end}
 require=function() end
 `);
};
