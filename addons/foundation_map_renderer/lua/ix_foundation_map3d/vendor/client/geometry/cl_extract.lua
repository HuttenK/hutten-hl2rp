-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Util = DM.Util
local SURFACE, BATCH, SURF = DM.SURFACE, DM.BATCH, DM.SURF

DM.Extract = DM.Extract or {}
local Extract = DM.Extract

local string_find, string_lower = string.find, string.lower
local math_max, math_floor = math.max, math.floor

local SKIP_MATERIALS = {
	"tools/", "trigger", "clip", "hint", "skip", "nodraw", "invisible",
	"skybox", "sky_", "black_outside", "measure", "origin",
}

local WATER_MATERIALS = {
	"water", "slime", "lava", "liquid", "swamp", "ocean", "sea", "river",
	"lake", "wave", "pool",
}
local GLASS_MATERIALS = { "glass", "window", "transparent", "translucent" }

local ROAD_MATERIALS = {
	"road", "asphalt", "tarmac", "pavement", "sidewalk", "street", "highway",
	"curb", "cobble",
}

local CLASS_MATERIALS = {
	{ class = "SNOW",     words = { "snow", "ice", "frost", "glacier" } },
	{ class = "SAND",     words = { "sand", "beach", "dune", "desert" } },
	{ class = "GRASS",    words = { "grass", "moss", "leaf", "leaves", "forest", "field",
									"jungle", "foliage", "hedge", "nature/blend", "meadow" } },
	{ class = "DIRT",     words = { "dirt", "mud", "soil", "earth", "gravel", "path",
									"farmland", "ground" } },
	{ class = "ROCK",     words = { "rock", "cliff", "stone", "slate", "granite", "mountain",
									"quarry", "boulder", "cave" } },
	{ class = "WOOD",     words = { "wood", "plank", "timber", "lumber", "log", "fence",
									"shingle", "bark", "crate" } },
	{ class = "BRICK",    words = { "brick", "tile", "cobblestone", "masonry", "roof" } },
	{ class = "CONCRETE", words = { "concrete", "cement", "plaster", "stucco", "sidewalk_",
									"building", "wall" } },
	{ class = "METAL",    words = { "metal", "steel", "iron", "rust", "grate", "pipe",
									"vent", "alum", "chrome", "corrugated" } },
}

local function matchAny( haystack, list )
	for i = 1, #list do
		if string_find( haystack, list[i], 1, true ) then return true end
	end
	return false
end

local function materialClass( matName )
	for i = 1, #CLASS_MATERIALS do
		local entry = CLASS_MATERIALS[i]
		if matchAny( matName, entry.words ) then return SURFACE[entry.class] end
	end
	return nil
end

Extract.RoadMaterials = ROAD_MATERIALS

local HEIGHTFIELD_CELL = 256
local ROOF_THRESHOLD   = 190
local HORIZONTAL_DOT   = 0.7
local FACES_PER_YIELD  = 900

local HEIGHTFIELD_MAX_CELLS = 64

local ROOF_ELIGIBLE = {}

for class in pairs( DM.SURFACE_HORIZONTAL ) do
	if class ~= SURFACE.ROAD and class ~= SURFACE.WATER and class ~= SURFACE.ROOF then
		ROOF_ELIGIBLE[class] = true
	end
end

local function cellKey( cx, cy )
	return ( cx + 32768 ) * 65536 + ( cy + 32768 )
end

local function stampFloor( field, mins, maxs, z )
	local x0 = math_floor( mins.x / HEIGHTFIELD_CELL )
	local x1 = math_floor( maxs.x / HEIGHTFIELD_CELL )
	local y0 = math_floor( mins.y / HEIGHTFIELD_CELL )
	local y1 = math_floor( maxs.y / HEIGHTFIELD_CELL )

	if x1 - x0 > HEIGHTFIELD_MAX_CELLS then x1 = x0 + HEIGHTFIELD_MAX_CELLS end
	if y1 - y0 > HEIGHTFIELD_MAX_CELLS then y1 = y0 + HEIGHTFIELD_MAX_CELLS end

	for cx = x0, x1 do
		for cy = y0, y1 do
			local key = cellKey( cx, cy )
			local prev = field[key]
			if not prev or z < prev then field[key] = z end
		end
	end
end

local index = nil
local indexBounds = nil
local indexStale = false
local indexInfo = { faces = 0, skipped = 0, displacements = 0, failed = 0 }

function Extract.HasIndex() return index ~= nil end
function Extract.GetIndex() return index end
function Extract.GetInfo() return indexInfo end

function Extract.IsStale() return index == nil or indexStale end

function Extract.MarkStale()
	indexStale = true
end

function Extract.Release()
	index = nil
	indexBounds = nil
	indexStale = false
	collectgarbage( "step" )
end

function Extract.RestoreIndex( records, bounds )
	index = records or {}
	indexBounds = bounds
	indexStale = false
	indexInfo = { faces = #index, skipped = 0, displacements = 0, failed = 0, cached = true }
end

function Extract.GetWorldBounds()
	local map = NikNaks.CurrentMap
	local mins, maxs

	if map then
		local a, b = map:GetBrushBounds()
		mins, maxs = Util.CopyVector( a ), Util.CopyVector( b )
	else
		mins, maxs = Vector( -8192, -8192, -8192 ), Vector( 8192, 8192, 8192 )
	end

	return mins, maxs
end

local function isFaceSkipped( face, matName )
	if not face:ShouldRender() then return true end
	if face:IsSkyBox() or face:IsSkyBox3D() then return true end

	local texinfo = face:GetTexInfo()
	if texinfo then
		local flags = texinfo.flags
		if bit.band( flags, SURF.TRIGGER ) ~= 0 then return true end
		if bit.band( flags, SURF.HINT ) ~= 0 then return true end
		if bit.band( flags, SURF.SKIP ) ~= 0 then return true end
		if bit.band( flags, SURF.SKY2D ) ~= 0 then return true end
	end

	if matName == "" then return true end
	if matchAny( matName, SKIP_MATERIALS ) then return true end

	return false
end

local function classify( matName, nz, isDisplacement, _translucent, warp, taggedRoad, autoRoad )
	if warp or matchAny( matName, WATER_MATERIALS ) then return SURFACE.WATER, BATCH.WATER end
	if taggedRoad then return SURFACE.ROAD, BATCH.ROAD end
	if matchAny( matName, GLASS_MATERIALS ) then return SURFACE.GLASS, BATCH.GLASS end

	local horizontalUp = nz >= HORIZONTAL_DOT
	local horizontalDown = nz <= -HORIZONTAL_DOT

	if autoRoad and horizontalUp and matchAny( matName, ROAD_MATERIALS ) then
		return SURFACE.ROAD, BATCH.ROAD
	end

	local byMaterial = materialClass( matName )

	if byMaterial then
		if horizontalDown and byMaterial ~= SURFACE.ROCK then
			return SURFACE.CEILING, BATCH.OPAQUE
		end
		return byMaterial, horizontalUp and BATCH.TERRAIN or BATCH.OPAQUE
	end

	if isDisplacement then
		return horizontalUp and SURFACE.GRASS or SURFACE.ROCK, BATCH.TERRAIN
	end

	if horizontalUp then return SURFACE.GROUND, BATCH.TERRAIN end
	if horizontalDown then return SURFACE.CEILING, BATCH.OPAQUE end

	return SURFACE.WALL, BATCH.OPAQUE
end

Extract.Classify = classify

local function displacementBounds( face, verts, mins, maxs )
	local info = face:GetDisplacementInfo()
	local data = NikNaks.CurrentMap:GetDispVerts()
	local start, nearest = 1, math.huge
	for i = 1, 4 do
		local distance = verts[i]:DistToSqr( info.startPosition )
		if distance < nearest then start, nearest = i, distance end
	end
	local a, b, c, d = verts[start], verts[start % 4 + 1],
		verts[( start + 1 ) % 4 + 1], verts[( start + 2 ) % 4 + 1]
	local side = 2 ^ info.power
	mins:SetUnpacked( math.huge, math.huge, math.huge )
	maxs:SetUnpacked( -math.huge, -math.huge, -math.huge )

	for i = 0, ( side + 1 ) ^ 2 - 1 do
		local vertex = data[info.DispVertStart + i]
		local u, v = i % ( side + 1 ) / side, math_floor( i / ( side + 1 ) ) / side
		local x = ( a.x + ( d.x - a.x ) * u ) * ( 1 - v ) + ( b.x + ( c.x - b.x ) * u ) * v + vertex.vec.x * vertex.dist
		local y = ( a.y + ( d.y - a.y ) * u ) * ( 1 - v ) + ( b.y + ( c.y - b.y ) * u ) * v + vertex.vec.y * vertex.dist
		local z = ( a.z + ( d.z - a.z ) * u ) * ( 1 - v ) + ( b.z + ( c.z - b.z ) * u ) * v + vertex.vec.z * vertex.dist
		mins.x, mins.y, mins.z = math.min( mins.x, x ), math.min( mins.y, y ), math.min( mins.z, z )
		maxs.x, maxs.y, maxs.z = math.max( maxs.x, x ), math.max( maxs.y, y ), math.max( maxs.z, z )
	end
end

function Extract.RetagRoad( rec, isRoad, autoRoad )
	if rec.class == SURFACE.WATER or rec.class == SURFACE.GLASS then return end

	local class, batch = classify( rec.mat, rec.nz, rec.disp, false, false, isRoad, autoRoad )

	if rec.roof and class ~= SURFACE.ROAD and DM.SURFACE_HORIZONTAL[class] then
		class = SURFACE.ROOF
		batch = BATCH.OPAQUE
	end

	rec.class, rec.batch = class, batch
end

function Extract.BuildIndex( doc, opts, yielder )
	opts = opts or {}
	yielder = yielder or function() end

	local map = NikNaks.CurrentMap
	if not map then
		DM.Warn( "no BSP available - the minimap cannot be built" )
		index, indexBounds = {}, nil
		return index
	end

	local faces = map:GetFaces()

	local worldMins, worldMaxs = Extract.GetWorldBounds()
	local renderZones = doc and doc.renderZones or {}
	local roads = doc and doc.roads or {}

	local records, count = {}, 0
	local heightField = {}
	local skipped, dispCount, failed = 0, 0, 0

	local total = 0
	for _ in pairs( faces ) do total = total + 1 end
	total = math_max( total, 1 )

	local processed = 0
	local sinceYield = 0

	local bounds = {
		mins = Vector( math.huge, math.huge, math.huge ),
		maxs = Vector( -math.huge, -math.huge, -math.huge ),
	}

	local function processFace( faceId, face )
		local include = true
		local matName = string_lower( face:GetTexture() or "" )

		if isFaceSkipped( face, matName ) then
			include = false
			skipped = skipped + 1
		end

		if include then
			local verts = face:GetVertexs()

			if not verts or #verts < 3 then
				include = false
			else

				local mins = Vector( math.huge, math.huge, math.huge )
				local maxs = Vector( -math.huge, -math.huge, -math.huge )
				local cx, cy, cz = 0, 0, 0
				local n = #verts

				for i = 1, n do
					local v = verts[i]
					Util.ExpandBounds( mins, maxs, v )
					cx, cy, cz = cx + v.x, cy + v.y, cz + v.z
				end

				local isDisp = face:IsDisplacement()
				local center = Vector( cx / n, cy / n, cz / n )
				if isDisp and n == 4 then
					displacementBounds( face, verts, mins, maxs )
					center = ( mins + maxs ) * 0.5
				elseif ( face:GetBModel() or 0 ) > 0 then

					local transformed = face:GenerateVertexData()
					if transformed and #transformed >= 3 then
						mins:SetUnpacked( math.huge, math.huge, math.huge )
						maxs:SetUnpacked( -math.huge, -math.huge, -math.huge )
						for _, vertex in ipairs( transformed ) do Util.ExpandBounds( mins, maxs, vertex.pos ) end
						center = ( mins + maxs ) * 0.5
					end
				end

				local zoneId = DM.MapData.RenderZoneIdAt( renderZones, center )

				if include then

					local normal = face:GetNormal()
					local nz = normal.z
					local translucent = face:IsTranslucent()
					local texinfo = face:GetTexInfo()
					local warp = texinfo and bit.band( texinfo.flags, SURF.WARP ) ~= 0 or false

					local class, batch = classify( matName, nz, isDisp, translucent, warp,
						roads[faceId] == true, opts.autoRoad )

					if isDisp then dispCount = dispCount + 1 end

					count = count + 1
					records[count] = {
						id      = faceId,
						class   = class,
						batch   = batch,
						mins    = mins,
						maxs    = maxs,
						center  = center,
						normal  = normal,
						nz      = nz,
						mat     = matName,
						disp    = isDisp,
						translucent = translucent,
						bmodel  = face:GetBModel() or 0,
						zone    = zoneId,
					}

					Util.ExpandBounds( bounds.mins, bounds.maxs, mins )
					Util.ExpandBounds( bounds.mins, bounds.maxs, maxs )

					if nz >= HORIZONTAL_DOT and class ~= SURFACE.WATER then
						stampFloor( heightField, mins, maxs, center.z )
					end
				end
			end
		end
	end

	for faceId, face in pairs( faces ) do
		processed = processed + 1
		sinceYield = sinceYield + 1

		local ok, err = pcall( processFace, faceId, face )

		if not ok then
			failed = failed + 1
			if failed == 1 then
				DM.Warn( "face ", faceId, " could not be read: ", tostring( err ) )
			end
		end

		face._vertex = nil

		if sinceYield >= FACES_PER_YIELD then
			sinceYield = 0
			yielder( processed / total, "reading geometry" )
		end
	end

	for i = 1, count do
		local rec = records[i]

		if not rec.disp and ROOF_ELIGIBLE[rec.class] then
			local key = cellKey( math_floor( rec.center.x / HEIGHTFIELD_CELL ),
				math_floor( rec.center.y / HEIGHTFIELD_CELL ) )
			local floorZ = heightField[key]

			if floorZ and rec.center.z - floorZ > ROOF_THRESHOLD then
				rec.class = SURFACE.ROOF
				rec.batch = BATCH.OPAQUE
				rec.roof = true
			end
		end

		if i % 4000 == 0 then
			yielder( 1, "classifying surfaces" )
		end
	end

	if count == 0 then
		bounds.mins, bounds.maxs = Util.CopyVector( worldMins ), Util.CopyVector( worldMaxs )
	end

	if failed > 0 then
		DM.Warn( failed, " faces could not be read and were skipped" )
	end

	index = records
	indexBounds = bounds
	indexStale = false
	indexInfo = { faces = count, skipped = skipped, displacements = dispCount, failed = failed }

	return records
end

function Extract.GetIndexBounds()
	if indexBounds then return indexBounds.mins, indexBounds.maxs end
	return Extract.GetWorldBounds()
end

function Extract.GetTriangles( rec )
	local map = NikNaks.CurrentMap
	if not map then return nil end

	local face = map:GetFaces()[rec.id]
	if not face then return nil end

	local ok, tris = pcall( face.GenerateVertexTriangleData, face )

	face._vertTriangleData = nil
	face._vertex = nil

	if not ok or not tris or #tris < 3 then return nil end
	return tris
end

function Extract.GetTrianglePositions( rec )
	local map = NikNaks.CurrentMap
	if not map then return nil end

	local faces = map:GetFaces()
	local face = faces[rec.id]
	if not face then return nil end

	if not rec.disp and rec.bmodel == 0 then
		local ok, verts = pcall( face.GetVertexs, face )
		face._vertex = nil

		if not ok or not verts then return nil end

		local n = #verts
		if n < 3 then return nil end

		local out, p = {}, 0
		local first = verts[1]

		for i = 2, n - 1 do
			out[p + 1] = first
			out[p + 2] = verts[i]
			out[p + 3] = verts[i + 1]
			p = p + 3
		end

		return out
	end

	local tris = Extract.GetTriangles( rec )
	if not tris then return nil end

	local out = {}
	for i = 1, #tris do out[i] = tris[i].pos end
	return out
end
