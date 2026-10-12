-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D

DM.SURF = {
	LIGHT     = 0x1,
	SKY2D     = 0x2,
	SKY       = 0x4,
	WARP      = 0x8,
	TRANS     = 0x10,
	NOPORTAL  = 0x20,
	TRIGGER   = 0x40,
	NODRAW    = 0x80,
	HINT      = 0x100,
	SKIP      = 0x200,
	NOLIGHT   = 0x400,
	BUMPLIGHT = 0x800,
	NOSHADOWS = 0x1000,
	NODECALS  = 0x2000,
	NOCHOP    = 0x4000,
	HITBOX    = 0x8000,
}

DM.SURFACE = {
	GROUND   = 1,
	GRASS    = 2,
	DIRT     = 3,
	ROCK     = 4,
	SAND     = 5,
	SNOW     = 6,
	WOOD     = 7,
	BRICK    = 8,
	CONCRETE = 9,
	METAL    = 10,
	WALL     = 11,
	ROOF     = 12,
	CEILING  = 13,
	ROAD     = 14,
	WATER    = 15,
	GLASS    = 16,
}

DM.SURFACE_NAME = {
	[DM.SURFACE.GROUND]   = "Pavement",
	[DM.SURFACE.GRASS]    = "Grass",
	[DM.SURFACE.DIRT]     = "Dirt",
	[DM.SURFACE.ROCK]     = "Rock",
	[DM.SURFACE.SAND]     = "Sand",
	[DM.SURFACE.SNOW]     = "Snow",
	[DM.SURFACE.WOOD]     = "Wood",
	[DM.SURFACE.BRICK]    = "Brick",
	[DM.SURFACE.CONCRETE] = "Concrete",
	[DM.SURFACE.METAL]    = "Metal",
	[DM.SURFACE.WALL]     = "Wall",
	[DM.SURFACE.ROOF]     = "Roof",
	[DM.SURFACE.CEILING]  = "Ceiling",
	[DM.SURFACE.ROAD]     = "Road",
	[DM.SURFACE.WATER]    = "Water",
	[DM.SURFACE.GLASS]    = "Glass",
}

DM.SURFACE_TERRAIN = {
	[DM.SURFACE.GRASS] = true,
	[DM.SURFACE.DIRT]  = true,
	[DM.SURFACE.ROCK]  = true,
	[DM.SURFACE.SAND]  = true,
	[DM.SURFACE.SNOW]  = true,
}

DM.SURFACE_HORIZONTAL = {
	[DM.SURFACE.GROUND] = true,
	[DM.SURFACE.GRASS]  = true,
	[DM.SURFACE.DIRT]   = true,
	[DM.SURFACE.ROCK]   = true,
	[DM.SURFACE.SAND]   = true,
	[DM.SURFACE.SNOW]   = true,
	[DM.SURFACE.ROAD]   = true,
	[DM.SURFACE.WATER]  = true,
	[DM.SURFACE.ROOF]   = true,
}

DM.BATCH = {
	OPAQUE = 1,
	ROAD   = 2,
	PROP   = 3,
	WATER  = 4,
	GLASS  = 5,
	PROP_COARSE = 6,
	TERRAIN = 7,
}

DM.BATCH_ORDER = {
	DM.BATCH.OPAQUE,
	DM.BATCH.TERRAIN,
	DM.BATCH.ROAD,
	DM.BATCH.PROP,
	DM.BATCH.PROP_COARSE,
	DM.BATCH.WATER,
	DM.BATCH.GLASS,
}

DM.EDITOR_MODE = {
	OBJECT = 1,
	FACE   = 2,
}

DM.TOOL = {
	MOVE    = 1,
	ROTATE  = 2,
	SCALE   = 3,
	ADD     = 4,
	DELETE  = 5,
	TINT    = 6,
	COLOR   = 7,
	ROAD    = 8,
	ISOLATE = 9,
	VIEW    = 10,
	FLYCAM  = 11,
	LAYERS  = 12,
}

DM.OBJ = {
	ZONE       = 1,
	RENDERZONE = 2,
	POI        = 3,
	PROP       = 4,
}

DM.OBJ_NAME = {
	[DM.OBJ.ZONE]       = "Overlay zone",
	[DM.OBJ.RENDERZONE] = "Render zone",
	[DM.OBJ.POI]        = "Waypoint",
	[DM.OBJ.PROP]       = "Static prop",
}

DM.LAYER = {
	WORLD      = 1,
	TERRAIN    = 2,
	ROADS      = 3,
	WATER      = 4,
	PROPS      = 5,
	ZONES      = 6,
	RENDERZONE = 7,
	POI        = 8,
}

DM.LAYER_NAME = {
	[DM.LAYER.WORLD]      = "World brushes",
	[DM.LAYER.TERRAIN]    = "Terrain",
	[DM.LAYER.ROADS]      = "Roads",
	[DM.LAYER.WATER]      = "Water",
	[DM.LAYER.PROPS]      = "Props",
	[DM.LAYER.ZONES]      = "Overlay zones",
	[DM.LAYER.RENDERZONE] = "Render zones",
	[DM.LAYER.POI]        = "Waypoints",
}

DM.LAYER_ORDER = {
	DM.LAYER.WORLD, DM.LAYER.TERRAIN, DM.LAYER.ROADS, DM.LAYER.WATER,
	DM.LAYER.PROPS, DM.LAYER.ZONES, DM.LAYER.RENDERZONE, DM.LAYER.POI,
}

DM.NAV_MODE = {
	WALK    = 1,
	VEHICLE = 2,
}

DM.NAV_SOURCE = {
	NAVMESH   = 1,
	NODEGRAPH = 2,
	GRID      = 3,
	DIRECT    = 4,
}

DM.NAV_SOURCE_NAME = {
	[DM.NAV_SOURCE.NAVMESH]   = "navmesh",
	[DM.NAV_SOURCE.NODEGRAPH] = "node graph",
	[DM.NAV_SOURCE.GRID]      = "terrain grid",
	[DM.NAV_SOURCE.DIRECT]    = "direct",
}

DM.NET = {
	MAPDATA_REQUEST = "ix_ftmap_mapdata_request",
	MAPDATA         = "ix_ftmap_mapdata",
	MAPDATA_SAVE    = "ix_ftmap_mapdata_save",
	MAPDATA_SAVED   = "ix_ftmap_mapdata_saved",
	EDITOR_OPEN     = "ix_ftmap_editor_open",
	EDITOR_REQUEST  = "ix_ftmap_editor_request",
	NAV_REQUEST     = "ix_ftmap_nav_request",
	NAV_RESULT      = "ix_ftmap_nav_result",
	NAV_CLEAR       = "ix_ftmap_nav_clear",
	THEME_SYNC      = "ix_ftmap_theme_sync",
	WAYPOINT_SET    = "ix_ftmap_waypoint_set",
	WAYPOINTS       = "ix_ftmap_waypoints",
}

if SERVER then
	for _, name in pairs( DM.NET ) do
		util.AddNetworkString( name )
	end
end
