ENT.Type = "anim"
ENT.PrintName = "Gunsmith Workbench"
ENT.Author = "Hutten"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.Model = "models/props_combine_enhanced/combine_table.mdl"

function ENT:SpawnFunction(client, trace)
	local ent = ents.Create(self.ClassName)
	ent:SetPos(trace.HitPos + trace.HitNormal * 8)
	ent:SetAngles(Angle(0, client:EyeAngles().y + 180, 0))
	ent:Spawn()
	ent:Activate()

	return ent
end

if SERVER then
	function ENT:Initialize()
		self:SetModel(self.Model)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)

		local phys = self:GetPhysicsObject()

		if IsValid(phys) then
			phys:EnableMotion(false)
			phys:Sleep()
		end
	end

	function ENT:Use(client)
		if !IsValid(client) or !client:IsPlayer() then
			return
		end

		local ct = CurTime()

		if (client.nextGunsmithUse and ct < client.nextGunsmithUse) or client:IsRestricted() then
			return
		end

		client.nextGunsmithUse = ct + 1

		local weapon = client:GetActiveWeapon()

		if !IsValid(weapon) or !weapon.ArcCW then
			client:NotifyLocalized("gunsmith.needWeapon")
			return
		end

		-- Open the ArcCW customization menu on the client. The attach/detach
		-- gate in sv_plugin.lua authorises the actual changes by proximity to
		-- this bench and charges resin per modification.
		net.Start("arccw_togglecustomize")
			net.WriteBool(true)
		net.Send(client)

		client:NotifyLocalized("gunsmith.opened")
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_PVS
	end
else
	ENT.PopulateEntityInfo = true

	function ENT:OnPopulateEntityInfo(tooltip)
		local name = tooltip:AddRow("name")
		name:SetImportant()
		name:SetText(L("gunsmith.benchName"))
		name:SizeToContents()

		local desc = tooltip:AddRow("description")
		desc:SetText(L("gunsmith.benchHint"))
		desc:SizeToContents()
	end

	function ENT:Draw()
		self:DrawModel()
	end
end
