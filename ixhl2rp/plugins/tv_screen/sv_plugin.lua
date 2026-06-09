local PLUGIN = PLUGIN

-- Load saved material and sound on server start.
function PLUGIN:Initialize()
	self.currentMaterial  = ix.data.Get("tv_material", self.defaultMaterial)
	self.currentSound     = ix.data.Get("tv_sound", "")
	self.soundStartTime   = ix.data.Get("tv_sound_start", 0)
end

-- Send material and sound to a player when they spawn.
function PLUGIN:PlayerInitialSpawn(client)
	timer.Simple(3, function()
		if not IsValid(client) then return end

		local mat = self.currentMaterial or self.defaultMaterial or "vgui/white"
		net.Start("ix_tv_setmaterial")
			net.WriteString(mat)
		net.Send(client)

		local snd   = self.currentSound or ""
		local start = self.soundStartTime or 0
		net.Start("ix_tv_sound")
			net.WriteString(snd)
			net.WriteDouble(start)
		net.Send(client)
	end)
end

-- Per-player cooldown table for TV toggling.
local tvUseCooldown = {}

-- Toggle TV on/off when a player presses E on it.
function PLUGIN:PlayerUse(client, entity)
	if not IsValid(entity) then return end
	if not PLUGIN.tvModels[entity:GetModel()] then return end

	local sid = client:SteamID()
	local now = CurTime()

	if tvUseCooldown[sid] and now - tvUseCooldown[sid] < 1 then
		return false -- still on cooldown
	end
	tvUseCooldown[sid] = now

	local isOn = entity:GetNWBool("tv_on", true)
	entity:SetNWBool("tv_on", not isOn)

	return false -- prevent default use behaviour
end
