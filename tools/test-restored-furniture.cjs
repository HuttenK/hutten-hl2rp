const {run,source,native,base,finish}=require('./restored-test-runner.cjs');
const itemFile='helix/gamemode/game/items/sh_item.class.lua',inventoryFile='helix/gamemode/game/inventory/sh_inventory.class.lua',loader='helix/gamemode/game/items/sh_item.lua';
const env=source(base)+`
 ix.config.Get=function(k,d) if settings[k]~=nil then return settings[k] end;return d end
 angle_zero=Angle();settings={};ix.Inventory={stored={},pendingTransfers={}};function ix.Inventory:Get(id) return self.stored[id] end
 ix.Item={instances={},stored={}};ix.container={stored={['box.mdl']={name='Box',width=5,height=5}}}
 local Item=ix.Item;ITEM={};Inventory={};local rows={};local queries={};local deleted={};db={rows=rows,queries=queries,deleted=deleted}
 function table.IsEmpty(t) return next(t)==nil end
 function table.RemoveByValue(t,v) for i=#t,1,-1 do if t[i]==v then table.remove(t,i) end end end
 function table.GetKeys(t) local out={};for k in pairs(t) do out[#out+1]=k end;return out end
 ${native(inventoryFile,'function Inventory:GetItems()','function Inventory:GetSlot(')}
 ${native(inventoryFile,'function Inventory:AddItem(item,','function Inventory:AddItemByID(')}
 ${native(inventoryFile,'function Inventory:TakeItemTable(item)','function Inventory:TakeItem(uniqueID)')}
 ${native(inventoryFile,'function Inventory:GetReceivers()','function Inventory:OnCheckAccess(')}
 ${native(itemFile,'function ITEM:Remove(','function ITEM:Register()')}
 ${native(itemFile,'function ITEM:SetEntity(','if SERVER then')}
 ${native(itemFile,'function ITEM:GetOwner()','do\n\tif SERVER then')}
 ${native(itemFile,'function ITEM:Save()','function ITEM:CollectSyncData(')}
 ${native(loader,'function Item:LoadInstanceByID(','function Item:LoadToInventory(')}
 ${native(loader,'function Item:LoadToInventory(','function Item:LoadInstanceCount(')}
 do local Inventory=ix.Inventory
 ${native('helix/gamemode/game/inventory/sh_inventory.lua','function Inventory:CancelTransfer(','function GM:OnItemTransferred(')}
 end
 ix.storage={}
 ${native('helix/gamemode/game/inventory/sh_storage.lua','function ix.storage.InUse(inventory)','--- Returns whether or not an inventory is in use by')}
 ${native('helix/gamemode/game/inventory/sh_storage.lua','function ix.storage.RemoveContext(','--- Synchronizes an inventory')}
 ${native('helix/gamemode/game/inventory/sh_storage.lua','function ix.storage.RemoveReceiver(','--- Makes a player open an inventory')}
 function Inventory:UnreserveSlots(id) self.reservations=self.reservations or {};self.reservations[id]=nil end
 function Inventory:GetWidth() return self.width end;function Inventory:GetHeight() return self.height end
 function Inventory:GetItemSize() return 1,1 end;function Inventory:CheckSize() end;function Inventory:Sync() self.sync=(self.sync or 0)+1 end
 function Inventory:OverlapsOnlyItself(id,x,y) return #self.slots[y][x]==0 or self.slots[y][x][1]==id end
 function Inventory:FindPosition() for y=1,self.height do for x=1,self.width do if #self.slots[y][x]==0 then return x,y,false end end end end
 function newInventory(owner,kind)
  local inv=setmetatable({id=#ix.Inventory.stored+1,width=5,height=5,slots={},type=kind or 'main',owner=owner,receivers={}}, {__index=Inventory})
  for y=1,5 do inv.slots[y]={};for x=1,5 do inv.slots[y][x]={} end end
  ix.Inventory.stored[inv.id]=inv;return inv
 end
 function ITEM:GetID() return self.id end
 function Item:Get(id) return self.stored[id] end
 function Item:MigrateLegacyRow(_,data) return data end
 function Item:New(id,instanceID)
  if self.instances[instanceID] then return self.instances[instanceID] end
  local item=setmetatable({id=instanceID,uniqueID=id,preview_model=self.stored[id].preview_model,data={},vars_id={'paint'},vars={paint={}}},{__index=ITEM})
  self.instances[instanceID]=item;return item
 end
 mysql={}
 local function query(kind)
  local q={fields={},kind=kind}
  function q:Where(_,id) self.id=id end
  function q:WhereIn(_,ids) self.ids=type(ids)=='table' and ids or {ids} end
  function q:Select() end;function q:Update(k,v) self.fields[k]=v end
  function q:Callback(fn) self.callback=fn end
  function q:Execute()
   if self.kind=='select' then queries[#queries+1]=self
   elseif self.kind=='delete' then deleted[self.id]=(deleted[self.id] or 0)+1;rows[self.id]=nil
   else for k,v in pairs(self.fields) do rows[self.id][k]=v end end
  end
  return q
 end
 function mysql:Select() return query('select') end;function mysql:Update() return query('update') end;function mysql:Delete() return query('delete') end
 function flush()
  while #queries>0 do local q=table.remove(queries,1);local result={}
   for _,id in ipairs(q.ids) do if rows[id] then result[#result+1]=table.Copy(rows[id]) end end
   q.callback(result)
  end
 end
 function tobool(v) return v==true or v==1 end
 local adminOld=admin
 function admin(...)
  local p=adminOld(...);p.admin=false;p.inv=newInventory(p)
  function p:GetInventory() return self.inv end
  function p:HasItemByID(id) return table.HasValue(self.inv:GetItemsID(),id) end
  function p:Team() return self.team or 1 end
  function p:NotifyLocalized(v) self:Notify(v) end
  return p
 end
 function furniture(p,id,model)
  model=model or 'chair.mdl';local unique=model=='box.mdl' and 'cont_box' or 'furn_chair'
  ix.Item.stored[unique]={preview_model=model};rows[id]={item_id=id,unique_id=unique,inventory_type='main',character_id=p.character.id,data='[]'}
  local item=Item:New(unique,id);item.data.paint='blue';item.character_id=p.character.id
  assert(p.inv:AddItem(item));item:Save();return item
 end
 function PLUGIN:SetData(data) self.saved=util.TableToJSON(data) end
 function PLUGIN:GetData(default) return self.saved and util.JSONToTable(self.saved) or default end
 function util.IsValidModel() return true end
 net.WriteEntity=function() end
 local create=ents.Create
 function ents.Create(class)
  if failSpawn then return nil end
  local e=create(class);e.netvars={};e.children={}
  function e:SetNetVar(k,v) self.netvars[k]=v end;function e:GetNetVar(k) return self.netvars[k] end
  function e:NearestPoint() return self.pos end;function e:GetChildren() return self.children end
  if class=='ix_container' then
   function e:CreateInventory() self.inventory=newInventory(self,'container') end
   function e:GetInventory() return self.inventory end;function e:SetInventory(inv) self.inventory=inv end
   function e:SetMoney(v) self.money=v end;function e:GetMoney() return self.money or 0 end
   function e:SetLocked(v) self.locked=v end
   function e:SetDisplayName(v) self.displayName=v end;function e:GetDisplayName() return self.displayName or 'Box' end
  end
  return e
 end
 function util.TraceLine(t)
  if blocked then return {Hit=true,HitPos=Vector(999,0,0),HitNormal=Vector(0,0,1)} end
  if t.start.z>t.endpos.z and math.abs(t.start.x-t.endpos.x)<.001 and math.abs(t.start.y-t.endpos.y)<.001 then
   return {Hit=true,HitPos=Vector(t.endpos.x,t.endpos.y,0),HitNormal=Vector(0,0,1)}
  end
  return {Hit=false}
 end
 function util.TraceHull() return {Hit=occupied==true,StartSolid=false} end
 `+source(['helix/plugins/area/sh_geometry.lua','ixhl2rp/plugins/furnishing/sh_grid.lua','ixhl2rp/plugins/furnishing/sv_furnish.lua'])+`
 local runHook=hook.Run
 function hook.Run(event,...) local result=runHook(event,...);if result~=nil then return result end;if PLUGIN[event] then return PLUGIN[event](PLUGIN,...) end end
 function place(p,item) assert(PLUGIN:BeginFurnish(p,item));assert(PLUGIN:PlaceFurniture(p,item.id,Vector(50,0,10),Angle()));return PLUGIN.records[item.id].entity end
`;
function suite(name,test){run(name,env+'\n'+test);}
suite('Furniture preserves original native instance/data across placement, move, pack and replay',`
 local p=admin();local item=furniture(p,1);local entity=place(p,item)
 eq(#p.inv:GetItemsID(),0);eq(item.inventory_id,nil);eq(item.inventory_type,'furnishing');eq(db.rows[1].character_id,0)
 eq(PLUGIN:PlaceFurniture(p,1,Vector(50,0,10),Angle()),false)
 assert(PLUGIN:BeginFurnish(p));assert(PLUGIN:MoveFurniture(p,entity,Vector(65,0,10),Angle(0,90,0)))
 assert(PLUGIN:PackFurniture(p,entity));eq(#p.inv:GetItemsID(),1);eq(ix.Item.instances[1],item);eq(item.data.paint,'blue')
 eq(item.inventory_type,'main');eq(item:GetEntity(),nil);eq(PLUGIN:PackFurniture(p,entity),false);eq(db.deleted[1],nil)
`);
suite('Furniture rejects unowned/faction/remote/obstructed/invalid/transferring/expired placement and unavailable spawn',`
 local p=admin();local q=admin();local item=furniture(p,1)
 eq(PLUGIN:BeginFurnish(q,item),false)
 item.factionLock={[2]=true};eq(PLUGIN:BeginFurnish(p,item),false);item.factionLock=nil
 assert(PLUGIN:BeginFurnish(p,item));item.factionLock={[2]=true};eq(PLUGIN:PlaceFurniture(p,1,Vector(50,0,10),Angle()),false);item.factionLock=nil
 for _,pos in ipairs({Vector(900,0,0),Vector(0/0,0,0)}) do eq(PLUGIN:PlaceFurniture(p,1,pos,Angle()),false) end
 blocked=true;eq(PLUGIN:PlaceFurniture(p,1,Vector(50,0,10),Angle()),false);blocked=false
 occupied=true;eq(PLUGIN:PlaceFurniture(p,1,Vector(50,0,10),Angle()),false);occupied=false
 ix.Inventory.pendingTransfers.item_1=55;eq(PLUGIN:PlaceFurniture(p,1,Vector(50,0,10),Angle()),false);ix.Inventory.pendingTransfers.item_1=nil
 failSpawn=true;eq(PLUGIN:PlaceFurniture(p,1,Vector(50,0,10),Angle()),false);failSpawn=false
 clock=clock+181;PLUGIN:Think();eq(PLUGIN.sessions[p],nil);eq(#p.inv:GetItemsID(),1)
 local e=place(p,item);eq(PLUGIN:PackFurniture(q,e),false);eq(PLUGIN:BeginFurnish(q,nil,e),false)
 q.admin=true;assert(PLUGIN:PackFurniture(q,e));eq(#q.inv:GetItemsID(),1)
`);
suite('Containers cannot pack while occupied, open, loading, attached, pending transfer or inventory full',`
 local p=admin();local item=furniture(p,1,'box.mdl');local e=place(p,item);local inv=e:GetInventory()
 local content=furniture(p,2);p.inv:TakeItemTable(content);assert(inv:AddItem(content));eq(PLUGIN:PackFurniture(p,e),false)
 inv:TakeItemTable(content);e:SetMoney(1);eq(PLUGIN:PackFurniture(p,e),false);e:SetMoney(0)
 e.children={entity(999,'attachment')};eq(PLUGIN:PackFurniture(p,e),false);e.children={}
 inv.receivers={p};eq(PLUGIN:PackFurniture(p,e),false);inv.receivers={}
 ix.Inventory.pendingTransfers[55]={to_id=inv.id};eq(PLUGIN:PackFurniture(p,e),false);ix.Inventory.pendingTransfers[55]=nil
 PLUGIN.records[1].loadingContents=true;eq(PLUGIN:PackFurniture(p,e),false);PLUGIN.records[1].loadingContents=nil
 local find=p.inv.FindPosition;p.inv.FindPosition=function() end;eq(PLUGIN:PackFurniture(p,e),false);p.inv.FindPosition=find
 assert(PLUGIN:PackFurniture(p,e));eq(ix.Inventory.stored[inv.id],nil)
`);
suite('Persistence uses native SQL loader, skips duplicate records and retains container IDs/name/password/money',`
 local p=admin();local item=furniture(p,1,'box.mdl');local e=place(p,item);local content=furniture(p,2)
 p.inv:TakeItemTable(content);e:GetInventory():AddItem(content);content.character_id=0
 e:SetMoney(17);e:SetDisplayName('Locker');e.password='test';PLUGIN:SaveData()
 local rows=PLUGIN:GetData({});rows[#rows+1]=rows[1];PLUGIN:SetData(rows)
 e.valid=false;PLUGIN.records={};ix.Item.instances={};ix.Inventory.stored={};p.inv=newInventory(p)
 PLUGIN:LoadData();eq(PLUGIN.loading,true);PLUGIN:LoadData();eq(#db.queries,1);flush();eq(PLUGIN.loading,false)
 local r=PLUGIN.records[1];assert(r and IsValid(r.entity));eq(table.Count(PLUGIN.records),1)
 eq(r.entity:GetMoney(),17);eq(r.entity:GetDisplayName(),'Locker');eq(r.entity.password,'test');eq(#r.entity:GetInventory():GetItemsID(),1)
 eq(ix.Item.instances[1].data.paint,'blue');eq(ix.Item.instances[2].data.paint,'blue')
 eq(PLUGIN:PackFurniture(p,r.entity),false)
 local old=r.entity;local storage=old:GetInventory();PLUGIN:PreCleanupMap();old:Remove();PLUGIN:PostCleanupMap()
 eq(r.entity:GetInventory(),storage);eq(storage.owner,r.entity);eq(#storage:GetItemsID(),1);eq(db.deleted[1],nil)
`);
suite('Area ownership/footprint and limit apply on server; direct removal deletes native item once',`
 local p=admin();local item=furniture(p,1);settings.furnitureAreaOnly=true
 eq(PLUGIN:BeginFurnish(p,item),false)
 ix.area.stored={room={type='furnishing',startPosition=Vector(-100,-100,-20),endPosition=Vector(150,100,90),properties={furnishingOwner=p.character.id}}}
 local e=place(p,item);local second=furniture(p,2);settings.furnitureLimit=1;assert(PLUGIN:BeginFurnish(p,second))
 eq(PLUGIN:PlaceFurniture(p,2,Vector(50,0,10),Angle()),false)
 assert(PLUGIN:BeginFurnish(p));eq(PLUGIN:MoveFurniture(p,e,Vector(149,0,10),Angle()),false)
 e:Remove();eq(ix.Item.instances[1],nil);eq(db.deleted[1],1);eq(PLUGIN.records[1],nil)
`);

suite('Container restores colliding cells, retains unavailable contents and refuses foreign live ownership',`
 local p=admin();local item=furniture(p,1,'box.mdl');local e=place(p,item)
 local a=furniture(p,2);local b=furniture(p,3);p.inv:TakeItemTable(a);p.inv:TakeItemTable(b)
 assert(e:GetInventory():AddItem(a));assert(e:GetInventory():AddItem(b));PLUGIN:SaveData()
 db.rows[3].x=db.rows[2].x;db.rows[3].y=db.rows[2].y
 local r=PLUGIN.records[1];local saved=PLUGIN:GetData({});saved[1].contents[#saved[1].contents+1]=4
 saved[1].contents[#saved[1].contents+1]=5;PLUGIN:SetData(saved)
 local foreign=furniture(p,5);foreign.data.paint='live';db.rows[5].data='[]'
 e.valid=false;PLUGIN.records={};ix.Item.instances[2]=nil;ix.Item.instances[3]=nil
 PLUGIN:LoadData();flush();r=PLUGIN.records[1]
 eq(#r.storage:GetItemsID(),2);assert(ix.Item.instances[2].x~=ix.Item.instances[3].x)
 eq(ix.Item.instances[5],foreign);eq(foreign.data.paint,'live');eq(foreign.inventory_id,p.inv.id)
 eq(#r.unplacedContents,1);eq(r.unplacedContents[1],4);eq(PLUGIN:PackFurniture(p,r.entity),false)
 PLUGIN:SaveData();local row=PLUGIN:GetData({})[1];assert(table.HasValue(row.contents,4));assert(not table.HasValue(row.contents,5))
 db.rows[4]={item_id=4,unique_id='furn_chair',inventory_type='furnishing_1',data='[]',x=1,y=1}
 PLUGIN:RestoreFurnitureContents(r);flush();eq(#r.storage:GetItemsID(),3);eq(#r.unplacedContents,0)
 PLUGIN:SaveData();r.entity.valid=false;PLUGIN.records={};ix.Item.instances={};ix.Inventory.stored={};p.inv=newInventory(p)
 PLUGIN:LoadData();flush();eq(#PLUGIN.records[1].storage:GetItemsID(),3)
`);
suite('Oversize restore failure retains IDs until retry and legacy container types migrate',`
 local p=admin();local item=furniture(p,1,'box.mdl');local e=place(p,item);local content=furniture(p,2)
 p.inv:TakeItemTable(content);e:GetInventory():AddItem(content);PLUGIN:SaveData()
 local saved=PLUGIN:GetData({});saved[1].storageType=nil;db.rows[2].inventory_type='container';PLUGIN:SetData(saved)
 e.valid=false;PLUGIN.records={};ix.Item.instances={};ix.Inventory.stored={};p.inv=newInventory(p)
 local add=Inventory.AddItem;Inventory.AddItem=function(self,item,...) if self.furnishingRecord then return false end;return add(self,item,...) end
 PLUGIN:LoadData();flush();local r=PLUGIN.records[1];eq(#r.storage:GetItemsID(),0);eq(r.unplacedContents[1],2)
 PLUGIN:SaveData();eq(PLUGIN:GetData({})[1].contents[1],2);eq(db.deleted[2],nil)
 Inventory.AddItem=add;PLUGIN:RestoreFurnitureContents(r);eq(#r.storage:GetItemsID(),1)
 eq(db.rows[2].inventory_type,'furnishing_1');eq(r.storageType,'furnishing_1');eq(#r.unplacedContents,0)
`);
suite('Cleanup cancels orphan reservations, closes native receivers and preserves async storage through removal',`
 local p=admin();local item=furniture(p,1,'box.mdl');local e=place(p,item);local content=furniture(p,2)
 p.inv:TakeItemTable(content);e:GetInventory():AddItem(content);PLUGIN:SaveData()
 e.valid=false;PLUGIN.records={};ix.Item.instances={};ix.Inventory.stored={};p.inv=newInventory(p)
 PLUGIN:LoadData();local q=table.remove(db.queries,1);q.callback({table.Copy(db.rows[1])})
 local r=PLUGIN.records[1];e=r.entity;local inv=r.storage;assert(r.loadingContents)
 inv.storageInfo={entity=e};inv:AddReceiver(p);p.ixOpenStorage=inv
 inv.reservations={[81]=true};ix.Inventory.pendingTransfers[81]={from_id=p.inv.id,to_id=inv.id,items={2}};ix.Inventory.pendingTransfers.item_2=81
 PLUGIN:PreCleanupMap();eq(ix.Inventory.pendingTransfers[81],nil);eq(ix.Inventory.pendingTransfers.item_2,nil)
 eq(inv.reservations[81],nil);eq(p.ixOpenStorage,nil);eq(inv.storageInfo,nil);eq(next(inv.receivers),nil)
 e:Remove();PLUGIN:PostCleanupMap();eq(r.storage,inv);eq(inv.owner,r.entity);flush()
 eq(#inv:GetItemsID(),1);eq(r.loadingContents,nil)
 local old=r.entity;old:SetMoney(20);old:Remove();assert(IsValid(r.entity));assert(r.entity~=old)
 eq(r.storage,inv);eq(inv.owner,r.entity);eq(r.entity:GetMoney(),20);eq(db.deleted[1],nil)
 eq(PLUGIN:GetData({})[1].contents[1],2)
`);
suite('Native overlapping SQL callbacks preserve the live item moved after cold hydration',`
 local p=admin();local item=furniture(p,7);p.inv:TakeItemTable(item);item.inventory_type='container';item:Save()
 local stale=table.Copy(db.rows[7]);ix.Item.instances[7]=nil
 local created=0;function ITEM:OnInstanced() created=created+1 end
 local callbacks=0;local completed=0
 for i=1,2 do ix.Item:LoadInstanceByID(7,function(v) callbacks=callbacks+1;loaded=v end,function() completed=completed+1 end) end
 local first=table.remove(db.queries,1);first.callback({table.Copy(stale)})
 eq(created,1);eq(loaded.data.paint,'blue');eq(loaded.inventory_type,'container')
 local live=loaded;assert(p.inv:AddItem(live));live.data.paint='changed after query';live.character_id=p.character.id;live.mark_as_save=true
 local x,y=live.x,live.y;local second=table.remove(db.queries,1);second.callback({table.Copy(stale)})
 eq(callbacks,2);eq(completed,2);eq(loaded,live);eq(created,1);eq(live.data.paint,'changed after query')
 eq(live.inventory_id,p.inv.id);eq(live.inventory_type,'main');eq(live.x,x);eq(live.y,y);eq(live.mark_as_save,true)
`);

run('Legacy buildables keep native initialization, faction checks, finite/reach gates, and consume only successful spawn',env+source(['helix/gamemode/core/sh_meta.lua'])+`
 ix.meta.Item=ITEM
 local ITEM_DROP_ACTION={};local ITEM_TAKE_ACTION={}
 ${native(itemFile,'function ITEM:Init(uniqueID)','function ITEM:__tostring()')}
 function PLUGIN:AddConstructionToSave(e) self.built=e end
 function net.ReadAngle() return buildAngle or Angle() end
 function net.ReadVector() return buildPos or Vector(50,0,10) end
 `+source(['ixhl2rp/plugins/construction/items/base/buildable.lua'])+`
 local p=admin();local item=furniture(p,1);local B=ix.meta.ItemBuildable
 B.Init(item,item.uniqueID);item.OnPlace=B.OnPlace;item.wallMount=true;item.player=p
 assert(item.functions.take and item.functions.drop and item.functions.place);eq(item.uniqueID,'furn_chair')
 item.factionLock={[2]=true};eq(item.functions.place.OnCanRun(item),false);item.functions.place.OnRun(item);eq(p.build_item,nil)
 item.factionLock=nil;item.functions.place.OnRun(item);eq(p.build_item,item)
 p.trace={Hit=true,HitPos=Vector(50,0,10),HitNormal=Vector(0,0,1)}
 buildPos=Vector(999,0,0);net.handlers['build.place'](144,p);eq(db.deleted[1],nil)
 clock=clock+1;buildPos=Vector(0/0,0,0);net.handlers['build.place'](144,p);eq(db.deleted[1],nil)
 clock=clock+1;buildPos=Vector(50,0,10);local original=item.OnPlace;item.OnPlace=function() return nil end
 net.handlers['build.place'](144,p);eq(db.deleted[1],nil);eq(#p.inv:GetItemsID(),1)
 clock=clock+1;item.OnPlace=original;net.handlers['build.place'](144,p);eq(db.deleted[1],1);eq(p.build_item,nil);eq(#p.inv:GetItemsID(),0)
 clock=clock+1;net.handlers['build.place'](144,p);eq(db.deleted[1],1)
`);

run('Special furniture and workstations retain their actual entity classes and report spawn success',env+`
 local p=admin();local create=ents.Create
 function ents.Create(class) local e=create(class);if e then function e:SetFuelAmount(v) self.fuel=v end end;return e end
 `+['furn_stove','furn_coffeemachine','factory_recycler','station_combine','gunsmith_bench'].map(name=>
 `ITEM={uniqueID='${name}'}\n`+source(['ixhl2rp/plugins/construction/items/buildable/'+name+'.lua'])+`
 assert(not ix.furnish.Supported(ITEM));local entity=ITEM:OnPlace(p,Vector(20,0,0),Angle());assert(IsValid(entity));assert(entity:GetClass()~='prop_physics')
 failSpawn=true;eq(ITEM:OnPlace(p,Vector(),Angle()),nil);failSpawn=false
 `).join('\n'));
finish();

