module.exports=suite=>{
const client='ixhl2rp/plugins/field_equipment/cl_equipment.lua';
const pickupSetup=`
 CLIENT=true; SERVER=false; ix.field={}; ix.gui={}
 function Color(...) return {...} end
 surface={CreateFont=function() end}
 local message
 net.ReadString=function() return message end
 function ReceiveAction(name) message=name;net.handlers.ixFieldAnim() end
 function InstallAnimations()
  VManip={Anims={},registrations=0,plays={}}
  function VManip:GetAnim(name) return self.Anims[name] end
  function VManip:RegisterAnim(name,data)
   self.registrations=self.registrations+1;self.Anims[name]=data
  end
  function VManip:PlayAnim(name)
   assert(self.Anims[name], 'animation is not registered: '..name)
   self.plays[#self.plays+1]=name;return true
  end
 end
`;
suite('Workshop-only pickup registers its gesture before the first playback and keeps the inventory open',[client],`
 local menu={valid=true,Remove=function() error('pickup closed the inventory') end};ix.gui.menu=menu
 ReceiveAction('ix_field_pickup');eq(VManip.plays[1],'ix_field_pickup')
 local anim=VManip:GetAnim('ix_field_pickup')
 eq(anim.model,'c_vmanipinteract.mdl');eq(anim.loop,false);near(anim.startcycle,.1)
 ReceiveAction('ix_field_pickup');eq(#VManip.plays,2);eq(VManip.registrations,1)
`,pickupSetup+`InstallAnimations()`);
suite('Pickup tolerates an absent animation library and registers after late loading or registry replacement',[client],`
 ReceiveAction('ix_field_pickup')
 InstallAnimations();ReceiveAction('ix_field_pickup');eq(#VManip.plays,1)
 VManip.Anims={};ReceiveAction('ix_field_pickup');eq(#VManip.plays,2);eq(VManip.registrations,2)
`,pickupSetup);
suite('An existing companion pickup definition is reused and non-pickup field animations stay unchanged',[client],`
 local existing={model='c_vmanipinteract.mdl',speed=1.2}
 VManip.Anims.ix_field_pickup=existing
 ReceiveAction('ix_field_pickup');eq(VManip.registrations,0);eq(VManip.Anims.ix_field_pickup,existing)
 VManip.Anims.nvg_aviators_in={}
 local closed=0;ix.gui.menu={valid=true,Remove=function() closed=closed+1 end}
 ReceiveAction('nvg_aviators_in');eq(VManip.plays[2],'nvg_aviators_in');eq(VManip.registrations,0);eq(closed,1)
`,pickupSetup+`InstallAnimations()`);
const shared='ixhl2rp/plugins/field_equipment/sh_plates.lua';
const server='ixhl2rp/plugins/field_equipment/sv_equipment.lua';
const setup=`
ix.field={}; ix.config={Add=function() end,Get=function(_,v) return v end}
HITGROUP_HEAD=1; HITGROUP_CHEST=2; HITGROUP_STOMACH=3; HITGROUP_LEFTARM=4; HITGROUP_RIGHTARM=5; HITGROUP_LEFTLEG=6; HITGROUP_RIGHTLEG=7
SERVER=true; tick=0; engine={TickCount=function() return tick end}
function vest(cap,plates)
 local v={id=1,plateCapacity=cap,data={plates=plates or {}}}
 function v:GetData(k,d) return self.data[k] or d end
 function v:SetData(k,d) self.data[k]=d end
 function v:GetEntity() return nil end
 return v
end
`;
suite('Carriers start empty; sequential 60 pistol / 30 rifle hits; torso/arms protected, head/legs untouched',[shared],`
 local F=ix.field; local v=vest(3); local p={char_outfit={armor={[v]=true}}}
 local info={class='bullet',attacker='shooter',weapon={HoldType='pistol'}}
 eq(F.Count(v),0); eq(F.Absorb(p,1,info,100),nil)
 v.data.plates={1,1,1}
 for _,hit in ipairs({HITGROUP_HEAD,HITGROUP_LEFTLEG,HITGROUP_RIGHTLEG}) do
  tick=tick+1; eq(F.Absorb(p,hit,info,100),nil)
  near(v.data.plates[1],1); near(v.data.plates[2],1); near(v.data.plates[3],1)
  eq(v.ixPlateShot,nil)
 end
 for i=1,59 do tick=i; near(F.Absorb(p,2,info,100),25) end
 assert(v.data.plates[1]>0); near(v.data.plates[2],1)
 tick=60; near(F.Absorb(p,4,info,100),25); eq(v.data.plates[1],-1); eq(F.Count(v),2)
 tick=61; near(F.Absorb(p,2,info,100),50)
 local old=v.data.plates[2]; eq(F.Absorb(p,6,info,100),nil); near(v.data.plates[2],old)
 v.data.plates={1,1,1}; v.ixPlateShot=nil; info.weapon.HoldType='ar2'
 for i=1,30 do tick=100+i; F.Absorb(p,2,info,100) end
 eq(v.data.plates[1],-1); near(v.data.plates[2],1)
 local left=v.data.plates[2]; F.Absorb(p,2,info,100); near(v.data.plates[2],left)
 eq(F.Absorb(p,2,{class='burn'},100),nil)
 v.plateCapacity=0; near(F.Absorb(p,2,{class='slash'},100),50)
 eq(F.Absorb(p,1,{class='slash'},100),nil)
 eq(F.Absorb(p,1,{class='bullet'},100),nil)
`,setup);
suite('Plate replacement rejects foreign items; preserves used durability; full inventory cannot lose plates',[shared,server],`
 local F=ix.field; local v=vest(2,{.4,-1}); local plate=vest(0); plate.id=2; plate.uniqueID='mat_armor_plate'; plate.data.plateHealth=.7
 local p={valid=true,items={v,plate},character={}}
 function p:GetCharacter() return self.character end
 function p:Alive() return true end
 function p:InCriticalState() return false end
 function p:IsRestricted() return false end
 function p:HasItemByID(id) for _,v in ipairs(self.items) do if v.id==id then return true end end return false end
 function p:GetItems() return self.items end
 function p:Notify() end
 function p:AddItem(item) if self.full then return false end; self.received=item; return true end
 function plate:Remove() self.removed=true end
 local foreign=vest(2); foreign.id=99
 eq(F.ChangePlate(p,foreign,1,true),false)
 eq(F.ChangePlate(p,v,3,true),false)
 eq(F.ChangePlate(p,v,1,true),false); eq(plate.removed,nil)
 eq(F.ChangePlate(p,v,2,true),true); near(v.data.plates[2],.7); eq(plate.removed,true)
 p.full=true; eq(F.ChangePlate(p,v,1,false),false); near(v.data.plates[1],.4)
 p.full=false; eq(F.ChangePlate(p,v,1,false),true); eq(v.data.plates[1],0); near(p.received.data.plateHealth,.4)
 v.data.plates[1]=-1; eq(F.ChangePlate(p,v,1,false),true); eq(v.data.plates[1],0)

`,setup+`
util={AddNetworkString=function() end}; net={Receive=function() end}; hook={Add=function() end}; timer={Create=function() end}
ix.Item={instances={},Instance=function() local p=vest(0); function p:Remove() self.removed=true end; return p end}
`);
suite('NVG activation requires equipped item, active character and conscious player',[shared,server],`
 local p={valid=true,character={},equipped=false,nw={}}
 function p:GetCharacter() return self.character end
 function p:GetFirstAtSlot() return self.equipped and 1 or nil end
 function p:Alive() return true end
 function p:InCriticalState() return self.critical end
 function p:IsRestricted() return false end
 function p:SetNWBool(k,v) self.nw[k]=v end
 ix.Item.instances[1]={nvgType='nvg_gpnvg',IsEquipped=function() return true end}
 on=true; handlers.arcticnvgs_toggle(1,p); eq(p.nw.nvg_on,nil)
 p.equipped=true; handlers.arcticnvgs_toggle(1,p); eq(p.nw.nvg_on,true)
 on=false; handlers.arcticnvgs_toggle(1,p); eq(p.nw.nvg_on,false)
 p.ixNVGNext=0; p.critical=true; on=true; handlers.arcticnvgs_toggle(1,p); eq(p.nw.nvg_on,false)
 `,setup+`
util={AddNetworkString=function() end}; handlers={}; net={Receive=function(k,f) handlers[k]=f end,ReadBool=function() return on end}
hook={Add=function() end}; timer={Create=function() end}; ix.Item={instances={}}
`);

suite('NVG item registers glasses-slot toggle at load time',
 ['ixhl2rp/plugins/field_equipment/items/cigarette_pack.lua','ixhl2rp/plugins/items_clothing/items/clothes/nvg_gpnvg.lua'],`
 assert(ITEM.functions.toggleNVG)
 eq(ITEM.equip_inv,'glasses'); eq(ITEM.nvgType,'nvg_gpnvg')
 `,`
 ITEM={functions={},registered={},AddData=function(self,k) self.registered[k]=true end}
 ix.transmit={owner=1}
 `);


suite('Inventory rejects missing rows, fractional coordinates and stale stack anchors',
 ['helix/gamemode/game/inventory/sh_inventory.class.lua'],`
 local inv=ix.meta.Inventory:New(); inv.width=2; inv.height=2; inv.slots={{{1},{}}}
 eq(inv:GetSlot(1,2),nil); eq(inv:GetSlot(nil,1),nil); eq(inv:GetSlot(1.5,1),nil)
 eq(inv:GetSlot(0,1),nil); eq(inv:GetSlot(3,1),nil); eq(inv:GetSlot(1,1)[1],1)
 eq(inv:CanStack(nil,nil),false)
 ix.Item.instances[1]={id=1,inventory_id=inv.id,x=1,y=2}
 eq(inv:MoveStack({1},1,1,false),false)
 ix.Item.instances[1].y=1
 ix.Item.instances[2]={id=2,inventory_id=inv.id,x=2,y=1}
 eq(inv:MoveStack({1,2},1,1,false),false); eq(inv.slots[1][1][1],1)
 `,`ix.Inventory={stored={}}; ix.Item={instances={}}; table.HasValue=function(t,v) for _,x in pairs(t) do if x==v then return true end end return false end`);
suite('Only pickups trigger generic gestures; cigarette packs have no smoking action',[shared,server,'ixhl2rp/plugins/field_equipment/items/cigarette_pack.lua'],`
 eq(ix.field.Smoke,nil); eq(ITEM.functions.smoke,nil)
 eq(handlers.PlayerItemActionFinished,nil)
 local sent; ix.field.Animate=function(_,name) sent=name end
 handlers.PlayerPickedUpInventoryItem({}); eq(sent,'ix_field_pickup')
 sent=nil; handlers.OnItemEquipped({}, {equip_inv='vest'}); eq(sent,nil)
 `,setup+`
 ITEM={functions={}}; handlers={}; hook={Add=function(k,_,f) handlers[k]=f end}; timer={Create=function() end}
 `);

suite('Third-person poses write only in bone build; skip invalid/unused bones and expire stale models',
 ['addons/legends_field_actions/lua/gcal/gcal_tpik.lua'],`
 local apply=GCAL.InstallTPIK({}).ApplyCachedThirdPersonBones
 local p={valid=true,model='citizen',writes=0,callbacks=0}
 function p:GetModel() return self.model end
 function p:GetBoneName(b) return b==1 and '__INVALIDBONE__' or 'bone' end
 function p:BoneHasFlag(b) return b~=2 end
 function p:GetBoneMatrix(b) return {} end
 function p:AddCallback(name,f) eq(name,'BuildBonePositions'); self.cb=f; self.callbacks=self.callbacks+1; return 1 end
 function p:InvalidateBoneCache() end
 function p:SetupBones() self.building=true; self.cb(self,3); self.building=false end
 function p:SetBoneMatrix(b,m) assert(self.building); eq(b,0); self.writes=self.writes+1 end
 function p:SetBonePosition() error('duplicate position write') end
 local track={thirdpersonBoneMatrices={[0]={},[1]={},[2]={},[8]={}}}
 eq(apply(track,p),true); eq(p.writes,1); eq(p.callbacks,1)
 apply(track,p); eq(p.writes,2); eq(p.callbacks,1)
 frame=2; p:SetupBones(); eq(p.writes,2)
 frame=1; p.model='different'; p:SetupBones(); eq(p.writes,2)
 p.model='citizen'; p.ixGCALReadingBase=true; p:SetupBones(); eq(p.writes,2)
 `,`CLIENT=true; SERVER=false; GCAL={}; function CreateMaterial() return {GetName=function() return 'hidden' end} end; frame=1; function FrameNumber() return frame end; BONE_USED_BY_ANYTHING=0x7ff00`);

suite('Item updates use stable keys across different field orders and preserve explicit false',
 ['helix/gamemode/game/items/sh_item.class.lua'],`
 local a=ix.meta.Item:New('vest'); a.id=17
 a:AddData('plates',{Transmit=0}); a:AddData('enabled',{Transmit=0})
 a:AddData('plates',{Transmit=0})
 eq(a.vars.plates.index,1); eq(a.vars.enabled.index,2); eq(a.vars_id[1],'plates'); eq(a.vars_id[2],'enabled')
 local b=ix.meta.Item:New('vest'); b.id=17
 b:AddData('unrelated',{Transmit=0}); b:AddData('enabled',{Transmit=0}); b:AddData('plates',{Transmit=0})
 b.var_max_bits=7; a.var_max_bits=2; ix.Item.instances[17]=b
 a.data.enabled=true; net.WriteItemData(a,'enabled',false)
 local item,key,value=net.ReadItemData(); eq(item,b); eq(key,'enabled'); eq(value,false)
 wire={}; cursor=0; a.data.plates={1,.5,-1}; net.WriteItemData(a,'plates')
 item,key,value=net.ReadItemData(); eq(key,'plates'); eq(value[2],.5); eq(value[3],-1)
 wire={}; cursor=0; a.vars.enabled.Write=function(_,v) net.WriteUInt(v,6) end
 b.vars.enabled.Read=function() return net.ReadUInt(6) end
 net.WriteItemData(a,'enabled',31); item,key,value=net.ReadItemData(); eq(value,31)
 wire={}; cursor=0; b.vars.enabled.Read=nil
 net.WriteItemData(a,'enabled',31); eq(net.ReadItemData(),nil)
 `,`
 ix.Item={instances={}}; ix.transmit={none=0}; bit={band=function() return 0 end}
 function table.Count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
 net.ChooseOptimalBits=function(n) return 4 end
 wire={}; cursor=0
 local function write(kind,v,bits) wire[#wire+1]={kind=kind,value=v,bits=bits} end
 local function read(kind,bits) cursor=cursor+1; local t=wire[cursor]; eq(t.kind,kind); eq(t.bits,bits); return t.value end
 net.WriteUInt=function(v,b) write('uint',v,b) end; net.ReadUInt=function(b) return read('uint',b) end
 net.WriteString=function(v) write('string',v) end; net.ReadString=function() return read('string') end
 net.WriteBool=function(v) write('bool',v) end; net.ReadBool=function() return read('bool') end
 net.WriteType=function(v) write('type',v) end; net.ReadType=function() return read('type') end
 `);

const itemSource=require('fs').readFileSync(require('path').join(__dirname,'../helix/gamemode/game/items/sh_item.lua'),'utf8');
const allocator=itemSource.slice(itemSource.indexOf('\tfunction Item:GenerateID()'),itemSource.indexOf('\tfunction Item:LoadInstanceByID'));
const creator=itemSource.slice(itemSource.indexOf('\tfunction Item:LoadInstanceCount()'),itemSource.indexOf('\tfunction Item:Spawn('));
suite('New item IDs cannot replace unloaded saved items or existing live items',[],`
 eq(Item:GenerateID(),316); eq(Item:GenerateID(),317)
 Item.instance_count=0; Item.instances[400]={uniqueID='old'}; eq(Item:GenerateID(),401)
 dbFailed=true; eq(Item:GenerateID(),nil); dbFailed=false
 eq(Item:Instance('plate',{},400),nil); eq(Item.instances[400].uniqueID,'old')
 eq(Item:Instance('plate',{},1),nil); eq(inserted,0)
 local p=Item:Instance('plate',{}); eq(p.id,402); eq(inserted,1)
 mysql.module='mysqloo'; Item.idsReady=nil; delayed=true
 eq(Item:GenerateID(),nil)
 Item.instance_count=900; pending({{max_id='315'}})
 eq(Item.instance_count,900); eq(Item:GenerateID(),901)
 `,`
 Item={instance_count=0,instances={},stored={plate={}},ResolveID=function(_,v) return v end}
 function Item:New(name,id) local p={id=id,uniqueID=name,data={},rotated=false,x=0,y=0}; self.instances[id]=p; return p end
 function ErrorNoHalt() end
 util.TableToJSON=function() return '{}' end
 sql={Query=function(q) if dbFailed then return false end if q:find('MAX',1,true) then return {{max_id='315'}} end return {{item_id='1'}} end}
 inserted=0; mysql={module='sqlite'}
 function mysql:Insert() inserted=inserted+1; return {Insert=function() end,Execute=function() end} end
 function mysql:RawQuery(_,f) pending=f; if not delayed then pending({{max_id='315'}}) end end
 `+require('./glua.cjs').normalize(allocator+creator));

suite('Eyewear reach preserves arm lengths for reachable, distant and degenerate targets',
 ['addons/legends_field_actions/lua/gcal/gcal_tpik.lua'],`
 local root=Vector(0,0,0)
 for _,target in ipairs({Vector(12,0,0),Vector(100,0,0),Vector(0,0,0),Vector(0,0,18)}) do
  local elbow,hand=GCAL.SolveArmReach(root,target,Vector(0,0,1),10,9)
  near(root:Distance(elbow),10); near(elbow:Distance(hand),9)
  assert(hand:Distance(root)<19.001)
 end
 local elbow,hand=GCAL.SolveArmReach(root,Vector(12,0,0),Vector(0,-1,0),10,9)
 near(hand.x,12); near(hand.y,0); assert(elbow.y<0)
 eq(GCAL.SolveArmReach(root,root,Vector(0,0,1),0,9),nil)
 `,`
 CLIENT=true; SERVER=false; GCAL={}
 local V={}; V.__index=V
 function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},V) end
 function V.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
 function V.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
 function V.__mul(a,n) return Vector(a.x*n,a.y*n,a.z*n) end
 function V:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
 function V:LengthSqr() return self:Dot(self) end
 function V:Length() return math.sqrt(self:LengthSqr()) end
 function V:GetNormalized() local n=self:Length(); return n>0 and self*(1/n) or Vector(0,0,0) end
 function V:Distance(b) return (self-b):Length() end
 `);

suite('Limb pads wear like one plate; pellet callbacks do not multiply wear; unrelated hits do not activate padding',[shared],`
 local F=ix.field; local pad=vest(0); pad.limbPadding=true; pad.data.value=1
 pad.armor={coverage={[HITGROUP_LEFTARM]=.5,[HITGROUP_RIGHTARM]=.5}}
 local player={char_outfit={armor={[pad]=true}}}
 assert(F.HasLimbPadding(player,HITGROUP_LEFTARM)); eq(F.HasLimbPadding(player,HITGROUP_HEAD),false)
 local info={class='bullet',attacker='shooter',weapon={HoldType='pistol'}}
 for i=1,60 do
  tick=i; pad.data.value=pad.data.value-F.LimbPaddingWear(pad,info,999)
  eq(F.LimbPaddingWear(pad,info,999),0)
 end
 near(pad.data.value,0); pad.data.value=0; eq(F.HasLimbPadding(player,HITGROUP_LEFTARM),false)
 pad.data.value=1; info.weapon.HoldType='ar2'
 for i=1,30 do tick=100+i; pad.data.value=pad.data.value-F.LimbPaddingWear(pad,info,999) end
 near(pad.data.value,0)
 eq(F.LimbPaddingWear(pad,{class='club'},.25),.25)
 pad.limbPadding=false; eq(F.LimbPaddingWear(pad,info,.2),.2)
`,setup);
suite('Shoulder pads have a separate slot and only cover arms',
 ['ixhl2rp/plugins/items_clothing/items/clothes_armor/shoulder_pads.lua'],`
 eq(ITEM.equip_inv,'armprotection'); eq(ITEM.bodyGroups[5],1)
 eq(ITEM.armor.coverage[HITGROUP_LEFTARM],.5); eq(ITEM.armor.coverage[HITGROUP_HEAD],nil)
 eq(ITEM.armor.coverage[HITGROUP_LEFTLEG],nil); assert(ITEM.limbPadding)
`,setup+'ITEM={}');
suite('Knee pads use leg protection without replacing trousers',
 ['ixhl2rp/plugins/items_clothing/items/clothes_armor/knee_pads.lua'],`
 eq(ITEM.equip_inv,'legprotection'); eq(ITEM.bodyGroups[8],1); eq(ITEM.bodyGroups[7],nil)
 eq(ITEM.armor.coverage[HITGROUP_LEFTLEG],.5); eq(ITEM.armor.coverage[HITGROUP_LEFTARM],nil)
`,setup+'ITEM={}');
};
