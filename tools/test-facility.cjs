const fs=require('fs'),{normalize}=require('./glua.cjs');
module.exports=run=>{
 const base=['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','tools/fixtures/facility.lua','helix/plugins/area/sh_geometry.lua'];
 const server=[...base,...['sh_core','sh_repair','sv_store','sv_portables','sv_connections','sv_power','sv_doors','sv_comms','sv_jobs','sv_repair','sv_devices','sv_network','entities/entities/ix_facility_device'].map(s=>'ixhl2rp/plugins/facility_utilities/'+s+'.lua')];
 const solve=`function solveRepair(p) for i=PLUGIN.work[p].repair.stage,ix.Facility.repair.contacts do local r=PLUGIN.work[p].repair;clock=r.started+r.target*r.period*.5;PLUGIN:RepairInput(p,r.token,r.round,true) end end`;
 const wiringFixture=`
  local nextItem=20000
  ix.Item=ix.Item or {};ix.Item.instances=ix.Item.instances or {}
  ix.Inventory=ix.Inventory or {};ix.Inventory.pendingTransfers={}
  function ix.Item:Instance(id,data)
   nextItem=nextItem+1;local item={id=nextItem,uniqueID=id,data=data or {},removed=0}
   function item:GetOwner() return self.owner end;function item:GetEntity() return self.entity end
   function item:Save() end
   function item:Remove() self.removed=self.removed+1;ix.Item.instances[self.id]=nil;if self.owner then self.owner.cables[self.id]=nil end end
   self.instances[item.id]=item;return item
  end
  function ix.Item:Spawn(pos,ang,item) local e=entity(item.id,'cable',pos);item.entity=e;return e end
  local oldAdmin=admin
  function admin(...)
   local p=oldAdmin(...);p.cables={};p.fit=true
   local oldHas=p.HasItem
   function p:HasItem(id) if id=='facility_cable' then local _,item=next(self.cables);return item~=nil,item end;return oldHas(self,id) end
   function p:GetInventory() return {Sync=function() end,AddItem=function(_,item) if not p.fit then return false end;item.owner=p;p.cables[item.id]=item;return true end} end
   for i=1,16 do local item=ix.Item:Instance('facility_cable');item.owner=p;p.cables[item.id]=item end
   return p
  end
 `;
 const suite=(name,test)=>run(name,[],server.map(f=>'do local function source()\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend;source() end').join('\n')+'\nPLUGIN.loaded=true\n'+solve+wiringFixture+'\n'+test);
 const nativeItems=fs.readFileSync('helix/gamemode/game/items/sh_item.lua','utf8');
 const nativeDrop=normalize(nativeItems.slice(nativeItems.indexOf('\tfunction Item:Spawn('),nativeItems.indexOf('\tfunction Item:PerformInventoryAction(')));
 const dropFixture=`
  local P=PLUGIN;local queued={};timer.Simple=function(delay,fn) queued[#queued+1]={delay=delay,fn=fn} end
  function flushDrops() while #queued>0 do table.sort(queued,function(a,b) return a.delay<b.delay end);local t=table.remove(queued,1);t.fn() end end
  local rawType=type;local wasValid=IsValid
  type=function(v) return rawType(v)=='table' and v.mockPlayer and 'Player' or rawType(v) end
  IsValid=function(v) if rawType(v)=='table' and v.mockPlayer then return v.valid end;return wasValid(v) end
  local templates={};ix.transmit={owner=1}
  ${['generator','battery'].map(kind=>`do local ITEM={functions={},AddData=function() end};${normalize(fs.readFileSync('ixhl2rp/plugins/facility_utilities/items/sh_facility_'+kind+'.lua','utf8'))};templates['${kind}']=ITEM end`).join('\n')}
  local create=ents.Create
  function ents.Create(class)
   local e=create(class);local ph={valid=true,velocity=Vector()}
   function ph:EnableMotion(v) self.moving=v end;function ph:Wake() self.awake=true end
   function ph:SetVelocity(v) self.velocity=v end;function ph:SetMass(v) self.mass=v end
   function e:GetPhysicsObject() return ph end;function e:GetVelocity() return ph.velocity end
   function e:SetNetVar(k,v) self[k]=v end
   if class=='ix_item' then
    function e:Initialize() end
    function e:SetItem(id) self.ixItemID=id;local item=ix.Item.instances[id];self:SetModel(item.model);item:OnEntityCreated(self) end
    function e:GetItem() return ix.Item.instances[self.ixItemID] end
    function e:OnRemove() if not self.ixIsSafe then error('item removed without safe handoff') end end
   end
   return e
  end
  local inventory={id=88,Sync=function() end,OnCheckAccess=function() return true end}
  function inventory:TakeItemTable(item) item.inventory_id=nil end
  ix.Inventory.Get=function() return inventory end;ix.Item.entities={}
  function dropItem(p,kind,data,position)
   p.mockPlayer=true;function p:SteamID() return 'test' end
   function p:GetItemDropPos() return Vector(45,12,80) end
   local item=ix.Item:Instance('facility_'..kind,data);item.owner=p;item.inventory_id=88
   setmetatable(item,{__index=templates[kind]})
   function item:GetData(key,default) if self.data[key]~=nil then return self.data[key] end;return default end
   function item:SetEntity(e) self.entity=e end;function item:Sync() end
   assert(ix.Item:DropItem(p,item.id,position,Angle(0,35,0)))
   return item,item:GetEntity()
  end
  do local Item=ix.Item;${nativeDrop} end
 `;
 suite('Native menu dropping creates a usable generator, retains state and gives its dropper local controls',dropFixture+`
  local p=admin(0);p.admin=false;p.card=nil
  local item,original=dropItem(p,'generator',{fuel=123,capacity=75,fault=false})
  assert(IsValid(original));eq(table.Count(P.store.devices),0)
  original:GetPhysicsObject():SetVelocity(Vector(3,4,-20))
  timer.Simple(0,function() original:SetPos(Vector(45,12,10)) end) -- native drop surface adjustment
  flushDrops();eq(item.removed,1);eq(IsValid(original),false);eq(ix.Item.instances[item.id],nil);eq(ix.Item.entities[item.id],nil)
  local _,d=next(P.store.devices);eq(d.kind,'generator');eq(d.owner,p.character.id);eq(d.fuel,123);eq(d.capacity,75);eq(d.running,false)
  eq(d.dropped,true);eq(d.portable,true);near(d.entity:GetPos().z,10);near(d.entity:GetAngles().y,35)
  eq(d.entity:GetPhysicsObject().moving,true);near(d.entity:GetVelocity().z,-20)
  assert(P:DeviceAction(p,{id=d.id,command='generator'}));eq(d.running,true)
  local target=device('terminal');assert(P:ConnectGenerator(p,d,target.entity));eq(table.Count(p.cables),15)
 `);
 suite('Native positioned drop creates a usable battery and preserves fault, charge and capacity through pickup',dropFixture+`
  local p=admin(0);p.admin=false;p.card=nil
  local item,original=dropItem(p,'battery',{charge=2345,fault=true,capacity=45,circuit=999},Vector(60,0,15))
  flushDrops();local _,d=next(P.store.devices)
  eq(d.owner,p.character.id);eq(d.charge,2345);eq(d.capacity,45);eq(d.fault,true);eq(d.circuit,0)
  eq(item.removed,1);eq(P:DevicePowered(d),false)
  assert(P:PackGenerator(p,d));eq(P.store.devices[d.id],nil)
  local packed;for _,it in pairs(p.cables) do if it.uniqueID=='facility_battery' then packed=it end end
  assert(packed);eq(packed.data.charge,2345);eq(packed.data.fault,true);eq(packed.data.capacity,45)
  eq(P:PackGenerator(p,d),false)
 `);
 suite('Dropped power source conversion is idempotent and does not consume a picked-up or transferring item',dropFixture+`
  local p=admin();local item,e=dropItem(p,'battery',{charge=321},Vector(60,0,10))
  P:QueueDroppedSource(item,e);flushDrops();eq(table.Count(P.store.devices),1);eq(item.removed,1)
  eq(P:ConvertDroppedSource(item,e),false);eq(item.removed,1)
  local second,world=dropItem(p,'generator',{fuel=222},Vector(50,0,10))
  second.inventory_id=88;second:SetEntity(nil);flushDrops();eq(second.removed,0);eq(table.Count(P.store.devices),1)
  local third,prop=dropItem(p,'battery',{charge=333},Vector(50,0,10))
  ix.Inventory.pendingTransfers['item_'..third.id]=true;flushDrops();eq(third.removed,0);assert(IsValid(prop))
  ix.Inventory.pendingTransfers={};P:QueueDroppedSource(third,prop);flushDrops();eq(third.removed,1);eq(table.Count(P.store.devices),2)
 `);
 suite('Device limits and failed entity creation leave the dropped inventory item available without duplication',dropFixture+`
  local p=admin();local create=P.DeviceRecord
  P.DeviceRecord=function() end
  local item,e=dropItem(p,'generator',{fuel=101},Vector(60,0,10));flushDrops()
  eq(item.removed,0);assert(IsValid(e));eq(table.Count(P.store.devices),0);eq(#p.notices,1)
  P.DeviceRecord=create;local spawn=P.SpawnDevice;P.SpawnDevice=function() end
  P:QueueDroppedSource(item,e);flushDrops();eq(item.removed,0);assert(IsValid(e));eq(table.Count(P.store.devices),0)
  P.SpawnDevice=spawn;P:QueueDroppedSource(item,e);flushDrops();eq(item.removed,1);eq(table.Count(P.store.devices),1)
 `);
 suite('Dropped sources retain movable physics, settled transform, ownership and energy across reloads',dropFixture+`
  local p=admin();local item,e=dropItem(p,'battery',{charge=3210},Vector(50,0,20));flushDrops()
  local _,d=next(P.store.devices);d.entity:SetPos(Vector(65,14,3));d.entity:SetAngles(Angle(0,75,0));P.dirty=false
  P:SyncDevice(d);eq(P.dirty,true);P:SaveData();P:LoadData();flushDrops()
  d=P.store.devices[d.id];eq(d.charge,3210);eq(d.owner,p.character.id);eq(d.dropped,true)
  near(d.entity:GetPos().z,3);near(d.entity:GetAngles().y,75);eq(d.entity:GetPhysicsObject().moving,true)
  eq(table.Count(P.store.devices),1)
 `);
 suite('Conversion waits for loaded state and character switches cannot transfer ownership of a pending drop',dropFixture+`
  local p=admin();local cid=p.character.id;local item,e=dropItem(p,'generator',{fuel=600},Vector(40,0,0))
  P.loaded=false;queued[1].fn();table.remove(queued,1);eq(item.removed,0)
  p.character.id=cid+500;P.loaded=true;flushDrops()
  local _,d=next(P.store.devices);eq(d.owner,cid);eq(d.running,false);eq(item.removed,1)
 `);

 const carryFixture=`
  local P=PLUGIN;local p=admin(0);p.admin=false;p.card=nil
  local d=device('generator');d.owner=p.character.id;d.fuel=111;d.capacity=75
  local hands={valid=true}
  function p:GetWeapon() return hands end;function p:GetActiveWeapon() return self.activeWeapon end
  function p:SelectWeapon() if not self.preventSwitch then self.activeWeapon=hands end end
  function p:SetLocalVar(k,v) self[k]=v end
  function hands:IsHoldingObject() return IsValid(self.heldEntity) end
  function hands:CanHoldObject(e) return not self:IsHoldingObject() and not IsValid(e.ixHeldOwner) and P:CanPlayerHoldObject(p,e) end
  function hands:PickupObject(e) self.heldEntity=e;e.ixHeldOwner=p end
  function hands:DropObject() if self.heldEntity then self.heldEntity.ixHeldOwner=nil end;self.heldEntity=nil;p:SetLocalVar('holdingObject',nil);p:SetLocalVar('bIsHoldingObject',false) end
 `;
 suite('Generator and battery can be carried with hands, released and packed with state intact even when originally admin placed',carryFixture+`
  for _,kind in ipairs({'generator','battery'}) do
   d.kind=kind;d.portable=nil;d.charge=1234;d.fault=true
   local ph=d.entity:GetPhysicsObject();ph:EnableMotion(false);ph:SetMass(250)
   local snapshot=P:DeviceSnapshot(p,d).device;eq(snapshot.moveReason,nil)
   assert(P:DeviceAction(p,{id=d.id,command='carry'}));eq(hands.heldEntity,d.entity);eq(p.holdingObject,d.entity)
   eq(ph:IsMoveable(),true);eq(ph:GetMass(),kind=='battery' and 8 or 18)
   eq(P:DeviceSnapshot(p,d).device.heldByMe,true);eq(P:PackGenerator(p,d),false)
   eq(P:DeviceAction(p,{id=d.id,command='generator'}),false)
   eq(P:DeviceAction(p,{id=d.id,command='connect'}),false)
   assert(P:DeviceAction(p,{id=d.id,command='release'}));eq(hands.heldEntity,nil);eq(d.entity.ixHeldOwner,nil)
   assert(P:CanPlayerHoldObject(p,d.entity));assert(P:PackGenerator(p,d));eq(P:PackGenerator(p,d),false)
   local it;for _,v in pairs(p.cables) do if v.uniqueID=='facility_'..kind then it=v end end
   assert(it);eq(it.data.fuel,111);eq(it.data.charge,1234);eq(it.data.capacity,75);eq(it.data.fault,true)
   d=device('battery');d.owner=p.character.id;d.fuel=111;d.capacity=75
  end
 `);
 suite('Carrying and inventory pickup reject attached, running, held, remote, restricted and unauthorized sources without loss',carryFixture+`
  local function denied() eq(P:CarrySource(p,d),false);eq(P:PackGenerator(p,d),false);eq(P:CanPlayerHoldObject(p,d.entity),false);assert(IsValid(d.entity)) end
  d.running=true;denied();d.running=false
  d.links={{}};denied();d.links={}
  d.entity.ixHeldOwner=admin();denied();d.entity.ixHeldOwner=nil
  p.pos=Vector(999,0,0);denied();p.pos=Vector()
  p.restricted=true;denied();p.restricted=false
  d.owner=999;denied();d.owner=p.character.id
  d.entity.parent=entity(987);denied();d.entity.parent=nil
  d.kind='battery';local g=device('generator');g.links={{kind='battery',id=d.id}};denied();g.links={}
  local ph=d.entity:GetPhysicsObject();ph:EnableMotion(false);ph:SetMass(200)
  p.preventSwitch=true;eq(P:CarrySource(p,d),false);eq(ph:IsMoveable(),false);eq(ph:GetMass(),200);p.preventSwitch=false
  hands.CanHoldObject=function() return false end;eq(P:CarrySource(p,d),false);eq(ph:IsMoveable(),false);eq(ph:GetMass(),200)
  p.fit=false;eq(P:PackGenerator(p,d),false);assert(IsValid(d.entity));eq(P.store.devices[d.id],d)
 `);
 suite('Cables commit exactly one inventory item, reject missing or pending stock and preserve it on invalid targets',`
  local P=PLUGIN;local p=admin();local g=device('generator');local t=device('terminal')
  local stock=p.cables;p.cables={};eq(P:ConnectGenerator(p,g,t.entity),false);eq(#(g.links or {}),0)
  eq(P:DeviceAction(p,{id=g.id,command='connect'}),false)
  p.cables=stock;local item=P:CableItem(p);ix.Inventory.pendingTransfers['item_'..item.id]=true
  eq(P:ConnectGenerator(p,g,t.entity),false);eq(table.Count(p.cables),16)
  ix.Inventory.pendingTransfers={};t.entity.pos=Vector(1000,0,0);eq(P:ConnectGenerator(p,g,t.entity),false);eq(table.Count(p.cables),16)
  t.entity.pos=Vector(50,0,0);assert(P:ConnectGenerator(p,g,t.entity));eq(table.Count(p.cables),15);eq(item.removed,1)
  eq(P:ConnectGenerator(p,g,t.entity),false);eq(table.Count(p.cables),15)
 `);
 suite('Two-click cable placement traces both local anchors, cancels free and rechecks inventory at final click',`
  local P=PLUGIN;local p=admin();local b=device('battery');b.entity.pos=Vector(30,0,0);b.entity.ang=Angle(0,90,0)
  local t=device('terminal');t.entity.pos=Vector(60,0,0)
  assert(P:BeginCable(p));eq(P.cableModes[p].mode,'source')
  p.trace={Hit=true,Entity=b.entity,HitPos=b.entity:LocalToWorld(Vector(4,5,6))}
  assert(P:ConnectionAction(p,{command='connect'}));eq(P.cableModes[p].mode,'connect');near(P.cableModes[p].start.y,5)
  assert(P:ConnectionAction(p,{command='cancel'}));eq(table.Count(p.cables),16);eq(#(b.links or {}),0)
  assert(P:BeginCable(p));assert(P:ConnectionAction(p,{command='connect'}))
  p.trace={Hit=true,Entity=t.entity,HitPos=t.entity:LocalToWorld(Vector(1,2,3))}
  local stock=p.cables;p.cables={};eq(P:ConnectionAction(p,{command='connect'}),false)
  p.cables=stock;assert(P:ConnectionAction(p,{command='connect'}));eq(table.Count(p.cables),15)
  near(b.links[1].start.x,4);near(b.links[1].start.y,5);near(b.links[1].point.z,3);eq(P.cableModes[p],nil)
  P:SaveData();P:LoadData();b=P.store.devices[b.id];near(b.links[1].start.y,5)
  near(b.entity:GetNW2Vector('ixGeneratorCableStart1').z,6)
 `);
 suite('Unplugging returns one cable, keeps links on full inventory, and rejects stale menu selections',`
  local P=PLUGIN;local p=admin();local b=device('battery');local t=device('terminal');local other=device('terminal')
  assert(P:ConnectGenerator(p,b,t.entity));assert(P:ConnectGenerator(p,b,other.entity));eq(table.Count(p.cables),14)
  local token=P:DeviceLinkToken(b.links[1]);p.fit=false
  eq(P:DeviceAction(p,{id=b.id,command='disconnect',index=1,expectedLink=token}),false);eq(#b.links,2);eq(table.Count(p.cables),14)
  p.fit=true;assert(P:DeviceAction(p,{id=b.id,command='disconnect',index=1,expectedLink=token}));eq(#b.links,1);eq(table.Count(p.cables),15)
  eq(P:DeviceAction(p,{id=b.id,command='disconnect',index=1,expectedLink=token}),false);eq(table.Count(p.cables),15)
  assert(P:BeginCable(p,true));p.trace={Entity=other.entity,HitPos=Vector()}
  assert(P:ConnectionAction(p,{command='connect'}));eq(#b.links,0);eq(table.Count(p.cables),16)
  eq(P:ConnectionAction(p,{command='connect'}),false);eq(table.Count(p.cables),16)
 `);
 suite('Normal mains needs no cable; blackout batteries need physical output and assigned sectors do not route power',`
  local P=PLUGIN;local p=admin();local c=circuit('Room',20,3,false,-20)
  local b=device('battery',c);b.charge=100;local t=device('terminal',c);local other=device('intercom',c)
  P:RecomputePower(1);eq(P:DevicePowered(t),true);eq(P:DevicePowered(other),true);eq(b.charge,110)
  ix.plugin.list.blackout.zones.Room.active=true;P:RecomputePower(1)
  eq(c.powered,false);eq(P:DevicePowered(t),false);eq(b.charge,110)
  assert(P:ConnectGenerator(p,b,t.entity));P:RecomputePower(1)
  eq(P:DevicePowered(t),true);eq(P:DevicePowered(other),false);eq(b.charge,105)
  ix.plugin.list.blackout.zones.Room.active=false;P:RecomputePower(1)
  eq(P:DevicePowered(other),true);eq(b.charge,115);eq(t.entity:GetNW2Bool('ixGeneratorPower'),false)
 `);
 suite('A battery wired to a powerbox restores its zone without charging from its own reserve',`
  local P=PLUGIN;local p=admin();local c=circuit('Room',20,3,true,-20)
  local b=device('battery');b.charge=45;local t=device('terminal')
  local box=connectCircuit(b,c);P:RecomputePower(1);eq(c.powered,true);eq(P:DevicePowered(t),true);eq(b.charge,25)
  P:RecomputePower(1);eq(b.charge,5);P:RecomputePower(0);eq(c.powered,false)
  eq(P:DevicePowered(t),false);eq(P:BatteryMains(b),false)
 `);
 suite('Battery direct loads and generator replenishment conserve charge and reject battery loops',`
  local P=PLUGIN;local p=admin();circuit('Dark',20,3,true,-20)
  local g=device('generator');g.running=true;g.fuel=50
  local b=device('battery');b.charge=100;local another=device('battery');local t=device('terminal')
  eq(P:ConnectGenerator(p,b,b.entity),false);eq(P:ConnectGenerator(p,b,another.entity),false);eq(P:ConnectGenerator(p,b,g.entity),false)
  assert(P:ConnectGenerator(p,g,b.entity));assert(P:ConnectGenerator(p,b,t.entity))
  P:RecomputePower(1);eq(b.charge,105);eq(P:DevicePowered(t),true)
  g.running=false;P:RecomputePower(1);eq(b.charge,100)
  b.fault=true;P:RecomputePower(1);eq(P:DevicePowered(t),false);eq(b.charge,100)
 `);
 suite('Lost endpoints keep cables recoverable and deleting a source drops exactly its remaining cables',`
  local P=PLUGIN;local p=admin();local b=device('battery');local t=device('terminal')
  assert(P:ConnectGenerator(p,b,t.entity));t.entity.valid=false;P:RecomputePower(0)
  eq(#b.links,1);eq(IsValid(b.entity:GetNW2Entity('ixGeneratorCable1')),false)
  assert(P:DeviceAction(p,{id=b.id,command='disconnect',index=1}));eq(table.Count(p.cables),16)
  local other=device('terminal');assert(P:ConnectGenerator(p,b,other.entity))
  local count=0;local original=ix.Item.Spawn;function ix.Item:Spawn(pos,ang,item) count=count+1;return original(self,pos,ang,item) end
  P:DeviceRemoved(b.entity);eq(count,1);eq(P.store.devices[b.id],nil)
  P:DeviceRemoved(b.entity);eq(count,1)
 `);
 suite('A remote legacy sector assignment cannot power an unconnected device in a blackout',`
  local P=PLUGIN;local c=circuit('Powered',20,3,false,1000);circuit('Dark',20,3,true,-20)
  local t=device('terminal',c);local b=device('battery',c);b.charge=100
  P:RecomputePower(1);eq(c.powered,true);eq(P:DevicePowered(t),false);eq(b.charge,100)
 `);
 suite('A direct generator cable charges batteries only while operational and clamps to capacity and remaining fuel',`
  local P=PLUGIN;local p=admin();local g=device('generator');local b=device('battery');circuit('Blackout',20,3,true,-20);b.charge=0
  g.running=true;g.fuel=20;g.capacity=6;P:RecomputePower(1);eq(b.charge,0)
  assert(P:ConnectGenerator(p,g,b.entity));eq(g.links[1].kind,'battery');P:RecomputePower(1);eq(b.charge,6)
  eq(b.chargeSource,'ЗАРЯД: ГЕНЕРАТОР');eq(b.entity:GetNW2Bool('ixGeneratorPower',false),false)
  g.running=false;P:RecomputePower(1);eq(b.charge,6);eq(b.chargeSource,nil)
  g.running=true;b.fault=true;P:RecomputePower(1);eq(b.charge,6)
  b.fault=false;g.capacity=60;b.charge=5997;P:RecomputePower(1);eq(b.charge,6000);eq(b.chargeSource,'ЗАРЯЖЕН')
  b.charge=0;g.fuel=.2;P:RecomputePower(1);near(b.charge,2);eq(g.running,false)
  P:RecomputePower(1);near(b.charge,2)
 `);
 suite('Charging uses leftover generator output after zone and device loads without battery feedback or bypassing isolation',`
  local P=PLUGIN;local p=admin();local c=circuit('Load',50,3,true,0);circuit('Outside',1,3,true,105)
  local g=device('generator');local b=device('battery');local terminal=device('terminal');terminal.entity.pos=Vector(110,0,0)
  g.running=true;g.fuel=100;b.charge=0;connectCircuit(g,c)
  assert(P:ConnectGenerator(p,g,terminal.entity));assert(P:ConnectGenerator(p,g,b.entity))
  P:RecomputePower(1);eq(c.powered,true);eq(b.charge,5);eq(terminal.entity:GetNW2Bool('ixGeneratorPower'),true)
  c.isolated=true;P:RecomputePower(1);eq(b.charge,5)
  c.isolated=false;g.links={g.links[3]};b.circuit=c.id;b.charge=100;b.capacity=60
  P:RecomputePower(1);eq(c.powered,false);eq(b.charge,110) -- assignment never connects a reserve
  connectCircuit(b,c);P:RecomputePower(1);eq(c.powered,true);eq(b.charge,70);eq(b.chargeSource,'ГЕНЕРАТОР / РЕЗЕРВ ПО КАБЕЛЮ')
 `);
 suite('Battery cables reject duplicate inputs, persist across restoration and stop charging after a cable breaks',`
  local P=PLUGIN;local p=admin();local g=device('generator');local second=device('generator');local b=device('battery');circuit('Blackout',20,3,true,-20);b.charge=100
  local hit=Vector(2,3,4);assert(P:ConnectGenerator(p,g,b.entity,hit));eq(P:ConnectGenerator(p,second,b.entity),false)
  g.running=true;g.fuel=80;P:RecomputePower(1);eq(b.charge,110);P:SaveData();P:LoadData()
  local restored=P.store.devices[g.id];local battery=P.store.devices[b.id]
  eq(restored.links[1].kind,'battery');eq(restored.links[1].point.z,4);eq(battery.charge,110)
  eq(P:ResolvePowerTarget(restored.links[1]),battery.entity);eq(restored.running,false)
  restored.running=true;battery.entity.pos=Vector(2000,0,0);P:RecomputePower(1)
  eq(#restored.links,1);eq(P:CableValid(restored,restored.links[1]),false);eq(battery.charge,120) -- now outside the blackout, charges from mains
 `);
 suite('Portable battery placement and pickup preserve charge and fault, remove legacy circuit assignment, and avoid duplication or full-inventory loss',`
  local P=PLUGIN;local c=circuit('Assigned');local p=admin();p.admin=false;p.card=nil
  local item={id=78,uniqueID='facility_battery',removed=0,GetOwner=function() return p end,GetEntity=function() end,
   GetData=function(_,k,default) local t={charge=1234,circuit=c.id,fault=true,capacity=45};if t[k]~=nil then return t[k] end;return default end}
  ix.Item={instances={[78]=item}};function item:Remove() self.removed=self.removed+1;ix.Item.instances[self.id]=nil end
  assert(P:BeginGeneratorPlacement(p,item));eq(P.cableModes[p].mode,'place_battery')
  p.trace={Hit=true,HitWorld=true,HitSky=false,HitNormal=Vector(0,0,1),HitPos=Vector(50,0,0)}
  util.TraceLine=function(t) if t.endpos.z<t.start.z then return {Hit=true,HitWorld=true,HitNormal=Vector(0,0,1)} end;return {Hit=false} end
  util.TraceHull=function() return {Hit=false} end
  assert(P:ConnectionAction(p,{command='place',yaw=30}));eq(item.removed,1);eq(P:PlacePortableGenerator(p,30),false)
  local _,d=next(P.store.devices);eq(d.kind,'battery');eq(d.charge,1234);eq(d.circuit,0);eq(d.capacity,45);eq(d.fault,true)
  eq(d.entity:GetModel(),'models/items/car_battery01.mdl')
  local fit=false;function p:GetInventory() return {Sync=function() end,AddItem=function() return fit end} end
  local created={};function ix.Item:Instance(id,data) local it={id=id,data=data,removed=0,Save=function() end};function it:Remove() self.removed=self.removed+1 end;created[#created+1]=it;return it end
  eq(P:PackGenerator(p,d),false);eq(created[1].removed,1);assert(IsValid(d.entity))
  local g=device('generator');g.links={{kind='battery',id=d.id}};eq(P:PackGenerator(p,d),false);eq(#created,1)
  g.links={};fit=true;assert(P:DeviceAction(p,{id=d.id,command='pack'}))
  eq(created[2].id,'facility_battery');eq(created[2].data.charge,1234);eq(created[2].data.circuit,0);eq(created[2].data.fault,true)
  eq(P:DeviceAction(p,{id=d.id,command='pack'}),false);eq(#created,2)
 `);
 suite('Compound reserve areas restore both wings without restoring the empty corner',`
  local p=PLUGIN;local b=ix.plugin.list.blackout
  local outer={min=Vector(),max=Vector(100,100,100),active=true}
  local room={min=Vector(),max=Vector(100,100,100),active=true,volumes={{min=Vector(),max=Vector(100,40,100)},{min=Vector(),max=Vector(40,100,100)}}}
  b.zones={All=outer,L=room};p.store.circuits={R={zone='L',powered=true}}
  local pieces=p:FacilityBlackoutVolumes(b.zones,{outer,room})
  local function dark(point) for _,piece in ipairs(pieces) do if point:WithinAABox(piece.min,piece.max) then return true end end;return false end
  eq(dark(Vector(80,20,20)),false);eq(dark(Vector(20,80,20)),false);eq(dark(Vector(80,80,20)),true)
  room.remoteIsolation=true;pieces=p:FacilityBlackoutVolumes(b.zones,{outer,room})
  eq(dark(Vector(80,20,20)),true);eq(dark(Vector(20,80,20)),true)
 `);
 suite('Powered cutouts retain their source-zone fade bounds and per-zone darkness',`
  local P=PLUGIN;local c=circuit('Powered');c.powered=true
  local cut=ix.plugin.list.blackout.zones.Powered;cut.min=Vector(20,20,20);cut.max=Vector(40,40,40)
  local outer={min=Vector(),max=Vector(100,100,100),active=true,darkness=32,softness=55}
  local fragments=P:FacilityBlackoutVolumes({Outer=outer,Powered=cut},{outer})
  eq(#fragments,6)
  for _,b in ipairs(fragments) do eq(b.darkness,32);eq(b.softness,55);eq(b.fadeMin,outer.min);eq(b.fadeMax,outer.max) end
 `);
 suite('Portable battery charge, fault, capacity and sector survive the actual inventory serializer',`
  ix.transmit={owner=1};ITEM={vars={},vars_id={},data={charge=2345,fault=true,circuit=7,capacity=45},functions={}}
  function ITEM:AddData(key,value) self.vars[key]=value;self.vars_id[#self.vars_id+1]=key end
  function ITEM:GetID() return 34 end
  ${normalize(fs.readFileSync('ixhl2rp/plugins/facility_utilities/items/sh_facility_battery.lua','utf8'))}
  ${normalize(fs.readFileSync('helix/gamemode/game/items/sh_item.class.lua','utf8').split('\tfunction ITEM:SaveData()')[1].split('\n\tfunction ITEM:Save()')[0].replace(/^/,'function ITEM:SaveData()'))}
  local saved;mysql={Update=function() return {Update=function(_,key,value) if key=='data' then saved=util.JSONToTable(value) end end,Where=function() end,Execute=function() end} end}
  ITEM:SaveData();eq(saved.charge,2345);eq(saved.fault,true);eq(saved.circuit,7);eq(saved.capacity,45);eq(ITEM.stackable,false)
 `);
 suite('Repair has five progressively faster and narrower stages; misses preserve difficulty and only the fifth spends parts',`
  local P,F=PLUGIN,ix.Facility;local p=admin();local d=device('generator');d.fault=true
  giveItem(p,'tool_screw');local part=giveItem(p,'facility_spares');assert(P:RepairHere(p,d))
  local periods={7.2,6.3,5.4,4.5,3.8};local widths={.20,.18,.16,.145,.13}
  for stage=1,5 do
   local w=P.work[p];local r=w.repair;eq(r.stage,stage);near(r.period,periods[stage]);near(r.width,widths[stage])
   assert(d.fault);eq(part.removed,0);eq(P:CompleteWork(p,w),false)
   -- Just outside this stage's allowed band; stage five would pass using the old broad band.
   local offset=r.width*.5+.025;clock=r.started+(r.target+offset)*r.period*.5
   P:RepairInput(p,r.token,r.round,true);eq(r.stage,stage);near(r.width,widths[stage]);near(r.period,periods[stage])
   clock=r.started+r.target*r.period*.5;P:RepairInput(p,r.token,r.round,true)
   if stage<5 then eq(r.stage,stage+1);assert(r.period<periods[stage]);assert(r.width<widths[stage]) end
  end
  eq(P.work[p],nil);eq(d.fault,false);eq(part.removed,1)
 `);
 const fuseboxSetup=`
  local B=ix.plugin.list.blackout
  do local PLUGIN=B
   ${normalize(fs.readFileSync('ixhl2rp/plugins/blackout/sv_plugin.lua','utf8'))}
  end
  B.repairSkill=3;B.breakSkill=4;B.repairXP=40;B.breakXP=30;B.shockChance=0
  B.RecomputeZones=function(s) s.recomputes=(s.recomputes or 0)+1 end
  B.SaveFuseboxes=function() end;B.GetOwningZone=function(s) return s.testZone end
  local boxID=3000
  function powerbox()
   boxID=boxID+1;local e=entity(boxID,'models/props_c17/powerbox.mdl',Vector(60,0,0));e.class='ix_blackout_fusebox';e.broken=true;e.open=true
   function e:GetDoorOpen() return self.open end;function e:DoorPitch() return self.open and -140 or 0 end
   function e:InteractionTarget(p) return self.open and (p.aimPart or 'panel') or 'door' end
   function e:StartSparks() self.sparks=true end;function e:StopSparks() self.sparks=false end
   B.fuseboxes[#B.fuseboxes+1]=e;return e
  end
  function technician(id)
   local p=admin(1);p.admin=false;p.card=nil;p.skill=4;p.xp=0
   function p.character:GetSkillModified() return p.skill end
   function p.character:UpdateSkillProgress(_,xp) p.xp=p.xp+xp end
   function p:DoStaredAction() error('Old timer must never run') end
   giveItem(p,id or 'tool_screw');return p
  end
 `;
 suite('Powerbox repair and sabotage require five scored contacts, preserve the screwdriver, and award XP once',fuseboxSetup+`
  for _,id in ipairs({'tool_screw'}) do
   local p=technician(id);local e=powerbox();local tool=p.items[id]
   assert(B:TryRepair(p,e));eq(e.ixRepairing,p);eq(e.sparks,true)
   local w=PLUGIN.work[p];local r=w.repair
   eq(PLUGIN:CompleteWork(p,w),false);eq(e:GetBroken(),true)
   PLUGIN:RepairInput(p,r.token+1,r.round,true);eq(r.stage,1)
   solveRepair(p);eq(e:GetBroken(),false);eq(e.ixRepairing,nil);eq(e.sparks,false);eq(p.xp,40);eq(tool.removed,0)
   PLUGIN:RepairInput(p,r.token,r.round,true);eq(p.xp,40);eq(PLUGIN:CompleteWork(p,w),false)
   assert(B:TryBreakScrewdriver(p,e));eq(PLUGIN.work[p].sabotage,true)
   solveRepair(p);eq(e:GetBroken(),true);eq(p.xp,70);eq(tool.removed,0);eq(e.ixRepairing,nil)
  end
 `);
 suite('Powerbox calibration cancels and releases occupancy on lost tools, skill, character, proximity, door, target or life',fuseboxSetup+`
  local changes={function(p,e) p.items.tool_screw=nil end,function(p,e) p.skill=2 end,
   function(p,e) p.character.id=p.character.id+100 end,function(p,e) p.pos=Vector(800,0,0) end,
   function(p,e) e.open=false end,function(p,e) e.valid=false end,function(p,e) e.broken=false end,
   function(p,e) p.dead=true end}
  for index,change in ipairs(changes) do
   local p=technician();local e=powerbox();assert(B:TryRepair(p,e));local r=PLUGIN.work[p].repair
   change(p,e);PLUGIN:TickJobs();assert(PLUGIN.work[p]==nil,'Cancellation scenario '..index);eq(p.xp,0)
   if IsValid(e) then eq(e.ixRepairing,nil);eq(e.sparks,false) end
   PLUGIN:RepairInput(p,r.token,r.round,true);eq(p.xp,0)
  end
 `);
 suite('Powerbox calibration preserves skill gates, rejects closed/misaimed/busy targets, times out, and releases maintenance jobs',fuseboxSetup+`
  local p=technician();local q=technician();local e=powerbox()
  e.open=false;eq(B:TryRepair(p,e),false);e.open=true
  p.aimPart='door';eq(B:TryRepair(p,e),false);p.aimPart=nil
  p.skill=2;B:TryRepair(p,e);eq(PLUGIN.work[p],nil);p.skill=3
  assert(B:TryRepair(p,e));B:TryRepair(q,e);eq(PLUGIN.work[q],nil)
  clock=PLUGIN.work[p].repair.expires+1;PLUGIN:TickJobs();eq(PLUGIN.work[p],nil);eq(e:GetBroken(),true);eq(e.ixRepairing,nil)
  PLUGIN:DiscoverJobs();local j;for _,v in pairs(PLUGIN.store.jobs) do if v.target==e:EntIndex() then j=v end end
  p.card={clearanceLevel=1,department='security'}
  assert(PLUGIN:JobAction(p,{id=j.id,command='claim'}));assert(PLUGIN:BeginWork(p,j));local r=PLUGIN.work[p].repair
  PLUGIN:RepairInput(p,r.token,r.round,false);eq(j.status,'open');eq(j.owner,nil);eq(e.ixRepairing,nil)
  assert(PLUGIN:JobAction(p,{id=j.id,command='claim'}));assert(PLUGIN:BeginWork(p,j));solveRepair(p);eq(j.status,'closed')
  B:TryBreakScrewdriver(p,e);eq(PLUGIN.work[p],nil) -- sabotage still needs level 4
  p.skill=4;assert(B:TryBreakScrewdriver(p,e));PLUGIN:ReleaseWorker(p,p.character);eq(PLUGIN.work[p],nil);eq(e.ixRepairing,nil)
 `);
 suite('Cable click stores the server-traced local point, follows rotated props, networks and reloads the same anchor',`
  local P=PLUGIN;local p=admin();local g=device('generator');local d=device('terminal');local target=d.entity
  target.pos=Vector(50,0,0);target.ang=Angle(0,90,0)
  local localPoint=Vector(5,11,23);local worldPoint=target:LocalToWorld(localPoint)
  p.trace={Hit=true,Entity=target,HitPos=worldPoint};P:SetCableMode(p,'connect',g.id)
  assert(P:ConnectionAction(p,{command='connect',point=Vector(999,999,999)})) -- ignore client-supplied coordinates
  local link=g.links[1];near(link.point.x,5);near(link.point.y,11);near(link.point.z,23)
  near(g.entity:GetNW2Vector('ixGeneratorCablePoint1').z,23)
  target.pos=Vector(65,0,0);target.ang=Angle(0,180,0);assert(P:CableValid(g,link))
  near(target:LocalToWorld(link.point).x,60);near(target:LocalToWorld(link.point).y,-11)
  P:SaveData();P:LoadData();g=P.store.devices[g.id];near(g.links[1].point.x,5);near(g.links[1].point.y,11);near(g.links[1].point.z,23)
  assert(P:DeviceAction(p,{id=g.id,command='disconnect',index=1}));P:RecomputePower(0);eq(IsValid(g.entity:GetNW2Entity('ixGeneratorCable1')),false)
 `);
 suite('Hanging cable preserves both endpoints, sags below its chord and rests above traced floors',`
  local a,b=Vector(0,0,20),Vector(300,0,60)
  local points=ix.Facility.CablePoints(a,b);eq(points[1],a);eq(points[#points],b);assert(#points<=21)
  assert(points[math.ceil(#points/2)].z<0)
  local traces=0;points=ix.Facility.CablePoints(a,b,function(start,finish)
   traces=traces+1;if finish.z<2 then return {Hit=true,HitPos=Vector(finish.x,finish.y,2),HitNormal=Vector(0,0,1)} end
   return {Hit=false}
  end)
  for _,v in ipairs(points) do assert(v.z>=2) end;eq(traces,#points-2)
  local same=ix.Facility.CablePoints(a,a);for _,v in ipairs(same) do near(v:DistToSqr(a),0) end
 `);
 suite('Both screwdriver items appear in equipment requirements, complete repairs and remain required throughout',`
  local P=PLUGIN;local p=admin(4)
  for _,id in ipairs({'tool_screw'}) do
   local d=device('generator');d.fault=true
   local tool=giveItem(p,id);local part=giveItem(p,'facility_spares')
   eq(P:DeviceSnapshot(p,d).device.hasTool,true)
   assert(P:RepairHere(p,d));local w=P.work[p];assert(P:WorkValid(p,w))
   p.items[id]=nil;eq(P:DeviceSnapshot(p,d).device.hasTool,false);eq(P:WorkValid(p,w),false)
   p.items[id]=tool;assert(P:WorkValid(p,w));solveRepair(p)
   eq(d.fault,false);eq(part.removed,1);eq(tool.removed,0)
   p.items[id]=nil
  end
 `);
 suite('Facility setup rejects non-admins, remote placement, invalid sectors and malformed configuration',`
  local P=PLUGIN;local p=admin();p.admin=false
  eq(P:AdminAction(p,{command='circuit',name='West',zone='West'}),false)
  p.admin=true;eq(P:AdminAction(p,{command='circuit',name='West',zone='missing'}),false)
  local c=circuit('West');eq(P:AdminAction(p,{command='circuit',name='Again',zone='West'}),false)
  eq(P:AdminAction(p,{command='circuitConfig',id=c.id,name='West',load=0/0,priority=1}),false)
  p.trace={Hit=true,HitPos=Vector(999,0,0),HitNormal=Vector(0,0,1)};eq(P:Place(p,'speaker'),false)
  p.trace.HitPos=Vector(30,0,0);assert(P:Place(p,'speaker'));eq(table.Count(P.store.devices),1)
  local d=device('generator',c);eq(P:AdminAction(p,{command='deviceConfig',id=d.id,name='G',circuit=999,radius=300,capacity=60,level=1,department=''}),false)
 `);
 suite('Facility backup prioritizes whole circuits, drains fuel and batteries, sheds load and respects isolation',`
  local P=PLUGIN;local high=circuit('Containment',40,1,true);local low=circuit('Offices',40,5,true)
  local g=device('generator');g.capacity=50;g.fuel=2;g.running=true
  connectCircuit(g,high);connectCircuit(g,low)
  P:RecomputePower(1);eq(high.powered,true);eq(low.powered,false);near(g.fuel,1)
  P:RecomputePower(1);eq(g.running,false);P:RecomputePower(0);eq(high.powered,false)
  local b=device('battery',high);b.capacity=50;b.charge=40;connectCircuit(b,high);b.entity.pos=Vector(100,0,0)
  ix.plugin.list.blackout.zones.BatteryRoom={min=Vector(0,0,0),max=Vector(101,101,101),active=true}
  P:RecomputePower(1);eq(high.powered,false);near(b.charge,0);P:RecomputePower(0);eq(high.powered,false) -- exhaustion revokes reserve in the same tick
  g.fuel=100;g.running=true;high.isolated=true;P:RecomputePower(0);eq(high.powered,false);eq(low.powered,true)
  high.isolated=false;ix.plugin.list.blackout.zones.Containment.remoteIsolation=true;P:RecomputePower(0);eq(high.powered,false)
  ix.plugin.list.blackout.zones.Containment.remoteIsolation=nil;ix.plugin.list.blackout.zones.Containment.active=false
  P:RecomputePower(1);eq(high.source,'СЕТЬ');eq(b.charge,0) -- battery's own room is still blacked out
  ix.plugin.list.blackout.zones.BatteryRoom.active=false;P:RecomputePower(1);assert(b.charge>0)
 `);
 suite('Facility backed-up subzones cut holes in blackout masks while safety isolations remain dark',`
  local P=PLUGIN;local b=ix.plugin.list.blackout;local c=circuit('Room',10,1,true,20)
  b.zones.Room.max=Vector(40,40,40);b.zones.Room.min=Vector(20,20,20)
  b.zones.All={min=Vector(0,0,0),max=Vector(100,100,100),active=true}
  local g=device('generator');g.fuel=100;g.running=true;connectCircuit(g,c);P:RecomputePower(0);eq(c.powered,true)
  local function inside(pos,boxes) for _,box in ipairs(boxes) do if pos:WithinAABox(box.min,box.max) then return true end end;return false end
  local boxes=P:FacilityBlackoutVolumes(b.zones,{b.zones.All,b.zones.Room})
  eq(inside(Vector(30,30,30),boxes),false);eq(inside(Vector(10,10,10),boxes),true)
  eq(P:FacilityPowerAt(Vector(30,30,30)),false)
  b.zones.All.remoteIsolation=true;P:RecomputePower(0);eq(c.powered,false)
  boxes=P:FacilityBlackoutVolumes(b.zones,{b.zones.All});eq(inside(Vector(30,30,30),boxes),true)
 `);
 suite('Generator supplies only physically linked zones; independent generators never pool their outputs',`
  local P=PLUGIN;local a=circuit('A',40,1,true);local b=circuit('B',40,2,true)
  local g=device('generator');g.running=true;g.fuel=90;g.capacity=30
  local other=device('generator');other.running=true;other.fuel=90;other.capacity=30
  P:RecomputePower(0);eq(a.powered,false);eq(b.powered,false)
  connectCircuit(g,a);connectCircuit(other,b);P:RecomputePower(0);eq(a.powered,false);eq(b.powered,false)
  g.capacity=60;P:RecomputePower(0);eq(a.powered,true);eq(b.powered,false)
  g.links={};P:RecomputePower(0);eq(a.powered,false)
  local battery=device('battery');P:RecomputePower(0);eq(a.powered,false)
  battery.circuit=a.id;battery.capacity=50;P:RecomputePower(1);eq(a.powered,false)
  connectCircuit(battery,a);ix.plugin.list.blackout.zones.BatteryRoom={min=Vector(-10,-10,-10),max=Vector(500,500,500),active=true}
  P:RecomputePower(1);eq(a.powered,true);eq(b.powered,false);eq(battery.charge,5960)
 `);
 suite('Direct generator cables power only their endpoint and cannot override isolation or equipment faults',`
  local P=PLUGIN;local c=circuit('Room',20,1,true,-20);local g=device('generator');g.fuel=90;g.running=true
  local a=device('intercom',c);local b=device('intercom',c)
  g.links={{kind='device',id=a.id,name=a.name}};P:RecomputePower(0)
  eq(c.powered,false);eq(P:DevicePowered(a),true);eq(P:DevicePowered(b),false);eq(a.entity:GetNW2Bool('ixGeneratorPower'),true)
  a.fault=true;eq(P:DevicePowered(a),false);a.fault=false
  c.isolated=true;P:RecomputePower(0);eq(P:DevicePowered(a),false)
  c.isolated=false;ix.plugin.list.blackout.zones.Room.remoteIsolation=true;P:RecomputePower(0);eq(P:DevicePowered(a),false)
  ix.plugin.list.blackout.zones.Room.remoteIsolation=nil;P:RecomputePower(0);eq(P:DevicePowered(a),true)
  g.running=false;P:RecomputePower(0);eq(P:DevicePowered(a),false)
  g.running=true;P:RecomputePower(0);a.entity.pos=Vector(700,0,0);P:RecomputePower(0);eq(#g.links,1);eq(P:CableValid(g,g.links[1]),false);eq(a.entity:GetNW2Bool('ixGeneratorPower'),false)
 `);
 suite('Cable connection uses nearby validated endpoints and rejects duplicates, walls and unauthorized controls',`
  local P=PLUGIN;local p=admin(1);p.admin=false;local g=device('generator');g.owner=p.character.id
  local a=device('terminal');a.entity.pos=Vector(40,0,0)
  assert(P:ConnectGenerator(p,g,a.entity));eq(#g.links,1);eq(P:ConnectGenerator(p,g,a.entity),false)
  local q=admin(1);q.admin=false;eq(P:DeviceAction(q,{id=g.id,command='disconnect',index=1}),false);eq(#g.links,1)
  assert(P:DeviceAction(p,{id=g.id,command='disconnect',index=1}));eq(#g.links,0)
  a.entity.pos=Vector(1000,0,0);eq(P:ConnectGenerator(p,g,a.entity),false);a.entity.pos=Vector(40,0,0)
  local trace=util.TraceLine;util.TraceLine=function() return {Hit=true} end;eq(P:ConnectGenerator(p,g,a.entity),false);util.TraceLine=trace
  P:SetCableMode(p,'connect',g.id);p.character.id=p.character.id+1;eq(P:ConnectionAction(p,{command='connect'}),false)
  eq(next(P.cableModes),nil);eq(P:ConnectGenerator(p,g,g.entity),false)
 `);
 suite('Connecting a fusebox creates only its circuit and does not repair it; connections survive reload',`
  local P=PLUGIN;local p=admin();local b=ix.plugin.list.blackout
  b.zones.Fuse={min=Vector(-50,-50,-50),max=Vector(200,200,200),active=true}
  function b:GetOwningZone() return self.zones.Fuse end
  local box=entity(1200,'fuse',Vector(50,0,0));box.class='ix_blackout_fusebox';box.broken=true
  local g=device('generator');g.running=true;g.fuel=123
  assert(P:ConnectGenerator(p,g,box));eq(table.Count(P.store.circuits),1);eq(box.broken,true)
  local _,c=next(P.store.circuits);eq(c.powered,true)
  P:SaveData();P:LoadData();g=P.store.devices[g.id];eq(g.running,false);eq(g.fuel,123);eq(#g.links,1)
  g.running=true;P:RecomputePower(0);eq(P.store.circuits[c.id].powered,true)
  box.valid=false;clock=clock+31;P:RecomputePower(0);eq(#g.links,1);eq(P:CableValid(g,g.links[1]),false);eq(P.store.circuits[c.id].powered,false)
 `);
 suite('Generator cables migrate only the old registered fusebox model, preserving position and live deletion identity',`
  local box=entity(2100,'models/props_c17/powerbox.mdl',Vector(50,0,0));box.class='ix_blackout_fusebox';box.mapid=-1
  local link={kind='zone',zone='Lab',binding={class='ix_blackout_fusebox',model='models/props_se/propper/power_box_2.mdl',mapid=-1,pos=Vector(50,0,0)}}
  eq(PLUGIN:ResolvePowerTarget(link),box);eq(link.binding.model,box.model);eq(PLUGIN.dirty,true)
  box.valid=false;local replacement=entity(2101,box.model,Vector(50,0,0));replacement.class=box.class
  eq(PLUGIN:ResolvePowerTarget(link),nil)
  local other={kind='entity',binding={class='prop_physics',model='models/props_se/propper/power_box_2.mdl',mapid=-1,pos=Vector(50,0,0)}}
  eq(PLUGIN:ResolvePowerTarget(other),nil);eq(other.binding.model,'models/props_se/propper/power_box_2.mdl')
 `);
 suite('Portable placement consumes one owned item only on valid floor and packing cannot duplicate or lose it',`
  local P=PLUGIN;local p=admin();p.admin=false;p.card=nil
  local item={id=77,uniqueID='facility_generator',removed=0,GetOwner=function() return p end,GetEntity=function() end,GetData=function(_,k,default) if k=='fuel' then return 160 end;return default end}
  ix.Item={instances={[77]=item}};function item:Remove() self.removed=self.removed+1;ix.Item.instances[self.id]=nil end
  assert(P:BeginGeneratorPlacement(p,item));p.trace={Hit=true,HitWorld=true,HitSky=false,HitNormal=Vector(0,0,1),HitPos=Vector(80,0,0)}
  local trace=util.TraceLine;util.TraceLine=function(t) if t.endpos.z<t.start.z then return {Hit=true,HitWorld=true,HitNormal=Vector(0,0,1)} end;return {Hit=false} end
  util.TraceHull=function() return {Hit=true} end
  eq(P:PlacePortableGenerator(p,0),false);eq(item.removed,0)
  util.TraceHull=function() return {Hit=false} end
  assert(P:PlacePortableGenerator(p,0));eq(item.removed,1);eq(P:PlacePortableGenerator(p,0),false)
  local _,d=next(P.store.devices);eq(d.portable,true);eq(d.fuel,160);eq(d.owner,p.character.id)
  local fit=false;local inv={Sync=function() end,AddItem=function() return fit end};function p:GetInventory() return inv end
  local created={};function ix.Item:Instance(_,data) local it={data=data,removed=0,Save=function() end};function it:Remove() self.removed=self.removed+1 end;created[#created+1]=it;return it end
  util.TraceLine=trace
  eq(P:PackGenerator(p,d),false);eq(created[1].removed,1);assert(IsValid(d.entity))
  fit=true;assert(P:PackGenerator(p,d));eq(created[2].data.fuel,160);eq(P.store.devices[d.id],nil)
  eq(P:DeviceAction(p,{id=d.id,command='pack'}),false);eq(#created,2)
 `);
 suite('Generator pickup fuel and fault data survive the real item SaveData serializer',`
  ix.transmit={owner=1};ITEM={vars={},vars_id={},data={fuel=275,fault=true},functions={}}
  function ITEM:AddData(key,value) self.vars[key]=value;self.vars_id[#self.vars_id+1]=key end
  function ITEM:GetID() return 33 end
  ${normalize(fs.readFileSync('ixhl2rp/plugins/facility_utilities/items/sh_facility_generator.lua','utf8'))}
  ${normalize(fs.readFileSync('helix/gamemode/game/items/sh_item.class.lua','utf8').split('\tfunction ITEM:SaveData()')[1].split('\n\tfunction ITEM:Save()')[0].replace(/^/,'function ITEM:SaveData()'))}
  local saved;mysql={Update=function() return {Update=function(_,key,value) if key=='data' then saved=util.JSONToTable(value) end end,Where=function() end,Execute=function() end} end}
  ITEM:SaveData();eq(saved.fuel,275);eq(saved.fault,true);eq(ITEM.stackable,false)
 `);
 suite('CCTV, TV and blackout entity checks accept direct generator power without enabling an off switch',`
  local e=entity(1900,'camera',Vector());e:SetNW2Int('ixCCTVID',7)
  ix.plugin.list.blackout.IsPosBlackedOut=function() return true end
  local camera={id=7,on=true,entity=e};eq(ix.CCTV.Powered(camera),false)
  e:SetNW2Bool('ixGeneratorPower',true);eq(ix.CCTV.Powered(camera),true)
  camera.on=false;eq(ix.CCTV.Powered(camera),false)
  do local P={};local T={Transform=function() return Vector() end}
   ${normalize(fs.readFileSync('ixhl2rp/plugins/tv_screen/cl_plugin.lua','utf8').split('function P:ScreenPowered(s)')[1].split('function P:DisplayScreen')[0].replace(/^/,'function P:ScreenPowered(s)'))}
   eq(P:ScreenPowered({entity=e,on=true}),true);eq(P:ScreenPowered({entity=e,on=false}),false)
   e:SetNW2Bool('ixGeneratorPower',false);eq(P:ScreenPowered({entity=e,on=true}),false)
  end
  do local PLUGIN={IsPoweredClass=function() return true end,IsPosBlackedOut=function() return true end}
   ${normalize(fs.readFileSync('ixhl2rp/plugins/blackout/sh_plugin.lua','utf8').split('function PLUGIN:ElectronicsOverride(pos)')[1].split('ix.lang.AddTable')[0].replace(/^/,'function PLUGIN:ElectronicsOverride(pos)'))}
   eq(PLUGIN:IsEntityBlackedOut(e),true);e:SetNW2Bool('ixGeneratorPower',true);eq(PLUGIN:IsEntityBlackedOut(e),false)
  end
 `);
 suite('Facility door commands enforce department, level, power and two distinct live operators',`
  local P=PLUGIN;local c=circuit('Doors',20,3,false,-20);P:RecomputePower(0);local d=door(c,3,true)
  local p=admin(2);p.admin=false;local s=session(p)
  eq(P:DoorAction(p,s,{id=d.id,command='unlock'}),false);p.card.clearanceLevel=3;p.card.department='science'
  eq(P:DoorAction(p,s,{id=d.id,command='unlock'}),false);p.card.department='security'
  assert(P:DoorAction(p,s,{id=d.id,command='unlock'}));eq(#d.entity.inputs,0)
  eq(P:DoorAction(p,s,{id=d.id,command='unlock'}),false)
  local q=admin(3);q.admin=false;local t=session(q);assert(P:DoorAction(q,t,{id=d.id,command='unlock'}));eq(#d.entity.inputs,1)
  P:DoorAction(p,s,{id=d.id,command='open'});p.pos=Vector(1000,0,0)
  eq(P:DoorAction(q,t,{id=d.id,command='open'}),false);eq(#d.entity.inputs,1)
  c.isolated=true;P:RecomputePower(0);eq(P:DoorAction(q,t,{id=d.id,command='close'}),false)
 `);
 suite('Facility lockdown blocks ordinary door inputs and restores each previous lock state',`
  local P=PLUGIN;local c=circuit('Doors');P:RecomputePower(0);local a=door(c);local b=door(c);b.entity.state.m_bLocked=true
  local p=admin(3);p.admin=false;local s=session(p)
  assert(P:LockSector(p,s,{id=c.id}));eq(c.lockdown,true);eq(a.entity.state.m_bLocked,true)
  eq(P:AcceptInput(a.entity,'Unlock'),true);eq(P:AcceptInput(a.entity,'Open'),true)
  eq(P:DoorAction(p,s,{id=a.id,command='unlock'}),false)
  assert(P:LockSector(p,s,{id=c.id}));eq(c.lockdown,false);eq(a.entity.state.m_bLocked,false);eq(b.entity.state.m_bLocked,true)
 `);
 suite('Facility voice reaches only chosen sector speakers and terminates on power loss, expiry or leaving the console',`
  local P=PLUGIN;local c=circuit('PA');P:RecomputePower(0);local speaker=device('speaker',c);speaker.entity.pos=Vector(1000,0,0)
  local p=admin(2);p.admin=false;local s=session(p);local listener=admin();listener.pos=Vector(1100,0,0)
  assert(P:CommsAction(p,s,{command='broadcast',id=c.id}))
  local hear,spatial,label,gain,effect=P:VoiceRoute(listener,p);eq(hear,true);eq(spatial,false);assert(gain>0 and gain<1);eq(effect,'radio')
  listener.pos=Vector(1400,0,0);eq(P:VoiceRoute(listener,p),nil)
  listener.pos=Vector(1100,0,0);c.isolated=true;P:RecomputePower(0);eq(P:VoiceRoute(listener,p),nil)
  c.isolated=false;P:RecomputePower(0);p.pos=Vector(500,0,0);clock=clock+.2;eq(P:VoiceRoute(listener,p),nil)
  p.pos=Vector();assert(P:CommsAction(p,s,{command='broadcast',id=c.id}));clock=clock+121;eq(P:VoiceRoute(listener,p),nil)
 `);
 suite('Facility intercom calls reject takeover and close when a participant leaves',`
  local P=PLUGIN;local c=circuit('Calls');P:RecomputePower(0);local d=device('intercom',c)
  local caller=admin(0);caller.admin=false;caller.card=nil;local operator=admin(2);operator.admin=false;operator.pos=Vector(1000,0,0);local s=session(operator)
  assert(P:CallIntercom(caller,d));local thief=admin();eq(P:CallIntercom(thief,d),false)
  assert(P:CommsAction(operator,s,{command='accept',id=d.id}));eq(P:VoiceRoute(operator,caller),true)
  eq(P:VoiceRoute(caller,operator),true)
  eq(select(5,P:VoiceRoute(operator,caller)),'radio');eq(select(5,P:VoiceRoute(caller,operator)),'radio')
  local other=admin(2);other.admin=false;eq(P:CommsAction(other,session(other),{command='accept',id=d.id}),false)
  caller.pos=Vector(500,0,0);clock=clock+.2;P:PruneComms();eq(P.calls[d.id],nil)
 `);
 suite('Facility jobs require ownership, physical presence, tools and parts; cancellation consumes nothing and completion only once',`
  local P=PLUGIN;local d=device('generator');d.fault=true;P:DiscoverJobs();local j=next(P.store.jobs);j=P.store.jobs[j]
  local p=admin(1);p.admin=false;local q=admin(1);q.admin=false
  assert(P:JobAction(p,{id=j.id,command='claim'}));eq(P:JobAction(q,{id=j.id,command='claim'}),false)
  eq(P:BeginWork(p,j),false);giveItem(p,'tool_screw');local part=giveItem(p,'facility_spares')
  p.trace={Entity=d.entity};assert(P:BeginWork(p,j));p.pos=Vector(500,0,0);clock=clock+30;P:TickJobs();eq(part.removed,0);eq(d.fault,true)
  p.pos=Vector();assert(P:JobAction(p,{id=j.id,command='claim'}));assert(P:BeginWork(p,j));clock=clock+30;P:TickJobs();eq(part.removed,0);eq(d.fault,true)
  -- A completed timer does not fix anything; all five contacts must be pressed.
  local r=P.work[p].repair;r.started=clock+.7;solveRepair(p);eq(part.removed,1);eq(d.fault,false);eq(j.status,'closed')
  P:TickJobs();eq(part.removed,1);eq(P:JobAction(p,{id=j.id,command='claim'}),false)
 `);
 suite('Facility workpoints accept cardless workers while fuel requires a local stopped generator and a real canister',`
  local P=PLUGIN;local p=admin();p.admin=false;p.card=nil;local d=device('workpoint');d.fault=true;P:DiscoverJobs();local _,j=next(P.store.jobs)
  assert(P:JobAction(p,{id=j.id,command='claim'}));p.trace={Entity=d.entity};assert(P:BeginWork(p,j));clock=clock+16;P:TickJobs();eq(j.status,'closed')
  local g=device('generator');eq(P:Refuel(p,g.id),false);local fuel=giveItem(p,'facility_fuel')
  g.running=true;eq(P:Refuel(p,g.id),false);eq(fuel.removed,0);g.running=false
  assert(P:Refuel(p,g.id));near(g.fuel,300);eq(fuel.removed,1);eq(P:Refuel(p,g.id),false)
  local snap=P:Snapshot(p,'jobs');eq(#snap.devices,1);eq(#snap.doors,0);eq(#snap.circuits,0)
 `);
 suite('Facility persistence restores devices, circuits and door links but clears live sessions and stale fusebox IDs',`
  local P=PLUGIN;local c=circuit('Restore');local d=device('battery',c);d.charge=1234;local doorRecord=door(c)
  local j=P:NewJob('device',d.id,'Fix battery',1);j.owner=1;j.status='assigned'
  local fuse=P:NewJob('fusebox',999,'Fuse',1)
  P:SaveData();P:LoadData();P:RestoreBindings()
  near(P.store.devices[d.id].charge,1234);eq(P.store.devices[d.id].circuit,0)
  eq(P.store.jobs[j.id].status,'open');eq(P.store.jobs[fuse.id].status,'closed');eq(P.store.doors[doorRecord.id].entity,doorRecord.entity)
  eq(next(P.calls),nil);eq(next(P.broadcasts),nil)
 `);
 suite('Facility CCTV preview grants only the selected linked camera and expires with terminal access',`
  local P=PLUGIN;local p=admin(2);p.admin=false;local s=session(p);local d=door();d.camera=17
  ix.plugin.list.cctv={devices={[17]={kind='camera'}}}
  assert(P:DoorAction(p,s,{command='camera',id=d.id}));eq(P:CameraPreviewAllowed(p,17),true);eq(P:CameraPreviewAllowed(p,18),false)
  p.card.clearanceLevel=0;eq(P:CameraPreviewAllowed(p,17),false);p.card.clearanceLevel=2
  clock=clock+31;eq(P:CameraPreviewAllowed(p,17),false)
 `);
 suite('Facility terminal mutations require a current private session including maintenance actions',`
  local P=PLUGIN;local p=admin();local d=device('workpoint');local j=P:NewJob('device',d.id,'Clean',0)
  eq(P:TerminalAction(p,nil,{section='jobs',command='claim',id=j.id}),false)
  local s=session(p);s.public=true;eq(P:TerminalAction(p,s,{section='jobs',command='claim',id=j.id}),false)
  s.public=false;assert(P:TerminalAction(p,s,{section='jobs',command='claim',id=j.id}))
  p.pos=Vector(1000,0,0);eq(P:TerminalAction(p,s,{section='jobs',command='release',id=j.id}),false)
 `);
 suite('Facility removal refreshes blackout volumes, restores locks, and closes orphaned work',`
  local P=PLUGIN;local p=admin();local c=circuit('Deletion');P:RecomputePower(0)
  local d=door(c);P:LockSector(p,session(p),{id=c.id});eq(d.entity.state.m_bLocked,true)
  assert(P:AdminAction(p,{command='remove',kind='door',id=d.id}));eq(d.entity.state.m_bLocked,false)
  local before=ix.plugin.list.blackout.refreshes
  assert(P:AdminAction(p,{command='remove',kind='circuit',id=c.id}));assert(ix.plugin.list.blackout.refreshes>before)
  local target=device('workpoint');target.fault=true;P:DiscoverJobs();local _,j=next(P.store.jobs)
  assert(P:JobAction(p,{id=j.id,command='claim'}));P:PlayerLoadedCharacter(p,nil,p:GetCharacter());eq(j.status,'open')
  assert(P:AdminAction(p,{command='remove',kind='device',id=target.id}));P:TickJobs();eq(j.status,'closed')
  p.noCharacter=true;eq(P:BeginWork(p,j),false)
 `);
 suite('Facility prop panels share hosts with other screens and preserve transforms and per-model presets',`
  local P=PLUGIN;local p=admin();local host=entity(904,'models/props_lab/monitor01b.mdl',Vector(30,0,0),Angle())
  ix.CCTV.SurfacePlacement=function() return {x=2,y=3,z=4,p=0,yaw=90,r=90},host end
  p.trace={Hit=true,HitPos=Vector(30,0,0),HitNormal=Vector(0,0,1)}
  host:SetNW2Int('ixTVScreenID',9)
  local ok,_,id=P:Place(p,'panel');assert(ok);local d=P.store.devices[id]
  eq(d.entity:GetParent(),host);near(d.entity:GetLocalPos().z,4);local added,_,second=P:Place(p,'panel');assert(added);assert(second~=id)
  assert(P:AdminAction(p,{command='preset',id=id}));P:SaveData();P:LoadData();P:RestoreBindings()
  d=P.store.devices[id];eq(d.entity:GetParent(),host);near(d.localPos.x,2)
  eq(P.store.devices[second].entity:GetParent(),host);assert(ix.PropScreens.Has(host,'ixFacilityPanelID',id));assert(ix.PropScreens.Has(host,'ixFacilityPanelID',second))
  local e=d.entity;e.valid=false;P:DeviceRemoved(e);eq(P.store.devices[id],nil)
  assert(ix.PropScreens.Has(host,'ixFacilityPanelID',second));eq(host:GetNW2Int('ixFacilityPanelID'),second);eq(host:GetNW2Int('ixTVScreenID'),9)
 `);
 suite('Facility panel survives a host restored after the old timeout, including non-physics props',`
  local P=PLUGIN;local p=admin();local host=entity(904,'models/props_lab/monitor01b.mdl',Vector(30,0,0),Angle());host.mapid=-1;host.class='prop_dynamic'
  ix.CCTV.SurfacePlacement=function() return {x=2,y=3,z=4,p=0,yaw=90,r=90},host end
  p.trace={Hit=true,HitPos=Vector(30,0,0),HitNormal=Vector(0,0,1)}
  local ok,_,id=P:Place(p,'panel');assert(ok);local identity=host.ixPropScreenHostID
  P:PreCleanupMap();host.valid=false;P:LoadData();P:RestoreBindings()
  clock=clock+90;P:RestoreBindings();P:SaveData();assert(P.store.devices[id]);eq(P.store.devices[id].entity,nil)
  P:LoadData();local restored=entity(905,host.model,Vector(50,0,0),Angle());restored.mapid=-1;restored.class='prop_dynamic';restored.ixPropScreenHostID=identity
  P:RestoreBindings();eq(P.store.devices[id].entity:GetParent(),restored);near(P.store.devices[id].localPos.z,4)
 `);
 suite('Facility shared-host panels select the aimed screen for use, configuration and physical power connections',`
  local P,F,S=PLUGIN,ix.Facility,ix.PropScreens;local p=admin();p.pos=Vector(0,0,64)
  local host=entity(904,'models/test.mdl',Vector(50,0,64));local ids={}
  for i=1,2 do
   p.trace={Hit=true,Entity=host,HitPos=Vector(45,(i-1)*50,64),HitNormal=Vector(-1,0,0)}
   local ok,_,id=P:Place(p,'panel');assert(ok);ids[i]=id
   -- Engine child angles are inherited; the fixture stores local angles separately.
   local e=P.store.devices[id].entity;e.ang=e:GetLocalAngles()
  end
  for i,id in ipairs(ids) do
   p.pos=Vector(0,(i-1)*50,64);local target=S.Aim(p,128);eq(target.kind,'panel');eq(target.row.id,id)
   local used;P.UseDevice=function(_,_,e) used=e.facilityID end;eq(P:PlayerUse(p,host),false);eq(used,id)
   local focus;P.SendUI=function(_,_,_,v) focus=v end;P:ConfigureEntity(p,host);eq(focus,id)
   local link,e=P:PowerTarget(host,p);eq(link.kind,'device');eq(link.id,id);eq(e,P.store.devices[id].entity)
  end
  util.TraceLine=function() return {Hit=true,HitPos=Vector(5,50,64)} end;eq(S.Aim(p,128),nil)
 `);
 suite('Facility paired doors and plugin teardown restore physical state and mic grants',`
  local P=PLUGIN;local c=circuit('Pair');P:RecomputePower(0);local a=door(c);local b=door(c);a.entity.partner=b.entity
  local p=admin();local s=session(p)
  assert(P:DoorAction(p,s,{command='open',id=a.id}));eq(a.entity.state.m_eDoorState,2);eq(b.entity.state.m_eDoorState,2)
  P:LockSector(p,s,{id=c.id});p:SetNW2Bool('ixFacilityMic',true);P:OnUnload()
  eq(a.entity.state.m_bLocked,false);eq(b.entity.state.m_bLocked,false);eq(p.ixFacilityMic,false)
 `);
 suite('Facility receiver rings, answers the oldest caller, cues both participants and rejects takeover',`
  local P=PLUGIN;local a=device('intercom');local b=device('intercom');local r=device('receiver');r.entity.pos=Vector(1000,0,0)
  local first=admin();first.admin=false;first.card=nil;local second=admin();second.admin=false;second.card=nil
  local op=admin(1);op.admin=false;op.pos=Vector(1000,0,0)
  assert(P:CallIntercom(first,b));eq(net.packets[#net.packets].name,'ixFacilityTone');eq(net.packets[#net.packets].integer,1)
  clock=clock+1;assert(P:CallIntercom(second,a));eq(P:NextCall(),b.id)
  P:PruneComms();eq(r.entity.soundCount,1);clock=clock+1;P:PruneComms();eq(r.entity.soundCount,1)
  eq(P:UseReceiver(op,r),false);op.card.clearanceLevel=2;assert(P:UseReceiver(op,r));eq(P.calls[b.id].operator,op)
  eq(net.packets[#net.packets].integer,2);eq(net.packets[#net.packets-1].target,first)
  eq(P:VoiceRoute(op,first),true);eq(P:VoiceRoute(first,op),true)
  local other=admin(2);other.admin=false;other.pos=op.pos;eq(P:UseReceiver(other,r),false)
  clock=clock+6;P:PruneComms();eq(r.entity.soundCount,1);assert(op.ixFacilityVoiceHint~='')
  assert(P:UseReceiver(op,r));eq(P.calls[b.id],nil);eq(net.packets[#net.packets].integer,3)
  assert(P:UseReceiver(op,r));eq(P.calls[a.id].operator,op)
  r.fault=true;clock=clock+1;P:PruneComms();eq(P.calls[a.id],nil);eq(op.ixFacilityVoiceHint,'')
 `);
 suite('Facility receiver calls expire on timeout, movement and character changes',`
  local P=PLUGIN;local d=device('intercom');local r=device('receiver');r.entity.pos=Vector(1000,0,0)
  local caller=admin();local op=admin(2);op.admin=false;op.pos=r.entity.pos
  assert(P:CallIntercom(caller,d));clock=clock+91;P:PruneComms();eq(next(P.calls),nil)
  assert(P:CallIntercom(caller,d));assert(P:UseReceiver(op,r));op.pos=Vector(1500,0,0);clock=clock+1;P:PruneComms();eq(next(P.calls),nil)
  op.pos=r.entity.pos;clock=clock+4;assert(P:CallIntercom(caller,d));assert(P:UseReceiver(op,r))
  op.character.id=op.character.id+100;clock=clock+1;P:PruneComms();eq(next(P.calls),nil)
 `);
 suite('Facility global PA needs L2, reaches distant listeners without speakers and stops on invalid sessions',`
  local P=PLUGIN;local d=device('announcement');local op=admin(1);op.admin=false;local listener=admin();listener.pos=Vector(99999,0,0)
  eq(P:UseAnnouncement(op,d),false);op.card.clearanceLevel=2;assert(P:UseAnnouncement(op,d))
  eq(net.packets[#net.packets].integer,4);local hear,spatial,label,gain,effect=P:VoiceRoute(listener,op);eq(hear,true);eq(spatial,false);eq(gain,1);eq(effect,'pa')
  local other=admin(2);other.admin=false;eq(P:UseAnnouncement(other,d),false)
  local c=circuit('PA');local speaker=device('speaker',c);P:RecomputePower(0)
  eq(P:CommsAction(other,session(other),{command='broadcast',id=c.id}),false)
  assert(P:UseAnnouncement(op,d));eq(P.broadcasts[op],nil)
  assert(P:UseAnnouncement(op,d));clock=clock+121;eq(P:VoiceRoute(listener,op),nil)
  assert(P:UseAnnouncement(op,d));op.pos=Vector(500,0,0);clock=clock+1;eq(P:VoiceRoute(listener,op),nil)
  op.pos=Vector();assert(P:UseAnnouncement(op,d));d.fault=true;clock=clock+1;eq(P:VoiceRoute(listener,op),nil)
  d.fault=false;assert(P:UseAnnouncement(op,d));op.character.id=op.character.id+100;clock=clock+1;eq(P:VoiceRoute(listener,op),nil)
  assert(P:UseAnnouncement(op,d));op.card.clearanceLevel=1;clock=clock+1;eq(P:VoiceRoute(listener,op),nil)
 `);
 suite('Facility direct repair claims locally, releases failed claims and permits calibration beside a parent prop',`
  local P=PLUGIN;local p=admin(1);p.admin=false;local d=device('panel');d.fault=true
  eq(P:DeviceAction(p,{id=d.id,command='repair'}),false);local _,j=next(P.store.jobs);eq(j.owner,nil);eq(j.status,'open')
  giveItem(p,'tool_screw');local part=giveItem(p,'facility_spares');local host=entity(900,'prop',Vector())
  d.entity:SetParent(host);p.trace={Entity=host};assert(P:DeviceAction(p,{id=d.id,command='repair'}));eq(j.owner,p.character.id)
  local other=admin();eq(P:DeviceAction(other,{id=d.id,command='repair'}),false)
  solveRepair(p);eq(d.fault,false);eq(part.removed,1);P:TickJobs();eq(part.removed,1)
  d.fault=true;P:DiscoverJobs();giveItem(p,'facility_spares');p.pos=Vector(1000,0,0)
  eq(P:DeviceAction(p,{id=d.id,command='repair'}),false)
 `);
 suite('Facility direct generator controls keep access checks and report actual fuel added at tank capacity',`
  local P=PLUGIN;local p=admin(1);p.admin=false;local g=device('generator');g.fuel=500
  local can=giveItem(p,'facility_fuel');local ok,msg=P:DeviceAction(p,{id=g.id,command='refuel'});assert(ok);eq(g.fuel,600);eq(can.removed,1);assert(msg:find('1:40',1,true))
  eq(P:DeviceAction(p,{id=g.id,command='generator'}),false);p.card.clearanceLevel=3
  assert(P:DeviceAction(p,{id=g.id,command='generator'}));eq(g.running,true)
  p.pos=Vector(1000,0,0);eq(P:DeviceAction(p,{id=g.id,command='generator'}),false);eq(g.running,true)
  p.pos=Vector();local snap=P:DeviceSnapshot(p,g);eq(snap.device.canStart,true);eq(snap.device.hasFuel,false)
  eq(ix.Facility.Time(600),'10:00');eq(ix.Facility.Time(0),'0:00')
 `);
 suite('Facility calibration scores presses on the server, rejects replay and permits cancellation before an acknowledgement',`
  local P=PLUGIN;local p=admin(1);p.admin=false;local d=device('generator');d.fault=true
  giveItem(p,'tool_screw');local part=giveItem(p,'facility_spares');assert(P:RepairHere(p,d))
  local w=P.work[p];local r=w.repair;local token,round=r.token,r.round
  clock=r.started;P:RepairInput(p,token,round,true);eq(r.stage,1);eq(r.round,2);eq(part.removed,0)
  clock=r.started+r.target*r.period*.5;local stale=r.round;P:RepairInput(p,token,stale,true);eq(r.stage,2)
  P:RepairInput(p,token,stale,true);eq(r.stage,2);P:RepairInput(p,token+1,r.round,true);eq(r.stage,2)
  eq(P:CompleteWork(p,w),false);local other=admin();P:RepairInput(other,token,r.round,true);eq(r.stage,2)
  P:RepairInput(p,token,stale,false);eq(P.work[p],nil);eq(part.removed,0);eq(d.fault,true);eq(P.store.jobs[w.job].owner,nil)
 `);
 suite('Facility calibration aborts on distance, lost card, lost tools, deleted equipment and cleared faults without spending parts',`
  local P=PLUGIN
  local mutations={
   function(p,d) p.pos=Vector(1000,0,0) end,
   function(p,d) p.card=nil end,
   function(p,d) p.items.tool_screw=nil end,
   function(p,d) p.items.facility_spares=nil end,
   function(p,d) d.entity.valid=false end,
   function(p,d) d.fault=false end,
   function(p,d) p.character.id=p.character.id+100 end
  }
  for _,change in ipairs(mutations) do
   local d=device('generator');d.fault=true;local p=admin(1);p.admin=false
   giveItem(p,'tool_screw');local part=giveItem(p,'facility_spares');assert(P:RepairHere(p,d));local r=P.work[p].repair
   change(p,d);clock=r.started+r.target*r.period*.5;P:RepairInput(p,r.token,r.round,true)
   eq(P.work[p],nil);eq(part.removed,0)
  end
 `);
 suite('Facility calibration times out without repairing, releases abandoned work and cannot persist a live puzzle',`
  local P=PLUGIN;local p=admin(1);p.admin=false;local d=device('battery');d.fault=true
  giveItem(p,'tool_screw');local part=giveItem(p,'facility_spares');assert(P:RepairHere(p,d))
  local w=P.work[p];clock=w.repair.expires+1;P:TickJobs();eq(P.work[p],nil);eq(P.store.jobs[w.job].owner,nil);eq(part.removed,0)
  assert(P:RepairHere(p,d));P:ReleaseWorker(p,p:GetCharacter());eq(P.work[p],nil);eq(part.removed,0)
  assert(P:RepairHere(p,d));P:SaveData();P:LoadData();eq(P.work[p],nil);eq(P.store.devices[d.id].fault,true);eq(part.removed,0)
 `);
 suite('Facility CCTV repairs require five contacts and restore the original enabled state only once',`
  local P=PLUGIN;local p=admin(1);p.admin=false;giveItem(p,'tool_screw')
  local updates=0;ix.plugin.list.cctv={devices={},SendDevice=function() updates=updates+1 end,SaveData=function() end}
  for _,wasOn in ipairs({true,false}) do
   local id=P:NewID();local e=entity(800+id,'camera',Vector());local d={kind='camera',entity=e,on=false}
   ix.plugin.list.cctv.devices[id]=d;local j=P:NewJob('cctv',id,'Camera',1);j.previousOn=wasOn
   local part=giveItem(p,'facility_spares');assert(P:JobAction(p,{id=j.id,command='claim'}));p.trace={Entity=e}
   eq(P:BeginWork(p,j),false);assert(P:BeginWork(p,j,true))
   local w=P.work[p];eq(P:CompleteWork(p,w),false);solveRepair(p)
   eq(d.on,wasOn);eq(part.removed,1);eq(j.status,'closed')
   P:RepairInput(p,w.repair.token,w.repair.round,true);eq(part.removed,1)
  end
  eq(updates,2)
 `);
 suite('Facility calibration tolerates bounded network delay and late client claims cannot repair after a job is released',`
  local P=PLUGIN;local d=device('generator');d.fault=true;local p=admin(1);p.admin=false;function p:Ping() return 300 end
  giveItem(p,'tool_screw');local part=giveItem(p,'facility_spares');assert(P:RepairHere(p,d))
  local w=P.work[p];local r=w.repair;clock=r.started+r.target*r.period*.5+.15;P:RepairInput(p,r.token,r.round,true);eq(r.stage,2)
  assert(P:JobAction(p,{id=w.job,command='release'}));clock=r.started+r.target*r.period*.5+.15
  P:RepairInput(p,r.token,r.round,true);eq(P.work[p],nil);eq(part.removed,0);eq(d.fault,true)
 `);
 const definitions=Object.keys({speaker:1,intercom:1,receiver:1,announcement:1,generator:1,battery:1,workpoint:1,panel:1,terminal:1,doorconsole:1,powerconsole:1}).map(kind=>`do ENT={};${normalize(fs.readFileSync('ixhl2rp/plugins/facility_utilities/entities/entities/ix_facility_'+kind+'.lua','utf8'))};definitions['${kind}']=ENT end`).join('\n');
 suite('Facility spawn-menu entities register exactly once and survive save, restore, movement and removal',`
  local P=PLUGIN;local p=admin();local baseENT=ENT;local definitions={}
  ${definitions}
  ENT=baseENT
  local host=entity(800,'models/props_lab/monitor01b.mdl',Vector(20,0,0),Angle())
  ix.CCTV.SurfacePlacement=function() return {x=2,y=0,z=4,p=0,yaw=90,r=90},host end
  local tr={Hit=true,HitPos=Vector(20,0,0),HitNormal=Vector(0,0,1)}
  for kind,def in pairs(definitions) do
   eq(def.Spawnable,true);eq(def.AdminOnly,true);eq(def.Base,'ix_facility_device');eq(def.Category,ix.Facility.entityCategory);eq(def.Model,ix.Facility.kinds[kind].model)
   local e=baseENT.SpawnFunction(def,p,tr);assert(IsValid(e));eq(P.store.devices[e.facilityID].entity,e)
  end
  eq(table.Count(P.store.devices),11);eq(host:GetNW2Int('ixFacilityPanelID',0)>0,true)
  local direct=ents.Create('ix_facility_generator');direct:Spawn();assert(direct.facilityID);eq(table.Count(P.store.devices),12)
  direct:Initialize();eq(table.Count(P.store.devices),12)
  p.admin=false;eq(baseENT.SpawnFunction(definitions.terminal,p,tr),nil);eq(P:Place(p,'terminal',tr),false);p.admin=true
  direct.pos=Vector(90,10,20);P:PhysgunDrop(p,direct);local id=direct.facilityID;P:SaveData();P:LoadData();P:RestoreBindings()
  eq(table.Count(P.store.devices),12);near(P.store.devices[id].entity:GetPos().x,90)
  P.store.devices[id].entity:Remove();eq(P.store.devices[id],nil)
 `);
 suite('Facility context properties configure selected equipment and map doors only for nearby admins',`
  properties={list={},Add=function(key,definition) properties.list[key]=definition end}
  ${normalize(fs.readFileSync('ixhl2rp/plugins/facility_utilities/sh_properties.lua','utf8'))}
  local P=PLUGIN;local p=admin();local d=device('intercom');local sent
  P.SendUI=function(_,who,page,id,message,kind) sent={who=who,page=page,id=id,kind=kind} end
  local prop=properties.list.ixFacilityConfigure;net.ReadEntity=function() return d.entity end
  eq(prop:Filter(d.entity,p),true);prop:Receive(32,p);eq(sent.id,d.id)
  sent=nil;p.admin=false;eq(prop:Filter(d.entity,p),false);clock=clock+1;prop:Receive(32,p);eq(sent,nil)
  p.admin=true;d.entity.pos=Vector(1000,0,0);clock=clock+1;prop:Receive(32,p);eq(sent,nil)
  local doorEntity=entity(901,'door',Vector(20,0,0),Angle());doorEntity.class='func_door'
  P:ConfigureEntity(p,doorEntity);eq(sent.kind,'door');local doorID=sent.id;eq(P.store.doors[doorID].entity,doorEntity)
  P:ConfigureEntity(p,doorEntity);eq(sent.id,doorID);eq(table.Count(P.store.doors),1)
  local host=entity(902,'models/props_lab/monitor01b.mdl',Vector(20,0,0),Angle())
  local panel=P:DeviceRecord('panel',Vector(),Angle());panel.binding={};panel.localPos=Vector();panel.localAng=Angle();P.store.devices[panel.id]=panel
  P:SpawnDevice(panel,host);eq(prop:Filter(host,p),true);P:ConfigureEntity(p,host);eq(sent.id,panel.id)
  panel.entity:Remove();eq(host:GetNW2Int('ixFacilityPanelID',0),0)
 `);
 suite('Facility standalone consoles reuse plasma geometry and retain private card and power checks',`
  local F=ix.Facility;local facilities=PLUGIN;local p=admin();local rows={}
  for _,kind in ipairs({'terminal','doorconsole','powerconsole'}) do
   local d=device(kind);rows[#rows+1]=d;eq(F.IsScreen(d.entity),true)
   local pos,a,scale=F.PanelGeometry(d.entity);near(scale,56/1920);near(pos.z,35.2);near(pos.x,6.12)
   local after=d.entity:GetAngles();near(after.p,0);near(after.y,0);near(after.r,0)
  end
  eq(F.IsScreen(device('generator').entity),false)
  ix.FoundationNet={};PLUGIN={SetData=function() end};
  ${normalize(fs.readFileSync('ixhl2rp/plugins/foundation_network/sv_network.lua','utf8'))}
  local network=PLUGIN;ix.plugin.list.foundation_network=network;local route
  network.SendPage=function(_,player,s,identity,card,path) route=path end
  util.SHA256=function(v) return v end;function SysTime() return 1 end;math.Rand=function() return .5 end
  p.card.GetID=function() return 5 end
  for _,d in ipairs(rows) do
   eq(network:Near(p,d.entity),true);network:Login(p,d.entity);eq(route,'scip://utilities/'..F.kinds[d.kind].page)
   local s=network.sessions[p];assert(network:Session(p,s.token))
   d.entity:SetNW2Bool('ixFacilityPowered',false);eq(network:Session(p,s.token),nil);d.entity:SetNW2Bool('ixFacilityPowered',true)
  end
  p.card=nil;network:Login(p,rows[1].entity);eq(network.sessions[p],nil)
 `);
 const client=[...base,'tools/terminal-preview-fixture.lua','ixhl2rp/plugins/facility_utilities/sh_core.lua','ixhl2rp/plugins/facility_utilities/sh_repair.lua','ixhl2rp/plugins/foundation_network/cl_design.lua','ixhl2rp/plugins/facility_utilities/cl_hardware.lua','ixhl2rp/plugins/facility_utilities/cl_ui.lua','ixhl2rp/plugins/facility_utilities/cl_devices.lua','ixhl2rp/plugins/facility_utilities/cl_repair.lua'];
 run('Repair UI paints five stages and uses each server-sent target width without rebuilding the window',[],client.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend').join('\n')+`
  local F=ix.Facility;input={IsKeyDown=function() return false end};gui={IsGameUIVisible=function() return false end};surface.PlaySound=function() end
  function ScrW() return 1280 end;function ScrH() return 720 end
  local data={token=1,round=1,stage=1,target=.55,started=10,period=7.2,width=.2,title='Ремонт',result='start'}
  F.OpenRepair(data);local win=F.repairWindow;local first=PreviewSVG(win)
  assert(first:find('05',1,true));assert(first:find('ЭТАП 1 / 5',1,true))
  local widths={};local original=draw.RoundedBox
  draw.RoundedBox=function(radius,x,y,w,h,c)
   if c.r==38 and c.g==114 and c.b==94 then widths[#widths+1]=w end
   original(radius,x,y,w,h,c)
  end
  PreviewSVG(win)
  data=table.Copy(data);data.round=5;data.stage=5;data.period=3.8;data.width=.13;F.OpenRepair(data)
  eq(F.repairWindow,win);local fifth=PreviewSVG(win);assert(fifth:find('ЭТАП 5 / 5',1,true))
  eq(#widths,2);near(widths[2]/widths[1],.13/.20)
 `);
 run('Powerbox sabotage UI identifies disconnection, requires no spares and confirms the correct result',[],client.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend').join('\n')+`
  local F=ix.Facility;input={IsKeyDown=function() return false end};gui={IsGameUIVisible=function() return false end};surface.PlaySound=function() end
  function ScrW() return 1920 end;function ScrH() return 1080 end
  local data={token=1,round=1,stage=1,target=.5,started=10,period=7.2,width=.20,title='Саботаж электрощита',sabotage=true,noParts=true,result='start'}
  F.OpenRepair(data);local win=F.repairWindow;PreviewLayout(win)
  eq(win.facilityTitle,'ОТКЛЮЧЕНИЕ КОНТАКТОВ')
  local function text(p) local s=p.text or '';for _,c in ipairs(p:GetChildren()) do s=s..text(c) end;return s end
  assert(text(win):find('Разомкните 5 контактов',1,true));assert(text(win):find('запчасти не нужны',1,true))
  data.result='complete';data.stage=6;F.OpenRepair(data);eq(win.finished,true);assert(win.feedback.text:find('разомкнуты',1,true))
 `);
 run('Client cables render continuous hanging segments at networked anchors and cache static floor traces',[],client.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend').join('\n')+`
  local p=admin();function LocalPlayer() return p end
  local g=entity(8800,'battery',Vector(0,0,15));g.class='ix_facility_battery'
  g:SetNW2Vector('ixGeneratorCableStart1',Vector(3,4,5))
  local e=entity(8801,'terminal',Vector(180,0,0));g:SetNW2Entity('ixGeneratorCable1',e);g:SetNW2Vector('ixGeneratorCablePoint1',Vector(1,2,50))
  local traces=0;util.TraceHull=function() traces=traces+1;return {Hit=false} end
  local points={};local frames=0;local cableDepth=false
  render={OverrideDepthEnable=function(v,w) cableDepth=v and w end,SetMaterial=function() end,StartBeam=function(n) assert(cableDepth);points={};frames=frames+1;assert(n>3) end,
   AddBeam=function(point) points[#points+1]=point end,EndBeam=function() end}
  ${normalize(fs.readFileSync('ixhl2rp/plugins/facility_utilities/cl_connections.lua','utf8'))}
  local paint=hooks.PostDrawTranslucentRenderables.ixFacilityGeneratorCables
  paint(false,false);assert(frames>0);near(points[1].x,3);near(points[1].y,4);near(points[1].z,20);near(points[#points].x,181);near(points[#points].y,2);near(points[#points].z,50)
  eq(cableDepth,false);assert(points[math.ceil(#points/2)].z<20);local old=traces;paint(false,false);eq(traces,old)
  e.ang=Angle(0,90,0);paint(false,false);assert(traces>old);near(points[#points].x,178);near(points[#points].y,1)
  old=frames;paint(true,false);eq(frames,old)
  ix.plugin.list.blackout={drawsWorldGeometry=true}
  old=frames;paint(false,false);eq(frames,old)
  hooks.ixBlackoutWorldGeometry.ixFacilityGeneratorCables(false,false,false);eq(frames,old+1)
  old=frames;hooks.ixBlackoutWorldGeometry.ixFacilityGeneratorCables(false,true,false);eq(frames,old+1)
  old=frames;hooks.ixBlackoutWorldGeometry.ixFacilityGeneratorCables(false,true,true);eq(frames,old)
  old=frames;paint(false,false);eq(frames,old)
  ix.plugin.list.blackout.drawsWorldGeometry=false;paint(false,false);eq(frames,old+1)
  old=frames;paint(false,false,true);eq(frames,old)

 `);
 run('Facility terminal UI builds all four pages and microphone requires a held authorized press',[],client.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend').join('\n')+`
  MOUSE_LEFT=107;local F=ix.Facility;local p=admin();function LocalPlayer() return p end
  function p:IsSpeaking() return false end;function p:GetNW2Bool(k,d) if self[k]~=nil then return self[k] end;return d end
  local held=true;input={IsMouseDown=function() return held end};system={HasFocus=function() return true end}
  gui={IsGameUIVisible=function() return false end,IsConsoleVisible=function() return false end}
  local voice={};permissions={EnableVoiceChat=function(v) voice[#voice+1]=v end}
  local function find(root,key) if root[key] then return root end;for _,child in ipairs(root:GetChildren()) do local v=find(child,key);if v then return v end end end
  local data={calls={},circuits={{id=1,name='Sector',load=20,priority=1,powered=true,source='СЕТЬ'}},devices={},doors={},jobs={}}
  for _,section in ipairs({'comms','doors','power','jobs'}) do
   local root=vgui.Create('DPanel');root:SetSize(1400,900);root.route='scip://utilities/'..section;root.body=root;data.page=section;data.transmitting=1
   F.RenderTerminal(root,data);PreviewLayout(root);assert(#root:GetChildren()==1 and #root:GetChildren()[1]:GetChildren()>1)
   if section=='comms' then
    local mic=find(root,'OnSurfacePressed');assert(mic);mic:OnSurfacePressed(MOUSE_LEFT);eq(#voice,0)
    p.ixFacilityMic=true;mic:OnSurfacePressed(MOUSE_LEFT);eq(voice[1],true);mic:OnSurfaceReleased();eq(voice[2],false)
   end
  end
  local panel={valid=true,token='t',route='scip://utilities/power'};local requests=0;ix.FoundationNet.Request=function(a) eq(a,'utilitySync');requests=requests+1 end
  F.UpdateTerminal(panel);eq(requests,0);held=false;F.UpdateTerminal(panel);eq(requests,1);F.UpdateTerminal(panel);eq(requests,1)
 `);
 run('Facility device snapshots update without a popup and retain the explicit help workspace',[],client.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend').join('\n')+`
  local F=ix.Facility;input={LookupBinding=function() return 'v' end}
  local player=admin();function LocalPlayer() return player end
  function ScrW() return 1920 end;function ScrH() return 1080 end;eq(F.VoiceKey(),'Удерживайте V — говорить')
  local data={device={entity=101,id=1,name='Generator',kind='generator',fuel=300,running=false,canStart=true,hasFuel=true,circuits=1}}
  F.OpenDevice(data);eq(F.window,nil);eq(F.deviceSnapshots[101].data.running,false)
  data.device.running=true;F.OpenDevice(data);eq(F.deviceSnapshots[101].data.running,true)
  F.OpenDevice({close=true});eq(next(F.deviceSnapshots),nil)
  F.HelpWindow();assert(IsValid(F.helpWindow));local first=F.helpWindow;F.HelpWindow();eq(IsValid(first),false)
 `);
 run('Facility calibration UI submits one press per key edge, survives round updates and closes only its own session',[],client.map(f=>'do\n'+normalize(fs.readFileSync(f,'utf8'))+'\nend').join('\n')+`
  local F=ix.Facility;local held=false;KEY_SPACE=65;KEY_ESCAPE=70
  input={IsKeyDown=function() return held end};gui={IsGameUIVisible=function() return false end}
  surface.PlaySound=function() end;vgui.GetKeyboardFocus=function() return F.repairWindow end
  function ScrW() return 1920 end;function ScrH() return 1080 end
  local data={token=1,round=1,stage=1,target=.55,started=10,period=7.2,width=.20,title='Repair',result='start'}
  F.OpenRepair(data);local win=F.repairWindow;assert(IsValid(win));PreviewLayout(win)
  clock=10;held=true;win:Think();eq(net.packets[#net.packets].boolean,true);local count=#net.packets
  win:Think();eq(#net.packets,count);eq(F.RepairPress(win),false)
  local update=table.Copy(data);update.round=2;update.stage=2;update.result='hit';F.OpenRepair(update);eq(F.repairWindow,win)
  win:Think();eq(#net.packets,count);held=false;win:Think();held=true;win:Think();eq(#net.packets,count+1)
  F.OpenRepair({token=99,result='cancel'});eq(F.repairWindow,win)
  -- Simulate the engine's OnRemove notification (the lightweight preview fixture has no event dispatch).
  win:OnRemove();eq(net.packets[#net.packets].boolean,false);eq(F.repairWindow,nil)
  F.OpenRepair(update);win=F.repairWindow;local final=table.Copy(update);final.result='complete';final.stage=6
  F.OpenRepair(final);eq(win.finished,true);count=#net.packets;win:OnRemove();eq(#net.packets,count)
 `);
};
if(require.main===module){const f=require('fengari');let count=0;module.exports((name,files,test)=>{const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);const source=fs.readFileSync('tools/fixture.lua','utf8')+'\n'+test;const result=f.lauxlib.luaL_dostring(L,f.to_luastring(source));if(result!==f.lua.LUA_OK){fs.writeFileSync('docs/facility-test-expanded.lua',source);throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));}console.log('PASS '+name);count++;});console.log(count+' facility regression suites passed.');}
