PLUGIN.name        = "Cassette Player"
PLUGIN.author      = "Hutten"
PLUGIN.description = "Boombox entity with insertable cassette items and 3D positional audio."

-- Load realm-specific files (Helix does NOT auto-load sv_plugin / cl_plugin).
ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")

-- Entity NetVars for ix_boombox.  Keys must be globally unique across all plugins.
-- boombox_cassette: display name of the loaded cassette ("" = nothing loaded)
-- boombox_sound   : sound file path currently playing
-- boombox_stime   : CurTime() value when playback started (for late-joiner sync)
ix.Net:AddEntityVar("boombox_cassette", nil, ix.Net.Type.All)
ix.Net:AddEntityVar("boombox_sound",    nil, ix.Net.Type.All)
ix.Net:AddEntityVar("boombox_stime",    nil, ix.Net.Type.All)

-- Add "Insert into player" function to all cassette items so it appears in the TAB menu.
-- sh_plugin.lua runs AFTER ix.Item:LoadFromDir, so ix.Item.stored is already populated.
-- IMPORTANT: after adding a function we must manually assign .index and update functions_id /
-- functions_bits, because Item:Register (which normally does this) has already run.
for uniqueID, item in pairs(ix.Item.stored or {}) do
	if item.isCassette then
		item.functions = item.functions or {}

		-- Count existing functions BEFORE adding so nextIdx is correct.
		local nextIdx = table.Count(item.functions) + 1

		item.functions.InsertCassette = {
			name  = "Вставить в плеер",
			index = nextIdx,   -- must be set here; Item:Register already ran

			-- Show button only when a boombox with no cassette is within 96 units.
			OnCanRun = function(itemTable)
				local client = itemTable.player
				if !IsValid(client) then return false end
				if IsValid(itemTable.entity) then return false end
				for _, ent in ipairs(ents.FindByClass("ix_boombox")) do
					if ent:GetPos():Distance(client:GetPos()) <= 96 then
						if ent:GetNetVar("boombox_cassette", "") == "" then
							return true
						end
					end
				end
				return false
			end,

			OnRun = function(itemTable)
				if SERVER then
					local client = itemTable.player
					local boombox
					for _, ent in ipairs(ents.FindByClass("ix_boombox")) do
						if ent:GetPos():Distance(client:GetPos()) <= 96 then
							if ent:GetNetVar("boombox_cassette", "") == "" then
								boombox = ent
								break
							end
						end
					end
					if IsValid(boombox) then
						boombox:OnSelectInsertCassette(client, itemTable.id)
					end
				end
				return false  -- item system must not drop/remove the item here
			end,
		}

		-- Keep functions_id and functions_bits in sync so the server can decode
		-- the action_index that the client writes into the net message.
		item.functions_id          = item.functions_id or {}
		item.functions_id[nextIdx] = "InsertCassette"
		item.functions_bits        = net.ChooseOptimalBits(table.Count(item.functions))
	end
end
