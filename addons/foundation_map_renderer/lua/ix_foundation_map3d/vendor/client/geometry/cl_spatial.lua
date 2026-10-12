-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.
local DM = ix.FoundationMap3D
local Util = DM.Util

DM.Spatial = DM.Spatial or {}
local Spatial = DM.Spatial

local math_floor, math_min, math_max, math_abs = math.floor, math.min, math.max, math.abs

local Grid = {}
Grid.__index = Grid
Spatial.Grid = Grid

function Spatial.New( cellSize )
	return setmetatable( {
		cellSize = cellSize or 1024,
		cells    = {},
		count    = 0,
		items    = 0,
		visited  = {},
		epoch    = 0,
		mins     = Vector( math.huge, math.huge, math.huge ),
		maxs     = Vector( -math.huge, -math.huge, -math.huge ),
	}, Grid )
end

local function key( cx, cy )
	return cx .. ":" .. cy
end

function Grid:Clear()
	self.cells = {}
	self.count = 0
	self.items = 0
	self.visited = {}
	self.epoch = 0
	self.mins = Vector( math.huge, math.huge, math.huge )
	self.maxs = Vector( -math.huge, -math.huge, -math.huge )
end

function Grid:Insert( item, mins, maxs )
	local size = self.cellSize
	local x0, x1 = math_floor( mins.x / size ), math_floor( maxs.x / size )
	local y0, y1 = math_floor( mins.y / size ), math_floor( maxs.y / size )

	Util.ExpandBounds( self.mins, self.maxs, mins )
	Util.ExpandBounds( self.mins, self.maxs, maxs )

	self.items = self.items + 1

	for cx = x0, x1 do
		for cy = y0, y1 do
			local k = key( cx, cy )
			local cell = self.cells[k]

			if not cell then
				cell = {
					n = 0,
					items = {},
					mins = Vector( cx * size, cy * size, mins.z ),
					maxs = Vector( ( cx + 1 ) * size, ( cy + 1 ) * size, maxs.z ),
					cx = cx, cy = cy,
				}
				self.cells[k] = cell
				self.count = self.count + 1
			else
				if mins.z < cell.mins.z then cell.mins.z = mins.z end
				if maxs.z > cell.maxs.z then cell.maxs.z = maxs.z end
			end

			cell.n = cell.n + 1
			cell.items[cell.n] = item
		end
	end
end

function Grid:InsertPoint( item, pos, radius )
	radius = radius or 0
	local r = Vector( radius, radius, radius )
	self:Insert( item, pos - r, pos + r )
end

function Grid:GetCell( cx, cy )
	return self.cells[key( cx, cy )]
end

function Grid:NewEpoch()
	self.epoch = self.epoch + 1
	return self.epoch
end

function Grid:QueryBox( mins, maxs, out )
	out = out or {}
	local n = 0

	local size = self.cellSize
	local epoch = self:NewEpoch()
	local visited = self.visited

	for cx = math_floor( mins.x / size ), math_floor( maxs.x / size ) do
		for cy = math_floor( mins.y / size ), math_floor( maxs.y / size ) do
			local cell = self.cells[key( cx, cy )]

			if cell and cell.maxs.z >= mins.z and cell.mins.z <= maxs.z then
				local items = cell.items
				for i = 1, cell.n do
					local item = items[i]
					if visited[item] ~= epoch then
						visited[item] = epoch
						n = n + 1
						out[n] = item
					end
				end
			end
		end
	end

	for i = n + 1, #out do out[i] = nil end
	return out, n
end

function Grid:QueryFrustum( frustum, out )
	out = out or {}
	local n = 0

	local epoch = self:NewEpoch()
	local visited = self.visited

	for _, cell in pairs( self.cells ) do
		if Util.BoxInFrustum( frustum, cell.mins, cell.maxs ) then
			local items = cell.items
			for i = 1, cell.n do
				local item = items[i]
				if visited[item] ~= epoch then
					visited[item] = epoch
					n = n + 1
					out[n] = item
				end
			end
		end
	end

	for i = n + 1, #out do out[i] = nil end
	return out, n
end

function Grid:TraverseRay( origin, dir, maxDist, visitor )
	local size = self.cellSize

	local cx = math_floor( origin.x / size )
	local cy = math_floor( origin.y / size )

	local stepX = dir.x > 0 and 1 or -1
	local stepY = dir.y > 0 and 1 or -1

	local tDeltaX = math_abs( dir.x ) > 1e-9 and math_abs( size / dir.x ) or math.huge
	local tDeltaY = math_abs( dir.y ) > 1e-9 and math_abs( size / dir.y ) or math.huge

	local nextX = ( dir.x > 0 and ( cx + 1 ) * size or cx * size )
	local nextY = ( dir.y > 0 and ( cy + 1 ) * size or cy * size )

	local tMaxX = math_abs( dir.x ) > 1e-9 and ( nextX - origin.x ) / dir.x or math.huge
	local tMaxY = math_abs( dir.y ) > 1e-9 and ( nextY - origin.y ) / dir.y or math.huge

	local t = 0
	local guard = 0

	while t <= maxDist do
		guard = guard + 1
		if guard > 4096 then break end

		local cell = self.cells[key( cx, cy )]
		if cell then
			if visitor( cell, t ) then return end
		end

		if tMaxX < tMaxY then
			t = tMaxX
			cx = cx + stepX
			tMaxX = tMaxX + tDeltaX
		else
			t = tMaxY
			cy = cy + stepY
			tMaxY = tMaxY + tDeltaY
		end
	end
end

function Grid:QueryRay( origin, dir, maxDist, out )
	out = out or {}
	local n = 0

	local epoch = self:NewEpoch()
	local visited = self.visited

	self:TraverseRay( origin, dir, maxDist, function( cell )
		local items = cell.items
		for i = 1, cell.n do
			local item = items[i]
			if visited[item] ~= epoch then
				visited[item] = epoch
				n = n + 1
				out[n] = item
			end
		end
	end )

	for i = n + 1, #out do out[i] = nil end
	return out, n
end

function Grid:QueryFrustumCells( frustum, eye, out )
	out = out or {}
	local n = 0

	for _, cell in pairs( self.cells ) do
		if Util.BoxInFrustum( frustum, cell.mins, cell.maxs ) then
			n = n + 1
			out[n] = cell

			local cxWorld = ( cell.mins.x + cell.maxs.x ) * 0.5
			local cyWorld = ( cell.mins.y + cell.maxs.y ) * 0.5
			local dx, dy = cxWorld - eye.x, cyWorld - eye.y
			cell._dist = dx * dx + dy * dy
		end
	end

	for i = n + 1, #out do out[i] = nil end

	table.sort( out, function( a, b ) return ( a._dist or 0 ) < ( b._dist or 0 ) end )
	return out, n
end

function Grid:GetStats()
	local maxItems, sum = 0, 0
	for _, cell in pairs( self.cells ) do
		maxItems = math_max( maxItems, cell.n )
		sum = sum + cell.n
	end

	return {
		cells    = self.count,
		items    = self.items,
		refs     = sum,
		maxCell  = maxItems,
		cellSize = self.cellSize,
	}
end
