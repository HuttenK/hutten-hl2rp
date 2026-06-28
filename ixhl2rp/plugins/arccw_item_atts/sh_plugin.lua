local PLUGIN = PLUGIN

PLUGIN.name        = "ArcCW Item Attachments"
PLUGIN.author      = "Hutten"
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
--
-- bAllowClear: pass true ONLY for an explicit user customization action (a real
-- attach/detach via the ArcCW menu). For incidental saves (unequip, drop, etc.)
-- leave it false: if the live weapon is empty but the item still has saved
-- attachments, we must NOT overwrite them. A freshly-given weapon (e.g. equipped
-- across a server restart) starts empty until ApplyAtts runs; saving that empty
-- state would erase the real data from the item and the database.
function PLUGIN.SaveAtts(weapon, bAllowClear)
	if not IsValid(weapon) then return end

	local item = weapon.ixItem
	if not item then return end

	local data = PLUGIN.SerializeAtts(weapon)

	-- Guard against destructive "empty" saves of an unapplied weapon.
	if data == nil and not bAllowClear and item:GetData("arccw_atts") then
		return
	end

	item:SetData("arccw_atts", data)
end

if SERVER then
	util.AddNetworkString("arccw_item_atts_apply")
	MsgN("[arccw_atts] sh_plugin.lua loaded on SERVER")
end

-- NOTE: the arccw_atts data key is registered in the shared weapon base
-- (ammo_cringe/items/base/weapon.lua) Init, so it exists identically on both
-- realms for every weapon. Do NOT register it here or in a server-only file:
-- a realm mismatch corrupts the per-key item.data sync, and a server-only or
-- timer-based registration can race item loading and miss weapons (breaking
-- attachment persistence).

ix.util.Include("sv_plugin.lua", "server")
ix.util.Include("cl_plugin.lua", "client")
