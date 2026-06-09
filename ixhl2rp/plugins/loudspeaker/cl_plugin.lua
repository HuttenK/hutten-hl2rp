local PLUGIN = PLUGIN

PLUGIN.lsCurrentSound   = ""
PLUGIN.lsSoundStartTime = 0
PLUGIN.lsChannels       = {}
PLUGIN.lsCached         = {}
PLUGIN.lsLastCache      = -999

local CACHE_INTERVAL = 5

local function IsURL(path)
	return isstring(path) and (path:find("^https?://") ~= nil)
end

local function RefreshCache()
	local now = CurTime()
	if now - PLUGIN.lsLastCache < CACHE_INTERVAL then return end
	PLUGIN.lsLastCache = now

	local list = {}
	for _, ent in ipairs(ents.FindByModel(PLUGIN.speakerModel)) do
		if IsValid(ent) then table.insert(list, ent) end
	end
	PLUGIN.lsCached = list
end

local function StopAllChannels()
	for _, ch in pairs(PLUGIN.lsChannels) do
		if IsValid(ch) then ch:Stop() end
	end
	PLUGIN.lsChannels = {}
end

local function CreateChannel(ent)
	if not IsValid(ent) then return end
	if PLUGIN.lsCurrentSound == "" then return end

	local idx       = ent:EntIndex()
	local soundPath = PLUGIN.lsCurrentSound
	local startTime = PLUGIN.lsSoundStartTime
	local flags     = "3d noblock"

	local function onChannel(channel, errNum)
		if not IsValid(channel) then return end
		if PLUGIN.lsCurrentSound != soundPath then channel:Stop(); return end
		if not IsValid(ent) then channel:Stop(); return end

		local len    = channel:GetLength()
		local offset = CurTime() - startTime
		if len > 0 then offset = offset % len end
		if offset > 0 then channel:SetTime(offset) end

		channel:SetPos(ent:GetPos())
		channel:Set3DFadeDistance(80, 600)
		channel:SetVolume(1)
		channel:Play()

		PLUGIN.lsChannels[idx] = channel
	end

	if IsURL(soundPath) then
		sound.PlayURL(soundPath, flags, onChannel)
	else
		sound.PlayFile("sound/" .. soundPath, flags, onChannel)
	end
end

net.Receive("ix_ls_sound", function()
	local path      = net.ReadString()
	local startTime = net.ReadDouble()

	PLUGIN.lsCurrentSound   = path
	PLUGIN.lsSoundStartTime = startTime

	StopAllChannels()
	if path == "" then return end

	for _, ent in ipairs(PLUGIN.lsCached) do
		CreateChannel(ent)
	end
end)

local lastTick = 0
hook.Add("Think", "ix_ls_sound_update", function()
	for _, ent in ipairs(PLUGIN.lsCached) do
		if not IsValid(ent) then continue end
		local ch = PLUGIN.lsChannels[ent:EntIndex()]
		if IsValid(ch) then ch:SetPos(ent:GetPos()) end
	end

	local now = CurTime()
	if now - lastTick < 2 then return end
	lastTick = now

	RefreshCache()

	if PLUGIN.lsCurrentSound == "" then return end
	for _, ent in ipairs(PLUGIN.lsCached) do
		if IsValid(ent) and not IsValid(PLUGIN.lsChannels[ent:EntIndex()]) then
			CreateChannel(ent)
		end
	end
end)
