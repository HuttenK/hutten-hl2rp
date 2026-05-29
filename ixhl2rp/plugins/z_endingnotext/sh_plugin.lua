PLUGIN.name        = "End (No Text)"
PLUGIN.description = ""
PLUGIN.author      = ""

if SERVER then
	util.AddNetworkString("autonomous.ending.notext")
end

ix.command.Add("StartEndingNoText", {
	description    = "",
	superadminOnly = true,

	OnRun = function(self, client)
		local players = player.GetAll()

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
