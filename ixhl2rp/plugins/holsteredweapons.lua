PLUGIN.name = "Holstered Weapons"
PLUGIN.author = "Black Tea / Legends"
PLUGIN.description = "Displays equipped inventory weapons on the back or hip."

local PLUGIN = PLUGIN

HOLSTER_DRAWINFO = HOLSTER_DRAWINFO or {}

HOLSTER_DRAWINFO["arccw_uspmatch"] = {
	pos = Vector(1, -8, -1),
	ang = Angle(0, 70, 0),
	bone = "ValveBiped.Bip01_Pelvis",
	model = "models/weapons/w_pistol.mdl"
}

HOLSTER_DRAWINFO["arccw_usp_mp443"] = {
	pos = Vector(1, -8, -1),
	ang = Angle(0, 70, 0),
	bone = "ValveBiped.Bip01_Pelvis",
	model = "models/weapons/tfa_ins2/mp443/w_mp443.mdl"
}

HOLSTER_DRAWINFO["arccw_357"] = {
	pos = Vector(-1, -7, -1),
	ang = Angle(0, 70, 0),
	bone = "ValveBiped.Bip01_Pelvis",
	model = "models/weapons/tfa_mmod/w_357.mdl"
}

HOLSTER_DRAWINFO["arccw_spas12"] = {
	pos = Vector(4, 5, -2),
	ang = Angle(-20, 8, 0),
	bone = "ValveBiped.Bip01_Spine1",
	model = "models/weapons/w_shotgun.mdl"
}

HOLSTER_DRAWINFO["arccw_smg1"] = {
	pos = Vector(3, 5, -2),
	ang = Angle(-170, -5, 180),
	bone = "ValveBiped.Bip01_Spine1",
	model = "models/weapons/w_smg1.mdl"
}

HOLSTER_DRAWINFO["arccw_m4a4"] = {
	pos = Vector(7, 20, 5),
	ang = Angle(0, 190, 0),
	bone = "ValveBiped.Bip01_Spine1",
	model = "models/weapons/arccw_go/v_rif_m4a1.mdl"
}

HOLSTER_DRAWINFO["arccw_crowbar"] = {
	pos = Vector(4, 6, 0),
	ang = Angle(30, 5, 0),
	bone = "ValveBiped.Bip01_Spine1",
	model = "models/weapons/w_crowbar.mdl"
}

HOLSTER_DRAWINFO["arccw_hatchet"] = {
	pos = Vector(5, -8, -1),
	ang = Angle(0, -90, 90),
	bone = "ValveBiped.Bip01_Pelvis",
	model = "models/weapons/tfa_nmrih/w_me_hatchet.mdl"
}

HOLSTER_DRAWINFO["arccw_knife"] = {
	pos = Vector(0, -8, 1),
	ang = Angle(0, -90, 90),
	bone = "ValveBiped.Bip01_Pelvis",
	model = "models/weapons/w_knife_ct.mdl"
}

HOLSTER_DRAWINFO["arccw_ar2"] = {
	pos = Vector(5, -4, -3),
	ang = Angle(0, 5, 0),
	bone = "ValveBiped.Bip01_Spine1",
	model = "models/weapons/w_IRifle.mdl"
}

HOLSTER_DRAWINFO["weapon_rpg"] = {
	pos = Vector(3, 20, 3),
	ang = Angle(-180, 5, 0),
	bone = "ValveBiped.Bip01_Spine1",
	model = "models/weapons/w_rocket_launcher.mdl"
}

HOLSTER_DRAWINFO["cellar_nade_flashbang"] = {
	pos = Vector(2, 8, 0),
	ang = Angle(15, 0, 270),
	bone = "ValveBiped.Bip01_Pelvis",
	model = "models/weapons/w_eq_flashbang.mdl"
}

HOLSTER_DRAWINFO["weapon_frag"] = {
	pos = Vector(2, 8, 0),
	ang = Angle(15, 0, 270),
	bone = "ValveBiped.Bip01_Pelvis",
	model = "models/items/grenadeammo.mdl"
}

HOLSTER_DRAWINFO["cellar_nade_m18"] = {
	pos = Vector(2, 8, 0),
	ang = Angle(15, 0, 270),
	bone = "ValveBiped.Bip01_Pelvis",
	model = "models/weapons/w_eq_smokegrenade_dropped.mdl"
}

HOLSTER_DRAWINFO["arccw_stunstick"] = {
	pos = Vector(4, 9, -2),
	ang = Angle(0, 100, 0),
	bone = "ValveBiped.Bip01_Pelvis",
	model = "models/weapons/w_stunbaton.mdl"
}

HOLSTER_DRAWINFO["riff_m4"] = {
    pos = Vector(3, 1, 2),
    ang = Angle(10, 180, -10),
    bone = "ValveBiped.Bip01_Spine1",
    model = "models/tnb/trpweapons/w_tc_syndicate.mdl"
}

HOLSTER_DRAWINFO["riff_357"] = {
    pos = Vector(-1, -7, -1),
    ang = Angle(0, 70, 0),
    bone = "ValveBiped.Bip01_Pelvis",
    model = "models/weapons/w_azn_trigund.mdl"
}

function PLUGIN:GetDisplayInfo(item)
	if not item.isWeapon or item.holsterDisplay == false then return end
	-- PAC is only responsible when its integration is actually available.
	if item.pacData and ix.pac and ix.pac.list then return end
	local slot = item.holsterSlot or (item.weaponCategory == "sidearm" and "hip" or
		item.weaponCategory == "primary" and "back")
	if slot ~= "hip" and slot ~= "back" then return end
	local profile = HOLSTER_DRAWINFO[item.class] or {}
	return {
		model = item.holsterModel or profile.model or item.model,
		fallback = item.holsterFallbackModel or "",
		slot = slot
	}
end

-- Inventory ownership and the live weapon's item link are both checked. A gun
-- granted by the spawn menu alone never gains an inventory holster display.
function PLUGIN:CollectEquipped(client)
	local result = {}
	local character = client:GetCharacter()
	if not character or not client:Alive() then return result end
	for _, item in pairs(client:GetItems()) do
		if item:GetData("equip") == true then
			local weapon = client:GetWeapon(item.class or "")
			if IsValid(weapon) and weapon:GetOwner() == client and weapon.ixItem == item then
				local info = self:GetDisplayInfo(item)
				if info and isstring(info.model) and info.model ~= "" then result[weapon] = info end
			end
		end
	end
	return result
end

if SERVER then
	function PLUGIN:Think()
		if (self.nextHolsterSync or 0) > CurTime() then return end
		self.nextHolsterSync = CurTime() + 0.25
		for _, client in ipairs(player.GetAll()) do
			local equipped = self:CollectEquipped(client)
			local character = client:GetCharacter()
			for _, weapon in ipairs(client:GetWeapons()) do
				local info = equipped[weapon]
				if info then
					weapon:SetNWString("ixHolsterModel", info.model)
					weapon:SetNWString("ixHolsterFallback", info.fallback)
					weapon:SetNWString("ixHolsterSlot", info.slot)
					weapon:SetNWEntity("ixHolsterOwner", client)
					weapon:SetNWInt("ixHolsterCharacter", character:GetID())
				end
				weapon:SetNWBool("ixHolsterEquipped", info ~= nil)
			end
		end
	end
	return
end

local owners = {}
local defaults = {
	hip = {bone = "ValveBiped.Bip01_Pelvis", pos = Vector(1, -8, -1), ang = Angle(0, 70, 0)},
	back = {bone = "ValveBiped.Bip01_Spine1", pos = Vector(4, 5, -2), ang = Angle(-20, 8, 0)}
}

-- EFT pistols use several stock world models. Place their visual centre at the
-- right hip in the character's facing frame instead of inheriting pelvis roll.
local eftHip = {
	bone = "ValveBiped.Bip01_Pelvis",
	pos = Vector(0, -8, -4),
	ang = Angle(90, 0, 0),
	bodyFrame = true
}

-- Bone local axes differ between model rigs. Build a body-facing frame from
-- the torso's actual direction instead of copying the bone's authored rotation.
function PLUGIN:HolsterBoneFrame(client, boneName, matrix)
	local facing = Angle(0, client:GetRenderAngles().y, 0)
	if boneName == "ValveBiped.Bip01_Pelvis" then return facing end
	local upper = client:LookupBone("ValveBiped.Bip01_Spine4") or client:LookupBone("ValveBiped.Bip01_Neck1")
	local upperMatrix = upper and client:GetBoneMatrix(upper)
	if not upperMatrix then return facing end
	local up = upperMatrix:GetTranslation() - matrix:GetTranslation()
	if up:LengthSqr() < 0.01 then return facing end
	up:Normalize()
	local forward = up:Cross(facing:Right())
	if forward:LengthSqr() < 0.01 then return facing end
	forward:Normalize()
	return forward:AngleEx(up)
end

function PLUGIN:ClearHolsters(client)
	if ix.WeaponAssembly and client.GetWeapons then
		for _, weapon in ipairs(client:GetWeapons()) do ix.WeaponAssembly.Remove(weapon) end
	end
	for _, model in pairs(client.holsteredWeapons or {}) do
		if IsValid(model) then model:Remove() end
	end
	client.holsteredWeapons = nil
	owners[client] = nil
end

function PLUGIN:CanDrawHolsters(client)
	return IsValid(client) and client:GetCharacter() and client:Alive() and
		not client:IsDormant() and not client:GetNoDraw() and client:GetColor().a > 0 and
		not IsValid(client:GetNetVar("ragdoll")) and
		client:GetPos():DistToSqr(EyePos()) < 2500 * 2500
end

function PLUGIN:PostPlayerDraw(client)
	if not self:CanDrawHolsters(client) then self:ClearHolsters(client) return end
	if client == LocalPlayer() and not client:ShouldDrawLocalPlayer() then return end
	local active = client:GetActiveWeapon()
	local characterID = client:GetCharacter():GetID()
	local used = {}
	client.holsteredWeapons = client.holsteredWeapons or {}
	owners[client] = true
	for _, weapon in ipairs(client:GetWeapons()) do
		if weapon == active or not weapon:GetNWBool("ixHolsterEquipped") or
			weapon:GetNWEntity("ixHolsterOwner") ~= client or
			weapon:GetNWInt("ixHolsterCharacter") ~= characterID then continue end
		local profile = HOLSTER_DRAWINFO[weapon:GetClass()] or defaults[weapon:GetNWString("ixHolsterSlot")]
		if weapon:GetNWString("ixHolsterSlot") == "hip" and weapon:GetClass():sub(1, 9) == "arc9_eft_" then
			profile = eftHip
		end
		if not profile then continue end
		local bone = client:LookupBone(profile.bone)
		local matrix = bone and client:GetBoneMatrix(bone)
		if not matrix then continue end
		if weapon.ARC9 and ix.WeaponAssembly then
			local A = ix.WeaponAssembly
			local tree = ix.arc9Inventory.AttachmentTree(weapon.Attachments)
			local assembly = A.Get(weapon, weapon:GetClass(), tree, weapon:Clip1())
			if assembly then
				local hip = weapon:GetNWString("ixHolsterSlot") == "hip"
				local facing = self:HolsterBoneFrame(client, profile.bone, matrix)
				local pos, ang = LocalToWorld(hip and Vector(0, -8, -4) or Vector(-3.5, 0, 9),
					hip and Angle(90, 0, 0) or Angle(-65, 90, 0), matrix:GetTranslation(), facing)
				local offset = LocalToWorld(A.Center(assembly), angle_zero, vector_origin, ang)
				A.Draw(assembly, pos - offset, ang)
			end
			continue
		end
		local path = weapon:GetNWString("ixHolsterModel")
		if not util.IsValidModel(path) then path = weapon:GetNWString("ixHolsterFallback") end
		if path == "" or not util.IsValidModel(path) then continue end
		local model = client.holsteredWeapons[weapon]
		if IsValid(model) and model:GetModel() ~= path then model:Remove() model = nil end
		if not IsValid(model) then
			model = ClientsideModel(path, RENDERGROUP_OPAQUE)
			if not IsValid(model) then continue end
			model:SetNoDraw(true)
			client.holsteredWeapons[weapon] = model
		end
		used[weapon] = true
		local pos, ang = matrix:GetTranslation(), matrix:GetAngles()
		if profile.bodyFrame then
			local facing = Angle(0, client:GetRenderAngles().y, 0)
			pos, ang = LocalToWorld(profile.pos * client:GetModelScale(), profile.ang, pos, facing)
			-- Imported models do not all put their origin in the grip. Centre the
			-- visible mesh so that those origin differences do not shift the holster.
			model:SetModelScale(1, 0)
			local mins, maxs = model:GetRenderBounds()
			local offset = LocalToWorld((mins + maxs) * (0.5 * client:GetModelScale()), angle_zero, vector_origin, ang)
			pos = pos - offset
		else
		local right, up, forward = ang:Right(), ang:Up(), ang:Forward()
		pos = pos + profile.pos.x * right + profile.pos.y * forward + profile.pos.z * up
		ang:RotateAroundAxis(right, profile.ang.p)
		ang:RotateAroundAxis(up, profile.ang.y)
		ang:RotateAroundAxis(forward, profile.ang.r)
		end
		model:SetModelScale(client:GetModelScale(), 0)
		model:SetPos(pos)
		model:SetAngles(ang)
		model:SetupBones()
		model:DrawModel()
	end
	for weapon, model in pairs(client.holsteredWeapons) do
		if not used[weapon] then
			if IsValid(model) then model:Remove() end
			client.holsteredWeapons[weapon] = nil
		end
	end
end

function PLUGIN:Think()
	if (self.nextHolsterCleanup or 0) > CurTime() then return end
	self.nextHolsterCleanup = CurTime() + 1
	for client in pairs(owners) do
		if not self:CanDrawHolsters(client) then self:ClearHolsters(client) end
	end
end

function PLUGIN:EntityRemoved(entity)
	if owners[entity] then self:ClearHolsters(entity) end
end

function PLUGIN:ShutDown()
	for client in pairs(owners) do self:ClearHolsters(client) end
end

-- Includes models made by the previous implementation during Lua auto-refresh.
for _, client in ipairs(player.GetAll()) do PLUGIN:ClearHolsters(client) end
