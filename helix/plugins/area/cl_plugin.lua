
local PLUGIN = PLUGIN

function PLUGIN:GetPlayerAreaTrace()
	local client = LocalPlayer()

	return util.TraceLine({
		start = client:GetShootPos(),
		endpos = client:GetShootPos() + client:GetForward() * 96,
		filter = client
	})
end

function PLUGIN:StartEditing()
	ix.area.bEditing = true
	self.editStart = nil
	self.editEnd = nil
	self.editProperties = nil
	self.editVolumeID, self.editVolumeRevision, self.volumePreview = nil, nil, nil
end

-- Infrastructure volumes can overlap a named location without replacing it.
-- Editing therefore finds all boxes directly instead of using Player:GetArea().
function PLUGIN:GetEditableAreas()
	local client = LocalPlayer()
	local position = client:GetPos() + client:OBBCenter()
	local found = {}
	for id, info in pairs(ix.area.stored) do
		if (ix.area.Contains(info, position)) then found[#found + 1] = id end
	end
	table.sort(found)
	return found
end

function PLUGIN:StopEditing()
	ix.area.bEditing = false
	self.editVolumeID, self.editVolumeRevision, self.volumePreview = nil, nil, nil

	if (IsValid(ix.gui.areaEdit)) then
		ix.gui.areaEdit:Remove()
	end
end
