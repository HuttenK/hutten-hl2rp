const fs = require('node:fs');
const path = require('node:path');
const {normalize} = require('./glua.cjs');
const read = p => fs.readFileSync(path.join(__dirname, '..', p), 'utf8');
const nativeServer = normalize(read('tools/fixtures/arc9-upstream/sh_effects.lua').split('function SWEP:GetQCAMuzzle()')[0]);
const nativeTracer = normalize(read('tools/fixtures/arc9-upstream/arc9_tracer.lua'));
const setup = normalize(read('tools/geometry-fixture.lua')) + `
 unpack=table.unpack
 math.pow=function(a,b) return a^b end
 hooks={};timers={};commands={};effectCalls={};particleCalls=0;traceCalls=0
 hook.Add=function(e,n,f) hooks[e..n]=f end;hook.Remove=function(e,n) hooks[e..n]=nil end
 timer.Simple=function(_,f) f() end;timer.Create=function(n,_,_,f) timers[n]=f end;timer.Remove=function(n) timers[n]=nil end
 concommand={Add=function(n,f) commands[n]=f end,Remove=function(n) commands[n]=nil end}
 ents.FindByClass=function() return {} end
 UnPredictedCurTime=CurTime
 function IsFirstTimePredicted() return firstPrediction~=false end
 singlePlayer=false;game={SinglePlayer=function() return singlePlayer end}
 function Material(name) return {name=name} end
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 color_white=Color(255,255,255)
 function EffectData()
  local data={origin=Vector(),start=Vector(),attachment=0,scale=0,surface=0}
  for field,key in pairs({Entity='entity',Origin='origin',Start='start',Attachment='attachment',Scale='scale',SurfaceProp='surface',Flags='flags'}) do
   data['Get'..field]=function(s) return s[key] end;data['Set'..field]=function(s,v) s[key]=v end
  end
  return data
 end
 function RecipientFilter()
  return {AddPVS=function(s,v) s.position=v end,RemovePlayer=function(s,v) s.excluded=v end}
 end
 util.Effect=function(name,data,override,recipients) effectCalls[#effectCalls+1]={name=name,data=data,filter=recipients} end
 util.QuickTrace=function() traceCalls=traceCalls+1;error('cosmetic adapter must not trace') end
 function owner()
  return {valid=true,IsPlayer=function() return true end,GetShootPos=function() return Vector(12000,6000,64) end,
   GetVelocity=function() return Vector() end,ShouldDrawLocalPlayer=function(s) return s.thirdperson or false end}
 end
 viewer=owner();function LocalPlayer() return viewer end
 eye=Vector();function EyePos() return eye end;function EyeAngles() return Angle() end
 getmetatable(Vector()).DistToSqr=function(a,b) return (a-b):LengthSqr() end
 SWEP={}
 assert(load([==[${nativeServer}]==], '@lua/weapons/arc9_base/sh_effects.lua'))()
 function weapon()
  local w={valid=true,ARC9=true,owner=owner(),DoEffects=SWEP.DoEffects,shot=3,values={MuzzleParticle='rifle',TracerColor=Color(100,200,20),TracerSize=1}}
  function w:GetOwner() return self.owner end
  function w:GetPos() return Vector(12000,6000,20) end
  function w:GetProcessedValue(key) return self.values[key] end
  function w:GetQCAMuzzle() return 3 end
  function w:GetNthShot() return self.shot end
  function w:GetVM() return self end
  function w:GetMuzzleDevice(world) self.world=world;return self.muzzle end
  return w
 end
 settings={arc9_muzzle_others={GetString=function() return '1' end}}
 GetConVar=function(n) return settings[n] end
 effects={};effectDefinitions={}
 effects.Create=function(name) return effectDefinitions[name] and table.Copy(effectDefinitions[name]) end
 effects.Register=function(t,name) effectDefinitions[name]=t end
 render={GetViewSetup=function() return {} end,SetMaterial=function() end}
 drawCalls={}
 local function finite(v) assert(type(v)=='number' and v==v and math.abs(v)<math.huge,'non-finite draw parameter') end
 function render.DrawSprite(pos,w,h,color) finite(w);finite(h);drawCalls[#drawCalls+1]={pos=pos,width=w,color=color} end
 function render.DrawBeam(a,b,w,_,__,color) finite(w);drawCalls[#drawCalls+1]={pos=a,finish=b,width=w,color=color} end
 EFFECT={}
 assert(load([==[${nativeTracer}]==], '@lua/effects/arc9_tracer.lua'))()
 effectDefinitions.arc9_tracer=EFFECT
 nativeEffect=EFFECT
 function newEffect()
  local e=table.Copy(effectDefinitions.arc9_tracer)
  function e:SetRenderBoundsWS(a,b) self.bounds={a,b} end
  return e
 end
 function shotData(w,finish)
  local d=EffectData();d:SetEntity(w);d:SetStart(Vector(1,0,0));d:SetOrigin(finish or Vector(100,0,0));return d
 end
`;
const sv='ixhl2rp/plugins/arc9_shot_effects/sv_effects.lua';
const cl='ixhl2rp/plugins/arc9_shot_effects/cl_effects.lua';
module.exports = suite => {
 suite('Multiplayer muzzle dispatcher uses shooter PVS and excludes the predicted owner once per actual shot', [sv], `
 local w=weapon();w:DoEffects()
 eq(#effectCalls,1);eq(effectCalls[1].filter,nil);near(effectCalls[1].data:GetOrigin().x,0)
 effectCalls={};ix.arc9ShotEffects.Install(w);local dispatch=w.DoEffects
 ix.arc9ShotEffects.Install(w);eq(w.DoEffects,dispatch)
 w:DoEffects();eq(#effectCalls,1)
 local e=effectCalls[1];eq(e.name,'arc9_muzzleeffect');eq(e.data:GetEntity(),w)
 near(e.filter.position.x,12000);near(e.filter.position.y,6000);eq(e.filter.excluded,w.owner)
 eq(e.data:GetOrigin(),e.filter.position);eq(e.data:GetAttachment(),3);eq(e.data:GetSurfaceProp(),1)
 w.shot=4;w:DoEffects();eq(#effectCalls,2);eq(effectCalls[2].data:GetSurfaceProp(),0)
 `,setup);
 suite('Muzzle dispatcher retains no-effect, prediction, SP, NPC, vFire and custom weapon behavior', [sv], `
 local w=weapon();ix.arc9ShotEffects.Install(w)
 w.values.NoMuzzleEffect=true;w:DoEffects();eq(#effectCalls,0)
 w.values.NoMuzzleEffect=false;firstPrediction=false;w:DoEffects();eq(#effectCalls,0)
 firstPrediction=true;singlePlayer=true;w:DoEffects();eq(effectCalls[1].filter.excluded,nil)
 singlePlayer=false;w.owner.IsPlayer=function() return false end;w:DoEffects();eq(effectCalls[2].filter.excluded,nil)
 w.values.MuzzleParticle=nil;w.values.MuzzleEffect='MuzzleFlash';w:DoEffects();eq(effectCalls[3].name,'MuzzleFlash');eq(effectCalls[3].filter,nil)
 vFireInstalled=true;w.values.MuzzleParticle='rifle';w.values.ShootEnt='vfire_ball';w:DoEffects();eq(effectCalls[4].name,'arc9_boc_flamethrower_vfire')
 local custom=weapon();local calls=0;custom.DoEffects=function() calls=calls+1 end
 local fn=custom.DoEffects;ix.arc9ShotEffects.Install(custom);eq(custom.DoEffects,fn);custom:DoEffects();eq(calls,1)
 `,setup);
 suite('Muzzle wrapper unload restores only owned methods and cancels delayed installation', [sv], `
 local w=weapon();local fn=w.DoEffects;ix.arc9ShotEffects.Install(w)
 local other=weapon();ix.arc9ShotEffects.Install(other);local inner=other.DoEffects
 local foreign=function(s) return inner(s) end;other.DoEffects=foreign
 PLUGIN:OnUnload();eq(w.DoEffects,fn);eq(other.DoEffects,foreign)
 other:DoEffects();eq(effectCalls[1].filter,nil)
 ix.arc9ShotEffects.Install(w);eq(w.DoEffects,fn)
 eq(hooks.WeaponEquipixARC9ShotEffects,nil)
 `,setup);
 suite('Hitscan widths are finite and visible on both sides of the native 256-unit discontinuity', [cl], `
 local F=ix.arc9ShotEffects
 for _,distance in ipairs({0,1,64,255.9,256,256.1,1000,20000}) do
  local width=F.TracerWidth(1,distance*distance);assert(width==width and width>=1 and width<math.huge)
 end
 near(F.TracerWidth(1,1000000),math.log(1000000-256*256))
 eq(F.TracerWidth(0,10),0);eq(F.TracerWidth(-1,10),0)
 `,setup);
 suite('Installed ARC9 near-tracer failure reproduces with native Clamp and is fixed by the adapter', [cl], `
 -- Match lua/includes/extensions/math.lua: argument order preserves NaN.
 math.Clamp=function(value,low,high) return math.min(math.max(value,low),high) end
 local w=weapon();local e=newEffect();e:Init(shotData(w));clock=clock+.017
 local ok,err=pcall(nativeEffect.Render,e)
 eq(ok,false);assert(tostring(err):find('non%-finite draw parameter'))
 drawCalls={};e:Render();assert(#drawCalls>=3 and drawCalls[2].width>0)
 `,setup);
 suite('Hitscan effect uses assembled remote muzzle, valid bounds and no extra bullet trace', [cl], `
 local w=weapon();w.muzzle={valid=true,GetAttachment=function(_,att) eq(att,3);return {Pos=Vector(20,0,0)} end}
 local e=newEffect();e:Init(shotData(w));eq(w.world,true);near(e.StartPos.x,20);near(e.EndPos.x,100)
 eq(e.Color,w.values.TracerColor);eq(e.Size,1);near(e.bounds[1].x,20);near(e.bounds[2].x,100)
 clock=clock+.017;e:Render();assert(#drawCalls>=3);assert(drawCalls[2].width>0)
 for _,d in ipairs(drawCalls) do assert(d.pos.x<=100 and (not d.finish or d.finish.x>=20)) end
 eq(traceCalls,0);assert(e:Think())
 clock=clock+1;eq(e:Think(),false)
 `,setup);
 suite('Muzzle origin follows first/third-person and CCTV views, with missing-model fallback', [cl], `
 local F=ix.arc9ShotEffects;local w=weapon();w.owner=viewer
 w.muzzle={valid=true,GetAttachment=function() return {Pos=Vector(9,8,7)} end}
 near(F.TracerOrigin(w,Vector()).x,9);eq(w.world,nil) -- no flags: false or nil selects VM
 viewer.thirdperson=true;F.TracerOrigin(w,Vector());eq(w.world,true)
 viewer.thirdperson=false;ix.CCTV={rendering=true};F.TracerOrigin(w,Vector());eq(w.world,true)
 w.muzzle.valid=false;near(F.TracerOrigin(w,Vector(33,0,0)).x,33)
 `,setup);
 suite('Tracer cancellation, zero length, zero size and invalid weapon never emit malformed geometry', [cl], `
 local w=weapon();local e=newEffect();e:Init(shotData(w,Vector(1,0,0)));eq(e.Dir,nil);eq(e:Think(),false)
 e:Render();eq(#drawCalls,0)
 e:Init(shotData({valid=false}));eq(e:Think(),false)
 w.values.TracerSize=0;e:Init(shotData(w));clock=clock+.01;e:Render();eq(#drawCalls,0)
 w.values.TracerSize=1;e:Init(shotData(w));w.TracerCancelled=true;e:Render();eq(e.Cancelled,true);eq(#drawCalls,0)
 `,setup);
 suite('Tracer adapter unload restores native registration without overwriting another addon', [cl], `
 assert(effectDefinitions.arc9_tracer.Init~=nativeEffect.Init)
 PLUGIN:OnUnload();eq(effectDefinitions.arc9_tracer.Init,nativeEffect.Init)
 eq(timers.ixARC9ShotEffects,nil);eq(commands.ix_arc9_effects_info,nil)
 `,setup);
 suite('Tracer adapter leaves later third-party registration in place', [cl], `
 local other={Init=function() end};effects.Register(other,'arc9_tracer')
 PLUGIN:OnUnload();eq(effectDefinitions.arc9_tracer,other)
 `,setup);
};
