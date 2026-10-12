-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Util = DM.Util

DM.SurfaceQuery = {}
local Query = DM.SurfaceQuery
local cache, order, first, last, vertices = {}, {}, 1, 0, 0
local cacheMap, cacheVersion
local MAX_VERTICES = 131072

function Query.GetTriangles( rec )
	local map, version = NikNaks.CurrentMap, DM.Bake and DM.Bake.Version
	if cacheMap ~= map or cacheVersion ~= version then
		cache, order, first, last, vertices = {}, {}, 1, 0, 0
		cacheMap, cacheVersion = map, version
	end
	local data = cache[rec]
	if data then return data end
	data = DM.Extract.GetTrianglePositions( rec )
	if not data or #data < 3 then return nil end
	if ( rec.bmodel or 0 ) ~= 0 then

		local face = map and map:GetFaces()[rec.id]
		if face then
			local ok, polygon = pcall( face.GetVertexs, face )
			face._vertex = nil
			if ok and polygon then
				for i = 2, #polygon - 1 do
					local dot = ( polygon[i] - polygon[1] ):Cross( polygon[i + 1] - polygon[1] ):Dot( rec.normal )
					if math.abs( dot ) > 1e-8 then data.winding = dot < 0 and -1 or 1; break end
				end
			end
		end
	end
	if #data > MAX_VERTICES then return data end
	while vertices + #data > MAX_VERTICES and first <= last do
		local old = order[first]
		if cache[old] then vertices = vertices - #cache[old]; cache[old] = nil end
		order[first], first = nil, first + 1
	end
	if first > last then order, first, last = {}, 1, 0 end
	cache[rec] = data
	last = last + 1
	order[last], vertices = rec, vertices + #data
	return data
end

function Query.IsGround( rec )
	local S = DM.SURFACE
	if ( rec.bmodel or 0 ) ~= 0 or rec.roof or rec.class == S.ROOF
		or rec.class == S.CEILING or rec.class == S.WATER or rec.class == S.GLASS then return false end
	return rec.disp or ( rec.nz or rec.normal.z ) > 0.05 and (
		rec.class == S.GROUND or rec.class == S.ROAD or DM.SURFACE_TERRAIN[rec.class]
		or rec.batch == DM.BATCH.TERRAIN )
end

function Query.Collect( grid, mins, maxs, yield )
	local out, seen = {}, {}
	if not grid then return out end
	local size = grid.cellSize

	for x = math.floor( mins.x / size ), math.floor( maxs.x / size ) do
		for y = math.floor( mins.y / size ), math.floor( maxs.y / size ) do
			local cell = grid:GetCell( x, y )
			if cell then
				for i = 1, cell.n do
					local rec = cell.items[i]
					if not seen[rec] then
						seen[rec] = true
						if rec.maxs.x >= mins.x and rec.mins.x <= maxs.x
							and rec.maxs.y >= mins.y and rec.mins.y <= maxs.y
							and rec.maxs.z >= mins.z and rec.mins.z <= maxs.z then out[#out + 1] = rec end
					end
					if yield and i % 128 == 0 then yield() end
				end
			end
			if yield then yield() end
		end
	end
	return out
end

local function rayTriangle( origin, dir, a, b, c )

	local ex, ey, ez = b.x - a.x, b.y - a.y, b.z - a.z
	local fx, fy, fz = c.x - a.x, c.y - a.y, c.z - a.z
	local px, py, pz = dir.y * fz - dir.z * fy, dir.z * fx - dir.x * fz, dir.x * fy - dir.y * fx
	local det = ex * px + ey * py + ez * pz
	if math.abs( det ) < 1e-8 then return nil end
	local tx, ty, tz = origin.x - a.x, origin.y - a.y, origin.z - a.z
	local u = ( tx * px + ty * py + tz * pz ) / det
	if u < -1e-7 or u > 1.0000001 then return nil end
	local qx, qy, qz = ty * ez - tz * ey, tz * ex - tx * ez, tx * ey - ty * ex
	local v = ( dir.x * qx + dir.y * qy + dir.z * qz ) / det
	if v < -1e-7 or u + v > 1.0000001 then return nil end
	local t = ( fx * qx + fy * qy + fz * qz ) / det
	if t <= 0 then return nil end
	return t, ey * fz - ez * fy, ez * fx - ex * fz, ex * fy - ey * fx
end

function Query.Intersect( rec, origin, dir, opts, limit )
	opts = opts or {}
	local positions = Query.GetTriangles( rec )
	if not positions then return nil end
	local best = limit or opts.maxDistance or 80000
	local hit, normal
	for i = 1, #positions - 2, 3 do
		local t, nx, ny, nz = rayTriangle( origin, dir, positions[i], positions[i + 1], positions[i + 2] )
		if t and t < best then
			local z = origin.z + dir.z * t
			local visible = not opts.clipZ or ( opts.clipInvert and z >= opts.clipZ )
				or ( not opts.clipInvert and z <= opts.clipZ )
			local reference = rec.normal
			if positions.winding == -1 or ( not positions.winding
				and nx * reference.x + ny * reference.y + nz * reference.z < 0 ) then nx, ny, nz = -nx, -ny, -nz end
			local length = math.sqrt( nx * nx + ny * ny + nz * nz )
			local facing = nx * dir.x + ny * dir.y + nz * dir.z
			if visible and length > 1e-8 and ( opts.doubleSided or facing < -1e-8 )
				and ( not opts.minNormalZ or nz / length >= opts.minNormalZ ) then
				best, hit = t, origin + dir * t
				if facing > 0 then length = -length end
				normal = Vector( nx / length, ny / length, nz / length )
			end
		end
	end
	return hit, normal, hit and best or nil
end

function Query.Pick( grid, origin, dir, opts )
	if not grid then return nil end
	opts = opts or {}
	local distance = opts.maxDistance or 80000
	local bestPos, bestNormal, bestRec
	local epoch = grid:NewEpoch()
	local visited = grid.visited
	grid:TraverseRay( origin, dir, distance, function( cell, enteredAt )
		if bestRec and distance < enteredAt then return true end
		for i = 1, cell.n do
			local rec = cell.items[i]
			if visited[rec] ~= epoch then
				visited[rec] = epoch
				local allowed = ( not opts.zoneFilter or opts.zoneFilter( rec.zone ) )
					and ( not opts.recordFilter or opts.recordFilter( rec ) )
					and ( not opts.groundOnly or Query.IsGround( rec ) )
					and ( not opts.terrainOnly or rec.disp and Query.IsGround( rec ) )
				local box = allowed and Util.RayBox( origin, dir, rec.mins, rec.maxs )
				if box and box <= distance then
					local pos, normal, t = Query.Intersect( rec, origin, dir, opts, distance )
					if pos then bestPos, bestNormal, bestRec, distance = pos, normal, rec, t end
				end
			end
		end
	end )
	return bestPos, bestNormal, bestRec
end
