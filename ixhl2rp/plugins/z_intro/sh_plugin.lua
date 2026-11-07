PLUGIN.name = "Intro Sequence"
PLUGIN.description = "Показывает кинематографичное интро игрокам."
PLUGIN.author = "Крутой ИИ"

-- The plugin loader includes derma/cl_intro.lua on clients.

if SERVER then
	util.AddNetworkString("autonomous.intro")
end

ix.command.Add("StartIntro", {
	description = "Показать интро всем игрокам.",
	OnCheckAccess = function(self, client)
		return IsValid(client) and client:IsAdmin()
	end,
	OnRun = function(self, client)
		if not SERVER or not IsValid(client) or not client:IsAdmin() then return end

		net.Start("autonomous.intro")
		net.Broadcast()

		client:ChatPrint("[INTRO] Интро запущено для всех игроков.")
	end
})
