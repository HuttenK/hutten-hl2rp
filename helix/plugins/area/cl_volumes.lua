local PLUGIN = PLUGIN

function PLUGIN:BeginVolume(id)
	local info = ix.area.stored[id]
	if (!info) then return end
	self.editVolumeID, self.editVolumeRevision = id, info.volumeRevision or 0
	self.editStart, self.editEnd, self.editProperties = nil, nil, nil
	ix.util.NotifyLocalized("areaVolumeStart")
end

function PLUGIN:SubmitVolume()
	net.Start("ixAreaVolumeEdit")
		net.WriteString(self.editVolumeID)
		net.WriteUInt(self.editVolumeRevision, 32)
		net.WriteBool(true)
		net.WriteVector(self.editStart)
		net.WriteVector(self:GetPlayerAreaTrace().HitPos)
	net.SendToServer()
	self.editVolumeID, self.editVolumeRevision = nil, nil
	self.editStart, self.editEnd = nil, nil
end

function PLUGIN:OpenAreaOptions(id, info)
	local menu = DermaMenu()
	menu:AddOption(L("areaVolumeAdd"), function() self:BeginVolume(id) end):SetIcon("icon16/shape_square_add.png")
	local volumes = ix.area.GetVolumes(info)
	if (#volumes > 1) then
		local remove = menu:AddSubMenu(L("areaVolumeRemove"))
		for index, box in ipairs(volumes) do
			local option = remove:AddOption(L("areaVolumeNumber", index), function()
				Derma_Query(L("areaVolumeDeleteConfirm", index, id), L("areaVolumeRemove"), L("no"), nil, L("yes"), function()
					net.Start("ixAreaVolumeEdit")
						net.WriteString(id); net.WriteUInt(info.volumeRevision or 0, 32)
						net.WriteBool(false); net.WriteUInt(index, 6)
					net.SendToServer()
				end)
			end)
			local entered, exited = option.OnCursorEntered, option.OnCursorExited
			option.OnCursorEntered = function(panel)
				if (entered) then entered(panel) end
				self.volumePreview = box
			end
			option.OnCursorExited = function(panel)
				if (exited) then exited(panel) end
				self.volumePreview = nil
			end
		end
	end
	hook.Run("AreaEditPopulateOptions", id, info, menu)
	menu:AddSpacer()
	menu:AddOption(L("areaDelete"), function()
		Derma_Query(L("areaDeleteConfirm", id), L("areaDelete"), L("no"), nil, L("yes"), function()
			net.Start("ixAreaRemove"); net.WriteString(id); net.SendToServer()
		end)
	end):SetIcon("icon16/delete.png")
	local removed = menu.OnRemove
	menu.OnRemove = function(panel)
		self.volumePreview = nil
		if (removed) then removed(panel) end
	end
	menu:Open(ScrW() * .5, ScrH() * .5)
end
