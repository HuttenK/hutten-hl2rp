-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D

if DM.NativeProps and DM.NativeProps.Release then DM.NativeProps.Release() end
DM.NativeProps = {}
local Native = DM.NativeProps
local enabled, building = true, nil
local cells, models, wanted = {}, {}, {}
local sourceRecords = nil
local PREPARE_BUDGET = 0.001

local ROAD_LIFT = 8
local IDLE_POOL_TARGET = 256
local poolSize, deadline = 0, 0
local nextPrune, nextIndexCheck = 0, 0
local indexFailed = false
local selectionKey, selectionCache = nil, nil
local selectedModels, selectionPass = {}, 0
local viewPlanes, crossingPlanes = {}, {}
local retiring = {}
local flatMaterial = CreateMaterial( "ix_ftmap_native_prop_flat", "VertexLitGeneric", {
	["$basetexture"] = "color/white", ["$model"] = "1",
} )

function Native.IsEnabled() return enabled end

local function retireModels()
	for _, model in pairs( models ) do
		if IsValid( model.ent ) then retiring[#retiring + 1] = model.ent end
	end
	models, wanted, poolSize = {}, {}, 0
end

function Native.Release()
	enabled, building, sourceRecords = false, nil, nil
	cells = {}
	selectionKey, selectionCache = nil, nil
	selectedModels = {}
	retireModels()
	for _, ent in ipairs( retiring ) do if IsValid( ent ) then ent:Remove() end end
	retiring = {}
end

local function yieldWork()
	if SysTime() >= deadline then coroutine.yield() end
end

local function buildIndex()
	local doc = DM.MapData.Get()
	if not DM.Props.IsBuilt( doc ) or DM.Props.Count() == 0 then
		local lo, hi = DM.Bake.GetWorldBounds()
		DM.Props.Build( doc, DM.Themes.Get( "standard" ), lo, hi,
			DM.Config.Get( "ix_ftmap_sv_height_invert" ), yieldWork )
	end
	local records = DM.Props.GetAll()
	local buckets, order, bounds = {}, {}, {}
	local source = NikNaks.CurrentMap:GetStaticProps()
	for i, rec in ipairs( records ) do

		local original = source[rec.index]
		local mins, maxs = rec.mins, rec.maxs
		local lo, hi
		if rec.tree then
			local cachedBounds = bounds[rec.model]
			if not cachedBounds then
				lo, hi = DM.Props.ReadModelBounds( rec.model )
				cachedBounds = { lo, hi }; bounds[rec.model] = cachedBounds
			end
			lo, hi = cachedBounds[1], cachedBounds[2]
		end
		if lo and hi then
			local half = ( hi - lo ) * ( rec.scale * 0.5 )
			local center = ( hi + lo ) * ( rec.scale * 0.5 )
			center:Rotate( rec.ang ); center:Add( rec.pos )
			local f, r, u = rec.ang:Forward(), rec.ang:Right(), rec.ang:Up()
			local extent = Vector( math.abs( f.x * half.x ) + math.abs( r.x * half.y ) + math.abs( u.x * half.z ),
				math.abs( f.y * half.x ) + math.abs( r.y * half.y ) + math.abs( u.y * half.z ),
				math.abs( f.z * half.x ) + math.abs( r.z * half.y ) + math.abs( u.z * half.z ) )
			mins, maxs = center - extent, center + extent
		end

		if string.find( rec.model, "%f[%a]road" ) then
			maxs = Vector( maxs.x, maxs.y, maxs.z + ROAD_LIFT )
		end
		local key = math.floor( rec.pos.x / 1024 ) .. ":" .. math.floor( rec.pos.y / 1024 ) .. ":" .. rec.zone
		local cell = buckets[key]
		if not cell then
			cell = { mins = Vector( mins ), maxs = Vector( maxs ), zone = rec.zone, items = {} }
			buckets[key] = cell; order[#order + 1] = cell
		else
			DM.Util.ExpandBounds( cell.mins, cell.maxs, mins )
			DM.Util.ExpandBounds( cell.mins, cell.maxs, maxs )
		end
		local model = models[rec.model]
		if not model then
			model = { name = rec.model, visible = {}, visibleCount = 0, lastUsed = 0 }
			models[rec.model] = model
		end
		cell.items[#cell.items + 1] = { rec = rec, model = model, mins = mins, maxs = maxs,
			mins.x, mins.y, mins.z, maxs.x, maxs.y, maxs.z,
			skin = original and original.Skin or 0, tint = original and original.DiffuseModulation or color_white }
		if i % 16 == 0 then yieldWork() end
	end

	for i = 1, #order do
		local cell = order[i]
		local lo, hi = cell.mins, cell.maxs
		cell[1], cell[2], cell[3] = lo.x, lo.y, lo.z
		cell[4], cell[5], cell[6] = hi.x, hi.y, hi.z
		if i % 16 == 0 then yieldWork() end
	end
	cells, sourceRecords = order, records
	selectionKey, selectionCache = nil, nil
end

function Native.Enable()
	if DM.Bake.IsBusy() then DM.Msg( "native props: wait for the running map job to finish" ); return end
	if not DM.Bake.IsReady() then DM.Msg( "native props: waiting for world geometry" ); return end
	enabled, indexFailed = true, false
	for _, model in pairs( models ) do
		if model.failed then
			model.failed = nil
			if IsValid( model.ent ) then
				model.ent:Remove(); model.ent = nil; poolSize = poolSize - 1
			end
		end
	end

	building = coroutine.create( buildIndex )
end

local function prepareModel( model )
	local ent = model.ent
	if not IsValid( ent ) then
		ent = ClientsideModel( model.name, RENDERGROUP_BOTH )
		if not IsValid( ent ) then
			model.failed = true
			DM.Warn( "native props: engine could not create ", model.name )
			return
		end
		model.ent = ent; poolSize = poolSize + 1
		model.skin, model.scale = nil, nil
		ent:SetNoDraw( true )
		ent:DrawShadow( false )
		ent:SetLOD( 0 )
	end
	model.textured = nil
	local materials = {}
	local road = false
	for i, name in ipairs( ent:GetMaterials() ) do
		local ok, alpha, masked, decal = pcall( DM.Props.GetTreeMaterial, name )
		if ok then
			materials[i] = "!" .. ( masked and alpha or flatMaterial ):GetName()
			road = road or ( decal and string.find( model.name, "%f[%a]road" ) ~= nil )
		else

			materials[i] = name
			DM.Warn( "native props: retaining source material ", name, ": ", tostring( alpha ) )
		end
	end
	model.materials = materials
	model.road = road
	model.materialProvider = DM.Props.GetTreeMaterial
end

hook.Add( "Think", "ix_ftmap_native_props_prepare", function()
	deadline = SysTime() + PREPARE_BUDGET

	for _ = 1, 8 do
		local ent = table.remove( retiring )
		if not ent then break end
		if IsValid( ent ) then ent:Remove() end
		if SysTime() >= deadline then return end
	end
	if not DM.IsActive() then return end
	if building then
		local ok, err = coroutine.resume( building )
		if not ok then
			building, indexFailed = nil, true
			DM.Warn( "native props: index failed: ", tostring( err ) ); return
		end
		if coroutine.status( building ) == "dead" then
			building = nil
		end
		return
	end
	if not enabled or indexFailed then return end

	if SysTime() >= nextIndexCheck then
		nextIndexCheck = SysTime() + 0.2
		if DM.Bake.IsReady() and not DM.Bake.IsBusy() and ( sourceRecords ~= DM.Props.GetAll()
			or not DM.Props.IsBuilt( DM.MapData.Get() ) ) then Native.Enable(); return end
	end
	while #wanted > 0 and SysTime() < deadline do
		local model = table.remove( wanted )
		model.queued = nil
		if ( not IsValid( model.ent ) or model.materialProvider ~= DM.Props.GetTreeMaterial )
			and not model.failed and SysTime() - model.lastUsed < 1 then
			local ok, err = pcall( prepareModel, model )
			if not ok then
				model.failed = true
				DM.Warn( "native props: could not prepare ", model.name, ": ", tostring( err ) )
			end
		end
	end

	if SysTime() >= nextPrune and SysTime() < deadline then
		nextPrune = SysTime() + 1
		for _, model in pairs( models ) do
			if poolSize <= IDLE_POOL_TARGET or SysTime() >= deadline then break end
			if IsValid( model.ent ) and SysTime() - model.lastUsed > 5 then
				model.ent:Remove(); model.ent = nil; poolSize = poolSize - 1
			end
		end
	end
end )

local function setViewPlane( i, nx, ny, nz, distance )
	local pl = viewPlanes[i]
	if not pl then pl = {}; viewPlanes[i] = pl end
	pl[1], pl[2], pl[3], pl[4] = nx, ny, nz, distance

	pl[5], pl[8] = nx >= 0 and 4 or 1, nx >= 0 and 1 or 4
	pl[6], pl[9] = ny >= 0 and 5 or 2, ny >= 0 and 2 or 5
	pl[7], pl[10] = nz >= 0 and 6 or 3, nz >= 0 and 3 or 6
end

local function prepareViewPlanes( frustum, clipZ, invert )
	local count = frustum.count
	for i = 1, count do
		local pl = frustum[i]
		setViewPlane( i, pl[1], pl[2], pl[3], pl[4] )
	end
	if clipZ then
		count = count + 1
		setViewPlane( count, 0, 0, invert and 1 or -1, invert and clipZ or -clipZ )
	end
	return count
end

local function classifyCell( cell, planeCount )
	local crossing = 0
	for i = 1, planeCount do
		local pl = viewPlanes[i]
		local nx, ny, nz, distance = pl[1], pl[2], pl[3], pl[4]
		if nx * cell[pl[5]] + ny * cell[pl[6]] + nz * cell[pl[7]] < distance then return -1 end
		if nx * cell[pl[8]] + ny * cell[pl[9]] + nz * cell[pl[10]] < distance then
			crossing = crossing + 1; crossingPlanes[crossing] = pl
		end
	end
	return crossing
end

local function insideCrossingPlanes( item, count )
	for i = 1, count do
		local pl = crossingPlanes[i]
		if pl[1] * item[pl[5]] + pl[2] * item[pl[6]] + pl[3] * item[pl[7]] < pl[4] then return false end
	end
	return true
end

local function selectVisible( view, opts )
	local selected = selectedModels
	local invert = DM.Config.Get( "ix_ftmap_cl_clip_invert" )
	local now = SysTime()

	local key
	if not opts.zoneFilter then
		key = table.concat( { view.origin.x, view.origin.y, view.origin.z,
			view.angles.p, view.angles.y, view.angles.r, view.fov or 0, view.ortho or 0,
			view.w, view.h, view.aspect or 0, view.znear or 0, view.zfar or 0,
			opts.clipZ or "none", invert and 1 or 0 }, ":" )
	end
	if not ( key and key == selectionKey and selectionCache ) then
		local planeCount = prepareViewPlanes( view.frustum, opts.clipZ, invert )
		local previousCount, selectedCount = #selected, 0
		selectionPass = selectionPass + 1
		for ci = 1, #cells do
			local cell = cells[ci]
			if not opts.zoneFilter or opts.zoneFilter( cell.zone ) then
				local crossing = classifyCell( cell, planeCount )
				if crossing >= 0 then
					for ii = 1, #cell.items do
						local item = cell.items[ii]
						if crossing == 0 or insideCrossingPlanes( item, crossing ) then
							local model = item.model
							if model.selectionPass ~= selectionPass then
								model.visibleCount = 0; model.selectionPass = selectionPass
								selectedCount = selectedCount + 1; selected[selectedCount] = model
								model.previousVisibleCount = #model.visible
							end
							local n = model.visibleCount + 1
							model.visible[n] = item; model.visibleCount = n
						end
					end
				end
			end
		end
		for i = selectedCount + 1, previousCount do selected[i] = nil end
		for i = 1, selectedCount do
			local model = selected[i]
			for j = model.visibleCount + 1, model.previousVisibleCount do model.visible[j] = nil end
		end
	end

	for i = 1, #selected do
		local model = selected[i]
		model.lastUsed = now
		model.ready = not model.failed and IsValid( model.ent )
			and model.materialProvider == DM.Props.GetTreeMaterial
		if not model.ready then
			if not model.queued and not model.failed then
				model.queued = true; wanted[#wanted + 1] = model
			end
		end
	end
	selectionKey, selectionCache = key, selected
	return selected
end

Native.SelectVisible = selectVisible

local function drawModelInstances( model, textured, red, green, blue )
	local ent = model.ent
	if model.textured ~= textured then
		ent:SetSubMaterial()
		if not textured then
			for i, name in ipairs( model.materials ) do ent:SetSubMaterial( i - 1, name ) end
		end
		model.textured = textured
	end
	for i = 1, model.visibleCount do
		local item = model.visible[i]
		local rec = item.rec
		local pos = rec.pos
		if model.road then
			if not item.roadPos then item.roadPos = Vector( pos.x, pos.y, pos.z + ROAD_LIFT ) end
			pos = item.roadPos
		end
		ent:SetPos( pos ); ent:SetAngles( rec.ang )
		if model.skin ~= item.skin then ent:SetSkin( item.skin ); model.skin = item.skin end
		if model.scale ~= rec.scale then ent:SetModelScale( rec.scale, 0 ); model.scale = rec.scale end
		if textured then
			render.SetColorModulation( item.tint.r / 255, item.tint.g / 255, item.tint.b / 255 )
			render.SetBlend( ( item.tint.a or 255 ) / 255 )
		else
			render.SetColorModulation( red * rec.r / 255, green * rec.g / 255, blue * rec.b / 255 )
			render.SetBlend( 1 )
		end
		ent:SetupBones()
		ent:DrawModel()
	end
end

Native.DrawModelInstances = drawModelInstances

function Native.Draw( view, opts )
	if not enabled then return end
	local red, green, blue = render.GetColorModulation()
	local blend = render.GetBlend()
	local textured = DM.Config.Get( "ix_ftmap_cl_map_textures" )
	local ok, failure = pcall( function()
		local selected = Native.SelectVisible( view, opts )
		render.SuppressEngineLighting( true )
		render.ResetModelLighting( 0.4, 0.4, 0.4 )
		render.SetModelLighting( 4, 1, 1, 1 )
		render.SetModelLighting( 0, 0.65, 0.65, 0.65 )
		render.MaterialOverride( opts.overrideMaterial )
		for _, model in ipairs( selected ) do
			if model.ready and not model.failed then
				local modelOK, modelError = pcall( Native.DrawModelInstances, model, textured, red, green, blue )
				if not modelOK then
					model.failed = true
					DM.Warn( "native props: draw failed for ", model.name, ": ", tostring( modelError ) )
				end
			end
		end
	end )

	render.MaterialOverride()
	render.ResetModelLighting( 1, 1, 1 )
	render.SuppressEngineLighting( false )
	render.SetColorModulation( red, green, blue )
	render.SetBlend( blend )
	if not ok then DM.Warn( "native props: draw error: ", tostring( failure ) ); return end
end

hook.Add( "ShutDown", "ix_ftmap_native_props_cleanup", Native.Release )
