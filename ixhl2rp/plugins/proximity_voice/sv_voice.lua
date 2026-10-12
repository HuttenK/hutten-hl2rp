local PLUGIN=PLUGIN
local V=ix.voice
util.AddNetworkString("ixRadioVoicePTT")
util.AddNetworkString("ixRadioVoiceAck")
util.AddNetworkString("ixVoiceRoute")
-- Channel tables also contain faction/class/personal permissions. Keep those
-- semantics, while checking item-only frequencies against the equipped radio.
function V.ChannelAccess(p,id,number)
 if not ix.radio or not p.listenChannels or not p.globalChannels then return false end
 if not p.listenChannels[id] and not p.globalChannels[id] then return false end
 if not ix.radio:HasPlayerChannel(p,id,number) then return false end
 local c=p:GetCharacter(); if not c then return false end
 local faction=ix.faction.indices[c:GetFaction()]
 local class=ix.class.list[c:GetClass()]
 if (faction and faction.listenChannels and faction.listenChannels[id]) or
  (class and class.listenChannels and class.listenChannels[id]) or
  (c:GetRadioChannels() or {})[id] or (p.tempChannels or {})[id] then return true end
 local itemID=p:GetFirstAtSlot(1,1,"radio")
 local item=itemID and ix.Item.instances[itemID]
 return item and item.IsOn and item:IsOn() and item:GetFrequencyID()==id and
  (not item.factionLock or item.factionLock[p:Team()]) or false
end
function V.Transmission(p)
 if not V.CanSpeak(p) or p:IsRestricted() or not ix.radio then return end
 local id=p:GetNetVar("radioChannel")
 local station=p:GetEyeTraceNoCursor().Entity
 local stationary=IsValid(station) and station:GetClass()=="ix_stationary_radio" and station:IsOn() and
  p:GetShootPos():DistToSqr(station:GetPos())<=128^2
 if stationary then id=station:GetFrequency() end
 local channel=ix.radio.channels[id]
 if not channel or (not stationary and not V.ChannelAccess(p,id)) then return end
 local targets=channel.global and table.Copy(channel.targetChannels) or
  {[id]=channel.subChannels>1 and ((p.listenChannels or {})[id] or 1) or true}
 local info={player=p,text="",voice=true,bShouldSend=true,
  data={channelID=id,channel=channel.name,transmitTable=targets,range=ix.config.Get("voiceRange",600)}}
 hook.Run("AdjustRadioTransmitInfo",info)
 if info.bShouldSend then return info end
end
function V.RadioListener(listener,info)
 -- Reuse channel matching, but prevent stale item channel grants after unequip.
 for id,number in pairs(info.data.transmitTable) do
  if V.ChannelAccess(listener,id,number) then return true end
 end
 for _,radio in ipairs(ents.FindByClass("ix_stationary_radio")) do
  if radio:IsOn() and radio:GetFrequency()==info.data.channelID and
   V.Position(listener):DistToSqr(radio:GetPos())<ix.config.Get("chatRange",280)^2 then return true end
 end
 return false
end
function V.Route(listener,talker)
 if not V.Active(listener) or not V.CanSpeak(talker) then return false,false,"" end
 local held=talker.ixRadioVoice
 if held and held.character==talker:GetCharacter() and held.expires>CurTime() then
  local info=V.Transmission(talker)
  if info and info.data.channelID==held.channel and (listener==talker or V.RadioListener(listener,info)) then
   return true,false,tostring(info.data.channel or "RADIO")
  end
 end
 local facility=ix.plugin.list.facility_utilities
 if facility then local hear,spatial,label,gain=facility:VoiceRoute(listener,talker);if hear then return hear,spatial,label,gain end end
 if V.Position(listener):DistToSqr(V.Position(talker))<=ix.config.Get("voiceRange",600)^2 then return true,true,"" end
 return false,false,""
end
function PLUGIN:PlayerCanHearPlayersVoice(listener,talker)
 local hear,spatial,label,gain=V.Route(listener,talker)
 if V.ApplyRadioFilter then V.ApplyRadioFilter(listener,talker,hear,spatial) end
 listener.ixVoiceRoutes=listener.ixVoiceRoutes or {}
 local old=listener.ixVoiceRoutes[talker]
 local mode=hear and (gain and 3 or spatial and 1 or 2) or 0
 if not old or old.mode~=mode or old.label~=label or old.at+1<CurTime() or math.abs((old.gain or 1)-(gain or 1))>.1 then
  listener.ixVoiceRoutes[talker]={mode=mode,label=label,gain=gain,at=CurTime()}
  net.Start("ixVoiceRoute"); net.WriteEntity(talker); net.WriteUInt(mode,2); net.WriteString(label);if mode==3 then net.WriteFloat(gain) end; net.Send(listener)
 end
 return hear,spatial
end
net.Receive("ixRadioVoicePTT",function(length,p)
 if length>8 then return end
 local on=net.ReadBool()
 if not on then p.ixRadioVoice=nil return end
 if (p.ixVoiceNextRequest or 0)>CurTime() then return end
 p.ixVoiceNextRequest=CurTime()+.2
 local info=V.Transmission(p)
 p.ixRadioVoice=info and {character=p:GetCharacter(),channel=info.data.channelID,expires=CurTime()+2.5} or nil
 net.Start("ixRadioVoiceAck"); net.WriteBool(info~=nil); net.Send(p)
end)
function PLUGIN:PlayerDeath(p) p.ixRadioVoice=nil; p.ixVoiceRoutes=nil end
function PLUGIN:PlayerLoadedCharacter(p) p.ixRadioVoice=nil; p.ixVoiceRoutes=nil end
function PLUGIN:PlayerDisconnected(p)
 for _,other in ipairs(player.GetAll()) do if other.ixVoiceRoutes then other.ixVoiceRoutes[p]=nil end end
end

-- This is a SERVER replicated ConVar. Client writes cannot enforce it.
function V.HideEngineIcons()
 local icons=GetConVar("mp_show_voice_icons")
 -- Engine-created ConVars reject Lua setters, even in the server realm.
 if icons and icons:GetBool() then RunConsoleCommand("mp_show_voice_icons", "0") end
end
hook.Add("InitPostEntity","ixVoiceHideEngineIcons",V.HideEngineIcons)
-- Also handles Lua reloads and server.cfg/addons resetting it after map startup.
timer.Create("ixVoiceHideEngineIcons",2,0,V.HideEngineIcons)
