local P=ix.PushCart
P.riderStates=P.riderStates or {}

function P:CanSitWheelchair(client,cart)
 if not IsValid(cart) or cart:GetClass()~="ix_medical_wheelchair" or not self:CanOperate(client)
  or self:IsPushing(client) or not self:Near(client,cart) or self:InteractionTarget(client)~=cart then return false end
 if self:HasContents(cart) or self:CargoBusy(cart) or IsValid(cart:GetPusher()) or self.riderStates[cart]
  or cart:GetVelocity():LengthSqr()>25 or cart:GetUp().z<.97 then return false end
 local ragdoll=client:GetLocalVar("ragdoll")
 if IsValid(client:GetLocalVar("holdingObject")) or ix.BodyDrag and ix.BodyDrag.Body(client)
  or client:GetNetVar("crit",false) or client:GetNetVar("tied",false) or client:GetLocalVar("knocked",false)
  or ragdoll and ragdoll~=0 or IsValid(client.ixRagdoll) or client:IsFrozen()
  or client:GetNetVar("forcedSequence")~=nil or client:GetNetVar("sitHelperPos")
  or client:GetNW2Bool("ixPoseStudioPlaying",false) then return false end
 return true
end

function P:PrepareRider(client,cart,pose,seat)
 pose:SetNoDraw(true);pose:SetModel(client:GetModel());pose:SetPos(cart:GetPos());pose:SetAngles(angle_zero)
 local sequence,low,high,name=self:PatientSequence(pose,true)
 if not sequence then return nil,"Эта модель не поддерживает сидение в коляске." end
 local scale=client:GetModelScale();low,high=low*scale,high*scale
 local size=high-low
 if size.x>55 or size.y>52 or size.z>65 then return nil,"Эта модель слишком велика для коляски." end
 pose:SetModelScale(scale,0);pose:Spawn();pose:ResetSequence(sequence);pose:SetCycle(0);pose:SetPlaybackRate(0)
 local pelvis=pose:LookupBone("ValveBiped.Bip01_Pelvis");local head=pose:LookupBone("ValveBiped.Bip01_Head1")
 local pelvisMatrix=pelvis and pose:GetBoneMatrix(pelvis);local headMatrix=head and pose:GetBoneMatrix(head)
 if not pelvisMatrix or not headMatrix then return nil,"Не удалось подготовить позу сидения." end
 local offset=cart.PatientSeat+Vector(0,0,4*scale)-(pelvisMatrix:GetTranslation()-cart:GetPos())
 offset.z=math.max(offset.z,.5-low.z)
 local eye=offset+headMatrix:GetTranslation()-cart:GetPos()+Vector(0,0,3*scale)
 local state={cart=cart,patient=client,body=seat,display=NULL,seat=seat,character=client:GetCharacter(),
  model=client:GetModel(),scale=scale,sequence=name,localPos=offset,eye=eye,top=offset.z+high.z,
  position=cart:GetPos(),angles=cart:GetAngles(),halfLength=17*scale,halfWidth=17*scale,height=72*scale,
  allowWeapons=client:GetAllowWeaponsInVehicle(),entered=CurTime()}
 state.safeExit=self:PatientExit(state,client)
 if not state.safeExit then return nil,"Рядом нет свободного места, чтобы затем встать." end
 local mins,maxs=Vector(math.huge,math.huge,math.huge),Vector(-math.huge,-math.huge,-math.huge)
 for _,x in ipairs({low.x,high.x}) do for _,y in ipairs({low.y,high.y}) do for _,z in ipairs({low.z,high.z}) do
  local point=LocalToWorld(Vector(x,y,z),angle_zero,vector_origin,cart:GetAngles())
  for _,axis in ipairs({"x","y","z"}) do mins[axis]=math.min(mins[axis],point[axis]);maxs[axis]=math.max(maxs[axis],point[axis]) end
 end end end
 local clear=util.TraceHull({start=cart:LocalToWorld(offset),endpos=cart:LocalToWorld(offset),
  mins=mins,maxs=maxs,filter={client,cart,pose,seat},mask=MASK_PLAYERSOLID})
 if clear.Hit or clear.StartSolid or clear.AllSolid then return nil,"Место для пассажира занято." end
 -- The stock seat's passenger-foot attachment defines the player's origin.
 -- Offset that seat so the sampled pelvis rests on this wheelchair's cushion.
 seat.ixWheelchairSeat=true;seat.bNoPersist=true;seat.DoNotDuplicate=true
 seat:SetModel("models/nova/airboat_seat.mdl")
 seat:SetKeyValue("vehiclescript","scripts/vehicles/prisoner_pod.txt");seat:SetKeyValue("limitview","0")
 seat:SetPos(cart:GetPos());seat:SetAngles(angle_zero);seat:Spawn();seat:Activate()
 local attachment=seat:LookupAttachment("vehicle_feet_passenger0")
 local feet=attachment and attachment>0 and seat:GetAttachment(attachment)
 if not feet then return nil,"Не удалось подготовить сиденье коляски." end
 local feetLocal=seat:WorldToLocal(feet.Pos)
 local heading=Angle(0,-90,0)
 local rotated=LocalToWorld(feetLocal,angle_zero,vector_origin,heading)
 seat:SetParent(cart);seat:SetLocalPos(offset-rotated);seat:SetLocalAngles(heading)
 seat:SetMoveType(MOVETYPE_NONE);seat:SetNotSolid(true);seat:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
 -- Keep the native vehicle networked for its occupant; hide only its mesh.
 seat:SetRenderMode(RENDERMODE_TRANSCOLOR);seat:SetColor(Color(255,255,255,0));seat:DrawShadow(false)
 seat:SetNW2Entity("ixRiderCart",cart)
 return state
end

function P:SitWheelchair(client,cart)
 if not self:CanSitWheelchair(client,cart) then return false,"Коляска занята или сейчас нельзя сесть." end
 local pose=ents.Create("prop_dynamic");local seat=ents.Create("prop_vehicle_prisoner_pod")
 if not IsValid(pose) or not IsValid(seat) then
  if IsValid(pose) then pose:Remove() end;if IsValid(seat) then seat:Remove() end
  return false,"Не удалось подготовить сиденье."
 end
 local ok,state,reason=xpcall(function() return self:PrepareRider(client,cart,pose,seat) end,debug.traceback)
 pose:Remove()
 if not ok or not state then
  seat:Remove();if not ok then ErrorNoHalt("[PushCart] Rider preparation failed: "..tostring(state).."\n") end
  return false,ok and reason or "Не удалось подготовить сиденье."
 end
 self.riderStates[cart]=state;state.entering=true
 client:EnterVehicle(seat);state.entering=nil
 if client:GetVehicle()~=seat then self.riderStates[cart]=nil;seat:Remove();return false,"Сейчас нельзя сесть в коляску." end
 cart:SetNW2Entity("ixCartRider",client);cart:SetNW2Vector("ixCartRiderPos",state.localPos);cart:SetNW2Vector("ixCartRiderEye",state.eye)
 client:SetNW2Entity("ixRiderCart",cart);client:SetNW2String("ixCartRiderSequence",state.sequence)
 client:SetAllowWeaponsInVehicle(false)
 cart:UpdateLoad();cart:LayoutCrates()
 return true,"Вы сели в коляску. E — встать. Другой персонаж может вас везти."
end

function P:FinishRider(cart,state)
 if self.riderStates[cart]~=state then return end
 self.riderStates[cart]=nil
 local client=state.patient
 if IsValid(cart) then
  if IsValid(cart:GetPusher()) then cart:StopPush() end
  cart:SetNW2Entity("ixCartRider",NULL);cart:UpdateLoad();cart:LayoutCrates()
 end
 if IsValid(client) then
  client:SetNW2Entity("ixRiderCart",NULL);client:SetNW2String("ixCartRiderSequence","")
  client:SetAllowWeaponsInVehicle(state.allowWeapons);client.ixCartRiderAnimation=nil
  if client:GetCharacter()==state.character and not client:InVehicle() then
   client:SetPos(state.exitPosition or state.safeExit);client:SetLocalVelocity(vector_origin)
  end
 end
 -- PlayerLeaveVehicle runs within the native exit. Retire the empty helper
 -- after that call has finished, not halfway through engine vehicle cleanup.
 timer.Simple(0,function() if IsValid(state.seat) then state.seat:Remove() end end)
end

function P:ReleaseRider(cart)
 local state=self.riderStates[cart];if not state then return end
 state.releasing=true
 state.exitPosition=self:PatientExit(state) or state.safeExit
 if IsValid(state.patient) and state.patient:GetVehicle()==state.seat then state.patient:ExitVehicle() end
 self:FinishRider(cart,state)
end

hook.Add("CanPlayerEnterVehicle","ixWheelchairRider",function(client,seat)
 if not seat.ixWheelchairSeat then return end
 local state=P.riderStates[seat:GetParent()]
 if not state or state.seat~=seat or state.patient~=client or not state.entering then return false end
end)
hook.Add("CanExitVehicle","ixWheelchairRider",function(seat,client)
 if not seat.ixWheelchairSeat then return end
 local state=P.riderStates[seat:GetParent()];if not state or state.releasing then return end
 if CurTime()-state.entered<.5 then return false end
 local position=P:PatientExit(state,client)
 if not position then
  if (state.nextWarning or 0)<CurTime() then client:Notify("Нет свободного места рядом с коляской.");state.nextWarning=CurTime()+2 end
  return false
 end
 state.exitPosition=position
 if IsValid(state.cart:GetPusher()) then state.cart:StopPush() end
end)
hook.Add("PlayerLeaveVehicle","ixWheelchairRider",function(client,seat)
 if not seat.ixWheelchairSeat then return end
 local cart=seat:GetParent();local state=P.riderStates[cart]
 if state and state.patient==client then
  state.exitPosition=state.exitPosition or P:PatientExit(state,client) or state.safeExit
  P:FinishRider(cart,state)
 end
end)

local function ReleasePlayer(client)
 for cart,state in pairs(P.riderStates) do if state.patient==client then P:ReleaseRider(cart) end end
end
for _,event in ipairs({"PlayerDeath","PlayerSpawn","PlayerDisconnected","PrePlayerLoadedCharacter"}) do
 hook.Add(event,"ixWheelchairRider",ReleasePlayer)
end
hook.Add("OnCharacterFallover","ixWheelchairRider",function(client,_,fallen) if fallen then ReleasePlayer(client) end end)
hook.Add("EntityRemoved","ixWheelchairRider",function(entity)
 for cart,state in pairs(P.riderStates) do if cart==entity or state.seat==entity then P:ReleaseRider(cart) end end
end)
for _,event in ipairs({"PreCleanupMap","ShutDown"}) do
 hook.Add(event,"ixWheelchairRider",function() for cart in pairs(P.riderStates) do P:ReleaseRider(cart) end end)
end
hook.Add("Think","ixWheelchairRider",function()
 if (P.nextRiderCheck or 0)>CurTime() then return end;P.nextRiderCheck=CurTime()+.2
 for cart,state in pairs(P.riderStates) do
  local client=state.patient
  if not IsValid(cart) or not IsValid(client) or not client:Alive() or client:GetCharacter()~=state.character
   or not IsValid(state.seat) or client:GetVehicle()~=state.seat or client:GetModel()~=state.model
   or client:GetModelScale()~=state.scale or client:GetNetVar("crit",false) then P:ReleaseRider(cart)
  else
   state.position,state.angles=cart:GetPos(),cart:GetAngles()
   if (state.nextExit or 0)<CurTime() then state.nextExit=CurTime()+1;state.safeExit=P:PatientExit(state) or state.safeExit end
  end
 end
end)
