module.exports=function(suite){
const accessSetup=`
 ix.util={Include=function() end};ix.log.Add=function() end;hook.Add=function() end
 concommand={Add=function() end};unpack=table.unpack;function L(s) return s end;function RealTime() return clock end
 CAMI={GetPrivilege=function() return {MinAccess='user'} end,RegisterPrivilege=function() end,PlayerHasAccess=function() return camiGrant end}
 Format=string.format;function ServerLog() logs=(logs or 0)+1 end
 function isbool(v) return type(v)=='boolean' end
 function string.Explode(sep,s) local r={} for v in (s..sep):gmatch('(.-)'..sep) do r[#r+1]=v end return r end
 function actor(admin)
  local p={valid=true,admin=admin,char={}}
  function p:IsAdmin() return self.admin end;function p:IsSuperAdmin() return self.superadmin or false end
  function p:GetCharacter() return self.char end;function p:Name() return 'Tester' end;function p:SteamID() return 'STEAM_TEST' end
  function p:Notify(s) notice=s end;function p:NotifyLocalized(s) notice=s end;function p:ChatPrint(s) notice=s end
  function p:Freeze() freezes=(freezes or 0)+1 end
  p.char.Health=function() return {Reset=function() resets=(resets or 0)+1 end} end
  p.char.GetFaction=function() return 1 end
  return p
 end
 admin=actor(true);superadmin=actor(true);superadmin.superadmin=true;guest=actor(false)
 allPlayers={admin,guest};broadcasts=0;sends=0;reads=0
 net.Start=function(n) channel=n end;net.Broadcast=function() broadcasts=broadcasts+1 end;net.Send=function(p) sends=sends+1;recipient=p end
 net.WriteString=function() end;net.WriteBool=function() end;net.WriteUInt=function() end
 net.ReadString=function() reads=reads+1;return message or 'AUTHORIZED' end
 net.ReadBool=function() return true end;net.ReadUInt=function() return revision or 0 end
 function PLUGIN:SetData(v) saved=v end
 `;
suite('Intro and both endings require live admin status despite stale CAMI grants or direct callbacks',[
 'helix/gamemode/core/libs/sh_command.lua','ixhl2rp/plugins/z_intro/sh_plugin.lua',
 'ixhl2rp/plugins/z_ending/sh_plugin.lua','ixhl2rp/plugins/z_endingnotext/sh_plugin.lua'],`
 for _,name in ipairs({'StartIntro','StartEnding','StartEndingNoText'}) do
  local c=ix.command.list[name:lower()];camiGrant=true
  eq(ix.command.HasAccess(guest,name),false);eq(c:OnCheckAccess(nil),false)
  c:OnRun(guest);c:OnRun(nil);eq(broadcasts,0);eq(freezes,nil);eq(resets,nil)
 end
 camiGrant=false
 for _,p in ipairs({admin,superadmin}) do
  for _,name in ipairs({'StartIntro','StartEnding','StartEndingNoText'}) do
   assert(ix.command.HasAccess(p,name));clock=clock+1;ix.command.Run(p,name,{})
  end
 end
 eq(broadcasts,6);eq(freezes,8);eq(resets,8)
 admin.admin=false;camiGrant=true;local before=broadcasts;clock=clock+1
 ix.command.Run(admin,'StartIntro',{});ix.command.list.startending:OnRun(admin);eq(broadcasts,before)
 `,accessSetup);
suite('StatusHUD editing remains admin-only after demotion while HUD recipients require MTF',[
 'helix/gamemode/core/libs/sh_command.lua','ixhl2rp/plugins/status_display/sh_plugin.lua','ixhl2rp/plugins/status_display/sv_status.lua'],`
 camiGrant=true
 for _,name in ipairs({'StatusHUD','StatusHUDClear'}) do
  eq(ix.command.HasAccess(guest,name),false);ix.command.list[name:lower()]:OnRun(guest)
 end
 PLUGIN:SendStatus(guest,true);PLUGIN:SendStatus(nil,true);eq(sends,0);eq(broadcasts,0)
 net.handlers.ixStatusHUDSave(128,guest);net.handlers.ixStatusHUDSave(128,nil);eq(reads,0);eq(PLUGIN.status.revision,0)
 camiGrant=false;assert(ix.command.HasAccess(admin,'StatusHUD'));ix.command.Run(admin,'StatusHUD',{})
 eq(channel,'ixStatusHUDEdit');eq(recipient,admin)
 net.handlers.ixStatusHUDSave(128,admin);eq(PLUGIN.status.text,'AUTHORIZED');eq(PLUGIN.status.revision,1);eq(broadcasts,0);eq(sends,3)
 local before=sends;admin.admin=false;clock=clock+1;revision=1;message='FORGED'
 net.handlers.ixStatusHUDSave(128,admin);ix.command.list.statushudclear:OnRun(admin);eq(PLUGIN.status.text,'AUTHORIZED');eq(sends,before)
 net.handlers.ixStatusHUDReady(0,guest);eq(channel,'ixStatusHUD');eq(recipient,guest)
 PLUGIN:PlayerLoadedCharacter(guest);eq(channel,'ixStatusHUD')
 admin.admin=true;ix.command.Run(admin,'StatusHUDClear',{});eq(PLUGIN.status.enabled,false);eq(PLUGIN.status.text,'')
 `,accessSetup);
};
