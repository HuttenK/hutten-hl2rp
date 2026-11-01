const {run,source,base,finish}=require('./restored-test-runner.cjs');
const setup=source([...base,'tools/fixtures/water-animations.lua','ixhl2rp/plugins/water_sources/sh_plugin.lua','ixhl2rp/plugins/water_sources/sh_water.lua','ixhl2rp/plugins/water_sources/sv_water.lua'])+`
 local waterPlugin=PLUGIN
 hook.Add('PlayerActionChanged','waterfixture',function(p) waterPlugin:PlayerActionChanged(p) end)
 PLUGIN={}
`+source(['ixhl2rp/plugins/action_animations/sh_plugin.lua','ixhl2rp/plugins/action_animations/sh_ik.lua','ixhl2rp/plugins/action_animations/sv_actions.lua'])+`
 local W,A=ix.water,ix.ActionAnimations
 function accepted(p,e,code,id) W.Open(p,e);return W.Begin(p,e,code,id or 0) end
 function publish(p) local k,t,s=A.Select(p);A.Publish(p,k,t,s);return k end
`;
function test(name,code){run(name,setup+code)}
test('Opening/cancelling water menus and rejected selections never start an animation',`
 local p=waterUser();local e=waterSource(p);waterContainer(p,1)
 W.Open(p,e);eq(A.Select(p),'');eq(p.nw.ixContextAction,nil)
 eq(W.Begin(p,e,2,999),false);eq(A.Select(p),'');eq(p.nw.ixContextAction,nil)
 clock=clock+1;p.restricted=true;eq(accepted(p,e,1),false);eq(A.Select(p),'')
`);
test('Accepted source-local contact comes from the original server trace and follows moved/rotated props',`
 local p=waterUser();local e=waterSource(p);local hit=Vector(-10,3,7)
 W.Open(p,e);waterNear(W.menus[p].anchor,hit)
 p.trace={Entity=entity(999,'unrelated'),HitPos=Vector(9000,0,0)}
 assert(W.Begin(p,e,1,0));eq(p.nw.ixContextAction,'waterdrink');waterNear(p.nw.ixContextActionAnchor,hit)
 e.pos=Vector(40,5,48);e.ang=Angle(0,90,0)
 waterNear(e:LocalToWorld(p.nw.ixContextActionAnchor),e.pos+Vector(-3,-10,7))
 eq(p.nw.ixContextActionStarted,W.actions[p].started);eq(p.nw.ixContextActionFinish,W.actions[p].finish)
`);
test('Sink and toilet drink/fill have distinct accepted actions; handwash remains separate',`
 for _,kind in ipairs({'sink','toilet'}) do for code=1,2 do
  local p=waterUser();local e=waterSource(p,kind);waterContainer(p,1)
  assert(accepted(p,e,code,1));eq(A.Select(p),code==1 and 'waterdrink' or 'waterfill');eq(p.nw.ixContextActionSource,kind)
 end end
 local p=waterUser();local e=waterSource(p);assert(accepted(p,e,3));eq(A.Select(p),'wash')
 p=waterUser();e=waterSource(p,'toilet');eq(accepted(p,e,3),false);eq(A.Select(p),'')
`);
test('Fill publishes only the exact selected owned container model and changes no inventory or liquids before completion',`
 local p=waterUser();local e=waterSource(p);local other=waterContainer(p,1,'models/first.mdl');local selected=waterContainer(p,2,'models/selected.mdl')
 assert(accepted(p,e,2,2));eq(p.nw.ixContextActionProp,'models/selected.mdl');eq(W.actions[p].item,selected)
 eq(#p.items,2);eq(other.reagents.volume,0);eq(selected.reagents.volume,0)
 selected.owner=waterUser();eq(publish(p),'');eq(p.nw.ixContextActionProp,'');eq(#p.items,2)
 clock=clock+2;W.Tick();eq(selected.reagents.volume,0)
`);
test('Lost range, source, line of sight, selected container, character or session end clears animation metadata',`
 for _,mode in ipairs({'range','wall','entity','character','container','cancel','expiry'}) do
  wall=false;local p=waterUser();local e=waterSource(p);local item=waterContainer(p,1);assert(accepted(p,e,2,1))
  if mode=='range' then p.pos=Vector(500,0,0) elseif mode=='wall' then wall=true elseif mode=='entity' then e.valid=false
  elseif mode=='character' then p.character={} elseif mode=='container' then item.closed=true elseif mode=='cancel' then W.Cancel(p) else clock=clock+2 end
  eq(publish(p),'');eq(p.nw.ixContextActionProp,'');eq(p.nw.ixContextActionFinish,0);eq(p.nw.ixContextActionSource,'')
 end
`);
test('Extreme source anchors and malformed model paths never become client visual metadata',`
 local p=waterUser();local e=waterSource(p);p.trace.HitPos=Vector(99999,0,0)
 assert(accepted(p,e,1));eq(W.actions[p].anchor,nil);eq(A.Select(p),'')
 W.Cancel(p);clock=clock+3;p.trace.HitPos=e.pos;local item=waterContainer(p,1,'models/../cfg/server.cfg')
 assert(accepted(p,e,2,1));eq(p.nw.ixContextAction,'waterfill');eq(p:GetNW2String('ixContextActionProp',''),'')
 W.actions[p].anchor=Vector(0/0,0,0);eq(A.Select(p),'')
`);
test('Water starts supersede an earlier bodycam reach; new bodycam requests cannot steal the accepted action',`
 local p=waterUser();local e=waterSource(p);local helmet={};p.ixActionBodycam={character=p.character,helmet=helmet,enabled=true,finish=clock+5}
 ix.bodycams={WornHelmet=function() return helmet end,Attached=function() return true end,Enabled=function() return true end}
 assert(accepted(p,e,1));eq(p.ixActionBodycam,nil);eq(p.nw.ixContextAction,'waterdrink')
 hook.Run('BodycamStateChanged',p,helmet,false);eq(p.ixActionBodycam,nil);eq(p.nw.ixContextAction,'waterdrink')
 W.Cancel(p);eq(p.nw.ixContextAction,'');eq(p.ixContextWaterSession,nil)
`);
const client=setup+`
 CLIENT=true;SERVER=false;RENDERGROUP_OPAQUE=0
 local me=waterUser();LocalPlayer=function() return me end;allPlayers={me}
`+source(['ixhl2rp/plugins/action_animations/cl_actions.lua'])+`
 local p=me;local e=waterSource(p)
 local function mat(v) local m=Matrix();m:SetTranslation(v);return m end
 local matrices={[1]=mat(Vector(0,0,68)),[2]=mat(Vector(0,0,36)),[3]=mat(Vector(0,6,56)),[4]=mat(Vector(0,-6,56)),[5]=mat(Vector(23,0,42))}
 local state={kind='waterdrink',rig={head=1,pelvis=2,arms={L={3,6,7},R={4,8,5}}},target=e,source='sink',anchor=Vector(),weight=1}
 function p:LookupBone(name) return name:find('Hand',1,true) and 5 or nil end
 function p:GetBoneMatrix(i) return matrices[i] end
 local created,removed,drawn=0,0,0
 util.IsValidModel=function() return not invalidModel end
 function ClientsideModel(model)
  created=created+1;local prop={valid=true,model=model}
  function prop:GetModel() return self.model end;function prop:SetNoDraw() end
  function prop:OBBMins() return Vector(-3,-3,0) end;function prop:OBBMaxs() return Vector(3,3,propExtent or 12) end
  function prop:SetPos(v) self.pos=v end;function prop:SetAngles(v) self.ang=v end
  function prop:SetupBones() end;function prop:DrawModel() drawn=drawn+1 end
  function prop:Remove() self.valid=false;removed=removed+1 end
  return prop
 end
`;
run('Drink scoops at the actual source then reaches the mouth; filling holds both hands at source; washing differs',client+`
 p.nw.ixContextActionStarted=clock;p.nw.ixContextActionFinish=clock+2
 local initial=A.Goals(p,state,matrices);waterNear(initial.R,e.pos)
 clock=clock+1.35;local sip=A.Goals(p,state,matrices);assert(sip.R:DistToSqr(matrices[1]:GetTranslation())<65);assert(sip.R:DistToSqr(initial.R)>300)
 state.kind='waterfill';local fill=A.Goals(p,state,matrices);assert(fill.R:DistToSqr(e.pos)<40);assert(fill.L)
 state.kind='wash';local wash=A.Goals(p,state,matrices);assert(wash.R:DistToSqr(fill.R)>.1)
 e.pos=e.pos+Vector(4,6,0);state.kind='waterfill';local moved=A.Goals(p,state,matrices);waterNear(moved.R,fill.R+Vector(4,6,0))
`);
run('Cosmetic fill container uses exact model once, centered on hand; cancellation removes it before another draw',client+`
 local item=waterContainer(p,1);assert(accepted(p,e,2,1));state.kind='waterfill';A.actors[p]=state
 local draw=hooks.PostPlayerDraw.ixContextActionRadioProp;draw(p);draw(p);eq(created,1);eq(drawn,2)
 eq(state.prop:GetModel(),item:GetModel());waterNear(state.prop.pos,Vector(23,0,36));eq(#p.items,1);eq(item.reagents.volume,0)
 W.Cancel(p);draw(p);eq(removed,1);eq(state.prop,nil);eq(drawn,2)
`);
run('Missing and oversized container models fall back without retry storms; replacement and entity cleanup release models',client+`
 local item=waterContainer(p,1);assert(accepted(p,e,2,1));state.kind='waterfill';A.actors[p]=state
 local draw=hooks.PostPlayerDraw.ixContextActionRadioProp;invalidModel=true;draw(p);draw(p);eq(created,0)
 invalidModel=false;item.model='models/large_barrel.mdl';publish(p);propExtent=100;draw(p);draw(p);eq(created,1);eq(removed,1);eq(drawn,0)
 item.model='models/small_bottle.mdl';propExtent=12;publish(p);draw(p);eq(created,2);eq(drawn,1)
 item.model='models/new_bottle.mdl';publish(p);draw(p);eq(created,3);eq(removed,2)
 hooks.EntityRemoved.ixContextActionCleanup(p);eq(A.actors[p],nil);eq(removed,3)
`);
run('Client deadline, target removal/dormancy, death, pose and character model changes clear water actors',client+`
 local think=hooks.Think.ixContextActionActors
 for _,mode in ipairs({'deadline','target','dormant','death','pose','model'}) do
  p.dead=false;p.nw.ixPoseStudioPlaying=false;p.model='models/player/test.mdl';e.valid=true;e.dormant=false
  p.nw.ixContextAction='waterfill';p.nw.ixContextActionTarget=e;p.nw.ixContextActionSource='sink';p.nw.ixContextActionAnchor=Vector();p.nw.ixContextActionFinish=clock+2
  think();assert(A.actors[p]);local before=A.actors[p]
  local prop=ClientsideModel('models/test.mdl');before.prop=prop
  if mode=='deadline' then clock=clock+2 elseif mode=='target' then e.valid=false elseif mode=='dormant' then e.dormant=true
  elseif mode=='death' then p.dead=true elseif mode=='pose' then p.nw.ixPoseStudioPlaying=true else p.model='models/player/new.mdl' end
  think();eq(prop.valid,false);assert(A.actors[p]~=before)
  A.Clear(p)
 end
`);
finish();
