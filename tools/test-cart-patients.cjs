module.exports=function(suite){
 const fs=require('fs'),path=require('path'),{normalize}=require('./glua.cjs');
 const read=f=>fs.readFileSync(path.join(__dirname,'..',f),'utf8');
 const setup=['sharedposes','pose-gizmo','body-drag','cart-patients'].map(f=>read('tools/fixtures/'+f+'.lua')).join('\n');
 const base='ixhl2rp/plugins/pushcart/';
 const files=['ixhl2rp/plugins/body_drag/sh_drag.lua','ixhl2rp/plugins/body_drag/sh_weapons.lua','ixhl2rp/plugins/body_drag/sv_drag.lua',
  base+'libs/sh_bootstrap.lua',base+'sh_plugin.lua',base+'sh_patient.lua',base+'sh_interaction.lua',base+'sv_interaction.lua',base+'sv_patient.lua',base+'entities/entities/ix_pushcart/init.lua'];
 function method(file,start){const source=read(file),i=source.indexOf(start);if(i<0)throw Error(start);let end=source.indexOf('\nfunction ',i+1);return normalize(source.slice(i,end<0?undefined:end));}
 const methods='local P=ix.PushCart\n'+method(base+'sv_plugin.lua','function P:Near(')+method(base+'sv_plugin.lua','function P:HasContents(');
 function test(name,code,extra=[]){suite(name,[...files,...extra],methods+'\nprepareCart()\nlocal P,D=ix.PushCart,ix.BodyDrag\n'+code,setup);}
 const bleedingSetup=`
 local healthPlugin={};PLUGIN=healthPlugin
 local updates,emissions={},{}
 timer.Create=function(name,interval,repeats,fn) updates[name]=fn end
 effects={Register=function() end}
 function LocalPlayer() return carrier end
 carrier.EyePos=carrier.GetShootPos
 function Entity(id) return id==body:EntIndex() and body or NULL end
 function EffectData()
  return {SetOrigin=function(self,v) self.origin=v end,SetAngles=function(self,v) self.angles=v end,SetEntity=function(self,v) self.entity=v end}
 end
 util.Effect=function(name,data) eq(name,'bleeding');emissions[#emissions+1]=data end
 patient.vars.doll=body:EntIndex();patient.vars.isBleeding=true
 allPlayers={patient}
 function body:GetBonePosition() return Vector(0,-45,20),Angle() end
 function patient:GetBonePosition() return self:GetPos()+Vector(0,0,40),Angle() end
 do\n${normalize(read('ixhl2rp/plugins/!healthsystem/cl_fx.lua'))}\nend
 local function emit()
  clock=clock+.051 -- effects are time-budgeted, not emitted on every HUD draw
  emissions={};healthPlugin:DrawBleeding();return emissions[1] and emissions[1].origin
 end
 local function visibleDisplay()
  local display=P:PatientDisplay(patient)
  function display:GetPos() return LocalToWorld(self:GetLocalPos(),self:GetLocalAngles(),cart:GetPos(),cart:GetAngles()) end
  function display:GetBonePosition() return self:GetPos()+Vector(0,0,12),Angle() end
  return display
 end
 `;
 test('Bleeding follows the visible cart occupant through movement, unloading and standing recovery',bleedingSetup+`
 updates.ixBleedingUpdate();vectorNear(emit(),Vector(0,-45,20))
 assert(P:LoadPatient(carrier,cart));local display=visibleDisplay()
 vectorNear(emit(),display:GetBonePosition())
 cart.pos=cart.pos+Vector(180,35,0);P:SyncPatient(P.patientStates[cart])
 vectorNear(emit(),display:GetBonePosition()) -- hidden ragdoll still exposes the stale pickup bones
 function display:GetBonePosition() return nil end
 vectorNear(emit(),display:GetPos()+Vector(0,0,32))
 carrier.pos=cart.pos+Vector(0,-65,0);trace.Entity=cart
 assert(P:UnloadPatient(carrier,cart,false))
 vectorNear(emit(),body:GetBonePosition())
 patient.vars.doll=nil;vectorNear(emit(),patient:GetBonePosition())
 ix.PushCart=nil;vectorNear(emit(),patient:GetBonePosition())
 `);
 test('Bleeding visibility uses the cart display distance and stops immediately when healed or dead',bleedingSetup+`
 assert(P:LoadPatient(carrier,cart));local display=visibleDisplay()
 patient.pos=Vector(9000,0,0);body.pos=patient.pos
 updates.ixBleedingUpdate();vectorNear(emit(),display:GetBonePosition())
 cart.pos=Vector(9000,0,34);updates.ixBleedingUpdate();eq(emit(),nil)
 cart.pos=Vector(0,0,34);updates.ixBleedingUpdate();assert(emit())
 patient.vars.isBleeding=false;eq(emit(),nil)
 patient.vars.isBleeding=true;patient.dead=true;eq(emit(),nil)
 `);
 for (const className of ['ix_medical_gurney','ix_medical_wheelchair']) test(className+' loads the same wounded player in its own pose and restores dragging safely',`
  local originalENT=ENT;ENT={}
  ${normalize(read(base+'entities/entities/'+className+'.lua'))}
  for k,v in pairs(ENT) do cart[k]=v end;ENT=originalENT;cart.class='${className}'
  local create=ents.Create
  ents.Create=function(class)
   local display=create(class)
   if cart.PatientSeated then
    function display:LookupSequence(name) return name=='stances_sit01' and 14 or -1 end
    function display:GetSequenceInfo() return {bbmin=Vector(-22,-11,0),bbmax=Vector(11,11,47)} end
    function display:GetBoneMatrix(i)
     local m=Matrix();m:SetTranslation(self.pos+Vector(-20,0,20)*self.scale+Vector(i*5,0,0));return m
    end
   end
   return display
  end
  local inventory=body.inventory;local injuries=patient.vars;local physics=body.parts[1]
  assert(P:LoadPatient(carrier,cart));local state=P.patientStates[cart];local display=state.display
  eq(display:GetParent(),cart);eq(D.Body(carrier),nil);eq(body.hidden,true);eq(patient.vars,injuries);eq(body.inventory,inventory)
  near(display:GetLocalAngles().y,cart.PatientYaw)
  if cart.PatientSeated then
   eq(display.sequence,14);near(display:GetLocalPos().z+20,cart.PatientSeat.z+4)
   assert(display:GetLocalPos().z+state.low.z>=.5);eq(display:GetNW2String('ixPatientSequence'),'stances_sit01')
  end
  assert(cart.top>=state.top);eq(cart:CanAttachCrate({valid=true,isCargoCrate=true}),false)
  local old=physics.pos;cart.pos=cart.pos+Vector(100,20,0);P:SyncPatient(state);vectorNear(physics.pos,old+Vector(100,20,0))
  carrier.pos=cart.pos+Vector(0,-65,0);trace.Entity=cart
  assert(P:UnloadPatient(carrier,cart,true));eq(D.Body(carrier),body);eq(body.inventory,inventory);eq(P:GetPatient(cart),nil)
 `);
 test('Wheelchair rejects unavailable sitting animations without replacing them with a lying or standing pose',`
  cart.PatientSeated=true;local create=ents.Create
  ents.Create=function(class)
   local d=create(class)
   function d:LookupSequence(name) return name=='stances_down02' and 7 or -1 end
   return d
  end
  eq(P:LoadPatient(carrier,cart),false);eq(D.Body(carrier),body);eq(body.hidden,nil);eq(lastDisplay.valid,false)
 `);
 test('Cart load preserves the original patient, inventory and injuries while replacing only the displayed pose',`
 local inventory=body.inventory;local char=patient:GetCharacter();assert(P:LoadPatient(carrier,cart))
 eq(P:GetPatient(cart),patient);eq(patient.ixRagdoll,body);eq(body.inventory,inventory);eq(patient.character,char);eq(patient.vars.crit,true)
 eq(D.Body(carrier),nil);eq(body.hidden,true);eq(body.notSolid,true);eq(body:GetParent(),NULL)
 local display=P:PatientDisplay(patient);eq(display:GetParent(),cart);eq(display.model,body.model);eq(display.skin,body.skin)
 eq(display.groups[0],1);eq(display.submaterials[0],'camo');eq(display.material,'custom');eq(display.sequence,3);eq(display.rate,0)
 for _,p in ipairs(body.parts) do eq(p.motion,false);eq(p.collisions,false) end
 eq(cart.load,P.PATIENT_LOAD);assert(cart.top>30)
 `);
 for (const height of [155,180,190]) test('Cart patient preserves '+height+' cm height through loading and unloading',`
  local height=${height}
  body.scale=height/180
  assert(P:LoadPatient(carrier,cart));local display=P:PatientDisplay(patient)
  near(display:GetModelScale(),height/180);near(body:GetModelScale(),height/180)
  assert(P:UnloadPatient(carrier,cart,false));near(body:GetModelScale(),height/180)
 `);
 test('Server preparation has no client bone-cache APIs and cleans its uncommitted display after an engine error',`
 local prepare=P.PreparePatient
 function P:PreparePatient(client,cart,body,patient,display)
  eq(display.SetupBones,nil);eq(display.InvalidateBoneCache,nil)
  function display:GetBoneMatrix() error('simulated server bone failure') end
  return prepare(self,client,cart,body,patient,display)
 end
 local ok,reason=P:LoadPatient(carrier,cart);eq(ok,false);assert(reason)
 eq(lastDisplay.valid,false);eq(D.Body(carrier),body);eq(P.patientStates[cart],nil);eq(P:GetPatient(cart),nil)
 eq(body.hidden,nil);eq(body.parts[1].motion,true);eq(#errors,1)
 P.PreparePatient=prepare;assert(P:LoadPatient(carrier,cart));eq(lastDisplay.hidden,false)
 `);
 test('Refreshing patient transport removes only abandoned displays',`
 local abandoned=ents.Create('ix_cart_patient')
 assert(P:LoadPatient(carrier,cart));local live=P:PatientDisplay(patient)
 local stale=ents.Create('ix_cart_patient');stale:SetNW2Entity('ixPatientCart',cart)
 P:CleanupPatientDisplays();eq(abandoned.valid,false);eq(stale.valid,false);eq(live.valid,true)
 eq(P:GetPatient(cart),patient);eq(body.hidden,true)
 `);
 test('Failed cart loading leaves dragging intact: cargo, movement, tilt, missing pose, missing bone and blocked floor',`
 local function rejected() eq(P:LoadPatient(carrier,cart),false);eq(D.Body(carrier),body);eq(P:GetPatient(cart),nil);eq(body.hidden,nil) end
 cart.inventory.items={crate={}};rejected();cart.inventory.items=nil
 cart.velocity=Vector(10,0,0);rejected();cart.velocity=nil
 cart.ang=Angle(30,0,0);rejected();cart.ang=Angle()
 missingSequence=true;rejected();missingSequence=false
 missingBone=true;rejected();missingBone=false
 blockExit=true;rejected();blockExit=false
 noFloor=true;rejected();noFloor=false
 assert(P:LoadPatient(carrier,cart))
 `);
 test('Cart occupant follows movement without forces and unload restores each original physics flag',`
 assert(P:LoadPatient(carrier,cart));local display=P:PatientDisplay(patient);local state=P.patientStates[cart]
 local old=body.parts[1].pos;cart.pos=cart.pos+Vector(100,0,0);P:SyncPatient(state)
 vectorNear(body.parts[1].pos,old+Vector(100,0,0));eq(display.boneBuilds,1)
 local moves=body.parts[1].moves;P:SyncPatient(state);eq(body.parts[1].moves,moves)
 trace.Entity=display;rayFraction=.2;carrier.pos=Vector(100,-65,0)
 assert(P:UnloadPatient(carrier,cart,false));eq(P:GetPatient(cart),nil);eq(display.valid,false);eq(body.hidden,false);eq(body.notSolid,false)
 eq(body.parts[1].motion,true);eq(body.parts[1].collisions,true);eq(body.parts[2].motion,false);eq(body.parts[2].collisions,false)
 eq(patient.ixRagdoll,body);eq(patient.vars.crit,true);eq(cart.load,0)
 `);
 test('Occupied cart rejects crate attachment including restoration and cannot be packed as empty',`
 assert(P:LoadPatient(carrier,cart));assert(P:HasContents(cart))
 local crate=enrich(dragEntity('ix_cargo_crate'));crate.isCargoCrate=true
 eq(cart:CanAttachCrate(crate),false);eq(cart:AttachCrate(crate,true),false);eq(cart:AttachCrate(crate,false),false)
 assert(not table.HasValue(P:InteractionOptions(carrier,cart),'pack'));eq(D.CanTarget(carrier,body),false)
 `);
 test('Blocked unloading preserves the occupied cart; valid handoff reacquires the same body and reload lock',`
 local weapon=dragWeapon(carrier);assert(P:LoadPatient(carrier,cart));trace.Entity=cart
 blockExit=true;eq(P:UnloadPatient(carrier,cart,true),false);assert(P:GetPatient(cart));eq(body.hidden,true);blockExit=false
 weapon.reloading=true;eq(P:UnloadPatient(carrier,cart,true),false);weapon.reloading=false
 assert(P:UnloadPatient(carrier,cart,true));eq(D.Body(carrier),body);eq(P:GetPatient(cart),nil);eq(weapon:Reload(),false)
 D.Stop(carrier);eq(weapon:Reload(),'reloaded')
 `);
 test('Ordinary unloading checks the carrier footprint; handoff alone may share it before drag collision exclusion',`
  assert(P:LoadPatient(carrier,cart));local raw=util.TraceHull;local sawFloor=false
  util.TraceHull=function(data)
   if data.endpos.z<data.start.z then sawFloor=true;assert(not table.HasValue(data.filter,carrier)) end
   return raw(data)
  end
  assert(P:PatientExit(P.patientStates[cart],carrier,false));assert(sawFloor)
  util.TraceHull=function(data)
   if data.endpos.z<data.start.z then assert(table.HasValue(data.filter,carrier)) end
   return raw(data)
  end
  assert(P:PatientExit(P.patientStates[cart],carrier,true))
 `);
 test('Patient menus consume tokens once and reject replacement patients, stale targets and distant actors',`
 assert(P:LoadPatient(carrier,cart));P:OpenInteraction(carrier,cart)
 local token=carrier.ixCartMenu.token;cart:SetNW2Entity('ixCartPatient',enrich(dragPlayer()))
 eq(P:PerformInteraction(carrier,cart,token,'unloadPatient'),false);assert(P.patientStates[cart])
 cart:SetNW2Entity('ixCartPatient',patient);clock=clock+1;P:OpenInteraction(carrier,cart);token=carrier.ixCartMenu.token
 trace.Entity=NULL;eq(P:PerformInteraction(carrier,cart,token,'unloadPatient'),false);assert(P.patientStates[cart])
 trace.Entity=cart;clock=clock+1;P:OpenInteraction(carrier,cart);token=carrier.ixCartMenu.token
 local nearby=carrier.pos;carrier.pos=Vector(2000,0,0);eq(P:PerformInteraction(carrier,cart,token,'unloadPatient'),false);assert(P.patientStates[cart]);carrier.pos=nearby
 clock=clock+1;P:OpenInteraction(carrier,cart);token=carrier.ixCartMenu.token
 assert(P:PerformInteraction(carrier,cart,token,'unloadPatient'));eq(P:PerformInteraction(carrier,cart,token,'unloadPatient'),false)
 `);
 test('Native recovery chooses a safe exit and retires the cart without replacing the original body',`
 assert(P:LoadPatient(carrier,cart));local display=P:PatientDisplay(patient)
 local exit=fire('GetRagdollRecoveryPosition',patient,body);assert(exit);eq(P:GetPatient(cart),nil);eq(display.valid,false)
 eq(fire('GetRagdollRecoveryPosition',patient,body),nil);eq(patient.vars.crit,true)
 eq(patient.ixRagdoll,body);assert(body.inventory);eq(body.parts[1].motion,false) -- native deletion owns final cleanup
 `);
 for(const [name,event] of [
  ['cart removal','cart:OnRemove()'],['deleted display','display:Remove()'],['character swap',"fire('PrePlayerLoadedCharacter',patient)"],
  ['disconnect',"fire('PlayerDisconnected',patient)"],['death',"fire('PlayerDeath',patient)"],['map cleanup',"fire('PreCleanupMap')"],
  ['shutdown',"fire('ShutDown')"],['changed model',"body.model='other.mdl';fire('Think')"]]){
  test('Cart patient cleanup survives '+name,`
   assert(P:LoadPatient(carrier,cart));local display=P:PatientDisplay(patient);${event}
   eq(P:GetPatient(cart),nil);eq(P.patientStates[cart],nil);eq(display.valid,false)
   assert(body.valid and body.inventory);eq(body.hidden,false);eq(body.notSolid,false);eq(body.parts[1].motion,true)
   eq(patient:GetNW2Entity('ixPatientCart'),NULL);eq(body:GetNW2Entity('ixPatientCart'),NULL)
   eq(P:ReleasePatient(cart),nil)
  `);
 }
 test('E loads immediately and rejects another loader; occupied-body menus preserve explicit critical actions',`
  P:OpenInteraction(carrier,cart);eq(P:GetPatient(cart),patient);eq(carrier.ixCartMenu,nil)
  local display=P:PatientDisplay(patient);rayFraction=.1;local options=P:InteractionOptions(carrier,display)
  assert(table.HasValue(options,'takePatient'));assert(table.HasValue(options,'finishPatient'));assert(table.HasValue(options,'robPatient'))
  eq(P:LoadPatient(carrier,cart),false);eq(fire('PhysgunPickup',carrier,body),false)
  eq(fire('CanPlayerHoldObject',carrier,display),false)
 `);
 test('An unavailable custom SD pose falls back to a verified lying sequence rather than a standing idle',`
  local display=enrich(dragEntity('ix_cart_patient'));local lookups={}
  function display:LookupSequence(name) lookups[#lookups+1]=name;return name=='stances_down02' and 7 or -1 end
  local sequence,low,high=P:PatientSequence(display);eq(sequence,7);assert(high.z-low.z<high.x-low.x)
  eq(lookups[1],'custom_male_down02');eq(lookups[2],'custom_female_down02')
 `);
 test('Patient ray selection stops at nearer geometry and medicine resolves the displayed patient',`
 assert(P:LoadPatient(carrier,cart));local display=P:PatientDisplay(patient)
 rayFraction=.4;trace.Fraction=.2;eq(P:TracePatient(carrier),nil)
 trace.Fraction=.8;eq(P:TracePatient(carrier),display);eq(ix.Medicine.ResolveTarget(carrier),patient)
 eq(ix.Medicine.PatientEntity(patient),display);assert(ix.Medicine.Reachable(carrier,patient))
 wall=true;eq(ix.Medicine.Reachable(carrier,patient),false)
 `,['ixhl2rp/plugins/medical/sv_treatment.lua']);
};
