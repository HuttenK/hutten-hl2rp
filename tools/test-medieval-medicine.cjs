const fs=require('fs');
const {normalize}=require('./glua.cjs');
module.exports=suite=>{
 const files=['ixhl2rp/plugins/!healthsystem/sh_hediff.class.lua',
  'ixhl2rp/plugins/!healthsystem/sh_health.class.lua','ixhl2rp/plugins/!healthsystem/libs/sh_hediffs.lua',
  'ixhl2rp/plugins/!healthsystem/sh_effects.define.lua','ixhl2rp/plugins/medical/libs/sh_catalog.lua',
  'ixhl2rp/plugins/medical/items/base/medical.lua',
  'ixhl2rp/plugins/medical/sv_treatment.lua','ixhl2rp/plugins/downed_state/sh_downed.lua'];
 const setup=`
 function class(name)
  local c={};c.__index=c;ix.meta[name]=c
  function c:New(...) local o=setmetatable({},self);o.__index=o;if o.Init then o:Init(...) end;return o end
  function c:implements(base) for k,v in pairs(ix.meta[base]) do if k~='__index' and self[k]==nil then self[k]=v end end;return self end
  return c
 end
 abstract_class=class
 ix.transmit={owner=1}
 ix.meta.Item={AddData=function() end}
 function ix.meta.Item:GetData(k,default) return self.data[k] or default end
 function ix.meta.Item:SetData(k,v) self.data[k]=v end
 function ix.meta.Item:Remove() self.removed=true end
 function Material() return {} end;function Color() return {} end
 function Model(m) return m end
 HITGROUP_HEAD=1;HITGROUP_CHEST=2;HITGROUP_STOMACH=3;HITGROUP_LEFTARM=4;HITGROUP_RIGHTARM=5;HITGROUP_LEFTLEG=6;HITGROUP_RIGHTLEG=7
 ix.util.Lib=function(name,value) ix[name]=value;return value end
 ix.char={loaded={},HookVar=function() end};ix.Downed={}
 net.ChooseOptimalBits=function() return 16 end
 function math.Remap(v,a,b,c,d) return c+(v-a)*(d-c)/(b-a) end
 messages={};net.Start=function(s) messages[#messages+1]=s end
 p={valid=true,vars={},items={},Alive=function(s) return not s.dead end}
 function p:SetNetVar(k,v) self.vars[k]=v end;function p:GetNetVar(k) return self.vars[k] end
 function p:IsPlayer() return true end;function p:IsRestricted() return self.restricted end
 function p:InCriticalState() return self.critical end;function p:GetItems() return self.items end
 function p:Notify(s) self.notice=s end;function p:EmitSound() end
 function p:SetAction() end;function p:GetActiveWeapon() return nil end
 function p:Kill() assert(poison.removed);self.dead=true;self.kills=(self.kills or 0)+1 end
 char={GetID=function() return 1 end,GetPlayer=function() return p end}
 function p:GetCharacter() return char end
 function char:Health() return health end
 ix.char.loaded[1]=char
 ix.Amputation={GetLimb=function(c) return c and c.missing end}
 function fixture()
  health=ix.meta.HealthStat:New(char,'health')
  p.vars={};char.missing=nil
  return health
 end
 function injury(kind,group,amount) return health:AddHediff(kind,group,{severity=amount}) end
 function remedy(id,data)
  local item=setmetatable({uniqueID=id,data=data or {},functions={}},ix.meta.ItemMedical)
  item:Init();item.stats.uses=ix.Medicine.Catalog[id].uses
  return item
 end
 function use(id,group) return ix.Medicine.Apply(remedy(id),p,p,group or 0) end
 function eligible(id,group) return ix.Medicine.Eligible({uniqueID=id},p,group or 0) end
 function p:GetWeapon() return nil end
 function complete(item,success,group)
  local M=ix.Medicine;M.Reachable=function() return true end
  item.inUse=p;p.items={item};p.ixMedicalCleanup=nil
  local s={item=item,target=p,patient=char,character=char,hitgroup=group or 0,deadline=clock+100}
  p.ixMedicalSession=s;p.bUsingMedical=true;M.activeSessions[p]=s
  M.Finish(p,success)
  eq(p.ixMedicalSession,nil);eq(item.inUse,nil);eq(M.activeSessions[p],nil)
 end
 `;
 suite('Severe melee trauma rolls fracture once per hit, including merged bruises; loading saved injuries never rolls again',
 [...files,'ixhl2rp/plugins/medical/sh_treatment.lua'],`
  local rolls,fractures,number=0,0,100
  math.random=function(n) eq(n,100);rolls=rolls+1;return number end
  local function count(h)
   local n=0;for _,d in h:GetHediffs() do if d.isFracture then n=n+1 end end;return n
  end
  for n=1,100 do
   number=n;local h=fixture();local event={meleeHit=true}
   h:AddHediff('bruise',4,{severity=2},nil,event);eq(event.fractureRolled,nil)
   h:AddHediff('blunt',4,{severity=45},nil,event)
   h:AddHediff('blunt',4,{severity=1},nil,event);eq(rolls,n)
   fractures=fractures+count(h)
  end
  eq(fractures,10)
  local h=fixture();function p:SteamID() return 'test' end
  h:Load({health={{'cut',4,{severity=45}}}});eq(rolls,100);eq(count(h),0)
  h:AddHediff('bruise',4,{severity=5});eq(count(h),1) -- ordinary non-melee injury
 `,setup);
 suite('Four medieval remedies treat every native wound type without regenerating amputations',files,`
  fixture();local M=ix.Medicine;eq(table.Count(M.Catalog),4)
  eq(M.Catalog.bandage.model,'models/props_clutter/bar_rag.mdl');eq(M.Catalog.splint.model,'models/props_clutter/flute.mdl')
  eq(eligible('decoction'),false);eq(eligible('herbal_decoction'),false)
  for id,template in pairs(ix.Hediffs:All()) do
   if template.isInjury and not template.isFracture then
    local d=injury(id,4,35);assert(eligible('decoction',4),id)
    local result=use('decoction',4);near(result.dmg,30);near(d:GetSeverity(),5)
    result=use('decoction',4);near(result.dmg,5);eq(health:GetPartHealth(5),45)
   end
  end
  local a=injury('cut',4,20);local b=injury('bruise',4,20);local other=injury('cut',5,20)
  use('decoction',4);eq(health:GetPartHealth(5),35);eq(other:GetSeverity(),20)
  local fracture=injury('fracture',6,5);eq(eligible('decoction',6),false);assert(eligible('splint',6))
  use('splint',6);eq(health:GetPartHealth(7),50);eq(eligible('splint',6),false)
  char.missing={hitgroup=5};eq(eligible('decoction',5),true)
  injury('fracture',5,5);eq(eligible('splint',5),false)
  assert(eligible('bandage',5));use('bandage',5);eq(other.tended_time,0);assert(char.missing)
  use('decoction',5);eq(eligible('decoction',5),false);assert(char.missing)
  eq(eligible('splint',5),false) -- healing stump wounds must not grow a limb back
 `,setup);
 suite('Bandage stops all bleeding on a selected part and transmits dressing; decoction preserves that state',files,`
  fixture();local wounds={}
  for n=1,6 do wounds[n]=injury('cut',4,10) end
  local other=injury('cut',5,10);local hp=health:GetPartHealth(5)
  use('bandage',4)
  eq(health:GetPartHealth(5),hp);eq(other.tended_time,-1);near(health:GetBleedRate(),.6)
  local dressed=0;for _,msg in ipairs(messages) do if msg=='health.tended' then dressed=dressed+1 end end
  eq(dressed,6);eq(eligible('bandage',4),false)
  use('decoction',4);use('decoction',4);eq(health:GetPartHealth(5),45)
  near(health:GetBleedRate(),.6);use('bandage',5);near(health:GetBleedRate(),0)
  fixture();local old=injury('cut',4,100)
  health:TendHediff(old,100);old.tended_start=os.time()-50
  near(old:GetSeverity(),50);use('decoction',4);near(old:GetSeverity(),20);eq(old.tended_time,0)
 `,setup);
 suite('Herbal decoction restores blood without silently stopping continuing blood loss, enabling ordinary rescue',files,`
  fixture();local cut=injury('cut',4,10);local blood=injury('bleeding',0,.15);health.bloodloss=true
  assert(eligible('herbal_decoction',6));use('herbal_decoction',6)
  near(blood:GetSeverity(),0);eq(health.bloodloss,true);eq(eligible('herbal_decoction'),false)
  blood:OnTick(health);assert(blood:GetSeverity()>0,'Open wounds must continue losing blood')
  use('bandage',4);use('herbal_decoction');eq(health.bloodloss,nil);near(ix.Downed.Blood(char),1)
  fixture();injury('cut',1,25);injury('blunt',2,80);injury('bleeding',0,.99)
  eq(ix.Downed.CanRecover(health),false)
  use('bandage');for i=1,5 do use('decoction') end;for i=1,4 do use('herbal_decoction') end
  eq(ix.Downed.CanRecover(health),true);eq(health:GetPartHealth(2),25);eq(health:GetPartHealth(3),80)
 `,setup);
 suite('Decoction spends actual healed HP from 1000 volume and supports partial final doses',files,`
  fixture();injury('cut',4,35)
  local item=remedy('decoction');item:OnInstanced(true)
  eq(item:GetCapacity(),1000);eq(item.data.volume,1000)
  complete(item,true,4);eq(item.removed,nil);eq(item:GetUses(),970);eq(health:GetPartHealth(5),40)
  complete(item,true,4);eq(item:GetUses(),965);eq(health:GetPartHealth(5),45)
  complete(item,true,4);eq(item:GetUses(),965);eq(item.removed,nil) -- no wound: no cost
  local wound=injury('cut',4,20)
  complete(item,false,4);eq(item:GetUses(),965);eq(wound:GetSeverity(),20)
  item:SetResource(7.5);complete(item,true,4);eq(item.removed,true);near(wound:GetSeverity(),12.5)
  item=remedy('decoction');item:SetResource(0)
  complete(item,true,4);near(wound:GetSeverity(),12.5);eq(item.removed,nil)
 `,setup);
 suite('One decoction item can heal a thousand HP across many wounds and is removed only when empty',files,`
  fixture();local item=remedy('decoction');item:OnInstanced(true)
  for i=1,33 do
   injury('bruise',4,30);complete(item,true,4)
   eq(item:GetUses(),1000-i*30);eq(item.removed,nil);eq(health:GetPartHealth(5),45)
  end
  local wound=injury('bruise',4,20);complete(item,true,4)
  eq(item.removed,true);eq(wound:GetSeverity(),10)
 `,setup);
 suite('Bandages and herbal decoctions each last five successful treatments and preserve cancelled doses',files,`
  for _,id in ipairs({'bandage','herbal_decoction'}) do
   fixture();local item=remedy(id);item:OnInstanced(true)
   eq(item:GetCapacity(),5);eq(item:GetUses(),5);eq(item:GetResourceText(),'Применения: 5 / 5')
   for i=1,5 do
    if id=='bandage' then injury('cut',4,1) else injury('bleeding',0,.25) end
    complete(item,false);eq(item:GetUses(),6-i);eq(item.removed,nil)
    complete(item,true)
    if i<5 then eq(item:GetUses(),5-i);eq(item.removed,nil) else eq(item.removed,true) end
   end
  end
 `,setup);
 suite('Medicine resources persist across reloads, preserve old inventory data and conserve combined supplies',files,`
  local item=remedy('decoction',{uses=1});item:OnInstanced(false);eq(item:GetUses(),1000)
  item:SetResource(412.5);local loaded=remedy('decoction',{volume=item.data.volume,uses=1})
  loaded:OnInstanced(false);near(loaded:GetUses(),412.5)
  eq(loaded:GetResourceText(),'Запас: 412.5 / 1000 ед.')
  eq(remedy('decoction',{uses=0}):GetUses(),0)
  eq(remedy('decoction',{volume=0,uses=1}):GetUses(),0)
  for _,id in ipairs({'decoction','bandage','herbal_decoction'}) do
   local from,to=remedy(id),remedy(id);local capacity=from:GetCapacity()
   from:SetResource(capacity-1);to:SetResource(capacity-1)
   assert(from.combine.comb.OnCanRun(from,to));from.combine.comb.OnRun(from,to)
   eq(to:GetUses(),capacity);eq(from:GetUses(),capacity-2);eq(from.removed,nil)
   eq(from.combine.comb.OnCanRun(from,to),false)
   to:SetResource(capacity-1);from:SetResource(1);from.combine.comb.OnRun(from,to)
   eq(to:GetUses(),capacity);eq(from.removed,true)
   local saved=remedy(id,{volume=to.data.volume,uses=to.data.uses});saved:OnInstanced(false)
   eq(saved:GetUses(),capacity)
  end
  eq(remedy('bandage',{uses=1}):GetUses(),1) -- changing capacity never refills an existing partial item
  eq(remedy('herbal_decoction',{uses=1}):GetUses(),1)
 `,setup);
 const itemFiles=['ixhl2rp/plugins/medical/libs/sh_catalog.lua','ixhl2rp/plugins/medical/items/unknown_flask.lua'];
 suite('Unknown flask is skin 2, consumes itself before direct death, and is never offered as treatment',itemFiles,`
  poison=ITEM;poison.player=p;poison.owner=p
  function poison:GetOwner() return self.owner end;function poison:GetEntity() return self.entity end
  function poison:Remove() self.removed=true end
  eq(poison.skin,2);eq(poison.model,'models/leon/eldenring/flask.mdl');eq(ix.Medicine.Catalog.unknown_flask,nil)
  p.restricted=true;eq(poison.functions.drink.OnRun(poison),false);eq(p.dead,nil);p.restricted=nil
  poison.owner={};poison.functions.drink.OnRun(poison);eq(p.dead,nil);poison.owner=p
  poison.functions.drink.OnRun(poison);eq(poison.removed,true);eq(p.kills,1)
  poison.functions.drink.OnRun(poison);eq(p.kills,1)
 `,setup+'\nITEM={functions={}}');
 const amp=normalize(fs.readFileSync('ixhl2rp/plugins/amputation/sv_plugin.lua','utf8'));
 const noReattach=amp.slice(amp.indexOf('function Amputation.BeginReattach('),amp.indexOf('function PLUGIN:PlayerLoadedCharacter'));
 suite('Severed limbs cannot start a reattachment operation',[],`
  eq(Amputation.BeginReattach({}, {}, {}),false)
 `,`Amputation={Restore=function() error('Must not restore a limb') end}\n`+noReattach);
};
