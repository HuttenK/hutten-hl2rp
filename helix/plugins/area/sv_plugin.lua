
util.AddNetworkString("ixAreaSync")
util.AddNetworkString("ixAreaAdd")
util.AddNetworkString("ixAreaRemove")
util.AddNetworkString("ixAreaChanged")

util.AddNetworkString("ixAreaEditStart")
util.AddNetworkString("ixAreaEditEnd")

ix.log.AddType("areaAdd", function(client, name)
	return string.format("%s has added area \"%s\".", client:Name(), tostring(name))
end)

ix.log.AddType("areaRemove", function(client, name)
	return string.format("%s has removed area \"%s\".", client:Name(), tostring(name))
end)

local function SortVector(first, second)
	return Vector(math.min(first.x, second.x), math.min(first.y, second.y), math.min(first.z, second.z)),
		Vector(math.max(first.x, second.x), math.max(first.y, second.y), math.max(first.z, second.z))
end

function ix.area.Create(name, type, startPosition, endPosition, bNoReplicate, properties, volumes)
	local min, max = SortVector(startPosition, endPosition)

	local info = {
		type = type or "area",
		startPosition = min,
		endPosition = max,
		bNoReplicate = bNoReplicate,
		volumes = volumes,
		properties = properties or {}
	}
	local allowed, reason = hook.Run("AreaDefinitionCreating", name, info)
	if (allowed == false) then return false, reason end
	if ix.area.stored[name] then hook.Run("AreaDefinitionRemoved", name) end
	ix.area.stored[name] = info
	hook.Run("AreaDefinitionCreated", name, info)

	-- network to clients if needed
	if (!bNoReplicate) then
		ix.area.Sync(name)
	end
	return true
end

function ix.area.Sync(name)
	local info = ix.area.stored[name]
	if (!info or info.bNoReplicate) then return end
	local volumes = ix.area.GetVolumes(info)
	net.Start("ixAreaAdd")
		net.WriteString(name)
		net.WriteString(info.type)
		net.WriteVector(info.startPosition)
		net.WriteVector(info.endPosition)
		net.WriteTable(info.properties)
		net.WriteUInt(info.volumeRevision or 0, 32)
		net.WriteUInt(#volumes, 6)
		for _, box in ipairs(volumes) do net.WriteVector(box.min); net.WriteVector(box.max) end
	net.Broadcast()
end

function ix.area.Remove(name, bNoReplicate)
	local info = ix.area.stored[name]
	hook.Run("AreaDefinitionRemoved", name)
	ix.area.stored[name] = nil
	hook.Run("AreaDefinitionDeleted", name, info)

	-- network to clients if needed
	if (!bNoReplicate) then
		net.Start("ixAreaRemove")
			net.WriteString(name)
		net.Broadcast()
	end
end
