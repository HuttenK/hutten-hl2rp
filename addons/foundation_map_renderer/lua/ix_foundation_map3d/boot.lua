-- Terminal-only adapter for the imported geometry engine. No minimap UI or
-- public telemetry is loaded; the Foundation terminal owns access and data.
local DM=ix.FoundationMap3D
if DM and DM.loaded then return DM end
DM={VERSION="3.0.0-terminal-1",DATA_VERSION=1,activeUntil=0,progress=0}
ix.FoundationMap3D=DM
function DM.IsActive() return RealTime()<DM.activeUntil end
function DM.Msg(...) MsgC(Color(90,210,225),"[Terminal map] ",color_white,...,"\n") end
function DM.Warn(...) ErrorNoHalt("[Terminal map] "..table.concat({...}," ").."\n") end
DM.Loading={IsFullscreen=function() return false end,Show=function() DM.progress=0 end,
 SetProgress=function(value) DM.progress=value end,Hide=function() end}
-- Marker systems are deliberately absent. Renderer callers explicitly disable
-- them; a non-nil filter keeps the generic renderer's comparison unambiguous.
DM.RenderZones={Filter=function() return true end}
include("ix_foundation_map3d/config.lua")
local modules={"shared/sh_enums.lua","shared/sh_util.lua","shared/sh_themes.lua","shared/sh_mapdata.lua",
 "client/geometry/cl_materials.lua","client/geometry/cl_surface_colours.lua","client/geometry/cl_water.lua",
 "client/geometry/cl_extract.lua","client/geometry/cl_relief.lua","client/geometry/cl_spatial.lua",
 "client/geometry/cl_surface_query.lua","client/geometry/cl_props.lua","client/geometry/cl_bake_cache.lua",
 "client/geometry/cl_bake.lua","client/render/cl_camera.lua","client/render/cl_native_props.lua","client/render/cl_renderer.lua"}
for _,path in ipairs(modules) do include("ix_foundation_map3d/vendor/"..path) end
local document=DM.MapData.CreateEmpty()
function DM.MapData.Get() return document end
DM.loaded=true
return DM
