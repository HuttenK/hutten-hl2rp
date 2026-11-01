module.exports=function(suite){
 const fs=require('fs'),path=require('path'),{normalize}=require('./glua.cjs');
 const read=file=>fs.readFileSync(path.join(__dirname,'..',file),'utf8');
 const dragSetup=['sharedposes','pose-gizmo','body-drag'].map(f=>read('tools/fixtures/'+f+'.lua')).join('\n');
 suite('Taking a casualty during the visible fall cancels crawl, releases the death driver and retains the drag grip',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua',
  'ixhl2rp/plugins/body_drag/sh_drag.lua','ixhl2rp/plugins/body_drag/sh_weapons.lua','ixhl2rp/plugins/body_drag/sv_drag.lua'],`
 patient.vars.crit=true;patient.vars.criticalFallUntil=clock+5;patient.vars.criticalCrawlUntil=clock+30
 body.AnimModule={valid=true,Remove=function(self) self.valid=false end}
 local driver=body.AnimModule
 assert(ix.BodyDrag.Start(carrier,body));eq(patient.vars.criticalFallUntil,nil)
 eq(patient.vars.criticalCrawlUntil,nil);eq(patient.vars.crit,true);eq(patient.vars.knocked,true)
 eq(driver.valid,false);eq(ix.BodyDrag.Body(carrier),body)
 clock=clock+40;ix.Downed.CrawlTick(patient);eq(patient.ixRagdoll,body);eq(body.valid,true)
 `,dragSetup+`ix.Downed={};concommand={Add=function() end}`);

 const proneClient=read('addons/ix_crawl_animation_content/lua/prone/cl_prone.lua');
 const proneShared=read('addons/ix_crawl_animation_content/lua/prone/sh_prone.lua');
 const handle=proneShared.slice(proneShared.indexOf('function prone.Handle(ply)'),proneShared.indexOf('local proneMoveSpeed'));
 suite('Voluntary prone blocks double-Ctrl, console requests and server impulses while keeping ordinary crouch input',
 ['ixhl2rp/plugins/pronesupport.lua'],`
 ${normalize(proneClient.slice(0,proneClient.indexOf('-- If they enable jump')))}
 ${normalize(handle)}
 local cmd={buttons=IN_DUCK,SetImpulse=function() error('Voluntary prone impulse escaped') end}
 for i=1,10 do commands.prone();hooks['prone.ReadBindKeys'](cmd);clock=clock+.1 end
 eq(cmd.buttons,IN_DUCK);prone.Handle(p)
 eq(PLUGIN['prone.ShouldChangeCalcView'](),false)
 eq(PLUGIN['prone.ShouldChangeCalcViewModelView'](),false)
 `,`
 SERVER=false;CLIENT=true;IN_DUCK=4;hooks={};commands={}
 hook.Add=function(_,id,fn) hooks[id]=fn end
 hook.Run=function(event,...) if PLUGIN[event] then return PLUGIN[event](PLUGIN,...) end end
 concommand={Add=function(name,fn) commands[name]=fn end}
 CreateClientConVar=function() return {GetBool=function() return true end,GetInt=function() return 83 end} end
 p={valid=true,IsProne=function() return false end};function LocalPlayer() return p end
 prone={Config={DefaultBindKey=83}}
 prone.CanEnter=function(ply) return hook.Run('prone.CanEnter',ply)~=false end
 prone.Enter=function() error('Server accepted voluntary prone') end
 `);

 suite('Complex Death Animations play once for the conscious fall, fit its deadline and do not restart after crawling',
 ['addons/death_animations/lua/autorun/server/sv_sdohnahyi.lua'],`
 cvars.bd_enable_players.value=1;cvars.bd_anim_chance.value=0
 -- Keep this independent of any archived animation chance or NPC crawl setting.
 local rag={valid=true,IsPlayerHolding=function() return false end,
  GetModelScale=function() return .9167 end,CallOnRemove=function() end}
 local p={valid=true,ixRagdoll=rag,Alive=function() return true end,
  GetNetVar=function() return clock+5 end,GetPos=function() return 1 end,GetAngles=function() return {y=0} end}
 hooks.OnCharacterFallover(p,rag,true);eq(#queued,1);queued[1]()
 eq(spawned,1);assert(driver.rate>1);assert(driver.ExpiresAt<=clock+5);eq(#queued,1)
 eq(rag.IsDeathRagdoll,true);eq(driver.scale,.9167)
 hooks.OnCharacterFallover(p,rag,true);queued[2]();eq(spawned,1)
 falling=false;hooks.OnCharacterFallover(p,{valid=true},true);eq(#queued,2)
 falling=true;rag.IsDeathRagdoll=nil;hooks.OnCharacterFallover(p,rag,true)
 falling=false;queued[3]();eq(spawned,1)
 `,`
 hooks={};queued={};cvars={};spawned=0;falling=true
 ix.Downed={Active=function() return true end,Falling=function() return falling end}
 hook.Add=function(event,_,fn) hooks[event]=fn end
 CreateConVar=function(name,v)
  local c={value=v};function c:GetBool() return tonumber(self.value)~=0 end
  function c:GetFloat() return tonumber(self.value) end;function c:GetString() return tostring(self.value) end
  cvars[name]=c;return c
 end
 RunConsoleCommand=function() end;timer.Simple=function(_,fn) queued[#queued+1]=fn end
 function table.Random(t) return t[1] end;function Angle() return {} end
 ents.Create=function()
  spawned=spawned+1;driver={valid=true,rate=.5}
  function driver:SetModel() end;function driver:SetModelScale(v) self.scale=v end
  function driver:SetPos() end;function driver:SetAngles() end;function driver:Spawn() end
  function driver:LookupSequence() return 1,12 end
  function driver:ResetSequence() end;function driver:SetCycle() end
  function driver:GetPlaybackRate() return self.rate end;function driver:SetPlaybackRate(v) self.rate=v end
  return driver
 end
 `);
};
