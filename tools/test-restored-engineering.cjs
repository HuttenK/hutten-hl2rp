const {run,source,native,base,finish}=require('./restored-test-runner.cjs');
const files=[...base,...['sh_core','sh_repair','sh_engineering_games','sh_engineering','sv_store','sv_connections','sv_power','sv_doors','sv_comms','sv_jobs','sv_repair','sv_engineering','sv_devices','sv_network'].map(f=>'ixhl2rp/plugins/facility_utilities/'+f+'.lua')];
const env=source(files)+`
 PLUGIN.loaded=true;ix.config.Add=function() end
 local original=admin
 function admin(...)
  local p=original(...);p.skill=5
  function p.character:GetSkillModified() return p.skill end
  return p
 end
 local create=ents.Create
 function ents.Create(...) local e=create(...)
  function e:NearestPoint(p) return self.pos end
  function e:WorldToLocalAngles(a) local _,v=WorldToLocal(Vector(),a,Vector(),self.ang);return v end
  function e:LocalToWorldAngles(a) local _,v=LocalToWorld(Vector(),a,Vector(),self.ang);return v end
  return e
 end
 function engineer(mode)
  ix.config.Get=function(k,d) if k=='facilityRepairGame' then return mode end;return d end
  local p=admin();local d=device('generator');d.fault=true;d.entity.pos=Vector(60,0,0)
  p.trace={Entity=d.entity,HitPos=d.entity.pos-Vector(2,0,0),HitNormal=Vector(-1,0,0)}
  giveItem(p,'tool_screw');local part=giveItem(p,'facility_spares');local remove=part.Remove
  function part:Remove(delete) assert(delete==true,'parts must be deleted from SQL');remove(self) end
  assert(PLUGIN:RepairHere(p,d));return p,d,part
 end
 function inputMove(p,kind,a,b)
  local r=PLUGIN.work[p].repair;clock=clock+.2
  PLUGIN:EngineeringInput(p,r.token,r.round,kind,a or 0,b or 0)
 end
 function aimBolt(p,index)
  local w=PLUGIN.work[p];local points=ix.Facility.EngineeringBolts(w.entity,{count=w.repair.game.count,anchor=w.repair.anchor})
  p.dir=(points[index]-p:GetShootPos()):GetNormalized()
 end
`;
// Config registration is an engine boundary, supplied before loading shared rules.
const setup='ix.config.Add=function() end\n';
function suite(name,test){run(name,setup+env+'\n'+test);}
suite('All three games solve five stages via server; replay and premature completion do not spend parts',`
 for _,kind in ipairs({'probe','pressure','bolts'}) do
  local p,d,part=engineer(kind);local w=PLUGIN.work[p];local token=w.repair.token
  eq(PLUGIN:CompleteWork(p,w),false)
  for stage=1,5 do
   local r=w.repair;eq(r.stage,stage);eq(part.removed,0)
   local public=PLUGIN:EngineeringPublic(r)
   eq(public.broken,nil);eq(public.weights,nil);eq(public.base,nil)
   if kind=='probe' then
    while true do
     local possible={};for i=1,r.game.count do if public.possible[i] then possible[#possible+1]=i end end
     if #possible==1 then inputMove(p,'answer',possible[1]);break end
     inputMove(p,'probe',0,possible[math.floor(#possible/2)]);public=PLUGIN:EngineeringPublic(r)
    end
   elseif kind=='pressure' then
    local g=r.game;local answer
    for code=0,124 do local v=ix.repair.games.pressure.Unpack(code);local value=g.base
     for i=1,3 do value=value+v[i]*g.weights[i] end
     if value>=public.lo and value<=public.hi then answer=code;break end
    end
    assert(answer);inputMove(p,'run',answer)
   else
    local count=r.game.count
    for pair=1,count/2 do for _,index in ipairs({pair,pair+count/2}) do
     aimBolt(p,index);inputMove(p,'hold',index)
     local round=r.round;assert(r.hold)
     PLUGIN:EngineeringInput(p,token,round,'hold',index,0);eq(r.round,round)
     clock=r.hold+r.torqueTime*(r.game.lo[index]+r.game.hi[index])/2
     PLUGIN:EngineeringInput(p,token,round,'release',index,0)
    end end
   end
  end
  eq(PLUGIN.work[p],nil);eq(d.fault,false);eq(part.removed,1)
  PLUGIN:EngineeringInput(p,token,w.repair.round,'answer',1,0);eq(part.removed,1)
 end
`);
suite('Engineering rejects spoofed tokens/rounds/ranges, legacy scoring and duplicate input',`
 local p,d,part=engineer('probe');local r=PLUGIN.work[p].repair;local budget=r.game.budget
 PLUGIN:EngineeringInput(p,r.token+1,r.round,'probe',0,2);eq(r.game.budget,budget)
 PLUGIN:EngineeringInput(p,r.token,r.round+1,'answer',r.game.broken);eq(r.stage,1)
 PLUGIN:RepairInput(p,r.token,r.round,true);eq(r.stage,1)
 inputMove(p,'probe',0,999);eq(r.game.budget,budget)
 local round=r.round;inputMove(p,'probe',0,2);eq(r.game.budget,budget-1)
 clock=clock+.2;PLUGIN:EngineeringInput(p,r.token,round,'probe',0,2);eq(r.game.budget,budget-1)
 net.handlers.ixFacilityEngineeringInput(401,p);eq(r.game.budget,budget-1)
 eq(part.removed,0)
`);
suite('Cancellation covers range, obstruction, tools, access, character, death and time without consumption',`
 local mutations={function(p) p.pos=Vector(1000,0,0) end,function(p) p.items.tool_screw=nil end,
  function(p) p.character.id=p.character.id+1 end,function(p) p.dead=true end,
  function(p) clock=PLUGIN.work[p].repair.expires+1 end,function(p) p.card=nil;p.admin=false end}
 for _,mutate in ipairs(mutations) do
  local p,d,part=engineer('probe');local w=PLUGIN.work[p];mutate(p);PLUGIN:TickJobs()
  eq(PLUGIN.work[p],nil);eq(part.removed,0);assert(d.fault)
 end
 local p,d,part=engineer('probe');local r=PLUGIN.work[p].repair
 local trace=util.TraceLine;util.TraceLine=function() return {Hit=true} end
 PLUGIN:EngineeringInput(p,r.token,r.round,'answer',r.game.broken,0);eq(PLUGIN.work[p],nil);eq(part.removed,0);util.TraceLine=trace
`);
suite('Bolts require visible aimed point on both hold and release; moving aim invalidates hold',`
 local p,d,part=engineer('bolts');local w=PLUGIN.work[p];local r=w.repair
 p.dir=Vector(-1,0,0);inputMove(p,'hold',1);eq(r.hold,nil)
 aimBolt(p,1);inputMove(p,'release',1);eq(#r.game.done,0)
 inputMove(p,'hold',1);assert(r.hold);aimBolt(p,2);PLUGIN:TickJobs();eq(r.hold,nil)
 inputMove(p,'release',1);eq(#r.game.done,0)
 aimBolt(p,1);inputMove(p,'hold',1);clock=clock+20;PLUGIN:EngineeringInput(p,r.token,r.round,'release',1,0)
 eq(r.game.lost,1);eq(#r.game.done,0);eq(part.removed,0)
`);
suite('Random pressure puzzles solve from public diagnostic readings and base-5 packing; stages tighten steadily',`
 local G=ix.repair.games.pressure
 for code=0,124 do eq(G.Pack(G.Unpack(code)),code) end
 math.randomseed(403)
 for seed=1,100 do for stage=1,5 do
  local g=ix.Facility.EngineeringStage('pressure',stage,0);assert(g,'generator failed')
  local pub=ix.repair.PublicState(g);eq(pub.hi-pub.lo,12-stage*2);local start=table.Copy(pub.valves);local initial=pub.reading;local weights={}
  for index=1,3 do
   local v=table.Copy(start);local delta=v[index]<4 and 1 or -1;v[index]=v[index]+delta
   local result=ix.repair.PlayMove(g,{kind='run',a=G.Pack(v)})
   if result.win then break end
   weights[index]=(ix.repair.PublicState(g).reading-initial)/delta
  end
  if not g.win then
   local base=initial;for i=1,3 do base=base-start[i]*weights[i] end
   local code;for trial=0,124 do local v=G.Unpack(trial);local reading=base;for i=1,3 do reading=reading+weights[i]*v[i] end
    if reading>=pub.lo and reading<=pub.hi then code=trial;break end
   end
   assert(code);assert(ix.repair.PlayMove(g,{kind='run',a=code}).win,'public pressure solver failed')
  end
 end end
 local width=1;local period=9
 for stage=1,5 do local s=ix.Facility.EngineeringStage('bolts',stage,0);assert(s.hi[1]-s.lo[1]<width);width=s.hi[1]-s.lo[1] end
`);

run('Engineering UI uses string verdicts and matching pressure packing, fits narrow screens and closes once',setup+env+`
 SERVER=false;CLIENT=true;TOP=1;LEFT=2;FILL=3;KEY_ESCAPE=4;MOUSE_LEFT=1
 function Color(...) return {...} end;function ScrW() return 480 end;function ScrH() return 640 end
 local panels,labels={},{};vgui={};surface={PlaySound=function() end,CreateFont=function() end};draw={};gui={IsGameUIVisible=function() return false end}
 function vgui.Create(kind)
  local p={valid=true,kind=kind,children={},width=400,removed=0}
  panels[#panels+1]=p
  function p:Add(kind) local c=vgui.Create(kind);self.children[#self.children+1]=c;return c end
  function p:SetPos(x,y) self.x=x;self.y=y end;function p:SetSize(w,h) self.width=w;self.height=h end;function p:SetWide(w) self.width=w end;function p:GetWide() return self.width end
  function p:SetText(v) self.text=v end;function p:SetValue(v) self.value=v end
  for _,key in ipairs({'Dock','DockMargin','DockPadding','SetTall','Center','SetTitle','MakePopup','SetMinMax','SetDecimals'}) do p[key]=function() end end
  function p:Remove() self.removed=self.removed+1;assert(self.removed==1,'recursive removal');if self.OnRemove then self:OnRemove() end;self.valid=false end
  return p
 end
 function ix.Facility.Label(_,text) labels[#labels+1]=text end
 function ix.Facility.Button(parent,text,fn) local p=parent:Add('DButton');p.text=text;p.DoClick=fn;return p end
 function ix.Facility.CloseRepair() end
 local player=admin();function LocalPlayer() return player end
 input={IsMouseDown=function() return false end};net.WriteInt=function(v) net.packet.inputs=net.packet.inputs or {};table.insert(net.packet.inputs,v) end
 `+source(['ixhl2rp/plugins/facility_utilities/cl_hardware.lua','ixhl2rp/plugins/facility_utilities/cl_engineering.lua'])+`
 local F=ix.Facility
 local state=ix.repair.PublicState(F.EngineeringStage('probe',5,0));state.probes={{a=0,b=2,result='open'},{a=2,b=3,result='closed'}}
 F.OpenEngineering({token=20,round=1,stage=5,kind='probe',entity=1,expires=clock+30,state=state,title='Repair'})
 local joined=table.concat(labels,'|');assert(joined:find('0 → 2: обрыв',1,true));assert(joined:find('2 → 3: цепь есть',1,true))
 local board=panels[1].probeBoard;board:PerformLayout(panels[1].width-60)
 local previous;for _,p in ipairs(panels) do if p.facilityProbePoint then assert(p.x>=0 and p.x+p.width<=panels[1].width-60,'terminal overflow');if previous then assert(p.x>=previous.x+previous.width,'terminal targets overlap') end;previous=p end end
 local win=panels[1];local count=#net.packets;win:Remove();eq(#net.packets,count+1);eq(win.removed,1)
 panels={};labels={};local g=F.EngineeringStage('pressure',1,0)
 F.OpenEngineering({token=21,round=1,stage=1,kind='pressure',entity=1,expires=clock+30,state=ix.repair.PublicState(g),title='Repair'})
 for _,p in ipairs(panels) do if p.facilityValve then for i=1,4 do p.DoRightClick() end;for i=1,p.facilityValve do p.DoClick() end end end
 for _,p in ipairs(panels) do if p.text=='Проверить давление' then p.DoClick() end end
 eq(net.packets[#net.packets].inputs[1],1*25+2*5+3)
 local win=panels[1];F.OpenEngineering({token=21,round=2,stage=6,kind='pressure',result='complete',state=ix.repair.PublicState(g)})
 eq(IsValid(win),false);eq(win.removed,1)
`);
finish();
