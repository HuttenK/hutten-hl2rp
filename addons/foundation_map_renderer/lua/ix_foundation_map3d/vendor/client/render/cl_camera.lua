-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Util = DM.Util

DM.Camera = DM.Camera or {}
local Camera = DM.Camera

local smoothTarget = nil
local smoothYaw = 0
local lastUpdate = 0
local heightBlend = nil
local backBlend = nil
local lastVehicleYaw = nil

local PROFILE_BLEND = 6
local FOLLOW_SNAP_DISTANCE_SQR = 4096 * 4096

local function yawDelta( from, to )
	return math.NormalizeAngle( to - from )
end

local function followEntity()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return nil end

	local vehicle = ply:GetVehicle()
	if IsValid( vehicle ) then
		local body = vehicle

		for _ = 1, 4 do
			local parent = body:GetParent()
			if not IsValid( parent ) then break end
			body = parent
		end

		return body
	end

	return ply
end

function Camera.GetFollowTarget()
	local ent = followEntity()
	if not IsValid( ent ) then return nil end

	local ply = LocalPlayer()
	if ent == ply then
		return ent:GetPos() + Vector( 0, 0, 12 )
	end

	return ent:LocalToWorld( ent:OBBCenter() )
end

function Camera.GetFollowYaw()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return 0 end

	if DM.Config.Get( "ix_ftmap_sv_worldmap_lock" ) then return 0 end
	if not DM.Config.Get( "ix_ftmap_cl_rotate" ) then return 0 end

	local vehicle = ply:GetVehicle()
	if IsValid( vehicle ) then
		local body = followEntity()

		local velocity = body:GetVelocity()
		if velocity:Length2DSqr() > 40 * 40 then
			lastVehicleYaw = velocity:Angle().yaw
			return lastVehicleYaw
		end

		return lastVehicleYaw or body:GetAngles().yaw
	end

	lastVehicleYaw = nil
	return ply:EyeAngles().yaw
end

function Camera.Update()
	local now = RealTime()
	local dt = math.min( now - lastUpdate, 0.25 )
	lastUpdate = now

	local target = Camera.GetFollowTarget()
	if not target then return end

	local yaw = Camera.GetFollowYaw()

	if not smoothTarget or smoothTarget:DistToSqr( target ) > FOLLOW_SNAP_DISTANCE_SQR then
		smoothTarget = target
		smoothYaw = yaw
		return
	end

	local speed = DM.Config.Get( "ix_ftmap_cl_smooth" )

	if speed <= 0 then
		smoothTarget = target
		smoothYaw = yaw
		return
	end

	smoothTarget = LerpVector( 1 - math.exp( -speed * dt ), smoothTarget, target )

	smoothTarget.z = target.z
	smoothYaw = smoothYaw + yawDelta( smoothYaw, yaw ) * ( 1 - math.exp( -speed * dt ) )
end

-- The terminal supplies its own camera; no follow-player hook.

local function resolveProfile( dt )
	local height = DM.Config.Get( "ix_ftmap_sv_camera_height" )
	local back   = DM.Config.Get( "ix_ftmap_sv_camera_back" )

	heightBlend = heightBlend and Util.Approach( heightBlend, height, PROFILE_BLEND, dt ) or height
	backBlend   = backBlend and Util.Approach( backBlend, back, PROFILE_BLEND, dt ) or back

	return heightBlend, backBlend
end

function Camera.BuildFollowView( w, h, zoom )
	zoom = ( zoom or 1 ) * DM.Config.Get( "ix_ftmap_cl_hud_zoom" )

	local dt = math.min( FrameTime(), 0.1 )

	local liveTarget = Camera.GetFollowTarget()
	local target = smoothTarget or liveTarget or Vector( 0, 0, 0 )

	if liveTarget then
		if target:DistToSqr( liveTarget ) > FOLLOW_SNAP_DISTANCE_SQR then
			smoothTarget = liveTarget
			target = liveTarget
		else

			target = Vector( target.x, target.y, liveTarget.z )
		end
	end

	local yaw = smoothYaw

	local profileHeight, profileBack = resolveProfile( dt )

	local height = profileHeight * zoom
	local back   = profileBack * zoom
	local fov    = DM.Config.Get( "ix_ftmap_sv_camera_fov" )

	local topDown = DM.Config.Get( "ix_ftmap_sv_topdown_lock" ) or DM.Config.Get( "ix_ftmap_sv_worldmap_lock" )

	local pitch
	if topDown or back < 1 then
		pitch = 90
		back = 0
	else
		pitch = math.deg( math.atan2( height, back ) )
	end

	local yawForward = Angle( 0, yaw, 0 ):Forward()
	local origin = target - yawForward * back + Vector( 0, 0, math.max( height, 1 ) )
	local angles = Angle( pitch, yaw, 0 )

	local view = {
		origin = origin,
		angles = angles,
		fov    = fov,
		w      = w,
		h      = h,
		target = target,
		yaw    = yaw,
	}

	if DM.Config.Get( "ix_ftmap_sv_ortho" ) then
		local distance = origin:Distance( target )
		view.ortho = math.max( distance * math.tan( math.rad( fov ) * 0.5 ), 32 )
	end

	Camera.FinishView( view )
	return view
end

function Camera.BuildOrbitView( params )
	local pitch = Util.Clamp( params.pitch or 55, -89.5, 89.5 )
	local yaw = params.yaw or 0
	local distance = math.max( params.distance or 2000, 16 )
	local fov = params.fov or 70

	local angles = Angle( pitch, yaw, 0 )
	local origin = params.focus - angles:Forward() * distance

	local view = {
		origin = origin,
		angles = angles,
		fov    = fov,
		w      = params.w,
		h      = params.h,
		target = params.focus,
		yaw    = yaw,
	}

	if params.ortho then
		view.ortho = math.max( distance * math.tan( math.rad( fov ) * 0.5 ), 32 )
	end

	Camera.FinishView( view )
	return view
end

function Camera.BuildFreeView( origin, angles, fov, w, h, ortho )
	local view = {
		origin = origin,
		angles = angles,
		fov    = fov or 75,
		w      = w,
		h      = h,
		target = origin + angles:Forward() * 512,
		znear  = 8,
		zfar   = 65536,
	}

	if ortho then view.ortho = ortho end

	Camera.FinishView( view )
	return view
end

function Camera.FinishView( view )
	local reach = view.ortho or view.origin:Distance( view.target )

	view.znear = view.znear or math.max( 4, reach * 0.01 )
	view.zfar  = view.zfar or math.max( 32768, reach * 4 + 16384 )
	view.aspect = view.w / math.max( view.h, 1 )

	view.frustum = view.frustum or {}

	if view.ortho then
		DM.Util.BuildOrthoFrustum( view.origin, view.angles,
			view.ortho * view.aspect, view.ortho,
			1 - view.zfar, view.zfar, view.frustum, 64 )
	else
		DM.Util.BuildPerspectiveFrustum( view.origin, view.angles, view.fov, view.aspect,
			view.znear, view.zfar, view.frustum, 64 )
	end

	view.projector = DM.Util.MakeProjector( view )
	return view
end

function Camera.GetViewScale( view )
	if view.ortho then return view.ortho / 700 end
	return view.origin:Distance( view.target ) / 900
end
