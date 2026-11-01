// Read-only characterization of current production contracts. No game/database writes.
// These tests deliberately describe a few existing hazards; passing is not approval
// to retain the hazard or evidence that a future optimization is safe.
const fs = require('fs');
const path = require('path');
const runtime = require('./glua-runtime.cjs');
const { run, finish } = require('./restored-test-runner.cjs');
const root = path.resolve(__dirname, '..');
function section(file, start, end) {
  const s = fs.readFileSync(path.join(root, file), 'utf8');
  const a = s.indexOf(start), b = s.indexOf(end, a + start.length);
  if (a < 0 || b < 0) throw Error('Missing production section: ' + start);
  return runtime(s.slice(a, b));
}
const itemFile = 'helix/gamemode/game/items/sh_item.class.lua';
const invFile = 'helix/gamemode/game/inventory/sh_inventory.class.lua';
const netFile = 'helix/gamemode/core/sh_networking.lua';
const saveMethods = section(itemFile, 'function ITEM:SaveData()', 'function ITEM:CollectSyncData');
const itemSetup = `
ITEM={}; local writes={}; local serialized={}; local n=0
util.TableToJSON=function(data) n=n+1;local key='json'..n;serialized[key]=table.Copy(data);return key end
mysql={Update=function(_,name)
 local q={row={},tableName=name};function q:Update(k,v) self.row[k]=v end
 function q:Where(k,v) self.id=v end
 function q:Execute() writes[#writes+1]=self end;return q end}
function ITEM:GetID() return self.id end
local function item()
 return setmetatable({id=7,x=2,y=3,inventory_type='main',mark_as_save=false,
 data={ammo=2,temp=99},vars_id={'ammo','temp'},vars={ammo={},temp={NoSave=true}}},{__index=ITEM})
end
`;
run('An unmarked item still samples OnSave before encoding persisted fields', itemSetup + saveMethods + `
local v=item();local calls=0;v.OnSave=function(self) calls=calls+1;self.data.ammo=17;self.items={33} end
v:Save();eq(calls,1);eq(#writes,1);eq(serialized[writes[1].row.data].ammo,17)
eq(serialized[writes[1].row.data].temp,nil);eq(serialized[writes[1].row.items][1],33)
v:Save();eq(calls,2);eq(#writes,2)
`);
run('A successful character presave currently invokes item OnSave twice with different player context', itemSetup + saveMethods +
section(itemFile, 'function ITEM:Call(', 'function ITEM:GetOwner(') + `GM={};` +
section('helix/gamemode/core/hooks/sv_hooks.lua', 'function GM:CharacterPreSave(character)', 'timer.Create("ixLifeGuard"') + `
local v=item();local contexts={};v.OnSave=function(self) contexts[#contexts+1]=self.player or false end
local p={GetItems=function() return {v} end,Alive=function() return true end,Health=function() return 70 end}
local c={GetPlayer=function() return p end,SetSavedItems=function(self,x) self.items=x end,SetData=function(self,k,x) self[k]=x end}
GM:CharacterPreSave(c);eq(#contexts,2);eq(contexts[1],false);eq(contexts[2],p)
eq(#writes,1);eq(c.items[1],7);eq(c.health,70)
`);
run('Current item queue isolates a synchronous failure but clears the failed item without retry', `
local Item={};ix.Item=Item;local good=0;local errors=0
ErrorNoHalt=function() errors=errors+1 end
` + section('helix/gamemode/game/items/sh_item.lua', 'function Item:SaveData()', 'function Item:SyncAll(') + `
Item.instances={[1]={SaveData=function() error('injected failure') end},[2]={SaveData=function() good=good+1 end}}
Item.items_to_savedata={[1]=true,[2]=true};Item:Async_SaveData()
eq(good,1);eq(errors,1);eq(next(Item.items_to_savedata),nil)
`);
const rawQuery = section('helix/gamemode/core/libs/thirdparty/sv_mysql.lua', 'function mysql:RawQuery(', '-- A function to add a query to the queue.');
run('SQLite adapter completion is synchronous; an SQL error throws and omits completion callback', `
mysql={module='sqlite'};local calls=0;local fail=false;local qcalls=0
sql={Query=function() qcalls=qcalls+1;if fail then return false end end,QueryValue=function() return 1 end,LastError=function() return 'injected failure' end}
`+rawQuery+`
mysql:RawQuery('UPDATE fixture',function(_,ok) assert(ok);calls=calls+1 end);eq(calls,1)
fail=true;eq(pcall(mysql.RawQuery,mysql,'UPDATE fixture',function() calls=calls+1 end),false)
eq(calls,1);eq(qcalls,2)
`);
run('MySQLOO adapter logs asynchronous SQL errors without invoking completion callback', `
local pending;local calls=0;local errors=0;mysqloo={OPTION_NAMED_FIELDS=1}
mysql={module='mysqloo',connection={query=function() pending={setOption=function() end,start=function() end,lastInsert=function() return 3 end};return pending end}}
ErrorNoHalt=function() errors=errors+1 end
`+rawQuery+`
mysql:RawQuery('UPDATE fixture',function() calls=calls+1 end);eq(calls,0)
pending:onError('injected failure');eq(calls,0);eq(errors,1)
mysql:RawQuery('UPDATE fixture',function(_,ok) assert(ok);calls=calls+1 end)
pending:onSuccess({});eq(calls,1)
`);
run('Character Save preserves presave collection, completion callback then post-save notification', `
local CHAR={};local events={};local pending;local deny=false;ix.char={vars={data={field='data'}}}
hook.Run=function(name) events[#events+1]=name;if name=='CharacterPreSave' and deny then return false end end
util.TableToJSON=function() return 'serialized' end
mysql={Update=function() local q={Update=function() end,Where=function() end};function q:Callback(fn) pending=fn end;function q:Execute() events[#events+1]='submitted' end;return q end}
`+section('helix/gamemode/core/meta/sh_character.lua', 'function CHAR:Save(callback)', '\n\t--- Networks this character')+`
local c=setmetatable({vars={data={}},GetID=function() return 1 end},{__index=CHAR})
c:Save(function() events[#events+1]='callback' end);eq(events[1],'CharacterPreSave');eq(events[2],'submitted');eq(#events,2)
pending();eq(events[3],'callback');eq(events[4],'CharacterPostSave')
deny=true;events={};pending=nil;c:Save();eq(#events,1);eq(pending,nil)
c.isBot=true;events={};c:Save();eq(#events,0)
`);
const inventorySetup=`
local Inventory={};ix.Item={instances={}}
function table.Add(t,src) for _,v in ipairs(src) do t[#t+1]=v end return t end
function table.IsEmpty(t) return next(t)==nil end
function table.Count(t) local n=0;for _ in pairs(t) do n=n+1 end;return n end
function table.HasValue(t,v) for _,x in pairs(t) do if x==v then return true end end;return false end
local function inv(slots) return setmetatable({slots=slots,height=#slots,width=#slots[1]},{__index=Inventory}) end
`+section(invFile,'function Inventory:GetItems()', 'function Inventory:FindPosition(');
run('Inventory queries deduplicate occupied cells, expand bags, return fresh arrays and keep direct-ID semantics', inventorySetup+`
local child=inv({{{3}}});local outer=inv({{{1,2},{1}}})
ix.Item.instances[1]={id=1,uniqueID='bag',inventory=child};ix.Item.instances[2]={id=2,uniqueID='tool'};ix.Item.instances[3]={id=3,uniqueID='tool'}
eq(#outer:GetItemsID(),2);eq(#outer:GetItems(),3);eq(outer:GetItemsCount('tool'),2)
eq(outer:HasItemByID(3),false);eq(outer:HasItemByID(2),true)
local list=outer:GetItems();list[1]=nil;eq(#outer:GetItems(),3)
child.slots[1][1]={};eq(outer:GetItemsCount('tool'),1)
`);
run('Late item instances become visible without a slot mutation; indexes must not freeze missing instance resolution', inventorySetup+`
local outer=inv({{{9}}});eq(#outer:GetItemsID(),1);eq(#outer:GetItems(),0)
ix.Item.instances[9]={id=9,uniqueID='tool'};eq(#outer:GetItems(),1);eq(outer:GetItemsCount('tool'),1)
`);
run('Raw and no-log item loading mutates slots while bypassing InventoryItemAdded', inventorySetup+
section(invFile,'function Inventory:AddItem(item,','function Inventory:AddItemByID(')+`
local outer=inv({{{}}});outer.id=8;outer.type='container';outer.GetItemSize=function() return 1,1 end;outer.CheckSize=function() end
local notifications=0;hook.Run=function() notifications=notifications+1 end
local v={id=11,uniqueID='tool'};ix.Item.instances[11]=v
eq(outer:AddItem(v,1,1,true,true),true);eq(notifications,0);eq(#outer:GetItemsID(),1)
eq(v.inventory_id,8);eq(v.mark_as_save,true)
`);
const networkSetup=`
local PLAYER={};local ENTITY={};local sent={};local message;local Net={players={},entities={},locals={},vars={[2]={stm={}},[3]={parts={}},[4]={parts={}}}}
net.Start=function(name) message={name=name} end;net.WriteUInt=function() end
net.WriteNetVar=function(_,kind,v) message.kind=kind;message.value=istable(v) and table.Copy(v) or v end
net.Send=function(receiver) message.receiver=receiver;sent[#sent+1]=message end
net.Broadcast=function() message.receiver='all';sent[#sent+1]=message end
function PLAYER:ClearNetVar(key,receiver) self.cleared={key=key,receiver=receiver} end
function PLAYER:ClearLocalVar(key) self.cleared={key=key} end
`+section(netFile,'function ENTITY:SetNetVar(', 'function ENTITY:ClearNetVar(');
run('Same-table updates and identical values for different recipients currently send distinct messages', networkSetup+`
local p=setmetatable({EntIndex=function() return 5 end},{__index=PLAYER});local parts={a=true}
p:SetNetVar('parts',parts,'alice');parts.b=true;p:SetNetVar('parts',parts,'bob')
eq(#sent,2);eq(sent[1].value.b,nil);eq(sent[2].value.b,true);eq(sent[2].receiver,'bob')
p:SetNetVar('parts',false,'alice');eq(sent[3].value,false)
p:SetNetVar('parts',nil,'alice');eq(#sent,3);eq(p.cleared.key,'parts')
`);
run('Repeated equal local values remain network events; client correction hook runs for each received value', networkSetup+`
local p=setmetatable({EntIndex=function() return 5 end},{__index=PLAYER})
p:SetLocalVar('stm',70);p:SetLocalVar('stm',70);eq(#sent,2)
net.ReadNetVar=function() return 'stm',70 end;local corrections=0
hook.Run=function(name,key,value) eq(name,'OnLocalVarSet');eq(key,'stm');eq(value,70);corrections=corrections+1 end
`+section(netFile,'net.Receive("rp.net.local",', 'net.Receive("rp.net.entity",')+`
net.handlers['rp.net.local']();net.handlers['rp.net.local']();eq(corrections,2)
`);
finish();
