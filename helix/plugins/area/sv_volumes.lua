local PLUGIN = PLUGIN
util.AddNetworkString("ixAreaVolumeEdit")

function ix.area.UpdateVolumes(name, volumes)
	local info = ix.area.stored[name]
	if (!info) then return false, "areaDoesntExist" end
	local candidate = table.Copy(info)
	local ok, reason = ix.area.SetVolumes(candidate, volumes)
	if (!ok) then return false, reason end
	local allowed, message = hook.Run("AreaVolumesChanging", name, candidate)
	if (allowed == false) then return false, message end
	candidate.volumeRevision = (info.volumeRevision or 0) + 1
	ix.area.stored[name] = candidate
	hook.Run("AreaDefinitionUpdated", name, candidate, info)
	PLUGIN:SaveData()
	ix.area.Sync(name)
	return true
end

net.Receive("ixAreaVolumeEdit", function(_, client)
	if (!client:Alive() or !CAMI.PlayerHasAccess(client, "Helix - AreaEdit", nil)) then return end
	local name, revision = net.ReadString(), net.ReadUInt(32)
	local info = ix.area.stored[name]
	if (!info) then client:NotifyLocalized("areaDoesntExist"); return end
	if (revision ~= (info.volumeRevision or 0)) then client:NotifyLocalized("areaVolumeChanged"); ix.area.Sync(name); return end
	local volumes = table.Copy(ix.area.GetVolumes(info))
	if (net.ReadBool()) then
		if (#volumes >= ix.area.maxVolumes) then client:NotifyLocalized("areaVolumeLimit"); return end
		local candidate = {}
		local ok, reason = ix.area.SetVolumes(candidate, {{min = net.ReadVector(), max = net.ReadVector()}})
		if (!ok) then client:NotifyLocalized(reason); return end
		local box = candidate.volumes[1]
		local allowed, message = hook.Run("AreaVolumeAdding", name, info, box)
		if (allowed == false) then client:Notify(message or "Unable to add volume."); return end
		volumes[#volumes + 1] = box
	else
		local index = net.ReadUInt(6)
		if (#volumes <= 1) then client:NotifyLocalized("areaVolumeLast"); return end
		if (!volumes[index]) then client:NotifyLocalized("areaVolumeChanged"); return end
		table.remove(volumes, index)
	end
	local ok, reason = ix.area.UpdateVolumes(name, volumes)
	client:NotifyLocalized(ok and "areaVolumeSaved" or reason or "areaVolumeInvalid")
end)
