local PLUGIN = PLUGIN

PLUGIN.name        = "VRMod Compat"
PLUGIN.description = "Integrates VRMod x64 with ixhl2rp"
PLUGIN.author      = "Autonomous Team"

-- ─────────────────────────────────────────────────────────────────────────────
-- SHARED: безопасные заглушки если VRMod не загружен
-- ─────────────────────────────────────────────────────────────────────────────

local function VRModLoaded()
	return vrmod ~= nil and vrmod.IsPlayerInVR ~= nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVER
-- ─────────────────────────────────────────────────────────────────────────────

if SERVER then

	-- ── 1. Телепортация: разрешена только суперадминам ──────────────────────
	hook.Add("InitPostEntity", "ixVRCompat_Teleport", function()
		if not VRModLoaded() then return end
		RunConsoleCommand("vrmod_allow_teleport", "1")
	end)

	hook.Add("PlayerNoClip", "ixVRCompat_TeleportAccess", function(ply, desiredState)
		if not VRModLoaded() then return end
		if not ply:GetNWBool("ixInVR", false) then return end
		if not ply:IsSuperAdmin() then
			return false
		end
	end, HOOK_LOW)

	-- ── 2. Маркировка VR-игроков ──────────────────────────────────────────────
	hook.Add("VRMod_Start", "ixVRCompat_TagPlayer", function(ply)
		if IsValid(ply) then ply:SetNWBool("ixInVR", true) end
	end)

	hook.Add("VRMod_Exit", "ixVRCompat_UntagPlayer", function(ply)
		if IsValid(ply) then ply:SetNWBool("ixInVR", false) end
	end)

	-- ── 3. Ближний бой VR ─────────────────────────────────────────────────────
	hook.Add("VRMod_MeleeHit", "ixVRCompat_MeleeCheck", function(hitData, callback)
		if not IsValid(hitData.Attacker) then return end
		local attacker = hitData.Attacker
		local target   = hitData.HitEntity
		if not attacker:GetCharacter() or not attacker:Alive() then
			callback(nil, nil, 0); return
		end
		if attacker:IsRestricted() then
			callback(nil, nil, 0); return
		end
		if IsValid(target) and target:IsPlayer() then
			if not target:GetCharacter() then
				callback(nil, nil, 0); return
			end
		end
		if hitData.ImpactType == "fist" or hitData.ImpactType == "head" then
			if attacker.ProcessMeleeStamina then
				local canHit = attacker:ProcessMeleeStamina(4)
				if not canHit then callback(nil, nil, 0); return end
			end
		end
	end)

	-- ── 4. Подбор предметов: ix_item через VR-руки ───────────────────────────
	hook.Add("VRMod_Pickup", "ixVRCompat_ItemPickup", function(ply, ent)
		if not IsValid(ent) or not IsValid(ply) then return end
		if ent:GetClass() == "ix_item" then
			if ply:IsRestricted() then return false end
			local item = ent:GetItem()
			if item then
				local canTake = item.functions
					and item.functions.take
					and item.functions.take.OnCanRun
					and item.functions.take.OnCanRun(item)
				if canTake then
					ix.Item:PerformItemEntityAction(ply, item, ent, "take")
				end
			end
			return false
		end
	end)

	hook.Add("OnEntityCreated", "ixVRCompat_ItemBlacklist", function(ent)
		timer.Simple(0, function()
			if IsValid(ent) and ent:GetClass() == "ix_item" then
				ent._vrmod_pickupable = false
			end
		end)
	end)

	-- ── 5. Взвод/опуск оружия ────────────────────────────────────────────────
	util.AddNetworkString("ixVRRaiseWeapon")

	-- ── 6. VR-дроп оружия → Helix DropItem ───────────────────────────────────
	hook.Add("VRMod_PreDropWeapon", "ixVRCompat_DropWeapon", function(ply, wep, dropPos, dropAng)
		if not ply:GetNWBool("ixInVR", false) then return end
		if not ply:GetCharacter() then return end
		local inv = ply:GetInventory("main")
		if not inv then return end
		local weaponClass = wep:GetClass()
		for _, itemID in ipairs(inv:GetItemsID()) do
			local item = ix.Item.instances[itemID]
			if item and item.class == weaponClass and item:GetData("equip") then
				ix.Item:DropItem(ply, {itemID}, dropPos, dropAng)
				return false
			end
		end
	end)

	net.Receive("ixVRRaiseWeapon", function(len, ply)
		if not IsValid(ply) then return end
		if not ply:GetNWBool("ixInVR", false) then return end
		if not ply:GetCharacter() then return end
		if ply:IsRestricted() then return end
		local weapon = ply:GetActiveWeapon()
		if not IsValid(weapon) then return end
		if weapon.IsAlwaysLowered or weapon.NeverRaised then return end
		ply:ToggleWepRaised()
	end)

end -- SERVER

-- ─────────────────────────────────────────────────────────────────────────────
-- CLIENT
-- ─────────────────────────────────────────────────────────────────────────────

if CLIENT then

	local function AddHelixMenuItems()
		if not VRModLoaded() then return end
		if not vrmod.AddInGameMenuItem then return end

		vrmod.AddInGameMenuItem("Меню [TAB]", nil, nil, function()
			if IsValid(ix.gui.menu) then
				ix.gui.menu:Close()
			else
				local menu = vgui.Create("ui.tabmenu")
				if IsValid(menu) then menu:MakePopup() end
			end
		end)

		vrmod.AddInGameMenuItem("Чат", nil, nil, function()
			RunConsoleCommand("vrmod_chatmode")
		end)

		vrmod.AddInGameMenuItem("Взвести/Опустить", nil, nil, function()
			net.Start("ixVRRaiseWeapon")
			net.SendToServer()
		end)
	end

	hook.Add("VRMod_HelixRaiseWeapon", "ixVRCompat_RaiseWeapon", function()
		net.Start("ixVRRaiseWeapon")
		net.SendToServer()
	end)

	local function RemoveHelixMenuItems()
		if not VRModLoaded() then return end
		if not vrmod.RemoveInGameMenuItem then return end
		vrmod.RemoveInGameMenuItem("Меню [TAB]")
		vrmod.RemoveInGameMenuItem("Чат")
		vrmod.RemoveInGameMenuItem("Взвести/Опустить")
	end

	-- ── 8. Полноэкранный HUD ──────────────────────────────────────────────────
	local ixVRHudRT      = nil
	local ixVRHudMat     = nil
	local ixHudLastRender = -1
	local IX_HUD_INTERVAL = 1 / 30
	local ixPlayerInVR   = false

	local function EnableFullscreenHUD()
		RunConsoleCommand("vrmod_hud", "0")
	end

	local function DisableFullscreenHUD()
		RunConsoleCommand("vrmod_hud", "1")
		ixVRHudRT      = nil
		ixVRHudMat     = nil
		ixHudLastRender = -1
		ixPlayerInVR   = false
	end

	-- ── 10. VR animation isolation ───────────────────────────────────────────
	local function ixIsVRPlayer(ply)
		return g_VR and g_VR.net and g_VR.net[ply:SteamID()] ~= nil
	end

	local function ixVRCalcMainActivity(ply, vel)
		if not ixIsVRPlayer(ply) then return end
		if ply:InVehicle() then return end

		local _, convarValues = vrmod.GetConvars()

		if not convarValues.characterIK then
			ply:SetPlaybackRate(0)
			ply:SetPoseParameter("move_yaw", 0)
			ply:SetPoseParameter("move_x",   0)
			ply:SetPoseParameter("move_y",   0)
			return ACT_MP_STAND_IDLE, -1
		end

		local velLen = vel:Length2DSqr()
		if velLen > 0.01 then
			ply:SetPoseParameter("move_yaw",
				math.NormalizeAngle(vel:Angle().y - ply:EyeAngles().y))
		end

		local act
		if velLen > 22500 then
			act = ACT_MP_RUN
		elseif velLen > 0.25 then
			act = ACT_MP_WALK
		else
			act = ACT_MP_STAND_IDLE
		end

		local seq = ply:SelectWeightedSequence(act)
		return act, (seq and seq > 0) and seq or -1
	end

	hook.Add("DoAnimationEvent", "ixVRCompat_NoGestures", function(ply, event, data)
		if not ply:IsPlayer() then return end
		if ixIsVRPlayer(ply) then return 0 end
	end)

	hook.Add("UpdateAnimation", "ixVRCompat_ClearOutfitParams", function(entity)
		if not entity:IsPlayer() then return end
		if not ixIsVRPlayer(entity) then return end
		local outfit = entity.char_outfit
		if not outfit then return end
		local params = outfit.lastPoseParams
		if not params then return end
		for k in pairs(params) do
			entity:SetPoseParameter(k, 0)
		end
	end)

	hook.Add("VRMod_Start", "ixVRCompat_ClientEnter", function(ply)
		if ply ~= LocalPlayer() then return end
		ixPlayerInVR = true
		AddHelixMenuItems()
		EnableFullscreenHUD()
		timer.Simple(0, function()
			hook.Add("CalcMainActivity", "vrutil_hook_calcmainactivity", ixVRCalcMainActivity)
		end)
	end)

	hook.Add("VRMod_Exit", "ixVRCompat_ClientExit", function(ply)
		if ply ~= LocalPlayer() then return end
		RemoveHelixMenuItems()
		DisableFullscreenHUD()
	end)

	hook.Add("VRMod_PostRenderEyes", "ixVRCompat_FullHUD", function(rtW, rtH)
		if not VRModLoaded() then return end
		if not ixPlayerInVR then return end

		local scrW, scrH = ScrW(), ScrH()
		local eyeW = rtW / 2

		if not ixVRHudRT then
			ixVRHudRT  = GetRenderTarget("ix_vr_hud", scrW, scrH, false)
			ixVRHudMat = CreateMaterial("ix_vr_hud_mat", "UnlitGeneric", {
				["$basetexture"] = ixVRHudRT:GetName(),
				["$translucent"] = 1,
			})
			ixHudLastRender = -1
		end

		local now = CurTime()
		if now - ixHudLastRender >= IX_HUD_INTERVAL then
			render.PushRenderTarget(ixVRHudRT)
				render.OverrideAlphaWriteEnable(true, true)
				render.Clear(0, 0, 0, 0, true, true)
				render.RenderHUD(0, 0, scrW, scrH)
				render.OverrideAlphaWriteEnable(false)
			render.PopRenderTarget()
			ixHudLastRender = now
		end

		cam.Start2D()
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(ixVRHudMat)
			surface.DrawTexturedRect(0,    0, eyeW, rtH)
			surface.DrawTexturedRect(eyeW, 0, eyeW, rtH)
		cam.End2D()
	end)

	-- ── 9. Надёжное взаимодействие с инвентарём через VR-контроллеры ─────────
	timer.Simple(0, function()
		local meta = vgui.GetControlTable("ui.inv.item")
		if not meta then return end

		local origPressed = meta.OnMousePressed
		meta.OnMousePressed = function(self, ...)
			if not ixPlayerInVR then
				return origPressed(self, ...)
			end
			if self.pendingTransfer then return end
			self.mouse_pressed = CurTime()
			ix.inventory_drag_slot = self
		end

		local origRelease = meta.OnMouseReleased
		meta.OnMouseReleased = function(self, mcode)
			if not ixPlayerInVR then
				return origRelease(self, mcode)
			end
			self:MouseCapture(false)
			dragndrop.Clear()
			if self.item_data and self.mouse_pressed then
				self.mouse_pressed = nil
				ix.Item:OpenItemMenu(self.instance_ids, self.inventory_id)
			end
		end
	end)

	hook.Add("ScoreboardShow", "ixVRCompat_SuppressTab", function()
		if not VRModLoaded() then return end
		if ixPlayerInVR then
			if IsValid(ix.gui.menu) then
				ix.gui.menu:Close()
			else
				local menu = vgui.Create("ui.tabmenu")
				if IsValid(menu) then menu:MakePopup() end
			end
			return false
		end
	end)

end -- CLIENT
