local PLUGIN = PLUGIN

PLUGIN.name        = "ArcCW Item Attachments"
PLUGIN.author      = "Blaze Project"
PLUGIN.description = "Saves ArcCW weapon attachments per item instance, not per player."

-- Serialize weapon attachments to a saveable table.
-- Returns nil if the weapon has no ArcCW attachments.
function PLUGIN.SerializeAtts(weapon)
	if not IsValid(weapon) or not weapon.ArcCW or not weapon.Attachments then
		return nil
	end

	local data = {}
	local hasAny = false

	for slot, info in pairs(weapon.Attachments) do
		if not istable(info) then continue end
		if not info.Installed or info.Installed == "" then continue end

		data[slot] = {
			Installed  = info.Installed,
			SlidePos   = info.SlidePos   or 0.5,
			ToggleNum  = info.ToggleNum  or 1,
			ColorOptionIndex = info.ColorOptionIndex,
		}
		hasAny = true
	end

	return hasAny and data or nil
end

-- Save attachments from a live weapon into its Helix item.
function PLUGIN.SaveAtts(weapon)
	if not IsValid(weapon) then return end

	local item = weapon.ixItem
	if not item then return end

	local data = PLUGIN.SerializeAtts(weapon)

	-- Always write (even nil) so stale data is cleared when all atts removed.
	item:SetData("arccw_atts", data)
end

if SERVER then
	util.AddNetworkString("arccw_item_atts_apply")
	MsgN("[arccw_atts] sh_plugin.lua loaded on SERVER")
end

ix.util.Include("sv_plugin.lua", "server")
ix.util.Include("cl_plugin.lua", "client")
