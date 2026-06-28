local PLUGIN = PLUGIN

-- Thin command layer registered on both realms (gives clients autocomplete and
-- proper dispatch). The OnRun bodies only ever execute server-side, where the
-- PLUGIN:* helpers in sv_plugin.lua are defined.

ix.command.Add("BlackoutCorner", {
	description = "Mark a blackout box corner at the point you are looking at.",
	privilege = "Manage Blackouts",
	adminOnly = true,
	OnRun = function(self, client)
		return PLUGIN:MarkCorner(client)
	end
})

ix.command.Add("BlackoutCreate", {
	description = "Create a blackout zone from your two marked corners. Height extends the box upward (default 512).",
	privilege = "Manage Blackouts",
	adminOnly = true,
	arguments = {
		ix.type.string,
		bit.bor(ix.type.number, ix.type.optional)
	},
	OnRun = function(self, client, name, height)
		return PLUGIN:CreateZone(client, name, height)
	end
})

ix.command.Add("BlackoutToggle", {
	description = "Toggle a blackout zone on/off by name.",
	privilege = "Manage Blackouts",
	adminOnly = true,
	arguments = { ix.type.string },
	OnRun = function(self, client, name)
		return PLUGIN:ToggleZone(name)
	end
})

ix.command.Add("BlackoutRemove", {
	description = "Delete a blackout zone and restore its lights.",
	privilege = "Manage Blackouts",
	adminOnly = true,
	arguments = { ix.type.string },
	OnRun = function(self, client, name)
		return PLUGIN:RemoveZone(name)
	end
})

ix.command.Add("BlackoutList", {
	description = "List all blackout zones.",
	privilege = "Manage Blackouts",
	adminOnly = true,
	OnRun = function(self, client)
		return PLUGIN:ListZones(client)
	end
})
