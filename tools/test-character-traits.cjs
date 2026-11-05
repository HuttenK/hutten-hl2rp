const fs=require('fs'),path=require('path');
const normalize=require('./glua-runtime.cjs');
module.exports=suite=>{
 const dir='ixhl2rp/plugins/character_traits/';
 const catalog=dir+'sh_catalog.lua';
 const setup=`
 HITGROUP_HEAD=1;HITGROUP_CHEST=2;HITGROUP_STOMACH=3;HITGROUP_LEFTARM=4;HITGROUP_RIGHTARM=5;HITGROUP_LEFTLEG=6;HITGROUP_RIGHTLEG=7
 function Material() return {} end
 ix.char={HookVar=function() end}
 function string:utf8len() return utf8.len(self) end
 function string:utf8sub(a,b) return self:sub(utf8.offset(self,a), (utf8.offset(self,b+1) or (#self+1))-1) end
 unpack=table.unpack
 char={traits={},saves=0}
 function char:GetTraits() return self.traits end
 function char:SetTraits(t) self.traits=t;hook.Run('CharacterVarChanged',self,'traits') end
 function char:Save() self.saves=self.saves+1;self.saved=table.Copy(self.traits) end
 function char:GetPlayer() return p end
 p={valid=true,character=char,position=0,stm=100,suit=100}
 function p:GetCharacter() return self.character end
 function p:IsPlayer() return true end
 function p:Notify(s) self.notice=s end
 function p:NotifyLocalized(s,...) self.notice=s;self.args={...} end
 function p:Alive() return not self.dead end
 function p:IsRestricted() return self.restricted end
 function p:GetPos() local pos=self.position;return {DistToSqr=function(_,v) return (pos-v.value)^2 end,value=pos} end
 function p:SetAction(name,duration) hook.Run('PlayerActionChanged',self,name);self.action=name;self.duration=duration end
 function p:GetLocalVar() return self.stm end
 function p:EmitSound() self.sounds=(self.sounds or 0)+1 end
 function p:GetSuitPower() return self.suit end
 function p:SetSuitPower(n) self.suit=n end
 timer.jobs={}
 function timer.Simple(delay,fn) timer.jobs[#timer.jobs+1]={delay=delay,fn=fn} end
 function flush() local jobs=timer.jobs;timer.jobs={};for _,job in ipairs(jobs) do job.fn() end end
 `;
 suite('Traits validate points, mutually exclusive tiers, hostile values and independent selections', [catalog],`
 local T=ix.Traits;eq(#T.list,35)
 assert(T.Validate(nil));eq(T.Balance({}),0)
 eq(T.Validate({strong=true}),false)
 assert(T.Validate({strong=true,weak=nil,stuttering=true}))
 assert(T.Validate({feeble=true,herculean=nil,genius=true}))
 eq(T.Balance({feeble=true}),3);eq(T.Balance({frail=true}),2);eq(T.Balance({delicate=true}),1)
 for _,group in ipairs({'physique','intellect','beauty','height','strength','insight'}) do
  for _,a in ipairs(T.list) do for _,b in ipairs(T.list) do
   if a.id~=b.id and a.group==group and b.group==group then
    eq(T.Validate({[a.id]=true,[b.id]=true,stuttering=true,lisping=true,bleeder=true}),false)
   end
  end end
 end
 for _,bad in ipairs({false,5,'strong',{hacked=true},{weak=false},{weak=1},{weak={}},{[1]='weak'}, {one_eyed=true},{one_legged='head'}}) do eq(T.Validate(bad),false) end
 local values={one_eyed='right',one_legged='left',strong=true};local clean=T.Validate(values)
 assert(clean);assert(clean~=values);clean.one_eyed='left';eq(values.one_eyed,'right')
 near(T.Modifier(char,'health'),1);eq(T.Description(char),'')
 `,setup);
 suite('Trait registration persists a networked character field and validates on the server', [catalog,dir+'sh_plugin.lua',dir+'sv_effects.lua'],`
 local var=ix.char.vars.traits
 eq(var.field,'traits');eq(var.fieldType,ix.type.text);eq(var.Net.Transmit,ix.transmit.all)
 local ok,message=var:OnValidate({strong=true});eq(ok,false);eq(message,'traitInvalid')
 assert(var:OnValidate({strong=true,dull=true}))
 local payload={traits={dwarf=true},genetic={1,180,30,1}}
 var:OnAdjust(p,payload,payload.traits,{});eq(payload.genetic[2],145)
 char.traits={genius=true,one_eyed='left',weak=true,stuttering=true}
 hook.Run('OnCharacterCreated',p,char);eq(char.saves,1);eq(char.saved.one_eyed,'left');eq(char.saved.genius,true)
 `,setup+`
 ix.char={vars={}};ix.type={text=4};ix.transmit={all=7};ix.lang={AddTable=function() end}
 function ix.char.RegisterVar(k,v) ix.char.vars[k]=v end
 `);
 suite('Native limb health and bleeding honor traits without replacing bandages or modifying other characters', [catalog,'ixhl2rp/plugins/!healthsystem/sh_health.class.lua'],`
 local T=ix.Traits;local h=ix.meta.HealthStat:New(char,'health')
 function h:SetBleedingFX(on) self.bleeding=on end
 local base={};for k,part in h:GetParts() do base[k]=h:GetMaxHealth(k) end
 char.traits={feeble=true,spindly=true,bleeder=true};h.cachedParts=nil
 for k,part in h:GetParts() do
  local n=part.hitgroup>=4 and .85*.9 or .85
  eq(h:GetMaxHealth(k),math.Round(part.health*n))
 end
 h.hediffs={{part=2,tended_time=-1,bleedRate=.5,GetSeverity=function() return 8 end}}
 near(h:GetBleedRate(),5);eq(h.bleeding,true)
 h.hediffs[1].tended_time=0;h:OnUpdateDiffs();eq(h:GetBleedRate(),0);eq(h.bleeding,false)
 char.traits={herculean=true};h.cachedParts=nil
 for k,part in h:GetParts() do eq(h:GetMaxHealth(k),math.Round(part.health*1.15)) end
 char.traits={};h.cachedParts=nil;for k,n in pairs(base) do eq(h:GetMaxHealth(k),n) end
 `,setup);
 suite('Height exceptions require traits and preserve server and client hull/view dimensions', [catalog,'ixhl2rp/plugins/character_height/sh_height.lua'],`
 local T,H=ix.Traits,ix.CharacterHeight
 eq(T.ClampHeight(125,{}),155);eq(T.ClampHeight(215,{}),190)
 eq(T.ClampHeight(0,{dwarf=true}),125);eq(T.ClampHeight(300,{dwarf=true}),145)
 eq(T.ClampHeight(0,{giant=true}),195);eq(T.ClampHeight(300,{giant=true}),215)
 for _,bad in ipairs({true,false,25,'dwarf'}) do eq(T.ClampHeight(120,bad),155) end
 eq(T.ClampHeight(0/0,{}),180)
 char.Genetic=function() return {height=130} end;char.traits={dwarf=true};eq(H.SavedHeight(p),130)
 local scale=H.Scale(H.SavedHeight(p));near(scale,130/180)
 local made={};for _,method in ipairs({'SetHull','SetHullDuck','SetViewOffset','SetViewOffsetDucked'}) do
  p[method]=function(_,...) made[method]={...} end
 end
 H.Dimensions(p,scale);near(made.SetHull[2].z,72*scale);near(made.SetViewOffset[1].z,64*scale)
 char.traits={};eq(H.SavedHeight(p),155)
 `,setup+`
 concommand={Add=function() end};function p:GetNetVar() return nil end
 local V={};V.__index=V;V.__mul=function(v,n) return Vector(v.x*n,v.y*n,v.z*n) end
 function Vector(x,y,z) return setmetatable({x=x,y=y,z=z},V) end
 `);
 suite('Speech distortions preserve UTF-8, respect caps, and leave OOC, actions and other listeners untouched', [catalog,dir+'sh_speech.lua'],`
 local T=ix.Traits;local always=function() return 1 end
 char.traits={stuttering=true}
 eq(T.Speech(char,'ic','Привет, добрый рыцарь! Заходи.',always),'П-Привет, д-добрый р-рыцарь! Заходи.')
 char.traits={lisping=true};eq(T.Speech(char,'ic','Сосна, Зима. test',always),'Шошна, Жима. tesht')
 for _,kind in ipairs({'ooc','looc','me','it','roll','pm','event'}) do eq(T.Speech(char,kind,'Сосна',always),'Сосна') end
 char.traits={dull=true};local other={valid=true}
 eq(T.Hear(p,other,'ic','Добрый день, рыцарь.',always),'кочерыжка кочерыжка, рыцарь.')
 eq(T.Hear(p,p,'ic','Добрый день',always),'Добрый день')
 eq(T.Hear(p,other,'ooc','Добрый день',always),'Добрый день')
 char.traits={};eq(T.Hear(p,other,'ic','Добрый день',always),'Добрый день')
 `,setup);
 suite('Weak bans heavy weapons but permits shields, paired blades and carrying items', [catalog,dir+'sh_weapons.lua',dir+'sh_plugin.lua'],`
 local T=ix.Traits;char.traits={weak=true}
 for class in pairs(T.heavyWeapons) do eq(T.CanUseWeapon(char,class),false) end
 eq(T.CanUseWeapon(char,'aoc_sword'),true);eq(T.CanUseWeapon(char,'aoc_swordshield'),true)
 eq(T.CanUseWeapon(char,'aoc_dagger_dual'),true)
 local w={valid=true,GetClass=function() return 'aoc_longsword' end}
 eq(PLUGIN:PlayerSwitchWeapon(p,nil,w),true)
 char.traits={};eq(PLUGIN:PlayerSwitchWeapon(p,nil,w),nil)
 `,setup+`ix.char={RegisterVar=function() end};ix.type={};ix.transmit={all=7};ix.lang={AddTable=function() end}`);
 suite('Strong synchronizes per-instance AoC slice/cooldown/viewmodel timings and restores normal speed on owner change', [catalog,dir+'sh_weapons.lua'],`
 local T=ix.Traits;local vm={valid=true,SetPlaybackRate=function(s,n) s.rate=n end}
 p.GetViewModel=function() return vm end
 local original={Duration=2,Drain=10,{Time=.8,Damage=40,Start=5,End=80}}
 local w={AOC_Melee=true,Primary=original,Secondary=original,Tertiary=original,GetOwner=function() return p end,GetClass=function() return 'aoc_longsword' end}
 function w:CanPrimaryAttack() return not self.busy end
 function w:SequenceDuration() return 2 end
 function w:SendWeaponAnim() end
 function w:DoAttack() self.calls=(self.calls or 0)+1;self:SendWeaponAnim();self.duration=self:SequenceDuration() end
 T.PrepareWeapon(w);local wrapped=w.DoAttack;T.PrepareWeapon(w);eq(w.DoAttack,wrapped)
 char.traits={strong=true};w:DoAttack(1)
 near(w.Primary.Duration,2/1.08);near(w.Primary[1].Time,.8/1.08);near(w.duration,2/1.08);near(vm.rate,1.08)
 eq(w.Primary[1].Damage,40);eq(w.Primary[1].End,80);eq(w.Primary.Drain,10)
 eq(original.Duration,2);eq(original[1].Time,.8);assert(w.Primary~=w.Secondary)
 local cached=w.Primary;w:DoAttack(1);near(w.Primary.Duration,2/1.08);eq(w.Primary,cached)
 w:SendWeaponAnim();eq(vm.rate,1);eq(w:SequenceDuration(),2)
 char.traits={};w:DoAttack(1);eq(w.Primary.Duration,2);eq(w.Primary[1].Time,.8);eq(vm.rate,1)
 char.traits={weak=true};local calls=w.calls;w:DoAttack(1);eq(w.calls,calls);eq(w:CanPrimaryAttack(),false)
 char.traits={};w.busy=true;w:DoAttack(1);eq(w.calls,calls)
 `,setup);
 suite('Eye loss rolls exactly 2% for severe head wounds once and leg traits follow native amputation/restoration', [catalog,dir+'sv_effects.lua'],`
 local T=ix.Traits;local roll,rolls=1,0
 math.random=function(a,b) rolls=rolls+1;return b==100 and roll or 1 end
 local h={character=char};local wins=0
 for i=1,100 do
  roll=i;char.traits={};local before=char.saves;T.HeadInjury(h,1,'slash',8)
  if char.saves>before then wins=wins+1;eq(char.saved.one_eyed,'left') end
 end
 eq(wins,2)
 char.traits={};roll=1;T.HeadInjury(h,1,'slash',8);local saved=char.saves;local n=rolls
 T.HeadInjury(h,1,'slash',80);eq(char.saves,saved);eq(rolls,n)
 char.traits={};T.HeadInjury(h,4,'slash',20);T.HeadInjury(h,1,'slash',7.9);T.HeadInjury(h,1,'acid',20);eq(rolls,n)
 T.SyncLeg(char,'lleg');eq(char.traits.one_legged,'left')
 T.SyncLeg(char,'rleg');eq(char.traits.one_legged,'right')
 T.SyncLeg(char,nil);eq(char.traits.one_legged,nil)
 local amputations=0;ix.Amputation={Get=function() return char.amputation end,Amputate=function(_,key,silent) amputations=amputations+1;char.amputation=key;assert(silent) end}
 char.traits={one_legged='right'};hook.Run('PlayerLoadedCharacter',p,char);flush();eq(char.amputation,'rleg');eq(amputations,1)
 hook.Run('PlayerLoadedCharacter',p,char);flush();eq(amputations,1)
 char.amputation='lleg';hook.Run('PlayerLoadedCharacter',p,char);flush();eq(char.traits.one_legged,'left')
 `,setup);
 suite('Crafting is timed, consumes only at completion, rechecks resources and cancels stale character/station requests', [catalog,dir+'sv_effects.lua'],`
 local T=ix.Traits;local recipe={GetName=function() return 'Бинт' end}
 local checks,crafted=0,0;local craft={}
 function craft:AttemptCraft() checks=checks+1;if self.missing then return false,'craftNeedItems','wood' end return true end
 function craft:OnCraft() crafted=crafted+1;return true end
 eq(T.CraftDuration(char,recipe),5)
 char.traits={genius=true,shrewd=true};near(T.CraftDuration(char,recipe),4.25)
 char.traits={imbecile=true};near(T.CraftDuration(char,recipe),5.75)
 assert(T.BeginCraft(craft,p,recipe));eq(crafted,0);eq(T.BeginCraft(craft,p,recipe),false);flush();eq(crafted,1);eq(checks,1);eq(p.ixTraitCraft,nil)
 assert(T.BeginCraft(craft,p,recipe));craft.missing=true;flush();eq(crafted,1);eq(p.notice,'craftNeedItems');eq(p.args[1],'wood');craft.missing=nil
 assert(T.BeginCraft(craft,p,recipe));p:SetAction('Лечение',10);flush();eq(crafted,1);eq(p.action,'Лечение')
 for _,reason in ipairs({'movement','death','restriction','character','station','removed'}) do
  p.position=0;p.dead=nil;p.restricted=nil;p.character=char;p.ixStation=nil
  if reason=='removed' then p.ixStation={valid=true} end
  assert(T.BeginCraft(craft,p,recipe))
  if reason=='movement' then p.position=200 elseif reason=='death' then p.dead=true elseif reason=='restriction' then p.restricted=true
  elseif reason=='character' then p.character={} elseif reason=='station' then p.ixStation={} elseif reason=='removed' then p.ixStation.valid=false end
  flush();eq(crafted,1);eq(p.ixTraitCraft,nil)
 end
 `,setup);
 suite('Wheezing caps both stamina pools and throttles breathing without touching healthy players', [catalog,dir+'sh_plugin.lua',dir+'sv_effects.lua'],`
 eq(PLUGIN:CharacterMaxStamina(char),nil);hook.Run('FinishMove',p);eq(p.suit,100)
 char.traits={wheezing=true,clubfooted=true};eq(PLUGIN:CharacterMaxStamina(char),85);near(PLUGIN:AdjustStaminaOffsetRunning(p,-1),-1.1)
 clock=clock+1;hook.Run('FinishMove',p);eq(p.suit,85)
 p.stm=20;hook.Run('AdjustStaminaOffset',p,-1);eq(p.sounds,1);hook.Run('AdjustStaminaOffset',p,-1);eq(p.sounds,1)
 clock=clock+13;hook.Run('AdjustStaminaOffset',p,2);eq(p.sounds,1);hook.Run('AdjustStaminaOffset',p,-1);eq(p.sounds,2)
 `,setup+`ix.char={RegisterVar=function() end};ix.type={};ix.transmit={all=7};ix.lang={AddTable=function() end}`);
 suite('Trait selection replaces tiers, preserves side options and produces no shared draft mutation', [catalog,dir+'cl_creation.lua'],`
 local T=ix.Traits;local draft={frail=true,one_eyed='right',dull=true}
 local selection=T.Toggle(draft,'herculean');eq(selection.frail,nil);eq(selection.herculean,true);eq(selection.one_eyed,'right');eq(draft.frail,true)
 eq(T.Balance(selection),-1);eq(T.Validate(selection),false)
 selection=T.Toggle(selection,'stuttering');eq(T.Balance(selection),0);assert(T.Validate(selection))
 selection=T.Toggle(selection,'herculean');eq(selection.herculean,nil)
 selection=T.Toggle(selection,'one_legged');eq(selection.one_legged,'left')
 eq(T.CraftProgress(),nil)
 ix.bar={actionStart=clock,actionEnd=clock+5,actionText='ИЗГОТОВЛЕНИЕ: БИНТ'}
 local progress,remaining=T.CraftProgress();eq(progress,0);eq(remaining,5)
 clock=clock+2;local progress,remaining=T.CraftProgress();near(progress,.4);eq(remaining,3)
 ix.bar.actionText='ЛЕЧЕНИЕ';eq(T.CraftProgress(),nil)
 `,setup);
 suite('Trait creation keeps the scrolled canvas and controls while refreshing balance, tier selection and loss sides', [catalog,dir+'cl_creation.lua'],`
 local T,U=ix.Traits,ix.InterfaceOS
 local function menuFor(traits)
  local menu={draft={traits=traits or {},genetic={1,180}},content=panel(),next=panel(),previews=0}
  function menu:ShowStep() error('Selection must not rebuild the scrolled step') end
  function menu:PresentDraft() self.previews=self.previews+1 end
  T.BuildCreation(menu)
  return menu
 end
 local menu=menuFor();local content=menu.content
 local originals={};for i,child in ipairs(content.children) do originals[i]=child end
 local buttons,choices={},{}
 for _,child in ipairs(content.children) do
  if child.action then buttons[child.name]=child end
  if child.callback then choices[#choices+1]=child end
 end
 eq(#choices,2);assert(choices[1].disabled and choices[2].disabled)
 local function button(id) return buttons[T.byID[id].name] end
 local function click(id) button(id).action() end
 local function active(id)
  local row=button(id);row:Paint(500,100);return row.drawnActive
 end
 content.scroll=1200
 click('strong');eq(menu.next.disabled,true);eq(content.children[1].text,'Осталось очков: -1');assert(active('strong'))
 click('stuttering');eq(menu.next.disabled,false);eq(content.children[1].text,'Осталось очков: 0')
 click('strong');eq(active('strong'),false)
 click('frail');assert(button('herculean').tooltip:find('Заменит: '..T.byID.frail.name,1,true))
 click('herculean');eq(menu.draft.traits.frail,nil);eq(active('frail'),false);assert(active('herculean'));assert(menu.next.disabled)
 click('feeble');eq(menu.draft.traits.herculean,nil);eq(menu.next.disabled,false)
 click('quick');eq(T.Balance(menu.draft.traits),3)
 -- Programmatic dropdown refresh fires its callback too; it must not select a trait or recurse.
 eq(menu.draft.traits.one_eyed,nil);choices[1]:ChooseOptionID(2);eq(menu.draft.traits.one_eyed,nil)
 click('one_eyed');eq(choices[1].disabled,false);eq(choices[1].selected,1)
 choices[1]:ChooseOptionID(2);eq(menu.draft.traits.one_eyed,'right')
 click('lisping');eq(menu.draft.traits.one_eyed,'right');eq(choices[1].selected,2)
 click('one_eyed');assert(choices[1].disabled);eq(menu.draft.traits.one_eyed,nil)
 click('one_eyed');eq(menu.draft.traits.one_eyed,'left');eq(choices[1].selected,1)
 click('one_legged');choices[2]:ChooseOptionID(2);eq(menu.draft.traits.one_legged,'right')
 eq(menu.previews,0);click('albino');eq(menu.previews,1);click('albino');eq(menu.previews,2)
 click('dwarf');eq(menu.draft.genetic[2],145)
 click('giant');eq(menu.draft.traits.dwarf,nil);eq(menu.draft.genetic[2],195)
 click('giant');eq(menu.draft.genetic[2],190)
 eq(content.scroll,1200);eq(#content.children,#originals)
 for i,child in ipairs(content.children) do eq(child,originals[i]) end
 local resumed=menuFor({one_eyed='right',one_legged='left',strong=true})
 local side=0;for _,child in ipairs(resumed.content.children) do
  if child.callback then side=side+1;eq(child.disabled,false);eq(child.selected,side==1 and 2 or 1) end
 end
 eq(resumed.next.disabled,false);eq(resumed.previews,0)
 `,setup+`
 TOP=1;TEXT_ALIGN_RIGHT=2
 function Color(r,g,b) return {r=r,g=g,b=b} end
 function Material() return {IsError=function() return true end} end
 function panel()
  local p={children={},scroll=0}
  function p:Add() local child=panel();self.children[#self.children+1]=child;return child end
  function p:SetText(s) self.text=s end
  function p:SetTextColor(c) self.color=c end
  function p:SetDisabled(b) self.disabled=b end
  function p:SetTooltip(s) self.tooltip=s end
  for _,name in ipairs({'Dock','DockMargin','SetTall','SetFont','SetWrap','SetMouseInputEnabled'}) do p[name]=function() end end
  return p
 end
 ix.Legends={Scale=function(n) return n end}
 ix.InterfaceOS={accent=Color(200,170,100),ink=Color(230,230,230),muted=Color(150,150,150)}
 local U=ix.InterfaceOS
 function U.Label(parent,text,font,color) local p=parent:Add();p:SetText(text);p:SetTextColor(color);return p end
 function U.Button(parent,name,action) local p=parent:Add();p.name=name;p.action=action;return p end
 function U.Choice(parent,title,entries,selected,callback)
  U.Label(parent,title);local p=parent:Add();p.callback=callback
  function p:ChooseOptionID(id) self.selected=id;self.callback(entries[id].value) end
  return p
 end
 function U.ButtonFace(p,w,h,danger,active) p.drawnActive=active end
 function U.Fit(s) return s end
 function U.Text() end
 `);
 const combat=normalize(fs.readFileSync(path.join(__dirname,'../ixhl2rp/plugins/!healthsystem/sv_combat.lua'),'utf8'));
 const damage=combat.slice(combat.indexOf('local parents ='),combat.indexOf('local function ApplyStaminaDamage'));
 suite('Actual wound routing checks eyes once after armor penetration, including arrow/bullet wounds', [catalog,dir+'sv_effects.lua'],damage+`
 p.char_outfit={armor={}}
 local h={character=char,body={hit_parts={[1]=1,[4]=4}},hits=0}
 function h:GetPartHealth() return 100 end;function h:GetMaxHealth() return 100 end
 function h:AddHediff() self.hits=self.hits+1 end
 local checks=0;ix.Traits.HeadInjury=function(_,group,kind,amount) checks=checks+1;eq(group,1);assert(amount>0) end
 math.random=function(a) return a or .1 end;math.Rand=function() return .1 end
 local function hit(kind,amount) ApplyDamageToPart(h,1,{amount=amount or 40,attacker={},weapon={},class=kind}) end
 hit('slash');eq(checks,1);hit('bullet');eq(checks,2);hit('buckshot');eq(checks,3)
 local helmet={id=1,value=1,armor={coverage={[1]=1},class='plate',max_durability=100,density=.8,damage={},penetration={slash=1}}}
 function helmet:GetData() return self.value end;function helmet:SetData(_,n) self.value=n end
 p.char_outfit={armor={[helmet]=true}};ix.Item={instances={[1]=helmet}}
 hit('slash');eq(checks,3);assert(helmet.value<1)
 helmet.value=.001;hit('slash',4000);eq(checks,4);eq(helmet.value,0)
 `,setup);
 // Verify every published icon is real PNG content and has documented provenance.
 const manifest=JSON.parse(fs.readFileSync(path.join(__dirname,'../docs/character-trait-icons.json'),'utf8'));
 if(manifest.icons.length!==35) throw Error('Expected 35 CK3 icons');
 for(const icon of manifest.icons){
  const file=fs.readFileSync(path.join(__dirname,'../addons/medieval_ui_content/materials',icon.file));
  if(file.subarray(0,8).toString('hex')!=='89504e470d0a1a0a') throw Error('Not PNG: '+icon.file);
  if(!icon.source.startsWith('https://ck3.paradoxwikis.com/images/')) throw Error('Bad provenance');
  if(require('crypto').createHash('sha256').update(file).digest('hex')!==icon.sha256) throw Error('Icon changed: '+icon.file);
 }
};
