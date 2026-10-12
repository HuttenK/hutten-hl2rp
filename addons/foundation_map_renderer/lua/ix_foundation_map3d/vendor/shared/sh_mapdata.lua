-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Util = DM.Util

DM.MapData = DM.MapData or {}
local MapData = DM.MapData

local DEFAULT_ZONE_COLOR = Color( 90, 220, 200, 60 )
local DEFAULT_POI_COLOR  = Color( 255, 210, 90, 255 )
local ZONE_SHAPES = { box = true, circle = true, polygon = true, volume = true }
local MAX_PAYLOAD = 8 * 1024 * 1024
local MAX_JSON = 32 * 1024 * 1024

local function wireNumber( value, fallback, limit )
	if value == nil then return fallback end
	local number = tonumber( value )
	if not Util.IsFiniteNumber( number ) or math.abs( number ) > ( limit or 1048576 ) then
		error( "invalid numeric field" )
	end
	return number
end

local function wireId( value, fallback )
	local id = wireNumber( value, fallback, 2147483647 )
	if id == nil or id < 0 or id ~= math.floor( id ) then error( "invalid document ID" ) end
	return id
end

local function wireText( value, fallback, limit )
	if value == nil then return fallback end
	if type( value ) ~= "string" or #value > limit then error( "invalid text field" ) end
	return value
end

local function normalizeZoneShape( shape )
	shape = string.lower( tostring( shape or "box" ) )
	return ZONE_SHAPES[shape] and shape or "box"
end

MapData.NormalizeZoneShape = normalizeZoneShape

local function vecToTable( v )
	return { math.Round( v.x * 100 ) / 100, math.Round( v.y * 100 ) / 100, math.Round( v.z * 100 ) / 100 }
end

local function tableToVec( t )
	if type( t ) ~= "table" then return Vector( 0, 0, 0 ) end
	return Vector( wireNumber( t[1], 0 ), wireNumber( t[2], 0 ), wireNumber( t[3], 0 ) )
end

function MapData.GetMapRevision()
	local map = NikNaks and NikNaks.CurrentMap
	if not map then return 0 end

	local ok, rev = pcall( map.GetMapRevision, map )
	return ok and tonumber( rev ) or 0
end

function MapData.CreateEmpty( mapName )
	return {
		version     = DM.DATA_VERSION,
		map         = mapName or game.GetMap(),
		revision    = 0,
		mapRevision = MapData.GetMapRevision(),
		roads       = {},
		hidden      = {},
		hiddenProps = {},
		propEdits   = {},
		faceColors  = {},
		faceTints   = {},
		zones       = {},
		renderZones = {},
		pois        = {},
	}
end

function MapData.Clone( doc )
	local out = MapData.CreateEmpty( doc.map )
	out.version     = doc.version
	out.revision    = doc.revision
	out.mapRevision = doc.mapRevision

	for id in pairs( doc.roads ) do out.roads[id] = true end
	for id in pairs( doc.hidden ) do out.hidden[id] = true end
	for id in pairs( doc.hiddenProps ) do out.hiddenProps[id] = true end
	for id, c in pairs( doc.faceColors ) do out.faceColors[id] = Util.CopyColor( c ) end
	for id, t in pairs( doc.faceTints ) do out.faceTints[id] = t end

	for id, e in pairs( doc.propEdits or {} ) do
		out.propEdits[id] = {
			pos   = Util.CopyVector( e.pos ),
			ang   = Angle( e.ang.p, e.ang.y, e.ang.r ),
			scale = e.scale,
		}
	end

	for i, z in ipairs( doc.zones ) do
		out.zones[i] = {
			id = z.id, uid = z.uid, name = z.name,
			mins = Util.CopyVector( z.mins ), maxs = Util.CopyVector( z.maxs ),
			color = Util.CopyColor( z.color ), label = z.label, indoor = z.indoor,
			shape = normalizeZoneShape( z.shape ), points = {},
		}

		for pointIndex, point in ipairs( z.points or {} ) do
			out.zones[i].points[pointIndex] = Util.CopyVector( point )
		end
	end

	for i, z in ipairs( doc.renderZones ) do
		out.renderZones[i] = {
			id = z.id, uid = z.uid, name = z.name,
			mins = Util.CopyVector( z.mins ), maxs = Util.CopyVector( z.maxs ),
			strict = z.strict,
		}
	end

	for i, p in ipairs( doc.pois ) do
		out.pois[i] = {
			id = p.id, uid = p.uid, name = p.name, pos = Util.CopyVector( p.pos ),
			color = Util.CopyColor( p.color ), icon = p.icon,
		}
	end

	return out
end

local function valueEqual( a, b )
	if a == b then return true end
	if a == nil or b == nil then return false end

	if isvector( a ) or isvector( b ) then
		return isvector( a ) and isvector( b )
			and a.x == b.x and a.y == b.y and a.z == b.z
	end

	if isangle( a ) or isangle( b ) then
		return isangle( a ) and isangle( b )
			and a.p == b.p and a.y == b.y and a.r == b.r
	end

	if IsColor( a ) or IsColor( b ) then
		return IsColor( a ) and IsColor( b )
			and a.r == b.r and a.g == b.g and a.b == b.b and ( a.a or 255 ) == ( b.a or 255 )
	end

	if type( a ) ~= type( b ) then return false end
	if type( a ) ~= "table" then return false end

	for key, value in pairs( a ) do
		if not valueEqual( value, b[key] ) then return false end
	end

	for key in pairs( b ) do
		if a[key] == nil then return false end
	end

	return true
end

local function cloneValue( value )
	if isvector( value ) then return Util.CopyVector( value ) end
	if isangle( value ) then return Angle( value.p, value.y, value.r ) end
	if IsColor( value ) then return Util.CopyColor( value ) end
	if type( value ) ~= "table" then return value end

	local out = {}
	for key, child in pairs( value ) do out[key] = cloneValue( child ) end
	return out
end

MapData.ValueEqual = valueEqual
MapData.CloneValue = cloneValue

local MAP_FIELDS = {
	"roads", "hidden", "hiddenProps", "propEdits", "faceColors", "faceTints",
}

local LIST_FIELDS = {
	zones = { "uid", "name", "mins", "maxs", "color", "label", "indoor", "shape", "points" },
	renderZones = { "uid", "name", "mins", "maxs", "strict" },
	pois = { "uid", "name", "pos", "color", "icon" },
}

local function addKeys( keys, source )
	for key in pairs( source or {} ) do keys[key] = true end
end

local function mergeMap( base, edited, current )
	local out = {}
	local keys = {}
	addKeys( keys, base )
	addKeys( keys, edited )
	addKeys( keys, current )

	for key in pairs( keys ) do
		local value

		if not valueEqual( edited and edited[key], base and base[key] ) then
			value = edited and edited[key]
		else
			value = current and current[key]
		end

		if value ~= nil and value ~= false then out[key] = cloneValue( value ) end
	end

	return out
end

local function indexList( list )
	local index = {}
	for _, object in ipairs( list or {} ) do index[object.id] = object end
	return index
end

local function mergeObject( base, edited, current, fields )
	local out = cloneValue( current )

	for _, field in ipairs( fields ) do
		if not valueEqual( edited[field], base[field] ) then
			out[field] = cloneValue( edited[field] )
		end
	end

	out.id = current.id
	return out
end

local function mergeList( name, fields, baseList, editedList, currentList, metadata )
	local base = indexList( baseList )
	local edited = indexList( editedList )
	local current = indexList( currentList )
	local handled = {}
	local out = {}
	local highest = 0

	for id in pairs( base ) do if id > highest then highest = id end end
	for id in pairs( edited ) do if id > highest then highest = id end end
	for id in pairs( current ) do if id > highest then highest = id end end

	local function append( object, id )
		local copy = cloneValue( object )
		copy.id = id or copy.id
		out[#out + 1] = copy
	end

	for _, currentObject in ipairs( currentList or {} ) do
		local id = currentObject.id
		local baseObject = base[id]
		local editedObject = edited[id]
		handled[id] = true

		if baseObject then
			if editedObject then
				append( mergeObject( baseObject, editedObject, currentObject, fields ), id )
			end
		elseif editedObject then
			local editedUid = editedObject.uid and tostring( editedObject.uid ) or ""
			local currentUid = currentObject.uid and tostring( currentObject.uid ) or ""

			if editedUid ~= "" and editedUid == currentUid then

				append( editedObject, id )
			elseif valueEqual( editedObject, currentObject ) then
				append( currentObject, id )
			else
				append( currentObject, id )
				highest = highest + 1
				append( editedObject, highest )
				metadata.renamed[name][id] = highest
			end
		else
			append( currentObject, id )
		end
	end

	for _, editedObject in ipairs( editedList or {} ) do
		local id = editedObject.id

		if not handled[id] then
			local baseObject = base[id]

			if not baseObject or not valueEqual( editedObject, baseObject ) then
				append( editedObject, id )
			end
		end
	end

	return out
end

function MapData.MergeDocuments( base, edited, current )
	if not base then return MapData.Clone( edited ), { renamed = { zones = {}, renderZones = {}, pois = {} } } end
	if not current then return MapData.Clone( edited ), { renamed = { zones = {}, renderZones = {}, pois = {} } } end

	local out = MapData.Clone( current )
	local metadata = { renamed = { zones = {}, renderZones = {}, pois = {} } }

	for _, field in ipairs( MAP_FIELDS ) do
		out[field] = mergeMap( base[field], edited[field], current[field] )
	end

	for name, fields in pairs( LIST_FIELDS ) do
		out[name] = mergeList( name, fields, base[name], edited[name], current[name], metadata )
	end

	out.version = current.version
	out.map = current.map
	out.revision = current.revision
	out.mapRevision = current.mapRevision

	return out, metadata
end

function MapData.ContentEqual( a, b )
	if not a or not b then return a == b end

	for _, field in ipairs( MAP_FIELDS ) do
		if not valueEqual( a[field], b[field] ) then return false end
	end

	for name in pairs( LIST_FIELDS ) do
		if not valueEqual( a[name], b[name] ) then return false end
	end

	return true
end

local function toWire( doc )
	local wire = {
		v   = doc.version or DM.DATA_VERSION,
		map = doc.map,
		rev = doc.revision or 0,
		bsp = doc.mapRevision or 0,
		rd  = Util.EncodeIntSet( doc.roads ),
		hd  = Util.EncodeIntSet( doc.hidden ),
		hp  = Util.EncodeIntSet( doc.hiddenProps ),
		pe  = {},
		fc  = {},
		ft  = {},
		zn  = {},
		rz  = {},
		poi = {},
	}

	for id, e in pairs( doc.propEdits or {} ) do
		wire.pe[tostring( id )] = {
			p = vecToTable( e.pos ),
			a = { math.Round( e.ang.p * 10 ) / 10, math.Round( e.ang.y * 10 ) / 10, math.Round( e.ang.r * 10 ) / 10 },
			s = math.Round( ( e.scale or 1 ) * 1000 ) / 1000,
		}
	end

	for id, c in pairs( doc.faceColors ) do
		wire.fc[tostring( id )] = { math.floor( c.r ), math.floor( c.g ), math.floor( c.b ) }
	end

	for id, t in pairs( doc.faceTints ) do
		if t ~= 0 then wire.ft[tostring( id )] = math.Round( t * 100 ) / 100 end
	end

	for i, z in ipairs( doc.zones ) do
		wire.zn[i] = {
			id = z.id, u = z.uid, n = z.name,
			a = vecToTable( z.mins ), b = vecToTable( z.maxs ),
			c = Util.ColorToTable( z.color ),
			l = z.label and 1 or 0,
			i = z.indoor and 1 or 0,
			sh = normalizeZoneShape( z.shape ),
			pt = {},
		}

		for pointIndex, point in ipairs( z.points or {} ) do
			wire.zn[i].pt[pointIndex] = vecToTable( point )
		end
	end

	for i, z in ipairs( doc.renderZones ) do
		wire.rz[i] = {
			id = z.id, u = z.uid, n = z.name,
			a = vecToTable( z.mins ), b = vecToTable( z.maxs ),
			s = z.strict and 1 or 0,
		}
	end

	for i, p in ipairs( doc.pois ) do
		wire.poi[i] = {
			id = p.id, u = p.uid, n = p.name, p = vecToTable( p.pos ),
			c = Util.ColorToTable( p.color ), ic = p.icon,
		}
	end

	return wire
end

local function fromWire( wire )
	local doc = MapData.CreateEmpty( wireText( wire.map, game.GetMap(), 256 ) )

	doc.version     = wireId( wire.v, DM.DATA_VERSION )
	doc.revision    = wireId( wire.rev, 0 )
	doc.mapRevision = wireId( wire.bsp, 0 )

	doc.roads       = Util.DecodeIntSet( wire.rd )
	doc.hidden      = Util.DecodeIntSet( wire.hd )
	doc.hiddenProps = Util.DecodeIntSet( wire.hp )

	for key, e in pairs( wire.pe or {} ) do
		local id = wireId( key )
		local ang = type( e.a ) == "table" and e.a or {}

		if id then
			doc.propEdits[id] = {
				pos   = tableToVec( e.p ),
				ang   = Angle( wireNumber( ang[1], 0 ), wireNumber( ang[2], 0 ), wireNumber( ang[3], 0 ) ),
				scale = Util.Clamp( wireNumber( e.s, 1 ), 0.05, 20 ),
			}
		end
	end

	for key, c in pairs( wire.fc or {} ) do
		local id = wireId( key )
		if id then doc.faceColors[id] = Util.TableToColor( c ) end
	end

	for key, t in pairs( wire.ft or {} ) do
		local id = wireId( key )
		local v = wireNumber( t, 0 )
		if id and v then doc.faceTints[id] = Util.Clamp( v, -1, 1 ) end
	end

	for _, z in ipairs( wire.zn or {} ) do
		if #doc.zones >= 4096 then error( "too many zones" ) end
		local mins, maxs = Util.SortBounds( tableToVec( z.a ), tableToVec( z.b ) )
		local shape = normalizeZoneShape( z.sh )
		local points = {}

		for pointIndex, point in ipairs( z.pt or {} ) do
			if pointIndex > 64 then break end
			points[#points + 1] = tableToVec( point )
		end

		if shape == "polygon" and #points < 3 then
			points = {
				Vector( mins.x, mins.y, mins.z ),
				Vector( maxs.x, mins.y, mins.z ),
				Vector( maxs.x, maxs.y, mins.z ),
				Vector( mins.x, maxs.y, mins.z ),
			}
		end

		doc.zones[#doc.zones + 1] = {
			id     = wireId( z.id, #doc.zones + 1 ),
			uid    = wireText( z.u, "", 128 ),
			name   = wireText( z.n, "", 256 ),
			mins   = mins,
			maxs   = maxs,
			color  = Util.TableToColor( z.c, DEFAULT_ZONE_COLOR ),
			label  = ( tonumber( z.l ) or 1 ) ~= 0,
			indoor = ( tonumber( z.i ) or 0 ) ~= 0,
			shape  = shape,
			points = points,
		}
	end

	for _, z in ipairs( wire.rz or {} ) do
		if #doc.renderZones >= 4096 then error( "too many render zones" ) end
		local mins, maxs = Util.SortBounds( tableToVec( z.a ), tableToVec( z.b ) )
		doc.renderZones[#doc.renderZones + 1] = {
			id     = wireId( z.id, #doc.renderZones + 1 ),
			uid    = wireText( z.u, "", 128 ),
			name   = wireText( z.n, "", 256 ),
			mins   = mins,
			maxs   = maxs,
			strict = ( tonumber( z.s ) or 0 ) ~= 0,
		}
	end

	for _, p in ipairs( wire.poi or {} ) do
		if #doc.pois >= 4096 then error( "too many waypoints" ) end
		doc.pois[#doc.pois + 1] = {
			id    = wireId( p.id, #doc.pois + 1 ),
			uid   = wireText( p.u, "", 128 ),
			name  = wireText( p.n, "", 256 ),
			pos   = tableToVec( p.p ),
			color = Util.TableToColor( p.c, DEFAULT_POI_COLOR ),
			icon  = wireText( p.ic, "dot", 64 ),
		}
	end

	return doc
end

function MapData.Encode( doc )
	local json = util.TableToJSON( toWire( doc ) )
	if type( json ) ~= "string" or #json > MAX_JSON then error( "document is too large or invalid" ) end
	local payload = util.Compress( json ) or json
	if #payload > MAX_PAYLOAD then error( "document exceeds the transfer limit" ) end
	return payload
end

function MapData.Decode( payload )
	if type( payload ) ~= "string" or payload == "" then return nil, "empty payload" end
	if #payload > MAX_PAYLOAD then return nil, "payload is too large" end

	local decoded, json = pcall( util.Decompress, payload, MAX_JSON )
	if not decoded then return nil, "invalid compressed document" end
	if not json then

		json = payload
	end

	if #json > MAX_JSON then return nil, "document is too large" end
	local parsed, wire = pcall( util.JSONToTable, json )
	if not parsed or type( wire ) ~= "table" then return nil, "malformed document" end

	local ok, docOrErr = pcall( fromWire, wire )
	if not ok then return nil, tostring( docOrErr ) end

	return docOrErr
end

function MapData.Canonicalize( doc )
	if not doc then return nil end
	return fromWire( toWire( doc ) )
end

function MapData.WireContentEqual( a, b )
	if not a or not b then return a == b end
	return MapData.ContentEqual( MapData.Canonicalize( a ), MapData.Canonicalize( b ) )
end

function MapData.Fingerprint( doc )
	if not doc then return 0 end

	local parts = {
		Util.EncodeIntSet( doc.roads ),
		Util.EncodeIntSet( doc.hidden ),
		Util.EncodeIntSet( doc.hiddenProps ),
	}

	for _, z in ipairs( doc.renderZones ) do
		parts[#parts + 1] = string.format( "%d:%d:%s:%s", z.id, z.strict and 1 or 0, tostring( z.mins ), tostring( z.maxs ) )
	end

	for id, c in pairs( doc.faceColors ) do
		parts[#parts + 1] = id .. "#" .. c.r .. "," .. c.g .. "," .. c.b
	end

	for id, t in pairs( doc.faceTints ) do
		parts[#parts + 1] = id .. "%" .. t
	end

	for id, e in pairs( doc.propEdits or {} ) do
		parts[#parts + 1] = string.format( "%d@%s:%s:%.3f", id, tostring( e.pos ), tostring( e.ang ), e.scale or 1 )
	end

	table.sort( parts )
	return Util.Hash( table.concat( parts, "|" ) )
end

function MapData.NextId( list )
	local highest = 0
	for _, obj in ipairs( list ) do
		if obj.id > highest then highest = obj.id end
	end
	return highest + 1
end

function MapData.FindById( list, id )
	for i, obj in ipairs( list ) do
		if obj.id == id then return obj, i end
	end
	return nil
end

local function boxFootprint( zone )
	return {
		Vector( zone.mins.x, zone.mins.y, zone.mins.z ),
		Vector( zone.maxs.x, zone.mins.y, zone.mins.z ),
		Vector( zone.maxs.x, zone.maxs.y, zone.mins.z ),
		Vector( zone.mins.x, zone.maxs.y, zone.mins.z ),
	}
end

function MapData.GetZoneFootprint( zone, circleSegments )
	local shape = normalizeZoneShape( zone.shape )

	if shape == "polygon" and #( zone.points or {} ) >= 3 then
		return zone.points
	end

	if shape == "circle" then
		local center = ( zone.mins + zone.maxs ) * 0.5
		local radius = math.max( math.min( zone.maxs.x - zone.mins.x,
			zone.maxs.y - zone.mins.y ) * 0.5, 4 )
		local points = {}
		local segments = Util.Clamp( math.floor( circleSegments or 36 ), 12, 64 )

		for index = 1, segments do
			local angle = ( index - 1 ) / segments * math.pi * 2
			points[index] = Vector(
				center.x + math.cos( angle ) * radius,
				center.y + math.sin( angle ) * radius,
				zone.mins.z
			)
		end

		return points
	end

	return boxFootprint( zone )
end

function MapData.PointInPolygon2D( points, x, y )
	local inside = false
	local previous = #points

	for current = 1, #points do
		local a, b = points[current], points[previous]
		local crosses = ( a.y > y ) ~= ( b.y > y )

		if crosses then
			local edgeX = ( b.x - a.x ) * ( y - a.y ) / ( b.y - a.y ) + a.x
			if x < edgeX then inside = not inside end
		end

		previous = current
	end

	return inside
end

function MapData.ZoneContainsXY( zone, x, y )
	local shape = normalizeZoneShape( zone.shape )

	if shape == "box" then
		return x >= zone.mins.x and x <= zone.maxs.x
			and y >= zone.mins.y and y <= zone.maxs.y
	end

	if shape == "circle" then
		local center = ( zone.mins + zone.maxs ) * 0.5
		local radius = math.max( math.min( zone.maxs.x - zone.mins.x,
			zone.maxs.y - zone.mins.y ) * 0.5, 4 )
		local dx, dy = x - center.x, y - center.y
		return dx * dx + dy * dy <= radius * radius
	end

	return MapData.PointInPolygon2D( MapData.GetZoneFootprint( zone ), x, y )
end

function MapData.PointInZone( zone, pos )
	return pos.z >= zone.mins.z and pos.z <= zone.maxs.z
		and MapData.ZoneContainsXY( zone, pos.x, pos.y )
end

function MapData.GetZoneArea( zone )
	local shape = normalizeZoneShape( zone.shape )

	if shape == "box" then
		return math.abs( ( zone.maxs.x - zone.mins.x ) * ( zone.maxs.y - zone.mins.y ) )
	end

	if shape == "circle" then
		local radius = math.max( math.min( zone.maxs.x - zone.mins.x,
			zone.maxs.y - zone.mins.y ) * 0.5, 4 )
		return math.pi * radius * radius
	end

	local points = MapData.GetZoneFootprint( zone )
	local twiceArea = 0

	for index = 1, #points do
		local nextIndex = index % #points + 1
		twiceArea = twiceArea + points[index].x * points[nextIndex].y
			- points[nextIndex].x * points[index].y
	end

	return math.abs( twiceArea ) * 0.5
end

function MapData.GetZoneCenter( zone )
	local points = MapData.GetZoneFootprint( zone )
	local x, y = 0, 0

	for _, point in ipairs( points ) do
		x = x + point.x
		y = y + point.y
	end

	local count = math.max( #points, 1 )
	return Vector( x / count, y / count, zone.mins.z )
end

function MapData.RenderZoneIdAt( list, pos )
	if not list or #list == 0 then return 0 end

	local zone = MapData.FindZoneAt( list, pos )
	return zone and zone.id or 0
end

function MapData.DisplayName( obj )
	local name = obj and obj.name or ""
	if name ~= "" then return name end
	return DM.L( "no name" )
end

function MapData.FindZoneAt( list, pos )
	local best, bestVolume = nil, math.huge

	for _, zone in ipairs( list ) do
		if MapData.PointInZone( zone, pos ) then
			local volume = MapData.GetZoneArea( zone ) * math.max( zone.maxs.z - zone.mins.z, 1 )
			if volume < bestVolume then
				best, bestVolume = zone, volume
			end
		end
	end

	return best
end

function MapData.FindZonesAt( list, pos )
	local out = {}
	for _, zone in ipairs( list ) do
		if MapData.PointInZone( zone, pos ) then
			out[#out + 1] = zone
		end
	end

	table.sort( out, function( a, b )
		local aVolume = MapData.GetZoneArea( a ) * math.max( a.maxs.z - a.mins.z, 1 )
		local bVolume = MapData.GetZoneArea( b ) * math.max( b.maxs.z - b.mins.z, 1 )
		return aVolume < bVolume
	end )

	return out
end

function MapData.IsStale( doc )
	if not doc then return false end
	local current = MapData.GetMapRevision()
	if current == 0 or ( doc.mapRevision or 0 ) == 0 then return false end
	return doc.mapRevision ~= current
end

function MapData.IsEmpty( doc )
	if not doc then return true end
	return next( doc.roads ) == nil
		and next( doc.hidden ) == nil
		and next( doc.propEdits or {} ) == nil
		and next( doc.faceColors ) == nil
		and next( doc.faceTints ) == nil
		and #doc.zones == 0
		and #doc.renderZones == 0
		and #doc.pois == 0
end

function MapData.Describe( doc )
	if not doc then return "no data" end
	return string.format( "rev %d | %d roads | %d zones | %d render zones | %d waypoints",
		doc.revision or 0,
		Util.CountSet( doc.roads ),
		#doc.zones, #doc.renderZones, #doc.pois )
end
