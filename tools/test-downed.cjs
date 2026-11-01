module.exports = function(suite) {
 require('./test-downed-legacy.cjs')(suite);
 const fs=require('fs'),path=require('path');
 const combat=fs.readFileSync(path.join(__dirname,'../ixhl2rp/plugins/!healthsystem/sv_combat.lua'),'utf8');
 const stamina=require('./glua.cjs').normalize(combat.slice(combat.indexOf('local function ApplyStaminaDamage('),combat.indexOf('function PLUGIN:EvasionChance(')));
 const setup=`
 ix.Downed={HoldTime=1.5}; ix.config.Get=function(k,d) return d end
 char={data={},GetData=function(self,k,d) if self.data[k]~=nil then return self.data[k] end return d end,SetData=function(self,k,v) self.data[k]=v end}
 p=setmetatable({valid=true,alive=true,vars={crit=true,downedSince=1},character=char,kills=0},{__index=FindMetaTable('Player')})
 function p:GetCharacter() return self.character end
 function p:Alive() return self.alive end
 function p:GetNetVar(k,d) if self.vars[k]~=nil then return self.vars[k] end return d end
 function p:SetNetVar(k,v) self.vars[k]=v end
 function p:SetLocalVar(k,v) self.vars[k]=v end
 function p:SetHealth(v) self.hp=v end
 function p:SetAction() end
 function p:Kill() self.kills=self.kills+1; self.alive=false end
 function p:SetRagdolled() self.ixRagdoll={valid=true} end
 function p:IsPlayer() return true end
 function p:IsNPC() return false end
 function p:IsNextBot() return false end
 function char:Health() return hp end
 DMG_SLASH=1; DMG_CLUB=2; DMG_ENERGYBEAM=3
 net.ReadUInt=function() return operation end
 `;
 const crawlSetup=setup+fs.readFileSync(path.join(__dirname,'geometry-fixture.lua'),'utf8')+
  fs.readFileSync(path.join(__dirname,'fixtures/critical-fall.lua'),'utf8')+
  require('./glua.cjs').normalize(combat.slice(combat.lastIndexOf('\ndo\n\tlocal PLAYER')>=0
   ?combat.lastIndexOf('\ndo\n\tlocal PLAYER'):combat.lastIndexOf('\r\ndo\r\n\tlocal PLAYER')));
 suite('Self give-up requires a timed hold and rejects cancellation, stale episodes and duplicate completion',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sv_downed.lua'], `
 local receive=net.handlers.ixDownedGiveUp
 local function packet(op) operation=op;receive(2,p) end
 packet(2);eq(p.kills,0)
 packet(0);clock=clock+1;packet(2);eq(p.kills,0);eq(p.ixGiveUpRequest,nil)
 packet(0);clock=clock+2;p.vars.downedSince=2;packet(2);eq(p.kills,0)
 packet(0);clock=clock+2;packet(1);packet(2);eq(p.kills,0)
 packet(0);clock=clock+9;packet(2);eq(p.kills,0)
 local dropped=0;ix.BodyDrag={DropPatient=function(patient) eq(patient,p);dropped=dropped+1 end}
 packet(0);clock=clock+1.5;packet(2);packet(2)
 eq(p.kills,1);eq(dropped,1);eq(p.KilledByRP,false);eq(p.KilledBySystem,true)
 PLUGIN:PlayerSpawn(p);eq(p.ixDownedEnding,nil);eq(p.vars.crit,nil)
 p.alive=true;packet(0);eq(p.ixGiveUpRequest,nil)
 `,setup);
 suite('Give-up packets affect only their sender, require the same character and reject malformed payloads',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sv_downed.lua'], `
 local receive=net.handlers.ixDownedGiveUp
 operation=0;receive(0,p);receive(34,p);eq(p.ixGiveUpRequest,nil)
 receive(2,p);clock=clock+2;p.character={};operation=2;receive(2,p);eq(p.kills,0)
 p.character=char;operation=0;receive(2,p);clock=clock+2
 local other=setmetatable({valid=true,alive=true,vars={crit=true,downedSince=1},character=char,kills=0},{__index=p})
 other.ixGiveUpRequest=false;operation=2;receive(2,other);eq(other.kills,0);eq(p.kills,0)
 receive(2,p);eq(p.kills,1);eq(other.kills,0)
 `,setup);
 suite('Damage cannot execute casualties and third parties still need Finish off or Rob',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sv_downed.lua'], `
 eq(ix.Downed.EndLife(p),false);eq(ix.Downed.EndLife(p,true),false)
 eq(ix.Downed.FinishAction(p,p,'finish'),false)
 local actor={valid=true,Alive=function() return true end,GetCharacter=function() return char end}
 eq(ix.Downed.FinishAction(p,actor,'giveup'),false)
 eq(ix.Downed.FinishAction(p,actor,'damage'),false)
 eq(ix.Downed.FinishAction(p,actor,'finish'),true);eq(ix.Downed.FinishAction(p,actor,'finish'),false)
 eq(p.kills,1); eq(p.KilledByRP,false); eq(p.KilledBySystem,false)
 PLUGIN:PlayerSpawn(p);p.alive=true;p.vars.crit=true
 eq(ix.Downed.FinishAction(p,actor,'rob'),true);eq(p.kills,2);eq(p.KilledBySystem,false)
 `,setup);
 suite('Medical revival invalidates a pending give-up even if its completion arrives afterwards',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sv_downed.lua','ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua'], `
 local receive=net.handlers.ixDownedGiveUp
 operation=0;receive(2,p);assert(p.ixGiveUpRequest)
 p:SetCriticalState(false);eq(p.ixGiveUpRequest,nil)
 clock=clock+2;operation=2;receive(2,p);eq(p.kills,0)
 `,setup);
 suite('Critical damage falls visibly for 5 seconds, restores weapons into 25-second crawl, then becomes unconscious',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua','ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua'], `
 p.vars.crit=nil;p:SetCriticalState(true)
 eq(ix.Downed.Falling(p),true);eq(ix.Downed.CrawlWindow(p),false);eq(p.vars.knocked,false)
 assert(IsValid(p.ixRagdoll));eq(p.hidden,true);eq(#p.weapons,0);eq(p.created,1)
 local deadline=p.vars.criticalCrawlUntil;eq(deadline,clock+30)
 local body=p.ixRagdoll
 clock=clock+4.9;p:SetCriticalState(true);eq(p.vars.criticalCrawlUntil,deadline)
 ix.Downed.CrawlTick(p);eq(p.ixRagdoll,body);eq(p.created,1)
 clock=clock+.1;ix.Downed.CrawlTick(p);eq(IsValid(p.ixRagdoll),false)
 eq(ix.Downed.CrawlWindow(p),true);eq(deadline-clock,25);eq(p.vars.crit,true);eq(p.hp,1)
 eq(p.hidden,false);eq(p.notSolid,false);eq(p.move,MOVETYPE_WALK);eq(p.flags,FL_DUCKING)
 eq(p.pos.x,120);eq(p.pos.z,1);eq(p.active:GetClass(),'ix_hands');eq(#p.weapons,2)
 eq(p:GetWeapon('arc9_eft_ak74'):Clip1(),23);eq(p:GetAmmoCount(),90);eq(p.ixCriticalCrawlHandoff,nil)
 clock=deadline;ix.Downed.CrawlTick(p);assert(p.ixRagdoll);eq(p.vars.knocked,true)
 eq(p.created,2);eq(p.kills,0);eq(p.vars.criticalCrawlUntil,nil);eq(char.data.criticalCrawlDeadline,0)
 p.ixRagdoll=nil;p.vars.crit=nil;p:SetCriticalState(true);eq(p.vars.criticalCrawlUntil,nil)
 p:SetCriticalState(false);eq(char.data.criticalCrawlDeadline,nil)
 p.ixRagdoll=nil;p.vars.knocked=false;p:SetCriticalState(true);assert(ix.Downed.Falling(p))
 p:SetCriticalState(false);eq(ix.Downed.CrawlWindow(p),false)
 `,crawlSetup);
 suite('Crawl reconnect preserves remaining time and missing animation content cannot cancel the window',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua','ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua'], `
 char.data.crit=true;char.data.criticalCrawlDeadline=os.time()+8;p.vars.crit=nil
 p:SetCriticalState(true);assert(p.vars.criticalCrawlUntil<=clock+8);assert(p.vars.criticalCrawlUntil>=clock+7)
 p:SetCriticalState(false);p.ixRagdoll=nil;p.LookupSequence=function() return -1 end
 p:SetCriticalState(true);eq(p.vars.criticalCrawlUntil,clock+30);eq(p.vars.knocked,false);assert(IsValid(p.ixRagdoll))
 clock=clock+5;ix.Downed.CrawlTick(p);eq(IsValid(p.ixRagdoll),false);eq(ix.Downed.CrawlWindow(p),true)
 clock=clock+30;ix.Downed.CrawlTick(p);assert(p.ixRagdoll);eq(p.vars.criticalCrawlUntil,nil)
 `,crawlSetup);
 suite('Fall reconnect, seated entry, blocked ground and early medical revival preserve the critical episode',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua','ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua'], `
 p.vars.crit=nil;p.vehicle=true;char.data.crit=true
 char.data.criticalCrawlDeadline=os.time()+27;char.data.criticalFallDeadline=os.time()+2
 p:SetCriticalState(true);assert(p.exited);eq(p.vars.criticalFallUntil,clock+2)
 local deadline=p.vars.criticalCrawlUntil;local body=p.ixRagdoll
 blocked=true;clock=clock+2;ix.Downed.CrawlTick(p);eq(p.ixRagdoll,body);eq(p.hidden,true)
 blocked=false;airborne=true;clock=clock+1;ix.Downed.CrawlTick(p);eq(p.ixRagdoll,body)
 airborne=false;clock=clock+1;ix.Downed.CrawlTick(p);eq(ix.Downed.CrawlWindow(p),true)
 eq(p.vars.criticalCrawlUntil,deadline);eq(deadline-clock,23)
 p:SetCriticalState(false);p:SetCriticalState(true);body=p.ixRagdoll
 p:SetRagdolled(false);eq(p.vars.crit,nil);eq(p.vars.criticalFallUntil,nil)
 clock=clock+40;ix.Downed.CrawlTick(p);eq(IsValid(p.ixRagdoll),false);eq(p.hp,100)
 `,crawlSetup);
 suite('A held or cart-loaded casualty never automatically returns to crawl, and animation control is released',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua','ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua'], `
 for _,field in ipairs({'ixBodyDragger','ixHeldOwner','ixPatientCart','held'}) do
  p:SetCriticalState(false);p.ixRagdoll=nil;p:SetCriticalState(true)
  local body=p.ixRagdoll;body[field]=field=='held' and true or {valid=true}
  local driver={valid=true,Remove=function(self) self.valid=false end};body.AnimModule=driver
  clock=clock+5;ix.Downed.CrawlTick(p)
  eq(p.ixRagdoll,body);eq(body.valid,true);eq(p.vars.criticalCrawlUntil,nil)
  eq(p.vars.knocked,true);eq(p.vars.crit,true);eq(p.kills,0);eq(driver.valid,false)
  clock=clock+30;ix.Downed.CrawlTick(p);eq(p.ixRagdoll,body)
 end
 `,crawlSetup);
 suite('HL2 prone sequences resolve, Cellar keeps priority, and absent assets do not disable leg loss',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua'], `
 p.vars.crit=nil
 eq(ix.Downed.CrawlSequence(p,false),7);eq(ix.Downed.CrawlSequence(p,true),8)
 eq(ix.Downed.Crawling(p),true)
 sequences.pidle_normal=0;sequences.pwalk_all=3
 eq(ix.Downed.CrawlSequence(p,false),0);eq(ix.Downed.CrawlSequence(p,true),3)
 sequences={};eq(ix.Downed.CrawlSequence(p,false),nil);eq(ix.Downed.Crawling(p),true)
 missing=false;eq(ix.Downed.Crawling(p),false)
 `,setup+`
 SERVER=false;CLIENT=true;local missing=true
 ix.Amputation={HasKind=function() return missing end}
 local sequences={prone_passive=7,prone_walkpassive=8}
 function p:LookupSequence(name) return sequences[name] or -1 end
 function p:InVehicle() return false end;function p:GetLocalVar(k,d) return self:GetNetVar(k,d) end
 `);
 suite('Real stamina-impact handler starts one conscious fall and cannot extend the rescue window',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua','ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua'], `
 local function DamageToOuterParts(h,g) return g,false end
 local function SelectArmorToHit() return 0 end
 local function SelectDamageHediff() return nil,1 end
 ${stamina}
 p.vars.crit=nil;p.vars.stm=20
 ApplyStaminaDamage({},3,{target=p,physDamage=0,staminaDamage=10,class='club'})
 eq(p.vars.crit,nil);eq(p.vars.stm,10)
 ApplyStaminaDamage({},3,{target=p,physDamage=0,staminaDamage=30,class='club'})
 eq(ix.Downed.Falling(p),true);assert(IsValid(p.ixRagdoll));eq(p.vars.knocked,false)
 local deadline=p.vars.criticalCrawlUntil;eq(deadline,clock+30)
 clock=clock+2
 ApplyStaminaDamage({},3,{target=p,physDamage=0,staminaDamage=30,class='club'})
 eq(p.vars.criticalCrawlUntil,deadline)
 `,crawlSetup+`
 function p:ConsumeStamina(v) self.vars.stm=self.vars.stm-v end
 `);
 suite('Missing legs force crawl, movement preserves use but blocks combat, and recovery restores camera',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua'], `
 p.vars.crit=nil;eq(ix.Downed.Crawling(p),true)
 local mv={buttons=IN_USE+IN_JUMP+IN_SPEED+IN_ATTACK+IN_ATTACK2}
 function mv:GetButtons() return self.buttons end;function mv:SetButtons(v) self.buttons=v end
 function mv:SetMaxSpeed(v) self.speed=v end;function mv:SetMaxClientSpeed(v) self.clientSpeed=v end
 eq(ix.Downed.CrawlMove(p,mv),true);eq(mv.buttons,IN_USE+IN_DUCK);eq(mv.speed,17.5);eq(mv.clientSpeed,17.5)
 eq(p.view.z,18);eq(p.standingView.z,18);eq(p.crouchSpeed,1)
 local cmd={buttons=IN_USE+IN_ATTACK+IN_RELOAD}
 function cmd:GetButtons() return self.buttons end;function cmd:SetButtons(v) self.buttons=v end
 function cmd:RemoveKey(v) self.buttons=bit.band(self.buttons,bit.bnot(v)) end
 ix.Downed.CrawlCommand(p,cmd);eq(cmd.buttons,IN_USE+IN_DUCK)
 missing=false;eq(ix.Downed.CrawlMove(p,mv),false);eq(p.view.z,28);eq(p.standingView.z,64);eq(p.crouchSpeed,.3)
 eq(p.ixCrawlView,nil);eq(p.ixCrawlStandingView,nil)
 `,setup+`
 SERVER=false;CLIENT=true;local missing=true
 ix.Amputation={HasKind=function() return missing end}
 function p:LookupSequence() return 12 end
 function p:InVehicle() return false end;function p:GetLocalVar(k,d) return self:GetNetVar(k,d) end
 function Vector(x,y,z) return {x=x,y=y,z=z} end
 p.view=Vector(0,0,28);p.standingView=Vector(0,0,64);p.crouchSpeed=.3
 function p:GetViewOffset() return self.standingView end;function p:SetViewOffset(v) self.standingView=v end
 function p:GetViewOffsetDucked() return self.view end;function p:SetViewOffsetDucked(v) self.view=v end
 function p:GetCrouchedWalkSpeed() return self.crouchSpeed end;function p:SetCrouchedWalkSpeed(v) self.crouchSpeed=v end
 IN_JUMP=2;IN_SPEED=4;IN_ATTACK=8;IN_ATTACK2=16;IN_DUCK=32;IN_USE=64;IN_RELOAD=128
 bit={bor=function(a,b) return a|b end,band=function(a,b) return a&b end,bnot=function(a) return ~a end}
 `);
 suite('Gunfire cannot finish a downed player; blood and recovery follow real health data',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua'], `
 local D=ix.Downed
 local attacker={valid=true,IsPlayer=function() return true end}
 local d={amount=20,actor=attacker,bullet=true}
 function d:GetAttacker() return self.actor end
 function d:GetDamage() return self.amount end
 function d:IsBulletDamage() return self.bullet end
 function d:IsExplosionDamage() return false end
 function d:IsDamageType(kind) return self.kind==kind end
 eq(D.ShouldFinish(p,d),false); d.amount=3; eq(D.ShouldFinish(p,d),false)
 d.amount=50; d.actor=p; eq(D.ShouldFinish(p,d),false)
 d.actor=attacker; d.bullet=false; eq(D.ShouldFinish(p,d),false)
 d.kind=DMG_ENERGYBEAM; eq(D.ShouldFinish(p,d),false)
 d.kind=DMG_CLUB; eq(D.ShouldFinish(p,d),false)
 local condition={uniqueID='bleeding',GetSeverity=function() return 0.7 end}
 hp={character=char,hediffs={condition},GetConsciousness=function() return 1 end,
 GetPartHealth=function() return 10 end,GetBleedRate=function() return 0 end}
 near(D.Blood(char),0.3); eq(D.CanRecover(hp),true)
 hp.GetBleedRate=function() return 1 end; eq(D.CanRecover(hp),false)
 condition.GetSeverity=function() return 0.99 end; near(D.Blood(char),0.01)
 `,setup);
 suite('Critical entry is idempotent, tolerates missing ragdolls, and recovery invalidates pending surrender',
 ['ixhl2rp/plugins/!healthsystem/sv_criticalstate.lua'], `
 p.vars.crit=nil; p:SetCriticalState(true); eq(p.vars.crit,true); eq(p.vars.knocked,true); eq(p.hp,1)
 local first=p.vars.downedSince; clock=clock+5; p:SetCriticalState(true); eq(p.vars.downedSince,first)
 eq(char.data.critTime,nil); p.ixGiveUpRequest={}; p:SetCriticalState(false)
 eq(p.ixGiveUpRequest,nil); eq(p.vars.crit,nil)
 p.ixRagdoll=nil; p.SetRagdolled=function() end; p:SetCriticalState(true); eq(p.vars.crit,true)
 `,setup);
 suite('Blood loss stays critical instead of killing over prolonged bleeding',
 ['ixhl2rp/plugins/!healthsystem/sh_effects.define.lua'], `
 local condition=conditions.bleeding; condition.severity=0.98; condition.Send=function() end
 local count=0; local client={valid=true,Alive=function() return true end,
 SetCriticalState=function() count=count+1 end,Kill=function() error('Passive bleeding killed player') end}
 local health={GetBleedRate=function() return 5 end,GetPlayer=function() return client end,
 character={GetID=function() return 1 end,GetPlayer=function() return client end}}
 for i=1,1000 do condition:OnTick(health) end
 near(condition.severity,0.99); assert(count>0)
 `,`
 conditions={}; ix.Hediffs={New=function(self,id) local t={}; conditions[id]=t; return t end}
 function Color(...) return {...} end
 net.Start=function() end; net.WriteUInt=function() end; net.Send=function() end
 `);
 suite('Downed UI restores held surrender, cancels released/abandoned holds and keeps the ragdoll camera',
 ['ixhl2rp/plugins/downed_state/sh_downed.lua','ixhl2rp/plugins/downed_state/sh_crawl.lua','ixhl2rp/plugins/downed_state/cl_downed.lua'], `
 local panel=setmetatable({},{__index=panelClass})
 function panel:SetSize(w,h) self.w=w; self.h=h end
 function panel:GetWide() return self.w end
 function panel:GetTall() return self.h end
 function panel:MakePopup() end
 function panel:SetKeyboardInputEnabled() end
 function panel:SetMouseInputEnabled(v) self.mouse=v end
 function panel:InvalidateLayout() self:PerformLayout(self.w,self.h) end
 function panel:Remove() self:OnRemove();self.removed=true end
 function panel:Add() return button end
 -- No fullscreen overlay or popup in either the visible fall or crawl phase.
 local created=0;vgui.Create=function() created=created+1 end
 p.vars.criticalCrawlUntil=clock+30;p.vars.criticalFallUntil=clock+5
 hooks.ixDownedScreen();eq(created,0)
 p.vars.criticalFallUntil=nil;hooks.ixDownedScreen();eq(created,0)
 p.vars.criticalCrawlUntil=nil;hooks.ixDownedScreen();eq(created,1)
 panel:Init()
 clock=clock+1;panel:Paint(1280,720)
 assert(rectangles>=132);assert(textDraws>0);eq(textureResets,1)
 panel:PerformLayout(1280,720);assert(button.y+button.h<720);eq(panel.mouse,true)
 panel:PerformLayout(640,480);assert(button.x>=0);assert(button.x+button.w<=640);assert(button.y+button.h<480)
 panel:Think();eq(#sent,0);eq(button.visible,true)
 button:OnMousePressed(MOUSE_LEFT);eq(sent[#sent],0);eq(button.captured,true)
 clock=clock+1;panel:Think();eq(#sent,1)
 held=false;panel:Think();eq(sent[#sent],1);eq(button.started,nil);eq(button.captured,false)
 held=true;button:OnMousePressed(MOUSE_LEFT);hovered=false;panel:Think();eq(sent[#sent],1)
 hovered=true;button:OnMousePressed(MOUSE_LEFT);clock=clock+1.5;panel:Think();eq(sent[#sent],2)
 local completed=#sent;panel:Think();button:OnMouseReleased();eq(#sent,completed);eq(button.captured,false)
 clock=clock+4;panel:Think();eq(button.sent,nil)
 -- Conscious paralysis has the same camera and surrender control, with no
 -- full-screen tint, eyelids, or blood-loss blackout drawn over the scene.
 p.vars.scpParalyzed=true;panel:Think()
 local oldRects=rectangles;local oldTexts=textDraws
 panel:Paint(1280,720);eq(rectangles,oldRects);eq(textDraws,oldTexts+2)
 eq(button.visible,true);assert(button.y>600);assert(button.y+button.h<720)
 p.vars.scpParalyzed=nil;panel:Think()
 p.alive=false;panel:Paint(1280,720);panel:Think();eq(button.visible,false);eq(panel.mouse,false);p.alive=true
 -- Camera stays at the ragdoll eyes, including head-bone and blocked-trace fallbacks.
 local look={Forward=function() return 1 end}
 local body={valid=true,LookupAttachment=function() return 1 end,
 GetAttachment=function() return {Pos=100,Ang=look} end}
 Entity=function() return body end; Vector=function() return 0 end
 function p:GetLocalVar(_,fallback) return fallback end
 util.TraceHull=function(data) return {HitPos=data.endpos,StartSolid=false} end
 local view=PLUGIN:CalcView(p,30,look,90); eq(view.origin,103); eq(view.drawviewer,false)
 body.LookupAttachment=function() return 0 end; body.LookupBone=function() return 0 end
 body.GetBonePosition=function() return 80 end
 view=PLUGIN:CalcView(p,30,look,90); eq(view.origin,83)
 util.TraceHull=function() return {StartSolid=true} end
 view=PLUGIN:CalcView(p,30,look,90); eq(view.origin,80)
 button:OnMousePressed(MOUSE_LEFT);p.vars.crit=nil;panel:Think();eq(panel.removed,true);eq(sent[#sent],1)
 `,setup+`
 SERVER=false; CLIENT=true; ix.gui={}; sent={}; held=true;hovered=true
 function LocalPlayer() return p end
 function ScrW() return 1280 end; function ScrH() return 720 end
 function RealTime() return clock end
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 function Material() error('Downed screen must not depend on materials') end
 function FrameTime() return 1/60 end;function Lerp(t,a,b) return a+(b-a)*t end
 rectangles=0;textDraws=0;textureResets=0
 draw={NoTexture=function() textureResets=textureResets+1 end,
 SimpleText=function() end,SimpleTextOutlined=function() textDraws=textDraws+1 end}
 surface={CreateFont=function() end,SetDrawColor=function() end,
 DrawRect=function() rectangles=rectangles+1 end};hooks={};hook.Add=function(_,id,fn) hooks[id]=fn end
 vgui={Register=function(_,value) panelClass=value end}
 MOUSE_LEFT=1; input={IsMouseDown=function() return held end}
 net.Start=function() end; net.WriteUInt=function(v) sent[#sent+1]=v end; net.SendToServer=function() end
 button={valid=true,SetText=function() end,MouseCapture=function(self,v) self.captured=v end,
 IsHovered=function() return hovered end,SetVisible=function(self,v) self.visible=v end}
 function button:SetSize(w,h) self.w=w; self.h=h end
 function button:GetWide() return self.w end
 function button:SetPos(x,y) self.x=x; self.y=y end
 `);
 require('./test-critical-integration.cjs')(suite);
 require('./test-crawl-view.cjs')(suite);
};
