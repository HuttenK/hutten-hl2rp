-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D

DM.Assets = DM.Assets or {}
local Assets = DM.Assets

local WHITE_CANDIDATES = { "vgui/white", "color/white", "white", "models/debug/debugwhite" }

local function tryCreate( name, shader, params )
	local mat = CreateMaterial( name, shader, params )
	if not mat then return nil end

	local tex = mat:GetTexture( "$basetexture" )
	if not tex or tex:IsError() then return nil end

	return mat
end

local function createWhite( name, shader, extra )
	for i, texture in ipairs( WHITE_CANDIDATES ) do
		local params = {
			["$basetexture"] = texture,
			["$model"]       = 1,
		}

		for key, value in pairs( extra or {} ) do params[key] = value end

		local mat = tryCreate( name .. "_" .. i, shader, params )
		if mat then return mat end
	end

	DM.Warn( "no usable white texture found; falling back to an unverified material for ", name )
	return CreateMaterial( name .. "_fallback", shader, { ["$basetexture"] = "vgui/white", ["$model"] = 1 } )
end

Assets.World = createWhite( "ix_ftmap_world", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 0,
} )

Assets.WorldTranslucent = createWhite( "ix_ftmap_world_trans", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
} )

Assets.WorldInterior = createWhite( "ix_ftmap_world_interior", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 0,
	["$color2"]      = "[0.42 0.42 0.46]",
} )

Assets.Additive = createWhite( "ix_ftmap_additive", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$additive"]    = 1,
	["$translucent"] = 1,
} )

Assets.Overlay = createWhite( "ix_ftmap_overlay", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
	["$ignorez"]     = 1,
} )

Assets.Marker = createWhite( "ix_ftmap_marker", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
	["$ignorez"]     = 1,
	["$nocull"]      = 1,
} )

Assets.ZoneOverlay = createWhite( "ix_ftmap_zone_overlay_v2", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
	["$nocull"]      = 1,
} )

Assets.ZoneOutline = createWhite( "ix_ftmap_zone_outline_v2", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
	["$additive"]    = 1,
	["$nocull"]      = 1,
} )

hook.Remove( "PreRender", "ix_ftmap_water_material" )
Assets.Water = createWhite( "ix_ftmap_water_flat_v2", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 0,
} )

local themedMaterials = {}
local mapTextureMaterials = {}

function Assets.GetThemedMaterial( base, theme, kind )
	local colour = theme and theme.render and theme.render[kind]
	if not colour then return base end

	local role
	local translucent = false
	local scale = 1

	if base == Assets.WorldInterior then
		role = "interior"
		scale = 0.42
	elseif base == Assets.Water then
		role = "water"
	elseif base == Assets.WorldTranslucent then
		role = "translucent"
		translucent = true
	else
		role = "world"
	end

	local key = string.format( "%s_%s_%s_%d_%d_%d",
		theme.id or "theme", kind or "surface", role, colour.r, colour.g, colour.b )
	local cached = themedMaterials[key]
	if cached then return cached end

	local red = colour.r / 255 * scale
	local green = colour.g / 255 * scale
	local blue = colour.b / 255 * scale
	local params = {
		["$vertexcolor"] = 1,
		["$vertexalpha"] = translucent and 1 or 0,
		["$color2"] = string.format( "[%.4f %.4f %.4f]", red, green, blue ),
	}

	if translucent then params["$translucent"] = 1 end

	cached = createWhite( "ix_ftmap_theme_" .. key, "UnlitGeneric", params )
	themedMaterials[key] = cached
	return cached
end

function Assets.GetMapTextureMaterial( materialName, translucent, preserveSourceAlpha )
	materialName = string.lower( tostring( materialName or "" ) )
	local key = materialName .. "|" .. ( translucent and "1" or "0" )
		.. "|" .. ( preserveSourceAlpha and "1" or "0" )
	local cached = mapTextureMaterials[key]
	if cached ~= nil then
		return cached or ( translucent and Assets.WorldTranslucent or Assets.World )
	end

	local source = materialName ~= "" and Material( materialName ) or nil
	local texture = source and not source:IsError() and source:GetTexture( "$basetexture" ) or nil

	if not texture or texture:IsError() then
		mapTextureMaterials[key] = false
		return translucent and Assets.WorldTranslucent or Assets.World
	end

	local isAlphaTest = preserveSourceAlpha and source:GetInt( "$alphatest" ) ~= 0
	local isTranslucent = translucent
		or ( preserveSourceAlpha and source:GetInt( "$translucent" ) ~= 0 )
	local params = {
		["$basetexture"] = "color/white",
		["$model"] = 1,
		["$vertexcolor"] = 1,
		["$vertexalpha"] = ( isAlphaTest or isTranslucent ) and 1 or 0,
		["$translucent"] = isTranslucent and 1 or 0,
		["$alphatest"] = isAlphaTest and 1 or 0,
	}

	if isAlphaTest then
		params["$alphatestreference"] = source:GetFloat( "$alphatestreference" )
	end
	if source:GetInt( "$nocull" ) ~= 0 then params["$nocull"] = 1 end

	local material = CreateMaterial( "ix_ftmap_maptex_" .. util.CRC( key ), "UnlitGeneric", params )
	if not material then
		mapTextureMaterials[key] = false
		return translucent and Assets.WorldTranslucent or Assets.World
	end

	material:SetTexture( "$basetexture", texture )
	mapTextureMaterials[key] = material
	return material
end

Assets.Beam = createWhite( "ix_ftmap_beam", "UnlitGeneric", {
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$translucent"] = 1,
} )

local function font( name, size, weight, extra )
	local data = {
		font      = "Roboto",
		extended  = true,
		size      = size,
		weight    = weight or 500,
		antialias = true,
	}

	for key, value in pairs( extra or {} ) do data[key] = value end
	surface.CreateFont( name, data )
end

font( "IX_FTMAP_Tiny",   13, 500 )
font( "IX_FTMAP_Small",  16, 500 )
font( "IX_FTMAP_Text",   18, 500 )
font( "IX_FTMAP_Label",  20, 600 )
font( "IX_FTMAP_Title",  26, 700 )
font( "IX_FTMAP_Big",    38, 700 )
font( "IX_FTMAP_Huge",   54, 800 )
font( "IX_FTMAP_Mono",   16, 500, { font = "Consolas" } )

font( "IX_FTMAP_LabelOutline", 20, 600, { outline = true } )
font( "IX_FTMAP_ZoneLabelSmall", 16, 800 )
font( "IX_FTMAP_ZoneLabel3D", 96, 900 )
font( "IX_FTMAP_ZoneLabel3DMid", 64, 900 )
font( "IX_FTMAP_ZoneLabel3DSmall", 40, 900 )

local targets = {}

function Assets.GetRenderTarget( key, w, h )
	w, h = math.floor( w ), math.floor( h )

	local id = key .. "_" .. w .. "x" .. h
	local entry = targets[id]
	if entry then return entry.rt, entry.mat end

	local rtName = "ix_ftmap_rt_alpha_v2_" .. id
	local rt = GetRenderTarget( rtName, w, h )

	local mat = CreateMaterial( "ix_ftmap_rtmat_alpha_v2_" .. id, "UnlitGeneric", {
		["$basetexture"] = rt:GetName(),
		["$vertexcolor"] = 1,
		["$vertexalpha"] = 1,
		["$translucent"] = 1,
		["$ignorez"]     = 1,
	} )

	entry = { rt = rt, mat = mat }
	targets[id] = entry

	return rt, mat
end
