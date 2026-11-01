const fs=require('fs'),path=require('path');process.chdir(path.resolve(__dirname,'..'));
const {run,source,native,finish}=require('./restored-test-runner.cjs');
const meta=require('./fixtures/sd-clothing.json'),dir='ixhl2rp/plugins/items_clothing/items/';
const pre=`
ix.util={Lib=function(n,d) ix[n]=d;return d end,Include=function() end}
ix.Item={stored={},instances={}};ix.outfits={};ix.transmit={none=0,owner=1}
function class(n) local c={};c.__index=c;ix.meta[n]=c;function c:implements(b) for k,v in pairs(ix.meta[b]) do if k~="__index" and self[k]==nil then self[k]=v end end;return self end;return c end
function implements(b,n) ix.meta[n]:implements(b) end
ix.meta.Item={AddData=function() end}
function Model(s) return s end
HITGROUP_HEAD=1;HITGROUP_CHEST=2;HITGROUP_STOMACH=3;HITGROUP_LEFTARM=4;HITGROUP_RIGHTARM=5;HITGROUP_LEFTLEG=6;HITGROUP_RIGHTLEG=7
function Vector(...) return {...} end;function Angle(...) return {...} end
-- Item:Base copies base fields; clearing equip_slot must not inherit hotbar again.
function newItem(id,b) local i={};for k,v in pairs(ix.meta[b]) do if k~="__index" then i[k]=v end end;i.uniqueID=id;i.id=id;i.functions={};i.data={};if i.Init then i:Init() end;return i end
`;
const armor=['head_helmet_tier4','head_helmet_tier5','vest_antistab','vest_medium','vest_heavy','shoulder_pads','knee_pads'];
let registration='';
for(const [folder,names,b] of [['clothes',fs.readdirSync(dir+'clothes'),'ItemCloth'],['clothes_armor',armor.map(x=>x+'.lua'),'ItemClothArmor'],['bags',['bag.lua','bag_cp.lua','medicbag.lua','smallbag.lua'],'ItemBag']])for(const f of names){
 const id=f.slice(0,-4),file=folder==='bags'?'ixhl2rp/schema/items/bags/'+f:dir+folder+'/'+f;
 registration+=`ITEM=newItem(${JSON.stringify(id)},${JSON.stringify(b)})\n`+source([file])+`\nif not rawget(ITEM,'Register') then if ITEM.OnRegistered then ITEM:OnRegistered() end;ix.Item.stored[ITEM.uniqueID]=ITEM end;ITEM=nil\n`;
}
const base=pre+source(['helix/gamemode/game/character/appearance/sh_appearance.lua','helix/gamemode/items/base/equipable.lua',dir+'base/clothes.lua',dir+'base/clothes_armor.lua','helix/gamemode/items/base/bags.lua','ixhl2rp/plugins/items_clothing/libs/sh_sd_clothing.lua','helix/gamemode/game/character/appearance/sh_outfit.class.lua'])+ '\n' +registration+`
function owner(model)
 local p={valid=true,model=model or 'models/sd/citizens/citizen_male_04_hair4.mdl',bgs={},inventories={},skin=4}
 p.character={GetModel=function() return p.model end,GetSdSkin=function() return p.skin end,GetSpecial=function() return 10 end}
 function p:GetModel() return self.model end;function p:SetModel(m) self.model=m end
 function p:GetCharacter() return self.character end
 function p:GetBodygroup(g) return self.bgs[g] or 0 end;function p:SetBodygroup(g,v) self.bgs[g]=v end
 function p:GetNumBodyGroups() return 12 end
 function p:SetNoDraw(v) self.hidden=v end;function p:SetNWFloat(k,v) self[k]=v end;function p:SetNWInt() end
 function p:GetSkin() return self.skin end;function p:SkinCount() return 27 end;function p:SetSkin(s) self.skin=s end
 function p:SetPoseParameter() end;function p:GetInventories() return self.inventories end
 local o=setmetatable({owner=p,model=p.model,character=p.character,layers={p},displayIds={},armor={}},{__index=ix.meta.Outfit})
 function o:SendClientUpdate() end;p.char_outfit=o;return p,o
end
function stock(id) return assert(ix.Item.stored[id],id) end
`;
run('All 60 SD wearable states have items; catalog matches original MDL metadata on all 47 models',base+`
 local covered={};local count=0
 local props={};for _,p in ipairs({${meta.props.map(JSON.stringify).join(',')}}) do props[p]=true end
 local groups={${meta.groups.map(g=>`[${g.id}]={${g.values.map(JSON.stringify).join(',')}}`).join(',')}}
 for id,r in pairs(ix.SDClothing.catalog) do
  local i=stock(id);count=count+1;eq(i.sdClothing,true);eq(i.equip_inv,r.slot);eq(i.bodyGroupsSD[r.group],r.value);eq(next(i.bodyGroups),nil)
  eq(ix.Appearance.Database[i.displayID].variants.sd.bodyGroups[r.group],r.value)
  eq(groups[r.group][r.value+1],r.part..'.smd');assert(props[i.model] or id=='sd_satchel','missing prop '..id)
  covered[r.group..':'..r.value]=true
 end
 eq(count,52)
 for _,id in ipairs({${armor.map(JSON.stringify).join(',')}}) do for g,v in pairs(stock(id).bodyGroupsSD) do covered[g..':'..v]=true end end
 covered['10:1']=true
 ${meta.groups.flatMap(g=>g.values.map((v,i)=>({g:g.id,i,v}))).filter(r=>r.v&&r.v!=='hair.smd'&&r.v!=='hands_1.smd').map(r=>`assert(covered['${r.g}:${r.i}'],'uncovered ${r.v}');`).join('\n')}
 ${meta.models.map(m=>`eq(ix.Appearance:GetModelClass(${JSON.stringify(m)}),'sd')`).join('\n')}
 eq(stock('gloves_fingerless').bodyGroupsSD[9],1);eq(stock('gloves_af').bodyGroupsSD[9],2)
`);
run('Every clothing item equips and unequips through Outfit without changing other bodygroups or skin',base+`
 for id,r in pairs(ix.SDClothing.catalog) do
  local p,o=owner();o:Update();local i=stock(id);assert(i:CanEquip(p));i:OnEquipped(p);eq(p:GetBodygroup(r.group),r.value)
  for g=0,11 do if g~=r.group then eq(p:GetBodygroup(g),0) end end
  eq(p:GetSkin(),4);i:OnUnequipped(p);eq(p:GetBodygroup(r.group),0);eq(p:GetSkin(),4)
 end
`);
run('Clothing, masks, glasses, armor, pads and satchel coexist; removal leaves unrelated slots intact',base+`
 local p,o=owner();local ids={'sd_citizen_blue_short','jeans_boots','gloves_af','sunglasses','gasmask_gp7','vest_medium','knee_pads','shoulder_pads','sd_satchel','head_helmet_tier4'}
 for _,id in ipairs(ids) do stock(id):OnEquipped(p) end
 for _,id in ipairs(ids) do for g,v in pairs(stock(id).bodyGroupsSD) do eq(p:GetBodygroup(g),v) end end
 stock('sd_citizen_blue_short'):OnUnequipped(p);eq(p:GetBodygroup(4),0);eq(p:GetBodygroup(6),2);eq(p:GetBodygroup(7),5);eq(p:GetBodygroup(9),2);eq(p:GetBodygroup(11),1)
 stock('vest_medium'):OnUnequipped(p);eq(p:GetBodygroup(6),0);eq(p:GetBodygroup(5),1)
`);
run('Non-SD models reject SD clothes; existing armor variants and NVG items remain usable',base+`
 local p,o=owner('models/player/kleiner.mdl');eq(stock('sd_hoodie'):CanEquip(p),false);eq(stock('sd_hoodie'):CanEquip(nil),false)
 stock('sd_hoodie'):OnEquipped(p);eq(p:GetBodygroup(4),0)
 for _,id in ipairs({'nvg_gpnvg','nvg_n15','nvg_pnv10t','nvg_pvs14'}) do local i=stock(id);eq(i.sdClothing,nil);assert(i:CanEquip(p));assert(i.nvgType) end
 eq(ix.Appearance.Database[stock('head_helmet_tier4').displayID].variants.mpf.bodyGroups[6],1)
 eq(stock('vest_medium').plateCapacity,2);eq(stock('vest_heavy').plateCapacity,3)
`);
run('Backpacks and satchel appear independently; bag storage and non-SD appearances are preserved',base+`
 for _,id in ipairs({'bag','bag_cp','medicbag','smallbag'}) do
  local p,o=owner();local b=stock(id);local data=b.inventory_data;b.inventory={contents={123,456}}
  stock('sd_satchel'):OnEquipped(p);b:OnEquipped(p);eq(p:GetBodygroup(10),1);eq(p:GetBodygroup(11),1)
  eq(b.inventory.contents[1],123);eq(b.inventory_data,data);b:OnUnequipped(p);eq(p:GetBodygroup(10),0);eq(p:GetBodygroup(11),1)
  local other,outfit=owner('models/player/kleiner.mdl');b:OnEquipped(other);eq(other:GetBodygroup(10),0)
  if b.displayID then eq(outfit.displayIds[6].tag,b.displayID) end
 end
`);
run('Reload reapplies equipped clothing and character switch removes the previous outfit',base+`
 local p,o=owner();local top=stock('sd_hoodie');local pants=stock('jeans_boots')
 top.inventory_type='torso';pants.inventory_type='legs';ix.Item.instances[top.id]=top;ix.Item.instances[pants.id]=pants
 p.inventories={torso={GetItemsID=function() return {top.id} end},legs={GetItemsID=function() return {pants.id} end}}
 o.prepareItems=true;o:SetupItems();eq(p:GetBodygroup(4),17);eq(p:GetBodygroup(7),5)
 p.inventories={};o.prepareItems=true;o:SetupItems();eq(p:GetBodygroup(4),0);eq(p:GetBodygroup(7),0)
`);
run('Both cosmetic uniforms replace only the visible model and restore SD equipment, skin and saved identity',base+`
 for _,id in ipairs({'uniform_security_guard','uniform_epsilon11'}) do
  local p,o=owner();local saved=p.model;local i=stock(id);local skin=4
  function p.character:GetModel() return saved end;function p.character:GetSdSkin() return skin end
  function p:SetModel(m) local old=self.model;self.model=m;o:ModelChanged(m,old) end
  p.health=76;p.armor=18;p.walkSpeed=120;o.armor={existing=true}
  stock('jeans_boots'):OnEquipped(p);stock('vest_medium'):OnEquipped(p)
  local protection=o.armor;local model=ix.Appearance.Database[i.displayID].fullBodyModel
  assert(i:CanEquip(p));i:OnEquipped(p);eq(p.model,model);eq(p:GetSkin(),0);eq(o.model,saved);eq(p.character:GetModel(),saved)
  for g=0,11 do eq(p:GetBodygroup(g),0) end
  o:Update();eq(p.model,model);eq(p.health,76);eq(p.armor,18);eq(p.walkSpeed,120);eq(o.armor,protection)
  i:OnUnequipped(p);eq(p.model,saved);eq(p:GetSkin(),4);eq(p:GetBodygroup(7),5);eq(p:GetBodygroup(6),2)
  eq(o.armor,protection);eq(i.equip_inv,'torso');eq(i.equip_slot,nil);eq(i.gender,nil)
  eq(i.armor,nil);eq(i.isGasmask,nil);eq(i.plateCapacity,nil);eq(i.isMPF,nil)
 end
 eq(ix.Appearance.Database[stock('uniform_security_guard').displayID].fullBodyModel,'models/arty/codmw2022/sp/mexican federal police/grunts/scp_oz_security_1.mdl')
 eq(ix.Appearance.Database[stock('uniform_epsilon11').displayID].fullBodyModel,'models/kyo/reyes_deadofnight_pm.mdl')
`);
run('Cosmetic uniforms survive inventory reload, restore non-SD skin and do not leak to another character',base+`
 local p,o=owner('models/player/kleiner.mdl');local saved=p.model;local i=stock('uniform_epsilon11')
 function p.character:GetModel() return saved end
 function p:SetModel(m) local old=self.model;self.model=m;o:ModelChanged(m,old) end
 i.inventory_type='torso';ix.Item.instances[i.id]=i
 p.inventories={torso={GetItemsID=function() return {i.id} end}}
 o:LoadCharacter(p.character);eq(p.model,ix.Appearance.Database[i.displayID].fullBodyModel);eq(o.model,saved)
 -- Fresh player/appearance instance with the same saved character and inventory.
 local fresh,outfit=owner(saved);fresh.inventories=p.inventories;fresh.character.GetModel=function() return saved end
 outfit:LoadCharacter(fresh.character);eq(fresh.model,p.model);i:OnUnequipped(fresh);eq(fresh.model,saved);eq(fresh.skin,4)
 p.inventories={};local nextModel='models/player/barney.mdl';p.model=nextModel;p.skin=2
 p.character={GetModel=function() return nextModel end};o:LoadCharacter(p.character)
 eq(p.model,nextModel);eq(p.skin,2);eq(o.fullBodyBaseSkin,nil);eq(next(o.displayIds),nil)
`);
run('Cosmetic uniform slot conflicts and failed unequip preserve the currently worn model',base+`
 local p,o=owner();local i=stock('uniform_security_guard');local other=stock('uniform_epsilon11')
 function i:GetOwner() return p end
 other.inventory_type='torso';i.inventory_type='main'
 local slot={type='torso',isEquipment=true,GetItems=function() return {other} end}
 eq(i:CanTransfer({},slot),false)
 i.inventory_type='torso';i:OnEquipped(p);i.player=p;i.inventory_id=99;i.x=1;i.y=1
 local target={SendDeltaTransfer=function() error('Failed transfer was announced') end}
 local old={GetItemSize=function() return 1,1 end,Transfer=function() return false,'noFit' end,SyncTo=function() end}
 ix.Inventory={Get=function() return old end};function p:GetInventory() return target end;function p:NotifyLocalized() end
 i.functions.unequip.OnRun(i);eq(p.model,ix.Appearance.Database[i.displayID].fullBodyModel)
`);
run('Disconnect and character switching never save temporary uniform skin/bodygroups into character data',base+
 native('ixhl2rp/plugins/items_clothing/sh_plugin.lua','local function CacheBodygroups','function PLUGIN:PrePlayerLoadedCharacter')+`
 local p,o=owner();local data={skin=4,bgcache={[0]=2}};function p.character:SetData(k,v) data[k]=v end
 stock('uniform_epsilon11'):OnEquipped(p);CacheBodygroups(p,p.character);eq(data.skin,4);eq(data.bgcache[0],2)
 stock('uniform_epsilon11'):OnUnequipped(p);p:SetSkin(3);p:SetBodygroup(0,1);CacheBodygroups(p,p.character)
 eq(data.skin,3);eq(data.bgcache[0],1)
`);
run('Retired items disappear from spawn menus; saved instances migrate without losing filters or condition',base+`
 ${native('helix/gamemode/game/items/sh_item.lua','function Item:ResolveID','function Item:Register').replaceAll('Item:', 'ix.Item:')}
 local count=0;mysql={Update=function() return {Update=function() end,Where=function() end,Execute=function() end} end};util.TableToJSON=function() return '{}' end
 for old,id in pairs(ix.SDClothing.retired) do
  count=count+1;eq(ix.Item.stored[old],nil);assert(stock(id))
  local row={unique_id=old,item_id='123'};local data=ix.Item:MigrateLegacyRow(row,{filter=29,value=.6,equip=true})
  eq(row.unique_id,id);eq(data.filter,29);eq(data.value,.6);eq(data.equip,false)
 end;eq(count,32)
`);
run('Respirator filters without a visor; full gas masks keep their visor',base+source(['ixhl2rp/plugins/gasmask_immersion/sh_mask.lua'])+`
 local i=stock('respirator_af');eq(i.isGasmask,true);eq(ix.GasMask.Profile(i).visor,false)
 for _,id in ipairs({'gasmask_gp7','gasmask_m40_af'}) do local m=stock(id);eq(m.isGasmask,true);eq(m.immersionLens,true);eq(ix.GasMask.Profile(m).visor,true) end
`);
run('Slot migration fixes old head-slot pants, preserves full inventories, and ignores clothes inside backpacks',base+`
 local p,o=owner();local pants=stock('pants_grey');pants.x=1;pants.y=1;ix.Item.instances[pants.id]=pants
 local head={isEquipment=true,type='head',present=true}
 local legs={type='legs'};local main={type='main'};local transfers=0
 function head:GetItemsID() return self.present and {pants.id} or {} end
 function head:GetItemSize() return 1,1 end
 function head:Transfer(id,to) transfers=transfers+1;if to.full then return false end;self.present=false;to.item=id;return true end
 function legs:SendDeltaTransfer() self.sent=true end;main.SendDeltaTransfer=legs.SendDeltaTransfer
 p.inventories={head=head,legs=legs,main=main};function p:GetInventory(s) return self.inventories[s] end
 ix.SDClothing.RepairLegacySlots(p);eq(legs.item,pants.id);eq(legs.sent,true);eq(transfers,1)
 head.present=true;legs.full=true;ix.SDClothing.RepairLegacySlots(p);eq(main.item,pants.id)
 head.present=true;main.full=true;local before=transfers;ix.SDClothing.RepairLegacySlots(p);eq(head.present,true);eq(transfers,before+2)
 p.inventories={backpack={isEquipment=true,type='backpack',GetItemsID=function() return {'bag'} end,GetItems=function() error('must not walk bag contents') end}}
 ix.Item.instances.bag=stock('bag');before=transfers;ix.SDClothing.RepairLegacySlots(p);eq(transfers,before)
`);
run('Equipment slot conflicts reject a second garment; satchel has its own slot and failed removals stay visible',base+`
 local p,o=owner();local first=stock('sd_hoodie');local second=stock('sd_jacket_1');first.inventory_type='torso'
 function second:GetOwner() return p end
 local occupied={type='torso',GetItems=function() return {first} end}
 eq(second:CanTransfer({type='main'},occupied,1,1),false)
 local satchel=stock('sd_satchel');function satchel:GetOwner() return p end
 local empty={type='satchel',GetItems=function() return {} end}
 eq(satchel:CanTransfer({type='main'},empty,1,1),nil)
 local pants=stock('pants_grey');pants.player=p;pants.inventory_type='head';pants.inventory_id=55
 ix.Inventory={Get=function(_,id) return id==55 and {isEquipment=true} or nil end}
 eq(pants.functions.unequip.OnCanRun(pants),true)
 eq(stock('gasmask_gp7').width,1);eq(stock('gasmask_m40_af').width,1)
`);
finish();
