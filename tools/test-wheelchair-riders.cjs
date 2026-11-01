const fs=require('fs'),path=require('path'),{lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const normalize=require('./glua-runtime.cjs'),syntax=require('./glua.cjs').normalize;
process.chdir(path.resolve(__dirname,'..'));
const read=f=>fs.readFileSync(f,'utf8').replace(/\r\n/g,'\n');
const source=files=>files.map(f=>'do\n'+(f.startsWith('tools/fixtures/')?syntax:normalize)(read(f))+'\nend').join('\n');
const base='ixhl2rp/plugins/pushcart/';
const fixture=read('tools/fixture.lua')+'\n'+source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/body-drag.lua','tools/fixtures/cart-patients.lua']);
const files=['ixhl2rp/plugins/body_drag/sh_drag.lua','ixhl2rp/plugins/body_drag/sh_weapons.lua','ixhl2rp/plugins/body_drag/sv_drag.lua',...['libs/sh_bootstrap','sh_plugin','sh_kinematics','sh_patient','sh_rider','sh_interaction','sv_interaction','sv_patient','sv_rider','entities/entities/ix_pushcart/init'].map(f=>base+f+'.lua')];
function method(file,start){const s=read(file),a=s.indexOf(start),b=s.indexOf('\nfunction ',a+1);if(a<0)throw Error(start);return normalize(s.slice(a,b<0?undefined:b));}
const setup=fixture+'\n'+source(files)+'\nlocal P=ix.PushCart\n'+['Near','HasContents','Pack','Snapshot'].map(name=>method(base+'sv_plugin.lua','function P:'+name+'(')).join('\n')+`
 COLLISION_GROUP_IN_VEHICLE=10;COLLISION_GROUP_WEAPON=11;RENDERMODE_TRANSCOLOR=1
 prepareCart();ix.BodyDrag.Stop(carrier)
 cart.class='ix_medical_wheelchair';cart.PatientSeated=true;cart.PatientOnly=true
 cart.PatientSeat=Vector(0,0,20.5);cart.BedZ=20.5;cart.BedMinX=-2;cart.BedMaxX=10;cart.BedHalfY=9
 cart.cargoUID='chair';cart.cartGeometryVersion=3;cart.model='models/props_unique/wheelchair01.mdl'
 cart.inventory.id=7;cart.inventory.GetID=function() return 7 end;cart.inventory.GetItems=function() return {} end
 function cart:GetCollisionGroup() return 0 end
 function cart:ForcePlayerDrop() end
 function cart:HasDriveVars() return true end
 function cart:SetCustomCollisionCheck() end
 function cart:SetLoad(v) self.load=v end
 function cart:GetLoad() return self.load end
 function cart:ApplyDrive(state) self.drive=state end
 function P:TraceFor() return function(t) return {Hit=true,HitPos=Vector(t.endpos.x,t.endpos.y,0),HitNormal=Vector(0,0,1)} end end
 function P:WriteDrive() end
 function cart:GetCartSlot() return 0 end
 local existingEnrich=enrich
 function enrich(e)
  e=existingEnrich(e)
  function e:IsFrozen() return self.frozen==true end
  function e:GetNW2Bool(k,d) if self.nw[k]~=nil then return self.nw[k] end;return d end
  function e:GetHull() return Vector(-16,-16,0)*self.scale,Vector(16,16,72)*self.scale end
  function e:SetLocalVelocity(v) self.velocity=v end
  function e:GetVehicle() return self.vehicle or NULL end
  function e:GetAllowWeaponsInVehicle() return self.allowWeapons==true end
  function e:SetAllowWeaponsInVehicle(v) self.allowWeapons=v end
  function e:GetSequenceInfo() return {bbmin=Vector(-18,-12,0),bbmax=Vector(26,12,44)} end
  function e:LookupBone(name) if missingBone then return end;return name=='ValveBiped.Bip01_Pelvis' and 0 or 1 end
  function e:GetBoneMatrix(i) local m=Matrix();m:SetTranslation(self.pos+Vector(i==0 and 3 or 1,0,i==0 and 22 or 40)*self.scale);return m end
  function e:EnterVehicle(seat)
   if denyEntry or fire('CanPlayerEnterVehicle',self,seat)==false then return end
   self.vehicle=seat;self.parent=seat;seat.driver=self
   local attachment=seat:GetAttachment(1);self.pos=attachment.Pos
  end
  function e:ExitVehicle()
   local seat=self.vehicle;if not IsValid(seat) then self.vehicle=nil;return end
   self.vehicle=nil;self.parent=NULL;seat.driver=nil;fire('PlayerLeaveVehicle',self,seat)
  end
  function e:SelectWeapon(id) self.selected=id end
  function e:SetKeyValue(k,v) self.keys=self.keys or {};self.keys[k]=v end
  function e:Activate() end
  function e:LookupAttachment() return missingFeet and 0 or 1 end
  function e:GetAttachment()
   return {Pos=self:LocalToWorld(Vector(2,-4,5)),Ang=Angle(0,90,0)}
  end
  function e:GetPos()
   if IsValid(self.parent) then return self.parent:LocalToWorld(self.localPos or Vector()) end
   return self.pos
  end
  function e:GetAngles()
   if IsValid(self.parent) then local a=self.localAngles or Angle();return Angle(a.p,a.y+self.parent:GetAngles().y,a.r) end
   return self.ang
  end
  function e:WorldSpaceCenter() return self:GetPos() end
  function e:SetMoveType(v) self.move=v end
  function e:SetCollisionGroup(v) self.group=v end
  function e:SetRenderMode(v) self.renderMode=v end
  function e:DrawShadow(v) self.shadow=v end
  local oldRemove=e.Remove
  function e:Remove() oldRemove(self);fire('EntityRemoved',self) end
  return e
 end
 carrier=enrich(carrier);carrier.pos=Vector(0,-65,0);carrier.allowWeapons=true
 local helpers={};ents.Create=function(class)
  if failedClass==class then return NULL end
  local e=enrich(dragEntity(class));helpers[#helpers+1]=e;return e
 end
 local function helperCount() local n=0;for _,e in ipairs(helpers) do if IsValid(e) then n=n+1 end end;return n end
 local queued={};timer.Simple=function(_,fn) queued[#queued+1]=fn end
 function flush() local q=queued;queued={};for _,fn in ipairs(q) do fn() end end
 function leave(p)
  clock=clock+1;local seat=p:GetVehicle()
  if fire('CanExitVehicle',seat,p)==false then return false end
  p:ExitVehicle();flush();return true
 end
 function target(p) trace={Entity=cart,Hit=true,Fraction=.8,HitPos=cart.pos};local old=util.TraceLine;util.TraceLine=function(t) if t.filter==p then return trace end;return old(t) end end
 target(carrier)
`;
let count=0;
function run(name,test){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);const code=setup+'\n'+test;
 const result=lauxlib.luaL_dostring(L,to_luastring(code));if(result!==lua.LUA_OK){fs.mkdirSync('.runtime/wheelchair-riders-20261016',{recursive:true});fs.writeFileSync('.runtime/wheelchair-riders-20261016/failed.lua',code);throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));}
 lua.lua_close(L);console.log('PASS '+name);count++;
}
run('Voluntary sitting is offered only on a free stationary wheelchair; menus consume authorization once',`
 assert(table.HasValue(P:InteractionOptions(carrier,cart),'sit'))
 cart.class='ix_medical_gurney';eq(P:CanSitWheelchair(carrier,cart),false);cart.class='ix_medical_wheelchair'
 P:OpenInteraction(carrier,cart);local token=carrier.ixCartMenu.token
 assert(P:PerformInteraction(carrier,cart,token,'sit'));eq(P:GetRider(cart),carrier);eq(P:RiderCart(carrier),cart)
 eq(P:PerformInteraction(carrier,cart,token,'sit'),false);eq(helperCount(),1);eq(P:GetPatient(cart),nil)
 eq(carrier.vars.crit,nil);eq(carrier:GetAllowWeaponsInVehicle(),false);near(cart.load,P.PATIENT_LOAD)
 local seat=carrier:GetVehicle();eq(seat:GetParent(),cart);eq(seat.notSolid,true);eq(seat.color.a,0);eq(seat.bNoPersist,true)
 assert(leave(carrier));eq(P:GetRider(cart),nil);eq(carrier:GetAllowWeaponsInVehicle(),true);eq(helperCount(),0);near(cart.load,0)
`);
run('Occupied wheelchair cannot be packed, shared or loaded with a patient; another player can take its handle',`
 assert(P:SitWheelchair(carrier,cart));eq(P:HasContents(cart),true);eq(P:Pack(carrier,cart,'medical_wheelchair'),false)
 local other=enrich(dragPlayer());other.pos=Vector(-50,0,0);target(other)
 eq(P:CanSitWheelchair(other,cart),false);local options=P:InteractionOptions(other,cart)
 assert(table.HasValue(options,'push'));eq(table.HasValue(options,'pack'),false);eq(table.HasValue(options,'sit'),false)
 local kin=P:GetKinematics(cart);local oldFree=kin.FindFree;kin.FindFree=function(_,pose) return pose end
 assert(cart:StartPush(other));kin.FindFree=oldFree;eq(cart:GetPusher(),other)
 eq(P:CanLoadPatient(other,cart),false);assert(leave(carrier));eq(IsValid(cart:GetPusher()),false)
`);
run('Stale empty-chair menus cannot replace a rider or a patient, and native seat entry cannot bypass consent',`
 P:OpenInteraction(carrier,cart);local token=carrier.ixCartMenu.token
 cart:SetNW2Entity('ixCartPatient',patient);eq(P:PerformInteraction(carrier,cart,token,'sit'),false)
 cart:SetNW2Entity('ixCartPatient',NULL);clock=clock+1;P:OpenInteraction(carrier,cart);token=carrier.ixCartMenu.token
 local other=enrich(dragPlayer());other.pos=Vector(0,-60,0);target(other);assert(P:SitWheelchair(other,cart))
 target(carrier);eq(P:PerformInteraction(carrier,cart,token,'sit'),false)
 local seat=other:GetVehicle();eq(fire('CanPlayerEnterVehicle',carrier,seat),false);eq(P:GetRider(cart),other)
`);
run('Active actions, carried bodies, moving or tilted chairs and occupied storage reject sitting',`
 for _,key in ipairs({'crit','tied','knocked','ragdoll','forcedSequence','sitHelperPos'}) do
  carrier.vars[key]=1;eq(P:CanSitWheelchair(carrier,cart),false);carrier.vars[key]=nil
 end
 carrier.frozen=true;eq(P:CanSitWheelchair(carrier,cart),false);carrier.frozen=false
 cart.velocity=Vector(8,0,0);eq(P:CanSitWheelchair(carrier,cart),false);cart.velocity=nil
 cart.ang=Angle(30,0,0);eq(P:CanSitWheelchair(carrier,cart),false);cart.ang=Angle()
 cart.inventory.busy=true;eq(P:CanSitWheelchair(carrier,cart),false);cart.inventory.busy=false
 local old=ix.BodyDrag.Body;ix.BodyDrag.Body=function() return body end;eq(P:CanSitWheelchair(carrier,cart),false);ix.BodyDrag.Body=old
 eq(helperCount(),0)
`);
run('Failed pose, seat creation, native entry or obstructed boarding leaves no rider or orphan helper',`
 failedClass='prop_vehicle_prisoner_pod';eq(P:SitWheelchair(carrier,cart),false);eq(helperCount(),0);failedClass=nil
 missingSequence=true;eq(P:SitWheelchair(carrier,cart),false);eq(helperCount(),0);missingSequence=nil
 missingBone=true;eq(P:SitWheelchair(carrier,cart),false);eq(helperCount(),0);missingBone=nil
 missingFeet=true;eq(P:SitWheelchair(carrier,cart),false);eq(helperCount(),0);missingFeet=nil
 blockExit=true;eq(P:SitWheelchair(carrier,cart),false);eq(helperCount(),0);blockExit=nil
 denyEntry=true;eq(P:SitWheelchair(carrier,cart),false);eq(helperCount(),0);denyEntry=nil
 eq(P:GetRider(cart),nil);eq(P.riderStates[cart],nil);eq(carrier:GetAllowWeaponsInVehicle(),true)
`);
run('A blocked exit keeps the rider seated; a valid exit stops the attendant and restores player state',`
 assert(P:SitWheelchair(carrier,cart));local seat=carrier:GetVehicle()
 eq(fire('CanExitVehicle',seat,carrier),false) -- the use key that opened the menu must not exit immediately
 blockExit=true;eq(leave(carrier),false);eq(P:GetRider(cart),carrier);assert(carrier:InVehicle())
 blockExit=nil;local helper=enrich(dragPlayer());cart.pusher=helper;helper.ixPushCart=cart
 assert(leave(carrier));eq(carrier:InVehicle(),nil);eq(P.riderStates[cart],nil);eq(P:GetRider(cart),nil)
 eq(IsValid(cart:GetPusher()),false);eq(carrier:GetAllowWeaponsInVehicle(),true);eq(carrier.vars.crit,nil)
`);
for(const height of [155,180,190])run('Seated pelvis, view and occupied bounds follow the '+height+' cm character without scaling the chair',`
 carrier.scale=${height}/180;cart.ang=Angle(0,90,0)
 assert(P:SitWheelchair(carrier,cart));local s=P.riderStates[cart];local scale=carrier.scale
 vectorNear(s.localPos+Vector(3,0,22)*scale,cart.PatientSeat+Vector(0,0,4*scale))
 vectorNear(s.eye,s.localPos+Vector(1,0,43)*scale);eq(cart.scale,1)
 vectorNear(s.seat:GetAttachment(1).Pos,cart:LocalToWorld(s.localPos));assert(cart.top>40)
 local old=s.seat:GetPos();cart.pos=cart.pos+Vector(50,25,0);vectorNear(s.seat:GetPos(),old+Vector(50,25,0))
 eq(fire('CalcMainActivity',carrier),-1)
`);
for(const reason of ['cart removal','seat removal','death','disconnect','character change','spawn','map cleanup','shutdown','model change','height change','critical injury'])run('Rider cleanup survives '+reason,`
 assert(P:SitWheelchair(carrier,cart));local seat=carrier:GetVehicle()
 ${({
 'cart removal':"ENT.OnRemove(cart)",'seat removal':"seat:Remove()",death:"carrier.dead=true;fire('PlayerDeath',carrier)",disconnect:"fire('PlayerDisconnected',carrier)",'character change':"fire('PrePlayerLoadedCharacter',carrier)",spawn:"fire('PlayerSpawn',carrier)",'map cleanup':"fire('PreCleanupMap')",shutdown:"fire('ShutDown')",'model change':"carrier.model='other.mdl';fire('Think')",'height change':"carrier.scale=.9;fire('Think')",'critical injury':"carrier.vars.crit=true;fire('Think')"
 })[reason]}
 flush();eq(P:GetRider(cart),nil);eq(P.riderStates[cart],nil);eq(P:RiderCart(carrier),nil);eq(IsValid(seat),false)
 eq(carrier:GetAllowWeaponsInVehicle(),true)
`);
run('Saving an occupied wheelchair keeps the chair but never serializes its rider or temporary seat',`
 assert(P:SitWheelchair(carrier,cart))
 cart.inventory.GetItemsID=function() return {} end;cart.inventory.type='pushcart';cart.inventory.width=6;cart.inventory.height=4
 local record=P:Snapshot(cart)
 eq(record.class,'ix_medical_wheelchair');eq(record.uid,'chair');eq(record.geometryVersion,3)
 eq(#record.items,0);eq(#record.crates,0);vectorNear(record.pos,cart:GetPos())
 local fields={uid=true,inventoryType=true,items=true,width=true,height=true,class=true,pos=true,ang=true,geometryVersion=true,crates=true}
 for key in pairs(record) do assert(fields[key],'unexpected persisted field: '..key) end
 eq(carrier:GetVehicle().bNoPersist,true);eq(carrier:GetVehicle().DoNotDuplicate,true)
`);
const clientRider=`CLIENT=true;SERVER=false\n${source([base+'sh_rider.lua'])}`;
run('Rider camera follows the rendered chair and preserves view angles, third person and unrelated vehicles',`
 assert(P:SitWheelchair(carrier,cart))
 ${clientRider}
 local view={origin=Vector(100,200,300),angles=Angle(10,15,0),fov=90}
 local drawPos,drawAng=Vector(40,60,5),Angle(0,90,0)
 cart.GetDrawPose=function() return drawPos,drawAng end
 eq(fire('CalcVehicleView',carrier:GetVehicle(),carrier,view),view)
 vectorNear(view.origin,LocalToWorld(cart:GetNW2Vector('ixCartRiderEye'),angle_zero,drawPos,drawAng))
 near(view.angles.p,10);near(view.angles.y,15);eq(view.fov,90);eq(view.znear,2)
 view.origin=Vector(100,200,300);view.drawviewer=true
 eq(fire('CalcVehicleView',carrier:GetVehicle(),carrier,view),nil);vectorNear(view.origin,Vector(100,200,300))
 view.drawviewer=false
 eq(fire('CalcVehicleView',dragEntity('vehicle'),carrier,view),nil);vectorNear(view.origin,Vector(100,200,300))
 assert(leave(carrier));eq(fire('CalcVehicleView',NULL,carrier,view),nil)
`);
run('Animation sequence names resolve separately per model and the exit hint does not leak into CCTV',`
 assert(P:SitWheelchair(carrier,cart))
 ${clientRider}
 local calls,index=0,43
 carrier.LookupSequence=function(_,name) calls=calls+1;eq(name,carrier:GetNW2String('ixCartRiderSequence'));return index end
 local activity=hooks.CalcMainActivity.ixWheelchairRider
 local a,b=activity(carrier);eq(a,-1);eq(b,43);activity(carrier);eq(calls,1)
 carrier.model='new.mdl';index=77;a,b=activity(carrier);eq(a,-1);eq(b,77);eq(calls,2)
 local draws=0;LocalPlayer=function() return carrier end;ScrW=function() return 1920 end;ScrH=function() return 1080 end
 draw={SimpleText=function() draws=draws+1 end};color_white={};TEXT_ALIGN_CENTER=1
 local hud=hooks.HUDPaint.ixWheelchairRider
 hud();eq(draws,1);ix.CCTV={rendering=true};hud();eq(draws,1);ix.CCTV.rendering=false
 assert(leave(carrier));hud();eq(draws,1);eq(activity(carrier),nil)
`);
const drive=read(base+'sh_drive.lua');
const renderHelpers=normalize(drive.slice(drive.indexOf('\tfunction PushCart:ClearChildRenderOverride('),drive.indexOf('\tlocal function RenderCart(')));
run('Cart interpolation carries the visible rider and releases render overrides on exit or reset',`
 assert(P:SitWheelchair(carrier,cart))
 local PushCart=P
 function cart:SetRenderOrigin(v) self.renderOrigin=v end;function cart:SetRenderAngles(v) self.renderAngles=v end
 function carrier:SetRenderOrigin(v) self.renderOrigin=v end
 function carrier:SetRenderAngles(v) assert(v~=nil,'Player:SetRenderAngles requires an Angle');self.renderAngles=v end
 ${renderHelpers}
 local pos,ang=Vector(70,90,10),Angle(0,75,0)
 ApplyOverride(cart,pos,ang)
 vectorNear(carrier.renderOrigin,LocalToWorld(cart:GetNW2Vector('ixCartRiderPos'),angle_zero,pos,ang))
 eq(carrier.renderAngles,ang);eq(cart.overriddenChildren[carrier],true)
 ClearOverride(cart);eq(carrier.renderOrigin,nil);near(carrier.renderAngles.y,carrier:GetAngles().y)
 ApplyOverride(cart,pos,ang);assert(leave(carrier));ApplyOverride(cart,pos,ang)
 eq(carrier.renderOrigin,nil);near(carrier.renderAngles.y,carrier:GetAngles().y);eq(cart.overriddenChildren[carrier],nil)
`);
const renderCleanupFixture=`
 local PushCart=P
 ${renderHelpers}
 local function renderer(entity)
  function entity:SetRenderOrigin(v) self.renderOrigin=v end
  function entity:SetRenderAngles(v)
   if self:IsPlayer() then assert(v~=nil,'Player:SetRenderAngles requires an Angle') end
   self.renderAngles=v;self.resets=(self.resets or 0)+1
  end
  entity.renderOrigin=Vector(12,34,56);entity.renderAngles=Angle(8,65,4)
  return entity
 end
 renderer(carrier);carrier.ang=Angle(0,27,0)
 local crate=renderer(enrich(dragEntity('ix_cargo_crate')))
 local patientDisplay=renderer(enrich(dragEntity('ix_cart_patient')))
`;
run('Mixed render cleanup restores players, clears prop overrides and skips retained or invalid children',`
 ${renderCleanupFixture}
 local removed=renderer(enrich(dragEntity('player')));removed.valid=false
 local children={[carrier]=true,[crate]=true,[patientDisplay]=true,[removed]=true}
 ReleaseChildren(children,{[carrier]=true});eq(carrier.resets,nil);eq(removed.resets,nil)
 eq(crate.renderOrigin,nil);eq(crate.renderAngles,nil);eq(patientDisplay.renderAngles,nil)
 ReleaseChildren(children);eq(carrier.renderOrigin,nil);near(carrier.renderAngles.y,27);eq(removed.resets,nil)
 ReleaseChildren(children);near(carrier.renderAngles.y,27)
`);
run('Client cart removal or full update cleans rider and cargo render overrides without native nil-angle errors',`
 ${renderCleanupFixture}
 ${method(base+'entities/entities/ix_pushcart/cl_init.lua','function ENT:OnRemove(')}
 function cart:ClearCargoModels() self.clearedCargo=true end
 cart.overriddenChildren={[carrier]=true,[crate]=true,[patientDisplay]=true}
 cart.cargoRevision=1;cart.renderPadded=true
 ENT.OnRemove(cart)
 eq(cart.clearedCargo,true);eq(cart.overriddenChildren,nil);eq(cart.cargoRevision,nil);eq(cart.renderPadded,nil)
 eq(carrier.renderOrigin,nil);near(carrier.renderAngles.y,27)
 eq(crate.renderAngles,nil);eq(patientDisplay.renderAngles,nil)
 ENT.OnRemove(cart);eq(carrier.resets,1)
`);
console.log(count+' wheelchair rider suites passed; native vehicle attachment, animation and camera rendering still need an in-game check.');
