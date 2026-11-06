module.exports = function(suite) {
 const shared = 'ixhl2rp/plugins/proximity_voice/sh_plugin.lua';
 const setup = `
 ix.config.Add=function() end
 timers={};timer.Create=function(name,delay,count,fn) timers[name]=fn end
 `;
 suite('Local speech hides the default card and self indicator while speaker occlusion still follows voice events',
 [shared,'ixhl2rp/plugins/proximity_voice/cl_voice.lua'], `
 local listener={valid=true,GetCharacter=function() return {} end,Alive=function() return true end,EyePos=function() return 0 end}
 function LocalPlayer() return listener end
 local talker={valid=true,EyePos=function() return 1 end,WaterLevel=function() return 0 end,IsMuted=function() return false end}
 function talker:SetVoiceVolumeScale(v) self.gain=v end
 local wall=true
 util.TraceLine=function() return {Hit=wall} end
 eq(PLUGIN:PlayerStartVoice(talker),true)
 eq(PLUGIN:HUDShouldDraw('CHudVoiceSelfStatus'),false);eq(PLUGIN:HUDShouldDraw('CHudHealth'),nil)
 timers.ixVoiceOcclusion();near(talker.gain,.3)
 wall=false;timers.ixVoiceOcclusion();eq(talker.gain,1)
 wall=true;PLUGIN:PlayerEndVoice(talker);timers.ixVoiceOcclusion();eq(talker.gain,1)
 eq(PLUGIN:PlayerStartVoice(nil),true);PLUGIN:PlayerEndVoice(nil)
 `,setup+'\nSERVER=false;CLIENT=true');
 suite('The server hides overhead voice icons without changing spatial range and character restrictions',
 [shared,'ixhl2rp/plugins/proximity_voice/sv_voice.lua'], `
 local icons,writes=true,0
 GetConVar=function(n) eq(n,'mp_show_voice_icons');return {GetBool=function() return icons end} end
 RunConsoleCommand=function(n,v) eq(n,'mp_show_voice_icons');eq(v,'0');icons=false;writes=writes+1 end
 hook.Run('InitPostEntity');eq(writes,1);timers.ixVoiceHideEngineIcons();eq(writes,1)
 icons=true;timers.ixVoiceHideEngineIcons();eq(writes,2)
 local function person(x)
  return {valid=true,GetCharacter=function() return {} end,Alive=function() return true end,
   InCriticalState=function() return false end,GetLocalVar=function() return false end,GetNetVar=function(p) return p.gagged end,
   GetPos=function() return {x=x,DistToSqr=function(a,b) return (a.x-b.x)^2 end} end}
 end
 local talker=person(0)
 local audible,spatial=PLUGIN:PlayerCanHearPlayersVoice(person(600),talker);eq(audible,true);eq(spatial,true)
 eq(PLUGIN:PlayerCanHearPlayersVoice(person(601),talker),false)
 talker.gagged=true;eq(PLUGIN:PlayerCanHearPlayersVoice(person(1),talker),false)
 `,setup);
};
