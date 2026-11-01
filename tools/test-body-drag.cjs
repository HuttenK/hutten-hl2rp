module.exports=function(suite){
 const fs=require('fs'),path=require('path');
 const read=f=>fs.readFileSync(path.join(__dirname,'..',f),'utf8');
 const {normalize}=require('./glua.cjs');
 const combat=read('ixhl2rp/plugins/!healthsystem/sv_combat.lua');
 const start=combat.indexOf('function PLUGIN:EntityTakeDamage(');
 const damageHandler=normalize(combat.slice(start,combat.indexOf('\nfunction ',start+1)));
 const setup=['sharedposes','pose-gizmo','body-drag'].map(f=>read('tools/fixtures/'+f+'.lua')).join('\n');
 const base=['ixhl2rp/plugins/body_drag/sh_drag.lua','ixhl2rp/plugins/body_drag/sh_weapons.lua'];
 const server=[...base,'ixhl2rp/plugins/body_drag/sv_drag.lua'];
 suite('Body pull follows actual travel, reverses smoothly and stays on the left at rest and sideways',base,`
 local D=ix.BodyDrag
 near(math.abs(D.TrailYaw(Vector(100,0,0),nil,0,.1)),180)
 near(D.TrailYaw(Vector(-100,0,0),nil,180,.1),0)
 local yaw=180;for i=1,10 do local before=yaw;yaw=D.TrailYaw(Vector(-100,0,0),yaw,0,.1);assert(math.abs(math.AngleDifference(yaw,before))<=22.0001) end
 near(yaw,0);near(D.TrailYaw(Vector(),yaw,90,.1),yaw)
 local rear=D.GripTarget(carrier,180);local front=D.GripTarget(carrier,0)
 assert(rear.x<0 and front.x>0 and rear.y>0 and front.y>0)
 for _,a in ipairs({0,90,180,270}) do local point,shoulder=D.GripTarget(carrier,a);assert((point-shoulder):Dot(carrier:EyeAngles():Right())<=-3);assert(point:Distance(shoulder)<40) end
 `,setup);
 suite('Drag start validates target, line of sight, reach, availability and reload before taking ownership',server,`
 local D=ix.BodyDrag;local weapon=dragWeapon(carrier)
 eq(D.Start(carrier,carrier),false);eq(D.Start(carrier,dragEntity('prop_physics')),false)
 carrier.restricted=true;eq(D.Start(carrier,body),false);carrier.restricted=false
 weapon.reloading=true;eq(D.Start(carrier,body),false);weapon.reloading=false
 trace.Entity=dragEntity('prop_physics');eq(D.Start(carrier,body),false);trace.Entity=body
 trace.HitPos=Vector(1000,0,0);eq(D.Start(carrier,body),false);trace.HitPos=body.ph.pos
 body.ixHeldOwner=patient;eq(D.Start(carrier,body),false);body.ixHeldOwner=nil
 assert(D.Start(carrier,body));eq(D.Body(carrier),body);eq(body.ixBodyDragger,carrier)
 eq(D.Start(dragPlayer(),body),false);eq(fire('ShouldCollide',body,carrier),false)
 eq(fire('ShouldCollide',body,patient),nil);eq(fire('PhysgunPickup',patient,body),false)
 D.Stop(carrier);eq(D.Body(carrier),nil);eq(body.custom,false);eq(body.ixBodyDragger,nil)
 `,setup);
 suite('Physical drag pulls one bone, clamps wall targets, releases stuck bodies and never teleports physics',server,`
 local D=ix.BodyDrag;assert(D.Start(carrier,body));local state=D.states[carrier]
 carrier.velocity=Vector(80,0,0);D.Step(carrier,state,.015);eq(body.ph.calls,1)
 eq(body.ph.last.teleportdistance,0);eq(body.ph.last.maxangular,0)
 -- The controller needs headroom above walking pace, but remains bounded.
 assert(body.ph.last.maxspeed>=1000 and body.ph.last.maxspeed<=2000)
 assert(body.ph.last.maxspeeddamp>=body.ph.last.maxspeed)
 assert(body.ph.last.secondstoarrive>0 and body.ph.last.secondstoarrive<=.06)
 collision={Hit=true,HitPos=Vector(5,10,35),HitNormal=Vector(0,0,1)}
 D.Step(carrier,state,.015);vectorNear(body.ph.last.pos,Vector(5,10,39))
 obstruction={Hit=true};D.Step(carrier,state,.015);assert(D.Body(carrier))
 clock=clock+.7;D.Step(carrier,state,.015);eq(D.Body(carrier),nil)
 `,setup);
 suite('Accepted drag interrupts the falling controller while rejected grabs leave it running',server,`
 local D=ix.BodyDrag;local animation=dragEntity('hari_ragdoll_animation')
 body.AnimModule=animation;animation.Ragdoll=body
 animation:CallOnRemove('clear',function() body.AnimModule=nil end)
 trace.HitPos=Vector(1000,0,0);eq(D.Start(carrier,body),false)
 eq(body.BD_AnimationInterrupted,nil);eq(body.AnimModule,animation);assert(IsValid(animation))
 trace.HitPos=body.ph.pos;assert(D.Start(carrier,body))
 eq(IsValid(animation),false);eq(body.AnimModule,nil);eq(body.BD_AnimationInterrupted,true)
 D.Stop(carrier);eq(body.BD_AnimationInterrupted,true)
 -- A normal body without the animation addon still works.
 body=dragBody(patient);trace={Entity=body,HitPos=body.ph.pos,PhysicsBone=0}
 assert(D.Start(carrier,body));D.Stop(carrier)
 `,setup);
 suite('Drag runs once per simulation tick when Think is sparse, and removes the legacy hook on reload',server,`
 local D=ix.BodyDrag;assert(D.Start(carrier,body))
 eq(hooks.Think.ixBodyDragPhysics,nil);assert(hooks.Tick.ixBodyDragPhysics)
 for _,rate in ipairs({33,66,100}) do
  engine.TickInterval=function() return 1/rate end
  local before=body.ph.calls
  for tick=1,rate do
   clock=clock+1/rate;fire('Tick')
   if tick%5==0 then fire('Think') end
   near(body.ph.last.delta,1/rate)
  end
  eq(body.ph.calls-before,rate)
 end
 D.Stop(carrier);local before=body.ph.calls;fire('Tick');eq(body.ph.calls,before)
 `,setup+`\nhook.Add('Think','ixBodyDragPhysics',function() error('stale physics hook') end)`);
 suite('Death, recovery, character swap, vehicle entry, removal and teleport all release a drag',server,`
 local D=ix.BodyDrag
 local function check(change)
  carrier=dragPlayer();patient=dragPlayer();body=dragBody(patient);trace={Entity=body,HitPos=body.ph.pos,PhysicsBone=0}
  assert(D.Start(carrier,body));local state=D.states[carrier];change();D.Step(carrier,state,.02);eq(D.Body(carrier),nil)
 end
 check(function() patient.dead=true end)
 check(function() patient.ixRagdoll=nil end)
 check(function() carrier.character={} end)
 check(function() carrier.pos=Vector(500,0,0) end)
 check(function() carrier.vehicle=true end)
 check(function() body:Remove() end)
 check(function() fire('PlayerDeath',patient) end)
 check(function() fire('PlayerLoadedCharacter',carrier) end)
 `,setup);
 suite('Dragging preserves shooting, aiming and held-R raising while blocking direct and switched-weapon reloads',server,`
 local D=ix.BodyDrag;local w=dragWeapon(carrier);local original=w.Reload
 assert(D.Start(carrier,body));eq(w:Reload(),false);eq(w:CanReload(),false);eq(w.reloads,nil)
 local command={buttons=IN_ATTACK+IN_ATTACK2+IN_RELOAD}
 function command:KeyDown(k) return (self.buttons & k)~=0 end
 function command:RemoveKey(k) self.buttons=self.buttons & ~k end
 fire('StartCommand',carrier,command);eq(command.buttons,IN_ATTACK+IN_ATTACK2)
 clock=clock+.6;command.buttons=IN_RELOAD;fire('StartCommand',carrier,command);eq(carrier.raised,1)
 local second=dragWeapon(carrier);fire('WeaponEquip',second,carrier);eq(second:Reload(),false)
 D.Stop(carrier);eq(w.Reload,original);eq(w:Reload(),'reloaded');eq(second:Reload(),'reloaded')
 `,setup);
 suite('Native empty-magazine auto-reload is held and owned timers restored without overwriting weapon changes',server,`
 local D=ix.BodyDrag;local w=dragWeapon(carrier,false);w.clip=0;assert(D.Start(carrier,body));near(w.nextFire,clock+.2)
 D.Stop(carrier);near(w.nextFire,0)
 assert(D.Start(carrier,body));w.nextFire=clock+10;D.Stop(carrier);near(w.nextFire,clock+10)
 `,setup);
 suite('Client-stripped reload still raises once per hold on the server, expires safely, and leaves normal controls intact',server,`
 local D=ix.BodyDrag;local weapon=dragWeapon(carrier);assert(D.Start(carrier,body))
 local pending={};local message
 net.Start=function(name) eq(name,'ixBodyDragRaise') end
 net.WriteBool=function(value) message=value end
 net.SendToServer=function() pending[#pending+1]=message end
 local command={buttons=0}
 function command:KeyDown(k) return (self.buttons & k)~=0 end
 function command:RemoveKey(k) self.buttons=self.buttons & ~k end
 local function step(buttons,delta,drop)
  clock=clock+(delta or 0);command.buttons=buttons
  SERVER=false;CLIENT=true;fire('StartCommand',carrier,command)
  local wireButtons=command.buttons
  SERVER=true;CLIENT=false
  for _,held in ipairs(pending) do
   if not drop then release=held;net.handlers.ixBodyDragRaise(1,carrier) end
  end
  pending={};fire('StartCommand',carrier,command)
  return wireButtons
 end
 eq(step(IN_RELOAD+IN_ATTACK+IN_ATTACK2),IN_ATTACK+IN_ATTACK2)
 eq(carrier.raised,nil);eq(weapon:Reload(),false)
 step(IN_RELOAD,.26);step(IN_RELOAD,.26);eq(carrier.raised,1)
 for i=1,20 do step(IN_RELOAD,.26) end;eq(carrier.raised,1)
 step(0,.01);step(IN_RELOAD,.01);step(0,.1);step(0,1);eq(carrier.raised,1)
 step(IN_RELOAD);step(IN_RELOAD,.26);step(IN_RELOAD,.26);eq(carrier.raised,2)
 step(0,.01,true);step(0,1.1);eq(carrier.ixDragRaiseStart,nil)
 step(IN_RELOAD);step(IN_RELOAD,.26);step(IN_RELOAD,.26);eq(carrier.raised,3)
 D.Stop(carrier);eq(carrier.ixDragReloadUntil,nil)
 eq(step(IN_RELOAD+IN_ATTACK,.01),IN_RELOAD+IN_ATTACK);eq(weapon:Reload(),'reloaded')
 release=true;net.handlers.ixBodyDragRaise(1,carrier);eq(carrier.ixDragReloadUntil,nil)
 `,setup);
 suite('Release menu and use interception target only the carried body, leaving doors, props and other players usable',
 [...server,'ixhl2rp/plugins/body_drag/cl_drag.lua'],`
 local D=ix.BodyDrag;local menus=0;local sends=0
 LocalPlayer=function() return carrier end
 ix.SimpleMenu=function()
  menus=menus+1;local menu={valid=true,options={}}
  function menu:AddOption(text,callback) self.options[#self.options+1]={text=text,callback=callback} end
  function menu:Open() end;function menu:Center() end;function menu:Remove() self.valid=false end
  return menu
 end
 net.Start=function() end;net.WriteBool=function(v) eq(v,true) end
 net.SendToServer=function() sends=sends+1 end
 eq(D.HandleBind(carrier,'+use',true),true);eq(menus,1)
 eq(D.menu.options[1].text,'ВЗЯТЬ ЛЕВОЙ РУКОЙ')
 assert(D.Start(carrier,body));eq(D.HandleBind(carrier,'+use',true),true)
 eq(D.menu.options[1].text,'ОТПУСТИТЬ ПЕРСОНАЖА');eq(menus,2)
 eq(fire('PlayerUse',carrier,body),false)
 for _,target in ipairs({NULL,dragEntity('prop_door_rotating'),dragEntity('ix_item'),dragPlayer(),dragBody(dragPlayer())}) do
  trace.Entity=target;eq(D.HandleBind(carrier,'+use',true),nil);eq(menus,2)
  eq(fire('PlayerUse',carrier,target),nil)
 end
 trace.Entity=body;eq(D.HandleBind(carrier,'+use',false),nil)
 eq(D.HandleBind(carrier,'+attack',true),nil);eq(menus,2)
 D.menu.options[1].callback();eq(sends,1)
 D.Stop(carrier);D.menu.options[1].callback();eq(sends,1)
 `,setup);
 suite('Left-arm IK respects limb lengths for forward, backward, side and unreachable grips',
 [...base,'ixhl2rp/plugins/body_drag/cl_arms.lua'],`
 local D=ix.BodyDrag;local s,e,w=Vector(0,0,50),Vector(0,12,50),Vector(0,24,50)
 for _,t in ipairs({Vector(16,10,40),Vector(-16,10,40),Vector(0,20,40),Vector(0,80,40)}) do
  local a,b=D.SolveArm(s,e,w,t,Vector(0,1,-1));near(a:Distance(s),12);near(b:Distance(a),12)
  assert(b:Distance(s)<=24);if t:Distance(s)<23.88 then vectorNear(b,t) end
 end
 local a,b=D.SolveArm(s,e,w,s,Vector(0,0,1));vectorNear(a,e);vectorNear(b,w)
 `,setup);
 suite('Model arm override changes only left descendants, runs after ARC9 helpers, and restores callbacks on release',
 [...base,'ixhl2rp/plugins/body_drag/cl_arms.lua','ixhl2rp/plugins/arc9_helperbones.lua'],`
 local D=ix.BodyDrag;carrier:SetNW2Entity('ixDraggedBody',body);body:SetNW2Int('ixDragBone',0)
 local bones={[0]=Vector(0,0,50),Vector(0,12,50),Vector(0,24,50),Vector(0,26,50),Vector(0,-20,50)}
 local matrices={};for id,pos in pairs(bones) do matrices[id]=Matrix();matrices[id]:SetTranslation(pos) end
 function carrier:GetModel() return 'testmodel' end
 function carrier:GetBoneCount() return 5 end
 function carrier:LookupBone(n) return ({['ValveBiped.Bip01_L_UpperArm']=0,['ValveBiped.Bip01_L_Forearm']=1,['ValveBiped.Bip01_L_Hand']=2})[n] end
 function carrier:GetBoneParent(n) return ({[0]=-1,0,1,2,-1})[n] end
 function carrier:GetBoneName() return 'bone' end
 function carrier:GetBoneMatrix(n) return matrices[n] end
 function carrier:SetBoneMatrix(n,m) matrices[n]=m end
 function carrier:AddCallback(_,f) self.callback=f;return 1 end
 function carrier:RemoveCallback() self.callback=nil end
 function carrier:InvalidateBoneCache() end
 D.CacheGrip(body);D.WatchArm(carrier,carrier,false);carrier.callback(carrier)
 vectorNear(matrices[4]:GetTranslation(),bones[4]);assert(matrices[2]:GetTranslation():Distance(bones[2])>1)
 near(matrices[1]:GetTranslation():Distance(matrices[0]:GetTranslation()),12)
 near(matrices[2]:GetTranslation():Distance(matrices[1]:GetTranslation()),12)
 local weapon=dragWeapon(carrier);weapon.ARC9=true;weapon.DoTPIK=function()
  for id,pos in pairs(bones) do matrices[id]=Matrix();matrices[id]:SetTranslation(pos) end
  carrier.callback(carrier);vectorNear(matrices[2]:GetTranslation(),bones[2]);return 42
 end
 local original=weapon.DoTPIK;D.WatchARC9(weapon);eq(weapon:DoTPIK(),42)
 assert(matrices[2]:GetTranslation():Distance(bones[2])>1);vectorNear(matrices[4]:GetTranslation(),bones[4])
 local installed=weapon.DoTPIK
 carrier:SetNW2Entity('ixDraggedBody',NULL);D.CleanupArms(false);eq(weapon.DoTPIK,installed);eq(carrier.callback,nil)
 `,setup+`\nSERVER=false;CLIENT=true;CreateClientConVar=function() return {GetBool=function() return true end} end`);
 suite('All damage types are blocked on the critical player and ragdoll before the health pipeline',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sv_downed.lua'],`
 local damage={};function damage:SetDamage(v) self.amount=v end;function damage:SetDamageForce(v) self.force=v end
 patient.vars.crit=true
 for _,target in ipairs({patient,body}) do for _,kind in ipairs({'bullet','club','slash','blast','fire','fall','poison'}) do
  damage.amount=10000;damage.kind=kind;eq(PLUGIN:EntityTakeDamage(target,damage),true);eq(damage.amount,0);eq(damage.force,vector_origin)
 end end
 eq(PLUGIN:PlayerShouldTakeDamage(patient),false);eq(PLUGIN:CanPlayerSuicide(patient),false)
 -- Execute the real health handler, not just the additional plugin hook.
 ${damageHandler}
 damage.amount=10000;eq(PLUGIN:EntityTakeDamage(body,damage),true);eq(damage.amount,0)
 patient.vars.crit=false;eq(ix.Downed.BlockDamage(patient,damage),false);eq(ix.Downed.BlockDamage(body,damage),false)
 `,setup+'\nix.Downed={}');
 suite('Real timed rob and finish actions still execute, cancel on rescue and clear their ownership',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sv_downed.lua','ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua'],`
 for _,rob in ipairs({true,false}) do
  patient.dead=false;patient.vars.crit=true;patient.ixDownedEnding=nil;patient.kills=0
  carrier.ixCritUsing=patient;carrier.ixCritIsSlay=rob;patient.ixCritUsedBy=carrier
  net.handlers['crit.apply'](0,carrier);near(duration,rob and 10 or 30)
  patient.vars.crit=nil;step();eq(patient.kills,0);eq(removed,true);patient.vars.crit=true
  carrier.ixCritUsing=patient;carrier.ixCritIsSlay=rob;patient.ixCritUsedBy=carrier
  net.handlers['crit.apply'](0,carrier)
  while remaining>0 do remaining=remaining-1;step() end
  eq(patient.kills,1);eq(carrier.ixCritUsing,nil);eq(patient.ixCritUsedBy,nil)
  step();eq(patient.kills,1)
 end
 `,setup+`
 ix.Downed={};ix.log.Add=function() end;ix.BodyDrag.DropPatient=function(p) p.dropped=true end
 function patient:InCriticalState() return self.vars.crit==true end
 function patient:SetAction() end;function patient:Kill() self.dead=true;self.kills=(self.kills or 0)+1 end
 function patient.character:GetLevel() return 10 end
 function carrier:GetEyeTraceNoCursor() return {Entity=body} end
 function carrier:SetAction() end;function carrier:RewardXP() end
 function carrier:UniqueID() return 'carrier' end
 timer.Create=function(_,interval,reps,fn) duration=interval*reps;remaining=reps;step=fn;removed=false end
 timer.RepsLeft=function() return remaining end;timer.Remove=function() removed=true end
 net.ReadBool=function() return true end
 `);
 const dummySetup=setup+`
 ix.type={number=4,optional=64};bit={bor=function(a,b) return a|b end}
 commands={};ix.command={Add=function(n,v) commands[n]=v end}
 game={SinglePlayer=function() return single end,MaxPlayers=function() return capacity or 4 end}
 function carrier:GetEyeTraceNoCursor() return {HitPos=Vector(10,0,0),HitNormal=Vector(0,0,1),Entity=aimed} end
 function carrier:GetModel() return 'models/sd/test.mdl' end;function carrier:GetSkin() return 2 end
 function carrier:GetBodyGroups() return {{id=1}} end;function carrier:GetBodygroup() return 3 end
 function carrier:IsBot() return false end
 bot=dragPlayer();function bot:IsBot() return true end
 function bot.character:SetName(v) self.name=v end;function bot.character:SetModel(v) self.model=v end
 function bot:SetModel(v) self.model=v end;function bot:SetSkin(v) self.skin=v end
 function bot:SetModelScale(v) self.scale=v end;function bot:SetBodygroup(k,v) self.group=v end
 function bot:SetPos(v) self.pos=v end;function bot:SetEyeAngles(v) self.ang=v end;function bot:SetMoveType(v) self.move=v end
 function bot:Kick() self.kicked=true end;function bot:SetAction() end
 function bot:GetMaxHealth() return 100 end;function bot:SetHealth(v) self.hp=v end
 function bot:SetCriticalState(v) self.vars.crit=v end;function bot:Spawn() self.dead=false end
 function bot:SetRagdolled(enabled,time) eq(enabled,true);eq(time,nil);self.fell=true end
 function bot.character:Health() return {Reset=function() bot.healed=true end} end
 player.CreateNextBot=function() created=(created or 0)+1;return bot end
 ix.BodyDrag.DropPatient=function(p) p.dropped=true end
 allPlayers={carrier,bot}
 `;
 const dummyHeightSetup=dummySetup+`
 concommand={Add=function() end}
 bot.character.genetic={height=180,cachedSave={180},cachedDesc='old'}
 function bot.character.genetic:Sync() self.syncs=(self.syncs or 0)+1 end
 function bot.character:Genetic() return self.genetic end
 function bot:GetModel() return self.model or 'models/sd/test.mdl' end
 function bot:GetModelScale() return self.scale or 1 end
 function bot:LookupBone() return 1 end
 function bot:SetIK(v) self.ik=v end
 function bot:SetHull(a,b) self.hull=b end
 function bot:SetHullDuck(a,b) self.duckHull=b end
 function bot:SetViewOffset(v) self.view=v end
 function bot:SetViewOffsetDucked(v) self.duckView=v end
 function bot:GetNW2Float(k,d) return self.nw[k] or d end
 function bot:SetNW2Float(k,v) self.nw[k]=v end
 `;
 suite('Existing dummy plugin registers create/add, revive and healing commands on both realms',
 ['ixhl2rp/plugins/testdummy/sh_plugin.lua'],`
 eq(commands.DummyCreate.alias,'DummyAdd');assert(commands.DummyRevive and commands.DummyHeal and commands.DummyFallover)
 for _,command in pairs(commands) do eq(command.adminOnly,true) end
 eq(PLUGIN.CreateDummy,nil)
 `,dummySetup+'\nSERVER=false;CLIENT=true');
 suite('Existing dummy creation uses one exact bot, mirrors model and revive releases/heals only dummies',
 ['ixhl2rp/plugins/testdummy/sh_plugin.lua'],`
 single=true;assert(PLUGIN:CreateDummy(carrier));eq(created,nil);single=false
 capacity=2;assert(PLUGIN:CreateDummy(carrier));eq(created,nil);capacity=4
 commands.DummyCreate.OnRun(nil,carrier);eq(created,1);eq(bot.ixIsDummy,true);eq(bot.model,carrier:GetModel());eq(bot.skin,2);eq(bot.group,3)
 commands.DummyFallover.OnRun(nil,carrier);eq(bot.fell,true)
 aimed=carrier;eq(#PLUGIN:GetDummies(carrier),1)
 bot.vars.crit=true;bot.vars.knocked=true;bot.dead=true
 commands.DummyRevive.OnRun(nil,carrier);eq(bot.dead,false);eq(bot.hp,100);eq(bot.vars.crit,false);eq(bot.vars.knocked,false);eq(bot.dropped,true);eq(bot.healed,true)
 eq(carrier.dropped,nil);commands.DummyRemove.OnRun(nil,carrier);eq(bot.kicked,true)
 `,dummySetup);
 suite('Dummies cycle distinct saved heights, accept exact height and keep their dimensions after revival',
 ['ixhl2rp/plugins/character_height/sh_height.lua','ixhl2rp/plugins/testdummy/sh_plugin.lua'],`
 local function create(value,expected)
  commands.DummyCreate.OnRun(nil,carrier,value)
  eq(bot.character:Genetic().height,expected);near(bot.scale,expected/180);near(bot.hull.z,72*expected/180)
  eq(bot.character.genetic.cachedSave,nil);eq(bot.character.genetic.cachedDesc,nil)
  assert(bot.character.name:find(tostring(expected),1,true));assert(carrier.notice:find(tostring(expected),1,true))
 end
 create(nil,155);create(nil,180);create(170,170);create(nil,190);create(nil,155)
 PLUGIN:ResetDummy(bot);fire('PostPlayerLoadout',bot);near(bot.scale,155/180);near(bot.view.z,64*155/180)
 eq(bot.character.genetic.syncs,5);eq(bot.skin,2);eq(bot.group,3)
 `,dummyHeightSetup);
 suite('Pending dummy spawns reserve different heights and each admin has an independent comparison cycle',
 ['ixhl2rp/plugins/character_height/sh_height.lua','ixhl2rp/plugins/testdummy/sh_plugin.lua'],`
 local pending,bots={},{};timer.Simple=function(_,fn) pending[#pending+1]=fn end
 player.CreateNextBot=function() local b=table.Copy(bot);bots[#bots+1]=b;return b end
 PLUGIN:CreateDummy(carrier);PLUGIN:CreateDummy(carrier)
 local other=table.Copy(carrier);other.ixDummyHeightIndex=nil;PLUGIN:CreateDummy(other)
 -- Complete in reverse order: readiness cannot change the reserved height.
 for i=#pending,1,-1 do pending[i]() end
 eq(bots[1].character.genetic.height,155);eq(bots[2].character.genetic.height,180);eq(bots[3].character.genetic.height,155)
 near(bots[1]:GetModelScale(),155/180);eq(bots[2]:GetModelScale(),1)
 `,dummyHeightSetup);
 suite('Invalid heights and unavailable bot slots neither spawn dummies nor advance the height cycle',
 ['ixhl2rp/plugins/testdummy/sh_plugin.lua'],`
 for _,bad in ipairs({154,191,170.5,0/0,math.huge,-math.huge,'bad'}) do assert(PLUGIN:CreateDummy(carrier,bad)) end
 eq(created,nil);eq(carrier.ixDummyHeightIndex,nil)
 capacity=2;assert(PLUGIN:CreateDummy(carrier));eq(carrier.ixDummyHeightIndex,nil)
 capacity=4;player.CreateNextBot=function() return NULL end
 assert(PLUGIN:CreateDummy(carrier));eq(carrier.ixDummyHeightIndex,nil)
 `,dummySetup);
};
