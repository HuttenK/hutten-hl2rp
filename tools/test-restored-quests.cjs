// Meaningful server contract tests. No game process or network connection is started.
const fs=require('fs'),path=require('path'),assert=require('assert');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
const {native}=require('./restored-test-runner.cjs');
const root=path.resolve(__dirname,'..'),base='ixhl2rp/plugins/quest_director/';
let passed=0;
const fixture=String.raw`
SERVER=true;CLIENT=false;PLUGIN={};ix={questDirector={},skills={list={medicine={}}},specials={list={in_={}}},Inventory={pendingTransfers={}}}
unpack=table.unpack
function isstring(v) return type(v)=='string' end
function isnumber(v) return type(v)=='number' end
function istable(v) return type(v)=='table' end
function IsValid(v) return type(v)=='table' and v.valid==true end
function math.Clamp(v,a,b) return math.max(a,math.min(b,v)) end
function math.Round(v) return math.floor(v+.5) end
function table.Copy(v) if type(v)~='table' then return v end local out={} for k,x in pairs(v) do out[table.Copy(k)]=table.Copy(x) end return out end
function string.Trim(v) return v:match('^%s*(.-)%s*$') end
function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local V={};V.__index=V
function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
function V:DistToSqr(b) return (self.x-b.x)^2+(self.y-b.y)^2+(self.z-b.z)^2 end
function V.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
function V.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
function Angle(p,y,r) return {p=p,y=y,r=r} end
clock=100;wall=10000
function CurTime() return clock end;os.time=function() return wall end
timer={Simple=function(_,fn) fn() end};hook={Run=function() end,Add=function() end}
util={TraceLine=function() return {Hit=blockedLOS or false,Entity=nil} end,IsInWorld=function() return true end,IsValidModel=function(p) return p~='models/missing.mdl' end,AddNetworkString=function() end}
local json,seq={},0
function util.TableToJSON(value) seq=seq+1 local raw='serialized_'..seq json[raw]=table.Copy(value) return raw end
function util.JSONToTable(raw) return table.Copy(json[raw]) end
file={data={},CreateDir=function() end}
function file.Write(p,s) if not breakDisk then file.data[p]=s end end
function file.Read(p) return file.data[p] end
Schema={folder='test'};game={GetMap=function() return 'test_map' end};function ErrorNoHalt(s) lastError=s end
allPlayers={};player={GetAll=function() return allPlayers end}
net={handlers={},reads=0,values={}}
function net.Receive(k,fn) net.handlers[k]=fn end
function net.ReadUInt() net.reads=net.reads+1 return table.remove(net.values,1) end
function net.ReadData() net.reads=net.reads+1 return net.raw end
function net.Start(n) net.channel=n end
function net.WriteUInt() end;function net.WriteData(s) net.last=util.JSONToTable(s) end
function net.WriteString() end;function net.Send(p) net.recipient=p end
properties={Add=function() end,CanBeTargeted=function() return true end}
MOVETYPE_NOCLIP=8
local EntityMeta={};EntityMeta.__index=EntityMeta
function EntityMeta:GetPos() return self.pos or Vector() end
function EntityMeta:WorldSpaceCenter() return self:GetPos() end
function EntityMeta:GetClass() return self.class end
function EntityMeta:SetModel(v) self.model=v end
function EntityMeta:SetPos(v) self.pos=v end
function EntityMeta:SetAngles(v) self.ang=v end
function EntityMeta:Spawn() end;function EntityMeta:Activate() end;function EntityMeta:ApplyDefinition() end
function EntityMeta:SetNetVar() end;function EntityMeta:Remove() self.valid=false end
ents={Create=function(class) return setmetatable({valid=true,class=class},EntityMeta) end}
instances=0;ix.Item={instances={}}
function ix.Item:Get(id) if id=='bandage' then return {uniqueID=id,name=id} end end
function ix.Item:Instance(id)
 instances=instances+1
 local item={id=instances,uniqueID=id,items={}}
 function item:Remove(deleted) eq(deleted,true);self.deleted=true;ix.Item.instances[self.id]=nil end
 function item:GetData(k,default) return default end
 self.instances[item.id]=item;return item
end
function ix.Item:LoadInstanceByID(id,each,done) if storedItem and storedItem.id==id then self.instances[id]=storedItem;each(storedItem) end done() end
function actor(id,admin)
 local p=setmetatable({valid=true,id=id,admin=admin,pos=Vector(),inventory={items={}},money=0},EntityMeta)
 function p:IsPlayer() return true end;function p:IsAdmin() return self.admin==true end;function p:IsSuperAdmin() return false end
 function p:Alive() return self.alive~=false end;function p:GetMoveType() return 0 end
 function p:SteamID() return 'STEAM_'..self.id end;function p:SteamID64() return '7656'..self.id end
 function p:EntIndex() return self.id end;function p:GetCharacter() return self.char end
 function p:EyePos() return self:GetPos() end;function p:EyeAngles() return Angle(0,0,0) end
 function p:GetEyeTrace() return {Hit=true,HitPos=Vector(5,0,0),HitNormal=Vector(0,0,1)} end
 function p:Notify(s) self.notice=s end;function p:GetInventory() return self.inventory end;function p:GetBackpack() return nil end
 function p.inventory:GetItems() local out={} for _,item in pairs(self.items) do if not item.deleted then out[#out+1]=item end end return out end
 function p:AddItem(item) if self.noFit then return false end item.inventory_id=self.id;self.inventory.items[#self.inventory.items+1]=item;return true end
 local c={id=id,owner=p,money=0,xp=0,skillXP=0}
 function c:GetID() return self.id end;function c:GetName() return 'Character '..self.id end
 function c:GetSkillModified() return 2 end;function c:GetSpecial() return 3 end
 function c:GetSkills() return {medicine={1,0}} end
 function c:GiveMoney(n) self.money=self.money+n end;function c:AddLevelXP(n) self.xp=self.xp+n end
 function c:UpdateSkillProgress(_,n) self.skillXP=self.skillXP+n end
 function c:Save(cb) if holdSave then self.callback=cb else cb() end end
 p.char=c;allPlayers[#allPlayers+1]=p;return p
end
admin=actor(1,true);guest=actor(2,false);other=actor(3,false)
`;
const files=['sh_model.lua','sv_store.lua','sv_runtime.lua','sv_editor.lua','sv_network.lua','sh_placement_tools.lua'];
const setup=String.raw`
Q=ix.questDirector;Q.loaded=true
function install()
 local ok,npc=Q:Put(admin,'npc',{name='Coordinator',enabled=true,model='models/Humans/Group01/male_07.mdl',start='start',nodes={{id='start',text='Hello',options={{text='Inspect',action='event',target='talk'}}}}})
 assert(ok,npc);npcID=npc.id
 local ok,quest=Q:Put(admin,'quest',{name='Assignment',enabled=true,npc=npcID,repeatable=false,reward={money=10,xp=5,items={{item='bandage',count=1}},skills={{skill='medicine',xp=3}}},objectives={{id='inspect',name='Inspect crate',type='use',target='crate',count=1}}})
 assert(ok,quest);questID=quest.id
 local ok,obj=Q:Put(admin,'object',{name='Crate',enabled=true,target='crate',quest=questID,model='models/props_junk/wood_crate001a.mdl'})
 assert(ok,obj);objectID=obj.id
 local ok,place=Q:Place(admin,'npc',npcID);assert(ok,place);npcPlace=place.id
 local ok,place=Q:Place(admin,'object',objectID);assert(ok,place);objectPlace=place.id
end
function start(p)
 local ok,v=Q:GroupOpen(p,npcPlace,questID);assert(ok,v)
 local ok,msg=Q:Start(p,{placement=npcPlace,group=v.group});assert(ok,msg)
 return Q.runs[v.group]
end
function finish(p,r)
 local ok,msg=Q:Interact(p,{placement=objectPlace,run=r.id,objective='inspect',amount=9999});assert(ok,msg)
 eq(r.progress.inspect,1);local ok,msg=Q:Finish(p,npcPlace,r.id);assert(ok,msg)
 for _,v in pairs(Q:State(p.char.id).receipts) do return v end
end
`;
function test(name,body,extra=''){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const source=[fixture,...files.map(f=>'do\n'+normalize(fs.readFileSync(path.join(root,base,f),'utf8'))+'\nend'),setup,extra,body].join('\n');
 const status=lauxlib.luaL_dostring(L,to_luastring(source));
 if(status!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
 console.log('PASS '+name);passed++;
}
test('Shared schema rejects malformed arrays, duplicate goals, unsafe models and non-finite checks',String.raw`
 eq(Q:Clean('npc',{model='../../evil.mdl'}),nil)
 eq(Q:Clean('quest',{objectives={{id='same',type='use'},{id='same',type='use'}}}),nil)
 eq(Q:Clean('quest',{objectives={[2]={id='gap',type='use'}}}),nil)
 eq(Q.Number(0/0,10,0,100),10)
 local check=Q:CleanCheck({difficulty=math.huge,skillWeight=-1,retry=0});eq(check.difficulty,0);eq(check.skillWeight,0);eq(check.retry,1)
 assert(Q:Roll(guest.char,Q:CleanCheck({skill='medicine',difficulty=2})))
`);
test('Admin authoring enforces live roles, revisions, dependencies and transactional simple creation',String.raw`
 eq(Q:Put(guest,'npc',{name='Forged'}),false)
 eq(Q:Handle(guest,'admin_list',{kind='npc'}),false)
 install();local copy=table.Copy(Q.defs.quest[questID]);copy.description='changed';assert(Q:Put(admin,'quest',copy))
 eq(Q:Put(admin,'quest',copy),false)
 eq(Q:DeleteDefinition(admin,{kind='npc',id=npcID,revision=1}),false)
 local before=Q.serial;local ok=Q:CreateSimple(admin,{name='Bad',npcModel='models/missing.mdl'});eq(ok,false)
 local n=0 for _ in pairs(Q.defs.quest) do n=n+1 end eq(n,1)
 admin.admin=false;eq(Q:Handle(admin,'admin_put',{kind='quest',record=copy}),false)
`);
test('Single quest runs use immutable snapshots and cannot be progressed or finished by outsiders',String.raw`
 install();local r=start(guest);local copy=table.Copy(Q.defs.quest[questID]);copy.objectives[1].count=9;assert(Q:Put(admin,'quest',copy))
 eq(r.quest.objectives[1].count,1)
 eq(Q:Interact(other,{placement=objectPlace,run=r.id,objective='inspect'}),false)
 eq(Q:Finish(other,npcPlace,r.id),false)
 eq(#Q:Journal(other).runs,0)
 guest.pos=Vector(999,0,0);eq(Q:Interact(guest,{placement=objectPlace,run=r.id,objective='inspect'}),false)
 guest.pos=Vector();blockedLOS=true;eq(Q:Finish(guest,npcPlace,r.id),false);blockedLOS=false
 local receipt=finish(guest,r);eq(receipt.status,'pending');eq(Q:CanJoin(guest,Q.defs.quest[questID],true),false)
`);
test('Group consent is bound to the recipient character and rechecked for distance and quorum at start',String.raw`
 install();local q=Q.defs.quest[questID];q.maxMembers=3;q.minMembers=2;q.requireTogether=true
 local ok,v=Q:GroupOpen(guest,npcPlace,questID);assert(ok)
 eq(Q:Start(guest,{placement=npcPlace,group=v.group}),false)
 assert(Q:Invite(guest,{placement=npcPlace,group=v.group,character=other.char.id,entity=other.id}))
 local token;for k in pairs(Q.invites) do token=k end
 eq(Q:Accept(admin,{token=token,accept=true}),false)
 assert(Q:Accept(other,{token=token,accept=true}));eq(Q:Accept(other,{token=token,accept=true}),false)
 other.pos=Vector(1000,0,0);eq(Q:Start(guest,{placement=npcPlace,group=v.group}),false)
 other.pos=Vector();assert(Q:Start(guest,{placement=npcPlace,group=v.group}));local r=Q.runs[v.group]
 assert(Q:RemoveMember(guest,{placement=npcPlace,group=r.id,character=other.char.id}));eq(#r.participants,2)
 eq(Q:Interact(guest,{placement=objectPlace,run=r.id,objective='inspect'}),false)
`);
test('Ordered events do not cascade; damage weapon filters and dialogue sessions reject forgery',String.raw`
 install();local q=Q.defs.quest[questID];q.objectives={
 {id='one',name='One',type='damage',target='crate',count=10,weapon='weapon_pistol',check=Q:CleanCheck()},
 {id='two',name='Two',type='damage',target='crate',count=10,weapon='',check=Q:CleanCheck()}}
 local r=start(guest)
 eq(Q:Advance(guest,'damage','crate',10,{weapon='weapon_crowbar'}),0)
 eq(Q:Advance(guest,'damage','crate',20,{weapon='weapon_pistol'}),10);eq(r.progress.two,nil)
 eq(Q:Choose(guest,{placement=npcPlace,option=1}),false)
 local ok,v=Q:Dialogue(guest,npcPlace);assert(ok);eq(v.name,'Coordinator');assert(v.session)
 eq(Q:Choose(guest,{placement=npcPlace,option=99}),false)
 guest.char=other.char;eq(Q:Choose(guest,{placement=npcPlace,option=1}),false)
`);
test('Deposits use the actual delete API, persist intent and prevent replay during asynchronous character save',String.raw`
 install();local goal=Q.defs.quest[questID].objectives[1];goal.type='deposit';goal.item='bandage';goal.count=2
 local r=start(guest);guest.inventory.items={ix.Item:Instance('bandage'),ix.Item:Instance('bandage')}
 holdSave=true
 assert(Q:Interact(guest,{placement=objectPlace,run=r.id,objective='inspect',amount=2}));assert(r.deposit);eq(r.progress.inspect,nil)
 eq(#guest.inventory:GetItems(),0)
 eq(Q:Interact(guest,{placement=objectPlace,run=r.id,objective='inspect',amount=2}),false)
 eq(Q:Handle(admin,'admin_deposit',{id=r.id,delivered=true}),false)
 guest.char.callback();eq(r.progress.inspect,2);eq(r.deposit,nil)
`);
test('Deposits accept native ordinary items with empty contents and exclude bags, contents, equipment and reservations',String.raw`
 install();local goal=Q.defs.quest[questID].objectives[1];goal.type='deposit';goal.item='bandage';goal.count=2
 local r=start(guest);local stock=ix.Item:Instance('bandage');ix.Item.stored={bandage=stock}
 function ix.Item:ResolveID(id) return id end
 local ordinary=ix.Item:New('bandage',601);eq(next(ordinary.items),nil)
 local bag=ix.Item:New('bandage',602);bag.isBag=true
 local filled=ix.Item:New('bandage',603);filled.items={44}
 local pending=ix.Item:New('bandage',604);ix.Inventory.pendingTransfers.item_604=12
 local equipped=ix.Item:New('bandage',605);function equipped:GetData(k,d) return k=='equip' and true or d end
 guest.inventory.items={ordinary,bag,filled,pending,equipped}
 eq(Q:Interact(guest,{placement=objectPlace,run=r.id,objective='inspect',amount=2}),false);eq(ordinary.deleted,nil)
 assert(Q:Interact(guest,{placement=objectPlace,run=r.id,objective='inspect',amount=1}));eq(ordinary.deleted,true);eq(r.progress.inspect,1)
 eq(bag.deleted,nil);eq(filled.deleted,nil);eq(pending.deleted,nil);eq(equipped.deleted,nil)
`, 'do local Item=ix.Item\n'+native('helix/gamemode/game/items/sh_item.lua','function Item:New(uniqueID, forcedID)','if SERVER then')+'\nend');
test('Reward steps award money, level XP, skill XP and one item exactly once',String.raw`
 install();local receipt=finish(guest,start(guest));local d={placement=npcPlace,receipt=receipt.id}
 for i=1,4 do assert(Q:Claim(guest,d,false)) end
 eq(guest.char.money,10);eq(guest.char.xp,5);eq(guest.char.skillXP,3);eq(instances,1);eq(receipt.status,'claimed')
 assert(Q:Claim(guest,d,false));eq(guest.char.money,10);eq(instances,1)
 eq(Q:Claim(other,d,false),false)
`);
test('Full inventory preserves a single pending item across claim retries',String.raw`
 install();Q.defs.quest[questID].reward={money=0,xp=0,skills={},mode='each',items={{item='bandage',count=1,chance=100}}}
 local receipt=finish(guest,start(guest));local d={placement=npcPlace,receipt=receipt.id};guest.noFit=true
 eq(Q:Claim(guest,d,false),false);eq(receipt.status,'pending');eq(instances,1);assert(receipt.pendingItem)
 eq(Q:Claim(guest,d,false),false);eq(instances,1)
 guest.noFit=false;assert(Q:Claim(guest,d,false));eq(instances,1);eq(receipt.status,'claimed')
`);
test('Interrupted payout stays applying and cannot replay; admin recovery uses an expected cursor',String.raw`
 install();local receipt=finish(guest,start(guest));local d={placement=npcPlace,receipt=receipt.id};holdSave=true
 local ok,status=Q:Claim(guest,d,false);assert(ok);assert(status.waiting);eq(guest.char.money,10)
 Q.claiming={};eq(Q:Claim(guest,d,false),false);eq(guest.char.money,10)
 eq(Q:AdminReceipt(admin,{receipt=receipt.id,delivered=true,cursor=9}),false)
 assert(Q:AdminReceipt(admin,{receipt=receipt.id,delivered=true,cursor=1}));eq(receipt.cursor,2)
 guest.char.callback();eq(receipt.cursor,2)
 holdSave=false;assert(Q:Claim(guest,d,false));eq(guest.char.money,10);eq(guest.char.xp,5)
`);
test('Deadline, prerequisite delay, reputation and cooldown checks remain server-owned',String.raw`
 install();local q=Q.defs.quest[questID];q.duration=10;q.failureCooldown=50
 local npc=Q.defs.npc[npcID];npc.reputation.enabled=true;q.reputation.success=5
 local r=start(guest);wall=wall+11;eq(Q:Finish(guest,npcPlace,r.id),false)
 eq(Q:CanJoin(guest,q,true),false);wall=wall+51
 local r=start(guest);local receipt=finish(guest,r);eq(Q:State(guest.char.id).reputation[npcID],5)
 q.repeatable=true;q.reputation.required=true;q.reputation.minimum=6;eq(Q:CanJoin(guest,q,true),false)
`);
test('Per-map alternating snapshots recover the last valid generation and freeze mutations on storage failure',String.raw`
 install();local r=start(guest);assert(Q:Save());local prior=Q.generation
 assert(Q:Save());file.data[Q:StorePath()..(Q.generation%2)..'.json']='truncated'
 Q.loaded=false;Q.runs={};Q:Load();eq(Q.generation,prior);assert(Q.runs[r.id])
 breakDisk=true;eq(Q:Save(),false);assert(Q.storageFault)
 local before=Q.serial;eq(Q:Put(admin,'npc',{name='lost'}),false);eq(Q:CreateSimple(admin,{name='lost'}),false);eq(Q.serial,before)
 eq(Q:Handle(guest,'abandon',{run=r.id}),false);assert(Q.runs[r.id])
`);
test('Zone visits trigger on entry, not every tick, and character switches clear the occupancy cache',String.raw`
 install();Q.defs.quest[questID].objectives[1].type='zone';Q.defs.quest[questID].objectives[1].target='room';Q.defs.quest[questID].objectives[1].count=2
 local r=start(guest);Q.zones.z={target='room',pos={0,0,0},radius=32}
 PLUGIN:Think();eq(r.progress.inspect,1);clock=clock+2;PLUGIN:Think();eq(r.progress.inspect,1)
 guest.pos=Vector(50,0,0);clock=clock+2;PLUGIN:Think();guest.pos=Vector();clock=clock+2;PLUGIN:Think();eq(r.progress.inspect,2)
`);
test('Network framing rejects malformed and oversized packets before dispatch and denies forged admin actions',String.raw`
 net.handlers.ixQDRequest(10,guest);eq(net.reads,0)
 net.handlers.ixQDRequest(99999999,guest);eq(net.reads,0)
 net.values={1,500};net.handlers.ixQDRequest(64,guest);eq(net.reads,2)
 clock=clock+1;net.raw=util.TableToJSON({action='admin_examples',data={}});net.values={1,#net.raw}
 net.handlers.ixQDRequest((#net.raw+4)*8,guest);eq(net.last.ok,false);eq(next(Q.defs.quest),nil)
`);
for(const file of fs.readdirSync(path.join(root,base),{recursive:true}).filter(x=>x.endsWith('.lua'))){
 const L=lauxlib.luaL_newstate();
 const status=lauxlib.luaL_loadstring(L,to_luastring(normalize(fs.readFileSync(path.join(root,base,file),'utf8'))));
 assert.equal(status,lua.LUA_OK,file+': '+(status?to_jsstring(lua.lua_tostring(L,-1)):''));
}
console.log('PASS all restored client/server/entity Lua files parse');passed++;
const client=fs.readdirSync(path.join(root,base)).filter(f=>f.startsWith('cl_')).map(f=>fs.readFileSync(path.join(root,base,f),'utf8')).join('\n');
assert(!/ix\.mapedit|\/MapEdit|admin_sector_examples/.test(client));
const server=fs.readFileSync(path.join(root,base,'sv_network.lua'),'utf8');
for(const action of ['journal','dialogue','choose','group_open','group_view','invite','accept','start','remove_member','interact','finish','abandon','claim','claim_status','admin_list','admin_get','admin_put','admin_create_quest','admin_overview','admin_goal_object','admin_publish','admin_cancel','admin_delete','admin_receipt','admin_reputation','admin_examples','admin_place','admin_move','admin_unplace','admin_placements','admin_zone','admin_deposit']) assert(server.includes('"'+action+'"'),action);
for(const panel of [...client.matchAll(/(?:vgui\.Create|:Add)\("([A-Za-z0-9_]+)"/g)].map(m=>m[1])) assert(new Set(['DPanel','DLabel','DNumSlider','DTextEntry','DListView','DModelPanel','DPropertySheet','DScrollPanel','DFrame','DButton','DComboBox','DNumberWang','ContentIcon','ModelImage','DIconLayout','DCheckBoxLabel','DCollapsibleCategory']).has(panel),panel);
console.log('PASS recovered widget and request contracts use standard panels and available handlers');passed++;
console.log(passed+' restored quest suites passed.');
