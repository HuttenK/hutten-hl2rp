-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Assets = DM.Assets
local materials = {}

local function mergePatch( parent, patch, replace )
	for key, value in pairs( patch or {} ) do
		if istable( value ) and istable( parent[key] ) then
			mergePatch( parent[key], value, replace )
		elseif replace or parent[key] == nil then
			parent[key] = value
		end
	end
end

local function readVMT( name, seen )
	name = string.lower( name ):gsub( "^materials/", "" ):gsub( "%.vmt$", "" )
	seen = seen or {}
	if seen[name] then return {} end
	seen[name] = true
	local text = file.Read( "materials/" .. name .. ".vmt", "GAME" )
	local data = text and util.KeyValuesToTable( text ) or {}
	if not data then return {} end
	if not data.include then return data end
	local parent = readVMT( data.include, seen )
	mergePatch( parent, data.insert, false )
	mergePatch( parent, data.replace, true )
	return parent
end

local WATER_PARAMS = {
	"$normalmap", "$bumpmap", "$bumpframe", "$bumptransform", "$scale",
	"$envmap", "$envmapframe", "$reflecttint", "$reflectblendfactor",
	"$fogcolor", "$fogstart", "$fogend", "$waterdepth", "$abovewater",
	"$nofresnel", "$scroll1", "$scroll2", "$nocull",
	"$refractamount", "$refracttint", "$reflectamount", "$blurrefract",
}

function Assets.GetWaterMaterial( materialName )
	materialName = string.lower( tostring( materialName or "" ) )
	if materials[materialName] then return materials[materialName] end
	local source = Material( materialName )
	if source:IsError() or not string.find( string.lower( source:GetShader() or "" ), "water", 1, true ) then
		local fallback = Assets.GetMapTextureMaterial( materialName, true, true )
		materials[materialName] = fallback
		return fallback
	end

	local values = source:GetKeyValues()
	local vmt = readVMT( materialName )
	local params = {
		["$forcecheap"] = 1,
		["$forceexpensive"] = 0,
		["$nolowendlightmap"] = 1,
	}
	for _, key in ipairs( WATER_PARAMS ) do

		local value = vmt[key] or values[key]
		if isvector( value ) then
			params[key] = string.format( "[%g %g %g]", value.x, value.y, value.z )
		elseif type( value ) == "ITexture" then
			if not value:IsError() then params[key] = value:GetName() end
		elseif isstring( value ) or isnumber( value ) then
			params[key] = value
		end
	end
	params.Proxies = vmt.proxies
	local material = CreateMaterial( "ix_ftmap_mapwater_v4_" .. util.CRC( materialName ), source:GetShader(), params )

	for _, key in ipairs( { "$normalmap", "$envmap" } ) do
		local texture = values[key]
		if type( texture ) == "ITexture" and not texture:IsError() then material:SetTexture( key, texture ) end
	end
	materials[materialName] = material
	return material
end

function Assets.GetWaterTangents( a, b, c, normal )
	local edge1, edge2 = b.pos - a.pos, c.pos - a.pos
	local du1, dv1 = b.u - a.u, b.v - a.v
	local du2, dv2 = c.u - a.u, c.v - a.v
	local determinant = du1 * dv2 - du2 * dv1
	local tangent, bitangent
	if determinant == determinant and math.abs( determinant ) > 0.0000001 then
		tangent = ( edge1 * dv2 - edge2 * dv1 ) / determinant
		bitangent = ( edge2 * du1 - edge1 * du2 ) / determinant
		tangent = tangent - normal * normal:Dot( tangent )
	end
	if not tangent or tangent:LengthSqr() < 0.0000001 then
		local axis = math.abs( normal.z ) < 0.99 and Vector( 0, 0, 1 ) or Vector( 0, 1, 0 )
		tangent = axis:Cross( normal )
	end
	tangent:Normalize()
	local cross = normal:Cross( tangent )
	if bitangent and cross:Dot( bitangent ) < 0 then cross = -cross end
	return tangent, cross
end
