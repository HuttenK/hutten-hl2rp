const {native,source,read}=require('./restored-test-runner.cjs');
const {normalize}=require('./glua.cjs');
const geometry=source(['tools/geometry-fixture.lua']);
const setup=geometry+`
 SERVER=false;CLIENT=true
 ix.arc9Helpers={Install=function() end,CanBudget=function() return true end}
 ARC9={TPIK={HelperHasCachedRoots=function() return true end}}
 getmetatable(Vector()).DistToSqr=function(a,b) return (a-b):LengthSqr() end
 settings={};callbacks={};timers={};hooks={};commands={};effectInit=0
 function setting(n,v)
  local s={value=v,GetBool=function(s) return s.value~=0 end,GetInt=function(s) return s.value end,
   SetBool=function(s,b) s.value=b and 1 or 0 end,SetInt=function(s,b) s.value=b end}
  settings[n]=s;return s
 end
 setting('arc9_tpik_helper_bone_force_full_fps',1)
 function CreateClientConVar(n,v) return settings[n] or setting(n,tonumber(v)) end
 GetConVar=function(n) return settings[n] end
 cvars={AddChangeCallback=function(n,f) callbacks[n]=f end,RemoveChangeCallback=function(n) callbacks[n]=nil end}
 concommand={Add=function(n,f) commands[n]=f end,Remove=function(n) commands[n]=nil end}
 hook.Add=function(e,n,f) hooks[e..n]=f end;hook.Remove=function(e,n) hooks[e..n]=nil end
 timer.Create=function(n,_,_,f) timers[n]=f end;timer.Remove=function(n) timers[n]=nil end
 local initial={Init=function() effectInit=effectInit+1 end}
 effectDefinition=initial
 effects={Create=function() return table.Copy(effectDefinition) end,Register=function(t) effectDefinition=t end}
 localPlayer={valid=true,IsPlayer=function() return true end};function LocalPlayer() return localPlayer end
 mainEye=Vector();currentEye=Vector();function EyePos() return currentEye end
 render={GetViewSetup=function() return {origin=mainEye} end}
 function person(x)
  local p={valid=true,pos=Vector(x or 0,0,0),model='sd.mdl',scale=1,action='',net={}}
  function p:IsPlayer() return true end;function p:GetPos() return self.pos end
  function p:GetModel() return self.model end;function p:GetModelScale() return self.scale end
  function p:GetNetVar(n) return self.net[n] end;function p:GetNW2String() return self.action end
  return p
 end
 function weapon(p)
  local w={valid=true,ARC9=true,owner=p,LastTPIKTime=0,TPIKCache={},sequence=1,hold='rpg',reload=false}
  function w:GetOwner() return self.owner end;function w:GetHoldType() return self.hold end
  function w:GetSequenceIndex() return self.sequence end;function w:GetReloading() return self.reload end
  function w:ShouldLOD() return 0 end
  return w
 end
`;
const budget='ixhl2rp/plugins/render_efficiency/cl_budget.lua';
const rate=normalize(read('tools/fixtures/arc9-upstream/tpik-rate-excerpt.lua'));
module.exports=suite=>{
 suite('Distant ARC9 uses native cached solve decision but still runs each draw; near and local preserve full helper fidelity',
 [budget],`
 local p=person(2000);local w=weapon(p);local solve,apply=0,0
 local arc9_tpik_framerate_you={GetInt=function() return 60 end}
 local arc9_tpik_framerate_notyou={GetInt=function() return 20 end}
 local arc9_tpik_helper_bone_force_full_fps=settings.arc9_tpik_helper_bone_force_full_fps
 local TPIKHelperHasCachedRoots=function() return true end
 local function original(self)
  local ply=self:GetOwner()
  ${rate}
  if shouldfulltpik then solve=solve+1;self.LastTPIKTime=CurTime() end
  -- ARC9 reapplies/tweens relative targets outside its shouldfulltpik guard.
  apply=apply+1
 end
 for i=0,99 do clock=10+i*.01;ix.RenderBudget.RunTPIK(w,original) end
 eq(apply,100);assert(solve>=5 and solve<=6,'distant solve count '..solve)
 p.pos=Vector(1000,0,0);solve=0
 for i=0,99 do clock=12+i*.01;ix.RenderBudget.RunTPIK(w,original) end
 assert(solve>=9 and solve<=11,'medium solve count '..solve)
 p.pos=Vector(100,0,0);solve=0
 for i=0,19 do clock=14+i*.01;ix.RenderBudget.RunTPIK(w,original) end
 eq(solve,20)
 w.owner=localPlayer;localPlayer.GetModel=p.GetModel;localPlayer.model='sd.mdl';localPlayer.GetModelScale=p.GetModelScale;localPlayer.scale=1
 localPlayer.GetNetVar=p.GetNetVar;localPlayer.net={};localPlayer.GetNW2String=p.GetNW2String;localPlayer.action='';localPlayer.IsPlayer=p.IsPlayer
 solve=0;for i=0,19 do clock=15+i*.01;ix.RenderBudget.RunTPIK(w,original) end;eq(solve,20)
 `,setup);
 suite('Arm budgets invalidate height/model/owner/weapon sequence/actions/cache and restore timestamp after an error',
 [budget],`
 local p=person(2000);local w=weapon(p);local full=0;local draws=0
 local function original(self) draws=draws+1;if self.LastTPIKTime<CurTime() then full=full+1;self.LastTPIKTime=CurTime() end end
 ix.RenderBudget.RunTPIK(w,original);eq(full,1)
 clock=clock+.01;ix.RenderBudget.RunTPIK(w,original);eq(full,1);eq(draws,2)
 for _,change in ipairs({function() p.scale=.9 end,function() p.model='beta7.mdl' end,
  function() w.sequence=2 end,function() w.hold='passive' end,function() w.reload=true end,
  function() p.action='drag' end,function() p.net.sharedPose='sit' end,function() p.net.forcedSequence='lie' end,function() w.TPIKCache={} end,
  function() w.owner=person(2100) end}) do
  change();local before=full;clock=clock+.001;ix.RenderBudget.RunTPIK(w,original);eq(full,before+1)
 end
 local previous=w.LastTPIKTime;clock=clock+.001
 local ok=pcall(function() ix.RenderBudget.RunTPIK(w,function() error('fixture') end) end)
 eq(ok,false);eq(w.LastTPIKTime,previous)
 local replacement=weapon(w.owner);local before=full;ix.RenderBudget.RunTPIK(replacement,original);eq(full,before+1)
 before=full;currentEye=Vector(2090,0,0);ix.RenderBudget.RunTPIK(w,original);eq(full,before+1)
 `,setup);
 suite('Remote camera viewpoints promote arm updates; muzzle events stay unthrottled at every distance',
 [budget],`
 local p=person(2000);local w=weapon(p);eq(ix.RenderBudget.Interval(p),.2)
 local effect={Remove=function(s) s.removed=true end};local data={GetEntity=function() return w end}
 effectDefinition.Init(effect,data);eq(effectInit,1)
 clock=clock+.01;effectDefinition.Init(effect,data);eq(effectInit,2);eq(effect.removed,nil)
 currentEye=Vector(1990,0,0);hooks.PreDrawOpaqueRenderablesixRenderBudgetViews(false,false)
 currentEye=Vector();eq(ix.RenderBudget.Interval(p),0)
 effectDefinition.Init(effect,data);eq(effectInit,3)
 clock=clock+.4;eq(ix.RenderBudget.Interval(p),.2)
 effectDefinition.Init(effect,data);eq(effectInit,4)
 w.owner=person(2000);clock=clock+.01;effectDefinition.Init(effect,data);eq(effectInit,5)
 w.owner=localPlayer;effectDefinition.Init(effect,data);effectDefinition.Init(effect,data);eq(effectInit,7)
 w.owner=person(20000)
 for i=1,50 do assert(ix.RenderBudget.AllowMuzzle(w));effectDefinition.Init(effect,data) end
 eq(effectInit,57);eq(effect.removed,nil);eq(ix.RenderBudget.stats.muzzleSkipped,0)
 `,setup);
 suite('Client disable/unload restores original helper and muzzle behavior without overwriting an intervening preference',
 [budget],`
 eq(settings.arc9_tpik_helper_bone_force_full_fps:GetBool(),false)
 settings.ix_render_budget:SetBool(false);callbacks.ix_render_budget()
 eq(settings.arc9_tpik_helper_bone_force_full_fps:GetBool(),true);eq(ix.RenderBudget.Interval(person(2000)),0)
 settings.ix_render_budget:SetBool(true);callbacks.ix_render_budget()
 eq(settings.arc9_tpik_helper_bone_force_full_fps:GetBool(),false)
 settings.arc9_tpik_helper_bone_force_full_fps:SetBool(true)
 PLUGIN:OnUnload();eq(settings.arc9_tpik_helper_bone_force_full_fps:GetBool(),true)
 eq(timers.ixRenderBudgetInstall,nil);eq(commands.ix_render_budget_status,nil)
 local w=weapon(person(2000));local d={GetEntity=function() return w end}
 effectDefinition.Init({},d);effectDefinition.Init({},d);eq(effectInit,2)
 eq(ix.RenderBudget.Interval(w.owner),0)
 `,setup);
 suite('Existing helper/height/post-pose pipeline runs on every cached and full arm draw',
 [budget,'ixhl2rp/plugins/arc9_helperbones.lua'],`
 local H=ix.arc9Helpers;local p=person(2000);local w=weapon(p)
 local captures,applies,pre,post,draws=0,0,0,0,0
 H.Capture=function() captures=captures+1;return {} end
 H.Apply=function() applies=applies+1 end
 hook.Run=function(event) if event=='ixARC9PreArmPose' then pre=pre+1 elseif event=='ixARC9PostArmPose' then post=post+1 end end
 w.DoTPIK=function(s) draws=draws+1;s.LastTPIKTime=CurTime();return 'ok' end
 H.Install(w)
 for i=0,19 do clock=10+i*.01;eq(w:DoTPIK(false),'ok') end
 eq(captures,20);eq(applies,20);eq(pre,20);eq(post,20);eq(draws,20)
 `,setup);
 suite('Arm wrapper discovery avoids per-frame player enumeration but installs visible newcomers immediately',
 ['ixhl2rp/plugins/arc9_helperbones.lua'],`
 local H=ix.arc9Helpers;local visits,scans=0,0
 local w={};localPlayer.GetActiveWeapon=function() return w end
 local remote={GetActiveWeapon=function() return w end}
 H.Install=function(target) eq(target,w);visits=visits+1 end
 player.GetAll=function() scans=scans+1;return {remote} end
 for i=0,99 do clock=10+i*.01;hooks.ThinkixARC9ArmHelpers() end
 assert(scans>=9 and scans<=11);eq(visits,100+scans)
 local before=visits;hooks.PrePlayerDrawixARC9ArmHelpers(remote);eq(visits,before+1)
 `,setup);
 suite('Actual ARC9 penetration and ricochet switches stop before material/entity/secondary bullet work',
 ['tools/fixtures/arc9-upstream/sh_penetration.lua'],`
 SWEP:Penetrate(nil,nil,nil,nil);eq(SWEP.Penned,0);eq(SWEP:GetRicochetChance(nil),0)
 `,`SWEP={valid=true,GetOwner=function() error('penetration work must not run') end};GetConVar=function() return {GetBool=function() return false end} end`);
 const loop=read('tools/fixtures/arc9-upstream/sh_loopingsound.lua');
 const indoorSource=normalize(loop.slice(loop.indexOf('SWEP.IndoorTick = 0')));
 const shootSounds=native('tools/fixtures/arc9-upstream/sh_shoot.lua','function SWEP:DoShootSounds()','function SWEP:PrimaryAttack()');
 suite('Actual indoor mode0 uses one trace per quarter-second; mode1 three per tenth; both keep normal and indoor shot sounds',[],`
 local mode=0;local tracesCount=0;local soundmode={GetInt=function() return mode end}
 local p={valid=true,EyePos=function() return Vector() end,EyeAngles=function() return Angle() end}
 local SWEP={ShootSoundIndoor='indoor.wav',GetOwner=function() return p end}
 UnPredictedCurTime=CurTime
 util.TraceLine=function(t) tracesCount=tracesCount+1;return {Fraction=.5,HitSky=false} end
 ${indoorSource}
 local mix=SWEP:GetIndoor();assert(mix>0 and mix<1);eq(tracesCount,1)
 clock=clock+.20;eq(SWEP:GetIndoor(),mix);eq(tracesCount,1)
 clock=clock+.051;SWEP:GetIndoor();eq(tracesCount,2)
 mode=1;clock=20;SWEP:GetIndoor();eq(tracesCount,5)
 clock=20.05;SWEP:GetIndoor();eq(tracesCount,5)
 clock=20.101;SWEP:GetIndoor();eq(tracesCount,8)
 local lsstr,lsslr,ldsstr='ShootSound','LayerSound','DistantShootSound'
 local soundtab1,soundtab2,soundtab3={name='shootsound'},{name='shootlayer'},{name='shootdistant'}
 local soundtab4,soundtab5,soundtab6={name='shootsoundindoor'},{name='shootlayerindoor'},{name='shootdistantindoor'}
 local values={ShootSound='shot.wav',LayerSound='layer.wav',DistantShootSound='distant.wav',ShootSoundIndoor='indoor.wav',
  LayerSoundIndoor='indoor-layer.wav',DistantShootSoundIndoor='indoor-distant.wav',ShootPitchVariation=0,ShootVolume=100,ShootPitch=100}
 local swepGetProcessedValue=function(_,key) return values[key] end
 local swepGetValue=function() return false end
 function SWEP:GetNthShot() return 0 end;function SWEP:GetUBGL() return false end;function SWEP:GetBurstCount() return 0 end
 function SWEP:RandomChoice(v) return v end;function SWEP:StartLoop() end
 ARC9={CHAN_WEAPON=1,CHAN_LAYER=2,CHAN_DISTANT=3,CHAN_INDOOR=4,CHAN_INDOORDISTANT=5};math.Rand=function() return 0 end
 local played={};function SWEP:PlayTranslatedSound(t) played[t.name]=t.sound;assert(t.sound~='' and t.volume>0) end
 ${shootSounds}
 mode=0;clock=21;SWEP:DoShootSounds();eq(played.shootsound,'shot.wav');eq(played.shootsoundindoor,'indoor.wav');eq(played.shootdistant,'distant.wav')
 mode=1;clock=22;played={};SWEP:DoShootSounds();eq(played.shootsound,'shot.wav');eq(played.shootsoundindoor,'indoor.wav')
 `,geometry);
 suite('Indoor sound preset defaults to optimized, allows baseline A/B and rejects non-admin changes',
 ['ixhl2rp/plugins/render_efficiency/sv_arc9_sound.lua'],`
 eq(settings.arc9_indoorsound.value,0)
 commands.ix_arc9_sound_mode(nil,nil,{'baseline'});eq(settings.ix_arc9_indoor_mode.value,1);eq(settings.arc9_indoorsound.value,1)
 commands.ix_arc9_sound_mode({valid=true,IsSuperAdmin=function() return false end},nil,{'optimized'});eq(settings.arc9_indoorsound.value,1)
 commands.ix_arc9_sound_mode(nil,nil,{'optimized'});eq(settings.arc9_indoorsound.value,0)
 PLUGIN:OnUnload();eq(timers.ixARC9IndoorPolicy,nil)
 `,setup+`SERVER=true;CLIENT=false;settings.arc9_indoorsound=setting('arc9_indoorsound',1);CreateConVar=CreateClientConVar`);
};
