local P = ix.PushCart

function P:GetRider(cart)
 if not IsValid(cart) then return end
 local rider=cart:GetNW2Entity("ixCartRider")
 if IsValid(rider) then return rider end
end

function P:RiderCart(client)
 if not IsValid(client) then return end
 local cart=client:GetNW2Entity("ixRiderCart")
 if IsValid(cart) and self:GetRider(cart)==client then return cart end
end

-- The hidden native seat owns movement, exit and weapon restoration. Resolve
-- the sitting sequence on each realm so different animation packs cannot turn
-- a valid server sequence index into a standing pose on another client.
hook.Add("CalcMainActivity","ixWheelchairRider",function(client)
 if not P:RiderCart(client) or not client:InVehicle() then return end
 local name=client:GetNW2String("ixCartRiderSequence","")
 local model=client:GetModel();local cached=client.ixCartRiderAnimation
 if not cached or cached.model~=model or cached.name~=name then
  cached={model=model,name=name,index=client:LookupSequence(name)};client.ixCartRiderAnimation=cached
 end
 if cached.index and cached.index>=0 then client:SetCycle(0);return -1,cached.index end
end)

if CLIENT then
 hook.Add("CalcVehicleView","ixWheelchairRider",function(vehicle,client,view)
  local cart=P:RiderCart(client)
  if not cart or client:GetVehicle()~=vehicle or view.drawviewer then return end
  local pos,ang=cart:GetPos(),cart:GetAngles()
  if cart.GetDrawPose then pos,ang=cart:GetDrawPose() end
  view.origin=LocalToWorld(cart:GetNW2Vector("ixCartRiderEye"),angle_zero,pos,ang)
  view.znear=2
  return view
 end)
 hook.Add("HUDPaint","ixWheelchairRider",function()
  if ix.CCTV and ix.CCTV.rendering or not P:RiderCart(LocalPlayer()) then return end
  draw.SimpleText("E — встать из коляски","ixSmallFont",ScrW()/2,ScrH()*.88,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end)
end
