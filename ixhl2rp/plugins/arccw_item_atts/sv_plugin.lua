local PLUGIN = PLUGIN
MsgN("[arccw_atts] sv_plugin.lua loaded")

-- Apply saved attachments to a weapon from its item data.
local function ApplyAtts(weapon, item, client)
	if not IsValid(weapon) or not weapon.ArcCW then return end

	local data = item:GetData("arccw_atts")
	MsgN("[arccw_atts] ApplyAtts id=" .. tostring(item.id) .. " data=" .. tostring(data and "YES" or "nil"))

	-- Clear whatever ArcCW may have auto-applied.
	if weapon.Attachments then
		for slot, info in pairs(weapon.Attachments) do
			if istable(info) and info.Installed then
				weapon:Detach(slot, true, true)
			end
		end
	end

	if not data or table.IsEmpty(data) then
		weapon:AdjustAtts()
		weapon:RefreshBGs()
		weapon:NetworkWeapon()
		MsgN("[arccw_atts] No saved atts - cleared.")
		return
	end

	for slot, info in SortedPairs(data) do
		slot = tonumber(slot)
		if not slot then continue end

		local attname = info.Installed
		if not attname or attname == "" then continue end
		if not ArcCW.AttachmentTable or not ArcCW.AttachmentTable[attname] then continue end

		weapon:Attach(slot, attname, true, true)
		MsgN("[arccw_atts]   slot " .. slot .. " = " .. attname)

		local slotData = weapon.Attachments and weapon.Attachments[slot]
		if slotData then
			slotData.SlidePos  = info.SlidePos  or 0.5
			slotData.ToggleNum = info.ToggleNum or 1
			if info.ColorOptionIndex then
				slotData.ColorOptionIndex = info.ColorOptionIndex
			end
		end
	end

	weapon:AdjustAtts()
	weapon:RefreshBGs()
	weapon:NetworkWeapon()

	if IsValid(client) then
		net.Start("arccw_item_atts_apply")
			net.WriteEntity(weapon)
		net.Send(client)
	end
end

-- Wrap a server-side ArcCW net receiver so we save after it processes.
-- If adminOnly = true, non-admins are silently blocked.
local function WrapArcCWReceiver(msgName, adminOnly)
	local existing = net.Receivers and net.Receivers[msgName]
	if not existing then
		MsgN("[arccw_atts] WARNING: no receiver for " .. msgName)
		return
	end

	net.Receive(msgName, function(len, ply)
		if adminOnly and not ply:IsAdmin() then return end

		existing(len, ply)

		timer.Simple(0, function()
			if not IsValid(ply) then return end
			local wep = ply:GetActiveWeapon()
			if not IsValid(wep) or not wep.ArcCW or not wep.ixItem then return end
			MsgN("[arccw_atts] " .. msgName .. " -> saving atts for " .. wep:GetClass())
			PLUGIN.SaveAtts(wep)
		end)
	end)

	MsgN("[arccw_atts] Wrapped " .. msgName)
end

local function PatchWeaponItem(proto)
	-- ----------------------------------------------------------------
	-- Register arccw_atts data key so SetData/GetData actually work.
	-- Without this, SetData silently returns at the !self.vars[key] check.
	-- ----------------------------------------------------------------
	if not proto.vars["arccw_atts"] then
		proto:AddData("arccw_atts", {
			Transmit = ix.transmit.none,  -- server-only, no net sync needed
			NoSave   = false,              -- persist to database
		})
	end

	-- ----------------------------------------------------------------
	-- OnEquipWeapon: block ArcCW autosave preset, then apply item atts.
	-- ----------------------------------------------------------------
	local origEquip = proto.OnEquipWeapon
	function proto:OnEquipWeapon(client, weapon)
		MsgN("[arccw_atts] OnEquipWeapon: " .. tostring(self.uniqueID) .. " id=" .. tostring(self.id))
		if origEquip then origEquip(self, client, weapon) end
		if not IsValid(weapon) or not weapon.ArcCW then return end

		weapon:SetNWBool("ArcCW_DisableAutosave", true)
		client.ArcCW_DisableAutosave = true

		local item = self
		timer.Simple(0.5, function()
			if not IsValid(weapon) or not IsValid(client) then
				if IsValid(client) then client.ArcCW_DisableAutosave = nil end
				return
			end
			ApplyAtts(weapon, item, client)
			client.ArcCW_DisableAutosave = nil
		end)
	end

	-- ----------------------------------------------------------------
	-- Patch Unequip: save BEFORE StripWeapon (weapon still valid here).
	-- Called by the "unequip" inventory action.
	-- ----------------------------------------------------------------
	local origUnequip = proto.Unequip
	function proto:Unequip(user, bPlaySound, bRemoveItem)
		MsgN("[arccw_atts] Unequip: " .. tostring(self.uniqueID) .. " id=" .. tostring(self.id))
		local owner = self:GetOwner()
		if IsValid(owner) then
			local wep = owner:GetWeapon(self.class)
			if IsValid(wep) and wep.ArcCW then
				MsgN("[arccw_atts] Saving before Unequip strip...")
				PLUGIN.SaveAtts(wep)
			end
		end
		if origUnequip then return origUnequip(self, user, bPlaySound, bRemoveItem) end
	end

	-- ----------------------------------------------------------------
	-- Patch OnDrop: save BEFORE StripWeapon.
	-- OnDrop is called by the inventory "drop" action — it bypasses
	-- Unequip entirely and calls StripWeapon directly.
	-- ----------------------------------------------------------------
	local origOnDrop = proto.OnDrop
	function proto:OnDrop(client, inventory)
		MsgN("[arccw_atts] OnDrop: " .. tostring(self.uniqueID) .. " id=" .. tostring(self.id))
		-- inventory.owner is the player; client may be nil if someone else dropped it
		local owner = (inventory and inventory.owner) or client
		if IsValid(owner) then
			local wep = owner:GetWeapon(self.class)
			if IsValid(wep) and wep.ArcCW then
				MsgN("[arccw_atts] Saving before OnDrop strip...")
				PLUGIN.SaveAtts(wep)
			end
		end
		if origOnDrop then return origOnDrop(self, client, inventory) end
	end
end

-- Patch every loaded weapon prototype.
timer.Simple(0, function()
	local count = 0
	for uniqueID, proto in pairs(ix.Item.stored or {}) do
		if proto.isWeapon then
			PatchWeaponItem(proto)
			count = count + 1
		end
	end
	MsgN("[arccw_atts] Patched " .. count .. " weapon item prototypes.")

	-- Wrap ArcCW customization receivers.
	-- adminOnly = true: non-admins are blocked server-side.
	WrapArcCWReceiver("arccw_asktoattach",  true)
	WrapArcCWReceiver("arccw_asktodetach",  true)
	WrapArcCWReceiver("arccw_slidepos",     true)
	WrapArcCWReceiver("arccw_togglenum",    true)
	WrapArcCWReceiver("arccw_colorindex",   true)

	-- Block the customization menu toggle for non-admins.
	-- arccw_togglecustomize opens/closes the attachment UI on the client.
	local existingToggle = net.Receivers and net.Receivers["arccw_togglecustomize"]
	if existingToggle then
		net.Receive("arccw_togglecustomize", function(len, ply)
			if not ply:IsAdmin() then
				-- Tell client to close (force state = false) so it doesn't get stuck.
				net.Start("arccw_togglecustomize")
					net.WriteBool(false)
				net.Send(ply)
				return
			end
			existingToggle(len, ply)
		end)
		MsgN("[arccw_atts] Wrapped arccw_togglecustomize (admin-only)")
	end
end)

-- Save when weapon is physically dropped via G key.
hook.Add("PlayerDroppedWeapon", "arccw_item_atts_drop", function(client, weapon)
	if not IsValid(weapon) or not weapon.ArcCW or not weapon.ixItem then return end
	MsgN("[arccw_atts] PlayerDroppedWeapon: saving for " .. weapon:GetClass())
	PLUGIN.SaveAtts(weapon)
end)
