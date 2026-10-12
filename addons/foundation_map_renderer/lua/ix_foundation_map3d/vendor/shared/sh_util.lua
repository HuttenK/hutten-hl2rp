-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
DM.Util = DM.Util or {}

local Util = DM.Util

local math_min, math_max, math_floor, math_abs = math.min, math.max, math.floor, math.abs
local math_sqrt, math_tan, math_rad           = math.sqrt, math.tan, math.rad
local table_sort                              = table.sort
local string_char, string_byte                = string.char, string.byte
local Vector, Angle                           = Vector, Angle

Util.VEC_ZERO = Vector( 0, 0, 0 )
Util.VEC_UP   = Vector( 0, 0, 1 )
Util.VEC_DOWN = Vector( 0, 0, -1 )

function Util.IsFiniteNumber( value )
	return type( value ) == "number" and value == value and value > -math.huge and value < math.huge
end

function Util.IsValidPosition( pos )
	return isvector( pos ) and Util.IsFiniteNumber( pos.x ) and Util.IsFiniteNumber( pos.y )
		and Util.IsFiniteNumber( pos.z ) and math_abs( pos.x ) <= 1048576
		and math_abs( pos.y ) <= 1048576 and math_abs( pos.z ) <= 1048576
end

function Util.Clamp( v, lo, hi )
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

function Util.Lerp( t, a, b )
	return a + ( b - a ) * t
end

function Util.Approach( current, target, speed, dt )
	if speed <= 0 then return target end
	local f = 1 - math.exp( -speed * dt )
	return current + ( target - current ) * f
end

function Util.Round( v )
	return math_floor( v + 0.5 )
end

function Util.Snap( v, grid )
	if not grid or grid <= 0 then return v end
	return math_floor( v / grid + 0.5 ) * grid
end

function Util.CopyVector( v )
	return Vector( v.x, v.y, v.z )
end

function Util.ExpandBounds( mins, maxs, v )
	if v.x < mins.x then mins.x = v.x end
	if v.y < mins.y then mins.y = v.y end
	if v.z < mins.z then mins.z = v.z end
	if v.x > maxs.x then maxs.x = v.x end
	if v.y > maxs.y then maxs.y = v.y end
	if v.z > maxs.z then maxs.z = v.z end
end

function Util.SortBounds( mins, maxs )
	local a = Vector( math_min( mins.x, maxs.x ), math_min( mins.y, maxs.y ), math_min( mins.z, maxs.z ) )
	local b = Vector( math_max( mins.x, maxs.x ), math_max( mins.y, maxs.y ), math_max( mins.z, maxs.z ) )
	return a, b
end

function Util.PointInBox( p, mins, maxs )
	return p.x >= mins.x and p.x <= maxs.x
	   and p.y >= mins.y and p.y <= maxs.y
	   and p.z >= mins.z and p.z <= maxs.z
end

function Util.BoxesOverlap( aMin, aMax, bMin, bMax )
	return aMin.x <= bMax.x and aMax.x >= bMin.x
	   and aMin.y <= bMax.y and aMax.y >= bMin.y
	   and aMin.z <= bMax.z and aMax.z >= bMin.z
end

function Util.BoxVolume( mins, maxs )
	return math_abs( maxs.x - mins.x ) * math_abs( maxs.y - mins.y ) * math_abs( maxs.z - mins.z )
end

function Util.BoxCorners( mins, maxs, out )
	out = out or {}
	out[1] = Vector( mins.x, mins.y, mins.z )
	out[2] = Vector( maxs.x, mins.y, mins.z )
	out[3] = Vector( maxs.x, maxs.y, mins.z )
	out[4] = Vector( mins.x, maxs.y, mins.z )
	out[5] = Vector( mins.x, mins.y, maxs.z )
	out[6] = Vector( maxs.x, mins.y, maxs.z )
	out[7] = Vector( maxs.x, maxs.y, maxs.z )
	out[8] = Vector( mins.x, maxs.y, maxs.z )
	return out
end

function Util.RayBox( origin, dir, mins, maxs )
	local tmin, tmax = -math.huge, math.huge

	local o, d = origin.x, dir.x
	if math_abs( d ) < 1e-9 then
		if o < mins.x or o > maxs.x then return nil end
	else
		local inv = 1 / d
		local t1, t2 = ( mins.x - o ) * inv, ( maxs.x - o ) * inv
		if t1 > t2 then t1, t2 = t2, t1 end
		if t1 > tmin then tmin = t1 end
		if t2 < tmax then tmax = t2 end
		if tmin > tmax then return nil end
	end

	o, d = origin.y, dir.y
	if math_abs( d ) < 1e-9 then
		if o < mins.y or o > maxs.y then return nil end
	else
		local inv = 1 / d
		local t1, t2 = ( mins.y - o ) * inv, ( maxs.y - o ) * inv
		if t1 > t2 then t1, t2 = t2, t1 end
		if t1 > tmin then tmin = t1 end
		if t2 < tmax then tmax = t2 end
		if tmin > tmax then return nil end
	end

	o, d = origin.z, dir.z
	if math_abs( d ) < 1e-9 then
		if o < mins.z or o > maxs.z then return nil end
	else
		local inv = 1 / d
		local t1, t2 = ( mins.z - o ) * inv, ( maxs.z - o ) * inv
		if t1 > t2 then t1, t2 = t2, t1 end
		if t1 > tmin then tmin = t1 end
		if t2 < tmax then tmax = t2 end
		if tmin > tmax then return nil end
	end

	if tmax < 0 then return nil end
	return tmin >= 0 and tmin or 0
end

function Util.RayTriangle( origin, dir, v0, v1, v2 )
	local e1 = v1 - v0
	local e2 = v2 - v0
	local p  = dir:Cross( e2 )
	local det = e1:Dot( p )

	if det > -1e-6 and det < 1e-6 then return nil end

	local invDet = 1 / det
	local tv = origin - v0
	local u  = tv:Dot( p ) * invDet
	if u < 0 or u > 1 then return nil end

	local q = tv:Cross( e1 )
	local v = dir:Dot( q ) * invDet
	if v < 0 or u + v > 1 then return nil end

	local t = e2:Dot( q ) * invDet
	if t <= 0 then return nil end
	return t
end

function Util.RayPlane( origin, dir, planePoint, planeNormal )
	local denom = planeNormal:Dot( dir )
	if math_abs( denom ) < 1e-6 then return nil end
	local t = ( planePoint - origin ):Dot( planeNormal ) / denom
	if t < 0 then return nil end
	return t
end

function Util.ClosestPointOnLines( aOrigin, aDir, bOrigin, bDir )
	local r = bOrigin - aOrigin
	local a = aDir:Dot( aDir )
	local b = aDir:Dot( bDir )
	local c = bDir:Dot( bDir )
	local d = aDir:Dot( r )
	local e = bDir:Dot( r )
	local denom = a * c - b * b
	if math_abs( denom ) < 1e-9 then return 0 end
	return ( b * e - c * d ) / -denom
end

function Util.BuildPerspectiveFrustum( origin, angles, fov, aspect, zNear, zFar, out, margin )
	out = out or {}
	margin = margin or 0

	local f = angles:Forward()
	local r = angles:Right()
	local u = angles:Up()

	local tanX = math_tan( math_rad( fov ) * 0.5 )
	local tanY = tanX / math_max( aspect, 0.0001 )

	local function plane( i, n, point )
		n = n:GetNormalized()
		local pl = out[i] or {}
		pl[1], pl[2], pl[3] = n.x, n.y, n.z
		pl[4] = n:Dot( point ) - margin
		out[i] = pl
	end

	plane( 1, f * tanX - r, origin )
	plane( 2, f * tanX + r, origin )
	plane( 3, f * tanY - u, origin )
	plane( 4, f * tanY + u, origin )
	plane( 5, f, origin + f * zNear )
	plane( 6, -f, origin + f * zFar )

	out.count = 6
	return out
end

function Util.BuildOrthoFrustum( origin, angles, halfWidth, halfHeight, zNear, zFar, out, margin )
	out = out or {}
	margin = margin or 0

	local f = angles:Forward()
	local r = angles:Right()
	local u = angles:Up()

	local function plane( i, n, point )
		local pl = out[i] or {}
		pl[1], pl[2], pl[3] = n.x, n.y, n.z
		pl[4] = n:Dot( point ) - margin
		out[i] = pl
	end

	plane( 1, -r, origin + r * halfWidth )
	plane( 2, r,  origin - r * halfWidth )
	plane( 3, -u, origin + u * halfHeight )
	plane( 4, u,  origin - u * halfHeight )
	plane( 5, f,  origin + f * zNear )
	plane( 6, -f, origin + f * zFar )

	out.count = 6
	return out
end

function Util.BoxInFrustum( frustum, mins, maxs )
	for i = 1, frustum.count do
		local pl = frustum[i]
		local nx, ny, nz = pl[1], pl[2], pl[3]

		local px = nx >= 0 and maxs.x or mins.x
		local py = ny >= 0 and maxs.y or mins.y
		local pz = nz >= 0 and maxs.z or mins.z
		if nx * px + ny * py + nz * pz < pl[4] then return false end
	end
	return true
end

function Util.SphereInFrustum( frustum, center, radius )
	for i = 1, frustum.count do
		local pl = frustum[i]
		if pl[1] * center.x + pl[2] * center.y + pl[3] * center.z + radius < pl[4] then
			return false
		end
	end
	return true
end

function Util.MakeProjector( view )
	local ang = view.angles
	return {
		origin = view.origin,
		f = ang:Forward(),
		r = ang:Right(),
		u = ang:Up(),
		fov = view.fov,
		ortho = view.ortho,
		w = view.w,
		h = view.h,
	}
end

function Util.Project( proj, pos )
	local rel = pos - proj.origin
	local depth = rel:Dot( proj.f )
	local sx    = rel:Dot( proj.r )
	local sy    = rel:Dot( proj.u )

	local halfW, halfH = proj.w * 0.5, proj.h * 0.5

	if proj.ortho then
		local aspect = proj.w / math_max( proj.h, 1 )
		local ow = proj.ortho * aspect
		return halfW + ( sx / ow ) * halfW, halfH - ( sy / proj.ortho ) * halfH, depth > 0, depth
	end

	if depth <= 1 then
		return halfW, halfH, false, depth
	end

	local tanX = math_tan( math_rad( proj.fov ) * 0.5 )
	local tanY = tanX / ( proj.w / math_max( proj.h, 1 ) )

	return halfW + ( sx / ( depth * tanX ) ) * halfW,
		   halfH - ( sy / ( depth * tanY ) ) * halfH,
		   true, depth
end

function Util.ScreenToRay( view, px, py )
	local ang = view.angles
	local f, r, u = ang:Forward(), ang:Right(), ang:Up()
	local halfW, halfH = view.w * 0.5, view.h * 0.5
	local ndcX = ( px - halfW ) / halfW
	local ndcY = ( halfH - py ) / halfH

	if view.ortho then
		local aspect = view.w / math_max( view.h, 1 )
		local origin = view.origin + r * ( ndcX * view.ortho * aspect ) + u * ( ndcY * view.ortho )
		return origin, f
	end

	local tanX = math_tan( math_rad( view.fov ) * 0.5 )
	local tanY = tanX / ( view.w / math_max( view.h, 1 ) )
	local dir = ( f + r * ( ndcX * tanX ) + u * ( ndcY * tanY ) ):GetNormalized()
	return view.origin, dir
end

function Util.CopyColor( c, alpha )
	return Color( c.r, c.g, c.b, alpha or c.a or 255 )
end

function Util.ShadeColor( c, mul )
	return Color(
		Util.Clamp( c.r * mul, 0, 255 ),
		Util.Clamp( c.g * mul, 0, 255 ),
		Util.Clamp( c.b * mul, 0, 255 ),
		c.a or 255
	)
end

function Util.LerpColor( t, a, b )
	return Color(
		a.r + ( b.r - a.r ) * t,
		a.g + ( b.g - a.g ) * t,
		a.b + ( b.b - a.b ) * t,
		( a.a or 255 ) + ( ( b.a or 255 ) - ( a.a or 255 ) ) * t
	)
end

function Util.ColorToTable( c )
	return { math_floor( c.r ), math_floor( c.g ), math_floor( c.b ), math_floor( c.a or 255 ) }
end

function Util.TableToColor( t, fallback )
	if type( t ) ~= "table" or not t[1] then return fallback or Color( 255, 255, 255 ) end
	local channels = {}
	for i = 1, 4 do
		local value = t[i] == nil and 255 or tonumber( t[i] )
		if not Util.IsFiniteNumber( value ) then error( "invalid colour channel" ) end
		channels[i] = Util.Clamp( value, 0, 255 )
	end
	return Color( channels[1], channels[2], channels[3], channels[4] )
end

local CODEC_BASE   = 35
local CODEC_DIGITS = 32
local CODEC_CONT   = 32
local MAX_SET_ID = 2147483647
local MAX_SET_COUNT = 262144

local function checkSetId( id )
	if not Util.IsFiniteNumber( id ) or id < 0 or id > MAX_SET_ID or id ~= math_floor( id ) then
		error( "invalid surface or prop ID" )
	end
end

function Util.EncodeIntSet( set )
	if type( set ) ~= "table" then error( "invalid ID set" ) end
	local list = {}
	local n = 0

	if set[1] ~= nil and type( set[1] ) == "number" then
		for i = 1, #set do
			checkSetId( set[i] )
			n = n + 1
			if n > MAX_SET_COUNT then error( "too many surface or prop IDs" ) end
			list[n] = set[i]
		end
	else
		for id, on in pairs( set ) do
			if on then
				checkSetId( id )
				n = n + 1
				if n > MAX_SET_COUNT then error( "too many surface or prop IDs" ) end
				list[n] = id
			end
		end
	end

	if n == 0 then return "" end
	table_sort( list )

	local out, p, prev = {}, 0, -1
	for i = 1, n do
		local id = list[i]

		if id ~= prev then
			local delta = id - prev
			prev = id

			repeat
				local chunk = delta % CODEC_DIGITS
				delta = math_floor( delta / CODEC_DIGITS )
				p = p + 1
				out[p] = string_char( CODEC_BASE + chunk + ( delta > 0 and CODEC_CONT or 0 ) )
			until delta == 0
		end
	end

	return table.concat( out )
end

function Util.DecodeIntSet( str )
	local set = {}
	if str == nil or str == "" then return set end
	if type( str ) ~= "string" or #str > MAX_SET_COUNT * 7 then error( "invalid encoded ID set" ) end

	local prev, acc, shift, count = -1, 0, 1, 0
	for i = 1, #str do
		local byte = string_byte( str, i ) - CODEC_BASE
		if byte < 0 or byte >= CODEC_CONT * 2 then error( "invalid ID encoding" ) end
		local cont = byte >= CODEC_CONT
		if cont then byte = byte - CODEC_CONT end

		acc = acc + byte * shift
		if acc > MAX_SET_ID - prev then error( "ID overflow" ) end
		if cont then
			shift = shift * CODEC_DIGITS
			if shift > MAX_SET_ID + 1 then error( "ID overflow" ) end
		else
			if acc == 0 then error( "IDs must be increasing" ) end
			count = count + 1
			if count > MAX_SET_COUNT then error( "too many surface or prop IDs" ) end
			prev = prev + acc
			set[prev] = true
			acc, shift = 0, 1
		end
	end
	if shift ~= 1 then error( "incomplete ID encoding" ) end

	return set
end

function Util.CountSet( set )
	local n = 0
	for _, v in pairs( set ) do
		if v then n = n + 1 end
	end
	return n
end

function Util.SplitString( str, size )
	local out, n = {}, 0
	local len = #str
	local i = 1
	while i <= len do
		n = n + 1
		out[n] = string.sub( str, i, i + size - 1 )
		i = i + size
	end
	return out
end

function Util.Hash( str )
	local h = 2166136261
	for i = 1, #str do
		h = bit.bxor( h, string_byte( str, i ) )
		h = ( h * 16777619 ) % 4294967296
	end
	return h
end

function Util.FormatDistance( units )
	local meters = units * 0.01905
	if meters >= 1000 then
		return string.format( "%.1f km", meters / 1000 )
	end
	return string.format( "%.0f m", meters )
end

local circleCache = {}

function Util.Circle( x, y, radius, segments )
	segments = segments or 64
	local key = segments
	local base = circleCache[key]

	if not base then
		base = {}
		for i = 0, segments - 1 do
			local a = math_rad( ( i / segments ) * 360 )
			base[i + 1] = { math.cos( a ), math.sin( a ) }
		end
		circleCache[key] = base
	end

	local poly = {}
	for i = 1, segments do
		local c = base[i]
		poly[i] = { x = x + c[1] * radius, y = y + c[2] * radius }
	end
	return poly
end

function Util.DrawArc( x, y, outer, inner, fraction, segments )
	segments = segments or 64
	fraction = Util.Clamp( fraction, 0, 1 )
	if fraction <= 0 then return end

	local steps = math.max( math.ceil( segments * fraction ), 1 )
	local span = fraction * 360

	local quad = { {}, {}, {}, {} }

	local prevCos, prevSin
	for i = 0, steps do
		local a = math_rad( -90 + ( i / steps ) * span )
		local c, s = math.cos( a ), math.sin( a )

		if prevCos then
			quad[1].x, quad[1].y = x + prevCos * outer, y + prevSin * outer
			quad[2].x, quad[2].y = x + c * outer,       y + s * outer
			quad[3].x, quad[3].y = x + c * inner,       y + s * inner
			quad[4].x, quad[4].y = x + prevCos * inner, y + prevSin * inner
			surface.DrawPoly( quad )
		end

		prevCos, prevSin = c, s
	end
end

function Util.PathLength( points )
	local total = 0
	for i = 2, #points do
		total = total + points[i]:Distance( points[i - 1] )
	end
	return total
end

function Util.MapName()
	return game.GetMap()
end
