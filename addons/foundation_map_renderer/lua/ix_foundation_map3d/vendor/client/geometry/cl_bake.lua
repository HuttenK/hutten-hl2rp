-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Util = DM.Util
local Extract = DM.Extract
local Themes = DM.Themes
local Relief = DM.Relief

DM.Bake = DM.Bake or {}
local Bake = DM.Bake

if Bake.IsBusy and Bake.IsBusy() then
	hook.Add( "Think", "ix_ftmap_bake_reload_when_idle", function()
		if not Bake.IsBusy() then
			hook.Remove( "Think", "ix_ftmap_bake_reload_when_idle" )
			include( "ix_foundation_map3d/vendor/client/geometry/cl_bake.lua" )
		end
	end )
	return
end
local previous = Bake.CaptureRuntimeState and Bake.CaptureRuntimeState() or nil
local previousWorldMin, previousWorldMax
local previousMin, previousMax
if Bake.GetWorldBounds then previousWorldMin, previousWorldMax = Bake.GetWorldBounds() end
if Bake.GetBounds then previousMin, previousMax = Bake.GetBounds() end
local legacySurface = previous and previous.legacySurface or nil
if not previous and Bake.Ready then
	legacySurface = { HasSurfaceField = Bake.HasSurfaceField, PickSurface = Bake.PickSurface, GetSurfaceZ = Bake.GetSurfaceZ }
end

local MAX_TRIS_PER_MESH = 4000
local DEBOUNCE          = 0.2

local BUDGET_OVERLAY = 0.030
local BUDGET_CAP     = 0.002
local MIN_BUDGET     = 0.0008

Bake.Chunks   = Bake.Chunks or {}
Bake.Ready    = Bake.Ready or false
Bake.Version  = Bake.Version or 0
Bake.Stats    = Bake.Stats or { chunks = 0, meshes = 0, tris = 0, faces = 0, time = 0, props = 0 }

local SURFACE_CELL = 128
local SURFACE_PICK_CELL = 512

local surfaceField = previous and previous.surfaceField or {}
local surfaceReady = previous and previous.surfaceReady or false
local surfacePickGrid = previous and previous.surfacePickGrid or nil

local worldMins = previousWorldMin or Vector( -8192, -8192, -8192 )
local worldMaxs = previousWorldMax or Vector( 8192, 8192, 8192 )
local geometryBounds = { mins = previousMin or Vector( 0, 0, 0 ), maxs = previousMax or Vector( 0, 0, 0 ) }

local job = nil
local pending = previous and previous.pending or nil

function Bake.CaptureRuntimeState()
	return { surfaceField = surfaceField, surfaceReady = surfaceReady, surfacePickGrid = surfacePickGrid,
		legacySurface = legacySurface, pending = pending }
end

function Bake.IsReady() return Bake.Ready end
function Bake.IsBusy() return job ~= nil end
function Bake.GetJobName() return job and job.name or nil end

function Bake.GetBounds()
	if Bake.Ready then return geometryBounds.mins, geometryBounds.maxs end
	return worldMins, worldMaxs
end

function Bake.GetWorldBounds() return worldMins, worldMaxs end

local function surfaceKey( cx, cy )
	return ( cx + 32768 ) * 65536 + ( cy + 32768 )
end

local function addSurface( mins, maxs )
	local x0 = math.floor( mins.x / SURFACE_CELL )
	local x1 = math.floor( maxs.x / SURFACE_CELL )
	local y0 = math.floor( mins.y / SURFACE_CELL )
	local y1 = math.floor( maxs.y / SURFACE_CELL )

	if ( x1 - x0 ) > 40 or ( y1 - y0 ) > 40 then return end

	local top = maxs.z

	for cx = x0, x1 do
		for cy = y0, y1 do
			local key = surfaceKey( cx, cy )
			local current = surfaceField[key]

			if not current or top > current then surfaceField[key] = top end
		end
	end
end

function Bake.HasSurfaceField()
	if legacySurface then return legacySurface.HasSurfaceField() end
	return surfaceReady
end

function Bake.PickSurface( origin, dir, opts )
	if legacySurface then return legacySurface.PickSurface( origin, dir, opts ) end
	return DM.SurfaceQuery.Pick( surfacePickGrid, origin, dir, opts )
end

function Bake.QuerySurfaceRecords( mins, maxs, yield )
	return DM.SurfaceQuery.Collect( surfacePickGrid, mins, maxs, yield )
end

function Bake.GetSurfaceZ( x, y, radius )
	if legacySurface then return legacySurface.GetSurfaceZ( x, y, radius ) end
	if not surfaceReady then return nil end

	local cx = math.floor( x / SURFACE_CELL )
	local cy = math.floor( y / SURFACE_CELL )

	local direct = surfaceField[surfaceKey( cx, cy )]
	if direct then return direct end

	for r = 1, radius or 2 do
		local best = nil

		for dx = -r, r do
			for dy = -r, r do
				if math.abs( dx ) == r or math.abs( dy ) == r then
					local z = surfaceField[surfaceKey( cx + dx, cy + dy )]
					if z and ( not best or z > best ) then best = z end
				end
			end
		end

		if best then return best end
	end

	return nil
end

function Bake.GetCenter()
	local mins, maxs = Bake.GetBounds()
	return ( mins + maxs ) * 0.5
end

local function destroyChunks( chunks )
	if not chunks then return end

	for _, chunk in ipairs( chunks ) do
		for _, meshes in pairs( chunk.batches ) do
			for _, imesh in ipairs( meshes ) do
				if imesh and imesh.Destroy then imesh:Destroy() end
			end
		end

		for _, treeBatch in ipairs( chunk.treeBatches or {} ) do
			local imesh = treeBatch.mesh
			if imesh and imesh.Destroy then imesh:Destroy() end
		end

		for _, alphaPropBatch in ipairs( chunk.alphaPropBatches or {} ) do
			local imesh = alphaPropBatch.mesh
			if imesh and imesh.Destroy then imesh:Destroy() end
		end
	end
end

function Bake.Release()
	legacySurface = nil
	if DM.BakeCache then DM.BakeCache.Abort() end
	destroyChunks( Bake.Chunks )
	Bake.Chunks = {}
	Bake.Ready = false
	Bake.Stats = { chunks = 0, meshes = 0, tris = 0, faces = 0, time = 0, props = 0 }
end

hook.Add( "ShutDown", "ix_ftmap_bake_cleanup", function()
	Bake.Release()
end )

function Bake.RunJob( spec )
	if job then

		local cancelled = job
		job = nil

		if DM.BakeCache then DM.BakeCache.Abort() end
		DM.Msg( "cancelling job '", cancelled.name, "' for '", spec.name, "'" )
		if cancelled.onDone then cancelled.onDone( false ) end
	end

	local newJob = {
		name     = spec.name,
		title    = spec.title or "WORKING",
		kind     = spec.kind or "panel",
		onDone   = spec.onDone,
		progress = 0,
		status   = "",
		start    = SysTime(),
	}

	local function yielder( fraction, status )
		newJob.progress = Util.Clamp( fraction or 0, 0, 1 )
		if status then newJob.status = status end

		if SysTime() >= newJob.deadline then
			coroutine.yield()
		end
	end

	newJob.co = coroutine.create( function()
		spec.fn( yielder )
	end )

	job = newJob

	if newJob.kind ~= "silent" then
		DM.Loading.Show( newJob.kind, newJob.title )
	end
end

local function finishJob( errorMessage )
	local finished = job
	job = nil

	if finished and finished.kind ~= "silent" then
		DM.Loading.SetProgress( 1 )
		DM.Loading.Hide()
	end

	if errorMessage then
		if DM.BakeCache then DM.BakeCache.Abort() end
		DM.Warn( "job '", finished and finished.name or "?", "' failed at '",
			finished and finished.status or "?", "': ", errorMessage )
	end

	DM.lastError = errorMessage
	if finished and finished.onDone then
		finished.onDone( errorMessage == nil )
	end
end

hook.Add( "Think", "ix_ftmap_bake_step", function()
	if not DM.IsActive() then return end

	if pending and not job and SysTime() >= pending.at then
		local reason = pending.reason
		local forceRebuild = pending.force
		pending = nil
		Bake.Start( reason, forceRebuild )
	end

	if not job then return end

	local budget

	if DM.Loading.IsFullscreen() then
		budget = BUDGET_OVERLAY
	else
		local target = 1 / math.max( DM.Config.Get( "ix_ftmap_cl_bake_fps" ), 20 )
		budget = target - FrameTime()

		if budget > BUDGET_CAP then budget = BUDGET_CAP end
		if budget < MIN_BUDGET then budget = MIN_BUDGET end
	end

	job.deadline = SysTime() + budget

	job.steps = ( job.steps or 0 ) + 1
	if job.steps % 90 == 0 then collectgarbage( "step", 200 ) end

	local ok, err = coroutine.resume( job.co )

	if not ok then
		finishJob( tostring( err ) )
		return
	end

	if coroutine.status( job.co ) == "dead" then
		finishJob( nil )
		return
	end

	if job.kind ~= "silent" then
		DM.Loading.SetProgress( job.progress )
	end
end )

local function bucketRecords( records, cellSize, hidden, skipCeilings, yielder, renderZones )
	local buckets, order = {}, {}
	local CEILING = DM.SURFACE.CEILING

	for i = 1, #records do
		local rec = records[i]
		rec.zone = DM.MapData.RenderZoneIdAt( renderZones, rec.center )

		local skip = hidden[rec.id] or ( skipCeilings and rec.class == CEILING )

		if not skip then
			local cx = math.floor( rec.center.x / cellSize )
			local cy = math.floor( rec.center.y / cellSize )
			local key = cx .. ":" .. cy .. ":" .. rec.zone

			local bucket = buckets[key]
			if not bucket then
				bucket = {
					key = key, cx = cx, cy = cy, zone = rec.zone,
					mins = Vector( math.huge, math.huge, math.huge ),
					maxs = Vector( -math.huge, -math.huge, -math.huge ),
					byBatch = {},
				}
				buckets[key] = bucket
				order[#order + 1] = bucket
			end

			Util.ExpandBounds( bucket.mins, bucket.maxs, rec.mins )
			Util.ExpandBounds( bucket.mins, bucket.maxs, rec.maxs )

			local list = bucket.byBatch[rec.batch]
			if not list then
				list = {}
				bucket.byBatch[rec.batch] = list
			end
			list[#list + 1] = rec
		end

		if i % 5000 == 0 then yielder( 0.36, "grouping geometry" ) end
	end

	return order
end

local function buildTexturedBatchMeshes( records, batch, yielder, progress, cacheContext )
	local groups, order = {}, {}
	local isWater = batch == DM.BATCH.WATER

	for i = 1, #records do
		local rec = records[i]
		local materialName = rec.mat or ""
		local group = groups[materialName]

		if not group then
			group = { materialName = materialName, records = {}, useSourceTexture = true }
			groups[materialName] = group
			order[#order + 1] = group
		end

		if rec.translucent and not isWater then group.useSourceTexture = false end
		group.records[#group.records + 1] = rec
	end

	local translucent = batch == DM.BATCH.WATER or batch == DM.BATCH.GLASS
	local isRoad = batch == DM.BATCH.ROAD
	local meshes, materials, cacheMeshes = {}, {}, {}
	local totalTris = 0

	for groupIndex = 1, #order do
		local group = order[groupIndex]
		local cacheMaterialName = group.useSourceTexture and group.materialName or ""
		local material = isWater and DM.Assets.GetWaterMaterial( group.materialName ) or group.useSourceTexture
			and DM.Assets.GetMapTextureMaterial( group.materialName, translucent, translucent )
			or ( translucent and DM.Assets.WorldTranslucent or DM.Assets.World )
		local positions, texU, texV = {}, {}, {}
		local normals, tangents, bitangents = {}, {}, {}
		local count = 0

		local function flush()
			count = count - ( count % 3 )
			if count < 3 then
				count = 0
				return
			end

			local triangles = count / 3
			local imesh = Mesh( material )
			local cacheVertices = cacheContext and {} or nil

			mesh.Begin( imesh, MATERIAL_TRIANGLES, triangles )
			for vertexIndex = 1, count do
				local pos = positions[vertexIndex]
				local u, v = texU[vertexIndex], texV[vertexIndex]

				mesh.Position( pos )
				mesh.Color( 255, 255, 255, 255 )
				mesh.TexCoord( 0, u, v )
				if isWater then
					mesh.Normal( normals[vertexIndex] )
					mesh.TangentS( tangents[vertexIndex] )
					mesh.TangentT( bitangents[vertexIndex] )
				end
				mesh.AdvanceVertex()

				if cacheVertices then
					local offset = #cacheVertices
					cacheVertices[offset + 1] = pos.x
					cacheVertices[offset + 2] = pos.y
					cacheVertices[offset + 3] = pos.z
					cacheVertices[offset + 4] = 255
					cacheVertices[offset + 5] = 255
					cacheVertices[offset + 6] = 255
					cacheVertices[offset + 7] = 255
					cacheVertices[offset + 8] = u
					cacheVertices[offset + 9] = v
					if isWater then
						for i, vector in ipairs( { normals[vertexIndex], tangents[vertexIndex], bitangents[vertexIndex] } ) do
							cacheVertices[offset + 7 + i * 3] = vector.x
							cacheVertices[offset + 8 + i * 3] = vector.y
							cacheVertices[offset + 9 + i * 3] = vector.z
						end
					end
				end
			end
			mesh.End()

			meshes[#meshes + 1] = imesh
			materials[#materials + 1] = material
			totalTris = totalTris + triangles

			if cacheContext then
				local descriptor = DM.BakeCache.WriteMesh(
					cacheContext, cacheVertices, triangles, cacheMaterialName, isWater )
				if descriptor then cacheMeshes[#cacheMeshes + 1] = descriptor end
			end

			positions, texU, texV = {}, {}, {}
			normals, tangents, bitangents = {}, {}, {}
			count = 0
		end

		for recordIndex = 1, #group.records do
			local rec = group.records[recordIndex]
			local vertices = Extract.GetTriangles( rec )

			if vertices then
				local tangent, bitangent
				for vertexIndex = 1, #vertices do
					local vertex = vertices[vertexIndex]
					local pos = vertex.pos

					if pos then
						local u = tonumber( vertex.u ) or 0
						local v = tonumber( vertex.v ) or 0
						if u ~= u or math.abs( u ) > 1000000 then u = 0 end
						if v ~= v or math.abs( v ) > 1000000 then v = 0 end

						count = count + 1
						positions[count] = isRoad and Vector( pos.x, pos.y, pos.z + 0.35 ) or pos
						texU[count] = u
						texV[count] = v
						if isWater then
							local normal = vertex.normal or rec.normal
							if vertexIndex % 3 == 1 then
								tangent, bitangent = DM.Assets.GetWaterTangents(
									vertex, vertices[vertexIndex + 1], vertices[vertexIndex + 2], normal )
							end
							normals[count], tangents[count], bitangents[count] = normal, tangent, bitangent
						end

						if count >= MAX_TRIS_PER_MESH * 3 then flush() end
					end
				end
			end

			if recordIndex % 24 == 0 then yielder( progress, "building textured meshes" ) end
		end

		flush()
	end

	return meshes, totalTris, cacheMeshes, materials
end

local function buildBatchMeshes( records, theme, batch, doc, shading, yielder, progress, cacheContext )

	if DM.Config.Get( "ix_ftmap_cl_map_textures" )
		and batch ~= DM.BATCH.GLASS then
		return buildTexturedBatchMeshes( records, batch, yielder, progress, cacheContext )
	end

	local material = batch == DM.BATCH.WATER and DM.Assets.Water
		or ( batch == DM.BATCH.GLASS and DM.Assets.WorldTranslucent or DM.Assets.World )

	local zMin, zRange = shading.zMin, shading.zRange
	local intensity, invert = shading.intensity, shading.invert
	local faceStrength = shading.face

	local shadeLow, shadeHigh =
		Themes.AltitudeShade( theme, 0, intensity, invert ),
		Themes.AltitudeShade( theme, 1, intensity, invert )
	local shadeDelta = shadeHigh - shadeLow

	local meshes, cacheMeshes, meshCount = {}, {}, 0
	local totalTris = 0

	local bufPos = {}
	local bufR, bufG, bufB, bufA = {}, {}, {}, {}
	local n = 0

	local isRoad = batch == DM.BATCH.ROAD
	local isWater = batch == DM.BATCH.WATER

	local function flush()
		if n < 3 then
			n = 0
			return
		end

		local triangles = math.floor( n / 3 )
		local imesh = Mesh( material )

		mesh.Begin( imesh, MATERIAL_TRIANGLES, triangles )
		for i = 1, triangles * 3 do
			local pos = bufPos[i]

			mesh.Position( pos )
			mesh.Color( bufR[i], bufG[i], bufB[i], bufA[i] )

			mesh.TexCoord( 0, 0, 0 )

			mesh.AdvanceVertex()
		end
		mesh.End()

		meshCount = meshCount + 1
		meshes[meshCount] = imesh
		totalTris = totalTris + triangles

		if cacheContext then
			local vertices = {}

			for i = 1, triangles * 3 do
				local pos = bufPos[i]
				local offset = ( i - 1 ) * 9
				vertices[offset + 1] = pos.x
				vertices[offset + 2] = pos.y
				vertices[offset + 3] = pos.z
				vertices[offset + 4] = bufR[i]
				vertices[offset + 5] = bufG[i]
				vertices[offset + 6] = bufB[i]
				vertices[offset + 7] = bufA[i]
				vertices[offset + 8] = 0
				vertices[offset + 9] = 0
			end

			local descriptor = DM.BakeCache.WriteMesh( cacheContext, vertices, triangles )
			if descriptor then cacheMeshes[#cacheMeshes + 1] = descriptor end
		end

		n = 0
	end

	local faceColors = doc.faceColors
	local faceTints  = doc.faceTints
	local materialColours = DM.Config.Get( "ix_ftmap_cl_material_colours" ) and not isWater and batch ~= DM.BATCH.GLASS
	local baseR, baseG, baseB, baseA
	local blendR, blendG, blendB, vertexBlend, useMaterialColour

	local function emitVertex( pos, light, weight )
		local altitude = math.Clamp( ( pos.z - zMin ) / zRange, 0, 1 )
		local shade = isWater and 1 or ( shadeLow + shadeDelta * altitude ) * light
		if useMaterialColour then

			local ramp = 1 + ( altitude - 0.5 ) * intensity * ( invert and -0.35 or 0.35 )
			shade = math.Clamp( ramp * light, 0.62, 1.05 )
		end
		local r, g, b = baseR, baseG, baseB
		if weight then
			r, g, b = r + ( blendR - r ) * weight, g + ( blendG - g ) * weight, b + ( blendB - b ) * weight
		end
		n = n + 1
		bufPos[n] = isRoad and Vector( pos.x, pos.y, pos.z + 0.35 ) or pos
		bufR[n] = math.min( r * shade, 255 )
		bufG[n] = math.min( g * shade, 255 )
		bufB[n] = math.min( b * shade, 255 )
		bufA[n] = isWater and 255 or baseA
	end

	local function emitTriangle( a, b, c, lightA, lightB, lightC, index )
		local wa, wb, wc
		if vertexBlend then
			wa = math.Clamp( ( vertexBlend[index].color.a or 0 ) / 255, 0, 1 )
			wb = math.Clamp( ( vertexBlend[index + 1].color.a or 0 ) / 255, 0, 1 )
			wc = math.Clamp( ( vertexBlend[index + 2].color.a or 0 ) / 255, 0, 1 )
		end
		emitVertex( a, lightA, wa )
		emitVertex( b, lightB, wb )
		emitVertex( c, lightC, wc )
		if n >= MAX_TRIS_PER_MESH * 3 then
			flush()
			yielder( progress, "building meshes" )
		end
	end

	for r = 1, #records do
		local rec = records[r]
		local sourceColour = materialColours and not faceColors[rec.id] and DM.Assets.GetSurfaceColour( rec.mat )
		local secondColour = sourceColour and rec.disp and DM.Assets.GetSurfaceBlendColour( rec.mat )
		useMaterialColour = sourceColour ~= nil and sourceColour ~= false
		vertexBlend = secondColour and Extract.GetTriangles( rec ) or nil
		local tris
		if vertexBlend then
			tris = {}
			for i = 1, #vertexBlend do tris[i] = vertexBlend[i].pos end
		else
			tris = Extract.GetTrianglePositions( rec )
		end

		if tris then
			baseR, baseG, baseB, baseA = Themes.ResolveFaceBase(
				theme, rec.class, faceTints[rec.id], faceColors[rec.id]
					or sourceColour )
			if sourceColour then
				local tint = 1 + ( faceTints[rec.id] or 0 )
				baseR, baseG, baseB = sourceColour.r * tint, sourceColour.g * tint, sourceColour.b * tint
				if secondColour then
					blendR, blendG, blendB = secondColour.r * tint, secondColour.g * tint, secondColour.b * tint
				end
			end

			local perTriangle = rec.disp
			local terrain = Relief.IsTerrain( rec )
			local faceMul = perTriangle and 1 or Themes.FaceShade( rec.normal, faceStrength )
			if useMaterialColour then faceMul = 1 + ( faceMul - 1 ) * 0.6 end

			for i = 1, #tris - 2, 3 do
				local p1, p2, p3 = tris[i], tris[i + 1], tris[i + 2]

				if p1 and p2 and p3 then
					local mul = faceMul
					local normal = rec.normal

					if perTriangle or terrain then
						normal = Relief.TriangleNormal( p1, p2, p3, rec.normal )
						mul = Themes.FaceShade( normal, faceStrength )
						if useMaterialColour then mul = 1 + ( mul - 1 ) * 0.6 end
					end

					if terrain then
						local lightA = Relief.Shade( Relief.VertexNormal( shading.normals, p1, normal ), faceStrength )
						local lightB = Relief.Shade( Relief.VertexNormal( shading.normals, p2, normal ), faceStrength )
						local lightC = Relief.Shade( Relief.VertexNormal( shading.normals, p3, normal ), faceStrength )
						emitTriangle( p1, p2, p3, lightA, lightB, lightC, i )
					else
						emitTriangle( p1, p2, p3, mul, mul, mul, i )
					end
				end
			end

		end

		if r % 24 == 0 then yielder( progress, "building meshes" ) end
	end

	n = n - ( n % 3 )
	flush()

	return meshes, totalTris, cacheMeshes
end

local function buildSurfaceIndex( records, doc, skipCeilings, yielder, progress )
	legacySurface = nil
	surfaceField = {}
	surfaceReady = false

	local grid = DM.Spatial.New( SURFACE_PICK_CELL )

	for i = 1, #records do
		local rec = records[i]

		if not doc.hidden[rec.id] then
			addSurface( rec.mins, rec.maxs )

			if not ( skipCeilings and rec.class == DM.SURFACE.CEILING ) then
				grid:Insert( rec, rec.mins, rec.maxs )
			end
		end

		if i % 1200 == 0 then yielder( progress or 0, "mapping surfaces" ) end
	end

	return grid
end

local function bakeBody( yielder, forceRebuild )
	local started = SysTime()

	if forceRebuild then Extract.Release() end

	local doc = DM.MapData.Clone( DM.MapData.Get() )
	local fingerprint = DM.MapData.Fingerprint( doc )
	local theme = Themes.Get( "standard" )
	local cellSize = DM.Config.Get( "ix_ftmap_cl_chunk_size" )
	local skipCeilings = DM.Config.Get( "ix_ftmap_cl_skip_ceilings" )

	worldMins, worldMaxs = Extract.GetWorldBounds()

	local shading = {
		zMin      = worldMins.z,
		zRange    = math.max( worldMaxs.z - worldMins.z, 1 ),
		intensity = DM.Config.Get( "ix_ftmap_sv_height_shading" ),
		invert    = DM.Config.Get( "ix_ftmap_sv_height_invert" ),
		face      = DM.Config.Get( "ix_ftmap_sv_face_shading" ),
	}

	if not forceRebuild then
		yielder( 0, "checking baked cache" )

		local cached = DM.BakeCache.Load( doc, function( fraction, status )
			yielder( fraction * 0.72, status )
		end )

		if cached then
			worldMins, worldMaxs = cached.worldMins, cached.worldMaxs
			shading.zMin = worldMins.z
			shading.zRange = math.max( worldMaxs.z - worldMins.z, 1 )

			local records = cached.records
			Extract.RestoreIndex( records, {
				mins = cached.geometryMins,
				maxs = cached.geometryMaxs,
			} )

			local newSurfacePickGrid = buildSurfaceIndex(
				records, doc, skipCeilings, yielder, 0.76 )

			for i = 1, #cached.propSurfaces do
				local bounds = cached.propSurfaces[i]
				addSurface( bounds.mins, bounds.maxs )
				if i % 1000 == 0 then yielder( 0.94, "restoring prop surfaces" ) end
			end

			DM.Props.Build( doc, theme, worldMins, worldMaxs, shading.invert, function( fraction, status )
				yielder( 0.94 + fraction * 0.05, status )
			end )

			destroyChunks( Bake.Chunks )
			Bake.Chunks = cached.chunks
			geometryBounds.mins = cached.geometryMins
			geometryBounds.maxs = cached.geometryMaxs
			surfacePickGrid = newSurfacePickGrid
			surfaceReady = true

			Bake.Stats = cached.stats
			Bake.Stats.time = SysTime() - started
			Bake.Stats.cached = true
			Bake.Ready = true
			Bake.Version = Bake.Version + 1
			Bake.Fingerprint = fingerprint

			yielder( 1, "" )
			DM.Msg( string.format( "loaded baked map cache in %.2fs: %d chunks, %d triangles",
				Bake.Stats.time, Bake.Stats.chunks or #Bake.Chunks, Bake.Stats.tris or 0 ) )
			hook.Run( "IXFoundationMapBaked", Bake.Stats )
			return
		end
	end

	local cacheContext = DM.BakeCache.Begin( doc )

	yielder( 0, "reading geometry" )

	local records = Extract.GetIndex()

	if not records or Extract.IsStale() then
		records = Extract.BuildIndex( doc, { autoRoad = false }, function( fraction, status )
			yielder( fraction * 0.34, status )
		end )
	end

	yielder( 0.35, "grouping geometry" )

	local buckets = bucketRecords( records, cellSize, doc.hidden, skipCeilings, yielder, doc.renderZones )

	local newSurfacePickGrid = buildSurfaceIndex( records, doc, skipCeilings, yielder, 0.38 )
	if not DM.Config.Get( "ix_ftmap_cl_map_textures" ) then
		if DM.Config.Get( "ix_ftmap_cl_material_colours" ) then DM.Assets.PrepareSurfaceColours( yielder ) end
		shading.normals = Relief.BuildNormals( records, doc.hidden, yielder )
	end

	local newChunks = {}
	local totalTris, totalMeshes = 0, 0
	local bucketCount = math.max( #buckets, 1 )

	for b = 1, #buckets do
		local bucket = buckets[b]
		local progress = 0.4 + ( b / bucketCount ) * 0.3

		local chunk = {
			key       = bucket.key,
			mins      = bucket.mins,
			maxs      = bucket.maxs,
			center    = ( bucket.mins + bucket.maxs ) * 0.5,
			radius    = bucket.mins:Distance( bucket.maxs ) * 0.5,
			zone      = bucket.zone,
			batches   = {},
			batchMaterials = {},
			batchTris = {},
			tris      = 0,
		}

		for batch, list in pairs( bucket.byBatch ) do
			local meshes, tris, cacheMeshes, materials = buildBatchMeshes( list, theme, batch, doc,
				shading, yielder, progress, cacheContext )

			if #meshes > 0 then
				chunk.batches[batch] = meshes
				if materials then chunk.batchMaterials[batch] = materials end
				chunk.batchTris[batch] = tris
				chunk.cacheBatches = chunk.cacheBatches or {}
				chunk.cacheBatches[batch] = cacheMeshes
				chunk.tris = chunk.tris + tris
				totalTris = totalTris + tris
				totalMeshes = totalMeshes + #meshes
			end
		end

		if next( chunk.batches ) then
			newChunks[#newChunks + 1] = chunk
		end

		yielder( progress, "building meshes" )
	end

	shading.normals = nil
	yielder( 0.72, "measuring props" )

	DM.Props.Build( doc, theme, worldMins, worldMaxs, shading.invert, function( fraction, status )
		yielder( 0.72 + fraction * 0.1, status )
	end )

	local propList = DM.Props.GetAll()
	local propSurfaces = {}

	for i = 1, #propList do
		local rec = propList[i]

		if not rec.tree then
			addSurface( rec.mins, rec.maxs )
			propSurfaces[#propSurfaces + 1] = {
				mins = rec.mins,
				maxs = rec.maxs,
			}
		end
	end

	surfaceReady = true

	yielder( 0.98, "finalising" )

	destroyChunks( Bake.Chunks )
	Bake.Chunks = newChunks

	local mins = Vector( math.huge, math.huge, math.huge )
	local maxs = Vector( -math.huge, -math.huge, -math.huge )

	for _, chunk in ipairs( newChunks ) do
		Util.ExpandBounds( mins, maxs, chunk.mins )
		Util.ExpandBounds( mins, maxs, chunk.maxs )
	end
	for _, rec in ipairs( propList ) do
		Util.ExpandBounds( mins, maxs, rec.mins )
		Util.ExpandBounds( mins, maxs, rec.maxs )
	end

	if #newChunks == 0 and #propList == 0 then
		mins, maxs = Util.CopyVector( worldMins ), Util.CopyVector( worldMaxs )
	end

	geometryBounds.mins, geometryBounds.maxs = mins, maxs

	Bake.Stats = {
		chunks = #newChunks,
		meshes = totalMeshes,
		tris   = totalTris,
		faces  = #records,
		props  = DM.Props.Count(),
		time   = SysTime() - started,
	}

	local cached = DM.BakeCache.Save( cacheContext, newChunks, records, {
		worldMins = worldMins,
		worldMaxs = worldMaxs,
		geometryMins = mins,
		geometryMaxs = maxs,
		propSurfaces = propSurfaces,
		stats = Bake.Stats,
	} )

	for _, chunk in ipairs( newChunks ) do
		chunk.cacheBatches = nil
	end

	if not cached then
		DM.Warn( "the map was baked, but its persistent cache could not be saved" )
	end

	Bake.Ready = true
	Bake.Version = Bake.Version + 1
	Bake.Fingerprint = fingerprint
	surfacePickGrid = newSurfacePickGrid

	yielder( 1, "" )

	DM.Msg( string.format( "baked in %.2fs: %d chunks, %d meshes, %d triangles, %d props",
		Bake.Stats.time, Bake.Stats.chunks, Bake.Stats.meshes, Bake.Stats.tris, Bake.Stats.props ) )

	hook.Run( "IXFoundationMapBaked", Bake.Stats )
end

function Bake.Start( reason, forceRebuild )
	if not NikNaks.CurrentMap then
		DM.Warn( "cannot bake: the BSP could not be read" )
		return
	end

	local useCache = not forceRebuild and DM.BakeCache.Has( DM.MapData.Get() )

	DM.Msg( useCache and "loading minimap cache (" or "baking minimap (", reason or "manual", ")" )
	Bake.RunJob{
		name  = "bake",
		title = useCache and "LOADING MAP" or "GENERATING MAP",
		kind  = "panel",
		fn    = function( yielder )
			bakeBody( yielder, forceRebuild )
		end,
	}
end

function Bake.Request( reason, forceRebuild )
	pending = {
		reason = reason or "requested",
		force = forceRebuild == true,
		at = SysTime() + DEBOUNCE,
	}
end

