-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Util = DM.Util
local Bake = DM.Bake
local BATCH = DM.BATCH

DM.Renderer = DM.Renderer or {}
local Renderer = DM.Renderer

local visible = {}

local function startView( view )
	local x, y = view.x or 0, view.y or 0

	if view.ortho then
		local halfW = view.ortho * ( view.aspect or ( view.w / math.max( view.h, 1 ) ) )

		local pullback = view.zfar
		local origin = view.origin - view.angles:Forward() * pullback

		cam.Start{
			type   = "3D",
			origin = origin,
			angles = view.angles,
			aspect = view.aspect,
			x = x, y = y, w = view.w, h = view.h,
			znear  = 1,
			zfar   = view.zfar + pullback,
			ortho  = {
				left   = -halfW,
				right  =  halfW,
				top    = -view.ortho,
				bottom =  view.ortho,
			},
		}
		return
	end

	cam.Start3D( view.origin, view.angles, view.fov, x, y, view.w, view.h, view.znear, view.zfar )
end

local function endView()
	cam.End3D()
end

local function cullChunks( view, clipZ, zoneFilter )
	local chunks = Bake.Chunks
	local frustum = view.frustum
	local inverted = DM.Config.Get( "ix_ftmap_cl_clip_invert" )
	local n = 0

	for i = 1, #chunks do
		local chunk = chunks[i]

		local pass = true

		if zoneFilter and not zoneFilter( chunk.zone ) then
			pass = false
		elseif clipZ and ( ( not inverted and chunk.mins.z > clipZ )
			or ( inverted and chunk.maxs.z < clipZ ) ) then
			pass = false
		elseif not Util.BoxInFrustum( frustum, chunk.mins, chunk.maxs ) then
			pass = false
		end

		if pass then
			n = n + 1
			visible[n] = chunk
		end
	end

	for i = n + 1, #visible do visible[i] = nil end

	return n
end

local overrideMaterial = nil
local activeTheme = nil
local activeThemeKind = nil

local function applyThemeModulation( kind )
	local theme = activeTheme or DM.Themes.GetActive()
	local colour = theme.render and theme.render[kind]
	local red, green, blue

	activeThemeKind = kind

	if colour then
		red, green, blue = 1, 1, 1
	else
		colour = theme.monochrome or color_white
		local peak = math.max( colour.r, colour.g, colour.b, 1 )
		red, green, blue = colour.r / peak, colour.g / peak, colour.b / peak
	end

	render.SetColorModulation( red, green, blue )
end

local function themedMaterial( material )
	if overrideMaterial then return overrideMaterial end
	return DM.Assets.GetThemedMaterial( material, activeTheme, activeThemeKind )
end

local function drawBatch( count, batch, material, forceMaterial )
	local fallbackMaterial = themedMaterial( material )
	render.SetMaterial( fallbackMaterial )

	for i = 1, count do
		local chunk = visible[i]
		local list = chunk.batches[batch]
		local materials = not forceMaterial and chunk.batchMaterials
			and chunk.batchMaterials[batch] or nil

		if list then
			for j = 1, #list do
				if materials then
					local selectedMaterial = materials[j]

					if selectedMaterial == DM.Assets.World
						or selectedMaterial == DM.Assets.WorldTranslucent then
						if activeThemeKind then applyThemeModulation( activeThemeKind ) end
						render.SetMaterial( fallbackMaterial )
					else
						render.SetColorModulation( 1, 1, 1 )
						render.SetMaterial( selectedMaterial or fallbackMaterial )
					end
				end

				list[j]:Draw()
			end
		end
	end

end

function Renderer.DrawScene( view, opts, preserveTargetAlpha )
	opts = opts or {}

	if not Bake.IsReady() then

		startView( view )
		endView()
		return
	end

	local layers = opts.layers
	local function layerOn( id )
		if not layers then return true end
		return layers[id] ~= false
	end

	overrideMaterial = opts.overrideMaterial

	if opts.zoneFilter == DM.RenderZones.Filter then
		DM.RenderZones.PrepareFilter()
	end
	local count = cullChunks( view, opts.clipZ, opts.zoneFilter )

	activeTheme = DM.Themes.GetActive()

	startView( view )
	local clippingWasEnabled, clipCount, flashlight = false, 0, false
	local ok, failure = xpcall(function()
	render.PushFlashlightMode( false ); flashlight=true
	if preserveTargetAlpha then render.SetWriteDepthToDestAlpha( false ) end
	render.ClearDepth()

	
	if opts.clipZ then
		clippingWasEnabled = render.EnableClipping( true )

		if DM.Config.Get( "ix_ftmap_cl_clip_invert" ) then
			render.PushCustomClipPlane( Util.VEC_UP, opts.clipZ )
		else
			render.PushCustomClipPlane( Util.VEC_DOWN, -opts.clipZ )
		end
	end

	if opts.clipZ then clipCount=clipCount+1 end
	if opts.clipLow then
		if clipCount==0 then clippingWasEnabled=render.EnableClipping(true) end
		render.PushCustomClipPlane(Util.VEC_UP,opts.clipLow);clipCount=clipCount+1
	end
	if layerOn( DM.LAYER.WORLD ) then
		applyThemeModulation( "world" )
		drawBatch( count, BATCH.OPAQUE, DM.Assets.World )
	end

	if layerOn( DM.LAYER.TERRAIN ) then
		applyThemeModulation( "terrain" )
		drawBatch( count, BATCH.TERRAIN, DM.Assets.World )
	end

	if layerOn( DM.LAYER.ROADS ) then
		applyThemeModulation( "road" )
		drawBatch( count, BATCH.ROAD, DM.Assets.World )
	end

	if opts.props ~= false and layerOn( DM.LAYER.PROPS ) and DM.Config.Get( "ix_ftmap_cl_props" ) then
		applyThemeModulation( "prop" )
		DM.NativeProps.Draw( view, opts )
	end

	if layerOn( DM.LAYER.WORLD ) then
		applyThemeModulation( "glass" )
		render.CullMode( MATERIAL_CULLMODE_CW )
		drawBatch( count, BATCH.GLASS, DM.Assets.World, true )
		render.CullMode( MATERIAL_CULLMODE_CCW )
		drawBatch( count, BATCH.GLASS, DM.Assets.World, true )
	end

	if opts.clipZ then
		render.CullMode( MATERIAL_CULLMODE_CW )

		if layerOn( DM.LAYER.WORLD ) then
			applyThemeModulation( "world" )
			drawBatch( count, BATCH.OPAQUE, DM.Assets.WorldInterior )
		end

		if layerOn( DM.LAYER.TERRAIN ) then
			applyThemeModulation( "terrain" )
			drawBatch( count, BATCH.TERRAIN, DM.Assets.WorldInterior )
		end

		if layerOn( DM.LAYER.ROADS ) then
			applyThemeModulation( "road" )
			drawBatch( count, BATCH.ROAD, DM.Assets.WorldInterior )
		end

		if layerOn( DM.LAYER.WORLD ) then
			applyThemeModulation( "glass" )
			drawBatch( count, BATCH.GLASS, DM.Assets.WorldInterior )
		end

		render.CullMode( MATERIAL_CULLMODE_CCW )
	end

	local drawWater = layerOn( DM.LAYER.WATER ) and DM.Config.Get( "ix_ftmap_sv_water" )
	local drawGlass = layerOn( DM.LAYER.WORLD )

	if drawWater or drawGlass then
		render.OverrideDepthEnable( true, false )
		if drawWater then
			applyThemeModulation( "water" )
			drawBatch( count, BATCH.WATER, DM.Assets.Water )
		end
		if drawGlass then
			applyThemeModulation( "glass" )
			drawBatch( count, BATCH.GLASS, DM.Assets.WorldTranslucent )
		end
		render.OverrideDepthEnable( false, false )
	end

	render.SetColorModulation( 1, 1, 1 )

	if opts.marker ~= false then
		DM.Marker.Draw3D( view )
	end

	if opts.npcs ~= false and DM.Config.Get( "ix_ftmap_cl_npcs" ) then
		DM.NPCMarkers.Draw3D( view )
	end

	if opts.zoneVolumes and layerOn( DM.LAYER.ZONES ) then
		DM.Zones.Draw3D( view, {
			volumes    = true,
			outlines   = true,
			alphaScale = opts.zoneAlpha or 1,
		} )
	end

	if opts.navigation ~= false then
		DM.Navigation.Draw3D( view, { width = opts.pathWidth } )
	end

	if opts.zoneLabels and layerOn( DM.LAYER.ZONES ) then
		local labels = opts.zoneLabels

		DM.Zones.Draw3DLabels( view, {
			clipZ       = opts.clipZ,
			alpha       = labels.alpha,
			maxDistance = labels.maxDistance,
			minPixels   = labels.minPixels,
			maxPixels   = labels.maxPixels,
		} )
	end

	if opts.extra then opts.extra( view ) end
	end,debug.traceback)
	for _=1,clipCount do render.PopCustomClipPlane() end
	if clipCount>0 then render.EnableClipping(clippingWasEnabled) end
	render.CullMode(MATERIAL_CULLMODE_CCW)
	render.OverrideDepthEnable(false,false)
	render.MaterialOverride()
	render.SuppressEngineLighting(false)

	render.SetColorModulation( 1, 1, 1 )
	activeTheme = nil
	activeThemeKind = nil
	if preserveTargetAlpha then render.SetWriteDepthToDestAlpha( true ) end
	if flashlight then render.PopFlashlightMode() end
	endView()
	if not ok then error(failure,0) end

end

function Renderer.DrawToTexture( key, size, view, opts )
	local rt, mat = DM.Assets.GetRenderTarget( key, size, size )

	view.w, view.h = size, size
	view.x, view.y = 0, 0
	DM.Camera.FinishView( view )

	render.PushRenderTarget( rt )

	local bg = ( opts and opts.background ) or DM.Themes.GetActive().background
	render.OverrideAlphaWriteEnable( true, true )
	render.Clear( bg.r, bg.g, bg.b, 255, true, true )

	render.OverrideAlphaWriteEnable( true, false )
	Renderer.DrawScene( view, opts, true )
	render.OverrideAlphaWriteEnable( false )

	render.PopRenderTarget()

	return rt, mat
end
