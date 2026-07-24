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

ix.command.Add("BlackoutFusebox", {
	description = "Place a repairable circuit box where you are looking (put it inside a blackout zone).",
	privilege = "Manage Blackouts",
	adminOnly = true,
	OnRun = function(self, client)
		return PLUGIN:PlaceFusebox(client)
	end
})

ix.command.Add("BlackoutFuseboxRemove", {
	description = "Remove the circuit box you are looking at.",
	privilege = "Manage Blackouts",
	adminOnly = true,
	OnRun = function(self, client)
		return PLUGIN:RemoveFusebox(client)
	end
})

-- Диагностика: почему сущность не обесточивается. Смотрим на неё и печатаем
-- каждое условие по отдельности — класс, попадание в зоны, состояние зон.
ix.command.Add("BlackoutDebug", {
	description = "Проверить, считается ли сущность под прицелом обесточенной.",
	adminOnly = true,
	OnRun = function(self, client)
		local entity = client:GetEyeTraceNoCursor().Entity

		client:PrintMessage(HUD_PRINTCONSOLE, "\n[Blackout debug]\n")

		if (!IsValid(entity)) then
			client:PrintMessage(HUD_PRINTCONSOLE, "  no entity under crosshair\n")
			return
		end

		local class = entity:GetClass()
		local pos = entity:GetPos()

		client:PrintMessage(HUD_PRINTCONSOLE, string.format("  entity: %s  pos: %s\n", class, tostring(pos)))
		client:PrintMessage(HUD_PRINTCONSOLE, string.format("  powered class: %s (exact=%s)\n",
			tostring(PLUGIN:IsPoweredClass(class)), tostring(PLUGIN.poweredClasses[class] == true)))
		client:PrintMessage(HUD_PRINTCONSOLE, string.format("  zones on server: %d\n", table.Count(PLUGIN.zones)))

		-- Владелец точки — самая тесная из накрывающих её зон. Именно ей
		-- принадлежат стоящие здесь щитки.
		local owner = PLUGIN:GetOwningZone(pos)

		for name, z in pairs(PLUGIN.zones) do
			client:PrintMessage(HUD_PRINTCONSOLE, string.format(
				"    zone '%s' active=%s  min=%s max=%s  contains entity: %s | contains you: %s | owns it: %s\n",
				name, tostring(z.active), tostring(z.min), tostring(z.max),
				tostring(pos:WithinAABox(z.min, z.max)),
				tostring(client:GetPos():WithinAABox(z.min, z.max)),
				tostring(z == owner)))
		end

		client:PrintMessage(HUD_PRINTCONSOLE, string.format("  IsPosBlackedOut(entity): %s\n", tostring(PLUGIN:IsPosBlackedOut(pos))))
		client:PrintMessage(HUD_PRINTCONSOLE, string.format("  IsEntityBlackedOut:      %s\n", tostring(PLUGIN:IsEntityBlackedOut(entity))))
		client:PrintMessage(HUD_PRINTCONSOLE, string.format("  has ENT:Use: %s\n", tostring(isfunction(entity.Use))))

		client:Notify("Результат в консоли (~).")
	end
})
