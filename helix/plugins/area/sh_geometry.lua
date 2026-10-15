-- One logical area can contain several axis-aligned boxes. The outer bounds
-- remain available for labels/broad-phase queries, never for membership tests.
ix.area = ix.area or {}
ix.area.maxVolumes = 32
local cached = setmetatable({}, {__mode = "k"})

function ix.area.GetVolumes(info)
	if (info.volumes and #info.volumes > 0) then return info.volumes end
	local a, b = info.startPosition or info.min, info.endPosition or info.max
	return {{min = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)),
		max = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))}}
end

function ix.area.Contains(info, position)
	for _, box in ipairs(ix.area.GetVolumes(info)) do
		if (position:WithinAABox(box.min, box.max)) then return true end
	end
	return false
end

function ix.area.DistanceSqr(info, position)
	local distance = math.huge
	for _, box in ipairs(ix.area.GetVolumes(info)) do
		local a, b = box.min, box.max
		local x = math.max(a.x - position.x, 0, position.x - b.x)
		local y = math.max(a.y - position.y, 0, position.y - b.y)
		local z = math.max(a.z - position.z, 0, position.z - b.z)
		distance = math.min(distance, x*x + y*y + z*z)
	end
	return distance
end

-- Split A minus B into at most six non-overlapping boxes.
function ix.area.SubtractBox(box, cut)
	local a, b, c, d = box.min, box.max, cut.min, cut.max
	local low = Vector(math.max(a.x,c.x), math.max(a.y,c.y), math.max(a.z,c.z))
	local high = Vector(math.min(b.x,d.x), math.min(b.y,d.y), math.min(b.z,d.z))
	if (low.x >= high.x or low.y >= high.y or low.z >= high.z) then return {box} end
	local out = {}
	local function add(mn, mx)
		if (mn.x < mx.x and mn.y < mx.y and mn.z < mx.z) then out[#out + 1] = {min = mn, max = mx} end
	end
	add(a, Vector(low.x,b.y,b.z)); add(Vector(high.x,a.y,a.z), b)
	add(Vector(low.x,a.y,a.z), Vector(high.x,low.y,b.z))
	add(Vector(low.x,high.y,a.z), Vector(high.x,b.y,b.z))
	add(Vector(low.x,low.y,a.z), Vector(high.x,high.y,low.z))
	add(Vector(low.x,low.y,high.z), Vector(high.x,high.y,b.z))
	return out
end

function ix.area.GetDisjointVolumes(info)
	local old = cached[info]
	local a, b = info.startPosition or info.min, info.endPosition or info.max
	if (old and old.source == info.volumes and old.a == a and old.b == b) then return old.boxes end
	local boxes = {}
	for _, volume in ipairs(ix.area.GetVolumes(info)) do
		local parts = {volume}
		for _, cut in ipairs(boxes) do
			local nextParts = {}
			for _, part in ipairs(parts) do
				for _, piece in ipairs(ix.area.SubtractBox(part, cut)) do nextParts[#nextParts + 1] = piece end
			end
			parts = nextParts
		end
		for _, part in ipairs(parts) do boxes[#boxes + 1] = part end
		if (#boxes > 256) then return nil end
	end
	cached[info] = {source = info.volumes, a = a, b = b, boxes = boxes}
	return boxes
end

function ix.area.Measure(info)
	local size = 0
	for _, box in ipairs(ix.area.GetDisjointVolumes(info) or ix.area.GetVolumes(info)) do
		local v = box.max - box.min
		size = size + v.x*v.y*v.z
	end
	return size
end

function ix.area.SetVolumes(info, volumes)
	if (!istable(volumes) or #volumes < 1 or #volumes > ix.area.maxVolumes) then return false, "areaVolumeLimit" end
	local normalized, low, high = {}
	for _, box in ipairs(volumes) do
		if (!istable(box) or !isvector(box.min) or !isvector(box.max)) then return false, "areaVolumeInvalid" end
		local mn, mx = Vector(), Vector()
		for _, axis in ipairs({"x", "y", "z"}) do
			local a, b = box.min[axis], box.max[axis]
			if (a ~= a or b ~= b or math.abs(a) > 32768 or math.abs(b) > 32768) then return false, "areaVolumeInvalid" end
			mn[axis], mx[axis] = math.min(a,b), math.max(a,b)
			if (mx[axis] - mn[axis] < 1) then return false, "areaVolumeInvalid" end
		end
		normalized[#normalized + 1] = {min = mn, max = mx}
		if (!low) then low, high = Vector(mn.x,mn.y,mn.z), Vector(mx.x,mx.y,mx.z) end
		for _, axis in ipairs({"x", "y", "z"}) do low[axis], high[axis] = math.min(low[axis],mn[axis]), math.max(high[axis],mx[axis]) end
	end
	local candidate = {volumes = normalized, startPosition = low, endPosition = high}
	if (!ix.area.GetDisjointVolumes(candidate)) then return false, "areaVolumeComplex" end
	info.volumes, info.startPosition, info.endPosition = normalized, low, high
	return true
end
