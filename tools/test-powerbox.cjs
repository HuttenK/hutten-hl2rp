const fs=require('fs'),{normalize}=require('./glua.cjs');
const source=f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend\n';
module.exports=run=>{
 const fixtures=['sharedposes','pose-gizmo','tv','cctv'].map(f=>source('tools/fixtures/'+f+'.lua')).join('');
 const setup=fixtures+`
 SERVER=true;CLIENT=false;ENT={};IN_WALK=12
 ix.CCTV={kinds={}};ix.DevicePower={RefreshAll=function() end}
 ix.util={GetMaterial=function() return {} end};ix.lang={AddTable=function() end}
 function AddCSLuaFile() end
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 function CreateMaterial(name,shader,data) return {name=name,shader=shader,data=data} end
 function math.Rand(a,b) return a end
 function math.Approach(a,b,d) return a<b and math.min(a+d,b) or math.max(a-d,b) end
 function FrameTime() return .1 end
 function ents.GetAll() local out={};for _,e in pairs(entities) do if IsValid(e) then out[#out+1]=e end end;return out end
 local V=getmetatable(Vector());function V:WithinAABox(a,b) return self.x>=a.x and self.x<=b.x and self.y>=a.y and self.y<=b.y and self.z>=a.z and self.z<=b.z end
 net.WriteVector=function() end
 function CreatePhysCollideBox(mn,mx)
  return {Destroy=function(self) self.destroyed=true end,TraceBox=function(self,op,oa,start,finish)
   local a=WorldToLocal(start,Angle(),op,oa);local b=WorldToLocal(finish,Angle(),op,oa);local delta=b-a
   local low,high=0,1
   for _,k in ipairs({'x','y','z'}) do
    if math.abs(delta[k])<.00001 then if a[k]<mn[k] or a[k]>mx[k] then return false end
    else local x,y=(mn[k]-a[k])/delta[k],(mx[k]-a[k])/delta[k];if x>y then x,y=y,x end
     low=math.max(low,x);high=math.min(high,y);if low>high then return false end
    end
   end
   return start+(finish-start)*low,Vector(1,0,0),low
  end}
 end
 function newBox()
  local e=entity(500,'',Vector(),Angle());for k,v in pairs(ENT) do e[k]=v end;e.ixBlackoutFusebox=true
  function e:NetworkVar(kind,_,name) self['Get'..name]=function(s) return s[name] or (kind=='Float' and 0 or false) end;self['Set'..name]=function(s,v) s[name]=v end end
  e:SetupDataTables()
  function e:PhysicsInitMultiConvex(h) self.hulls=h end
  function e:SetCollisionBounds(a,b) self.mins=a;self.maxs=b end
  function e:EnableCustomCollisions(v) self.custom=v end
  function e:ResetSequence(v) self.sequence=v end
  function e:SetCycle(v) self.cycle=v end
  function e:SetPlaybackRate(v) self.rate=v end
  function e:EmitSound() end
  function e:LocalToWorld(v) return LocalToWorld(v,Angle(),self.pos,self.ang) end
  function e:WorldToLocal(v) return WorldToLocal(v,Angle(),self.pos,self.ang) end
  function e:GetPhysicsObject() return {valid=true,SetMass=function() end,EnableMotion=function() end,Sleep=function() end} end
  e:Initialize();return e
 end
 `;
 const entityFile='ixhl2rp/plugins/blackout/entities/entities/ix_blackout_fusebox.lua';
 const serverFile='ixhl2rp/plugins/blackout/sv_plugin.lua';
 const suite=(name,files,test)=>run(name,[],setup+files.map(source).join('')+test);
 suite('Both screwdriver IDs route powerbox repair and sabotage to calibration; missing tools and low skill reject work',[entityFile,serverFile],`
  local p=admin();p.inventories={};p.items={};p.skill=3
  function p:HasItem(id) return self.items[id]==true end
  function p:SetAction() end
  function p:DoStaredAction() error('Powerboxes must use calibration, never the old timer') end
  PLUGIN.BeginFuseboxCalibration=function(_,who,box,sabotage) who.complete=sabotage and 'sabotage' or 'repair';return true end
  PLUGIN.CheckElectricSkill=function(_,client,box,needed) return client.skill>=needed end
  PLUGIN.repairSkill=3;PLUGIN.breakSkill=4;PLUGIN.repairTime=30;PLUGIN.breakTime=30
  PLUGIN.RecomputeZones=function() end;PLUGIN.SaveFuseboxes=function() end
  PLUGIN.GetOwningZone=function() end;PLUGIN.ApplyBreak=function(_,client,box) box:SetBroken(true) end
  local c=p:GetCharacter();c.DoAction=function() end;c.UpdateSkillProgress=function() end
  function p:GetCharacter() return c end
  for _,id in ipairs({'tool_screw'}) do
   local e=newBox();e.StartSparks=function() end;e.StopSparks=function() end;e:SetBroken(true)
   p.items={};p.complete=nil;PLUGIN:TryRepair(p,e);eq(p.complete,nil)
   p.items[id]=true;p.skill=2;PLUGIN:TryRepair(p,e);eq(p.complete,nil)
   p.skill=3;PLUGIN:TryRepair(p,e);eq(p.complete,'repair');eq(e:GetBroken(),true)
   e:SetBroken(false)
   p.complete=nil;PLUGIN:TryBreakScrewdriver(p,e);eq(p.complete,nil)
   p.skill=4;PLUGIN:TryBreakScrewdriver(p,e);eq(p.complete,'sabotage');eq(e:GetBroken(),false)
  end
 `);
 suite('Powerbox collision follows the idle cabinet and post, ignores empty space, and follows entity rotation',[entityFile],`
  local e=newBox();eq(e.model,'models/props_c17/powerbox.mdl');eq(e.sequence,'idle');eq(e.rate,0);eq(#e.hulls,2);eq(e.custom,true)
  local h=e:TestCollision(Vector(80,0,54),Vector(-100,0,0),false,Vector());assert(h);near(h.HitPos.x,8.4376);eq(h.part,'door')
  eq(e:TestCollision(Vector(80,10,20),Vector(-100,0,0),false,Vector()),false)
  assert(e:TestCollision(Vector(80,0,20),Vector(-100,0,0),false,Vector()))
  e.ang=Angle(0,90,0);e.pos=Vector(150,80,0)
  assert(e:TestCollision(e:LocalToWorld(Vector(80,0,54)),e.ang:Forward()*-100,false,Vector()))
  local c=e.ixColliders[1];e:ClearColliders();eq(c.destroyed,true)
 `);
 suite('Door aim toggles the leaf; exposed inner panel starts work; cooldown and occupied boxes are respected',[entityFile],`
  local e=newBox();local p=admin();p.pos=Vector(80,0,54);p.dir=Vector(-1,0,0);local repair,breaks=0,0
  PLUGIN.TryRepair=function() repair=repair+1 end;PLUGIN.TryBreakScrewdriver=function() breaks=breaks+1 end
  e:Use(p);eq(e:GetDoorOpen(),true);eq(repair,0);eq(breaks,0)
  e:Use(p);eq(breaks,0);clock=clock+1;e:Use(p);eq(breaks,1)
  e:SetBroken(true);clock=clock+1;e:Use(p);eq(repair,1)
  local op,oa=e:DoorTransform();local centre=LocalToWorld(Vector(11,0,1),Angle(),op,oa)
  p.pos=centre+oa:Up()*65;p.dir=-oa:Up();eq(e:InteractionTarget(p),'door')
  e.ixRepairing=p;clock=clock+1;e:Use(p);eq(e:GetDoorOpen(),true)
  e.ixRepairing=nil;clock=clock+1;e:Use(p);eq(e:GetDoorOpen(),false);eq(repair,1)
  clock=clock+1;p.pos=Vector(80,0,54);p.dir=Vector(-1,0,0);e:Use(p);eq(e:GetDoorOpen(),true)
  clock=clock+1;p.pos=Vector(1000,0,0);e:Use(p);eq(repair,1)
 `);
 suite('Powerbox repair rejects back, sides, post, blocked rays and an opening door; rotated door stays targetable',[entityFile],`
  local e=newBox();local p=admin();e:SetBroken(true);local repaired=0
  PLUGIN.TryRepair=function() repaired=repaired+1 end
  p.pos=Vector(80,0,54);p.dir=Vector(-1,0,0)
  local trace=util.TraceLine;util.TraceLine=function() return {Hit=true} end
  e:Use(p);eq(e:GetDoorOpen(),false);util.TraceLine=trace
  e:Use(p);eq(e:GetDoorOpen(),true)
  clock=clock+.55;e:Use(p);eq(repaired,0)
  clock=clock+1
  p.pos=Vector(-80,0,54);p.dir=Vector(1,0,0);e:Use(p);eq(repaired,0)
  p.pos=Vector(80,0,20);p.dir=Vector(-1,0,0);e:Use(p);eq(repaired,0)
  p.pos=Vector(0,80,54);p.dir=Vector(0,-1,0);e:Use(p);eq(repaired,0)
  e.ang=Angle(15,90,12);e.pos=Vector(20,80,10)
  p.pos=e:LocalToWorld(Vector(80,0,54));p.dir=-e.ang:Forward();eq(e:InteractionTarget(p),'panel');e:Use(p);eq(repaired,1)
  clock=clock+1;local op,oa=e:DoorTransform();local centre=LocalToWorld(Vector(11,0,1),Angle(),op,oa)
  p.pos=centre+oa:Up()*65;p.dir=-oa:Up();eq(e:InteractionTarget(p),'door');e:Use(p);eq(e:GetDoorOpen(),false)
  eq(repaired,1)
 `);
 suite('Blackout powerbox indicator follows actual power without corrupting physical damage or remote isolation',[entityFile,serverFile],`
  local e=newBox();PLUGIN.fuseboxes={e};local outage=false
  function PLUGIN:IsPosBlackedOut() return outage end
  e:SetBroken(false);PLUGIN:RefreshBoxPower();eq(e:GetNoPower(),false)
  outage=true;PLUGIN:RefreshBoxPower();eq(e:GetNoPower(),true);eq(e:GetBroken(),false)
  e:SetBroken(true);outage=false;PLUGIN:RefreshBoxPower();eq(e:GetNoPower(),false);eq(e:GetBroken(),true)
  local p=admin();p.admin=false;eq(PLUGIN:PhysgunPickup(p,e),false);p.admin=true;eq(PLUGIN:PhysgunPickup(p,e),nil)
 `);
 suite('Local blackout switches independent lights only, preserving shared baked map light styles',[serverFile],`
  local function light(id,class,x)
   local e=entity(id,'',Vector(x,0,0));e.class=class;e.on=true
   function e:GetSaveTable() return {m_bOn=self.on} end
   function e:Input(input) self.on=input=='TurnOn' end
   return e
  end
  local baked=light(1,'light',0);local spot=light(2,'light_spot',0)
  local inside=light(3,'light_dynamic',0);local outside=light(4,'light_dynamic',500)
  function PLUGIN:IsPosBlackedOut(v) return v.x<100 end
  PLUGIN:RefreshLights();eq(baked.on,true);eq(spot.on,true);eq(inside.on,false);eq(outside.on,true)
  PLUGIN:AcceptInput(inside,'TurnOff');PLUGIN.unloading=true;PLUGIN:RefreshLights();eq(inside.on,false)
  -- A prior version may already have switched a baked style before auto-refresh.
  PLUGIN.lightStates[baked]={on=true};baked.on=false;PLUGIN:RefreshLights();eq(baked.on,true)
 `);
 suite('Admin blackout synchronizes own fuseboxes while nested box power follows the covering outage',[entityFile,serverFile],`
  local a={min=Vector(-100,-100,-10),max=Vector(100,100,100),active=false}
  local b={min=Vector(-10,-10,-5),max=Vector(10,10,70),active=false}
  PLUGIN.zones={outer=a,inner=b};local e=newBox();PLUGIN.fuseboxes={e}
  function PLUGIN:IsPosBlackedOut() return a.active or b.active end
  PLUGIN.SaveData=function() end;PLUGIN.NetworkZones=function() end
  PLUGIN:ToggleZone('outer');eq(a.active,true);eq(e:GetNoPower(),true);eq(e:GetBroken(),false)
  PLUGIN:ToggleZone('outer');eq(e:GetNoPower(),false)
  PLUGIN:ToggleZone('inner');eq(e:GetBroken(),true);eq(e:GetNoPower(),true)
  PLUGIN:ToggleZone('inner');eq(e:GetBroken(),false);eq(e:GetNoPower(),false)
 `);
 // Simulate one depth/color-buffer pixel, executing the real stencil operations.
 const stencilSetup=`
  SERVER=false;CLIENT=true;PLUGIN.maskLayers=1;PLUGIN.maskDarkness=220;PLUGIN.maskColor={r=4,g=6,b=16}
  local bit32={band=function(a,b) return a & b end,bor=function(a,b) return a | b end}
  local eye,scene=0,0;local value,draws=0,0;local write,test,reference,compare,pass,zfail,color=255,255,0,1,0,0,true
  local pixel,alpha,stencil,depthWrite=1,0,false,false
  local drawTranslucent=true
  function GetConVar(name) eq(name,'r_drawtranslucentworld');return {GetBool=function() return drawTranslucent end} end
  STENCILOPERATION_KEEP=0;STENCILOPERATION_INVERT=1;STENCILOPERATION_REPLACE=2
  STENCILCOMPARISONFUNCTION_ALWAYS=1;STENCILCOMPARISONFUNCTION_EQUAL=2;MATERIAL_CULLMODE_CW=1;MATERIAL_CULLMODE_CCW=2
  local eyePosition,ray,sceneDistance,nearClip
  local currentMatrix,currentMaterial
  local meshes={}
  function Matrix() return {SetTranslation=function(self,p) self.pos=p end,SetScale=function(self,s) self.scale=s end} end
  -- Intersect the submitted triangles, rather than assuming DrawBox/CullMode
  -- corresponds to one particular world axis. Shared triangle edges count once.
  local function intersections(vertices,origin,direction)
   local hits={}
   for i=1,#vertices,3 do
    local function world(v)
     local p=v.pos;local m=currentMatrix
     return m and m.pos+Vector(p.x*m.scale.x,p.y*m.scale.y,p.z*m.scale.z) or p
    end
    local a,b,c=world(vertices[i]),world(vertices[i+1]),world(vertices[i+2])
    local ab,ac=b-a,c-a;local h=direction:Cross(ac);local det=ab:Dot(h)
    if math.abs(det)>1e-9 then
     local delta=origin-a;local u=delta:Dot(h)/det;local q=delta:Cross(ab);local v=direction:Dot(q)/det
     if u>=-1e-8 and v>=-1e-8 and u+v<=1+1e-8 then
      local t=ac:Dot(q)/det;local duplicate=false
      for _,old in ipairs(hits) do if math.abs(old-t)<1e-6 then duplicate=true end end
      if not duplicate then hits[#hits+1]=t end
     end
    end
   end
   return hits
  end
  local function operation(op)
   local result=op==1 and (255-value) or op==2 and reference or value
   value=bit32.bor(bit32.band(value,255-write),bit32.band(result,write))
  end
  render={SetStencilEnable=function(v) stencil=v;if v then value=0 end end,SetStencilWriteMask=function(v) write=v end,
   SetStencilTestMask=function(v) test=v end,SetStencilReferenceValue=function(v) reference=v end,
   SetStencilCompareFunction=function(v) compare=v end,SetStencilPassOperation=function(v) pass=v end,
   SetStencilZFailOperation=function(v) zfail=v end,SetStencilFailOperation=function() end,ClearStencil=function() value=0 end,
   OverrideColorWriteEnable=function(enabled,allowed) color=not enabled or allowed end,OverrideAlphaWriteEnable=function() end,
   OverrideDepthEnable=function(v) depthWrite=v end,SetMaterial=function(m) currentMaterial=m end}
  function Mesh()
   local m={draws=0};meshes[#meshes+1]=m
   function m:BuildFromTriangles(v) self.vertices=v end
   function m:Destroy() self.dead=true end
   function m:Draw()
    assert(not self.dead);self.draws=self.draws+1
    eq(currentMaterial.data['$nocull'],'1');eq(currentMaterial.data['$ignorez'],'0');eq(currentMaterial.data['$translucent'],'0')
    eq(color,false);eq(depthWrite,true)
    local origin,direction=eyePosition or Vector(0,0,eye),ray or Vector(0,0,1)
    for _,t in ipairs(intersections(self.vertices,origin,direction)) do
     if t>(nearClip or 0) and t>(sceneDistance or scene-eye) then operation(zfail) end
    end
   end
   return m
  end
  surface={SetDrawColor=function(r,g,b,a) alpha=a/255 end,DrawRect=function()
   if compare==1 or bit32.band(value,test)==bit32.band(reference,test) then
    if color then draws=draws+1;pixel=pixel*(1-alpha) end;operation(pass)
   end
  end};cam={Start2D=function() end,End2D=function() end,PushModelMatrix=function(m) currentMatrix=m end,PopModelMatrix=function() currentMatrix=nil end};function ScrW() return 1920 end;function ScrH() return 1080 end
 `;
 suite('Blackout stencil shades only in-zone surfaces from inside/outside and unions overlaps without stacking',[],stencilSetup+`
  ${source('ixhl2rp/plugins/blackout/cl_plugin.lua')}
  PLUGIN.zones={{min=Vector(-50,-50,10),max=Vector(50,50,20)}}
  local paint=hooks.PostDrawOpaqueRenderables.ixBlackoutStencil
  local function check(e,s,n) eye=e;scene=s;draws=0;paint(false,false,false);eq(draws,n) end
  check(0,5,0);check(0,15,1);check(0,30,0)
  check(12,15,1);check(12,30,0) -- looking out from a dark zone must leave the next room bright
  PLUGIN.zones[2]={min=Vector(-50,-50,12),max=Vector(50,50,25)}
  check(0,15,1);check(0,23,1);check(0,30,0)
  check(12,15,1);check(0,30,0) -- successive CCTV/player views never share an inside-darkness value
  draws=0;paint(false,true,true);eq(draws,0)
 `);
 suite('Closed blackout mesh has identical depth parity from all six sides, diagonals, inside and near-plane crossings',[],stencilSetup+`
  ${source('ixhl2rp/plugins/blackout/cl_plugin.lua')}
  local center=Vector(3,7,15);PLUGIN.zones={{min=Vector(-50,-50,10),max=Vector(50,50,20)}}
  local paint=hooks.PostDrawOpaqueRenderables.ixBlackoutStencil
  local function check(origin,direction,distance,expected)
   eyePosition=origin;ray=direction;sceneDistance=distance;draws=0;pixel=1
   paint(false,false,false);eq(draws,expected);eq(currentMatrix,nil)
  end
  for _,direction in ipairs({Vector(1,0,0),Vector(-1,0,0),Vector(0,1,0),Vector(0,-1,0),Vector(0,0,1),Vector(0,0,-1),Vector(1,2,.3):GetNormalized(),Vector(-1,-2,-.3):GetNormalized()}) do
   check(center-direction*150,direction,150,1) -- surface inside
   check(center-direction*150,direction,1,0) -- foreground outside
   check(center-direction*150,direction,300,0) -- far room outside
   check(center,direction,2,1)
   check(center,direction,300,0)
  end
  nearClip=3;check(Vector(3,7,9.5),Vector(0,0,1),5.5,1)
  check(Vector(3,7,20.5),Vector(0,0,-1),5.5,1)
  eq(#meshes,1);eq(#meshes[1].vertices,36)
  -- Every undirected edge occurs twice: no open side or duplicated triangle.
  local edges={}
  local function key(v) return v.x..','..v.y..','..v.z end
  local vs=meshes[1].vertices
  for i=1,#vs,3 do for j=0,2 do
   local a,b=key(vs[i+j].pos),key(vs[i+(j+1)%3].pos);if a>b then a,b=b,a end
   local k=a..'/'..b;edges[k]=(edges[k] or 0)+1
  end end
  for _,count in pairs(edges) do eq(count,2) end
  PLUGIN:OnUnload();eq(meshes[1].dead,true)
 `);
 suite('Main blackout visibility ignores a stale auxiliary view; CCTV uses its own view and unknown far planes do not reject zones',[],stencilSetup+`
  function string.StartWith(s,prefix) return s:sub(1,#prefix)==prefix end
  ${source('ixhl2rp/plugins/blackout/cl_plugin.lua')}
  PLUGIN.zones={{min=Vector(80,-10,-10),max=Vector(100,10,10)}}
  local main={origin=Vector(),angles=Angle(),fov=90,aspect=16/9,zfar=0}
  local remote={origin=Vector(),angles=Angle(0,180,0),fov=90,aspect=16/9,zfar=1000}
  local target;render.GetRenderTarget=function() return target end
  local requested;render.GetViewSetup=function(aux) requested=aux;return aux and remote or main end
  eyePosition=Vector();ray=Vector(1,0,0);sceneDistance=90
  local paint=hooks.PostDrawOpaqueRenderables.ixBlackoutStencil
  draws=0;paint(false,false,false);eq(requested,false);eq(draws,1)
  target={GetName=function() return '_rt_FullFrameFB' end}
  draws=0;paint(false,false,false);eq(requested,false);eq(draws,1)
  target={GetName=function() return 'ix_cctv_feed_v1_1' end}
  draws=0;paint(false,false,false);eq(requested,true);eq(draws,0)
  remote.origin=Vector(180,0,0);eyePosition=remote.origin;ray=Vector(-1,0,0);sceneDistance=90
  draws=0;paint(false,false,false);eq(draws,1)
 `);
 suite('Blackout shades opaque surfaces before luminous particles and never shades the same view twice',[],stencilSetup+`
  hook.Add('PostDrawTranslucentRenderables','ixBlackoutStencil',function() error('Stale late veil survived refresh') end)
  ${source('ixhl2rp/plugins/blackout/cl_plugin.lua')}
  PLUGIN.zones={{min=Vector(-50,-50,10),max=Vector(50,50,20)}}
  eye=0;scene=15;pixel=1;draws=0
  hook.Run('PostDrawOpaqueRenderables',false,false,false);near(pixel,1-220/255);eq(draws,1)
  pixel=pixel+.6 -- emissive fire is added by the normal translucent pass
  hook.Run('PostDrawTranslucentRenderables',false,false,false);near(pixel,1-220/255+.6);eq(draws,1)
  for _,flags in ipairs({{true,false,false},{false,true,true},{false,false,true}}) do
   draws=0;hook.Run('PostDrawOpaqueRenderables',table.unpack(flags));eq(draws,0)
  end
  drawTranslucent=false;eye=12;scene=15;pixel=1;draws=0
  hook.Run('PostDrawOpaqueRenderables',false,false,false);near(pixel,1-220/255);eq(draws,1)
  eye=12;scene=30;pixel=1;draws=0;hook.Run('PostDrawOpaqueRenderables',false,false,false);eq(pixel,1);eq(draws,0)
  PLUGIN:OnUnload();eq(hooks.PostDrawOpaqueRenderables.ixBlackoutStencil,nil)
  eq(hooks.PostDrawOpaqueRenderables.ixBlackoutStencilFallback,nil)
  eq(hooks.PostDrawTranslucentRenderables.ixBlackoutStencil,nil)
 `);
 suite('Physical addon geometry is drawn once before blackout capture and is still drawn with no active zone',[],stencilSetup+`
  ${source('ixhl2rp/plugins/blackout/cl_plugin.lua')}
  local geometry=0
  hook.Add('ixBlackoutWorldGeometry','cables',function() geometry=geometry+1;eq(draws,0) end)
  function PLUGIN:CaptureFlashlight() eq(geometry,1);eq(draws,0) end
  PLUGIN.zones={{min=Vector(-50,-50,10),max=Vector(50,50,20)}};eye=0;scene=15;draws=0
  hook.Run('PostDrawOpaqueRenderables',false,false,false);eq(geometry,1);eq(draws,1)
  hook.Run('PostDrawTranslucentRenderables',false,false,false);eq(geometry,1)
  PLUGIN.zones={};draws=0;hook.Run('PostDrawOpaqueRenderables',false,false,false);eq(geometry,2)
  hook.Run('PostDrawOpaqueRenderables',true,false,false);eq(geometry,2)
  hook.Run('PostDrawOpaqueRenderables',false,true,false);eq(geometry,3)
  hook.Run('PostDrawOpaqueRenderables',false,true,true);eq(geometry,3)
  PLUGIN:OnUnload();eq(PLUGIN.drawsWorldGeometry,false)
 `);
 suite('Recorded opposite entrances shade the same zone even when the main view reports a 2D skybox',[],stencilSetup+`
  ${source('ixhl2rp/plugins/blackout/cl_plugin.lua')}
  PLUGIN.zones={{min=Vector(-718.9375,-1577.9375,-1103.9688),max=Vector(314.875,-928,-700),darkness=99,softness=1}}
  local paint=hooks.PostDrawOpaqueRenderables.ixBlackoutStencil
  local points={Vector(-146,-875.98,-906.97),Vector(-128,-1641.78,-906.97)}
  local surface=Vector(-136,-1250,-1000)
  for i,origin in ipairs(points) do
   eyePosition=origin;ray=(surface-origin):GetNormalized();sceneDistance=(surface-origin):Length();pixel=1;draws=0
   paint(false,i==1,false);eq(draws,1);assert(math.abs(pixel-.01)<=1/255)
   -- Foreground and the lit room beyond the blackout keep their lighting.
   for _,distance in ipairs({1,2000}) do
    sceneDistance=distance;pixel=1;draws=0;paint(false,i==1,false);eq(draws,0);eq(pixel,1)
   end
  end
 `);
 suite('Powerbox glow is red for offline or damaged boxes, green only when healthy and powered, on both the gauge and moving exterior door button',[],`
  SERVER=false;CLIENT=true;ENT={};RENDERGROUP_BOTH=42
  ${source(entityFile)}
  local e={valid=true,open=false,power=true,angles={},pitch=0}
  for k,v in pairs(ENT) do e[k]=v end
  function e:GetDoorOpen() return self.open end
  function e:GetDoorPitchFrom() return self.from or 0 end
  function e:GetDoorMotionAt() return self.changed or clock end
  function e:LookupBone(name) eq(name,'proxy_box.door_cntrl');return 1 end
  function e:ManipulateBoneAngles(id,a) eq(id,1);self.pitch=a.p end
  function e:GetNoPower() return not self.power end
  function e:GetBroken() return self.broken==true end
  local models=0;function e:DrawModel() models=models+1 end
  function e:LocalToWorld(v) return v end
  function e:GetForward() return Vector(1,0,0) end
  function e:GetPos() return Vector() end;function e:GetAngles() return Angle() end
  angle_zero=Angle()
  local lamps=0;local lampColor;local doorPosition,doorNormal;render={SetMaterial=function(mat)
   eq(mat.data['$basetexture'],'sprites/glow04');eq(mat.data['$ignorez'],'0');eq(mat.data['$additive'],'1')
  end,DrawQuadEasy=function(pos,normal,w,h,color)
   lamps=lamps+1;lampColor=color
   if w==3 then near(pos.x,1.55);near(pos.y,6.7);near(pos.z,58.86);eq(normal.x,1);near(h,3)
   else near(w,2);near(h,2);doorPosition=pos;doorNormal=normal end
  end}
  eq(e.RenderGroup,42);e:Draw();eq(models,1);eq(lamps,0)
  e:Think();eq(e.pitch,0);e.open=true;e.changed=clock;clock=clock+.1;e:Think();near(e.pitch,-22)
  clock=clock+1;e:Think();eq(e.pitch,-140)
  e.open=false;e.from=-140;e.changed=clock;clock=clock+1;e:Think();eq(e.pitch,0)
  e:DrawTranslucent();eq(lamps,2)
  assert(doorPosition:DistToSqr(Vector(6.197,-2.3595,60.106))<.00001)
  assert(doorNormal:Dot(Vector(1,0,0))>.9999)
  local closedPosition=doorPosition
  e.open=true;e.changed=clock;clock=clock+1;e:DrawTranslucent();eq(lamps,4);eq(lampColor.g,255)
  assert(doorPosition:DistToSqr(closedPosition)>20);assert(doorNormal:Dot(Vector(1,0,0))<0)
  e.broken=true;e:DrawTranslucent();eq(lamps,6);eq(lampColor.r,255)
  e.power=false;e:DrawTranslucent();eq(lamps,8);eq(lampColor.r,255);eq(lampColor.g,40)
  e.broken=false;e:DrawTranslucent();eq(lamps,10);eq(lampColor.r,255);eq(lampColor.g,40)
  e.power=true;e:DrawTranslucent();eq(lamps,12);eq(lampColor.r,40);eq(lampColor.g,255)
  e.power=false;e.open=false;e.from=-140;e.changed=clock;clock=clock+1;e:DrawTranslucent();eq(lamps,14);eq(lampColor.r,255);eq(models,1)
 `);
};
if(require.main===module){const f=require('fengari');let n=0;module.exports((name,files,test)=>{const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);const s=fs.readFileSync('tools/fixture.lua','utf8')+'\n'+test;const r=f.lauxlib.luaL_dostring(L,f.to_luastring(s));if(r!==f.lua.LUA_OK){fs.writeFileSync('docs/powerbox-expanded.lua',s);throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));}console.log('PASS '+name);n++});console.log(n+' powerbox regression suites passed.');}
