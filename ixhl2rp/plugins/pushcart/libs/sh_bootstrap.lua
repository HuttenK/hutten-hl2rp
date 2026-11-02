-- Helix includes libs before items/entities, and sh_plugin only afterwards.
-- Entity files need these constants and capture both tables during inclusion.
-- Keep the table identities stable across reloads; sh_kinematics fills Kin later.
ix.PushCart = ix.PushCart or {}

local PushCart = ix.PushCart
PushCart.Kin = PushCart.Kin or {}
PushCart.MODEL = "models/props_silo/pushcart.mdl"
-- EP2 puts the handle on model -X. Driving still uses +X towards the
-- pusher; a local half-turn converts either orientation into the other.
function PushCart:FlipModelAngles(angles)
	return Angle(-angles.p, angles.y + 180, -angles.r)
end
-- Use the visible crate dimensions for selection on both realms. Model bounds
-- refer to the full-sized stock mesh, not the scaled cargo container.
PushCart.CRATE_MINS = Vector(-10.5, -10.5, 0)
PushCart.CRATE_MAXS = Vector(10.5, 10.5, 22)

-- Independent geometry in the driving frame (+X towards the attendant).
-- Measurements come from the installed Roleplay Props models at their idle pose.
PushCart.Transports = {ix_pushcart = {item="pushcart", yaw=180}}
function PushCart:Transport(cart)
	-- SpawnFunction also receives the registered entity table, before an
	-- instance (and therefore GetClass) exists.
	local class = cart.ClassName or cart.GetClass and cart:GetClass()
	return self.Transports[class] or self.Transports.ix_pushcart
end
function PushCart:GetKinematics(cart)
	local profile = self:Transport(cart)
	if profile.loadedKin and cart.GetCargoLoad and (cart:GetCargoLoad() or 0) > 0 then return profile.loadedKin end
	return profile.kin or self.Kin
end
function PushCart:ModelAngles(cart, angles, inverse)
	local yaw = self:Transport(cart).yaw
	if yaw == 180 then return self:FlipModelAngles(angles) end
	local _, result = LocalToWorld(vector_origin, Angle(0, inverse and -yaw or yaw, 0), vector_origin, angles)
	return result
end
function PushCart:CartItem(cart)
	return self:Transport(cart).item
end

