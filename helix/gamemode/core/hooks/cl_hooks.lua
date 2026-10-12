
function GM:ForceDermaSkin()
	return "helix"
end

function GM:ScoreboardShow()
	if (LocalPlayer():GetCharacter()) then
		if IsValid(ix.gui.menu) then
			ix.gui.menu:Close()
		else
			vgui.Create("ui.tabmenu")
		end
	end
end

function GM:ScoreboardHide()
end

function GM:OnCharacterMenuCreated(panel)
	if (IsValid(ix.gui.notices)) then
		ix.gui.notices:Clear()
	end
end

local LOWERED_ANGLES = Angle(30, 0, -25)

local function HasViewWeaponOwner(weapon, client)
	if (!IsValid(weapon) or !weapon.ARC9) then return true end
	local owner = weapon:GetOwner()
	return IsValid(owner) and owner:IsPlayer() and owner == client
end

function GM:CalcViewModelView(weapon, viewModel, oldEyePos, oldEyeAngles, eyePos, eyeAngles)
	if (!IsValid(weapon)) then
		return
	end

	local client = LocalPlayer()
	if (!IsValid(client) or !HasViewWeaponOwner(weapon, client)) then
		return eyePos, eyeAngles
	end
	local bWepRaised = client:IsWepRaised()

	-- update tween if the raised state is out of date
	if (client.ixWasWeaponRaised != bWepRaised) then
		local fraction = bWepRaised and 0 or 1

		client.ixRaisedFraction = 1 - fraction
		client.ixRaisedTween = ix.tween.new(0.75, client, {
			ixRaisedFraction = fraction
		}, "outQuint")

		client.ixWasWeaponRaised = bWepRaised
	end

	local fraction = client.ixRaisedFraction
	local rotation = weapon.LowerAngles or LOWERED_ANGLES

	if (ix.option.Get("altLower", true) and weapon.LowerAngles2) then
		rotation = weapon.LowerAngles2
	end

	eyeAngles:RotateAroundAxis(eyeAngles:Up(), rotation.p * fraction)
	eyeAngles:RotateAroundAxis(eyeAngles:Forward(), rotation.y * fraction)
	eyeAngles:RotateAroundAxis(eyeAngles:Right(), rotation.r * fraction)

	if ix.Immersion and ix.Immersion.WeaponMotion then
		ix.Immersion.WeaponMotion(client, weapon, eyePos, eyeAngles)
	end

	viewModel:SetAngles(eyeAngles)
	local position, angles = self.BaseClass:CalcViewModelView(weapon, viewModel, oldEyePos, oldEyeAngles, eyePos, eyeAngles)
	if ix.PlayerControls and ix.PlayerControls.UpdateWeaponFOV then
		ix.PlayerControls.UpdateWeaponFOV(client)
	end
	return position, angles
end

function GM:LoadIntro()
	if (!IsValid(ix.gui.intro)) then
		vgui.Create("ixIntro")
	end
end

function GM:CharacterLoaded()
	local menu = ix.gui.characterMenu

	if (IsValid(menu)) then
		menu:Close((LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()) and true or nil)
	end

	local character = LocalPlayer():GetCharacter()
	
	for var, data in pairs(ix.char.meta_vars) do
		character.meta_vars[var]:Load(character.vars)
	end
end

function GM:InitializedConfig()
	local color = ix.config.Get("color")

	hook.Run("LoadFonts", ix.config.Get("font"), ix.config.Get("genericFont"))
	hook.Run("ColorSchemeChanged", color)

	if (!ix.config.loaded and !IsValid(ix.gui.loading)) then
		local loader = vgui.Create("EditablePanel")
		loader:ParentToHUD()
		loader:Dock(FILL)
		loader.Paint = function(this, w, h)
			surface.SetDrawColor(0, 0, 0)
			surface.DrawRect(0, 0, w, h)
		end

		local statusLabel = loader:Add("DLabel")
		statusLabel:Dock(FILL)
		statusLabel:SetText(L"loading")
		statusLabel:SetFont("ixTitleFont")
		statusLabel:SetContentAlignment(5)
		statusLabel:SetTextColor(color_white)

		timer.Simple(5, function()
			if (IsValid(ix.gui.loading)) then
				local fault = ix.Net:GetVar("dbError")

				if (fault) then
					statusLabel:SetText(fault and L"dbError" or L"loading")

					local label = loader:Add("DLabel")
					label:DockMargin(0, 64, 0, 0)
					label:Dock(TOP)
					label:SetFont("ixSubTitleFont")
					label:SetText(fault)
					label:SetContentAlignment(5)
					label:SizeToContentsY()
					label:SetTextColor(Color(255, 50, 50))
				end
			end
		end)

		ix.gui.loading = loader
		ix.config.loaded = true

		if (ix.config.Get("intro", true) and ix.option.Get("showIntro", true)) then
			hook.Run("LoadIntro")
		end
	end
end

function GM:InitPostEntity()
	ix.joinTime = RealTime() - 0.9716
	ix.option.Sync()

	ix.gui.bars = vgui.Create("ixInfoBarManager")
end

function GM:NetworkEntityCreated(entity)
	if (entity:IsPlayer()) then
		entity:SetIK(false)

		-- we've just discovered a new player, so we need to update their animation state
		if (entity != LocalPlayer()) then
			-- we don't need to call the PlayerWeaponChanged hook here since it'll be handled below,
			-- when this player's weapon has been discovered
			hook.Run("PlayerModelChanged", entity, entity:GetModel())
		end
	elseif (entity:IsWeapon()) then
		local owner = entity:GetOwner()

		if (IsValid(owner) and owner:IsPlayer() and entity == owner:GetActiveWeapon()) then
			hook.Run("PlayerWeaponChanged", owner, entity)
		end
	end
end

local vignette = ix.util.GetMaterial("helix/gui/vignette.png")
local vignetteAlphaGoal = 0
local vignetteAlphaDelta = 0
local vignetteTraceHeight = Vector(0, 0, 768)
local blurGoal = 0
local blurDelta = 0
local hasVignetteMaterial = !vignette:IsError()

timer.Create("ixVignetteChecker", 1, 0, function()
	local client = LocalPlayer()

	if (IsValid(client)) then
		local data = {}
			data.start = client:GetPos()
			data.endpos = data.start + vignetteTraceHeight
			data.filter = client
		local trace = util.TraceLine(data)

		-- this timer could run before InitPostEntity is called, so we have to check for the validity of the trace table
		if (trace and trace.Hit) then
			vignetteAlphaGoal = 25
		else
			vignetteAlphaGoal = 0
		end
	end
end)

function GM:CalcView(client, origin, angles, fov)
	local view = {origin = origin, angles = angles, fov = fov, drawviewer = false}
	if (!IsValid(client)) then return view end
	local entity = Entity(client:GetLocalVar("ragdoll", 0))
	local ragdoll = IsValid(client:GetRagdollEntity()) and client:GetRagdollEntity() or entity

	if ((!client:ShouldDrawLocalPlayer() and IsValid(entity) and entity:IsRagdoll())
	or (!client:Alive() and IsValid(ragdoll))) then
		local ent = client:Alive() and entity or ragdoll
		local index = ent:LookupAttachment("eyes")

		if (index and index > 0) then
			local data = ent:GetAttachment(index)

			if (data) then
				view.origin = data.Pos
				view.angles = data.Ang
			end
		end
		-- Resolve the body camera before the base gamemode can call the SWEP.
		return view
	end

	-- A valid active weapon may still have a NULL/non-player owner for a frame.
	-- ARC9's camera assumes player methods just like its crosshair does.
	if (!HasViewWeaponOwner(client:GetActiveWeapon(), client)) then return view end
	view = self.BaseClass:CalcView(client, origin, angles, fov) or view

	if (ix.Immersion and ix.Immersion.ApplyCamera) then
		ix.Immersion.ApplyCamera(client, view, origin, angles)
	end
	return view
end

local hookRun = hook.Run

do
	local aimLength = 0.35
	local aimTime = 0
	local aimEntity
	local lastEntity
	local lastTrace = {}

	timer.Create("ixCheckTargetEntity", 0.1, 0, function()
		local client = LocalPlayer()
		local time = SysTime()

		if (!IsValid(client)) then
			return
		end

		local character = client:GetCharacter()

		if (!character) then
			return
		end

		lastTrace.start = client:GetShootPos()
		lastTrace.endpos = lastTrace.start + client:GetAimVector(client) * 160
		lastTrace.filter = client
		lastTrace.mask = MASK_SHOT_HULL

		lastEntity = util.TraceHull(lastTrace).Entity

		if (lastEntity != aimEntity) then
			aimTime = time + aimLength
			aimEntity = lastEntity
		end

		local panel = ix.gui.entityInfo
		local bShouldShow = time >= aimTime and (!IsValid(ix.gui.characterMenu) or ix.gui.characterMenu.bClosing)
		local bShouldPopulate = lastEntity.OnShouldPopulateEntityInfo and lastEntity:OnShouldPopulateEntityInfo() or true

		if (bShouldShow and IsValid(lastEntity) and hookRun("ShouldPopulateEntityInfo", lastEntity) != false and
			(lastEntity.PopulateEntityInfo or bShouldPopulate)) then

			if (!IsValid(panel) or (IsValid(panel) and panel:GetEntity() != lastEntity)) then
				if (IsValid(ix.gui.entityInfo)) then
					ix.gui.entityInfo:Remove()
				end

				local infoPanel = vgui.Create(ix.option.Get("minimalTooltips", false) and "ixTooltipMinimal" or "ixTooltip")
				local entityPlayer = lastEntity:GetNetVar("player")

				if (entityPlayer) then
					infoPanel:SetEntity(entityPlayer)
					infoPanel.entity = lastEntity
				else
					infoPanel:SetEntity(lastEntity)
				end

				infoPanel:SetDrawArrow(true)
				ix.gui.entityInfo = infoPanel
			end
		elseif (IsValid(panel)) then
			panel:Remove()
		end
	end)
end

local mathApproach = math.Approach
local surface = surface

function GM:HUDPaintBackground()
	local client = LocalPlayer()

	if (!client:GetCharacter()) then
		return
	end

	local frameTime = FrameTime()
	local scrW, scrH = ScrW(), ScrH()

	if (hasVignetteMaterial and ix.config.Get("vignette")) then
		vignetteAlphaDelta = mathApproach(vignetteAlphaDelta, vignetteAlphaGoal, frameTime * 30)

		surface.SetDrawColor(0, 0, 0, 230 + vignetteAlphaDelta)
		surface.SetMaterial(vignette)
		surface.DrawTexturedRect(0, 0, scrW, scrH)
	end

	blurGoal = client:GetLocalVar("blur", 0) + (hookRun("AdjustBlurAmount", blurGoal) or 0)

	if (blurDelta != blurGoal) then
		blurDelta = mathApproach(blurDelta, blurGoal, frameTime * 20)
	end

	if (blurDelta > 0 and !client:ShouldDrawLocalPlayer()) then
		-- Injury/unconsciousness must remain readable even with broken PP assets.
        local shade = math.Clamp(blurDelta / 25, 0, 1)
        surface.SetDrawColor(8, 5, 7, 38 * shade)
        surface.DrawRect(0, 0, scrW, scrH)
        local edge = scrH * 0.23
        for band = 0, 47 do
            local y = edge * band / 48
            surface.SetDrawColor(4, 3, 5, 130 * shade * (1 - band / 48)^2)
            surface.DrawRect(0, y, scrW, math.ceil(edge / 48))
            surface.DrawRect(0, scrH - y - math.ceil(edge / 48), scrW, math.ceil(edge / 48))
        end
	end

	self.BaseClass:PaintWorldTips()

	local weapon = client:GetActiveWeapon()

	if (not (ix.GameplayHUD and ix.GameplayHUD.Enabled()) and IsValid(weapon) and hook.Run("CanDrawAmmoHUD", weapon) != false and weapon.DrawAmmo != false) then
		local clip = weapon:Clip1()
		local clipMax = weapon:GetMaxClip1()
		local count = client:GetAmmoCount(weapon:GetPrimaryAmmoType())
		local secondary = client:GetAmmoCount(weapon:GetSecondaryAmmoType())
		local x, y = scrW - 80, scrH - 80

		if (secondary > 0) then
			ix.util.DrawBlurAt(x, y, 64, 64)

			surface.SetDrawColor(255, 255, 255, 5)
			surface.DrawRect(x, y, 64, 64)
			surface.SetDrawColor(255, 255, 255, 3)
			surface.DrawOutlinedRect(x, y, 64, 64)

			ix.util.DrawText(secondary, x + 32, y + 32, nil, 1, 1, "ixBigFont")
		end

		if (weapon:GetClass() != "weapon_slam" and clip > 0 or count > 0) then
			x = x - (secondary > 0 and 144 or 64)

			ix.util.DrawBlurAt(x, y, 128, 64)

			surface.SetDrawColor(255, 255, 255, 5)
			surface.DrawRect(x, y, 128, 64)
			surface.SetDrawColor(255, 255, 255, 3)
			surface.DrawOutlinedRect(x, y, 128, 64)

			ix.util.DrawText((clip == -1 or clipMax == -1) and count or clip.."/"..count, x + 64, y + 32, nil, 1, 1, "ixBigFont")
		end
	end

	if (client:GetLocalVar("restricted") and !client:GetLocalVar("restrictNoMsg")) then
		ix.util.DrawText(L"restricted", scrW * 0.5, scrH * 0.33, nil, 1, 1, "ixBigFont")
	end

	ix.hud.DrawAll(false)
end

function GM:PostDrawOpaqueRenderables(bDepth, bSkybox)
	if (bDepth or bSkybox or #ix.blurRenderQueue == 0) then
		return
	end

	ix.util.ResetStencilValues()
	render.SetStencilEnable(true)
		render.SetStencilWriteMask(27)
		render.SetStencilTestMask(27)
		render.SetStencilFailOperation(STENCILOPERATION_KEEP)
		render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
		render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
		render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
		render.SetStencilReferenceValue(27)

		for i = 1, #ix.blurRenderQueue do
			ix.blurRenderQueue[i]()
		end

		render.SetStencilReferenceValue(34)
		render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
		render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
		render.SetStencilReferenceValue(27)

		cam.Start2D()
			ix.util.DrawBlurAt(0, 0, ScrW(), ScrH())
		cam.End2D()
	render.SetStencilEnable(false)

	ix.blurRenderQueue = {}
end

function GM:PostDrawHUD()
	cam.Start2D()
		ix.hud.DrawAll(true)

		if !IsValid(ix.gui.characterMenu) or ix.gui.characterMenu:IsClosing() then
			ix.bar.DrawAction()
		end
	cam.End2D()
end

function GM:ShouldPopulateEntityInfo(entity)
	local client = LocalPlayer()
	local ragdoll = Entity(client:GetLocalVar("ragdoll", 0))
	local entityPlayer = entity:GetNetVar("player")

	if (vgui.CursorVisible() or !client:Alive() or IsValid(ragdoll) or entity == client or entityPlayer == client) then
		return false
	end
end

local injTextTable = {
	[.3] = {"injMajor", Color(192, 57, 43)},
	[.6] = {"injLittle", Color(231, 76, 60)},
}

function GM:GetInjuredText(client)
	local health = client:Health()

	for k, v in pairs(injTextTable) do
		if ((health / client:GetMaxHealth()) < k) then
			return v[1], v[2]
		end
	end
end

local gray_color = Color(160, 160, 160)
function GM:PopulateImportantCharacterInfo(client, character, container)
	container:SetArrowColor(gray_color)

	-- name
	local name = container:AddRow("name")
	name:SetImportant()
	name:SetText(hookRun("GetCharacterName", client) or character:GetName())
	name:SetBackgroundColor(gray_color)
	name:SizeToContents()

	-- injured text
	local injureText, injureTextColor = hookRun("GetInjuredText", client)

	if (injureText) then
		local injure = container:AddRow("injureText")

		injure:SetText(L(injureText))
		injure:SetBackgroundColor(injureTextColor)
		injure:SizeToContents()
	end
end

function GM:PopulateCharacterInfo(client, character, container)
	local genetic = character:Genetic()
	local genText = ""

	if genetic then
		genText = genetic:GetDesc(true)
	end

	if genText != "" then
		local description = container:AddRow("genetic")
		description:SetText(genText)
		description:SizeToContents()
	end

	-- description
	local maxLen = ix.config.Get("descriptionDisplayLength", 256)
	local descriptionText = character:GetDescription()
	descriptionText = (descriptionText:utf8len() > maxLen and
		string.format("%s...", descriptionText:utf8sub(1, maxLen - 3)) or
		descriptionText)

	if (descriptionText != "") then
		local description = container:AddRow("description")
		description:SetText(descriptionText)
		description:SizeToContents()
	end
end

function GM:KeyRelease(client, key)
	if (!IsFirstTimePredicted()) then
		return
	end

	if (key == IN_USE) then
		if (!ix.menu.IsOpen()) then
			local data = {}
			data.start = client:GetShootPos()
			data.endpos = data.start + client:GetAimVector() * 96
			data.filter = client

			local entity = util.TraceLine(data).Entity

			if (IsValid(entity) and isfunction(entity.GetEntityMenu)) then
				hook.Run("ShowEntityMenu", entity)
			end
		end

		timer.Remove("ixItemUse")

		client.ixInteractionTarget = nil
		client.ixInteractionStartTime = nil
	end
end

function GM:PlayerBindPress(client, bind, pressed)
	bind = bind:lower()

	if (bind:find("use") and pressed) then
		local pickupTime = ix.config.Get("itemPickupTime", 0.5)

		if (pickupTime > 0) then
			local data = {}
				data.start = client:GetShootPos()
				data.endpos = data.start + client:GetAimVector() * 96
				data.filter = client
			local entity = util.TraceLine(data).Entity

			if (IsValid(entity) and entity.ShowPlayerInteraction and !ix.menu.IsOpen()) then
				client.ixInteractionTarget = entity
				client.ixInteractionStartTime = SysTime()

				timer.Create("ixItemUse", pickupTime, 1, function()
					client.ixInteractionTarget = nil
					client.ixInteractionStartTime = nil
				end)
			end
		end
	elseif (bind:find("jump")) then
		local entity = Entity(client:GetLocalVar("ragdoll", 0))

		if (IsValid(entity)) then
			ix.command.Send("CharGetUp")
		end
	elseif (bind:find("speed") and client:KeyDown(IN_WALK) and pressed) then
		if (LocalPlayer():Crouching()) then
			RunConsoleCommand("-duck")
		else
			RunConsoleCommand("+duck")
		end
	end
end

function GM:CreateMove(command)
	if ((IsValid(ix.gui.characterMenu) and !ix.gui.characterMenu.bClosing)) then
		command:ClearButtons()
		command:ClearMovement()
	end
end

-- Called when use has been pressed on an item.
function GM:ShowEntityMenu(entity)
	local options = entity:GetEntityMenu(LocalPlayer())

	if (istable(options) and !table.IsEmpty(options)) then
		ix.menu.Open(options, entity, true)
	end
end

local hidden = {}
hidden["CHudHealth"] = true
hidden["CHudBattery"] = true
hidden["CHudAmmo"] = true
hidden["CHudSecondaryAmmo"] = true
hidden["CHudCrosshair"] = true
hidden["CHudHistoryResource"] = true
hidden["CHudPoisonDamageIndicator"] = true
hidden["CHudSquadStatus"] = true
hidden["CHUDQuickInfo"] = true

function GM:HUDShouldDraw(element)
	if (hidden[element]) then
		return false
	end

	return true
end

function GM:ShouldDrawLocalPlayer(client)
	if (IsValid(ix.gui.characterMenu) and ix.gui.characterMenu:IsVisible()) then
		return false
	end
end

function GM:PostProcessPermitted(class)
	return false
end

function GM:RenderScreenspaceEffects()

end

function GM:ShowPlayerOptions(client, options)
	options["viewProfile"] = {"icon16/user.png", function()
		if (IsValid(client)) then
			client:ShowProfile()
		end
	end}
	options["Copy Steam ID"] = {"icon16/user.png", function()
		if (IsValid(client)) then
			SetClipboardText(client:SteamID())
		end
	end}
end

function GM:DrawHelixModelView(panel, ent)
	if (ent.weapon and IsValid(ent.weapon)) then
		ent.weapon:DrawModel()
	end
end

net.Receive("ixStringRequest", function()
	local time = net.ReadUInt(32)
	local title, subTitle = net.ReadString(), net.ReadString()
	local default = net.ReadString()

	if (title:sub(1, 1) == "@") then
		title = L(title:sub(2))
	end

	if (subTitle:sub(1, 1) == "@") then
		subTitle = L(subTitle:sub(2))
	end

	Derma_StringRequest(title, subTitle, default or "", function(text)
		net.Start("ixStringRequest")
			net.WriteUInt(time, 32)
			net.WriteString(text)
		net.SendToServer()
	end)
end)

function GM:Think()
	local client = LocalPlayer()

	if (IsValid(client) and client:Alive() and client.ixRaisedTween) then
		client.ixRaisedTween:update(FrameTime())
	end

	hook.Run("SlowThink")
end

function GM:ScreenResolutionChanged(oldW, oldH)
	hook.Run("LoadFonts", ix.config.Get("font"), ix.config.Get("genericFont"))

	if (IsValid(ix.gui.notices)) then
		ix.gui.notices:Remove()
		ix.gui.notices = vgui.Create("ixNoticeManager")
	end

	if (IsValid(ix.gui.bars)) then
		ix.gui.bars:Remove()
		ix.gui.bars = vgui.Create("ixInfoBarManager")
	end
end

function GM:DrawDeathNotice()
	return false
end

function GM:HUDAmmoPickedUp()
	return false
end

function GM:HUDDrawPickupHistory()
	return false
end

function GM:HUDDrawTargetID()
	return false
end

gameevent.Listen("player_spawn")
hook.Add("player_spawn", "ixPlayerSpawn", function(data)
	local client = Player(data.userid)

	if (IsValid(client)) then
		-- GetBoneName returns __INVALIDBONE__ for everything the first time you use it, so we'll force an update to make them valid
		client:SetupBones()
		client:SetIK(false)
	end
end)
