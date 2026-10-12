PLUGIN.name        = "End (No Text)"
PLUGIN.description = ""
PLUGIN.author      = ""

if SERVER then
	util.AddNetworkString("autonomous.ending.notext")
end

ix.command.Add("StartEndingNoText", {
	description    = "",
	OnCheckAccess = function(self, client)
		return IsValid(client) and client:IsAdmin()
	end,

	OnRun = function(self, client)
		if not SERVER or not IsValid(client) or not client:IsAdmin() then return end

		local players = player.GetAll()

		-- Действие необратимое и затрагивает весь сервер — оставляем след в логе.
		ServerLog(Format("[z_endingnotext] StartEndingNoText запущена игроком %s (%s)\n",
			client:Name(), client:SteamID()))

		net.Start("autonomous.ending.notext")
		net.Broadcast()

		for _, v in ipairs(players) do
			v:Freeze(true)

			local character = v:GetCharacter()
			if character then
				character:Health():Reset()
			end
		end
	end
})
