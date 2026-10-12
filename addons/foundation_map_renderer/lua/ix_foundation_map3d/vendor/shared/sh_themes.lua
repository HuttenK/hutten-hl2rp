-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Util = DM.Util

DM.Themes = DM.Themes or {}
local Themes = DM.Themes

Themes.List = {}
Themes.Order = {}

local SURFACE = DM.SURFACE

local SUN = Vector( -0.38, -0.46, 0.80 )
SUN:Normalize()

local MONO_EXEMPT = {
	[SURFACE.WATER] = true,
}

local SOLID = 128

local LUMA = {
	[SURFACE.GROUND]   = SOLID,
	[SURFACE.GRASS]    = SOLID,
	[SURFACE.DIRT]     = SOLID,
	[SURFACE.ROCK]     = SOLID,
	[SURFACE.SAND]     = SOLID,
	[SURFACE.SNOW]     = SOLID,
	[SURFACE.WOOD]     = SOLID,
	[SURFACE.BRICK]    = SOLID,
	[SURFACE.CONCRETE] = SOLID,
	[SURFACE.METAL]    = SOLID,
	[SURFACE.WALL]     = SOLID,
	[SURFACE.ROOF]     = 152,
	[SURFACE.CEILING]  = 68,
	[SURFACE.ROAD]     = 205,
	[SURFACE.GLASS]    = 150,
}

local FACING = {
	[SURFACE.CEILING] = 0.55,
}

local function register( theme )
	theme.surface = theme.surface or {}
	theme.facing = theme.facing or {}
	theme.shading = theme.shading or { lowGain = 0.35, highDrop = 0.5 }
	theme.ui = theme.ui or {}
	theme.monoStrength = theme.monoStrength or 1

	local lift = theme.lift or 1

	for class, level in pairs( LUMA ) do
		if not theme.surface[class] then
			local value = Util.Clamp( level * lift, 0, 246 )
			theme.surface[class] = Color( value, value, value, class == SURFACE.GLASS and 120 or 255 )
		end
	end

	for class in pairs( LUMA ) do
		if theme.facing[class] == nil then theme.facing[class] = FACING[class] or 1 end
	end

	theme.facing[SURFACE.WATER] = theme.facing[SURFACE.WATER] or 1

	theme.prop = theme.prop or Color( 132, 132, 136 )
	theme.tree = theme.tree or Color( 58, 104, 62 )

	theme.ui.accent    = theme.ui.accent    or Color( 90, 190, 255 )
	theme.ui.text      = theme.ui.text      or Color( 235, 240, 245 )
	theme.ui.textDim   = theme.ui.textDim   or Color( 150, 160, 172 )
	theme.ui.panel     = theme.ui.panel     or Color( 22, 26, 32, 235 )
	theme.ui.outline   = theme.ui.outline   or Color( 70, 80, 92 )
	theme.ui.player    = theme.ui.player    or Color( 255, 255, 255 )
	theme.ui.path      = theme.ui.path      or Color( 175, 110, 255 )
	theme.ui.poi       = theme.ui.poi       or Color( 255, 210, 90 )
	theme.ui.danger    = theme.ui.danger    or Color( 255, 130, 40 )
	theme.ui.selection = theme.ui.selection or Color( 255, 160, 30 )
	theme.ui.zone      = theme.ui.zone      or Color( 90, 220, 200 )

	Themes.List[theme.id] = theme
	Themes.Order[#Themes.Order + 1] = theme.id
	return theme
end

register{
	id = "standard",
	name = "Standard",
	background = Color( 12, 14, 18 ),
	monochrome = Color( 224, 228, 234 ),
	surface = {
		[SURFACE.WATER] = Color( 56, 116, 184, 210 ),
	},
	prop = Color( 138, 142, 150 ),
	tree = Color( 58, 104, 62 ),
	ui = {
		accent = Color( 90, 190, 255 ),
		path   = Color( 175, 110, 255 ),
	},
}

register{
	id = "fallout4",
	name = "Fallout 4",
	background = Color( 6, 14, 9 ),
	monochrome = Color( 122, 232, 148 ),
	shading = { lowGain = 0.42, highDrop = 0.58 },
	surface = {
		[SURFACE.WATER] = Color( 48, 150, 116, 210 ),
	},
	prop = Color( 108, 196, 124 ),
	tree = Color( 46, 112, 56 ),
	render = {
		world   = Color( 112, 238, 138 ),
		terrain = Color( 24, 76, 38 ),
		road    = Color( 174, 255, 190 ),
		prop    = Color( 82, 202, 108 ),
		water   = Color( 42, 166, 112 ),
		glass   = Color( 164, 255, 188 ),
	},
	ui = {
		accent  = Color( 128, 255, 154 ),
		text    = Color( 196, 255, 208 ),
		textDim = Color( 108, 178, 122 ),
		panel   = Color( 7, 20, 11, 240 ),
		outline = Color( 56, 138, 74 ),
		player  = Color( 220, 255, 224 ),
		path    = Color( 214, 255, 120 ),
		poi     = Color( 198, 255, 140 ),
		zone    = Color( 120, 232, 168 ),
	},
}

register{
	id = "alyx",
	name = "Half-Life: Alyx",
	background = Color( 9, 12, 18 ),
	monochrome = Color( 198, 216, 234 ),
	shading = { lowGain = 0.3, highDrop = 0.46 },
	surface = {
		[SURFACE.WATER] = Color( 50, 120, 190, 210 ),
	},
	prop = Color( 146, 164, 184 ),
	tree = Color( 54, 100, 64 ),
	render = {
		world   = Color( 76, 202, 214 ),
		terrain = Color( 14, 50, 66 ),
		road    = Color( 132, 238, 244 ),
		prop    = Color( 62, 166, 178 ),
		water   = Color( 24, 126, 178 ),
		glass   = Color( 142, 246, 252 ),
	},
	ui = {
		accent  = Color( 255, 146, 54 ),
		text    = Color( 226, 236, 246 ),
		textDim = Color( 138, 154, 172 ),
		panel   = Color( 11, 15, 22, 240 ),
		outline = Color( 62, 82, 104 ),
		player  = Color( 152, 244, 240 ),
		path    = Color( 255, 82, 52 ),
		poi     = Color( 255, 200, 120 ),
		zone    = Color( 120, 190, 230 ),
	},
}

register{
	id = "gta5",
	name = "GTA V",
	background = Color( 20, 31, 38 ),
	monochrome = Color( 238, 234, 222 ),
	lift = 1.38,
	shading = { lowGain = 0.24, highDrop = 0.38 },
	surface = {
		[SURFACE.WATER] = Color( 66, 148, 206, 225 ),
	},
	prop = Color( 168, 168, 160 ),
	tree = Color( 86, 126, 78 ),
	render = {
		world   = Color( 166, 170, 172 ),
		terrain = Color( 70, 76, 80 ),
		road    = Color( 248, 248, 244 ),
		prop    = Color( 132, 138, 142 ),
		water   = Color( 62, 116, 148 ),
		glass   = Color( 218, 228, 232 ),
	},
	ui = {
		accent  = Color( 236, 178, 44 ),
		text    = Color( 244, 242, 234 ),
		textDim = Color( 168, 176, 180 ),
		panel   = Color( 22, 34, 44, 240 ),
		outline = Color( 96, 132, 154 ),
		player  = Color( 250, 250, 244 ),
		path    = Color( 124, 208, 116 ),
		poi     = Color( 236, 178, 44 ),
		zone    = Color( 60, 170, 160 ),
	},
}

register{
	id = "cyberpunk",
	name = "Cyberpunk 2077",
	background = Color( 3, 6, 12 ),
	monochrome = Color( 210, 220, 232 ),
	shading = { lowGain = 0.22, highDrop = 0.38 },
	surface = {
		[SURFACE.WATER] = Color( 0, 150, 210, 220 ),
	},
	prop = Color( 170, 42, 50 ),
	tree = Color( 42, 88, 62 ),
	render = {
		world   = Color( 220, 52, 60 ),
		terrain = Color( 18, 34, 52 ),
		road    = Color( 0, 210, 255 ),
		prop    = Color( 190, 46, 54 ),
		water   = Color( 0, 176, 238 ),
		glass   = Color( 0, 226, 255 ),
	},
	ui = {
		accent  = Color( 252, 225, 49 ),
		text    = Color( 224, 238, 244 ),
		textDim = Color( 105, 128, 142 ),
		panel   = Color( 5, 9, 16, 245 ),
		outline = Color( 0, 142, 188 ),
		player  = Color( 0, 255, 170 ),
		path    = Color( 0, 220, 255 ),
		poi     = Color( 78, 126, 255 ),
		danger  = Color( 255, 58, 66 ),
		selection = Color( 252, 225, 49 ),
		zone    = Color( 0, 196, 232 ),
	},
}

function Themes.Get( id )
	return Themes.List[id] or Themes.List["standard"]
end

register{ id="foundation", name="Foundation", background=Color(5,13,20),
 monochrome=Color(216,237,243), render={world=Color(186,230,239),terrain=Color(116,161,181),road=Color(216,247,251),prop=Color(139,192,206),water=Color(53,125,161),glass=Color(125,217,226)} }
function Themes.GetActive() return Themes.Get("foundation") end
local function luminance( r, g, b )
	return ( 0.299 * r + 0.587 * g + 0.114 * b ) / 255
end

function Themes.AltitudeShade( theme, altitude, intensity, invert, scale )
	local shading = theme.shading
	scale = scale or 1

	local low  = 1 + intensity * shading.lowGain * scale
	local high = 1 - intensity * shading.highDrop * scale

	if invert then low, high = high, low end

	return Util.Lerp( altitude, low, high )
end

function Themes.FaceShade( normal, strength )
	if not normal or strength <= 0 then return 1 end

	local sun = normal.x * SUN.x + normal.y * SUN.y + normal.z * SUN.z
	local slope = math.abs( normal.z )
	local steep = 1 - slope

	local light = 1 + strength * 0.42 * sun
	local tilt = 1 - strength * 0.55 * steep * ( 0.5 + steep * 0.5 )

	return math.max( light * tilt, 0.18 )
end

function Themes.ResolveFaceBase( theme, class, tint, override )
	local base = override or theme.surface[class] or theme.surface[SURFACE.GROUND]

	local mul = theme.facing[class] or 1
	if tint and tint ~= 0 then mul = mul * ( 1 + tint ) end

	local r, g, b = base.r * mul, base.g * mul, base.b * mul

	if theme.monochrome and not override and not MONO_EXEMPT[class] then
		local lum = luminance( r, g, b )
		local m = theme.monochrome
		local strength = theme.monoStrength
		r = Util.Lerp( strength, r, m.r * lum )
		g = Util.Lerp( strength, g, m.g * lum )
		b = Util.Lerp( strength, b, m.b * lum )
	end

	return r, g, b, base.a or 255
end

function Themes.ResolveProp( theme, isTree, altitude, intensity, invert )
	local base = isTree and theme.tree or theme.prop
	local shade = Themes.AltitudeShade( theme, altitude, intensity, invert, isTree and 0.35 or 0.7 )

	local r, g, b = base.r * shade, base.g * shade, base.b * shade

	if theme.monochrome and not isTree then
		local lum = luminance( r, g, b )
		local m = theme.monochrome
		local strength = theme.monoStrength
		r = Util.Lerp( strength, r, m.r * lum )
		g = Util.Lerp( strength, g, m.g * lum )
		b = Util.Lerp( strength, b, m.b * lum )
	end

	return Util.Clamp( r, 0, 255 ), Util.Clamp( g, 0, 255 ), Util.Clamp( b, 0, 255 )
end

function Themes.GetSwatches( theme )
	if theme.render then
		return {
			theme.render.road,
			theme.render.world,
			theme.render.terrain,
			theme.render.prop,
			theme.render.water,
			theme.tree,
		}
	end

	local out = {}

	local classes = { SURFACE.ROAD, SURFACE.WALL, SURFACE.GROUND, SURFACE.ROCK, SURFACE.WATER }

	for i, class in ipairs( classes ) do
		local r, g, b = Themes.ResolveFaceBase( theme, class, nil, nil )
		out[i] = Color( r, g, b )
	end

	out[#out + 1] = theme.tree
	return out
end
