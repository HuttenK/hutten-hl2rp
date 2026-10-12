-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Assets = DM.Assets
local sourceMap, colours = nil, {}
local blends, textureColours = {}, {}

local function valid( value )
	return type( value ) == "number" and value == value and value >= 0 and value < math.huge
end

local function channel( value )

	return math.floor( math.min( value, 1 ) ^ ( 1 / 2.2 ) * 255 + 0.5 )
end

local function paletteColour( r, g, b )

	r, g, b = channel( r ), channel( g ), channel( b )
	local grey = r * 0.299 + g * 0.587 + b * 0.114
	return Color( math.floor( 24 + 0.8 * ( grey + ( r - grey ) * 0.9 ) + 0.5 ),
		math.floor( 24 + 0.8 * ( grey + ( g - grey ) * 0.9 ) + 0.5 ),
		math.floor( 24 + 0.8 * ( grey + ( b - grey ) * 0.9 ) + 0.5 ) )
end

function Assets.PrepareSurfaceColours( yielder )
	local map = NikNaks.CurrentMap
	if map == sourceMap then return end
	colours = {}
	blends, textureColours = {}, {}
	if not map then sourceMap = nil; return end
	local ok, data = pcall( map.GetTexData, map )
	if not ok or type( data ) ~= "table" then return end
	local count = 0
	for _, item in pairs( data ) do
		local rgb, name = item.reflectivity, item.nameStringTableID
		if type( name ) == "string" and rgb and valid( rgb.x ) and valid( rgb.y ) and valid( rgb.z ) then
			colours[string.lower( name )] = paletteColour( rgb.x, rgb.y, rgb.z )
		end
		count = count + 1
		if yielder and count % 128 == 0 then yielder( 0.39, "preparing surface colours" ) end
	end
	sourceMap = map
end

function Assets.GetSurfaceColour( materialName )
	return colours[string.lower( materialName or "" )]
end

local function textureColour( name )
	name = string.lower( name or "" ):gsub( "\\", "/" ):gsub( "^materials/", "" ):gsub( "%.vtf$", "" )
	if textureColours[name] ~= nil then return textureColours[name] or nil end
	local colour
	local f = file.Open( "materials/" .. name .. ".vtf", "rb", "GAME" )
	if f then

		if f:Size() >= 48 and f:Read( 4 ) == "VTF\0" and f:ReadULong() == 7 then
			f:Seek( 32 )
			local r, g, b = f:ReadFloat(), f:ReadFloat(), f:ReadFloat()
			if valid( r ) and valid( g ) and valid( b ) then
				colour = paletteColour( r, g, b )
			end
		end
		f:Close()
	end

	colour = colour or colours[name]
	textureColours[name] = colour or false
	return colour
end

function Assets.GetSurfaceBlendColour( materialName )
	local name = string.lower( materialName or "" )
	if blends[name] ~= nil then return blends[name] or nil end
	blends[name] = false
	local source = Material( name )
	if not source or source:IsError() then return end

	local shader = string.lower( source:GetShader() or "" )
	if shader ~= "worldvertextransition" and not shader:match( "^worldvertextransition_dx%d+$" ) then return end
	local texture = source:GetTexture( "$basetexture2" )
	local colour = textureColour( texture and texture:GetName() or source:GetString( "$basetexture2" ) )
	if not colour then return end
	blends[name] = colour
	return colour
end
