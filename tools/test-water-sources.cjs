const {run,source,base,finish}=require('./restored-test-runner.cjs');
const setup=source(base)+`
 ix.util={Include=function() end};ix.command={Add=function() end}; ix.Reagents={IsRefillable=function(_,i) return not i.closed end}
 net.WriteEntity=function() end;net.ReadEntity=function() return net.entity end
 net.ReadUInt=function(bits) return bits==2 and net.code or net.item end
 FACTION_VORTIGAUNT=999; IN_USE=32
 local original=admin
 function user()
  local p=original();p.items={};p.trace={}
  function p:GetInventory() return {GetItems=function() return self.items end} end
  function p:GetNetVar(k,d) if self[k]~=nil then return self[k] end;return d end
  function p:SetAction(text) hook.Run('PlayerActionChanged',self,text);self.action=text end
  function p:GetShootPos() return self.pos end
  function p:Team() return 1 end
  function p.character:UpdateNeeds(v) self.thirst=(self.thirst or 0)+v end
  function p.character:GetRadLevel() return self.rad or 0 end
  function p.character:SetRadLevel(v) self.rad=v end
  return p
 end
 function sink()
  local e=entity(900,'',Vector(40,0,0));function e:GetClass() return self.class or 'ix_sink_trigger' end
  function e:OBBMins() return Vector(-20,-20,-20) end;function e:OBBMaxs() return Vector(20,20,20) end
  function e:NearestPoint() return self.pos end;return e
 end
 function container(p,id,kind,volume)
  local i={id=id,uniqueID='empty_can',isReagentHolder=true,owner=p,reagents={volume=volume or 0,max_volume=330,reagents={}}}
  function i:GetOwner() return self.owner end;function i:GetName() return 'Container '..self.id end
  if kind then i.reagents.reagents={{uniqueID=kind,volume=volume or 10}} end
  function i.reagents:AddReagent(kind,amount) self.added=kind;self.volume=self.volume+amount end
  function i.reagents:UpdateTotal() end
  p.items[#p.items+1]=i;return i
 end
 function otherSession(p,mode)
  local s={character=p:GetCharacter(),item={inUse=p},entity=sink()}
  if mode=='medical' then p.ixMedicalSession=s;p.bUsingMedical=true
  else
   s.character=p:GetCharacter():GetID();s.repair={stage=2,round=3};s.fusebox=mode=='fusebox'
   local f=ix.plugin.list.facility_utilities;f.work=f.work or {};f.work[p]=s
  end
  return s
 end
 function unchanged(p,mode,s)
  if mode=='medical' then eq(p.ixMedicalSession,s);eq(p.bUsingMedical,true);eq(s.item.inUse,p)
  else eq(ix.plugin.list.facility_utilities.work[p],s);eq(s.repair.stage,2);eq(s.repair.round,3) end
 end
 chat={};ix.chat.Send=function(p,kind,text) chat[#chat+1]={p,kind,text} end
 util.TraceLine=function() return {Hit=wall==true} end
`+source(['ixhl2rp/plugins/water_sources/sh_plugin.lua','ixhl2rp/plugins/water_sources/sh_water.lua','ixhl2rp/plugins/water_sources/sv_water.lua'])+`
 local W=ix.water
 hook.Add('PlayerActionChanged','water',function(p) PLUGIN:PlayerActionChanged(p) end)
 function start(p,e,kind,id) W.Open(p,e);return W.Begin(p,e,kind,id or 0) end
`;
function suite(n,t){run(n,setup+t)}
suite('Explicit clean-water drink restores thirst without radiation or filling owned containers',`
 local p,e=user(),sink();local i=container(p,1)
 assert(start(p,e,1));clock=clock+2;W.Tick()
 eq(p.character.thirst,20);eq(p.character.rad,nil);eq(i.reagents.volume,0);eq(#chat,1)
 eq(W.actions[p],nil)
`);
suite('Selected container is filled in place, never another and never duplicated',`
 local p,e=user(),sink();local a,b=container(p,1),container(p,2)
 assert(start(p,e,2,2));clock=clock+2;W.Tick()
 eq(a.reagents.volume,0);eq(b.reagents.volume,330);eq(b.reagents.added,'water');eq(#p.items,2)
`);
suite('Medicine, closed and full containers excluded; normal and legacy water can top up',`
 local p=user();local a=container(p,1,'medicine',20);local b=container(p,2,'water',20)
 local c=container(p,3);c.closed=true;local d=container(p,4,nil,330);local e=container(p,5,'dirty_water',20)
 local list=W.Containers(p);eq(#list,2);eq(list[1],b);eq(list[2],e)
 e.reagents.reagents={{uniqueID='dirty_water',volume=10},{uniqueID='water',volume=10}};eq(W.Eligible(e),true)
 e.reagents.reagents[3]={uniqueID='medicine',volume=1};eq(W.Eligible(e),false)
`);
suite('Only direct toilet drinking causes radiation; known toilet props classify correctly and cannot wash',`
 local p,e=user(),sink();e.class='ix_toilet_trigger';assert(start(p,e,1));clock=clock+2;W.Tick();eq(p.character.thirst,20);assert(p.character.rad==50 or p.character.rad==100)
 e.class='prop_physics';e.model='models/props_se/propper/toilet05.mdl';eq(W.Source(e),'toilet')
 e.model='models/props_c17/furnituretoilet001a.mdl';eq(W.Source(e),'toilet')
 clock=clock+1;eq(start(p,e,3),false)
`);
suite('Toilet collection stays clean and direct Vortigaunt drinking preserves existing immunity',`
 local p,e=user(),sink();e.class='ix_toilet_trigger';local item=container(p,1)
 assert(start(p,e,2,1));clock=clock+2;W.Tick();eq(item.reagents.added,'water');eq(p.character.rad,nil)
 function p:Team() return FACTION_VORTIGAUNT end
 clock=clock+1;assert(start(p,e,1));clock=clock+2;W.Tick();eq(p.character.rad,nil);eq(p.character.thirst,20)
`);
suite('Changing a source type after warning/menu or during use cancels without hidden radiation or reward',`
 local p,e=user(),sink();e.class='prop_physics';e.model='models/custom/basin.mdl';W.ApplyModels({[e.model]='sink'})
 W.Open(p,e);W.ApplyModels({[e.model]='toilet'});eq(W.Begin(p,e,1,0),false)
 clock=clock+1;W.ApplyModels({[e.model]='sink'});assert(start(p,e,1));W.ApplyModels({[e.model]='toilet'});clock=clock+2;W.Tick()
 eq(p.character.thirst,nil);eq(p.character.rad,nil);eq(W.actions[p],nil)
`);
suite('Clean and saved legacy containers receive clean top-up without replacing their existing liquid',`
 for _,kind in ipairs({'water','dirty_water'}) do
  local p,e=user(),sink();local i=container(p,1,kind,110);assert(start(p,e,2,1));clock=clock+2;W.Tick()
  eq(i.reagents.added,'water');eq(i.reagents.volume,330);eq(i.reagents.reagents[1].uniqueID,kind)
 end
`);
suite('Transfer and content changes while filling cannot mutate another owner item',`
 for _,mode in ipairs({'owner','contents','remove'}) do
  local p,e=user(),sink();local i=container(p,9);assert(start(p,e,2,9))
  if mode=='owner' then i.owner=user() elseif mode=='contents' then i.reagents.reagents={{uniqueID='medicine',volume=3}} else p.items={} end
  clock=clock+2;W.Tick();eq(i.reagents.volume,0)
 end
`);
suite('Movement, wall, character change and replacement action cancel without reward',`
 for _,mode in ipairs({'move','wall','character','action'}) do
  wall=false;local p,e=user(),sink();assert(start(p,e,1))
  if mode=='move' then p.pos=Vector(1000,0,0) elseif mode=='wall' then wall=true elseif mode=='character' then p.character={}
  else p:SetAction('other') end
  clock=clock+3;W.Tick();eq(p.character.thirst,nil);eq(W.actions[p],nil)
 end
`);
suite('Unsolicited, replayed, expired, distant and restricted actions fail',`
 local p,e=user(),sink();eq(W.Begin(p,e,1,0),false)
 W.Open(p,e);clock=clock+21;eq(W.Begin(p,e,1,0),false)
 W.Open(p,e);p.restricted=true;eq(W.Begin(p,e,1,0),false);p.restricted=false
 clock=clock+1;assert(start(p,e,1));eq(W.Begin(p,e,1,0),false)
`);
suite('Wash produces only a contextual emote; toilet refuses wash; furniture sink recognized',`
 local p,e=user(),sink();assert(start(p,e,3));clock=clock+2;W.Tick();eq(p.character.thirst,nil);eq(#chat,1)
 e.class='ix_toilet_trigger';clock=clock+1;eq(start(p,e,3),false)
 e.class='prop_physics';e.model='models/env/furniture/square_sink/sink_double.mdl';eq(W.Source(e),'sink')
 e.class='ix_item';eq(W.Source(e),nil)
`);
suite('Accepted medical, device repair and fusebox work reject drink, fill and wash starts',`
 for _,mode in ipairs({'medical','repair','fusebox'}) do for code=1,3 do
  local p,e=user(),sink();local item=container(p,1);local s=otherSession(p,mode)
  eq(start(p,e,code,1),false);clock=clock+3;W.Tick()
  eq(p.character.thirst,nil);eq(item.reagents.volume,0);eq(W.actions[p],nil);unchanged(p,mode,s)
 end end
 eq(#chat,0)
`);
suite('Medical, device repair or fusebox session begun later interrupts all water rewards without clearing it',`
 for _,mode in ipairs({'medical','repair','fusebox'}) do for code=1,3 do
  local p,e=user(),sink();local item=container(p,1);assert(start(p,e,code,1))
  local s=otherSession(p,mode);p.action='native subsystem display'
  clock=clock+3;W.Tick()
  eq(W.actions[p],nil);eq(item.reagents.volume,0);eq(p.character.thirst,nil);eq(p.action,'native subsystem display');unchanged(p,mode,s)
 end end
 eq(#chat,0)
`);
suite('Context intention requires the aimed source, preserves local animation anchor and exact selected container',`
 local p,e=user(),sink();local first,chosen=container(p,10),container(p,42)
 function p:GetAimVector() return Vector(1,0,0) end
 p.trace={Entity=e,HitPos=Vector(48,0,0)}
 util.TraceLine=function(q) return q.mask==MASK_SOLID and {Entity=e} or {Hit=false} end
 assert(W.Choose(p,e,2,42,false));eq(W.actions[p].item,chosen);near(W.actions[p].anchor.x,8);eq(W.menus[p],nil)
 clock=clock+2;W.Tick();eq(first.reagents.volume,0);eq(chosen.reagents.volume,330);eq(chosen.reagents.added,'water')
`);
suite('Context intent rejects changed source warning, wrong aim, foreign ID and held/replayed request',`
 local p,e=user(),sink();container(p,1);function p:GetAimVector() return Vector(1,0,0) end
 util.TraceLine=function(q) return q.mask==MASK_SOLID and {Entity=aimed} or {Hit=false} end
 aimed=nil;eq(W.Choose(p,e,1,0,false),false)
 aimed=e;e.class='ix_toilet_trigger';eq(W.Choose(p,e,1,0,false),false);eq(W.actions[p],nil)
 assert(W.Choose(p,e,1,0,true));eq(W.Choose(p,e,1,0,true),false)
 clock=clock+2;W.Tick();assert(p.character.rad==50 or p.character.rad==100)
 clock=clock+1;eq(W.Choose(p,e,2,999,true),false);eq(W.actions[p],nil)
`);
suite('Context receiver rejects oversize payload before reading, shares action rate limit and accepts explicit intent',`
 local p,e=user(),sink();container(p,1);function p:GetAimVector() return Vector(1,0,0) end
 util.TraceLine=function(q) return q.mask==MASK_SOLID and {Entity=e} or {Hit=false} end
 net.entity=e;net.code=2;net.item=1;net.ReadBool=function() return false end
 local receiver=net.handlers.ixWaterChoose
 receiver(65,p);eq(W.actions[p],nil);eq(p.ixWaterNetAt,nil)
 receiver(48,p);assert(W.actions[p]);local a=W.actions[p];receiver(48,p);eq(W.actions[p],a)
`);
finish();
