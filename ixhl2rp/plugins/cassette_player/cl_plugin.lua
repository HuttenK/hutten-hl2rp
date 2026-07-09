-- Client-side 3D audio manager for all ix_boombox entities.
-- One channel per live boombox entity; position is updated every frame.

local PLUGIN = PLUGIN

-- [entIndex] = {channel = IGModAudioChannel|nil, soundPath = string}
local boomboxAudio  = {}
-- Cached entity list (refreshes every CACHE_INTERVAL seconds)
local boomboxCache  = {}
local lastCacheTime = -999
local CACHE_INTERVAL = 2

-- ── Радиус слышимости бумбокса ───────────────────────────────────────────────
-- BASS/IGModAudioChannel:Set3DFadeDistance(min, max): max НЕ гасит звук, а лишь
-- фиксирует громкость на ~min/max за пределами max — из-за этого бумбокс со
-- Set3DFadeDistance(80, 600) слышно по всей карте на ~13% громкости. Настоящий
-- радиус задаём ручным затуханием по дистанции до слушателя с жёстким нулём за
-- SND_SILENT. Меняйте эти два числа для регулировки дальности.
local SND_FULL   = 80    -- до этой дистанции (юниты) — полная громкость
local SND_SILENT = 600   -- на этой дистанции и дальше — полная тишина

local function DistanceVolume(ent)
    local ply = LocalPlayer()
    if not IsValid(ply) or not IsValid(ent) then return 0 end

    local d = ply:GetPos():Distance(ent:GetPos())
    if d <= SND_FULL then return 1 end
    if d >= SND_SILENT then return 0 end
    return 1 - (d - SND_FULL) / (SND_SILENT - SND_FULL)
end

local function RefreshCache()
    local now = CurTime()
    if now - lastCacheTime < CACHE_INTERVAL then return end
    lastCacheTime = now
    boomboxCache = ents.FindByClass("ix_boombox")
end

local function StopChannel(idx)
    local data = boomboxAudio[idx]
    if data and IsValid(data.channel) then
        data.channel:Stop()
    end
    boomboxAudio[idx] = nil
end

local function StartChannel(ent, soundPath, stime)
    local idx     = ent:EntIndex()
    -- Tracker reference is captured in the async callback so we can detect
    -- if the sound was superseded before the channel finishes loading.
    local tracker = {channel = nil, soundPath = soundPath}
    boomboxAudio[idx] = tracker

    local flags = "3d noblock"

    local function onChannel(ch, errCode)
        if not IsValid(ch) then return end
        -- Cancelled or replaced?
        if boomboxAudio[idx] != tracker then ch:Stop(); return end
        if not IsValid(ent)              then ch:Stop(); return end

        -- Seek into the loop so late-joiners sync with the server start time.
        local len    = ch:GetLength()
        local offset = CurTime() - stime
        if len > 0 then offset = offset % len end
        if offset > 0 then ch:SetTime(offset) end

        ch:SetPos(ent:GetPos())
        -- Отодвигаем затухание BASS за наш радиус (сохраняем только 3D-панораму);
        -- реальную дальность задаёт DistanceVolume, обновляемый каждый кадр в Think.
        ch:Set3DFadeDistance(SND_SILENT, SND_SILENT * 4)
        ch:SetVolume(DistanceVolume(ent))
        ch:Play()

        tracker.channel = ch
    end

    if soundPath:find("^https?://") then
        sound.PlayURL(soundPath, flags, onChannel)
    else
        sound.PlayFile("sound/" .. soundPath, flags, onChannel)
    end
end

hook.Add("Think", "ix_boombox_audio", function()
    RefreshCache()

    for _, ent in ipairs(boomboxCache) do
        if not IsValid(ent) then continue end

        local idx       = ent:EntIndex()
        local soundPath = ent:GetNetVar("boombox_sound", "")
        local stime     = ent:GetNetVar("boombox_stime", 0)
        local current   = boomboxAudio[idx]

        if soundPath == "" then
            -- Cassette ejected or nothing loaded — stop audio.
            if current then StopChannel(idx) end
        else
            if not current or current.soundPath != soundPath then
                -- New cassette inserted (or first sync after join).
                StopChannel(idx)
                StartChannel(ent, soundPath, stime)
            elseif IsValid(current.channel) then
                -- Update 3D position AND distance-based volume every frame — without
                -- the per-frame SetVolume the boombox stays at its start volume as the
                -- listener walks away (why it was audible across the whole map).
                current.channel:SetPos(ent:GetPos())
                current.channel:SetVolume(DistanceVolume(ent))
            end
        end
    end

    -- Clean up channels whose entity no longer exists.
    for idx, data in pairs(boomboxAudio) do
        local ent = Entity(idx)
        if not IsValid(ent) or ent:GetClass() != "ix_boombox" then
            if data and IsValid(data.channel) then data.channel:Stop() end
            boomboxAudio[idx] = nil
        end
    end
end)

-- ─── Диалог записи кассеты ───────────────────────────────────────────────────
net.Receive("cassette.record", function()
	local itemID = net.ReadInt(32)
	Derma_StringRequest(
		"Название кассеты",
		"Введите название (оставьте пустым для сброса):",
		"",
		function(name)
			Derma_StringRequest(
				"Звуковой файл или URL",
				"Путь из sound/ (напр. music/song.mp3) или http(s)-ссылка:",
				"",
				function(track)
					net.Start("cassette.record.response")
						net.WriteInt(itemID, 32)
						net.WriteString(name)
						net.WriteString(track)
					net.SendToServer()
				end
			)
		end
	)
end)
