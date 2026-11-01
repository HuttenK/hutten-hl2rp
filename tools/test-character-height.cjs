const fs=require('fs');
const base=['sharedposes','pose-gizmo','body-drag'].map(f=>fs.readFileSync('tools/fixtures/'+f+'.lua','utf8')).join('\n')+`
function IsValid(x) return type(x)=='table' and x.valid==true end
function RealTime() return clock end
concommand={commands={},Add=function(name,fn) concommand.commands[name]=fn end}
local V=getmetatable(Vector()); function V:__tostring() return self.x..','..self.y..','..self.z end
local M=getmetatable(Matrix())
function M:GetField(r,c) return self[r][c] end
function M:SetScale(v) for r=1,3 do for c=1,3 do self:SetField(r,c,r==c and ({v.x,v.y,v.z})[r] or 0) end end end
function M:GetScale() return Vector(self:GetField(1,1),self:GetField(2,2),self:GetField(3,3)) end
function heightPlayer(height)
 local p=dragPlayer();p.height=height;p.scale=1;p.model='models/sd/citizens/citizen_male_01_hair1.mdl';p.calls=0;p.netWrites=0
 function p:GetCharacter() return self.nochar and nil or self.character end
 function p.character:Genetic() return {height=p.height} end
 function p:LookupBone(name) if self.unsupported then return nil end return ({['ValveBiped.Bip01_Head1']=1,['ValveBiped.Bip01_Pelvis']=2,['ValveBiped.Bip01_L_Hand']=3,['ValveBiped.Bip01_L_Forearm']=4,['ValveBiped.Bip01_L_UpperArm']=5})[name] end
 function p:GetModel() return self.model end
 function p:GetModelScale() return self.scale end
 function p:SetModelScale(n) self.scale=n;self.calls=self.calls+1 end
 function p:SetIK(n) self.ik=n end
 function p:GetNW2Float(k,d) return self.nw[k] or d end
 function p:SetNW2Float(k,v) self.nw[k]=v;self.netWrites=self.netWrites+1 end
 function p:SetHull(a,b) self.mins=a;self.maxs=b end
 function p:SetHullDuck(a,b) self.dmins=a;self.dmaxs=b end
 function p:SetViewOffset(v) self.view=v end
 function p:SetViewOffsetDucked(v) self.duck=v end
 function p:GetBoneMatrix(i) local m=Matrix();m:SetTranslation(Vector(0,0,i==4 and 12*self.scale or 0));return m end
 return p
end
`;
const shared=['ixhl2rp/plugins/character_height/sh_height.lua'];
const headwear=base+`
CLIENT=true;SERVER=false;copies={};errors={}
STUDIO_RENDER=1;STUDIO_SHADOWDEPTHTEXTURE=1073741824;STUDIO_SSAODEPTHTEXTURE=134217728
bit={bor=function(a,b) return a | b end,band=function(a,b) return a & b end}
flashlightPasses=0;beamCount=0;inFlashlight=false
render={RenderFlashlights=function(draw)
 flashlightPasses=flashlightPasses+1
 for i=1,beamCount do inFlashlight=true;draw();inFlashlight=false end
end}
function CreateMaterial() end
function ErrorNoHalt(message) errors[#errors+1]=message end
function headEntity()
 local e=heightPlayer(155);e.scale=155/180;e.sub={[1]='painted_helmet'};e.group=5;e.head=Matrix();e.draws=0
 e.head:SetTranslation(Vector(10,20,30));e.head:SetScale(Vector(e.scale,e.scale,e.scale))
 function e:GetMaterial() return '' end
 function e:GetMaterials() return {'models/sd/skin','models/sd/helmet_spetsnaz','models/sd/hair','models/sd/hats'} end
 function e:GetBodygroup(i) return i==1 and self.group or 0 end
 function e:SetBodygroup(i,v) if i==1 then self.group=v end end
 function e:GetSubMaterial(i) return self.sub[i] or '' end
 function e:SetSubMaterial(i,m) self.sub[i]=m end
 function e:GetSkin() return 2 end
 function e:SetSkin(s) self.skin=s end
 function e:GetColor() return {r=100,g=200,b=255,a=255} end
 function e:SetColor(c) self.color=c end
 function e:GetRenderAngles() return self.renderAngles end
 function e:SetPos(v) self.pos=v end
 function e:SetAngles(v) assert(getmetatable(v)==getmetatable(Angle()),'Angle expected');self.ang=v end
 function e:GetBoneMatrix(i) return self.head end
 function e:SetBoneMatrix(i,m) self.head=m end
 function e:SetNoDraw(v) self.nodraw=v end
 function e:AddCallback(_,fn) self.callback=fn end
 function e:InvalidateBoneCache() end
 function e:SetupBones() if self.callback then self.callback(self) end end
 function e:DrawModel(flags)
  self.draws=self.draws+1
  self.drawLog=self.drawLog or {};self.drawLog[#self.drawLog+1]={beam=inFlashlight,flags=flags}
  if self.drawError then error('render failed') end
 end
 return e
end
function ClientsideModel(path) local m=headEntity();m.model=path;copies[#copies+1]=m;return m end
`;
module.exports=suite=>{
 suite('Height sanitizes saved values and scales model, view, crouch and collision without compounding',shared,`
 local H=ix.CharacterHeight
 for _,value in ipairs({0/0,math.huge,-math.huge,'bad'}) do eq(H.Height(value),180) end
 eq(H.Height(90),155);eq(H.Height(900),190);eq(H.Height(175.6),176)
 for _,height in ipairs({155,180,190}) do
  local p=heightPlayer(height);H.Apply(p);local s=height/180
  near(p.scale,s);near(p.view.z,64*s);near(p.duck.z,28*s);near(p.maxs.z,72*s);near(p.dmaxs.z,36*s);near(p.maxs.x,16*s)
  eq(p.ik,true);local calls,writes=p.calls,p.netWrites
  for n=1,20 do H.Apply(p) end
  eq(p.calls,calls);eq(p.netWrites,writes)
  p.height=180;H.Apply(p);eq(p.scale,1);eq(p.maxs.z,72);eq(p.view.z,64)
 end
 `,base);
 suite('Height changes during crawling keep both eye offsets low and update the saved recovery heights',shared,`
 local p=heightPlayer(165);local H=ix.CharacterHeight
 H.Apply(p);p.ixCrawlView=p.duck;p.ixCrawlStandingView=p.view
 p.height=190;H.Apply(p)
 near(p.view.z,19);near(p.duck.z,19)
 near(p.ixCrawlStandingView.z,64*190/180);near(p.ixCrawlView.z,28*190/180)
 p.ixCrawlView=nil;p.ixCrawlStandingView=nil;H.Apply(p,true)
 near(p.view.z,64*190/180);near(p.duck.z,28*190/180)
 `,base);
 suite('Preview command is self-only, admin-only and never mutates saved character height',shared,`
 local p=heightPlayer(176);local command=concommand.commands.ix_height_preview
 function p:PrintMessage() end
 p.IsAdmin=function() return false end;command(p,nil,{'155'});eq(p.ixHeightPreview,nil)
 p.IsAdmin=function() return true end;command(p,nil,{'155'});near(p.scale,155/180);eq(p.height,176)
 command(p,nil,{'0'});eq(p.ixHeightPreview,nil);near(p.scale,176/180)
 command(p,nil,{'190'});p.character={Genetic=function() return {height=180} end};ix.CharacterHeight.Apply(p);eq(p.scale,1)
 `,base);
 suite('SD helmet pass keeps hair selection, restores custom materials and draws normal-size gear at the animated head',
 [...shared,'ixhl2rp/plugins/character_height/cl_headwear.lua'],`
 local e=headEntity();local H=ix.CharacterHeight
 assert(H.BeginHeadwear(e));eq(e:GetSubMaterial(1),'!ix_height_hidden');eq(e:GetSubMaterial(2),'');eq(e.group,5)
 H.EndHeadwear(e);eq(e:GetSubMaterial(1),'painted_helmet');eq(e:GetSubMaterial(3),'')
 local copy=copies[1];eq(copy.group,5);eq(copy.sub[0],'!ix_height_hidden');eq(copy.sub[2],'!ix_height_hidden')
 eq(copy.sub[1],'painted_helmet');eq(copy.draws,1);eq(copy.skin,2)
 near(copy.head:GetScale().x,1);near(copy.head:GetTranslation().z,30);near(e.head:GetScale().x,155/180)
 for i=1,100 do H.BeginHeadwear(e);H.EndHeadwear(e) end
 eq(#copies,1);eq(copy.draws,101)
 e.group=0;eq(H.BeginHeadwear(e),nil);e.group=5;e.scale=190/180;eq(H.BeginHeadwear(e),nil)
 H.ClearHeadwear();eq(copy.valid,false)
 `,headwear);
 suite('Manual SD helmets receive each flashlight at their current head transform without duplicating native helmets',
 [...shared,'ixhl2rp/plugins/character_height/cl_headwear.lua'],`
 local H=ix.CharacterHeight;local e=headEntity();beamCount=2
 H.WrapHeadwear(e);e:RenderOverride(STUDIO_RENDER)
 local copy=copies[1];eq(copy.draws,3);eq(flashlightPasses,1)
 eq(copy.drawLog[1].beam,false);eq(copy.drawLog[2].beam,true);eq(copy.drawLog[3].beam,true)
 for _,row in ipairs(copy.drawLog) do eq(row.flags,STUDIO_RENDER) end
 near(copy.head:GetScale().x,1);near(copy.head:GetTranslation().z,30)
 e.head:SetTranslation(Vector(12,5,4));e:RenderOverride(STUDIO_RENDER)
 near(copy.head:GetTranslation().z,4);eq(copy.draws,6);eq(flashlightPasses,2)
 beamCount=0;e:RenderOverride(STUDIO_RENDER);eq(copy.draws,7)
 e.scale=1;e:RenderOverride(STUDIO_RENDER);eq(copy.draws,7);eq(flashlightPasses,3)
 e.scale=190/180;e:RenderOverride(STUDIO_RENDER);eq(copy.draws,7);eq(flashlightPasses,3)
 eq(e:GetSubMaterial(1),'painted_helmet');eq(#copies,1)
 `,headwear);
 suite('SD helmet copies never enter shadow or SSAO depth passes and original helmet materials remain intact',
 [...shared,'ixhl2rp/plugins/character_height/cl_headwear.lua'],`
 local H=ix.CharacterHeight;local e=headEntity();beamCount=1
 H.WrapHeadwear(e)
 for _,flag in ipairs({STUDIO_SHADOWDEPTHTEXTURE,STUDIO_SSAODEPTHTEXTURE}) do
  local flags=bit.bor(STUDIO_RENDER,flag)
  e:RenderOverride(flags)
  eq(#copies,0);eq(flashlightPasses,0);eq(e:GetSubMaterial(1),'painted_helmet')
  fire('PrePlayerDraw',e,flags);fire('PostPlayerDraw',e,flags)
  eq(#copies,0);eq(e:GetSubMaterial(1),'painted_helmet')
 end
 e:RenderOverride(STUDIO_RENDER);eq(copies[1].draws,2);eq(flashlightPasses,1)
 e:RenderOverride(bit.bor(STUDIO_RENDER,STUDIO_SHADOWDEPTHTEXTURE))
 eq(copies[1].draws,2);eq(flashlightPasses,1);eq(e:GetSubMaterial(1),'painted_helmet')
 `,headwear);
 suite('SD ragdoll headwear falls back to entity angles and retains explicit render overrides',
 [...shared,'ixhl2rp/plugins/character_height/cl_headwear.lua'],`
 local H=ix.CharacterHeight;local e=headEntity();e.ang=Angle(15,80,-20)
 H.WrapHeadwear(e);e:RenderOverride()
 eq(#errors,0);eq(copies[1].draws,1);eq(copies[1].ang,e.ang)
 e.renderAngles=Angle(2,40,5);e:RenderOverride()
 eq(#errors,0);eq(copies[1].draws,2);eq(copies[1].ang,e.renderAngles)
 eq(e:GetSubMaterial(1),'painted_helmet');eq(e:GetSubMaterial(3),'')
 `,headwear);
 suite('SD headwear cleanup handles cancelled draws, hidden heads, model replacement and patient render errors',
 [...shared,'ixhl2rp/plugins/character_height/cl_headwear.lua'],`
 local H=ix.CharacterHeight;local e=headEntity()
 H.BeginHeadwear(e);fire('PostRender');eq(e:GetSubMaterial(1),'painted_helmet');eq(copies[1].draws,0)
 e.head:SetScale(Vector(0,0,0));H.BeginHeadwear(e);H.EndHeadwear(e);eq(copies[1].draws,0)
 e.head:SetScale(Vector(.9,.9,.9));e.model='models/sd/citizens/citizen_female_04_hair1.mdl'
 H.BeginHeadwear(e);H.EndHeadwear(e);eq(copies[1].valid,false);eq(#copies,2)
 local count=0;e.RenderOverride=function(self) count=count+1;self:DrawModel() end
 H.WrapHeadwear(e);local wrapper=e.RenderOverride;H.WrapHeadwear(e);eq(e.RenderOverride,wrapper)
 e:RenderOverride();eq(count,1);eq(e:GetSubMaterial(1),'painted_helmet')
 e.drawError=true;e:RenderOverride();eq(#errors,1);eq(e:GetSubMaterial(1),'painted_helmet')
 H.ClearHeadwear();eq(copies[2].valid,false);assert(e.RenderOverride~=wrapper)
 `,headwear);
 suite('Stock bonemerged weapons retain world size around the grip without changing viewmodels or ARC9',
 [...shared,'ixhl2rp/plugins/character_height/cl_held_weapons.lua'],`
 local H=ix.CharacterHeight;local p=heightPlayer(155);local w={valid=true,bones={},writes=0}
 function w:GetOwner() return p end
 function w:LookupBone() return 0 end
 function w:GetBoneMatrix(i) return self.bones[i] end
 function w:SetBoneMatrix(i,m) self.bones[i]=m;self.writes=self.writes+1 end
 function w:GetBoneCount() return 2 end
 for _,s in ipairs({155/180,190/180}) do
  p.scale=s
  for i=0,1 do local m=Matrix();m:SetTranslation(Vector(10+20*s*i,2,3));m:SetScale(Vector(s,s,s));w.bones[i]=m end
  H.FixedWeaponBones(w);near(w.bones[0]:GetTranslation().x,10);near(w.bones[1]:GetTranslation().x,30);near(w.bones[1]:GetScale().x,1)
  local writes=w.writes;H.FixedWeaponBones(w);eq(w.writes,writes)
 end
 w.ARC9=true;local writes=w.writes;H.FixedWeaponBones(w);eq(w.writes,writes)
 `,base);
 suite('Height resets on unsupported models and character removal; respawn reapplies normal camera',shared,`
 local p=heightPlayer(155);local H=ix.CharacterHeight;H.Apply(p)
 p.unsupported=true;p.model='models/vortigaunt.mdl';H.Apply(p);eq(p.scale,1);eq(p.view.z,64)
 p.unsupported=false;p.model='models/sd/citizens/citizen_male_01_hair1.mdl';H.Apply(p);near(p.scale,155/180)
 p.GetCharacter=function() return nil end;H.Apply(p);eq(p.scale,1)
 p.GetCharacter=function() return p.character end;H.Apply(p);p.view=Vector(0,0,1)
 fire('PostPlayerLoadout',p);near(p.view.z,64*155/180)
 `,base);
 suite('Height respects bed camera and updates crawl and bed restoration values',shared,`
 local p=heightPlayer(155);p.vars.bedRestAngle=Angle();p.view=Vector(0,0,9);p.duck=Vector(0,0,9)
 local session={};ix.plugin.list.sleep={bedSessions={[p]=session}}
 ix.CharacterHeight.Apply(p);eq(p.view.z,9);eq(p.duck.z,9);near(session.view.z,64*155/180);near(session.duckView.z,28*155/180)
 p.vars.bedRestAngle=nil;p.ixCrawlView=Vector(0,0,28);p.height=190;ix.CharacterHeight.Apply(p)
 near(p.ixCrawlView.z,28*190/180);near(p.duck.z,18*190/180)
 `,base);
 suite('Client uses server height and updates only its own predicted movement dimensions',shared,`
 local a,b=heightPlayer(180),heightPlayer(180);localPlayer=a;a.nw.ixCharacterScale=155/180;b.nw.ixCharacterScale=190/180
 ix.CharacterHeight.Apply(a);ix.CharacterHeight.Apply(b)
 near(a.scale,155/180);near(a.maxs.z,72*155/180);near(b.scale,190/180);eq(b.maxs,nil)
 `,base+`CLIENT=true;SERVER=false;function LocalPlayer() return localPlayer end\n`);
 suite('Voluntary prone retains its low hull and camera and restores the selected standing height',shared,`
 local p=heightPlayer(155);PRONE_INPRONE=2
 function p:SteamID() return 'test' end
 function p:IsProne() return self.prone==true end
 function p:GetProneAnimationState() return 2 end
 p.prone=true;local data={};prone={Config={View=Vector(0,0,12),HullHeight=20},PlayerStateDatas={test=data}}
 ix.CharacterHeight.Apply(p);near(p.maxs.z,20*155/180);near(p.dmaxs.z,20*155/180);near(p.view.z,12*155/180)
 near(data.OriginalViewOffset.z,64*155/180);near(data.OriginalViewOffsetDucked.z,28*155/180)
 p.prone=false;fire('prone.OnPlayerExitted',p);near(p.maxs.z,72*155/180);near(p.view.z,64*155/180)
 `,base);
 suite('ARC9 arm length changes with height while its existing solve cache remains valid', [...shared,'ixhl2rp/plugins/character_height/cl_compat.lua'],`
 local p=heightPlayer(155);local w={TPIKCache={old=true},LastTPIKTime=99}
 for _,s in ipairs({155/180,1,190/180}) do
  p.scale=s;fire('ixARC9PreArmPose',w,p);near(w.TPIKBoneLengthCache.length,12*s)
  eq(w.TPIKBoneLengthCache.forearmIndex,4);eq(w.TPIKBoneLengthCache.model,p.model);eq(type(w.TPIKCache),'table');eq(w.LastTPIKTime,0)
  w.TPIKCache.token=1;fire('ixARC9PreArmPose',w,p);eq(w.TPIKCache.token,1)
 end
 `,base);
 suite('Preview height follows creation selection and equipment owner without resizing weapons', [...shared,'ixhl2rp/plugins/character_height/cl_compat.lua'],`
 local p=heightPlayer(180);local H=ix.CharacterHeight
 H.Preview({ixCharacterHeight=155},p);near(p.scale,155/180)
 local owner=heightPlayer(190);owner.scale=190/180;p.ProxyOwner=owner
 H.Preview({ixCharacterHeight=155},p);near(p.scale,190/180)
 p.unsupported=true;H.Preview({},p);eq(p.scale,1)
 `,base);
 suite('Height damage capture observes raw hits and critical entry, preserves dispatch and removes itself',
 [...shared,'tools/ix_height_damage_diagnostic.lua'],`
 local A=ix.HeightDamageAudit;eq(#A.events,1);eq(A.events[1].data.height,165)
 local damage={amount=11}
 function damage:GetDamage() return self.amount end
 function damage:GetDamageType() return 1 end
 function damage:GetAttacker() return subject end
 function damage:GetInflictor() return subject end
 function damage:GetDamagePosition() return Vector() end
 function damage:GetDamageForce() return Vector() end
 local a,b,c=hook.Call('EntityTakeDamage',nil,subject,damage)
 eq(a,'forwarded');eq(b,nil);eq(c,3);eq(damage.amount,4)
 eq(A.events[2].kind,'EntityTakeDamage');eq(A.events[2].data.damage.amount,11)
 local a,b,c=FindMetaTable('Player').SetCriticalState(subject,true,'token')
 eq(a,'critical');eq(b,nil);eq(c,'token');eq(subject.vars.crit,true)
 eq(A.events[3].kind,'enter_critical');eq(A.events[3].data.state.critical,false)
 assert(A.events[3].data.trace:find('stack traceback',1,true))
 FindMetaTable('Player').SetCriticalState(subject,true);eq(#A.events,3)
 -- A failed observation must not swallow real damage or change hook returns.
 subject.Health=function() error('snapshot failed') end
 a,b,c=hook.Call('EntityTakeDamage',nil,subject,damage);eq(a,'forwarded');eq(c,3)
 eq(A.events[4].kind,'diagnostic_error')
 subject.Health=function() return 1 end
 clock=clock+60;timers.ixHeightDamageAudit.fn()
 eq(ix.HeightDamageAudit,nil);eq(A.enabled,false);eq(hook.Call,originalCall)
 eq(FindMetaTable('Player').SetCriticalState,originalCritical);eq(timers.ixHeightDamageAudit,nil)
 assert(savedPath:find('ix_height_audit/',1,true));eq(savedReport.events[#savedReport.events].kind,'end')
 `,base+`
 subject=heightPlayer(165)
 function subject:IsAdmin() return true end
 function subject:GetHull() return Vector(-16,-16,0),Vector(16,16,72) end
 function subject:GetHullDuck() return Vector(-16,-16,0),Vector(16,16,36) end
 function subject:Health() return 100 end
 function subject:IsWepRaised() return false end
 function subject.character:GetID() return 1 end
 local health={hediffs={}}
 function health:GetPartHealth() return 50 end
 function health:GetConsciousness() return 1 end
 function subject.character:Health() return health end
 player.GetHumans=function() return {subject} end;game={SinglePlayer=function() return true end}
 file={CreateDir=function() end,Write=function(path,report) savedPath=path;savedReport=report end}
 util.TableToJSON=function(value) return value end
 originalCall=function(name,gm,first,damage) if name=='EntityTakeDamage' then damage.amount=4 end;return 'forwarded',nil,3 end
 hook.Call=originalCall
 originalCritical=function(self,state,token) self.vars.crit=state;return 'critical',nil,token end
 FindMetaTable('Player').SetCriticalState=originalCritical
 timers={}
 timer.Create=function(name,delay,reps,fn) timers[name]={fn=fn} end
 timer.Remove=function(name) timers[name]=nil end
 timer.RepsLeft=function() return 0 end
 `);
};
