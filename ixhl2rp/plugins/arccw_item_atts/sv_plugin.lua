local PLUGIN = PLUGIN
MsgN("[arccw_atts] sv_plugin.lua loaded")

-- ============================================================
-- Gunsmith workbench: paid ArcCW customization.
-- Customization is allowed for admins, or for any player standing
-- within range of an ix_gunsmith bench. Each charged modification
-- (install/remove an attachment) costs RESIN_COST resin.
-- ============================================================
local RESIN_ITEM     = "resin"
local RESIN_COST     = 5
local GUNSMITH_RANGE = 200

-- Which ArcCW messages count as a paid change. Slide/toggle/colour are
-- free fine-tuning of an already-installed part; add their message names
-- here (e.g. arccw_slidepos = true) to charge for those too.
local CHARGED = {
	arccw_asktoattach = true,
	arccw_asktodetach = true,
}

local function NearGunsmith(ply)
	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), GUNSMITH_RANGE)) do
		if IsValid(ent) and ent:GetClass() == "ix_gunsmith" then
			return true
		end
	end

	return false
end

-- Authoritative gate: admins always, otherwise must be next to a bench.
local function CanCustomize(ply)
	return IsValid(ply) and (ply:IsAdmin() or NearGunsmith(ply))
end

local function CountResin(ply)
	local inventory = ply:GetInventory("main")
	if not inventory then return 0 end

	local total = 0

	for _, item in pairs(inventory:GetItems()) do
		if item.uniqueID == RESIN_ITEM then
			total = total + (item:GetData("stack") or 1)
		end
	end

	return total
end

local function TakeResin(ply, amount)
	local inventory = ply:GetInventory("main")
	if not inventory or CountResin(ply) < amount then return false end

	local need = amount

	for _, item in pairs(inventory:GetItems()) do
		if need <= 0 then break end

		if item.uniqueID == RESIN_ITEM then
			local stack = item:GetData("stack") or 1

			if stack > need then
				item:SetData("stack", stack - need)
				need = 0
			else
				need = need - stack
				item:Remove()
			end
		end
	end

	return need <= 0
end

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
-- Customization is gated by CanCustomize (admin or near a gunsmith bench),
-- and CHARGED messages consume resin from the player first.
local function WrapArcCWReceiver(msgName)
	local existing = net.Receivers and net.Receivers[msgName]
	if not existing then
		MsgN("[arccw_atts] WARNING: no receiver for " .. msgName)
		return
	end

	net.Receive(msgName, function(len, ply)
		if not CanCustomize(ply) then return end

		-- Charge resin for structural changes (admins customise for free).
		if CHARGED[msgName] and not ply:IsAdmin() then
			if not TakeResin(ply, RESIN_COST) then
				ply:NotifyLocalized("gunsmith.needResin", RESIN_COST)

				-- Re-sync the live weapon so the client reverts any optimistic change.
				local wep = ply:GetActiveWeapon()
				if IsValid(wep) and wep.NetworkWeapon then
					wep:NetworkWeapon()
				end

				return
			end
		end

		existing(len, ply)

		timer.Simple(0, function()
			if not IsValid(ply) then return end
			local wep = ply:GetActiveWeapon()
			if not IsValid(wep) or not wep.ArcCW or not wep.ixItem then return end
			MsgN("[arccw_atts] " .. msgName .. " -> saving atts for " .. wep:GetClass())
			-- Explicit user customization: authoritative, may clear to empty.
			PLUGIN.SaveAtts(wep, true)
		end)
	end)

	MsgN("[arccw_atts] Wrapped " .. msgName)
end

local function PatchWeaponItem(proto)
	-- NOTE: the arccw_atts data key is registered in the shared weapon base
	-- (ammo_cringe/items/base/weapon.lua) Init, on BOTH realms. It must NOT be
	-- added here (server-only) or the server/client var_max_bits desync and
	-- per-key item.data pushes (e.g. equip) break.

	-- ----------------------------------------------------------------
	-- OnEquipWeapon: block ArcCW autosave preset, then apply item atts.
	-- ----------------------------------------------------------------
	local origEquip = proto.OnEquipWeapon
	function proto:OnEquipWeapon(client, weapon)
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

	-- Wrap ArcCW customization receivers. Each is gated by CanCustomize
	-- (admin or near a gunsmith bench); attach/detach also cost resin.
	WrapArcCWReceiver("arccw_asktoattach")
	WrapArcCWReceiver("arccw_asktodetach")
	WrapArcCWReceiver("arccw_slidepos")
	WrapArcCWReceiver("arccw_togglenum")
	WrapArcCWReceiver("arccw_colorindex")

	-- Gate the customization menu toggle. arccw_togglecustomize opens/closes
	-- the attachment UI on the client; only allow it at a gunsmith bench.
	local existingToggle = net.Receivers and net.Receivers["arccw_togglecustomize"]
	if existingToggle then
		net.Receive("arccw_togglecustomize", function(len, ply)
			if not CanCustomize(ply) then
				-- Tell client to close (force state = false) so it doesn't get stuck.
				net.Start("arccw_togglecustomize")
					net.WriteBool(false)
				net.Send(ply)
				return
			end
			existingToggle(len, ply)
		end)
		MsgN("[arccw_atts] Wrapped arccw_togglecustomize (gunsmith-gated)")
	end
end)

-- Save when weapon is physically dropped via G key.
hook.Add("PlayerDroppedWeapon", "arccw_item_atts_drop", function(client, weapon)
	if not IsValid(weapon) or not weapon.ArcCW or not weapon.ixItem then return end
	MsgN("[arccw_atts] PlayerDroppedWeapon: saving for " .. weapon:GetClass())
	PLUGIN.SaveAtts(weapon)
end)

-- Re-apply saved attachments whenever an item weapon is actually deployed.
--
-- Weapons equipped via OnLoadout (i.e. already equipped across a server
-- restart) are NEVER deployed at spawn: PostPlayerLoadout ends with
-- SelectWeapon("ix_hands"), so the +0.5s ApplyAtts in OnEquipWeapon runs
-- before the weapon is ever drawn. ArcCW loads its own per-class preset
-- (data/arccw_presets/<class>) on first deploy, overwriting our atts. The
-- item data itself is fine (data.arccw_atts=YES at spawn) — it just never
-- makes it onto the live weapon. Applying on deploy fixes that, and also
-- covers the normal equip path idempotently.
hook.Add("PlayerSwitchWeapon", "arccw_item_atts_deploy", function(client, oldWeapon, newWeapon)
	if not IsValid(newWeapon) or not newWeapon.ArcCW then return end

	local item = newWeapon.ixItem
	if not item or not item.isWeapon then return end

	-- Don't let ArcCW autosave clobber our managed data on this weapon.
	newWeapon:SetNWBool("ArcCW_DisableAutosave", true)

	-- Defer so we run after ArcCW's deploy/preset load completes.
	timer.Simple(0.1, function()
		if not IsValid(newWeapon) or not IsValid(client) then return end
		if client:GetActiveWeapon() ~= newWeapon then return end
		ApplyAtts(newWeapon, item, client)
	end)
end)

-- ----------------------------------------------------------------
-- Persist admin-placed gunsmith benches across restarts.
-- ----------------------------------------------------------------
function PLUGIN:SaveData()
	local data = {}

	for _, ent in ipairs(ents.FindByClass("ix_gunsmith")) do
		data[#data + 1] = { ent:GetPos(), ent:GetAngles() }
	end

	self:SetData(data)
end

function PLUGIN:LoadData()
	for _, v in ipairs(self:GetData() or {}) do
		local ent = ents.Create("ix_gunsmith")

		if IsValid(ent) then
			ent:SetPos(v[1])
			ent:SetAngles(v[2])
			ent:Spawn()

			local phys = ent:GetPhysicsObject()

			if IsValid(phys) then
				phys:EnableMotion(false)
			end
		end
	end
end
