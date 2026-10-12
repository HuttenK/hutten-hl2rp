-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D

DM.Relief = DM.Relief or {}
local Relief = DM.Relief
local SUN = Vector( -0.55, -0.65, 0.52 ):GetNormalized()

function Relief.IsTerrain( rec )
	return DM.SURFACE_TERRAIN[rec.class] == true
		or ( rec.disp and rec.class ~= DM.SURFACE.WATER
			and rec.class ~= DM.SURFACE.GLASS and rec.class ~= DM.SURFACE.ROAD
			and rec.class ~= DM.SURFACE.CEILING )
end

local function vertexKey( pos )
	return math.floor( pos.x * 16 + 0.5 ) .. ":"
		.. math.floor( pos.y * 16 + 0.5 ) .. ":" .. math.floor( pos.z * 16 + 0.5 )
end

function Relief.TriangleNormal( a, b, c, reference )
	local normal = ( b - a ):Cross( c - a )
	if normal:LengthSqr() < 0.0001 then return reference end

	if reference and normal:Dot( reference ) < 0 then normal = -normal end
	normal:Normalize()
	return normal
end

function Relief.BuildNormals( records, hidden, yielder )
	local field = {}
	for i, rec in ipairs( records ) do
		if rec.disp and Relief.IsTerrain( rec ) and not hidden[rec.id] then
			local positions = DM.Extract.GetTrianglePositions( rec ) or {}
			for j = 1, #positions - 2, 3 do
				local a, b, c = positions[j], positions[j + 1], positions[j + 2]
				local normal = ( b - a ):Cross( c - a )
				if normal:Dot( rec.normal ) < 0 then normal = -normal end
				if normal:LengthSqr() > 0.0001 then
					for k = j, j + 2 do
						local key = vertexKey( positions[k] )
						field[key] = field[key] and field[key] + normal or Vector( normal )
					end
				end
			end
		end
		if i % 32 == 0 then yielder( 0.39, "shading terrain" ) end
	end
	for _, normal in pairs( field ) do normal:Normalize() end
	return field
end

function Relief.VertexNormal( field, pos, fallback )
	local normal = field and field[vertexKey( pos )]

	if normal and normal:Dot( fallback ) > 0.5 then return normal end
	return fallback
end

function Relief.Shade( normal, strength )
	local light = normal:Dot( SUN ) - SUN.z
	local slope = 1 - math.abs( normal.z )

	return math.Clamp( 1 + strength * ( 0.65 * light - 0.18 * slope ), 0.62, 1.16 )
end
