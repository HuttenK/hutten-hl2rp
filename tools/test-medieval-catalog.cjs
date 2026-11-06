const fs = require('fs');
const {normalize} = require('./glua.cjs');
const catalog = require('./fixtures/medieval-catalog.json');
const source = file => normalize(fs.readFileSync(file, 'utf8'));
const classes = `
ix.util.Lib=function(n,t) ix[n]=t;return t end
function class(n)
 local c={};c.__index=c;ix.meta[n]=c
 function c:implements(b)
  assert(ix.meta[b],b)
  for k,v in pairs(ix.meta[b]) do if k~='__index' and self[k]==nil then self[k]=v end end
  return self
 end
 return c
end
function implements(b,n) return ix.meta[n]:implements(b) end
ix.transmit={all=2,owner=1,none=0};ix.outfits={};ix.Item={stored={},instances={}}
ix.char={vars={},RegisterVar=function(k,v) ix.char.vars[k]=v end};ix.type={number=1};ix.faction={indices={}}
ix.meta.Item={
 AddData=function(self,key,def) self.vars[key]=def end,
 GetData=function(self,key,default) return self.data[key] or default end, -- Match the real Item accessor, including false/default behavior.
 SetData=function(self,key,value) self.data[key]=value end,
 GetID=function(self) return self.id end,GetEntity=function(self) return self.entity end,
 GetOwner=function(self) return self.owner end,
}
function fresh(base,id)
 local i={data={},vars={},functions={},uniqueID=id,id=id}
 for k,v in pairs(assert(ix.meta[base])) do if k~='__index' then i[k]=v end end
 if i.Init then i:Init() end
 return i
end
local instanceSerial=0
function instance(id)
 instanceSerial=instanceSerial+1
 local stock=assert(ix.Item.stored[id]);local i=setmetatable({data={},id=id..'_instance_'..instanceSerial}, {__index=stock})
 ix.Item.instances[i.id]=i
 return i
end
function Vector(...) return {...} end;function Angle(...) return {...} end
function Model(m) return m end
HITGROUP_HEAD=1;HITGROUP_CHEST=2;HITGROUP_STOMACH=3;HITGROUP_LEFTARM=4;HITGROUP_RIGHTARM=5;HITGROUP_LEFTLEG=6;HITGROUP_RIGHTLEG=7
`;
function register(kind,base) {
 return catalog.filter(r=>r.kind===kind).map(r=>`do
 ITEM=fresh('${base}','${r.id}')
 ${source(r.path)}
 eq(ITEM.model,${JSON.stringify(r.model)})
 if ITEM.OnRegistered then ITEM:OnRegistered() end
 ix.Item.stored[ITEM.uniqueID]=ITEM
 ITEM=nil
 end`).join('\n');
}
const armorFiles = [
 'helix/gamemode/game/character/appearance/sh_appearance.lua',
 'helix/gamemode/items/base/equipable.lua',
 'ixhl2rp/plugins/items_clothing/items/base/clothes.lua',
 'ixhl2rp/plugins/items_clothing/items/base/clothes_armor.lua',
 'ixhl2rp/plugins/items_clothing/items/base/medieval_armor.lua',
 'ixhl2rp/plugins/items_clothing/items/base/medieval_helmet.lua',
 'ixhl2rp/plugins/templar_appearance.lua',
 'helix/gamemode/game/character/appearance/sh_outfit.class.lua'
];
const owners = `
function owner(skin,eyes)
 local p={valid=true,model='models/players/templar_archer_03.mdl',skin=0,bgs={},inventories={}}
 p.character={GetModel=function() return 'models/players/templar_archer_03.mdl' end,
  GetSdSkin=function() return skin end,GetTemplarEyes=function() return eyes end}
 function p:GetModel() return self.model end
 function p:SetModel(m) local old=self.model;self.model=m;self.skin=0;self.bgs={};self.char_outfit:ModelChanged(m,old) end
 function p:GetCharacter() return self.character end
 function p:SetSkin(s) self.skin=s end;function p:GetSkin() return self.skin end;function p:SkinCount() return 12 end
 function p:FindBodygroupByName(n) return n=='Yeux/Eyes' and 1 or -1 end
 function p:GetBodygroup(g) return self.bgs[g] or 0 end;function p:SetBodygroup(g,v) self.bgs[g]=v end
 function p:GetNumBodyGroups() return 8 end
 function p:GetBodygroupCount(g)
  if g==1 then return 3 end
  if g==2 then return self.model:match('templar_archer_0[123]') and 7 or 30 end
  if g==5 and self.model:find('templar_knight_',1,true) then return 2 end
  return 4
 end
 function p:SetNoDraw(v) self.hidden=v end;function p:SetNWFloat(k,v) self[k]=v end;function p:SetNWInt() end
 function p:SetPoseParameter() end;function p:GetInventories() return self.inventories end
 local o=setmetatable({owner=p,character=p.character,model=p.model,layers={p},displayIds={},armor={}}, {__index=ix.meta.Outfit})
 function o:SendClientUpdate() end
 p.char_outfit=o;return p,o
end
`;
module.exports = function(suite) {
 suite('Templar armor preserves every face and eye option through equip, reload, cloak changes and removal',armorFiles,
 register('armor','ItemMedievalArmor')+owners+`
 for skin=0,11 do for eyes=0,2 do
  local p,o=owner(skin,eyes);o:Update();eq(p.skin,skin);eq(p:GetBodygroup(1),eyes)
  for _,id in ipairs({'med_armor_black','med_armor_white','med_mail_long','med_mail_short','med_tunic_black'}) do
   local i=instance(id);i.owner=p;i.player=p;i.inventory_type='torso';i:OnInstanced(true);i:OnEquipped(p)
   eq(p.model,i.replacement);eq(p.skin,skin);eq(p:GetBodygroup(1),eyes);eq(o.armor[i],true)
   eq(i.equip_inv,'torso');eq(i.equip_slot,nil)
   near(p.speed_debuff or 1, i.armor.class==3 and .7 or i.armor.class==2 and .85 or 1)
   i:SetData('value',.43)
   if i.cloakModel then
    i:ToggleCloak(true);eq(p.model,i.cloakModel);eq(p.skin,skin);eq(p:GetBodygroup(1),eyes);eq(i:GetData('value'),.43)
    eq(ix.Appearance.Database[i.plainDisplayID].fullBodyModel,i.replacement)
    -- A new instance restores the saved cloak choice without changing its template.
    local saved=table.Copy(i.data);i:OnUnequipped(p)
    local nextItem=instance(id);nextItem.data=saved;nextItem.owner=p;nextItem.player=p;nextItem.inventory_type='torso'
    nextItem:OnInstanced(false);nextItem:OnEquipped(p);eq(p.model,i.cloakModel);eq(nextItem:GetData('value'),.43)
    nextItem:ToggleCloak(false);eq(p.model,i.replacement);i=nextItem
   end
   i:OnUnequipped(p);eq(o.armor[i],nil);eq(p.speed_debuff,1)
   eq(p.model,p.character:GetModel());eq(p.skin,skin);eq(p:GetBodygroup(1),eyes)
  end
 end end
 local p,o=owner(11,2);o:Update();local i=instance('med_tunic_black');i.owner=p;i.player=p;i.inventory_type='torso'
 i:OnInstanced(true);i:OnEquipped(p);i:ToggleCloak(true)
 local q,qo=owner(3,0);local other=instance('med_tunic_black');other.owner=q;other.player=q;other.inventory_type='torso';other:OnEquipped(q)
 eq(q.model,other.replacement);eq(q.skin,3);eq(p.model,i.cloakModel)
 -- Rebuilding equipment for a different character must clear old visuals/stats.
 local newChar={GetModel=function() return 'models/players/templar_archer_03.mdl' end,GetSdSkin=function() return 4 end,GetTemplarEyes=function() return 1 end}
 p.character=newChar;o:LoadCharacter(newChar);eq(p.skin,4);eq(p:GetBodygroup(1),1);eq(next(o.armor),nil);eq(p.speed_debuff,1)
 `,classes);

 const equipment=register('armor','ItemMedievalArmor')+'\n'+register('helmet','ItemMedievalHelmet')+'\n'+owners;
 const helmetIDs="{'med_helmet_kettle','med_helmet_spangen','med_helmet_bascinet','med_helmet_greathelm'}";
 suite('Four helmets map all eight Templar models, survive full-body swaps in either equip order, and preserve faces',armorFiles,
 equipment+`
 local expected={med_helmet_kettle={archer=1,knight=1},med_helmet_spangen={archer=2,knight=8},med_helmet_bascinet={archer=4,knight=6},med_helmet_greathelm={archer=6,knight=5}}
 local function check(p,h)
  local family=ix.Templar.Family(p.model)
  eq(p:GetBodygroup(2),expected[h.uniqueID][family]);eq(p.skin,9);eq(p:GetBodygroup(1),2)
  eq(p.char_outfit.armor[h],true)
 end
 for _,id in ipairs(${helmetIDs}) do
  for model in pairs(ix.Templar.models) do
   local p,o=owner(9,2);p.model=model;o.model=model;p.character.GetModel=function() return model end
   local h=instance(id);h.owner=p;h.player=p;h.inventory_type='head';h:OnInstanced(true)
   eq(h.equip_inv,'head');eq(h.equip_slot,nil);eq(h.functions.cloakOn,nil);assert(h:CanEquip(p))
   h:OnEquipped(p);eq(p.model,model);check(p,h)
   h:OnUnequipped(p);eq(p:GetBodygroup(2),0);eq(o.armor[h],nil);eq(p.skin,9);eq(p:GetBodygroup(1),2)
  end
  for _,bodyID in ipairs({'med_armor_black','med_armor_white','med_mail_long','med_mail_short','med_tunic_black'}) do
   for _,headFirst in ipairs({true,false}) do
    local p,o=owner(9,2)
    local h=instance(id);h.owner=p;h.player=p;h.inventory_type='head';h:OnInstanced(true)
    local b=instance(bodyID);b.owner=p;b.player=p;b.inventory_type='torso';b:OnInstanced(true)
    if headFirst then h:OnEquipped(p);b:OnEquipped(p) else b:OnEquipped(p);h:OnEquipped(p) end
    check(p,h)
    if b.cloakDisplayID then b:ToggleCloak(not b:GetCloakEnabled());check(p,h) end
    b:OnUnequipped(p);check(p,h);eq(p.model,p.character:GetModel())
    h:OnUnequipped(p);eq(p:GetBodygroup(2),0);eq(next(o.armor),nil)
   end
  end
 end
 `,classes);

 suite('Plate capes default on and save per item, with no model/helmet/face/durability or speed change',armorFiles,
 equipment+`
 for _,id in ipairs({'med_armor_black','med_armor_white'}) do
  local p,o=owner(6,1)
  local h=instance('med_helmet_spangen');h:OnInstanced(true);h:OnEquipped(p)
  local b=instance(id);b.owner=p;b.player=p;b.inventory_type='torso';b:OnInstanced(true);b:OnEquipped(p)
  eq(b:GetCloakEnabled(),true);eq(p:GetBodygroup(5),0)
  b:SetData('value',.41);h:SetData('value',.63)
  eq(b.functions.cloakOff.OnCanRun(b),true);eq(b.functions.cloakOn.OnCanRun(b),false)
  b.functions.cloakOff.OnRun(b)
  eq(p.model,b.replacement);eq(p:GetBodygroup(5),1);eq(p:GetBodygroup(2),8);eq(p.skin,6);eq(p:GetBodygroup(1),1)
  eq(b:GetData('value'),.41);eq(h:GetData('value'),.63);near(p.speed_debuff,.7)
  eq(b.functions.cloakOn.OnCanRun(b),true);eq(b.functions.cloakOff.OnCanRun(b),false)
  local saved=table.Copy(b.data);b:OnUnequipped(p)
  b=instance(id);b.data=saved;b.owner=p;b.player=p;b.inventory_type='torso';b:OnInstanced(false);b:OnEquipped(p)
  eq(b:GetCloakEnabled(),false);eq(p:GetBodygroup(5),1);eq(b:GetData('value'),.41);eq(p:GetBodygroup(2),8)
  local q,qo=owner(0,0);local second=instance(id);second:OnInstanced(true);second:OnEquipped(q)
  eq(q:GetBodygroup(5),0);eq(p:GetBodygroup(5),1)
  b.owner=q;b:ToggleCloak(true);eq(b:GetCloakEnabled(),false);b.owner=p
  b.inventory_type='main';b:ToggleCloak(true);eq(b:GetCloakEnabled(),false);b.inventory_type='torso'
  b.functions.cloakOn.OnRun(b);eq(p:GetBodygroup(5),0);eq(p.model,b.replacement);eq(p:GetBodygroup(2),8)
  -- Reconnect: existing equipment is replayed in the opposite order.
  b:SetData('medCloak',false)
  p.inventories={{GetItemsID=function() return {h.id,b.id} end}};h.inventory_type='head'
  o:LoadCharacter(p.character);eq(p:GetBodygroup(5),1);eq(p:GetBodygroup(2),8);eq(o.armor[h],true);eq(o.armor[b],true)
 end
 `,classes);

 suite('Helmets cannot equip on unrelated models or grant invisible armor after a uniform is removed',armorFiles,
 equipment+`
 local p,o=owner(4,1);local base='models/sd/citizens/citizen_male_01_hair1.mdl'
 p.model=base;o.model=base;p.character.GetModel=function() return base end
 local h=instance('med_helmet_greathelm');h:OnInstanced(true);eq(h:CanEquip(p),false)
 -- A saved helmet can load before the outfit which enables it.
 h:OnEquipped(p);eq(o.armor[h],false)
 local b=instance('med_armor_white');b:OnInstanced(true);b:OnEquipped(p)
 eq(o.armor[h],true);eq(p:GetBodygroup(2),5)
 b:OnUnequipped(p);eq(p.model,base);eq(o.armor[h],false)
 h:OnUnequipped(p);eq(o.armor[h],nil)
 b:OnEquipped(p);eq(o.armor[h],nil);eq(p:GetBodygroup(2),0)
 h:OnEquipped(p);eq(o.armor[h],true)
 p.inventories={};p.character={GetModel=function() return base end}
 o:LoadCharacter(p.character);eq(next(o.armor),nil);eq(p.model,base);eq(p:GetBodygroup(2),0)
 `,classes);

 suite('Resident creation offers only the Templar for either gender, validates face and eyes, and rejects old SD choices',
 ['ixhl2rp/schema/factions/sh_citizen.lua','helix/gamemode/game/character/appearance/sh_modelchoices.lua',
  'ixhl2rp/plugins/!character/sh_plugin.lua','ixhl2rp/plugins/sd_creation.lua','ixhl2rp/plugins/templar_appearance.lua'],`
 local model='models/players/templar_archer_03.mdl'
 ix.faction.indices[1]=FACTION
 local p={faction=1,gender=1,model=1}
 local field=ix.char.vars.model
 for gender=1,2 do
  p.gender=gender;p.model=1
  local choices=ix.BuildCharacterModelChoices(FACTION:GetModels({},gender))
  eq(#choices,1);eq(choices[1].entry,model);eq(#choices[1].variants,1)
  eq(field:OnValidate(1,p,{}),nil)
  local adjusted={};field:OnAdjust({},p,1,adjusted);eq(adjusted.model,model)
  for _,invalid in ipairs({2,'models/sd/citizens/citizen_male_01_hair1.mdl'}) do
   p.model=invalid;eq(field:OnValidate(invalid,p,{}),false)
  end
 end
 p.model=1
 eq(ix.char.vars.sdSkin:OnValidate(11,p,{}),11);eq(ix.char.vars.sdSkin:OnValidate(12,p,{}),false)
 local eyes=ix.char.vars.templarEyes
 eq(eyes:OnValidate(2,p,{}),2);eq(eyes:OnValidate(3,p,{}),false);eq(eyes:OnValidate(-1,p,{}),false)
 eq(eyes:OnValidate(0/0,p,{}),false);eq(eyes:OnValidate(1.5,p,{}),false);eq(eyes:OnValidate('1',p,{}),false)
 p.model=2;eq(eyes:OnValidate(2,p,{}),0)
 `,classes+`FACTION={index=1};function Color() return {} end;function Material(path) return path end`);

 const combat=source('ixhl2rp/plugins/!healthsystem/sv_combat.lua');
 const damage= combat.slice(combat.indexOf('local parents ='),combat.indexOf('local function ApplyStaminaDamage'));
 suite('Helmets reduce native head injuries only, wear independently, and lose protection when broken or unequipped',armorFiles,
 equipment+damage+`
 local p,o=owner(5,2)
 local health={character={GetPlayer=function() return p end},body={hit_parts={[1]=1,[2]=2}},hits={}}
 function health:GetPartHealth() return 100 end;function health:GetMaxHealth() return 100 end
 function health:AddHediff(kind,group,data) self.hits[#self.hits+1]={kind=kind,group=group,severity=data.severity} end
 local function hit(group,kind)
  health.hits={};ApplyDamageToPart(health,group,{amount=40,attacker={},weapon={},class=kind or 'slash'})
  local total=0;for _,r in ipairs(health.hits) do total=total+r.severity end;return total
 end
 math.random=function(a,b) if a then return a end return .4 end;math.Rand=function() return .4 end
 eq(hit(1),40);eq(hit(2),40)
 for _,id in ipairs(${helmetIDs}) do
  local h=instance(id);h:OnInstanced(true);h:OnEquipped(p)
  assert(hit(1)<40);assert(h:GetData('value')<1);eq(hit(2),40);eq(p.speed_debuff,nil)
  for _,kind in ipairs({'slash','club','fists','bullet','buckshot','impulse','explosive','acid','shock','burn','physics'}) do
   h:SetData('value',.5);hit(1,kind);assert(h:GetData('value')>=0 and h:GetData('value')<=.5)
  end
  h:SetData('value',0);eq(hit(1),40)
  h:SetData('value',1);h:OnUnequipped(p);eq(hit(1),40)
 end
 `,classes);
 suite('Native medical damage uses equipped armor, wears it down, and stops protecting after removal/breakage',armorFiles,
 register('armor','ItemMedievalArmor')+owners+damage+`
 local p,o=owner(5,2)
 local health={character={GetPlayer=function() return p end},body={hit_parts={[2]=2}},hits={}}
 function health:GetPartHealth() return 100 end;function health:GetMaxHealth() return 100 end
 function health:AddHediff(kind,group,data) self.hits[#self.hits+1]={kind=kind,group=group,severity=data.severity} end
 local function hit(kind)
  health.hits={}
  ApplyDamageToPart(health,2,{amount=40,attacker={},weapon={},class=kind})
  local total=0;for _,r in ipairs(health.hits) do total=total+r.severity end
  return total
 end
 math.random=function(a,b) if a then return a end return .4 end;math.Rand=function() return .4 end
 local naked=hit('slash');eq(naked,40)
 local results={}
 for _,id in ipairs({'med_armor_black','med_armor_white','med_mail_long','med_mail_short','med_tunic_black'}) do
  local i=instance(id);i:OnInstanced(true);i:OnEquipped(p)
  results[id]=hit('slash');assert(results[id]<naked);assert(i:GetData('value')<1)
  for _,kind in ipairs({'slash','club','fists','bullet','buckshot','impulse','explosive','acid','shock','burn','physics'}) do
   i:SetData('value',.5);hit(kind);assert(i:GetData('value')>=0 and i:GetData('value')<=.5)
  end
  i:SetData('value',0);eq(hit('slash'),naked)
  i:SetData('value',1);i:OnUnequipped(p);eq(hit('slash'),naked)
 end
 assert(results.med_armor_black<results.med_mail_long and results.med_mail_long<results.med_tunic_black)
 near(results.med_armor_black,results.med_armor_white)
 `,classes);

 const paperSetup=classes+`
 PLUGIN.maxTitleLength=128;PLUGIN.maxLength=10000
 netstream={handlers={},Hook=function(k,f) netstream.handlers[k]=f end,Start=function(...) netstream.last={...} end}
 function string.Replace(s,a,b) local from=1;local out='' while true do local x,y=s:find(a,from,true) if not x then return out..s:sub(from) end out=out..s:sub(from,x-1)..b;from=y+1 end end
 string.utf8sub=string.sub;Format=string.format
 function reader(id)
  local c={GetID=function() return id end,GetName=function() return 'Writer' end}
  return {valid=true,GetCharacter=function() return c end,IsAdmin=function() return false end}
 end
 `;
 suite('Diary and scroll save independently, remain author-editable, and reject forged/stale editor submissions',
 ['ixhl2rp/plugins/paperwork/items/base/writable.lua','ixhl2rp/plugins/paperwork/sv_plugin.lua'],
 register('writable','ItemWritable')+`
 local p=reader(1);local other=reader(2)
 for _,id in ipairs({'med_diary','med_scroll'}) do
  local i=instance(id);i.player=p;i.owner=p
  eq(i.stackable,false);eq(i.vars.T.Transmit,ix.transmit.none)
  i.functions.Write.OnRun(i);eq(netstream.last[6],true)
  netstream.handlers.ixWritePaper(p,i.id,'Journey','Chapter one',false)
  eq(i:GetData('T'),'Chapter one');eq(i:GetData('O'),1)
  local saved=table.Copy(i.data);i=instance(id);i.data=saved;i.player=p;i.owner=p;i:SetData('canEdit',1)
  eq(i:CanWrite(p),true);eq(i:CanWrite(other),false)
  i.functions.Write.OnRun(i);netstream.handlers.ixWritePaper(p,i.id,'Journey','Chapter two',false)
  eq(i:GetData('T'),'Chapter two')
  i:OpenDocument(p,false);netstream.handlers.ixWritePaper(p,i.id,'Forged','Read-only rewrite',false)
  eq(i:GetData('T'),'Chapter two')
  i:OpenDocument(p,true);i.owner=other;netstream.handlers.ixWritePaper(p,i.id,'Forged','Traded away',false)
  eq(i:GetData('T'),'Chapter two');i.owner=p
  i:OpenDocument(p,true);local original=p.GetCharacter;p.GetCharacter=other.GetCharacter
  netstream.handlers.ixWritePaper(p,i.id,'Forged','Wrong character',false);eq(i:GetData('T'),'Chapter two')
  p.GetCharacter=original
  netstream.handlers.ixWritePaperClosed(p,i.id);eq(i.user[p],nil)
 end
 ix.Item.instances.nonpaper={};netstream.handlers.ixWritePaper(p,'nonpaper','x','y',false)
 netstream.handlers.ixWritePaperClosed(p,'nonpaper')
 local untouched=instance('med_diary');netstream.handlers.ixWritePaper(p,untouched.id,'x','y',false);eq(untouched:GetData('T'),nil)
 `,paperSetup);

 const reagentSetup=classes+`
 ix.Reagents={holder={injectable=1,open=2},Consume=function(self,r,n) r.volume=r.volume-n;return 0,0 end}
 ix.meta.ItemReagentContainer=setmetatable({
 Init=function() end,OnDepleted=function(self) self.depleted=true end
 },{__index=ix.meta.Item})
 -- implements copies enumerable parent methods, as the runtime class does.
 for k,v in pairs(ix.meta.Item) do ix.meta.ItemReagentContainer[k]=v end
 `;
 suite('All 34 meals and drinks use native portions, hunger/thirst and depletion without modern can-opening',
 ['ixhl2rp/plugins/food/items/base/food.lua','ixhl2rp/plugins/food/items/base/drinks.lua'],
 register('food','ItemFood')+'\n'+register('drinks','ItemDrink')+`
 local count=0
 for id in pairs(ix.Item.stored) do
  local i=instance(id);count=count+1
  i.reagents={volume=0,AddReagent=function(self,kind,n) self.kind=kind;self.volume=self.volume+n end}
  local hunger,thirst=0,0
  i.player={GetCharacter=function() return {UpdateNeeds=function(_,t,h) thirst=thirst+t;hunger=hunger+h end} end,EmitSound=function() end}
  i:OnFirstCreated();eq(i.reagents.volume,i.volume);eq(i:IsClosed(),false);eq(i.functions.open.OnCanRun(i),false)
  local portion=i.portion_amount or i.sip_amount
  i.functions.use.OnRun(i);eq(i.reagents.volume,i.volume-portion)
  i.functions.useall.OnRun(i);near(i.reagents.volume,0);eq(i.depleted,true);eq(i.functions.use.OnCanRun(i),false)
  if i.portion_amount then near(hunger,i.stats.hunger*i.volume/i.portion_amount);near(thirst,i.stats.thirst*i.volume/i.portion_amount)
  else eq(i.reagents.kind,i.reagent_type) end
 end
 eq(count,34)
 `,reagentSetup);

 suite('Four storage items enter the persistent furnishing route with distinct container capacities',
 ['ixhl2rp/plugins/furnishing/sh_grid.lua','ixhl2rp/plugins/new_containers.lua'],
 catalog.filter(r=>r.kind==='furniture').map(r=>`do
 local data=ix.container.stored['${r.model}'];eq(data.width,${r.width});eq(data.height,${r.height})
 ITEM={};${source(r.path)}
 ITEM.uniqueID='${r.id}';assert(ix.furnish.Supported(ITEM));eq(ITEM.preview_model,'${r.model}')
 end`).join('\n'),
 `ix.container={stored={},Register=function(m,d) ix.container.stored[m]=d end}`);
};
