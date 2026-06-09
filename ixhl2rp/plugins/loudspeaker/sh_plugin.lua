local PLUGIN = PLUGIN

PLUGIN.name        = "Loudspeaker"
PLUGIN.author      = "Blaze Project"
PLUGIN.description = "Plays a synchronized sound from all speaker props on the map."

PLUGIN.speakerModel   = "models/props_wasteland/speakercluster01a.mdl"
PLUGIN.defaultSound   = ""
PLUGIN.soundStartTime = 0

if SERVER then
	util.AddNetworkString("ix_ls_sound")
end

-- /loudspeaker <sound_path>
-- Example: /loudspeaker ambient/alarms/citadel_alert_loop1.wav
ix.command.Add("loudspeaker", {
	description = "Запустить звук на всех громкоговорителях.",
	adminOnly   = true,
	arguments   = { ix.type.string },
	OnRun = function(self, client, soundPath)
		if soundPath == "" then return "@commandInvalidArg" end

		PLUGIN.defaultSound   = soundPath
		PLUGIN.soundStartTime = CurTime()
		ix.data.Set("ls_sound", soundPath)
		ix.data.Set("ls_sound_start", PLUGIN.soundStartTime)

		net.Start("ix_ls_sound")
			net.WriteString(soundPath)
			net.WriteDouble(PLUGIN.soundStartTime)
		net.Broadcast()

		client:ChatPrint("[Loudspeaker] Звук запущен: " .. soundPath)
	end
})

-- /loudspeakerstop
ix.command.Add("loudspeakerstop", {
	description = "Остановить звук на всех громкоговорителях.",
	adminOnly   = true,
	OnRun = function(self, client)
		PLUGIN.defaultSound   = ""
		PLUGIN.soundStartTime = 0
		ix.data.Set("ls_sound", "")

		net.Start("ix_ls_sound")
			net.WriteString("")
			net.WriteDouble(0)
		net.Broadcast()

		client:ChatPrint("[Loudspeaker] Звук остановлен.")
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
