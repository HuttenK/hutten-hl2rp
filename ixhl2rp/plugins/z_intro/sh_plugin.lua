PLUGIN.name = "Intro Sequence"
PLUGIN.description = "Показывает кинематографичное интро игрокам."
PLUGIN.author = "Крутой ИИ"

-- Подключаем ваш файл с визуальной частью (он должен лежать в этой же папке)
ix.util.Include("cl_intro.lua")

if SERVER then
	util.AddNetworkString("autonomous.intro")
end

ix.command.Add("StartIntro", {
	description = "Показать интро всем игрокам.",
	adminOnly = true,
	OnRun = function(self, client)
		net.Start("autonomous.intro")
		net.Broadcast()

		client:ChatPrint("[INTRO] Интро запущено для всех игроков.")
	end
})