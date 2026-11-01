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
PushCart.Transports = {
	ix_pushcart = {item = "pushcart", yaw = 180},
	ix_medical_gurney = {
		item = "medical_gurney", yaw = 90,
		gripRight = Vector(8, -32.6, 40), gripLeft = Vector(-8, -32.6, 40),
		loadedGeometry = {BODY_MIN_X=-55, BODY_MAX_X=55, BODY_HALF_Y=27},
		geometry = {HALF_BASE=15, WHEEL_CENTER_X=3, HALF_TRACK=8.5,
			BODY_MIN_X=-40, BODY_MAX_X=40, BODY_HALF_Y=13, CLEARANCE=6,
			BODY_TOP_EMPTY=42, WHEEL_BOTTOM=-.008218, REACH=45,
			HOLD_MIN_X=40, HOLD_MAX_X=95, HOLD_MAX_Y=32, HANDLE_X=32.6, GRIP_Z=40,
			BELLY_LINES={-8, -3, 3, 8}, MAX_PITCH=20, MAX_ROLL=15}
	},
	ix_medical_wheelchair = {
		item = "medical_wheelchair", yaw = 180,
		gripRight = Vector(-15, -9, 38), gripLeft = Vector(-15, 9, 38),
		loadedGeometry = {BODY_MIN_X=-48, BODY_MAX_X=24, BODY_HALF_Y=24},
		geometry = {HALF_BASE=9, WHEEL_CENTER_X=-9, HALF_TRACK=10.5,
			BODY_MIN_X=-23, BODY_MAX_X=23, BODY_HALF_Y=15, CLEARANCE=3,
			BODY_TOP_EMPTY=40, WHEEL_BOTTOM=-.116194, REACH=27,
			HOLD_MIN_X=25, HOLD_MAX_X=70, HOLD_MAX_Y=28, HANDLE_X=15, GRIP_Z=38,
			BELLY_LINES={-10, -5, 0, 5, 10}, MAX_PITCH=15, MAX_ROLL=12}
	}
}
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

