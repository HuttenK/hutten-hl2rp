-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D

DM.BakeCache = DM.BakeCache or {}
local Cache = DM.BakeCache

local FORMAT_VERSION = 23
local ROOT = "ix_foundation_map3d/vendor/bake_cache_v23"
local MESH_FILE = "meshes.dat"
local VERTEX_BYTES = 24
local WATER_VERTEX_BYTES = 60
local activeContext = nil

local function vec( value )
	return { value.x, value.y, value.z }
end

local function toVector( value )
	return Vector( value[1] or 0, value[2] or 0, value[3] or 0 )
end

local function cacheSignature( doc )
	local parts = {
		FORMAT_VERSION,
		game.GetMap(),
		DM.MapData.GetMapRevision(),
		DM.MapData.Fingerprint( doc ),
		DM.Config.Get( "ix_ftmap_sv_theme" ),
		DM.Config.Get( "ix_ftmap_sv_prop_lod" ),
		DM.Config.Get( "ix_ftmap_sv_foliage" ) and 1 or 0,
		DM.Config.Get( "ix_ftmap_sv_height_shading" ),
		DM.Config.Get( "ix_ftmap_sv_height_invert" ) and 1 or 0,
		DM.Config.Get( "ix_ftmap_sv_face_shading" ),
		DM.Config.Get( "ix_ftmap_cl_skip_ceilings" ) and 1 or 0,
		DM.Config.Get( "ix_ftmap_cl_chunk_size" ),
		DM.Config.Get( "ix_ftmap_cl_map_textures" ) and 1 or 0,
		DM.Config.Get( "ix_ftmap_cl_material_colours" ) and 1 or 0,
	}
	if #doc.renderZones > 0 then parts[#parts + 1] = "render-zones-2" end

	return util.CRC( table.concat( parts, "|" ) )
end

local function folderFor( doc )
	local map = string.gsub( string.lower( game.GetMap() or "unknown" ), "[^%w_%-]", "_" )
	local signature = cacheSignature( doc )
	return ROOT .. "/" .. map .. "/" .. signature, signature, ROOT .. "/" .. map
end

function Cache.Begin( doc )
	Cache.Abort()

	local folder, signature, mapFolder = folderFor( doc )
	file.CreateDir( ROOT )
	file.CreateDir( mapFolder )
	file.CreateDir( folder )
	file.Delete( folder .. "/manifest.dat" )
	file.Delete( folder .. "/" .. MESH_FILE )

	local meshFile = file.Open( folder .. "/" .. MESH_FILE, "wb", "DATA" )

	local context = {
		folder = folder,
		mapFolder = mapFolder,
		signature = signature,
		nextMesh = 0,
		meshOffset = 0,
		meshFile = meshFile,
		failed = meshFile == nil,
	}

	activeContext = context
	return context
end

function Cache.Has( doc )
	local folder = folderFor( doc )
	return file.Exists( folder .. "/manifest.dat", "DATA" )
end

function Cache.WriteMesh( context, vertices, triangles, materialName, waterBasis )
	if not context or context.failed or not context.meshFile or triangles <= 0 then return nil end

	context.nextMesh = context.nextMesh + 1
	local vertexCount = triangles * 3
	local stride = waterBasis and 18 or 9
	local expectedValues = vertexCount * stride

	if type( vertices ) ~= "table" or #vertices < expectedValues then
		context.failed = true
		return nil
	end

	local meshFile = context.meshFile
	local offset = context.meshOffset

	for vertex = 0, vertexCount - 1 do
		local valueOffset = vertex * stride

		meshFile:WriteFloat( tonumber( vertices[valueOffset + 1] ) or 0 )
		meshFile:WriteFloat( tonumber( vertices[valueOffset + 2] ) or 0 )
		meshFile:WriteFloat( tonumber( vertices[valueOffset + 3] ) or 0 )

		local red = math.max( 0, math.min(
			math.floor( ( tonumber( vertices[valueOffset + 4] ) or 255 ) + 0.5 ), 255 ) )
		local green = math.max( 0, math.min(
			math.floor( ( tonumber( vertices[valueOffset + 5] ) or 255 ) + 0.5 ), 255 ) )
		local blue = math.max( 0, math.min(
			math.floor( ( tonumber( vertices[valueOffset + 6] ) or 255 ) + 0.5 ), 255 ) )
		local alpha = math.max( 0, math.min(
			math.floor( ( tonumber( vertices[valueOffset + 7] ) or 255 ) + 0.5 ), 255 ) )
		local colour = bit.bor(
			red,
			bit.lshift( green, 8 ),
			bit.lshift( blue, 16 ),
			bit.lshift( alpha, 24 )
		)
		if colour < 0 then colour = colour + 4294967296 end
		meshFile:WriteULong( colour )

		meshFile:WriteFloat( tonumber( vertices[valueOffset + 8] ) or 0 )
		meshFile:WriteFloat( tonumber( vertices[valueOffset + 9] ) or 0 )
		if waterBasis then
			for i = 10, 18 do meshFile:WriteFloat( vertices[valueOffset + i] ) end
		end
	end

	local bytes = vertexCount * ( waterBasis and WATER_VERTEX_BYTES or VERTEX_BYTES )
	context.meshOffset = offset + bytes

	return {
		offset = offset,
		bytes = bytes,
		tris = triangles,
		material = materialName,
		waterBasis = waterBasis or nil,
	}
end

function Cache.Abort( context )
	context = context or activeContext
	if not context then return end

	if context.meshFile then
		context.meshFile:Close()
		context.meshFile = nil
	end

	if activeContext == context then activeContext = nil end
end

local function encodeRecords( records )
	local packed = {}

	for i = 1, #records do
		local rec = records[i]
		packed[i] = {
			id = rec.id,
			class = rec.class,
			batch = rec.batch,
			mins = vec( rec.mins ),
			maxs = vec( rec.maxs ),
			center = vec( rec.center ),
			normal = vec( rec.normal ),
			nz = rec.nz,
			mat = rec.mat,
			disp = rec.disp and 1 or 0,
			translucent = rec.translucent and 1 or 0,
			bmodel = rec.bmodel,
			zone = rec.zone,
			roof = rec.roof and 1 or 0,
		}
	end

	return packed
end

local function encodeChunk( chunk )
	local batches = {}

	for batch, descriptors in pairs( chunk.cacheBatches or {} ) do
		batches[tostring( batch )] = descriptors
	end

	return {
		key = chunk.key,
		mins = vec( chunk.mins ),
		maxs = vec( chunk.maxs ),
		center = vec( chunk.center ),
		radius = chunk.radius,

		zone = chunk.zone,
		tris = chunk.tris,
		batchTris = chunk.batchTris,
		batches = batches,

	}
end

local function encodeBounds( bounds )
	local packed = {}

	for i = 1, #( bounds or {} ) do
		packed[i] = {
			mins = vec( bounds[i].mins ),
			maxs = vec( bounds[i].maxs ),
		}
	end

	return packed
end

local function decodeBounds( packed )
	local bounds = {}

	for i = 1, #( packed or {} ) do
		bounds[i] = {
			mins = toVector( packed[i].mins ),
			maxs = toVector( packed[i].maxs ),
		}
	end

	return bounds
end

local function pruneOtherVersions( context )
	local _, folders = file.Find( context.mapFolder .. "/*", "DATA" )

	for _, folder in ipairs( folders or {} ) do
		if folder ~= context.signature then
			local oldPath = context.mapFolder .. "/" .. folder
			local files = file.Find( oldPath .. "/*", "DATA" )

			for _, name in ipairs( files or {} ) do
				file.Delete( oldPath .. "/" .. name )
			end

			file.Delete( oldPath )
		end
	end
end

function Cache.Save( context, chunks, records, state )
	if not context then return false end

	Cache.Abort( context )
	if context.failed then return false end
	if file.Size( context.folder .. "/" .. MESH_FILE, "DATA" ) ~= context.meshOffset then return false end

	local recordJson = util.TableToJSON( {
		records = encodeRecords( records ),
	} )

	if not recordJson then return false end

	file.Write( context.folder .. "/records.dat", util.Compress( recordJson ) or recordJson )
	if file.Size( context.folder .. "/records.dat", "DATA" ) <= 0 then return false end

	local packedChunks = {}
	for i = 1, #chunks do packedChunks[i] = encodeChunk( chunks[i] ) end

	local manifest = {
		version = FORMAT_VERSION,
		signature = context.signature,
		map = game.GetMap(),
		worldMins = vec( state.worldMins ),
		worldMaxs = vec( state.worldMaxs ),
		geometryMins = vec( state.geometryMins ),
		geometryMaxs = vec( state.geometryMaxs ),
		stats = state.stats,
		propSurfaces = encodeBounds( state.propSurfaces ),
		chunks = packedChunks,
	}

	local manifestJson = util.TableToJSON( manifest )
	if not manifestJson then return false end

	file.Write( context.folder .. "/manifest.dat", util.Compress( manifestJson ) or manifestJson )
	if file.Size( context.folder .. "/manifest.dat", "DATA" ) <= 0 then return false end

	pruneOtherVersions( context )
	return true
end

local function readTable( path )
	local payload = file.Read( path, "DATA" )
	if not payload or payload == "" then return nil end

	local json = util.Decompress( payload ) or payload

	return util.JSONToTable( json, true )
end

local function decodeMesh( meshFile, descriptor, material )
	local triangles = tonumber( descriptor.tris ) or 0
	local offset = tonumber( descriptor.offset )
	local bytes = tonumber( descriptor.bytes ) or 0
	local expectedBytes = triangles * 3 * ( descriptor.waterBasis and WATER_VERTEX_BYTES or VERTEX_BYTES )

	if triangles <= 0 or not offset or bytes ~= expectedBytes
		or offset < 0 or offset + bytes > meshFile:Size() then
		return nil
	end

	local imesh = Mesh( material )
	local position = Vector()
	meshFile:Seek( offset )

	mesh.Begin( imesh, MATERIAL_TRIANGLES, triangles )
	for _ = 1, triangles * 3 do
		position.x = meshFile:ReadFloat()
		position.y = meshFile:ReadFloat()
		position.z = meshFile:ReadFloat()
		mesh.Position( position )
		local colour = meshFile:ReadULong()
		mesh.Color(
			bit.band( colour, 0xFF ),
			bit.band( bit.rshift( colour, 8 ), 0xFF ),
			bit.band( bit.rshift( colour, 16 ), 0xFF ),
			bit.band( bit.rshift( colour, 24 ), 0xFF )
		)
		mesh.TexCoord( 0, meshFile:ReadFloat(), meshFile:ReadFloat() )
		if descriptor.waterBasis then
			mesh.Normal( Vector( meshFile:ReadFloat(), meshFile:ReadFloat(), meshFile:ReadFloat() ) )
			mesh.TangentS( meshFile:ReadFloat(), meshFile:ReadFloat(), meshFile:ReadFloat() )
			mesh.TangentT( meshFile:ReadFloat(), meshFile:ReadFloat(), meshFile:ReadFloat() )
		end
		mesh.AdvanceVertex()
	end
	mesh.End()

	return imesh
end

local function decodeRecords( packed )
	local records = {}

	for i = 1, #( packed or {} ) do
		local rec = packed[i]
		records[i] = {
			id = tonumber( rec.id ) or 0,
			class = tonumber( rec.class ) or 0,
			batch = tonumber( rec.batch ) or 0,
			mins = toVector( rec.mins ),
			maxs = toVector( rec.maxs ),
			center = toVector( rec.center ),
			normal = toVector( rec.normal ),
			nz = tonumber( rec.nz ) or 0,
			mat = rec.mat or "",
			disp = rec.disp == 1,
			translucent = rec.translucent == 1,
			bmodel = tonumber( rec.bmodel ) or 0,
			zone = tonumber( rec.zone ) or 0,
			roof = rec.roof == 1,
		}
	end

	return records
end

local function destroyLoaded( chunks )
	for _, chunk in ipairs( chunks ) do
		for _, meshes in pairs( chunk.batches ) do
			for _, imesh in ipairs( meshes ) do
				if imesh and imesh.Destroy then imesh:Destroy() end
			end
		end
	end
end

function Cache.Load( doc, yielder )
	yielder = yielder or function() end

	local folder, signature = folderFor( doc )
	local manifest = readTable( folder .. "/manifest.dat" )

	if not manifest or manifest.version ~= FORMAT_VERSION or manifest.signature ~= signature
		or manifest.map ~= game.GetMap() then
		return nil
	end

	local recordPack = readTable( folder .. "/records.dat" )
	if not recordPack or type( recordPack.records ) ~= "table" then return nil end

	local stats = manifest.stats
	if type( stats ) ~= "table" or #recordPack.records ~= stats.faces
		or type( manifest.chunks ) ~= "table" or #manifest.chunks ~= stats.chunks then
		DM.Warn( "incomplete minimap cache; rebuilding from the BSP" )
		return nil
	end

	local meshFile = file.Open( folder .. "/" .. MESH_FILE, "rb", "DATA" )
	if not meshFile then return nil end

	local chunks = {}
	local sourceChunks = manifest.chunks or {}
	local totalMeshes = 0

	for i = 1, #sourceChunks do
		for batch, descriptors in pairs( sourceChunks[i].batches or {} ) do
			if tonumber( batch ) ~= DM.BATCH.PROP and tonumber( batch ) ~= DM.BATCH.PROP_COARSE then
				totalMeshes = totalMeshes + #descriptors
			end
		end
	end

	local loadedMeshes = 0

	for i = 1, #sourceChunks do
		local packed = sourceChunks[i]
		local chunk = {
			key = type( packed.key ) == "string" and packed.key or tonumber( packed.key ) or 0,
			mins = toVector( packed.mins ),
			maxs = toVector( packed.maxs ),
			center = toVector( packed.center ),
			radius = tonumber( packed.radius ) or 0,

			zone = tonumber( packed.zone ) or 0,
			tris = tonumber( packed.tris ) or 0,
			batches = {},
			batchMaterials = {},
			batchTris = {},

		}

		for batchName, descriptors in pairs( packed.batches or {} ) do
			local batch = tonumber( batchName )
			if batch == DM.BATCH.PROP or batch == DM.BATCH.PROP_COARSE then descriptors = {} end
			local meshes = {}
			local materials = {}
			local translucent = batch == DM.BATCH.WATER or batch == DM.BATCH.GLASS
			local texturedBatch = DM.Config.Get( "ix_ftmap_cl_map_textures" )
				and batch ~= DM.BATCH.GLASS

			for descriptorIndex = 1, #descriptors do
				local descriptor = descriptors[descriptorIndex]
				local material

				if texturedBatch and batch == DM.BATCH.WATER then
					material = DM.Assets.GetWaterMaterial( descriptor.material )
				elseif texturedBatch then
					material = DM.Assets.GetMapTextureMaterial(
						descriptor.material, translucent, translucent )
				else
					material = translucent and DM.Assets.WorldTranslucent or DM.Assets.World
				end

				local imesh = decodeMesh( meshFile, descriptors[descriptorIndex], material )
				if not imesh then
					meshFile:Close()
					destroyLoaded( chunks )
					destroyLoaded( { chunk } )
					return nil
				end

				meshes[#meshes + 1] = imesh
				materials[#materials + 1] = material
				loadedMeshes = loadedMeshes + 1
				yielder( loadedMeshes / math.max( totalMeshes, 1 ), "loading baked map" )
			end

			chunk.batches[batch] = meshes
			if texturedBatch then
				chunk.batchMaterials[batch] = materials
			end
		end

		for batch, triangles in pairs( packed.batchTris or {} ) do
			local id = tonumber( batch )
			if id ~= DM.BATCH.PROP and id ~= DM.BATCH.PROP_COARSE then
				chunk.batchTris[id] = tonumber( triangles ) or 0
			end
		end

		chunks[#chunks + 1] = chunk
	end

	meshFile:Close()

	return {
		chunks = chunks,
		records = decodeRecords( recordPack.records ),
		worldMins = toVector( manifest.worldMins ),
		worldMaxs = toVector( manifest.worldMaxs ),
		geometryMins = toVector( manifest.geometryMins ),
		geometryMaxs = toVector( manifest.geometryMaxs ),
		propSurfaces = decodeBounds( manifest.propSurfaces ),
		stats = manifest.stats or {},
	}
end
