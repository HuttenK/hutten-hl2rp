-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Util = DM.Util
local Themes = DM.Themes

DM.Props = DM.Props or {}
local Props = DM.Props

local FOLIAGE_PATH_HINTS = {
	"/foliage/", "/vegetation/", "/trees/", "/flora/", "props_foliage",
}

local FOLIAGE_TOKENS = {
	tree = true, trees = true, foliage = true, bush = true, bushes = true,
	shrub = true, shrubs = true, palm = true, fern = true, leaf = true,
	leaves = true, pine = true, birch = true, spruce = true, willow = true,
	hedge = true, vine = true, grass = true, flower = true, branch = true,
	cactus = true, reed = true, flora = true,
}

local FOLIAGE_PREFIXES = {
	"tree", "foliage", "bush", "shrub", "palm", "fern", "leaf", "pine",
	"birch", "spruce", "willow", "hedge", "vine", "grass", "flower",
	"branch", "cactus", "reed",
}

local DEFAULT_MINS = Vector( -18, -18, 0 )
local DEFAULT_MAXS = Vector( 18, 18, 72 )

local MIN_RADIUS = {
	[0] = math.huge,
	[1] = 40,
	[2] = 16,
	[3] = 0,
}

local BASE_MODEL_EXTENT = 4096
local MAX_MODEL_EXTENT = 32768
local PICK_GRID_MAX_RADIUS = 2048

local props = {}
local grid = nil
local oversizedPickProps = {}
local builtKey = nil
local modelBounds = {}
local treeMaterials = {}
local treeMaterialAlpha = {}
local decalMaterials = {}
local treeMaterial = nil
local modelExtentLimit = BASE_MODEL_EXTENT

hook.Remove( "PreRender", "ix_ftmap_tree_alpha_masks" )

local function modelName( model )
	return string.match( model, "([^/]+)%.mdl$" ) or string.match( model, "([^/]+)$" ) or model
end

local function propsKey( doc )
	return table.concat( {
		game.GetMap(),
		DM.MapData.GetMapRevision(),
		DM.MapData.Fingerprint( doc ),
		DM.Config.Get( "ix_ftmap_sv_prop_lod" ),
		DM.Config.Get( "ix_ftmap_sv_foliage" ) and 1 or 0,
	}, "|" )
end

local function isTreeModel( model )
	for i = 1, #FOLIAGE_PATH_HINTS do
		if string.find( model, FOLIAGE_PATH_HINTS[i], 1, true ) then return true end
	end

	local name = modelName( model )

	for token in string.gmatch( name, "[%a%d]+" ) do
		if FOLIAGE_TOKENS[token] then return true end
	end

	for i = 1, #FOLIAGE_PREFIXES do
		local prefix = FOLIAGE_PREFIXES[i]
		if string.sub( name, 1, #prefix ) == prefix then return true end
	end

	return false
end

local function finite( v )
	return v and v.x == v.x and v.y == v.y and v.z == v.z
		and math.abs( v.x ) < 1e6 and math.abs( v.y ) < 1e6 and math.abs( v.z ) < 1e6
end

local function degenerate( mins, maxs )
	if not finite( mins ) or not finite( maxs ) then return true end

	local dx, dy, dz = maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z

	if dx < 0 or dy < 0 or dz < 0 then return true end
	if dx < 1 and dy < 1 and dz < 1 then return true end

	return dx > modelExtentLimit or dy > modelExtentLimit or dz > modelExtentLimit
end

local function usableBounds( mins, maxs )
	if not finite( mins ) or not finite( maxs ) then return false end
	local dx, dy, dz = maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z
	return dx >= 0 and dy >= 0 and dz >= 0 and math.max( dx, dy, dz ) >= 1
end

function Props.ReadModelBounds( model )
	local f = file.Open( model, "rb", "GAME" )
	if not f then return end
	local mins, maxs
	if f:Size() >= 152 and f:Read( 4 ) == "IDST" then
		local version = f:ReadLong()
		if version >= 44 and version <= 49 then
			f:Seek( 104 )
			local hullMins = Vector( f:ReadFloat(), f:ReadFloat(), f:ReadFloat() )
			local hullMaxs = Vector( f:ReadFloat(), f:ReadFloat(), f:ReadFloat() )
			mins = Vector( f:ReadFloat(), f:ReadFloat(), f:ReadFloat() )
			maxs = Vector( f:ReadFloat(), f:ReadFloat(), f:ReadFloat() )
			if not usableBounds( mins, maxs ) then mins, maxs = hullMins, hullMaxs end
		end
	end
	f:Close()
	if usableBounds( mins, maxs ) then return mins, maxs end
end

local function resolveBounds( model )
	local cached = modelBounds[model]
	if cached then return cached[1], cached[2] end

	local mins, maxs = Props.ReadModelBounds( model )

	if degenerate( mins, maxs ) then
		local ent = ClientsideModel( model, RENDERGROUP_OTHER )
		if IsValid( ent ) then
			ent:SetNoDraw( true )
			mins, maxs = ent:GetModelRenderBounds()
			if mins then mins = Vector( mins ) end
			if maxs then maxs = Vector( maxs ) end
			ent:Remove()
		end
	end

	if degenerate( mins, maxs ) then
		local ok, fileMins, fileMaxs = pcall( NikNaks.ModelSize, model )
		if ok and not degenerate( fileMins, fileMaxs ) then
			mins, maxs = Vector( fileMins ), Vector( fileMaxs )
		else
			mins, maxs = nil, nil
		end
	end

	modelBounds[model] = { mins, maxs }
	return mins, maxs
end

local function solidMaterial( materialName )
	treeMaterials[materialName] = false
	treeMaterialAlpha[materialName] = false
	return nil, false
end

treeMaterial = function( materialName )
	materialName = tostring( materialName or "" )

	local cached = treeMaterials[materialName]
	if cached ~= nil then return cached or nil, treeMaterialAlpha[materialName] == true, decalMaterials[materialName] == true end

	local lowered = string.lower( materialName )
	local leafMaterial = string.find( lowered, "leaf", 1, true )
		or string.find( lowered, "leaves", 1, true ) or string.find( lowered, "foliage", 1, true )

	if string.find( lowered, "glass", 1, true ) or string.find( lowered, "window", 1, true ) then
		return solidMaterial( materialName )
	end
	local text = file.Read( "materials/" .. materialName .. ".vmt", "GAME" )
	if text and not leafMaterial then
		text = string.lower( text ):gsub( "//[^\r\n]*", "" )
		local shader = string.match( text, '^%s*"?([%w_]+)' )
		if ( shader == "vertexlitgeneric" or shader == "lightmappedgeneric" or shader == "unlitgeneric" )
			and not string.find( text, "$alpha", 1, true )
			and not string.find( text, "$translucent", 1, true )
			and not string.find( text, "$additive", 1, true )
			and not string.find( text, "$decal", 1, true )
			and not string.find( text, "proxies", 1, true )
			and not string.find( text, "include", 1, true ) then
			return solidMaterial( materialName )
		end
	end

	local source = materialName ~= "" and Material( materialName ) or nil
	local texture = source and not source:IsError() and source:GetTexture( "$basetexture" ) or nil

	if not texture or texture:IsError() then
		treeMaterials[materialName] = false
		treeMaterialAlpha[materialName] = false
		return nil, false
	end

	local flags = tonumber( source:GetInt( "$flags" ) or 0 ) or 0
	local alphaTest = bit.band( flags, 256 ) ~= 0
	local translucent = bit.band( flags, 2097152 ) ~= 0
	local decal = bit.band( flags, 65536 ) ~= 0
	local noCull = bit.band( flags, 8192 ) ~= 0

	if not decal and not alphaTest and not leafMaterial then
		return solidMaterial( materialName )
	end

	local whiteTexture = DM.Assets.World:GetTexture( "$basetexture" )
	local alphaRef = source:GetFloat( "$alphatestreference" )
	if not alphaRef or alphaRef <= 0 or alphaRef >= 1 then alphaRef = 0.5 end
	local material = CreateMaterial( "ix_ftmap_prop_studio_alpha_v2_" .. util.CRC( materialName ), "VertexLitGeneric", {
		["$basetexture"] = "color/white",
		["$detail"] = "color/white",

		["$detailblendmode"] = "2",
		["$detailblendfactor"] = "1",
		["$detailscale"] = "1",
		["$alphatest"] = decal and not alphaTest and "0" or "1",
		["$alphatestreference"] = tostring( alphaRef ),
		["$allowalphatocoverage"] = alphaTest and bit.band( flags, 536870912 ) ~= 0 and "1" or "0",
		["$translucent"] = decal and translucent and "1" or "0",

		["$decal"] = decal and "1" or "0",
		["$vertexcolor"] = "0",
		["$vertexalpha"] = "0",
		["$model"] = "1",
		["$nocull"] = ( not decal or noCull ) and "1" or "0",
	} )

	if not material then
		treeMaterials[materialName] = false
		treeMaterialAlpha[materialName] = false
		return nil, false
	end

	material:SetTexture( "$basetexture", texture )
	material:SetTexture( "$detail", whiteTexture )
	local transform = source:GetMatrix( "$basetexturetransform" )
	if transform then material:SetMatrix( "$basetexturetransform", transform ) end
	material:SetInt( "$frame", source:GetInt( "$frame" ) or 0 )
	treeMaterials[materialName] = material
	treeMaterialAlpha[materialName] = true
	decalMaterials[materialName] = decal
	return material, true, decal
end

local function rotatedBounds( pos, ang, mins, maxs )
	local center = ( mins + maxs ) * 0.5
	local half = ( maxs - mins ) * 0.5
	center:Rotate( ang )
	center:Add( pos )

	local forward = ang:Forward()
	local right = ang:Right()
	local up = ang:Up()
	local extent = Vector(
		math.abs( forward.x ) * half.x + math.abs( right.x ) * half.y + math.abs( up.x ) * half.z,
		math.abs( forward.y ) * half.x + math.abs( right.y ) * half.y + math.abs( up.y ) * half.z,
		math.abs( forward.z ) * half.x + math.abs( right.z ) * half.y + math.abs( up.z ) * half.z )

	return center - extent, center + extent
end

local function normaliseFoliageBounds( mins, maxs )
	local height = Util.Clamp( maxs.z - mins.z, 24, 2048 )
	local footprint = math.max( maxs.x - mins.x, maxs.y - mins.y )
	local radius = Util.Clamp( math.min( footprint * 0.5, height * 0.65 ), 8, 768 )
	local bottom = Util.Clamp( mins.z, -height * 0.2, height * 0.2 )

	return Vector( -radius, -radius, bottom ), Vector( radius, radius, bottom + height )
end

function Props.Build( doc, theme, worldMins, worldMaxs, invertHeight, yielder )
	yielder = yielder or function() end

	props = {}
	oversizedPickProps = {}
	grid = DM.Spatial.New( 1024 )
	builtKey = propsKey( doc )

	local mapExtent = math.max(
		worldMaxs.x - worldMins.x,
		worldMaxs.y - worldMins.y,
		worldMaxs.z - worldMins.z )

	modelExtentLimit = Util.Clamp( mapExtent, BASE_MODEL_EXTENT, MAX_MODEL_EXTENT )

	local map = NikNaks.CurrentMap
	if not map then return end

	local lod = DM.Config.Get( "ix_ftmap_sv_prop_lod" )
	if lod <= 0 then
		return
	end

	local ok, list = pcall( map.GetStaticProps, map )
	if not ok or not list then
		DM.Warn( "static props could not be read from the BSP" )
		return
	end

	local renderZones = doc.renderZones or {}
	local hiddenProps = doc.hiddenProps or {}

	local foliage = DM.Config.Get( "ix_ftmap_sv_foliage" )
	local minRadius = MIN_RADIUS[lod] or 16
	local intensity = DM.Config.Get( "ix_ftmap_sv_height_shading" )
	local zRange = math.max( worldMaxs.z - worldMins.z, 1 )

	local edits = doc.propEdits or {}

	local total = 0
	for _ in pairs( list ) do total = total + 1 end
	total = math.max( total, 1 )

	local processed, count, skipped, broken = 0, 0, 0, 0

	for propIndex, prop in pairs( list ) do
		processed = processed + 1

		local model = prop.PropType and string.lower( prop.PropType ) or ""
		local edit = edits[propIndex]
		local pos = edit and edit.pos or prop.Origin

		if model ~= "" and pos and not hiddenProps[propIndex] then
			local zoneId = DM.MapData.RenderZoneIdAt( renderZones, pos )
			local include = true

			local tree = isTreeModel( model )
			local scale = edit and edit.scale or prop.UniformScale or 1
			local mins, maxs

			if include then
				mins, maxs = resolveBounds( model )

				if not mins then
					broken = broken + 1

					if util.IsValidModel( model ) then
						mins, maxs = DEFAULT_MINS, DEFAULT_MAXS
					else
						include = false
					end
				end
			end

			if include then
				local localMins = mins * scale
				local localMaxs = maxs * scale

				if tree then
					localMins, localMaxs = normaliseFoliageBounds( localMins, localMaxs )
				end

				local radius = math.max(
					localMaxs.x - localMins.x,
					localMaxs.y - localMins.y,
					localMaxs.z - localMins.z ) * 0.5

				if tree and not foliage then
					include = false
					skipped = skipped + 1
				elseif radius < minRadius and not tree then
					include = false
					skipped = skipped + 1
				end

				if include then
					local altitude = Util.Clamp( ( pos.z - worldMins.z ) / zRange, 0, 1 )
					local r, g, b = Themes.ResolveProp( theme, tree, altitude, intensity, invertHeight )
					local ang = edit and edit.ang or prop.Angles or angle_zero

					count = count + 1

					local rec = {
						pos       = Util.CopyVector( pos ),
						ang       = Angle( ang.p, ang.y, ang.r ),
						model     = model,
						scale     = scale,
						tree      = tree,
						radius    = radius,
						localMins = localMins,
						localMaxs = localMaxs,
						r = r, g = g, b = b,
						zone      = zoneId,
						index     = propIndex,
						edited    = edit ~= nil,
					}

					props[count] = rec

					rec.mins, rec.maxs = rotatedBounds( rec.pos, rec.ang, localMins, localMaxs )

					if radius <= PICK_GRID_MAX_RADIUS then
						grid:Insert( rec, rec.mins, rec.maxs )
					else
						oversizedPickProps[#oversizedPickProps + 1] = rec
					end
				end
			end
		end

		if processed % 300 == 0 then
			yielder( processed / total, "measuring props" )
		end
	end

end

function Props.GetAll() return props end
function Props.GetGrid() return grid end
function Props.GetOversizedPickProps() return oversizedPickProps end
function Props.Count() return #props end
function Props.GetTreeMaterial( materialName ) return treeMaterial( materialName ) end
function Props.IsBuilt( doc ) return builtKey == propsKey( doc ) end
function Props.Invalidate() builtKey = nil end
