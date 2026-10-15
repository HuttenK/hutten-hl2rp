local PLUGIN = PLUGIN

PLUGIN.name = "Prone Support"
PLUGIN.author = "Schwarz Kruppzo"
PLUGIN.description = ""

-- This schema uses injury-driven crawling. The addon's independent voluntary
-- state does not match our animation driver and must not be entered by a bind,
-- a console command, or a manually sent prone impulse.
PLUGIN["prone.CanEnter"] = function() return false end
PLUGIN["prone.AllowInput"] = function() return false end
PLUGIN["prone.ShouldChangeCalcView"] = function() return false end
PLUGIN["prone.ShouldChangeCalcViewModelView"] = function() return false end

function PLUGIN:DoPlayerDeath(player)
	if player:IsProne() then
		prone.Exit(player)
	end
end

function PLUGIN:PlayerLoadedCharacter(player)
	if player:IsProne() then
		prone.Exit(player)
	end
end
