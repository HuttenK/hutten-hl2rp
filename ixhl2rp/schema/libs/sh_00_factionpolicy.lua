-- Three active factions. Load-time allowlists also ignore stale files left by
-- an overlay deployment; removed HL2RP factions must never register again.
Schema.factionAllowlist = {citizen = true, foundation = true, mtf = true}
Schema.classAllowlist = {citizen = true, foundation = true, mtf = true}
Schema.creationFactions = {citizen = true}

-- Legacy item restrictions still reference these constants. Reserve invalid,
-- distinct team IDs rather than accidentally granting their rights to SCP teams.
local retired = {"ADMIN", "ADMIN_HEAD", "CWU_1", "CWU_2", "CWU_HEAD",
	"MED", "MED_HEAD", "MPF", "OTA", "EOW", "SECADMIN", "VORTIGAUNT",
	"CONSCRIPT", "CONSCRIPT_BIOTIC", "OVERWATCH", "ZOMBIE", "SYNTH"}
for index, name in ipairs(retired) do _G["FACTION_" .. name] = -1000 - index end

function Schema:ResetFactionClass(character, faction)
	for index, class in ipairs(ix.class.list) do
		if class.faction == faction and class.isDefault then
			character:SetClass(index)
			return
		end
	end
	character:SetClass(0)
end
