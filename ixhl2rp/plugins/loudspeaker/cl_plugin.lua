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

-- ── Радиус слышимости громкоговорителя ───────────────────────────────────────
-- BASS/IGModAudioChannel:Set3DFadeDistance(min, max): max НЕ гасит звук за пределом,
-- а фиксирует громкость на ~min/max — из-за этого динамик со Set3DFadeDistance(80, 600)
-- слышно по всей карте на ~13% громкости. Настоящий радиус задаём ручным затуханием
-- по дистанции до слушателя с жёстким нулём за LS_SND_SILENT. Громкоговоритель — это
-- система оповещения, поэтому радиус можно смело увеличивать (это дальность, за которой
-- наступает полная тишина). Меняйте эти два числа для регулировки дальности.
local LS_SND_FULL   = 400    -- до этой дистанции (юниты) — полная громкость
local LS_SND_SILENT = 2100   -- на этой дистанции и дальше — полная тишина

local function LSDistanceVolume(ent)
	local ply = LocalPlayer()
	if not IsValid(ply) or not IsValid(ent) then return 0 end

	local d = ply:GetPos():Distance(ent:GetPos())
	if d <= LS_SND_FULL then return 1 end
	if d >= LS_SND_SILENT then return 0 end
	return 1 - (d - LS_SND_FULL) / (LS_SND_SILENT - LS_SND_FULL)
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
		-- Отодвигаем затухание BASS за наш радиус (оставляем только 3D-панораму);
		-- реальную дальность задаёт LSDistanceVolume, обновляемый каждый кадр в Think.
		channel:Set3DFadeDistance(LS_SND_SILENT, LS_SND_SILENT * 4)
		channel:SetVolume(LSDistanceVolume(ent))
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
		if IsValid(ch) then
			-- Обновляем позицию И громкость по дистанции каждый кадр — без этого
			-- динамик оставался на стартовой громкости и был слышен по всей карте.
			ch:SetPos(ent:GetPos())
			ch:SetVolume(LSDistanceVolume(ent))
		end
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
