module.exports = suite => {
 const library='helix/gamemode/core/libs/sh_broadcastmedia.lua';
 suite('Broadcast subtitle parsing accepts SRT/VTT and rejects malformed or oversized cues', [library], `
 local M=ix.BroadcastMedia
 local cues=M.ParseSubtitles('1\\r\\n00:00:01,000 --> 00:00:03,500\\r\\nHello\\r\\nWorld\\r\\n\\r\\n')
 eq(#cues,1); near(cues[1].start,1); near(cues[1].finish,3.5); eq(cues[1].text,'Hello\\nWorld')
 local v=M.ParseSubtitles('WEBVTT\\n\\nfirst\\n00:02.000 --> 00:04.000 align:start\\n<b>Caption</b>\\n\\n')
 eq(v[1].text,'Caption'); eq(v[1].start,2)
 assert(not M.ParseSubtitles('1\\n00:99:00,000 --> 01:00:00,000\\nBad'))
 assert(not M.ParseSubtitles(string.rep('x',48001)))
 eq(#M.ParseSubtitles(''),0)
 assert(M.ValidSource('https://example.com/a.webm?x=1&y=2'))
 assert(not M.ValidSource('javascript:alert(1)')); assert(not M.ValidSource('../secret'))
 assert(not M.ValidSource('https://x/\" onload=\"bad'))
 assert(M.StartTime(10)>10); eq(M.Volume(2100,400,2100),0); eq(M.Volume(100,400,2100),1)
 `);
 const setup=`
 SERVER=false; CLIENT=true; GMOD_CHANNEL_STOPPED=0
 callbacks={}; requests=0
 sound={PlayURL=function(_,flags,cb) assert(flags:find('noplay')); requests=requests+1; callbacks[requests]=cb end}
 sound.PlayFile=sound.PlayURL
 function device() return {valid=true,GetPos=function() return {} end} end
 function channel(length,buffer)
  local c={valid=true,length=length or 100,buffer=buffer or 100,played=0,volume=-1,state=1}
  function c:Stop() self.valid=false end
  function c:GetLength() return self.length end
  function c:IsBlockStreamed() return false end
  function c:GetBufferedTime() return self.buffer end
  function c:SetTime(v) self.time=v end
  function c:SetPos() end; function c:Set3DFadeDistance() end
  function c:SetVolume(v) self.volume=v end
  function c:Play() self.played=self.played+1 end
  function c:EnableLooping(v) self.loop=v end
  function c:GetState() return self.state end
  return c
 end
 function src(start,loop) return {path='a.wav',start=start or 0,loop=loop~=false,volume=1} end
 `;
 suite('Broadcast audio deduplicates pending loads and rejects same-track stale callbacks', [library], `
 local m=ix.BroadcastMedia.NewAudio('test',80,500); local e=device()
 m:Update({[e]=src()}); m:Update({[e]=src()}); eq(requests,1)
 m:Update({[e]=src(5)}); eq(requests,2)
 local stale=channel(); callbacks[1](stale); eq(stale.valid,false)
 local c=channel(); callbacks[2](c); eq(c.loop,true); near(c.time,5)
 m:Update({[e]=src(5)}); eq(c.volume,1)
 m:Update({}); eq(c.valid,false); assert(m.entries[e]==nil)
 `,setup);
 suite('Broadcast channels are owned by entity identity and bounded in aggregate volume', [library], `
 local m=ix.BroadcastMedia.NewAudio('test',80,500); local a,b=device(),device()
 m:Update({[a]=src(),[b]=src()}); local ca,cb=channel(),channel(); callbacks[1](ca); callbacks[2](cb)
 m:Update({[a]=src(),[b]=src()}); near(ca.volume,.5); near(cb.volume,.5)
 a.valid=false; m:Update({[a]=src(),[b]=src()}); eq(ca.valid,false); eq(cb.volume,1)
 m:Destroy(); eq(cb.valid,false)
 `,setup);
 suite('Broadcast audio retries failures with backoff and cancels timed-out callbacks', [library], `
 local m=ix.BroadcastMedia.NewAudio('test',80,500); local e=device()
 m:Update({[e]=src()}); callbacks[1](nil,2,'missing'); m:Update({[e]=src()}); eq(requests,1)
 clock=13; m:Update({[e]=src()}); eq(requests,2)
 clock=44; m:Update({[e]=src()}); local stale=channel(); callbacks[2](stale); eq(stale.valid,false)
 clock=55; m:Update({[e]=src()}); eq(requests,3)
 m:Destroy(); local late=channel(); callbacks[3](late); eq(late.valid,false)
 `,setup);
 suite('Broadcast late joins wait for buffering and one-shot tracks do not wrap', [library], `
 local m=ix.BroadcastMedia.NewAudio('test',80,500); local e=device()
 clock=30; m:Update({[e]=src(0,false)}); local c=channel(100,5); callbacks[1](c)
 eq(c.played,0); eq(c.volume,0)
 c.buffer=50; m:Update({[e]=src(0,false)}); eq(c.played,1); eq(c.time,30)
 c.state=0; m:Update({[e]=src(0,false)}); eq(c.valid,false); m:Update({[e]=src(0,false)}); eq(requests,1)
 local other=device(); clock=200; m:Update({[other]=src(0,false)}); local ended=channel(); callbacks[2](ended)
 eq(ended.played,0); eq(ended.valid,false)
 `,setup);
 // TV migration, calibration and client sync are covered in test-tv-channels.cjs.
 suite('Cassette pickup preserves the original player on full inventory and blocks distant requests',
 ['ixhl2rp/plugins/cassette_player/entities/entities/ix_boombox/init.lua'], `
 local box=setmetatable({valid=true,boomboxItemID=1}, {__index=ENT})
 function box:GetPos() return {} end; function box:Remove() self.removed=true end
 local p={valid=true,IsPlayer=function() return true end,GetCharacter=function() return {} end,
 GetPos=function() return {DistToSqr=function() return distance end} end,Notify=function() end,
 GetInventory=function() return inv end}
 distance=0; box:OnSelectPickUp(p); assert(not box.removed); eq(instancesMade,0)
 clock=11; distance=100000; box:OnSelectPickUp(p); eq(adds,1)
 clock=12; distance=0; fits=true; box:OnSelectPickUp(p); eq(box.removed,true); eq(saves,1)
 `,`
 ENT={}; include=function() end; AddCSLuaFile=function() end
 instancesMade,adds,saves=0,0,0; fits=false
 ix.Item={instances={[1]={id=1,Save=function() saves=saves+1 end}},Instance=function() instancesMade=instancesMade+1 end}
 inv={AddItemByID=function() adds=adds+1; return fits end,Sync=function() end}
 `);
 suite('Cassette restart restores both original item references and locks interaction during async loads',
 [library,'ixhl2rp/plugins/cassette_player/sv_plugin.lua'], `
 PLUGIN:LoadData(); eq(#loads,2); assert(box.loadingItems)
 eq(box.boomboxItemID,10); eq(box.cassetteInstanceID,11)
 loads[1](); assert(box.loadingItems); loads[2](); eq(box.loadingItems,false)
 PLUGIN:LoadData(); eq(#loads,2)
 `,`
 PLUGIN={GetData=function() return {{pos={},ang={},boomboxItemID=10,cassetteInstanceID=11,cassetteName='Tape',track='a.wav'}} end}
 loads={}; ix.Item={instances={},LoadInstanceByID=function(_,id,_,cb) loads[#loads+1]=cb end}
 box={valid=true,SetPos=function() end,SetAngles=function() end,Spawn=function() end,Activate=function() end,SetNetVar=function() end}
 ents.Create=function() return box end
 `);

 suite('TV HUD captions follow actual playback and reject stale, distant and replaced panel reports',
 ['ixhl2rp/plugins/tv_screen/cl_subtitles.lua'], `
 PLUGIN.htmlPanel={valid=true}; local panel=PLUGIN.htmlPanel
 PLUGIN.tvSubtitleCues={{start=1,finish=3,text='First'},{start=2,finish=4,text='Second'}}
 PLUGIN.tvSubtitleNearby=true
 PLUGIN:SetTVPlayback(panel,2.5,true); eq(PLUGIN:GetTVSubtitle(),'First\\nSecond')
 PLUGIN:SetTVPlayback(panel,3,true); eq(PLUGIN:GetTVSubtitle(),'Second')
 PLUGIN:SetTVPlayback({},1,true); eq(PLUGIN:GetTVSubtitle(),'Second')
 PLUGIN:SetTVPlayback(panel,0/0,true); eq(PLUGIN:GetTVSubtitle(),'Second')
 clock=11; eq(PLUGIN:GetTVSubtitle(),'')
 PLUGIN:SetTVPlayback(panel,2,true); PLUGIN.tvSubtitleNearby=false; eq(PLUGIN:GetTVSubtitle(),'')
 PLUGIN.tvSubtitleNearby=true; PLUGIN:SetTVPlayback(panel,2,false); eq(PLUGIN:GetTVSubtitle(),'')
 PLUGIN:SetTVPlayback(panel,2,true); PLUGIN:ClearTVPlayback(); eq(PLUGIN:GetTVSubtitle(),'')
 local lines=PLUGIN:WrapTVSubtitle('Привет мир',6); eq(#lines,2); eq(lines[1],'Привет'); eq(lines[2],'мир')
 local long=PLUGIN:WrapTVSubtitle('абвгдеж',3); eq(long[1],'абв'); eq(long[2],'где'); eq(long[3],'ж')
 `, `
 function RealTime() return clock end
 function ScrH() return 1080 end
 hook.Add=function() end
 surface={CreateFont=function() end,SetFont=function() end,GetTextSize=function(text)
 local n=0; for _ in text:gmatch('[%z\\1-\\127\\194-\\244][\\128-\\191]*') do n=n+1 end; return n end}
 `);
};
