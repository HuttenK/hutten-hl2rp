PLUGIN.name = "End"
PLUGIN.description = ""
PLUGIN.author = ""

if SERVER then
	util.AddNetworkString("autonomous.ending")
end

ix.command.Add("StartEnding", {
	description = "",
	-- ВНИМАНИЕ: ключ пишется именно superAdminOnly (заглавная A). Было
	-- superadminOnly — Lua регистрозависим, поэтому helix читал nil и
	-- регистрировал CAMI-привилегию с MinAccess = "user" (см. helix
	-- gamemode/core/libs/sh_command.lua:197). Команду мог запустить ЛЮБОЙ
	-- игрок: заморозка всех на сервере и сброс здоровья.
	superAdminOnly = true,
	OnRun = function(self, client)
		local players = player.GetAll()

		-- Действие необратимое и затрагивает весь сервер — оставляем след в логе.
		ServerLog(Format("[z_ending] StartEnding запущена игроком %s (%s)\n",
			client:Name(), client:SteamID()))

		net.Start("autonomous.ending")
		net.Broadcast()

		for k, v in ipairs(players) do
			v:Freeze(true)

			local character = v:GetCharacter()
			if character then
				character:Health():Reset()
			end
		end
	end
})
