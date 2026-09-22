local PLUGIN = PLUGIN

PLUGIN.name = "Ambient Music"
PLUGIN.description = "Ambient Music"
PLUGIN.author = "Schwarz Kruppzo"

if SERVER then 
	return
end

local timerID = "ixAmbient"
-- Tracks bundled with Half-Life 2 / Garry's Mod; no custom music pack.
local ambients = {
 {"music/hl2_song7.mp3"}, {"music/hl2_song8.mp3"},
 {"music/hl2_song14.mp3"}, {"music/hl2_song16.mp3"},
 {"music/hl2_song19.mp3"}, {"music/hl2_song26.mp3"}
}

local function SetVolume(volume)
	if PLUGIN.snd then 
		PLUGIN.snd:ChangeVolume(volume)
	end
end

local function StopAmbient()
	if timer.Exists(timerID) then
		timer.Remove(timerID)
	end

	if PLUGIN.snd then
		PLUGIN.snd:Stop()
		PLUGIN.snd = nil
	end
end

local function PlayAmbient(ambientData)
	StopAmbient()

	if not IsValid(LocalPlayer()) then return end
 PLUGIN.snd = CreateSound(LocalPlayer(), ambientData[1])
 if not PLUGIN.snd then return end
	PLUGIN.snd:Play()
	
	local playing=PLUGIN.snd
 timer.Simple(0, function()
  if PLUGIN.snd~=playing then return end
		playing:ChangeVolume(ix.option.Get("ambientVol"), 0)
	end)

	local time = ambientData[2]

	if !time then
		time = SoundDuration(ambientData[1])
	end
	
	timer.Create(timerID, math.max(time or 0, 30) + ix.option.Get("ambientTime", 0), 1, function()
		PlayAmbient(ambients[math.random(1, #ambients)])
	end)
end

function PLUGIN:CharacterLoaded(character)
	if timer.Exists(timerID) or !ix.option.Get("ambientToggle") then
		return
	end

	PlayAmbient(ambients[math.random(1, #ambients)])
end

ix.option.Add("ambientToggle", ix.type.bool, true, {
	category = "option.category.music",
	OnChanged = function(_, value)
		if !value then
			StopAmbient()
			return
		end

		PlayAmbient(ambients[math.random(1, #ambients)])
	end
})

ix.option.Add("ambientVol", ix.type.number, 1, {
	category = "option.category.music",
	decimals = 2,
	min = 0.01, 
	max = 1, 
	OnChanged = function(_, value)
		SetVolume(value)
	end
})

ix.option.Add("ambientTime", ix.type.number, 0, {
	category = "option.category.music",
	decimals = 0,
	min = 0, 
	max = 600
})