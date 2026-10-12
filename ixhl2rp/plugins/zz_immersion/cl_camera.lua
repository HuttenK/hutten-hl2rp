local I = ix.Immersion
ix.lang.AddTable("en", {
 ["option.immersionCamera"]="Camera movement intensity",
 ["option.immersionCameraReduced"]="Reduced camera motion"
})
ix.lang.AddTable("ru", {
 ["option.immersionCamera"]="Интенсивность движения камеры",
 ["option.immersionCameraReduced"]="Уменьшенное движение камеры"
})
ix.option.Add("immersionCamera",ix.type.number,50,{category="appearance",min=0,max=100,decimals=0})
ix.option.Add("immersionCameraReduced",ix.type.bool,false,{category="appearance"})
function I.CameraEnabled()
 return not ix.option.Get("disableAnimations",false) and I.Unit(ix.option.Get("immersionCamera",50)/100)>0
end
local state={}
function I.ResetCamera() state={phase=0,weight=0,sprint=0,land=0} end
I.ResetCamera()
function I.CameraActive(p)
 return I.CameraEnabled() and I.Active() and not p:InVehicle()
  and p:GetMoveType()==MOVETYPE_WALK and p:WaterLevel()<2
  and not p:GetLocalVar("knocked",false) and p:GetLocalVar("drunk",0)<=0
  and not (ix.Downed and ix.Downed.Crawling and ix.Downed.Crawling(p))
end
function I.UpdateCamera()
 local p=LocalPlayer()
 if not IsValid(p) or not I.CameraActive(p) then I.ResetCamera() return end
 local character=p:GetCharacter()
 if state.character~=character then I.ResetCamera();state.character=character end
 local dt=math.Clamp(FrameTime(),0,.05)
 local velocity=p:GetVelocity()
 local speed=velocity:Length2D()
 local grounded=p:OnGround()
 if grounded and state.grounded==false then
  state.land=math.Clamp((-(state.fall or 0)-180)/500,0,1)
 end
 state.fall=grounded and 0 or math.min(state.fall or 0,velocity.z)
 state.grounded=grounded
 state.land=I.Approach(state.land,0,dt,.16)
 local weapon=p:GetActiveWeapon()
 local aiming=p:KeyDown(IN_ATTACK2)
 if IsValid(weapon) and weapon.GetSightAmount then aiming=aiming or weapon:GetSightAmount()>.01 end
 local target=grounded and not aiming and math.Clamp(speed/150,0,1) or 0
 if p:Crouching() then target=target*.3 end
 -- ARC9 already supplies weapon/camera movement. Add only a small contribution.
 if IsValid(weapon) and (weapon.ARC9 or weapon.ArcCW) then target=target*.45 end
 state.weight=I.Approach(state.weight,target,dt,.13)
 state.sprint=I.Approach(state.sprint,grounded and not aiming and p:KeyDown(IN_SPEED) and speed>150 and 1 or 0,dt,.22)
 -- Stretch the running cycle without increasing its amplitude. Use the
 -- smoothed sprint blend so cadence does not snap when sprint starts/stops.
 local cadence=math.min(speed/75,3.8)*(1-.65*state.sprint)
 state.phase=(state.phase+dt*cadence*math.pi*2)%(math.pi*2)
 state.aiming=aiming
end
hook.Add("Think","ixImmersionCamera",I.UpdateCamera)
function I.CameraOffsets()
 local scale=I.Unit(ix.option.Get("immersionCamera",50)/100)
 local reduced=ix.option.Get("immersionCameraReduced",false)
 if reduced then scale=scale*.25 end
 if state.aiming then return 0,0,0,0 end
 local weight=state.weight*scale
 local z=math.cos(state.phase*2)*.30*weight-state.land*.9*scale
 local side=math.sin(state.phase)*.18*weight
 local pitch=state.sprint*.35*weight+state.land*.45*scale
 local roll=reduced and 0 or math.sin(state.phase)*.16*weight
 return z,side,pitch,roll
end
-- Applied to the existing weapon/base view; never writes player aim or FOV.
function I.ApplyCamera(p,view,origin,angles)
 if not I.CameraActive(p) or view.drawviewer then return end
 local z,side,pitch,roll=I.CameraOffsets()
 local ang=view.angles or angles
 view.origin=(view.origin or origin)+Vector(0,0,z)+ang:Right()*side
 view.angles=Angle(ang.p+pitch,ang.y,ang.r+roll)
end
