local PLUGIN = PLUGIN

function PLUGIN:Initialize()
	self.defaultSound   = ix.data.Get("ls_sound", "")
	self.soundStartTime = ix.data.Get("ls_sound_start", 0)
end

function PLUGIN:PlayerInitialSpawn(client)
	timer.Simple(3, function()
		if not IsValid(client) then return end

		net.Start("ix_ls_sound")
			net.WriteString(PLUGIN.defaultSound or "")
			net.WriteDouble(PLUGIN.soundStartTime or 0)
		net.Send(client)
	end)
end
