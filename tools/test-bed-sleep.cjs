const {run,source,native,read,finish}=require('./restored-test-runner.cjs');
const assert=require('assert'),fs=require('fs'),path=require('path'),parser=require('luaparse'),{normalize}=require('./glua.cjs');
const files=['sh_plugin.lua','sh_beds.lua','sv_sleep.lua','cl_sleep.lua'].map(f=>'ixhl2rp/plugins/sleep/'+f);
for(const file of files) parser.parse(normalize(read(file)),{luaVersion:'5.2'});
console.log('PASS normalized Lua syntax: all four bed-rest files');
const env=source(['tools/geometry-fixture.lua'])+`
 local V=getmetatable(Vector());function V:DistToSqr(b) return (self-b):LengthSqr() end
 function math.NormalizeAngle(n) return (n+180)%360-180 end
 function math.AngleDifference(a,b) return math.NormalizeAngle(a-b) end
 MOVETYPE_WALK=2;MOVETYPE_NONE=0;MOVETYPE_OBSERVER=10;MOVETYPE_NOCLIP=8
 MASK_SOLID=1;MASK_PLAYERSOLID=2;IN_USE=32;IN_JUMP=2;IN_ATTACK=1;IN_ATTACK2=2048;IN_DUCK=4;IN_RELOAD=8192
 NULL={valid=false};local PLAYER=FindMetaTable('Player')
 ix.util={Include=function() end};ix.command={stored={},Add=function(k,v) ix.command.stored[k]=v end}
 ix.Net={Type={Angle=1,Bool=2},vars={}}
 function ix.Net:AddPlayerVar(k,localOnly,_,kind) self.vars[k]={localOnly=localOnly,kind=kind} end
 ix.bed={stored={['bed.mdl']={rate=.25},['models/props/interior/bunkbed.mdl']={rate=.25}}}
 ix.sharedPoses={Clear=function() end}
 function hook.Run(name,...) if PLUGIN[name] then return PLUGIN[name](PLUGIN,...) end end
 for _,k in ipairs({'Start','WriteEntity','WriteUInt','WriteBool','Send','Broadcast'}) do net[k]=function() end end
 local function clear() return {Hit=false,StartSolid=false,AllSolid=false} end
 util.TraceHull=function(args) return hullTrace and hullTrace(args) or clear() end
 util.TraceLine=function(args)
  if lineTrace then return lineTrace(args) end
  local bed=testBed
  if args.start.z>bed.pos.z+bed.high.z and args.endpos.z<args.start.z then
   return {Hit=true,StartSolid=false,Entity=bed,HitNormal=Vector(0,0,1),HitPos=Vector(args.start.x,args.start.y,bed.pos.z+10)}
  end
  return {Hit=true,StartSolid=false,Entity=bed,HitPos=bed.pos,HitNormal=Vector(0,0,1)}
 end
 function bed()
  local b={valid=true,class='prop_physics',model='bed.mdl',pos=Vector(36,0,0),angle=Angle(),low=Vector(-44,-22,-10),high=Vector(44,22,25)}
  function b:GetClass() return self.class end;function b:GetModel() return self.model end
  function b:GetPos() return self.pos end;function b:GetAngles() return self.angle end
  function b:GetUp() return self.angle:Up() end;function b:GetParent() return NULL end
  function b:GetVelocity() return self.velocity or Vector() end
  function b:OBBMins() return self.low end;function b:OBBMaxs() return self.high end
  function b:LocalToWorld(v) return self.pos+self.angle*v end
  function b:NearestPoint(v) return self.pos end;function b:WorldSpaceCenter() return self.pos end
  function b:IsWorld() return false end
  testBed=b;return b
 end
 function playerFixture()
  local p=setmetatable({valid=true,vars={canShoot=true},locals={},nw={},character={id=1},alive=true,model='citizen.mdl',pos=Vector(0,0,0),angle=Angle(),move=MOVETYPE_WALK,view=Vector(0,0,64),duckView=Vector(0,0,28),seq=7}, {__index=PLAYER})
  function p:GetCharacter() return self.character end;function p:Alive() return self.alive end
  function p:GetNetVar(k,d) local v=self.vars[k];if v==nil then return d end;return v end
  function p:SetNetVar(k,v) self.vars[k]=v end
  function p:GetLocalVar(k,d) local v=self.locals[k];if v==nil then return d end;return v end
  function p:SetLocalVar(k,v) self.locals[k]=v end
  function p:GetNW2Bool(k,d) return self.nw[k] or d end
  function p:GetMoveType() return self.move end;function p:SetMoveType(v) self.move=v end
  function p:IsPlayer() return true end;function p:IsProne() return self.prone or false end
  function p:OnGround() return true end;function p:InVehicle() return self.vehicle or false end
  function p:WaterLevel() return self.water or 0 end;function p:IsRestricted() return self.restricted or false end
  function p:IsFrozen() return self.frozen or false end
  function p:GetVelocity() return Vector() end;function p:SetLocalVelocity(v) self.velocity=v end
  function p:GetPos() return self.pos end;function p:SetPos(v) self.pos=v;self.setPosCount=(self.setPosCount or 0)+1 end
  function p:GetModel() return self.model end;function p:GetModelScale() return 1 end
  function p:GetViewOffset() return self.view end;function p:SetViewOffset(v) self.view=v end
  function p:GetViewOffsetDucked() return self.duckView end;function p:SetViewOffsetDucked(v) self.duckView=v end
  function p:GetShootPos() return self.pos+self.view end;function p:GetAimVector() return Vector(1,0,0) end
  function p:GetAngles() return self.angle end;function p:SetAngles(v) self.angle=v end
  function p:LookupSequence(name) return self.seq end;function p:SequenceDuration() return 1 end
  function p:GetSequenceInfo() return {bbmin=Vector(-40,-12,0),bbmax=Vector(40,12,20)} end
  function p:SetCycle() end;function p:SetPlaybackRate() end;function p:EntIndex() return 1 end
  function p:Notify(v) self.message=v end
  function p:GetHull() return Vector(-16,-16,0),Vector(16,16,72) end
  function p:SetRenderAngles(v) self.renderAngle=v end
  return p
 end
 `+native('helix/gamemode/core/libs/sh_anims.lua','function playerMeta:ForceSequence','else\n\tnet.Receive("ixSequenceSet",').replaceAll('playerMeta:','PLAYER:')+
 source(files.slice(0,3))+`
 local S=ix.sleep;local P=PLUGIN
 local geometry={CanReach=S.CanReach,BedTransform=S.BedTransform,ClearPlacement=S.ClearPlacement,ExitPosition=S.ExitPosition,HullClear=S.HullClear}
 function simpleGeometry()
  S.CanReach=function(p,b) return S.IsBed(b) end
  S.BedTransform=function(p,b) return b.pos+Vector(0,0,14),Angle() end
  S.ClearPlacement=function() return true end
  S.ExitPosition=function(p,s) return s.returnPos end
 end
 function start(asleep)
  simpleGeometry();local b=bed();local p=playerFixture();eq(P:BeginBedRest(p,b,asleep~=false),nil);assert(P.bedSessions[p]);return p,b,P.bedSessions[p]
 end
 `;
function suite(name,test){run(name,env+'\n'+test);}
suite('Native ForceSequence owns movement/shooting; rest to sleep to wake restores exact view without changing hull, medical or XP',`
 local p,b,s=start(false);eq(p.move,MOVETYPE_NONE);eq(p.vars.canShoot,false);eq(p.vars.forcedSequence,7);eq(S.IsSleeping(p),false)
 p.healRate=.25;p.locals.knocked=nil
 eq(P:BeginBedRest(p,nil,true),nil);eq(S.IsSleeping(p),true);eq(P.bedOccupants[b],p)
 eq(P:WakeBedRest(p),nil);eq(p.move,MOVETYPE_WALK);eq(p.vars.canShoot,true);eq(p.vars.forcedSequence,nil)
 eq(p.view.z,64);eq(p.duckView.z,28);eq(p.healRate,.25);eq(p.locals.knocked,nil);eq(P.bedOccupants[b],nil);eq(P.bedSessions[p],nil)
 eq(p.pos:DistToSqr(s.returnPos),0);local changes=p.setPosCount;P:WakeBedRest(p);eq(p.setPosCount,changes)
`);
suite('Cellar/SD down-only models sleep using their own lying sequence; unknown and standing-only models are rejected',`
 simpleGeometry();local b=bed();local p=playerFixture()
 local available={stances_down02=91,stances_down01=92}
 function p:LookupSequence(name) return available[name] or -1 end
 local name,id=S.RestSequence(p);eq(name,'stances_down02');eq(id,91)
 eq(P:BeginBedRest(p,b,true),nil);eq(p.vars.forcedSequence,91);eq(P.bedSessions[p].sequence,91)
 eq(P:WakeBedRest(p),nil);eq(p.vars.forcedSequence,nil);eq(p.move,MOVETYPE_WALK)
 clock=clock+1;available={idle_all_01=3};assert(P:BeginBedRest(p,b,true));eq(P.bedSessions[p],nil);eq(p.move,MOVETYPE_WALK)
 clock=clock+1;available={stances_down03=0};eq(S.RestSequence(p),'stances_down03');eq(P:BeginBedRest(p,b,false),nil);eq(p.vars.forcedSequence,0)
`);
suite('Bed activity resolves local sequence IDs and rejects standing/empty aliases even when LookupSequence succeeds',`
 local p=playerFixture()
 function p:LookupSequence(name) return name=='custom_male_down02' and 12 or name=='stances_down02' and 91 or -1 end
 function p:GetSequenceInfo(id)
  if id==12 then return {bbmin=Vector(-15,-15,0),bbmax=Vector(15,15,72)} end
  return {bbmin=Vector(-28,-12,-1),bbmax=Vector(40,17,13)}
 end
 local name,id=S.RestSequence(p);eq(name,'stances_down02');eq(id,91)
 p.vars.bedRestAngle=Angle();p.vars.forcedSequence=12
 local activity,sequence=P:CalcMainActivity(p);eq(activity,-1);eq(sequence,91)
 p.vars.bedRestAngle=nil;eq(P:CalcMainActivity(p),nil)
 function p:GetSequenceInfo() return {bbmin=Vector(),bbmax=Vector()} end
 eq(S.RestSequence(p),nil)
`);
suite('Server occupancy rejects simultaneous requests, preserves medical bed.user, and releases for the next sleeper',`
 local p,b=start();local q=playerFixture();assert(P:BeginBedRest(q,b,true));eq(P.bedSessions[q],nil)
 P:WakeBedRest(p);clock=clock+1;b.user=p;assert(P:BeginBedRest(q,b,true));eq(b.user,p)
 clock=clock+1;b.user=nil;eq(P:BeginBedRest(q,b,true),nil);eq(P.bedOccupants[b],q)
`);
suite('A blocked wake opens eyes and retains occupancy until safe; retry recovers without unsafe teleport',`
 local p,b=start();S.ExitPosition=function() end
 local changes=p.setPosCount;assert(P:WakeBedRest(p));eq(S.IsSleeping(p),false);eq(p.locals.bedRestBlocked,true);eq(p.move,MOVETYPE_NONE)
 eq(P.bedOccupants[b],p);eq(p.setPosCount,changes)
 local q=playerFixture();assert(P:BeginBedRest(q,b,true));eq(P.bedSessions[q],nil)
 clock=clock+1;S.ExitPosition=function(_,s) return s.returnPos end;P:Think();eq(P.bedSessions[p],nil);eq(p.move,MOVETYPE_WALK)
`);
suite('Native external LeaveSequence and replacement retire sleep; stale callbacks cannot clear a newer sequence',`
 local p,b,s=start();local old=s.callback;p:LeaveSequence();eq(P.bedSessions[p],nil);eq(P.bedOccupants[b],nil);eq(p.view.z,64)
 clock=clock+1;P:BeginBedRest(p,b,true);local newer=P.bedSessions[p];old();eq(P.bedSessions[p],newer)
 local callback=function() end;p.seq=22;p:ForceSequence('new_act',callback,0);eq(P.bedSessions[p],nil)
 eq(p.ixSeqCallback,callback);eq(p.vars.forcedSequence,22);eq(p.move,MOVETYPE_NONE);newer.callback();eq(p.vars.forcedSequence,22)
 p:LeaveSequence();eq(p.move,MOVETYPE_WALK)
`);
suite('Ragdoll handoff preserves observer, knocked and medical ownership; custom later view is not overwritten',`
 local p,b=start();p.move=MOVETYPE_OBSERVER;p.locals.ragdoll=42;p.locals.knocked=true;p.ixRagdoll={valid=true};p.healRate=1.5
 p.view=Vector(0,0,12);P:OnCharacterFallover(p,p.ixRagdoll,true)
 eq(P.bedSessions[p],nil);eq(p.move,MOVETYPE_OBSERVER);eq(p.locals.ragdoll,42);eq(p.locals.knocked,true);assert(p.ixRagdoll.valid);eq(p.view.z,12);eq(p.healRate,1.5)
`);
suite('Damage, death, spawn, disconnect and pre-character switch all clean owner exactly once',`
 for _,event in ipairs({'DoPlayerDeath','PlayerDeath','PlayerSpawn','PrePlayerLoadedCharacter','PlayerDisconnected'}) do
  local p,b,s=start();local changes=p.setPosCount;P[event](P,p);eq(P.bedSessions[p],nil);eq(P.bedOccupants[b],nil);eq(p.setPosCount,changes);s.callback();clock=clock+1
 end
 local p,b=start();P:EntityTakeDamage(p,{GetDamage=function() return 0 end});assert(P.bedSessions[p])
 P:EntityTakeDamage(p,{GetDamage=function() return 1 end});eq(P.bedSessions[p],nil)
`);
suite('Invalid states reject entry including native prone, upper-body poses, critical state, restraints and carts',`
 simpleGeometry()
 for _,change in ipairs({function(p) p.prone=true end,function(p) p.nw.ixPoseStudioPlaying=true end,function(p) p.vars.crit=true end,
  function(p) p.locals.knocked=true end,function(p) p.locals.ragdoll=12 end,function(p) p.vars.brth=true end,
  function(p) p.vars.tied=true end,function(p) p.restricted=true end,function(p) p.ixPushCart={valid=true} end,
  function(p) p.locals.bIsHoldingObject=true end,function(p) p.vehicle=true end,function(p) p.frozen=true end,
  function(p) p.vars.forcedSequence=3 end,function(p) p.seq=-1 end,function(p) p.character=nil end}) do
  local b=bed();local p=playerFixture();change(p);assert(P:BeginBedRest(p,b,true));eq(P.bedSessions[p],nil);eq(p.setPosCount,nil);clock=clock+1
 end
`);
suite('Rest blocks native prone and vehicles; movement and attack input are suppressed without hardcoded key codes',`
 local p=start();eq(P['prone.CanEnter'](P,p),false);eq(P:CanPlayerEnterVehicle(p),false)
 local cmd={ClearMovement=function(self) self.cleared=true end,RemoveKey=function(self,k) self.removed=k end};P:StartCommand(p,cmd);assert(cmd.cleared);eq(cmd.removed,IN_ATTACK+IN_ATTACK2+IN_DUCK+IN_RELOAD)
 P:KeyPress(p,IN_JUMP);assert(P.bedSessions[p]);clock=clock+1;P:KeyPress(p,IN_JUMP);eq(P.bedSessions[p],nil);eq(P:PlayerUse(p,bed()),false)
`);
suite('Bed movement, rotation, removal and external player movement wake; restraints/model/character handoff never returns an old position',`
 for _,change in ipairs({function(p,b) b.pos=b.pos+Vector(4,0,0) end,function(p,b) b.angle=Angle(0,5,0) end,
  function(p,b) b.valid=false end,function(p) p.pos=p.pos+Vector(4,0,0) end}) do
  local p,b=start();change(p,b);clock=clock+1;P:Think();eq(P.bedSessions[p],nil);eq(P.bedOccupants[b],nil)
 end
 for _,change in ipairs({function(p) p.vars.tied=true end,function(p) p.character={} end,function(p) p.model='other.mdl' end,
  function(p) p.move=MOVETYPE_NOCLIP end}) do
  local p,b=start();change(p);local changes=p.setPosCount;clock=clock+1;P:Think();eq(P.bedSessions[p],nil);eq(p.setPosCount,changes)
 end
`);
suite('Missing registration, wrong entity class, denied bunks, tilted/moving beds, headboards and uneven mattresses are rejected',`
 local p=playerFixture();local b=bed();assert(S.IsBed(b));b.class='ix_item';eq(S.IsBed(b),false);b.class='ix_bed';b.model='unknown.mdl';eq(S.IsBed(b),false)
 b.model='models/props/interior/bunkbed.mdl';eq(S.BedTransform(p,b),nil);b.model='bed.mdl'
 b.angle=Angle(12,0,0);eq(S.BedTransform(p,b),nil);b.angle=Angle();b.velocity=Vector(4,0,0);eq(S.BedTransform(p,b),nil);b.velocity=nil
 lineTrace=function() return {Hit=true,Entity={},HitNormal=Vector(0,0,1),HitPos=Vector()} end;eq(S.BedTransform(p,b),nil)
 local n=0;lineTrace=function() n=n+1;return {Hit=true,Entity=b,HitNormal=Vector(0,0,1),HitPos=Vector(0,0,n==1 and 10 or 18)} end;eq(S.BedTransform(p,b),nil)
`);
suite('Five actual surface samples choose mattress height and long axis with configured offsets; never headboard OBB height',`
 local p=playerFixture();local b=bed();local pos,ang=S.BedTransform(p,b);assert(pos);eq(pos.z,14);eq(ang.y,0)
 b.low=Vector(-20,-50,-10);b.high=Vector(20,50,25);pos,ang=S.BedTransform(p,b);eq(ang.y,90)
 b.angle=Angle(0,30,0);S.layouts['bed.mdl']={center=Vector(5,8,0),yaw=180,surface=10}
 lineTrace=function(t) return {Hit=true,Entity=b,HitNormal=Vector(0,0,1),HitPos=Vector(t.start.x,t.start.y,10)} end
 pos,ang=S.BedTransform(p,b);near(pos.x,(b:LocalToWorld(Vector(5,8,0))).x);near(pos.y,(b:LocalToWorld(Vector(5,8,0))).y);eq(ang.y,-150)
`);
suite('Reach/LOS rejects walls, excessive distance and solid starts; invisible corner access cannot bypass final path checks',`
 local p=playerFixture();local b=bed();assert(S.CanReach(p,b));b.pos=Vector(300,0,0);eq(S.CanReach(p,b),false);b.pos=Vector(36,0,0)
 lineTrace=function() return {Hit=true,Entity={valid=true},StartSolid=false} end;eq(S.CanReach(p,b),false)
 lineTrace=function() return {Hit=true,Entity=b,StartSolid=true} end;eq(S.CanReach(p,b),false)
 lineTrace=function() return {Hit=true,StartSolid=false} end;eq(S.ClearPlacement(p,b,Vector(36,0,14),Angle()),false)
`);
suite('Standing hull, horizontal body and full entry sweep independently reject blocked placement',`
 local p=playerFixture();local b=bed();lineTrace=function() return {Hit=false} end
 for blocked=1,3 do
  local n=0;hullTrace=function(t) n=n+1;return {Hit=n==blocked,StartSolid=false,AllSolid=false} end
  eq(S.ClearPlacement(p,b,Vector(36,0,14),Angle()),false)
 end
 local traces={};hullTrace=function(t) traces[#traces+1]=t;return {Hit=false} end
 assert(S.ClearPlacement(p,b,Vector(36,0,14),Angle(0,90,0)));eq(traces[2].mins.z,-3);near(traces[2].maxs.x,23);near(traces[2].maxs.y,44)
`);
suite('Exit requires standing clearance and swept path; blocked former spot falls back only to clear current mattress',`
 local p=playerFixture();local b=bed();p.pos=Vector(36,0,14);local state={returnPos=Vector(),bed=b}
 local n=0;hullTrace=function(t) n=n+1;return {Hit=n==1,StartSolid=false,AllSolid=false} end
 eq(S.ExitPosition(p,state):DistToSqr(p.pos),0)
 hullTrace=function() return {Hit=true} end;eq(S.ExitPosition(p,state),nil)
 hullTrace=function(t) return {Hit=t.start:DistToSqr(t.endpos)>0} end;eq(S.ExitPosition(p,state):DistToSqr(p.pos),0)
 state.returnPos=Vector(1000,0,0);local count=0;hullTrace=function(t) count=count+1;assert(t.endpos.x<1000);return {Hit=false} end;assert(S.ExitPosition(p,state))
`);
suite('Registered custom variables match schema and aliases use lowercase Cyrillic; oversized packets cannot start rest',`
 assert(ix.Net.vars.bedRestAngle);assert(ix.Net.vars.bedRestSleeping);assert(ix.Net.vars.bedRestBlocked.localOnly)
 eq(ix.command.stored.Sleep.alias[1],'спать');eq(ix.command.stored.Wake.alias[1],'проснуться');eq(ix.command.stored.Rest.alias[1],'отдыхать')
 local p=playerFixture();net.ReadUInt=function() error('oversized packet consumed') end;net.handlers.ixBedRestRequest(1000,p);eq(P.bedSessions[p],nil)
`);
suite('Removed-bed hook and invalid entity cleanup free occupancy, commands share entry validation, no entity-menu trust shortcut',`
 local p,b=start();b.valid=false;P:EntityRemoved(b);eq(P.bedSessions[p],nil);eq(P.bedOccupants[b],nil)
 clock=clock+1;p,b=start();p.valid=false;clock=clock+1;P:Think();eq(P.bedSessions[p],nil);eq(P.bedOccupants[b],nil)
 simpleGeometry();p=playerFixture();b=bed();S.CanReach=function() return false end;net.ReadUInt=function() return 2 end;net.ReadEntity=function() return b end
 net.handlers.ixBedRestRequest(18,p);eq(P.bedSessions[p],nil);assert(p.message)
`);
suite('Actual native critical-state entry leaves the sleep sequence before critical crawl, without clearing medical state',`
 ${native('ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua','function PLAYER:SetCriticalState','function PLAYER:InCriticalState')}
 local p,b=start();local data={}
 function p.character:GetData(k,d) if data[k]==nil then return d end;return data[k] end
 function p.character:SetData(k,v) data[k]=v end
 function p:InCriticalState() return self:GetNetVar('crit',false) end
 function p:SetHealth(v) self.health=v end
 local crawled=false;ix.Downed={BeginCrawl=function(player) eq(P.bedSessions[player],nil);eq(player.vars.forcedSequence,nil);crawled=true end,CrawlWindow=function() return true end}
 p:SetCriticalState(true);assert(crawled);eq(p.vars.crit,true);eq(data.crit,true);eq(p.health,1);eq(P.bedOccupants[b],nil);eq(p.view.z,64)
`);
suite('Actual cart CanOperate rejects sleepers and native upper-body PoseAvailable rejects movement lock',`
 local PushCart={}
 ${native('ixhl2rp/plugins/pushcart/sh_plugin.lua','function PushCart:CanOperate','-- Shared cap called')}
 local Pose={PoseUser=function(_,p) return p:GetCharacter()~=nil end}
 ${native('ixhl2rp/plugins/pose_studio/sv_studio.lua','function P:PoseAvailable','function P:PlayPose').replace('function P:PoseAvailable','function Pose:PoseAvailable')}
 local p=start();assert(not PushCart:CanOperate(p));assert(not Pose:PoseAvailable(p,{mask='upper'}))
 P:WakeBedRest(p);assert(PushCart:CanOperate(p));assert(Pose:PoseAvailable(p,{mask='upper'}))
`);
suite('External teleport is never undone; invalid-owner cleanup preserves later shooting and movement state',`
 local p,b=start();p.pos=Vector(80,0,14);local count=p.setPosCount;clock=clock+1;P:Think();eq(p.setPosCount,count);eq(p.pos.x,80)
 clock=clock+1;p,b=start();p.move=MOVETYPE_OBSERVER;p.vars.canShoot=true;P:EndBedRest(p,true);eq(p.move,MOVETYPE_OBSERVER);eq(p.vars.canShoot,true)
`);
suite('Client fade reaches black, leaves readable remapped wake hint, then opens eyes; menu choices send only action and entity',`
 CLIENT=true;SERVER=false;local p,b=start();function LocalPlayer() return p end
 function math.Approach(v,target,step) return v<target and math.min(target,v+step) or math.max(target,v-step) end
 function FrameTime() return .1 end;function ScrW() return 1280 end;function ScrH() return 720 end
 input={LookupBinding=function(name) return name=='+use' and 'h' or 'mouse4' end}
 color_white={};color_black={};TEXT_ALIGN_CENTER=1;local alpha=0;local drawn={}
 surface={SetDrawColor=function(r,g,b,a) alpha=a end,DrawRect=function() end}
 draw={SimpleTextOutlined=function(text) drawn[#drawn+1]=text end}
 local options,position;ix.SimpleMenu=function() options={};return {valid=true,AddOption=function(_,label,fn) options[label]=fn;return {SetImage=function() end} end,Open=function(_,x,y) position={x,y} end,Remove=function(self) self.valid=false end} end
 gui={IsGameUIVisible=function() return false end,IsConsoleVisible=function() return false end};vgui={CursorVisible=function() return false end}
 local sent={};net.WriteUInt=function(v,bits) sent.action=v;eq(bits,2) end;net.WriteEntity=function(v) sent.entity=v end;net.SendToServer=function() sent.done=true end
 ${source(['ixhl2rp/plugins/sleep/cl_sleep.lua'])}
 for n=1,25 do P:HUDPaint() end;near(alpha,255);assert(drawn[#drawn]:find('H / MOUSE4',1,true));eq(drawn[#drawn-1],'Вы спите')
 p.locals.bedRestBlocked=true;p.vars.bedRestSleeping=nil
 for n=1,5 do P:HUDPaint() end;assert(alpha<50);eq(drawn[#drawn-1],'Вы проснулись — выход занят')
 P:EndBedRest(p,true);net.ReadEntity=function() return b end;net.handlers.ixBedRestMenu();eq(position[1],640);eq(position[2],360);options['Лечь спать']();eq(sent.action,2);eq(sent.entity,b);assert(sent.done)
`);
suite('First-person body lies at the mattress transform and resolves its own pose instead of copying a stale standing index',`
 CLIENT=true;SERVER=false;local p=playerFixture();p.pos=Vector(100,200,40);p.vars.bedRestAngle=Angle(0,90,0)
 function p:GetSequence() return 0 end;function p:EyeAngles() return Angle(0,180,0) end
 function p:GetBodyGroups() return {} end;function p:GetMaterials() return {} end;function p:GetSkin() return 0 end
 function p:GetMaterial() return '' end;function p:GetColor() return {r=255,g=255,b=255,a=255} end
 function p:GetNoDraw() return false end;function p:ShouldDrawLocalPlayer() return false end;function p:GetObserverTarget() return NULL end
 function p:GetPoseParameter() return .5 end
 function LocalPlayer() return p end;function GetViewEntity() return p end
 local V=getmetatable(Vector());function V:Length2D() return math.sqrt(self.x*self.x+self.y*self.y) end
 ix.option={Add=function() end,Get=function(_,default) return default end};ix.type={bool=1};vector_up=Vector(0,0,1)
 local model={valid=true,scale=1}
 function ClientsideModel() return model end
 for _,name in ipairs({'SetNoDraw','SetSkin','SetMaterial','SetColor','SetPlaybackRate','FrameAdvance','SetPoseParameter','ManipulateBoneScale','ManipulateBonePosition','ManipulateBoneAngles','SetupBones','DrawModel'}) do model[name]=function() end end
 function model:GetModelScale() return self.scale end;function model:SetModelScale(v) self.scale=v end
 function model:LookupSequence(name) return name=='stances_down02' and 91 or -1 end
 function model:GetSequenceInfo() return {bbmin=Vector(-28,-12,-1),bbmax=Vector(40,17,13)} end
 function model:ResetSequence(v) self.sequence=v end;function model:SetCycle(v) self.cycle=v end
 function model:GetBoneCount() return 0 end;function model:LookupBone() return nil end
 function model:SetRenderOrigin(v) if v then self.renderPosition=v end end
 function model:SetRenderAngles(v) if v then self.renderAngle=v end end
 function EyePos() return p:GetShootPos() end;function EyeAngles() return p:EyeAngles() end
 cam={Start3D=function() end,End3D=function() end};render={}
 for _,name in ipairs({'EnableClipping','PushCustomClipPlane','SetColorModulation','SetBlend','PopCustomClipPlane'}) do render[name]=function() end end
 ${source(['ixhl2rp/plugins/legs.lua'])}
 PLUGIN:PlayerModelChanged(p,p:GetModel());PLUGIN:PostDrawTranslucentRenderables()
 eq(model.sequence,91);eq(model.cycle,0);eq(model.renderAngle.y,90);near(model.renderPosition:Distance(p.pos),0)
`);
// The native animation names above are backed by the installed content, not fixture guesses.
for(const file of ['m_anm.mdl','f_anm.mdl','z_anm.mdl','player/wiltos/anim_extension_prone.mdl']) {
 const b=fs.readFileSync(path.join(__dirname,'../addons/ix_crawl_animation_content/models',file));let found=false;
 for(let i=0;i<b.readInt32LE(188);i++) {const base=b.readInt32LE(192)+i*212,pos=base+b.readInt32LE(base+4);if(b.toString('utf8',pos,b.indexOf(0,pos))==='prone_passive') {
  found=true;const low=[32,36,40].map(o=>b.readFloatLE(base+o)),high=[44,48,52].map(o=>b.readFloatLE(base+o));
  assert(low[0]>=-44&&low[1]>=-23&&low[2]>=-3&&high[0]<=44&&high[1]<=23&&high[2]<=25,file+' exceeds body clearance');
 }} assert(found,file+' missing prone_passive');
}
console.log('PASS real compiled prone_passive presence and body bounds in four shipped animation models');
for(const file of ['male_stance_anims.mdl','female_stance_anims.mdl']) {
 const b=fs.readFileSync(path.join(__dirname,'../addons/ix_crawl_animation_content/models/ix_cellar/cellar',file));const found=new Set();
 for(let i=0;i<b.readInt32LE(188);i++) {const base=b.readInt32LE(192)+i*212,pos=base+b.readInt32LE(base+4),name=b.toString('utf8',pos,b.indexOf(0,pos));
  if(!['stances_down01','stances_down02','stances_down03'].includes(name))continue;
  found.add(name);const low=[32,36,40].map(o=>b.readFloatLE(base+o)),high=[44,48,52].map(o=>b.readFloatLE(base+o));
  assert(low[0]>=-44&&low[1]>=-23&&low[2]>=-3&&high[0]<=44&&high[1]<=23&&high[2]<=25,file+' '+name+' exceeds body clearance');
 }assert.equal(found.size,3,file+' missing lying aliases');
}
console.log('PASS actual Cellar male/female lying aliases and conservative body clearance');
finish();
