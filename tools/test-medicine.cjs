const fs=require('fs');
const {normalize}=require('./glua.cjs');
module.exports=suite=>{
 const files=['tools/fixtures/medicine.lua','ixhl2rp/plugins/medical/libs/sh_catalog.lua','ixhl2rp/plugins/medical/sh_treatment.lua','ixhl2rp/plugins/medical/sv_treatment.lua'];
 const catalog='ixhl2rp/plugins/medical/libs/sh_catalog.lua';
 const medicalDir='ixhl2rp/plugins/medical/items/medical/';
 const definitions=fs.readdirSync(medicalDir).filter(n=>fs.readFileSync(medicalDir+n,'utf8').includes('ix.Medicine.Catalog'));
 suite('Medical catalog loads before item definitions and all EFT items have concrete names, models and doses',[catalog],
  definitions.map(n=>`ITEM={stats={}}\n${normalize(fs.readFileSync(medicalDir+n,'utf8'))}\nassert(type(ITEM.name)=='string' and #ITEM.name>0); assert(type(ITEM.model)=='string' and ITEM.model:find('.mdl',1,true)); assert(ITEM.stats.uses>0)`).join('\n'),
  `Model=function(path) assert(type(path)=='string'); return path end`);
 suite('Legacy Workshop medicine weapons cannot call missing wound globals or bypass inventory treatment',files,`
  local legacy={ClassName='weapon_eft_anaglin',Deploy=function() error('missing OJSWounds') end,Heal=function() error('bypass') end}
  local other={ClassName='weapon_pistol',Spawnable=true}
  weapons.GetList=function() return {legacy,other} end
  ix.Medicine.GuardLegacyWeapons()
  local owner={valid=true,Notify=function() end}; legacy.GetOwner=function() return owner end
  eq(legacy:Deploy(),false); eq(legacy:Heal(),false); eq(legacy.Spawnable,false); eq(other.Spawnable,true)
  local deploy=legacy.Deploy; ix.Medicine.GuardLegacyWeapons(); eq(legacy.Deploy,deploy)
 `);
 suite('Examination reports visible injuries and limb-specific medicines only while the patient is reachable',
 [...files,'ixhl2rp/plugins/medical/sv_examination.lua'],`
  local viewer,patient=newMedic(),newMedic()
  local fracture=patient.character.hp:AddHediff('fracture',4,{severity=5})
  fracture.IsVisible=function() return true end; fracture.Stage=function() return 'Broken arm' end
  local splint=medicalItem(viewer,'eft_splint'); splint.functions={inject={}}
  local transmitted; local replies=0
  net.ReadEntity=function() return patient end; net.WriteEntity=function() end
  net.WriteTable=function(data) transmitted=data end; net.Send=function() replies=replies+1 end
  local examine=net.handlers.ixMedicalExamine
  examine(16,viewer); eq(replies,1)
  eq(transmitted.parts[5].injuries[1],'Broken arm'); eq(transmitted.parts[5].medicines[1],splint.id)
  eq(#transmitted.parts[7].medicines,0)
  examine(16,viewer); eq(replies,1)
  clock=clock+1; viewer.restricted=true; examine(16,viewer); eq(replies,1)
  viewer.restricted=false; clock=clock+1; ix.Medicine.Reachable=function() return false end
  examine(16,viewer); eq(replies,1)
 `);
 suite('Medicine fractures restrict the correct limbs; analgesic expiry restores restrictions without healing',files,`
 local h=newHealth(); h:AddHediff('fracture',4,{severity=5})
 assert(ix.Medicine.HasFracture(h,'arm')); eq(ix.Medicine.HasFracture(h,'leg'),false)
 local now=os.time(); local pain=h:AddHediff('painkiller',0,{severity=10,tended_start=now,tended_time=180})
 assert(ix.Medicine.PainSuppressed(h,now+179)); eq(ix.Medicine.PainSuppressed(h,now+180),false)
 eq(ix.Medicine.HasFracture(h,'arm'),false); assert(ix.Medicine.HasFracture(h,'arm',true))
 pain.tended_start=now-181; assert(ix.Medicine.HasFracture(h,'arm'))
 local p=newMedic(); p.character.hp=h
 local rifle={valid=true,HoldType='ar2'}; local pistol={valid=true,HoldType='pistol'}
 eq(ix.Medicine.CanUseWeapon(p,rifle),false); eq(ix.Medicine.CanUseWeapon(p,pistol),true)
 rifle.ixItem={twoHanded=false}; eq(ix.Medicine.CanUseWeapon(p,rifle),true)
 `);
 suite('Medicine selected-limb treatment preserves unrelated fractures and blood; kits cannot mend bones',files,`
 local p=newMedic(); local h=p.character.hp
 local arm=h:AddHediff('fracture',4,{severity=5}); local leg=h:AddHediff('fracture',6,{severity=5})
 local wound=h:AddHediff('cut',4,{severity=20}); local blood=h:AddHediff('bleeding',0,{severity=.4})
 ix.Medicine.Apply(medicalItem(p,'healthkit'),p,p,4)
 eq(arm.severity,5); eq(leg.severity,5); eq(#h.hediffs,3); eq(blood.severity,.4)
 ix.Medicine.Apply(medicalItem(p,'eft_splint'),p,p,4)
 eq(#h.hediffs,2); assert(ix.Medicine.HasFracture(h,'leg')); eq(ix.Medicine.HasFracture(h,'arm'),false)
 eq(ix.Medicine.Eligible(medicalItem(p,'eft_splint'),p,4),false)
 ix.Medicine.Apply(medicalItem(p,'morphine'),p,p,0)
 eq(ix.Medicine.HasFracture(h,'leg'),false); assert(ix.Medicine.HasFracture(h,'leg',true)); eq(blood.severity,.4)
 `);
 suite('Volume budgets charge actual healing and dressing, preserve leftovers and restrict fracture repair',files,`
 local p=newMedic(); local h=p.character.hp
 local wound=h:AddHediff('cut',4,{severity=20})
 local item=medicalItem(p,'eft_afak',400)
 local plan=ix.Medicine.VolumePlan(item,h,4); near(plan.cost,70)
 local result=ix.Medicine.Apply(item,p,p,4); near(result.resourceCost,70); near(result.dmg,20)
 eq(#h.hediffs,0); eq(ix.Medicine.Eligible(item,p,4),false)
 wound=h:AddHediff('cut',4,{severity=20}); item.uses=49
 eq(ix.Medicine.Eligible(item,p,4),false)
 item.uses=55; result=ix.Medicine.Apply(item,p,p,4)
 near(result.resourceCost,55); near(wound.severity,15); eq(wound.tended_time,0)
 item.uses=7; result=ix.Medicine.Apply(item,p,p,4)
 near(result.resourceCost,7); near(wound.severity,8)
 h.hediffs={}; h:AddHediff('fracture',4,{severity=5})
 for id,def in pairs(ix.Medicine.Catalog) do
  if def.kind~='splint' and def.kind~='surgery' then
   ix.Medicine.Apply(medicalItem(p,id),p,p,4)
   assert(ix.Medicine.HasFracture(h,'arm',true))
  end
 end
 local cms=medicalItem(p,'eft_surgery',5)
 local wound=h:AddHediff('cut',4,{severity=20})
 local result=ix.Medicine.Apply(cms,p,p,4)
 eq(ix.Medicine.HasFracture(h,'arm',true),false); eq(ix.Medicine.Catalog.eft_splint.uses,1)
 eq(wound.severity,20); eq(wound.tended_time,-1)
 eq(ix.Medicine.Eligible(cms,p,4),false)
 eq(ix.Medicine.Catalog.eft_surgery.capacity,nil)

 `);
 suite('CMS consumes one of five uses per fracture and cannot treat ordinary wounds',files,`
 local p=newMedic(); local h=p.character.hp; local cms=medicalItem(p,'eft_surgery',5)
 for remaining=4,0,-1 do
  h:AddHediff('fracture',4,{severity=5})
  ix.Medicine.Begin(cms,p,4); assert(p.ixMedicalSession)
  ix.Medicine.Finish(p,true); flush()
  eq(ix.Medicine.HasFracture(h,'arm',true),false)
  if remaining>0 then eq(cms.uses,remaining) else assert(cms.removed) end
 end
 `);
 suite('Volume completion spends only the current plan and cancellation preserves capacity',files,`
 local p=newMedic(); local item=medicalItem(p,'eft_afak',400)
 p.character.hp:AddHediff('cut',4,{severity=20})
 ix.Medicine.Begin(item,p,4); assert(p.ixMedicalSession)
 ix.Medicine.Finish(p,false); eq(item.uses,400); flush()
 ix.Medicine.Begin(item,p,4); assert(p.ixMedicalSession)
 ix.Medicine.Finish(p,true); eq(item.uses,330)
 ix.Medicine.Finish(p,true); eq(item.uses,330)
 `);
 suite('Epinephrine wakes a stabilized patient on completion, preserves wounds, and expires without a cached consciousness boost',files,`
 local p,t=newMedic(),newMedic(); t.critical=true; t.knocked=true; t.ixRegainConscious=true
 function t:SetLocalVar(k,v) self[k]=v end
 function t:SetCriticalState(v) self.critical=v; self.wakes=(self.wakes or 0)+1 end
 function t:SetRagdolled(v) self.ragdolled=v end
 local h=t.character.hp; h.cachedConscious=0.1
 h.GetConsciousness=HealthConsciousness
 local wound=h:AddHediff('bruise',4,{severity=20})
 local blood=h:AddHediff('bleeding',0,{severity=.4})
 local item=medicalItem(p,'epinephrine',1)
 ix.Medicine.Begin(item,t,0); local session=p.ixMedicalSession; assert(session); eq(t.critical,true)
 clock=clock+.2; session.weapon:Think(); eq(t.critical,true)
 clock=clock+1.1; session.weapon:Think()
 eq(item.removed,true); eq(t.critical,false); eq(t.knocked,false); eq(t.ragdolled,false)
 eq(t.ixRegainConscious,nil); eq(wound.severity,20); eq(blood.severity,.4)
 near(h:GetConsciousness(),.5); ix.Medicine.Finish(p,true); eq(t.wakes,1)
 for _,d in h:GetHediffs() do if d.uniqueID=='epinephrine_revival' then d.tended_start=os.time()-90 end end
 near(h:GetConsciousness(),.1)
 `,'HEALTH={}\n'+normalize(fs.readFileSync('ixhl2rp/plugins/!healthsystem/sh_health.class.lua','utf8').split('function HEALTH:GetConsciousness()')[1].split('if SERVER then')[0].replace(/^/,'function HEALTH:GetConsciousness()'))+'\nHealthConsciousness=HEALTH.GetConsciousness');
 suite('Revival rejects unstable patients without consumption and other stimulants cannot wake them',files,`
 local p,t=newMedic(),newMedic(); t.critical=true; local h=t.character.hp
 local item=medicalItem(p,'epinephrine',1)
 h.bleed=1; ix.Medicine.Begin(item,t,0); eq(p.ixMedicalSession,nil); eq(item.removed,nil)
 h.bleed=0; local blood=h:AddHediff('bleeding',0,{severity=.8})
 eq(ix.Medicine.Eligible(item,t,0),false); blood.severity=.2
 h.partHP=0; eq(ix.Medicine.Eligible(item,t,0),false); h.partHP=100
 ix.Medicine.Begin(item,t,0); assert(p.ixMedicalSession)
 h.bleed=1; ix.Medicine.Finish(p,true); eq(item.removed,nil); eq(t.critical,true); flush()
 h.bleed=0
 for _,id in ipairs({'eft_l1','eft_propital','morphine'}) do
  ix.Medicine.Apply(medicalItem(p,id),t,p,0); eq(t.critical,true)
  eq(ix.Medicine.ConsciousnessSupported(h),false)
 end
 t.dead=true; eq(ix.Medicine.CanRevive(t),false)
 `);
 suite('Medical completion is once-only, animation-driven and consumes a charge only on success',files,`
 local p=newMedic(); allPlayers={p}; local item=medicalItem(p,'morphine',2)
 ix.Medicine.Begin(item,p,0); local s=p.ixMedicalSession; assert(s); eq(item.uses,2)
 clock=clock+.2; s.weapon:Think(); eq(s.weapon.activity,ACT_VM_RECOIL1); eq(item.uses,2)
 clock=clock+1.1; s.weapon:Think(); eq(item.uses,1); eq(p.ixMedicalSession,nil)
 ix.Medicine.Finish(p,true); eq(item.uses,1); eq(p.character.actions,1)
 flush(); eq(s.weapon.valid,false)
 `);
 suite('Treatment cancels safely on range, restriction, patient character change, ownership loss and missing animation',files,`
 local p,t=newMedic(),newMedic(); allPlayers={p,t}
 local item=medicalItem(p,'morphine',3)
 local function start() item.player=p; ix.Medicine.Begin(item,t,0); assert(p.ixMedicalSession) end
 start(); local old=t.character; t.character={}; hooks.Think.ixMedicalSessions(); eq(item.uses,3); eq(item.inUse,nil); t.character=old; flush()
 start(); p.items={}; hooks.Think.ixMedicalSessions(); eq(item.uses,3); eq(item.inUse,nil); p.items={item}; flush()
 start(); p.restricted=true; hooks.Think.ixMedicalSessions(); eq(item.uses,3); p.restricted=false; flush()
 start(); local reachable=ix.Medicine.Reachable; ix.Medicine.Reachable=function() return false end
 hooks.Think.ixMedicalSessions(); eq(item.uses,3); ix.Medicine.Reachable=reachable; flush()
 start(); p.badSequence=true; clock=clock+.2; p.active:Think(); eq(p.ixMedicalSession,nil); eq(item.uses,3); flush()
 file.Exists=function() return false end; ix.Medicine.Begin(item,t,0); eq(item.inUse,nil); eq(item.uses,3)
 `);
 suite('Transfusion items stay usable and donation refuses injured or critically ill donors',files,`
 local p=newMedic(); local h=p.character.hp; local bag=medicalItem(p,'bloodbag_empty')
 assert(ix.Medicine.Eligible(bag,p,0)); h:AddHediff('bleeding',0,{severity=.3})
 eq(ix.Medicine.Eligible(bag,p,0),false); assert(ix.Medicine.Eligible(medicalItem(p,'bloodbag'),p,0))
 h.hediffs={}; eq(ix.Medicine.Eligible(medicalItem(p,'ivbag'),p,0),false)
 h.bleed=1; eq(ix.Medicine.Eligible(bag,p,0),false)
 `);
 suite('Severe limb injury adds one fracture; mild, torso and fracture damage cannot recurse',files,`
 local h=newHealth(); h.partHP=10; local fn=hooks.OnHediffAdded.ixMedicalFractures
 fn(h,{isInjury=true},4); eq(#h.hediffs,1)
 fn(h,{isInjury=true},4); eq(#h.hediffs,1)
 fn(h,{isInjury=true,isFracture=true},6); eq(#h.hediffs,1)
 fn(h,{isInjury=true},2); eq(#h.hediffs,1)
 h.partHP=100; fn(h,{isInjury=true},6); eq(#h.hediffs,1)
 `);
 // Exercise the real early movement branch, including the cap on both speed APIs.
 const movement=fs.readFileSync(__dirname+'/../ixhl2rp/plugins/!healthsystem/sh_movement.lua','utf8');
 const fn=movement.slice(movement.indexOf('function PLUGIN:SetupMove'));
 suite('Broken-leg movement removes sprint and applies the same walking cap on client and server',files,`
 local p=newMedic(); local h=p.character.hp; h.cachedMovement=1; h:AddHediff('fracture',6,{severity=5})
 function p:GetStopModifier() return 1 end; function p:OnGround() return false end; function p:GetLocalVar() end
 function p:SetSprintMove(v) self.sprinting=v end; function p:SetSprintSpeed(v) self.speed=v end
 function p:SetRunFading(v) self.fading=v end
 local mv={buttons=IN_SPEED}
 function mv:GetButtons() return self.buttons end; function mv:SetButtons(v) self.buttons=v end
 function mv:SetMaxClientSpeed(v) self.client=v end; function mv:SetMaxSpeed(v) self.server=v end
 PLUGIN:SetupMove(p,mv,{}); eq(mv.buttons,0); near(mv.client,55); near(mv.server,55); eq(p.sprinting,false)
 `,'ix.config.Get=function() return 100 end\nbit={band=function(a,b) return a & b end,bnot=function(a) return ~a end}\n'+normalize(fn));
 suite('Medical inventory actions pass selected patient and limb through the actual inventory argument order',
  [...files,'ixhl2rp/plugins/medical/items/base/medical.lua'],`
 local p,t=newMedic(),newMedic()
 local item=setmetatable({functions={},data={},player=p},{__index=ix.meta.ItemMedical})
 function item:AddData() end
 function item:GetData(k,d) return self.data[k] or d end
 function item:GetEntity() return nil end
 item:Init(); eq(item:GetUses(),1)
 ix.Medicine.Begin=function(i,target,limb) eq(i,item); captured={target,limb}; return false end
 item.functions.inject.OnRun(item,{1},{target=t,limb=4}); eq(captured[1],t); eq(captured[2],4)
 item.functions.use.OnRun(item,{1},{limb=6}); eq(captured[1],p); eq(captured[2],6)
 item.inUse=p; eq(item.functions.use.OnCanRun(item),false)
 item.inUse=nil; item.uniqueID='eft_afak'; item.stats.uses=5; item.data.uses=2
 function item:SetData(k,v) self.data[k]=v end
 near(item:GetUses(),160); eq(item:GetCapacity(),400)
 item:SetResource(73.5); near(item:GetUses(),73.5)
 item.data.uses=5; near(item:GetUses(),73.5)
 item.data.volume=0; eq(item:GetUses(),0)
 item:OnInstanced(true); eq(item:GetUses(),400)
 local donor=setmetatable({uniqueID='eft_afak',stats={uses=5},data={volume=80}}, {__index=item})
 function donor:Remove() self.removed=true end
 item:SetResource(350); donor.combine.comb.OnRun(donor,item)
 eq(item:GetUses(),400); eq(donor:GetUses(),30)
 item.uniqueID='eft_surgery'; item.stats.uses=5; item.data={volume=350,uses=5}
 eq(item:GetUses(),3); item:SetResource(2); eq(item:GetUses(),2); eq(item.data.volume,nil)
 item:OnInstanced(true); eq(item:GetUses(),5)
 donor.uniqueID='eft_splint'; donor.stats.uses=1; donor.data={uses=5}
 eq(donor:GetUses(),1)

 `,`local oldClass=class; function class(name) local c=oldClass(name); c.implements=function(self) return self end; return c end
 ix.transmit={owner=1}`);
 suite('Medical examination tolerates synchronous layout before and during child creation',
 ['ixhl2rp/plugins/medical/cl_examination.lua'],`
 local panel=setmetatable({}, {__index=examPanel})
 local noop=function() end
 function panel:SetSize(w,h) self.w=w; self.h=h; self:PerformLayout(w,h) end
 function panel:Center() self:PerformLayout(self.w,self.h); self.centered=true end
 for _,name in ipairs({'SetTitle','ShowCloseButton','SetDraggable','MakePopup','SetAlpha','AlphaTo'}) do panel[name]=noop end
 function panel:Add()
  self:PerformLayout(self.w,self.h)
  return {valid=true,SetText=noop,SetFont=noop,SetTextColor=noop,SetWrap=noop,SetContentAlignment=noop,
   SetPos=function(child,x,y) child.x=x; child.y=y end,
   SetSize=function(child,w,h) child.w=w; child.h=h end}
 end
 panel:PerformLayout(1000,780); panel:Init()
 assert(panel.centered); eq(panel.close.x,826); eq(panel.close.w,150)
 near(panel.info.x,510); near(panel.info.h,600)
 panel.close.valid=false; panel:PerformLayout(800,600); near(panel.info.x,408)
 `,`ix.Medicine={}; Color=function(...) return {...} end
 ScrW=function() return 1920 end; ScrH=function() return 1080 end
 CurTime=function() return 0 end; vgui={Register=function(_,panel) examPanel=panel end}
 net.Receive=function() end`);
 suite('H opens one combined menu per press in single-player, ignores text input and leaves E world use intact',
 ['ixhl2rp/plugins/radialmenu.lua','ixhl2rp/plugins/player_controls/cl_controls.lua'],`
  hooks.Think.ixPlayerControlKeys(); eq(opened,0)
  down=true; hooks.Think.ixPlayerControlKeys(); eq(opened,1); eq(lastPersonal,true); eq(lastTarget,nil)
  hooks.Think.ixPlayerControlKeys(); eq(opened,1); assert(IsValid(ix.gui.charRadial))
  down=false; hooks.Think.ixPlayerControlKeys(); down=true; hooks.Think.ixPlayerControlKeys(); eq(ix.gui.charRadial.valid,false)
  down=false; hooks.Think.ixPlayerControlKeys()
  focus={valid=true,GetClassName=function() return 'TextEntry' end}; down=true; hooks.Think.ixPlayerControlKeys(); eq(opened,1)
  down=false; hooks.Think.ixPlayerControlKeys(); focus=nil
  target={valid=true,IsPlayer=function() return true end,GetCharacter=function() return {} end}
  down=true; hooks.Think.ixPlayerControlKeys(); eq(opened,2); eq(lastTarget,target); eq(lastPersonal,true)
  eq(PLUGIN:ShowEntityMenu(target),true)
  eq(PLUGIN:ShowEntityMenu({valid=true,IsPlayer=function() return false end,GetClass=function() return 'prop_physics' end}),nil)
  radialPanel.OnKeyCodePressed({Remove=function() error('opening key closed menu') end},KEY_H)
 `,`CLIENT=true; SERVER=false; KEY_H=18; KEY_J=20; KEY_N=22; KEY_ESCAPE=70; KEY_TAB=71; KEY_LAST=100; MOUSE_LEFT=107; MOUSE_5=111
 surface={CreateFont=function() end}; Color=function(...) return {...} end
 hooks={}; hook.Add=function(event,name,fn) hooks[event]=hooks[event] or {}; hooks[event][name]=fn end; hook.Remove=function() end
 commands={}; concommand={Add=function(name,fn) commands[name]=fn end}
 RunConsoleCommand=function(name) commands[name]() end
 CreateClientConVar=function() return {GetBool=function() return true end} end
 down=false; input={IsKeyDown=function(key) return key==KEY_H and down end,IsKeyTrapping=function() return false end,LookupKeyBinding=function() return nil end}
 gui={IsGameUIVisible=function() return false end}
 ix.gui={}; ix.menu={IsOpen=function() return false end}
 opened=0; vgui={Register=function(name,p) if name=='ixCharRadialMenu' then radialPanel=p end end,GetKeyboardFocus=function() return focus end,CursorVisible=function() return false end}
 ix.lang={AddTable=function() end}; ix.type={number=1}; ix.option={stored={}}
 ix.option.Add=function(key,kind,default,data) ix.option.stored[key]={default=default} end
 ix.option.Get=function(key) return ix.option.stored[key].default end
 vgui.Create=function()
  opened=opened+1; return {valid=true,SetTarget=function(_,t,e,r,p) lastTarget=t; lastPersonal=p end,Remove=function(s) s.valid=false end}
 end
 local point=setmetatable({},{__add=function(s) return s end,__mul=function(s) return s end})
 client={valid=true,GetCharacter=function() return {} end,Alive=function() return true end,GetShootPos=function() return point end,GetAimVector=function() return point end}
 LocalPlayer=function() return client end
 util.TraceLine=function() return {Entity=target} end
 `);
 suite('Radial personal actions work without a target, paginate large inventories and keep medical targets',
 ['ixhl2rp/plugins/radialmenu.lua'],`
 local pnl=setmetatable({menuStack={},options={},SetAlpha=function() end,AlphaTo=function() end},{__index=radialPanel})
 pnl:SetTarget(nil,nil,false,true); eq(#pnl.options,3); assert(pnl.options[1].disabled)
 pnl.options[2].callback(); eq(examined,client)
 local function head(id,slot,equipped)
  return {id=id,equip_inv=slot,functions={equip={index=1},unequip={index=2}},GetName=function() return slot end,
   IsEquipped=function() return equipped end,GetData=function() return false end}
 end
 client.items={head(1,'glasses',false),head(2,'mask',true),head(3,'head',false),head(4,'torso',false)}
 pnl:SetTarget(nil,nil,false,true); eq(#pnl.options[3].children,3)
 pnl:PushOptions(pnl.options[3].children,'Head'); pnl.options[1].callback()
 eq(sentID,1); eq(sentAction,1)
 pnl.options[3].callback(); eq(sentID,2); eq(sentAction,2)
 assert(pnl:PopOptions())
 local many={}; for i=1,19 do many[i]={label='item'..i} end
 pnl:PushOptions(many,'Weapons'); eq(#pnl.options,7)
 pnl.page=5; pnl:PageOptions(); eq(pnl.options[1].label,'item17'); assert(pnl.options[5].disabled)
 assert(pnl:PopOptions()); eq(#pnl.options,3)
 `,`CLIENT=true; SERVER=false
 surface={CreateFont=function() end}; Color=function(...) return {...} end
 vgui={Register=function(_,p) radialPanel=p end}; hook.Add=function() end; hook.Remove=function() end
 input={IsKeyDown=function() return false end}
 concommand={Add=function() end}; CreateClientConVar=function() return {GetBool=function() return true end} end
 client={valid=true,items={}}; function LocalPlayer() return client end
 function client:GetItems() return self.items end
 function client:GetCharacter() return self end
 ix.Medicine={OpenExamination=function(p) examined=p end}
 net.Start=function() writes=0 end; net.WriteUInt=function(v) writes=writes+1; if writes==1 then sentID=v elseif writes==3 then sentAction=v end end; net.WriteTable=function(t) sent=t end; net.WriteBool=function() end; net.SendToServer=function() end`);
};
