PLUGIN.name = "End"
PLUGIN.description = ""
PLUGIN.author = ""

if SERVER then
	util.AddNetworkString("autonomous.ending")
end

ix.command.Add("StartEnding", {
	description = "",
	superadminOnly = true,
	OnRun = function(self, client)
		local players = player.GetAll()

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
